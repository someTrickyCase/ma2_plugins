local lu = require("luaunit")
local fakeGma = require("test.support.fake-gma")

local MAIN = "plugins/fixture-to-channel/main.lua"

local function loadPlugin(fake)
  local environment = setmetatable({ gma = fake.gma }, { __index = _G })
  local chunk = assert(loadfile(MAIN, "t", environment))
  return chunk("plugin_2", "Fixture to Channel")
end

local function washShow()
  return fakeGma.new({
    layers = {
      { name = "tr_washes", fixtures = { { name = "wash 1", fixId = "103" } } },
    },
  })
end

local tests = {}

function tests.testReturnsStartAndCleanup()
  local start, cleanup = loadPlugin(washShow())
  lu.assertIsFunction(start)
  lu.assertIsFunction(cleanup)
end

function tests.testStartMovesFixtureIdsToChannelIds()
  local fake = washShow()
  local start = loadPlugin(fake)
  start()
  lu.assertEquals(fake.propsAt(1, 1), {
    Name = "wash 1",
    FixId = "-",
    ChaId = "103",
  })
end

function tests.testAsksWithItsOwnTitleAndDirection()
  local fake = washShow()
  local start = loadPlugin(fake)
  start()
  lu.assertEquals(fake.questions, {
    {
      title = "Fixture to Channel",
      text = "Move 1 fixture from Fixture ID to Channel ID?",
    },
  })
end

function tests.testLoadingDoesNotTouchTheShow()
  local fake = washShow()
  loadPlugin(fake)
  lu.assertEquals(fake.commands, {})
end

return tests
