local lu = require("luaunit")
local report = require("core.report")

local wash = { name = "MQuaWBa 1", layer = "tr_washes" }
local par = { name = "sirius", layer = "pars" }
local lipar = { name = "LP1895 1", layer = "tr_pars" }
local profile = { name = "Eclipse 750 HD 1", layer = "led Profiles" }

local function steps(...)
  local list = {}
  for _, action in ipairs({ ... }) do
    list[#list + 1] = { action = action }
  end
  return { steps = list, conflicts = {} }
end

local tests = {}

function tests.testOneConflictIsSingular()
  local conflicts = { { id = 101, fixtures = { wash, par } } }
  lu.assertEquals(report.conflicts(conflicts, "fixId"), {
    "Cannot move: 1 conflict. Nothing was changed.",
    "Fixture ID 101: MQuaWBa 1 (tr_washes), sirius (pars)",
  })
end

function tests.testListsEveryConflict()
  local conflicts = {
    { id = 101, fixtures = { wash, par } },
    { id = 301, fixtures = { lipar, profile } },
  }
  lu.assertEquals(report.conflicts(conflicts, "fixId"), {
    "Cannot move: 2 conflicts. Nothing was changed.",
    "Fixture ID 101: MQuaWBa 1 (tr_washes), sirius (pars)",
    "Fixture ID 301: LP1895 1 (tr_pars), Eclipse 750 HD 1 (led Profiles)",
  })
end

function tests.testNamesChannelIdInReverseDirection()
  local conflicts = { { id = 202, fixtures = { wash, par } } }
  lu.assertEquals(
    report.conflicts(conflicts, "chaId")[2],
    "Channel ID 202: MQuaWBa 1 (tr_washes), sirius (pars)"
  )
end

function tests.testQuestionCountsFixturesNotSteps()
  local plan = steps("clear", "set", "clear")
  lu.assertEquals(
    report.question(plan, "chaId", "fixId"),
    "Move 1 fixture from Channel ID to Fixture ID?"
  )
end

function tests.testQuestionUsesPluralForManyFixtures()
  local plan = steps("set", "set", "clear", "clear")
  lu.assertEquals(
    report.question(plan, "fixId", "chaId"),
    "Move 2 fixtures from Fixture ID to Channel ID?"
  )
end

function tests.testDoneNamesCountAndDirection()
  local plan = steps("set", "set", "set", "clear", "clear", "clear")
  lu.assertEquals(
    report.done(plan, "chaId", "fixId"),
    "Done: 3 fixtures moved from Channel ID to Fixture ID."
  )
end

function tests.testNothingToDoNamesTheMissingId()
  lu.assertEquals(
    report.nothingToDo("chaId"),
    "Nothing to move: no fixture has a Channel ID."
  )
end

return tests
