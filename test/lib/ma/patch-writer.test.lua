local lu = require("luaunit")
local fakeGma = require("test.support.fake-gma")
local swapIds = require("core.swap-ids")
local patchWriter = require("ma.patch-writer")

local LAYERS = 'cd /; cd "EditSetup"; cd "Layers"; '

local function fren(options)
  options.layers = {
    { name = "hazer", fixtures = { { name = "HZ-1000 1", chaId = "901" } } },
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

local dim2 = { name = "Dim 2", layer = "fren", chaId = 802 }

local function set(fixture, field, value)
  return { action = "set", fixture = fixture, field = field, value = value }
end

local function clear(fixture, field)
  return { action = "clear", fixture = fixture, field = field }
end

local function noProgress() end

local tests = {}

function tests.testSendsAssignInTheFixturesLayerThenCommits()
  local fake = fren({})
  patchWriter.apply(fake.gma, { set(dim2, "fixId", 802) }, noProgress)
  lu.assertEquals(fake.commands, {
    LAYERS .. "cd 2; assign 2 /FixId=802",
    "cd /",
  })
end

function tests.testClearSendsEmptyValue()
  local fake = fren({})
  local steps = { set(dim2, "fixId", 802), clear(dim2, "chaId") }
  patchWriter.apply(fake.gma, steps, noProgress)
  lu.assertEquals(fake.commands[3], LAYERS .. "cd 2; assign 2 /ChaId=")
end

function tests.testMovesTheIdInThePatch()
  local fake = fren({})
  local steps = { set(dim2, "fixId", 802), clear(dim2, "chaId") }
  lu.assertTrue(patchWriter.apply(fake.gma, steps, noProgress))
  lu.assertEquals(fake.propsAt(2, 2), {
    Name = "Dim 2",
    FixId = "802",
    ChaId = "-",
  })
end

function tests.testFollowsFixtureThroughAllThreePhases()
  local fake = fakeGma.new({
    layers = {
      {
        name = "pars",
        fixtures = {
          { name = "A", chaId = "5", fixId = "7" },
          { name = "B", chaId = "7" },
        },
      },
    },
  })
  local a = { name = "A", layer = "pars", chaId = 5, fixId = 7 }
  local b = { name = "B", layer = "pars", chaId = 7 }
  local plan = swapIds.plan({ a, b }, "chaId", "fixId")
  lu.assertTrue(patchWriter.apply(fake.gma, plan.steps, noProgress))
  lu.assertEquals(fake.propsAt(1, 1), { Name = "A", FixId = "5", ChaId = "-" })
  lu.assertEquals(fake.propsAt(1, 2), { Name = "B", FixId = "7", ChaId = "-" })
end

function tests.testReportsProgressAfterEachStep()
  local fake = fren({})
  local calls = {}
  local steps = { set(dim2, "fixId", 802), clear(dim2, "chaId") }
  patchWriter.apply(fake.gma, steps, function(done, total)
    calls[#calls + 1] = { done, total }
  end)
  lu.assertEquals(calls, { { 1, 2 }, { 2, 2 } })
end

function tests.testStopsWhenFixtureCannotBeFound()
  local fake = fren({})
  local ghost = { name = "Ghost", layer = "fren", chaId = 999 }
  local ok, problem =
    patchWriter.apply(fake.gma, { set(ghost, "fixId", 999) }, noProgress)
  lu.assertNil(ok)
  lu.assertEquals(
    problem,
    "Step 1 of 1 failed: set FixId=999 on Ghost (fren): "
      .. "cannot find it as Channel 999"
  )
  lu.assertEquals(fake.commands, {})
end

function tests.testStopsWhenIdBelongsToAnotherFixture()
  local fake = fren({})
  local wrong = { name = "Dim 9", layer = "fren", chaId = 802 }
  local _, problem =
    patchWriter.apply(fake.gma, { set(wrong, "fixId", 802) }, noProgress)
  lu.assertEquals(
    problem,
    "Step 1 of 1 failed: set FixId=802 on Dim 9 (fren): "
      .. "Channel 802 is Dim 2"
  )
end

function tests.testStopsWhenMaIgnoresTheCommand()
  local fake = fren({ ignoreAssign = true })
  local steps = { set(dim2, "fixId", 802), clear(dim2, "chaId") }
  local ok, problem = patchWriter.apply(fake.gma, steps, noProgress)
  lu.assertNil(ok)
  lu.assertEquals(
    problem,
    "Step 1 of 2 failed: set FixId=802 on Dim 2 (fren): "
      .. "cannot find it as Fixture 802"
  )
  lu.assertEquals(#fake.commands, 2)
end

function tests.testStopsOnCommandErrorAndStillCommits()
  local fake = fren({ failWith = "Error #72: COMMAND NOT EXECUTED" })
  local _, problem =
    patchWriter.apply(fake.gma, { set(dim2, "fixId", 802) }, noProgress)
  lu.assertEquals(
    problem,
    "Step 1 of 1 failed: set FixId=802 on Dim 2 (fren): "
      .. "Error #72: COMMAND NOT EXECUTED"
  )
  lu.assertEquals(fake.lastCommand(), "cd /")
end

function tests.testNamesClearStepsInProblems()
  local fake = fren({ ignoreAssign = true })
  local dim1 = { name = "Dim 1", layer = "fren", chaId = 801, fixId = 5 }
  local _, problem =
    patchWriter.apply(fake.gma, { clear(dim1, "fixId") }, noProgress)
  lu.assertStrContains(problem, "clear FixId on Dim 1 (fren)")
end

return tests
