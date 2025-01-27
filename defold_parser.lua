local offset = 0
local file = ''

local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

local function is_array(tbl)
  return tbl[1] ~= nil
end

---@return string|nil
local function _char()
  offset = offset + 1
  local c = file:sub(offset, offset)
  if c == '' then return nil end
  return c
end

local function _skip_spaces()
  while 1 do
    local c = _char()
    if c ~= ' ' and c ~= '\t' then
      offset = offset - 1
      return
    end
  end
end

local obj = {}
---@return string
function obj:extract_key()
  _skip_spaces()
  local result = ''
  while 1 do
    local c = _char()
    if c:match('[a-zA-Z_]+') then
      result = result .. c
    else
      offset = offset - 1
      return result
    end
  end
end

---@return string
function obj:extract_scalar()
  _skip_spaces()
  local result = ''
  local c = _char()
  if c == '"' then -- parse oneline/multiline text
    local skip_quote = false
    while 1 do
      c = _char()
      if c == nil then return result end
      if c == '"' and not skip_quote then
        _skip_spaces()
        if _char() == '"' then
          offset = offset - 1
          result = result .. "\n" .. self:extract_scalar()
          return result
        else
          offset = offset - 1
          return result
        end
      else
        skip_quote = false
        if c == "\\" then skip_quote = true end
        result = result .. c
      end
    end
  else -- parse oneline value (const/number)
    offset = offset - 1
    while 1 do
      c = _char()
      if c ~= " " and c ~= "\t" and c ~= nil then
        result = result .. c
      else
        return result
      end
    end
  end
end

---@return string|table
function obj:extract_value()
  _skip_spaces()
  local c = _char()
  if c == ':' then return obj:extract_scalar() end
  if c == '{' then return obj:extract_dict() end
  error("file format error")
end

---@return table
function obj:extract_dict()
  _skip_spaces()
  local result = {}
  while 1 do
    local key = obj:extract_key()
    local value = obj:extract_value()
    if result[key] ~= nil then
      if not is_array(result[key]) then
        result[key] = { result[key] }
      end
      table.insert(result[key], value)
    else
      result[key] = value
    end
    _skip_spaces()
    local c = _char()
    if c == "}" or c == nil then
      return result
    else
      offset = offset - 1
    end
  end
end

local export = {}
---@meta
---@param path string
function export:parse_file(path)
  local f = io.open(path, 'r')
  local rows = {}
  assert(f, ("read file error: %s"):format(path))
  for v in f:lines() do if v then table.insert(rows, trim(v)) end end
  return self:parse(table.concat(rows, ' '))
end

function export:parse(text)
  offset = 0
  file = text
  return obj:extract_dict()
end

return export
