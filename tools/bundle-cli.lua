package.path = "./?.lua;" .. package.path

local bundle = require("tools.bundle")

local pluginName, outFolder, commit, date = table.unpack(arg)

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

writeFile(base .. ".lua", bundle.lua(parts))
writeFile(base .. ".xml", bundle.xml(parts))
print(base .. ".lua")
print(base .. ".xml")
