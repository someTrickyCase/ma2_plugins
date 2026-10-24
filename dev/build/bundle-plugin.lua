package.path = "./?.lua;" .. package.path

local bundle = require("dev.build.bundler")

local pluginName, outFolder, commit, date, slot = table.unpack(arg)

local function readFile(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local text = file:read("a")
  file:close()
  return text
end

local function writeFile(path, text)
  local file = assert(io.open(path, "wb"))
  file:write(text)
  file:close()
end

local stamp = { commit = commit, date = date }
local parts = bundle.collect(pluginName, readFile, stamp)
local base = outFolder .. "/" .. parts.file
local target = slot and math.tointeger(tonumber(slot))
local instructions = bundle.instructions(parts, target)

writeFile(base .. ".lua", bundle.lua(parts))
writeFile(base .. ".xml", bundle.xml(parts))
print(base .. ".lua")
print(base .. ".xml")
for _, line in ipairs(instructions) do
  print(line)
end
