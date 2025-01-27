local offset = 0
local file = ''
local extract_dict

local function trim(str) return str:match("^%s*(.-)%s*$") end

local function is_array(tbl) return tbl[1] ~= nil end

---@return string|nil
local function get_char()
  offset = offset + 1
  local c = file:sub(offset, offset)
  if c == '' then return nil end
  return c
end

local function skip_spaces()
  while 1 do
    local c = get_char()
    if c ~= ' ' and c ~= '\t' then
      offset = offset - 1
      return
    end
  end
end

---@return string
function extract_key()
  skip_spaces()
  local result = ''
  while 1 do
    local c = get_char()
    assert(c, "extract key error")
    if c:match('[a-zA-Z_]+') then
      result = result .. c
    else
      offset = offset - 1
      return result
    end
  end
end

---@return string
function extract_scalar()
  skip_spaces()
  local result = ''
  local c = get_char()
  if c == '"' then -- parse text (oneline/multiline)
    local skip_quote = false
    while 1 do
      c = get_char()
      if c == nil then return result end
      if c == '"' and not skip_quote then
        skip_spaces()
        if get_char() == '"' then
          offset = offset - 1
          result = result .. "\n" .. extract_scalar()
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
      c = get_char()
      if c ~= " " and c ~= "\t" and c ~= nil then
        result = result .. c
      else
        return result
      end
    end
  end
end

---@return string|table
function extract_value()
  skip_spaces()
  local c = get_char()
  if c == ':' then return extract_scalar() end
  if c == '{' then return extract_dict() end
  error("file format error")
end

---@return table
extract_dict = function()
  skip_spaces()
  local result = {}
  while 1 do
    local key = extract_key()
    local value = extract_value()
    if result[key] ~= nil then
      if not is_array(result[key]) then
        result[key] = { result[key] }
      end
      table.insert(result[key], value)
    else
      result[key] = value
    end
    skip_spaces()
    local c = get_char()
    if c == "}" or c == nil then
      return result
    else
      offset = offset - 1
    end
  end
end

-----------------------------------
---@param text string
local function parse(text)
  offset = 0
  file = text
  return extract_dict()
end
---@meta
---@param path string
local function parse_file(path)
  local f = io.open(path, 'r')
  local rows = {}
  assert(f, ("read file error: %s"):format(path))
  for v in f:lines() do if v then table.insert(rows, trim(v)) end end
  return parse(table.concat(rows, ' '))
end

return {
  parse_file = parse_file,
  parse = parse
}
