local fakeGma = require("test.support.fake-gma")

local BUNDLE_FOLDER = "test/bundles"

local function run(bundleFile, options)
  local fake = fakeGma.new(options)
  local environment = {
    gma = fake.gma,
    require = function(name)
      error("real require used for " .. name)
    end,
  }
  setmetatable(environment, { __index = _G })
  local path = BUNDLE_FOLDER .. "/" .. bundleFile
  local chunk = assert(loadfile(path, "t", environment))
  local start = chunk("plugin_1", "Plugin")
  start()
  return fake
end

return { run = run }
