local lu = require("luaunit")
local fakeGma = require("test.support.fake-gma")
local conflictGroup = require("ma.conflict-group")

local DIM = { name = "Dim 1", layer = "fren", fixId = 1001 }
local PAR = { name = "Par 1", layer = "fren", chaId = 28 }

local function show(options)
  options.layers = {
    {
      name = "fren",
      fixtures = {
        { name = "Dim 1", fixId = "1001" },
        { name = "Par 1", chaId = "28" },
      },
    },
  }
  return fakeGma.new(options)
end

local tests = {}

function tests.testStoresGroupAndLayoutFromSelection()
  local fake = show({})
  local result = conflictGroup.create(fake.gma, { DIM, PAR })
  lu.assertEquals(result, { group = 1, layout = 1 })
  lu.assertEquals(fake.commands, {
    "ClearSelection",
    "Fixture 1001",
    "Channel 28",
    'Store Group 1 "Conflicts" /nc',
    'Store Layout 1 "Conflicts" /nc',
    "Assign Group 1 Layout 1",
    "ClearSelection",
    "Group 1",
    "ClearSelection",
  })
end

function tests.testGroupAndLayoutHoldTheFixtures()
  local fake = show({})
  conflictGroup.create(fake.gma, { DIM, PAR })
  lu.assertEquals(fake.poolMembers("Group", 1), { "Dim 1", "Par 1" })
  lu.assertEquals(fake.poolMembers("Layout", 1), { "Dim 1", "Par 1" })
end

function tests.testTakesFirstFreeNumbers()
  local fake = show({ groups = { 1, 2, 4 }, layouts = { 1 } })
  local result = conflictGroup.create(fake.gma, { DIM })
  lu.assertEquals(result, { group = 3, layout = 2 })
end

function tests.testMissingFixtureStopsBeforeAnyCommand()
  local fake = show({})
  local ghost = { name = "Ghost", layer = "fren", fixId = 777 }
  local result, problem = conflictGroup.create(fake.gma, { DIM, ghost })
  lu.assertNil(result)
  lu.assertStrContains(problem, "Fixture 777")
  lu.assertEquals(fake.commands, {})
end

function tests.testCommandErrorStops()
  local fake = show({ failWith = "UNKNOWN COMMAND" })
  local result, problem = conflictGroup.create(fake.gma, { DIM })
  lu.assertNil(result)
  lu.assertStrContains(problem, "ClearSelection")
  lu.assertStrContains(problem, "UNKNOWN COMMAND")
  lu.assertEquals(#fake.commands, 1)
end

function tests.testEmptySelectionStops()
  local fake = show({ selectNothing = true })
  local result, problem = conflictGroup.create(fake.gma, { DIM })
  lu.assertNil(result)
  lu.assertStrContains(problem, "selected nothing")
end

function tests.testGroupThatWasNotCreatedStops()
  local fake = show({ storeIgnored = true })
  local result, problem = conflictGroup.create(fake.gma, { DIM })
  lu.assertNil(result)
  lu.assertStrContains(problem, "Group 1")
end

function tests.testGroupWithWrongContentStops()
  local fake = show({ groupLosesOne = true })
  local result, problem = conflictGroup.create(fake.gma, { DIM, PAR })
  lu.assertNil(result)
  lu.assertStrContains(problem, "Group 1 holds 1 of 2")
  lu.assertEquals(fake.lastCommand(), "ClearSelection")
end

return tests
