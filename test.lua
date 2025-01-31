#!/usr/bin/env lua
local parser = require "defold_parser"

local function get_file_content(name)
  local file = io.open(name, "rb")
  assert(file, "read file error")
  return file:read("a*")
end

local function test_file(path)
  local data = parser.load(path)
  assert(get_file_content(path) == parser.compile(data), (" ❌ Test error: %s"):format(path))
  print((" ✅ Test passed: file %s"):format(path))
end

-- DEBUG FUNCTIONS
-- dump = function(value, level)
--   local do_print
--   if level == nil then do_print = true end
--   level = level or 0
--   local tab = "  "
--   local result = ''
--   if type(value) == 'table' then
--     result = result .. "{\n"
--     for k, v in pairs(value) do
--       result = result .. string.format('%s%s = %s\n', tab:rep(level + 1), k, dump(v, level + 1))
--     end
--     result = result .. tab:rep(level) .. "}"
--   else
--     result = value
--   end
--   if do_print then
--     print(dump(value, 0))
--   end
--   return result
-- end
--
-- local function dump_file(path)
--   local parsed = parser.load(path)
--   print("-----------------\n     parsed \n-----------------")
--   dump(parsed)
--   print("--------------------\n     compiled\n--------------------")
--   -- dump(parser.compile(parsed))
--   -- -------------------
--   -- parser.save('tests/debug', parsed)
--   -------------------
-- end
--

--- TESTS ---
test_file("tests/font.font")
test_file("tests/atlas.atlas")
test_file("tests/particlefx.particlefx")
test_file("tests/collection.collection")
test_file("tests/go.go")
test_file("tests/collection_several_embedded.collection")
test_file("tests/collection_with_label.collection")
test_file("tests/full_go.go")
test_file("tests/collision_go.go")
test_file("tests/gui.gui")
