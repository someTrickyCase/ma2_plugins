local lu = require("luaunit")
local session = require("test.support.session")

local function oneFixture()
  return {
    layers = {
      { name = "fren", fixtures = { { name = "Dim 1", chaId = "801" } } },
    },
  }
end

local function twoWantingTheSameId()
  return {
    layers = {
      {
        name = "fren",
        fixtures = {
          { name = "Dim 1", chaId = "801" },
          { name = "Dim 2", chaId = "801" },
        },
      },
    },
  }
end

local tests = {}

function tests.testReadsThePatchSetsTheIdAndClearsTheOldOne()
  local fake = session.run("channel-to-fixture", oneFixture())

  lu.assertEquals(fake.commands, {
    'cd /; cd "EditSetup"; cd "Layers"',
    "cd /",
    'cd /; cd "EditSetup"; cd "Layers"; cd 1; assign 1 /FixId=801',
    "cd /",
    'cd /; cd "EditSetup"; cd "Layers"; cd 1; assign 1 /ChaId=',
    "cd /",
  })
end

function tests.testAsksBeforeItMovesAnything()
  local fake = session.run("channel-to-fixture", oneFixture())

  lu.assertEquals(fake.questions, {
    {
      title = "Channel to Fixture",
      text = "Move 1 fixture from Channel ID to Fixture ID?",
    },
  })
end

function tests.testConflictStoresAGroupAndALayoutAndChangesNoId()
  local fake = session.run("channel-to-fixture", twoWantingTheSameId())

  lu.assertEquals(fake.commands, {
    'cd /; cd "EditSetup"; cd "Layers"',
    "cd /",
    "ClearSelection",
    "Channel 801",
    "Channel 801",
    'Store Group 1 "Conflicts" /nc',
    'Store Layout 1 "Conflicts" /nc',
    "Assign Group 1 Layout 1",
    "ClearSelection",
    "Group 1",
    "ClearSelection",
  })

  lu.assertEquals(fake.propsAt(1, 1).FixId, "-")
  lu.assertEquals(fake.propsAt(1, 1).ChaId, "801")
end

return tests
