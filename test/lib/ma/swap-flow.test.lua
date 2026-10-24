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

local function mixedShow(options)
  return fakeShow(options, {
    {
      name = "tr_washes",
      fixtures = { { name = "MQuaWBa 1", fixId = "101" } },
    },
    {
      name = "pars",
      fixtures = {
        { name = "sirius", chaId = "101" },
        { name = "Dim 1", chaId = "801" },
      },
    },
  })
end

local CONFLICT_LINE = "Fixture ID 101: MQuaWBa 1 (tr_washes), sirius (pars)"
local POOLS_LINE = 'Group 1 and Layout 1 "Conflicts"'

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
    TITLE .. ": Cancelled. No ID was changed.",
  })
end

function tests.testOnlyConflictsShowsGroupWithoutAsking()
  local fake = conflictingShow({})
  runFlow(fake)
  lu.assertEquals(fake.questions, {})
  lu.assertEquals(assignCount(fake), 0)
  lu.assertEquals(fake.poolMembers("Group", 1), { "MQuaWBa 1", "sirius" })
  lu.assertEquals(
    fake.messages[1].text,
    table.concat({
      "Cannot move: 1 conflict. No ID was changed.",
      "See " .. POOLS_LINE .. ".",
      CONFLICT_LINE,
    }, "|")
  )
end

function tests.testEchoesEveryLineToSystemMonitor()
  local fake = conflictingShow({})
  runFlow(fake)
  lu.assertEquals(fake.echoes, {
    TITLE .. ": Cannot move: 1 conflict. No ID was changed.",
    TITLE .. ": See " .. POOLS_LINE .. ".",
    TITLE .. ": " .. CONFLICT_LINE,
  })
end

function tests.testConflictsAskToMoveTheOthers()
  local fake = mixedShow({})
  runFlow(fake)
  lu.assertEquals(fake.questions, {
    {
      title = TITLE,
      text = table.concat({
        "1 conflict: see " .. POOLS_LINE .. ".",
        "Move the other 1 fixture from Channel ID to Fixture ID?",
      }, "|"),
    },
  })
  lu.assertEquals(fake.echoes[1], TITLE .. ": " .. CONFLICT_LINE)
end

function tests.testOkMovesOnlyFixturesWithoutConflict()
  local fake = mixedShow({})
  runFlow(fake)
  lu.assertEquals(fake.propsAt(2, 1).ChaId, "101")
  lu.assertEquals(fake.propsAt(2, 2), {
    Name = "Dim 1",
    FixId = "801",
    ChaId = "-",
  })
  lu.assertEquals(
    fake.messages[1].text,
    table.concat({
      "Done: 1 fixture moved from Channel ID to Fixture ID.",
      "Skipped 2 fixtures: see " .. POOLS_LINE .. ".",
    }, "|")
  )
end

function tests.testCancelAfterConflictsKeepsGroupAndIds()
  local fake = mixedShow({ confirm = false })
  runFlow(fake)
  lu.assertEquals(assignCount(fake), 0)
  lu.assertEquals(fake.poolMembers("Group", 1), { "MQuaWBa 1", "sirius" })
  lu.assertEquals(
    fake.echoes[#fake.echoes],
    TITLE .. ": Cancelled. No ID was changed."
  )
end

function tests.testGroupProblemStopsBeforeAsking()
  local fake = mixedShow({ storeIgnored = true })
  runFlow(fake)
  lu.assertEquals(fake.questions, {})
  lu.assertEquals(assignCount(fake), 0)
  lu.assertStrContains(fake.messages[1].text, "Group 1 Conflicts")
  lu.assertStrContains(fake.messages[1].text, "No ID was changed.")
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
