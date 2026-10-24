local lu = require("luaunit")
local fakeGma = require("test.support.fake-gma")
local swapFlow = require("ma.swap-flow")

local TITLE = "Channel to Fixture"

local function fakeShow(options, layers)
  options.layers = layers
    or {
      {
        name = "fren",
        fixtures = {
          { name = "Dim 1", chaId = "801" },
          { name = "Dim 2", chaId = "802" },
        },
      },
    }
  return fakeGma.new(options)
end

local function conflictingShow(options)
  return fakeShow(options, {
    {
      name = "tr_washes",
      fixtures = { { name = "MQuaWBa 1", fixId = "101" } },
    },
    { name = "pars", fixtures = { { name = "sirius", chaId = "101" } } },
  })
end

local function runFlow(fake)
  local flow =
    swapFlow.new(fake.gma, { title = TITLE, from = "chaId", to = "fixId" })
  flow.start()
  return flow
end

local function assignCount(fake)
  local count = 0
  for _, command in ipairs(fake.commands) do
    if command:find("assign", 1, true) then
      count = count + 1
    end
  end
  return count
end

local tests = {}

function tests.testAsksBeforeChanging()
  local fake = fakeShow({})
  runFlow(fake)
  lu.assertEquals(fake.questions, {
    { title = TITLE, text = "Move 2 fixtures from Channel ID to Fixture ID?" },
  })
end

function tests.testMovesIdsAndSaysDone()
  local fake = fakeShow({})
  runFlow(fake)
  lu.assertEquals(fake.propsAt(1, 2), {
    Name = "Dim 2",
    FixId = "802",
    ChaId = "-",
  })
  lu.assertEquals(fake.messages, {
    {
      title = TITLE,
      text = "Done: 2 fixtures moved from Channel ID to Fixture ID.",
    },
  })
end

function tests.testCancelChangesNothing()
  local fake = fakeShow({ confirm = false })
  runFlow(fake)
  lu.assertEquals(assignCount(fake), 0)
  lu.assertEquals(fake.messages, {})
  lu.assertEquals(fake.echoes, {
    TITLE .. ": Cancelled. Nothing was changed.",
  })
end

function tests.testShowsConflictsWithoutAsking()
  local fake = conflictingShow({})
  runFlow(fake)
  lu.assertEquals(fake.questions, {})
  lu.assertEquals(assignCount(fake), 0)
  lu.assertEquals(
    fake.messages[1].text,
    table.concat({
      "Cannot move: 1 conflict. Nothing was changed.",
      "Fixture ID 101: MQuaWBa 1 (tr_washes), sirius (pars)",
    }, "|")
  )
end

function tests.testEchoesEveryLineToSystemMonitor()
  local fake = conflictingShow({})
  runFlow(fake)
  lu.assertEquals(fake.echoes, {
    TITLE .. ": Cannot move: 1 conflict. Nothing was changed.",
    TITLE .. ": Fixture ID 101: MQuaWBa 1 (tr_washes), sirius (pars)",
  })
end

function tests.testSaysWhenNothingToMove()
  local fake = fakeShow({}, {
    {
      name = "tr_washes",
      fixtures = { { name = "MQuaWBa 1", fixId = "101" } },
    },
  })
  runFlow(fake)
  lu.assertEquals(fake.questions, {})
  lu.assertEquals(
    fake.messages[1].text,
    "Nothing to move: no fixture has a Channel ID."
  )
end

function tests.testShowsReadProblem()
  local fake = fakeShow({ cdLandsNowhere = true })
  runFlow(fake)
  lu.assertEquals(
    fake.messages[1].text,
    "cannot open the patch: landed in CMD_ROOT"
  )
end

function tests.testShowsWriteProblemAndStopsProgress()
  local fake = fakeShow({ ignoreAssign = true })
  runFlow(fake)
  lu.assertStrContains(fake.messages[1].text, "Step 1 of 4 failed")
  lu.assertEquals(fake.progress[#fake.progress], "stop")
end

function tests.testShowsProgressWhileApplying()
  local fake = fakeShow({})
  runFlow(fake)
  lu.assertEquals(fake.progress, {
    "start " .. TITLE,
    "range 0 4",
    "text Step 1 of 4",
    "set 1",
    "text Step 2 of 4",
    "set 2",
    "text Step 3 of 4",
    "set 3",
    "text Step 4 of 4",
    "set 4",
    "stop",
  })
end

function tests.testCleanupClosesProgressWhenPluginIsStopped()
  local flow
  local fake = fakeShow({
    onSleep = function()
      flow.cleanup()
      error("plugin stopped")
    end,
  })
  flow = swapFlow.new(fake.gma, { title = TITLE, from = "chaId", to = "fixId" })
  lu.assertFalse(pcall(flow.start))
  lu.assertEquals(fake.progress[#fake.progress], "stop")
end

function tests.testCleanupWhenIdleDoesNothing()
  local fake = fakeShow({})
  local flow =
    swapFlow.new(fake.gma, { title = TITLE, from = "chaId", to = "fixId" })
  flow.cleanup()
  lu.assertEquals(fake.progress, {})
end

return tests
