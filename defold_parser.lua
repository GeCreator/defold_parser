---@type function
local extract_dict
---@type function
local compile

local tab = '  '

---Returns a table that is protected from key shuffling.
---In what order the keys were added, the iteration(ipairs(), pairs()) will be in the same order.
---@return table
local function sorted_table()
  local keys = {}
  local data = {}

  local mt = {
    __index = function(_, k)
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

---@return RawDataContainer
---@param data string
local function make_container(data)
  data = data:gsub("\n", " ")
  ---@class RawDataContainer
  local obj = {
    file = data,
    offset = 0,
  }
  ---@return string|nil
  function obj:get_char()
    self.offset = self.offset + 1
    local c = self.file:sub(self.offset, self.offset)
    if c == '' then return nil end
    return c
  end

  function obj:skip_spaces()
    while 1 do
      local c = self:get_char()
      if c ~= ' ' and c ~= '\t' then
        self.offset = self.offset - 1
        return
      end
    end
  end

  function obj:back()
    self.offset = self.offset - 1
  end

  return obj
end

local function split_string(str, delimiter)
  local result = {}
  for part in str:gmatch("[^" .. delimiter .. "]*") do
    table.insert(result, part)
  end
  return result
end

--Unquote string to one level
---@param str string
---@return string
local function decode_text_field(str)
  str = string.gsub(str, [[\\n]], [[__N]])
  str = string.gsub(str, [[\n""]], "\n")
  str = string.gsub(str, [[__N"]], "\\\\n\"\n")
  str = string.gsub(str, [[\\]], [[\]])
  str = string.gsub(str, [[\"]], [["]])
  return str
end

---@param str string
---@return string
local function encode_text_field(str)
  local result = ''
  local parts = split_string(str, "\n")

  for i, line in ipairs(parts) do
    if string.match(line, '\\n"$') ~= nil then
      line = string.gsub(line, '^"', '')
      line = string.gsub(line, '"$', '')
      line = string.gsub(line, [[\]], [[\\]])
      line = string.gsub(line, [["]], [[\"]])
      result = result .. '"' .. line .. '"' .. "\n"
    else
      line = string.gsub(line, [["]], [[\"]])
      local newline = nil
      if i < #parts then
        newline = [[\n]]
      end
      result = result .. string.format('"%s%s"', line, newline or '')
      if newline then
        result = result .. "\n"
      end
    end
  end

  --- magic replace (hack) ----
  result = result:gsub([["\"\"]], [["\"]])
  -----------------------------
  return result
end

---@param container RawDataContainer
---@return string
local function extract_key(container)
  container:skip_spaces()
  local result = ''
  while 1 do
    local c = container:get_char()
    assert(c, "extract key error")
    if c:match('[a-zA-Z0-9_]+') then
      result = result .. c
    else
      container:back()
      return result
    end
  end
end

---@param container RawDataContainer
---@return string|number|any
local function extract_scalar(container)
  container:skip_spaces()
  local result = ''
  local c = container:get_char()
  if c == '"' then -- parse text (oneline/multiline)
    while 1 do
      c = container:get_char()
      -- if c == nil then return decode_text_field(result) end
      if c == '"' and not skip_quote then
        container:skip_spaces()
        if container:get_char() ~= '"' then
          container:back()
          return decode_text_field(result)
        end
        result = result .. '""'
      else
        skip_quote = false
        if c == "\\" then skip_quote = true end
        result = result .. c
      end
    end
  else -- parse const/number/bool values
    container:back()
    while 1 do
      c = container:get_char()
      if c ~= " " and c ~= nil then
        result = result .. c
      else
        if result:match("^[0-9\\.-]+$") then return tonumber(result) end
        if result == "false" then return false end
        if result == "true" then return true end
        return result
      end
    end
  end
end

---@param container RawDataContainer
---@return string|table|number
local function extract_value(container)
  container:skip_spaces()
  local c = container:get_char()
  if c == ':' then return extract_scalar(container) end
  if c == '{' then return extract_dict(container) end
  error("file format error")
end

---@param container RawDataContainer
---@return table
extract_dict = function(container)
  container:skip_spaces()
  local result = sorted_table()
  while 1 do
    if container:get_char() == nil then
      return {}
    end
    container:back()
    local key = extract_key(container)
    local value = extract_value(container)

    if key == 'data' then
      if type(value) == 'string' then
        local container_2 = make_container(tostring(value))
        value = extract_dict(container_2)
      end
    end
    if result[key] ~= nil then
      if not is_array(result[key]) then
        result[key] = { result[key] }
      end
      table.insert(result[key], value)
    else
      result[key] = value
    end
    container:skip_spaces()
    local char = container:get_char()
    if char == "}" or char == nil then
      return result
    else
      container:back()
    end
  end
end

-----------------------------------
--Convert lua table to string(in defold file format)
---@param level number
---@param tbl table
---@return string
compile = function(tbl, level)
  local result = ''

  for key, value in pairs(tbl) do
    if is_array(value) then
      for _, v in ipairs(value) do
        if type(v) == 'string' then
          result = result .. tab:rep(level) .. key .. ': ' .. encode_text_field(v) .. "\n"
        elseif type(v) == 'number' then
          result = result .. tab:rep(level) .. key .. ': ' .. tostring(v) .. "\n"
        else
          result = result .. tab:rep(level) .. key .. " {\n"
          result = result .. compile(v, level + 1)
          result = result .. tab:rep(level) .. "}\n"
        end
      end
    else
      if type(value) == 'table' then
        if key == "data" then
          result = result .. tab:rep(level) .. key .. ": "
          local d = encode_text_field(compile(value, 0))
          d = d:gsub("\n", "\n" .. tab:rep(level))
          -- magic replace (hack) --
          d = d:gsub([[  "  \"]], [[  "]])
          --------------------------
          result = result .. d .. "\n"
        else
          result = result .. tab:rep(level) .. key .. " {\n"
          result = result .. compile(value, level + 1)
          result = result .. tab:rep(level) .. "}\n"
        end
      else
        if type(value) == 'string' then
          if key == "text" or value:upper() ~= value or value == '' then -- if not const
            value = encode_text_field(value)
            value = value:gsub("\n", "\n" .. tab:rep(level))
          end
        elseif type(value) == 'number' then
          value = tostring(value)
        elseif type(value) == 'boolean' then
          value = tostring(value)
        end
        result = result .. tab:rep(level) .. key .. ': ' .. value .. "\n"
      end
    end
  end
  return result
end

return {
  table = sorted_table,
  --Convert string(in defold file format) to table
  ---@param str string
  ---@return table
  parse = function(str)
    return extract_dict(make_container(str))
  end,
  ---Convert table to string(defold file format)
  ---@param tbl table
  ---@return string
  compile = function(tbl)
    return compile(tbl, 0)
  end,
  ---Compile table and save to file
  ---@param path string
  ---@param tbl table
  save = function(path, tbl)
    local f = io.open(path, 'w')
    assert(f, ("file write error to %s"):format(path))
    f:write(compile(tbl, 0))
    f:close()
  end,
  ---Parse defold file and return table
  ---@meta
  ---@param path string
  load = function(path)
    local f = io.open(path, 'r')
    local rows = {}
    assert(f, ("read file error: %s"):format(path))
    for v in f:lines() do if v then table.insert(rows, trim(v)) end end
    f:close()
    local c = make_container(table.concat(rows, "\n"))
    return extract_dict(c)
  end
}
