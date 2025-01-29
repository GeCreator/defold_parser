local offset = 0
local file = ''
---@type function
local extract_dict
local tab = '  '

local function sorted_table()
  local keys = {}
  local data = {}

  local mt = {
    __index = function(tbl, k)
      if data[k] ~= nil then
        return data[k]
      end
      return nil
    end,
    __newindex = function(_, k, v)
      if data[k] == nil then
        table.insert(keys, k)
      end
      data[k] = v
    end,
    __pairs = function(tbl)
      local offset = 0
      return function(_)
        offset = offset + 1
        local key = keys[offset]
        local value = data[key]

        return key, value
      end, tbl, nil
    end
  }
  return setmetatable({}, mt)
end

local function trim(str) return str:match("^%s*(.-)%s*$") end

local function is_array(tbl)
  return type(tbl) == 'table' and tbl[1] ~= nil
end

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
    if c:match('[a-zA-Z0-9_]+') then
      result = result .. c
    else
      offset = offset - 1
      return result
    end
  end
end

---@return string|number|any
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
        if result:match("^[0-9\\.]+$") then return tonumber(result) end
        return result
      end
    end
  end
end

---@return string|table|number
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
--Convert string(in defold file format) to table
---@param text string
---@return table
local function parse(text)
  offset = 0
  file = text
  return extract_dict()
end

--Convert lua table to string(in defold file format)
---@param level number
---@param tbl table
---@return string
local function compile(tbl, level)
  local result = ''
  local keys = {}
  for k in pairs(tbl) do table.insert(keys, k) end
  table.sort(keys)

  for _, key in ipairs(keys) do
    if is_array(tbl[key]) then
      for _, v in ipairs(tbl[key]) do
        result = result .. tab:rep(level) .. key .. " {\n"
        result = result .. tab:rep(level) .. compile(v, level + 1)
        result = result .. tab:rep(level) .. "}\n"
      end
    else
      local value
      if type(tbl[key]) == 'string' then
        if tbl[key]:upper() ~= tbl[key] then
          value = '"' .. tbl[key] .. '"'
        else
          value = tbl[key]
        end
      elseif type(tbl[key]) == 'table' then
        print("---")
        dump(tbl[key])
        print("---")
        os.exit()
      end
      result = result .. tab:rep(level) .. key .. ': ' .. value .. "\n"
    end
  end
  return result
end

compile_string = function(tbl)
  return compile(tbl, 0)
end

--Parse defold file and return table
---@meta
---@param path string
local function parse_file(path)
  local f = io.open(path, 'r')
  local rows = {}
  assert(f, ("read file error: %s"):format(path))
  for v in f:lines() do if v then table.insert(rows, trim(v)) end end
  return parse(table.concat(rows, ' '))
end

local function compile_and_save(path, tbl)
  local f = io.open(path, 'w')
  assert(f, ("file write error to %s"):format(path))
  f:write(compile(tbl, 0))
  f:close()
end

return {
  table = sorted_table,
  parse = parse,
  compile = compile_string,
  save = compile_and_save,
  load = parse_file,
}
