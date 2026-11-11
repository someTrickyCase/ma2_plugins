local lu = require("luaunit")
local unused = require("core.unused-fixtures")

local function row(attribute, value, extras)
  local entry = extras or {}
  entry.address = "Fixture 1"
  entry.attribute = attribute
  entry.value = value
  entry.valueText = entry.valueText or tostring(value)
  return entry
end

local function plan(cues, definition)
  local sequence = { addresses = { "Fixture 1" }, cues = {} }
  for _, rows in ipairs(cues) do
    sequence.cues[#sequence.cues + 1] = { rows = rows }
  end
  return unused.plan(sequence, { ["Fixture 1"] = definition })
end

local tests = {}

function tests.testRemovesOnlyExplicitlyDarkDimmerFixture()
  local result = plan(
    { { row("DIM", 0) }, { row("PAN", 50) } },
    { hasDimmer = true }
  )
  lu.assertEquals(result.remove, { "Fixture 1" })
end

function tests.testTinyPositiveDimmerKeepsFixture()
  local result = plan(
    { { row("DIM", 0) }, { row("DIM", 0.00001) } },
    { hasDimmer = true }
  )
  lu.assertEquals(result.keep, { "Fixture 1" })
end

function tests.testShutterClosureCannotExcludeDimmerFixture()
  local result = plan(
    { { row("DIM", 50), row("SHUTTER", 0) } },
    { hasDimmer = true, closedRanges = { { minimum = 0, maximum = 10 } } }
  )
  lu.assertEquals(result.keep, { "Fixture 1" })
end

function tests.testMissingInitialValueDoesNotKeepDimmerFixture()
  local cues = { { row("PAN", 50) }, { row("DIM", 0) } }
  lu.assertEquals(plan(cues, { hasDimmer = true }).remove, { "Fixture 1" })
  lu.assertEquals(
    plan(cues, { hasDimmer = true, default = 0 }).remove,
    { "Fixture 1" }
  )
  lu.assertEquals(
    plan(cues, { hasDimmer = true, default = 100 }).remove,
    { "Fixture 1" }
  )
  lu.assertEquals(
    plan({ { row("PAN", 50) } }, { hasDimmer = true }).remove,
    { "Fixture 1" }
  )
end

function tests.testPositiveStoredDimmerKeepsFixtureWithEffectsAndPresetLinks()
  for _, entry in ipairs({
    row("DIM", 0.00001, { hasEffect = true }),
    row("DIM", 50, { preset = { "1", "1", "2" } }),
  }) do
    lu.assertEquals(
      plan({ { entry } }, { hasDimmer = true }).keep,
      { "Fixture 1" }
    )
  end
end

function tests.testDimmerNeedsPositiveStoredValueDespiteEffectsOrLinks()
  for _, entry in ipairs({
    row("DIM", 0, { hasEffect = true }),
    row("DIM", nil, { valueText = "DefaultLink" }),
    row("DIM", 0, { preset = { "1", "1", "2" } }),
  }) do
    lu.assertEquals(
      plan({ { entry } }, { hasDimmer = true }).remove,
      { "Fixture 1" }
    )
  end
end

function tests.testDimmerReleaseCountsAsZero()
  for _, cues in ipairs({
    { { row("DIM", nil, { valueText = "Release" }) } },
    { { row("DIM", 0) }, { row("DIM", nil, { valueText = "Release" }) } },
  }) do
    local result = plan(cues, { hasDimmer = true })
    lu.assertEquals(result.remove, { "Fixture 1" })
    lu.assertEquals(result.uncertain, {})
  end
end

function tests.testDimmerReleaseDoesNotHidePositiveValuesInOtherCues()
  for _, values in ipairs({ { 50, "Release" }, { "Release", 50 } }) do
    local cues = {}
    for _, value in ipairs(values) do
      cues[#cues + 1] = {
        row("DIM", tonumber(value), { valueText = tostring(value) }),
      }
    end
    lu.assertEquals(plan(cues, { hasDimmer = true }).keep, { "Fixture 1" })
  end
end

function tests.testReleaseWithEffectOrPresetLinkDoesNotKeepDimmerFixture()
  for _, extras in ipairs({
    { valueText = "Release", hasEffect = true },
    { valueText = "Release", preset = { "1", "1", "2" } },
  }) do
    local result = plan({ { row("DIM", nil, extras) } }, { hasDimmer = true })
    lu.assertEquals(result.remove, { "Fixture 1" })
  end
  local result = plan({ { row("SHUTTER", nil, { valueText = "Release" }) } }, {
    hasDimmer = false,
    closedRanges = { { minimum = 0, maximum = 10 } },
  })
  lu.assertEquals(#result.uncertain, 1)
end

function tests.testShutterOnlyFixtureNeedsVerifiedClosedRanges()
  local cues = { { row("SHUTTER", 5) }, { row("SHUTTER", 9) } }
  local ranges = { { minimum = 0, maximum = 10 } }
  lu.assertEquals(
    plan(cues, { hasDimmer = false, closedRanges = ranges }).remove,
    { "Fixture 1" }
  )
  lu.assertEquals(#plan(cues, { hasDimmer = false }).uncertain, 1)
  lu.assertEquals(
    plan(
      { { row("SHUTTER", 20) } },
      { hasDimmer = false, closedRanges = ranges }
    ).keep,
    { "Fixture 1" }
  )
end

function tests.testMissingFixtureTypeCannotCauseRemoval()
  lu.assertEquals(#plan({ { row("DIM", 0) } }, nil).uncertain, 1)
end

return tests
