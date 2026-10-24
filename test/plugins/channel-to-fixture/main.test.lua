local lu = require("luaunit")
local fakeGma = require("test.support.fake-gma")

local MAIN = "plugins/channel-to-fixture/main.lua"

local function loadPlugin(fake)
  local environment = setmetatable({ gma = fake.gma }, { __index = _G })
  local chunk = assert(loadfile(MAIN, "t", environment))
  return chunk("plugin_1", "Channel to Fixture")
end

local function frenShow()
  return fakeGma.new({
    layers = {
      { name = "fren", fixtures = { { name = "Dim 1", chaId = "801" } } },
    },
  })
end

local tests = {}

function tests.testReturnsStartAndCleanup()
  local start, cleanup = loadPlugin(frenShow())
  lu.assertIsFunction(start)
  lu.assertIsFunction(cleanup)
end

function tests.testStartMovesChannelIdsToFixtureIds()
  local fake = frenShow()
  local start = loadPlugin(fake)
  start()
  lu.assertEquals(fake.propsAt(1, 1), {
    Name = "Dim 1",
    FixId = "801",
    ChaId = "-",
  })
end

function tests.testLoadingDoesNotTouchTheShow()
  local fake = frenShow()
  loadPlugin(fake)
  lu.assertEquals(fake.commands, {})
end

return tests
