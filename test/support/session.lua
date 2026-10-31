local bundle = require("dev.build.bundler")
local fakeGma = require("test.support.fake-gma")

local STAMP = { commit = "abc1234", date = "2026-10-24" }

local function readRealFile(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local text = file:read("a")
  file:close()
  return text
end

local function run(pluginName, options)
  local parts = bundle.collect(pluginName, readRealFile, STAMP)
  local fake = fakeGma.new(options)
  local environment = {
    gma = fake.gma,
    require = function(name)
      error("real require used for " .. name)
    end,
  }
  setmetatable(environment, { __index = _G })
  local chunk = assert(load(bundle.lua(parts), "=bundle", "t", environment))
  local start = chunk("plugin_1", parts.name)
  start()
  return fake
end

return { run = run }
