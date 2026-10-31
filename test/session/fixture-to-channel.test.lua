local lu = require("luaunit")
local session = require("test.support.session")

local function oneFixture()
  return {
    layers = {
      { name = "fren", fixtures = { { name = "Dim 1", fixId = "801" } } },
    },
  }
end

local tests = {}

function tests.testReadsThePatchSetsTheIdAndClearsTheOldOne()
  local fake = session.run("fixture-to-channel", oneFixture())

  lu.assertEquals(fake.commands, {
    'cd /; cd "EditSetup"; cd "Layers"',
    "cd /",
    'cd /; cd "EditSetup"; cd "Layers"; cd 1; assign 1 /ChaId=801',
    "cd /",
    'cd /; cd "EditSetup"; cd "Layers"; cd 1; assign 1 /FixId=',
    "cd /",
  })
end

function tests.testAsksBeforeItMovesAnything()
  local fake = session.run("fixture-to-channel", oneFixture())

  lu.assertEquals(fake.questions, {
    {
      title = "Fixture to Channel",
      text = "Move 1 fixture from Fixture ID to Channel ID?",
    },
  })
end

return tests
