local lu = require("luaunit")
local fakeGma = require("test.support.fake-gma")
local patchReader = require("ma.patch-reader")

local function showWithFrenAndWashes()
  return fakeGma.new({
    layers = {
      {
        name = "fren",
        fixtures = {
          { name = "Dim 1", chaId = "801" },
          { name = "Dim 2", chaId = "802" },
        },
      },
      {
        name = "tr_washes",
        fixtures = { { name = "MQuaWBa 1", fixId = "101" } },
      },
    },
  })
end

local tests = {}

function tests.testReadsFixturesOfAllLayers()
  local fake = showWithFrenAndWashes()
  lu.assertEquals(patchReader.read(fake.gma), {
    { name = "Dim 1", layer = "fren", fixId = nil, chaId = 801 },
    { name = "Dim 2", layer = "fren", fixId = nil, chaId = 802 },
    { name = "MQuaWBa 1", layer = "tr_washes", fixId = 101, chaId = nil },
  })
end

function tests.testReadsBothIdsOfOneFixture()
  local fake = fakeGma.new({
    layers = {
      {
        name = "pars",
        fixtures = { { name = "A", chaId = "5", fixId = "7" } },
      },
    },
  })
  lu.assertEquals(patchReader.read(fake.gma), {
    { name = "A", layer = "pars", fixId = 7, chaId = 5 },
  })
end

function tests.testReadsIdsAsIntegers()
  local fake = showWithFrenAndWashes()
  local fixtures = patchReader.read(fake.gma)
  lu.assertEquals(math.type(fixtures[1].chaId), "integer")
end

function tests.testEmptyPatchGivesNoFixtures()
  local fake = fakeGma.new({ layers = {} })
  lu.assertEquals(patchReader.read(fake.gma), {})
end

function tests.testSkipsEmptyLayer()
  local fake = fakeGma.new({
    layers = {
      { name = "empty", fixtures = {} },
      { name = "hazer", fixtures = { { name = "HZ-1000 1", chaId = "901" } } },
    },
  })
  lu.assertEquals(patchReader.read(fake.gma), {
    { name = "HZ-1000 1", layer = "hazer", fixId = nil, chaId = 901 },
  })
end

function tests.testOpensLayersFromTheRoot()
  local fake = showWithFrenAndWashes()
  patchReader.read(fake.gma)
  lu.assertEquals(fake.commands[1], 'cd /; cd "EditSetup"; cd "Layers"')
end

function tests.testLeavesCommandLineAtRoot()
  local fake = showWithFrenAndWashes()
  patchReader.read(fake.gma)
  lu.assertEquals(fake.lastCommand(), "cd /")
end

function tests.testReportsCommandError()
  local fake = fakeGma.new({ failWith = "Error #72: COMMAND NOT EXECUTED" })
  local fixtures, problem = patchReader.read(fake.gma)
  lu.assertNil(fixtures)
  lu.assertEquals(
    problem,
    "cannot open the patch: Error #72: COMMAND NOT EXECUTED"
  )
end

function tests.testReportsWrongDestination()
  local fake = fakeGma.new({ layers = {}, cdLandsNowhere = true })
  local fixtures, problem = patchReader.read(fake.gma)
  lu.assertNil(fixtures)
  lu.assertEquals(problem, "cannot open the patch: landed in CMD_ROOT")
end

function tests.testLeavesCommandLineAtRootAfterProblem()
  local fake = fakeGma.new({ layers = {}, cdLandsNowhere = true })
  patchReader.read(fake.gma)
  lu.assertEquals(fake.lastCommand(), "cd /")
end

return tests
