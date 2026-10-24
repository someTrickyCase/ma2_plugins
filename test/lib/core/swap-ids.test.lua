local lu = require("luaunit")
local swapIds = require("core.swap-ids")

local function fixture(name, chaId, fixId)
  return { name = name, chaId = chaId, fixId = fixId }
end

local function set(target, field, value)
  return { action = "set", fixture = target, field = field, value = value }
end

local function clear(target, field)
  return { action = "clear", fixture = target, field = field }
end

local function channelToFixture(fixtures)
  return swapIds.plan(fixtures, "chaId", "fixId")
end

local tests = {}

function tests.testEmptyPatchNeedsNoSteps()
  lu.assertEquals(channelToFixture({}), { steps = {}, conflicts = {} })
end

function tests.testMovesChannelIdToFixtureId()
  local dim = fixture("Dim 1", 5, nil)
  lu.assertEquals(channelToFixture({ dim }).steps, {
    set(dim, "fixId", 5),
    clear(dim, "chaId"),
  })
end

function tests.testSkipsFixtureWithoutChannelId()
  local wash = fixture("Wash 1", nil, 101)
  lu.assertEquals(channelToFixture({ wash }).steps, {})
end

function tests.testSkipsFixtureWithoutAnyId()
  local preset = fixture("[Preset] Dim", nil, nil)
  lu.assertEquals(channelToFixture({ preset }).steps, {})
end

function tests.testOverwritesExistingFixtureIdInThreePhases()
  local both = fixture("Par 1", 5, 7)
  lu.assertEquals(channelToFixture({ both }).steps, {
    clear(both, "fixId"),
    set(both, "fixId", 5),
    clear(both, "chaId"),
  })
end

function tests.testClearsAllOldIdsBeforeSettingAnyNewOne()
  local a = fixture("A", 5, 7)
  local b = fixture("B", 7, nil)
  lu.assertEquals(channelToFixture({ a, b }).steps, {
    clear(a, "fixId"),
    set(a, "fixId", 5),
    set(b, "fixId", 7),
    clear(a, "chaId"),
    clear(b, "chaId"),
  })
end

function tests.testTakenTargetIsConflictAndPlansNoSteps()
  local wash = fixture("MQuaWBa 1", nil, 101)
  local par = fixture("sirius", 101, nil)
  lu.assertEquals(channelToFixture({ wash, par }), {
    steps = {},
    conflicts = { { id = 101, fixtures = { wash, par } } },
  })
end

function tests.testIdFreedByOverwriteIsNoConflict()
  local a = fixture("A", 5, 7)
  local b = fixture("B", 7, nil)
  lu.assertEquals(channelToFixture({ a, b }).conflicts, {})
end

function tests.testListsAllConflictsSortedById()
  local wash = fixture("wash", nil, 301)
  local profile = fixture("profile", 301, nil)
  local otherWash = fixture("other wash", nil, 101)
  local par = fixture("par", 101, nil)
  local free = fixture("free", 900, nil)
  local fixtures = { wash, profile, otherWash, par, free }
  lu.assertEquals(channelToFixture(fixtures).conflicts, {
    { id = 101, fixtures = { otherWash, par } },
    { id = 301, fixtures = { wash, profile } },
  })
end

function tests.testWorksInReverseDirection()
  local wash = fixture("Wash 1", nil, 101)
  lu.assertEquals(swapIds.plan({ wash }, "fixId", "chaId").steps, {
    set(wash, "chaId", 101),
    clear(wash, "fixId"),
  })
end

return tests
