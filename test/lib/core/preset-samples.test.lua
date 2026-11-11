local lu = require("luaunit")
local samples = require("core.preset-samples")

local function row(attribute, value, extra)
  local item = extra or {}
  item.address = "Fixture 1"
  item.attribute = attribute
  item.value = value
  item.part = item.part or "0"
  return item
end

local function collect(rows, options)
  local definition = {
    modules = {
      ["0"] = {
        PAN = {},
        TILT = {},
        COLORRGB1 = { preset = "COLOR" },
        COLORRGB2 = { preset = "COLOR" },
        COLOR1 = { preset = "COLOR", functions = { { wheel = "0" } } },
      },
    },
  }
  return samples.collect(
    { cues = { { number = "1", rows = rows } } },
    { ["Fixture 1"] = { definition = definition, module = "0" } },
    options or {}
  )
end

local tests = {}

function tests.testCollectsPositionValuesAndKeepsOriginalRows()
  local pan, tilt = row("PAN", -120), row("TILT", 30)
  local result = collect({ pan, tilt })
  lu.assertEquals(#result.samples, 1)
  lu.assertEquals(result.samples[1].values, { PAN = -120, TILT = 30 })
  lu.assertEquals(result.samples[1].pool, 2)
  lu.assertIs(result.samples[1].rows[1], pan)
  lu.assertIs(result.samples[1].rows[2], tilt)
end

function tests.testPartialRawPositionDoesNotReplaceOtherPresetReference()
  local pan = row("PAN", 20)
  local tilt = row("TILT", 30, { preset = { "1", "2", "1" } })
  local result = collect({ pan, tilt })
  lu.assertEquals(result.samples[1].values, { PAN = 20 })
  lu.assertEquals(result.samples[1].rows, { pan })
end

function tests.testSeparatesPartsMixingAndWheelData()
  local result = collect({
    row("PAN", 1),
    row("TILT", 2, { part = "1" }),
    row("COLORRGB1", 10),
    row("COLORRGB2", 20),
    row("COLOR1", 30),
  }, {
    wheelLabel = function()
      return "Red"
    end,
  })
  lu.assertEquals(#result.samples, 4)
  lu.assertEquals(result.samples[3].values, { COLORRGB1 = 10, COLORRGB2 = 20 })
  lu.assertEquals(result.samples[3].pool, 4)
  lu.assertEquals(result.samples[4].label, "Red")
  lu.assertNotEquals(result.samples[3].scope, result.samples[4].scope)
end

function tests.testSkipsEffectsUnknownValuesAndRemovedFixtures()
  local result = collect({
    row("PAN", 10, { hasEffect = true }),
    row("TILT", nil),
    row("DIM", 0),
  })
  lu.assertEquals(result.samples, {})
  lu.assertEquals(#result.skipped, 2)
  lu.assertEquals(
    collect({ row("PAN", 10) }, { removed = { "Fixture 1" } }).samples,
    {}
  )
end

function tests.testWheelScopeIncludesSlotLabel()
  local red = collect({ row("COLOR1", 10) }, {
    wheelLabel = function()
      return "Red"
    end,
  }).samples[1]
  local blue = collect({ row("COLOR1", 11) }, {
    wheelLabel = function()
      return "Blue"
    end,
  }).samples[1]
  lu.assertNotEquals(red.scope, blue.scope)
end

function tests.testAmbiguousTargetChannelsAreReportedForReview()
  local entry = row("PAN", 10)
  local result = samples.collect(
    { cues = { { number = "1", rows = { entry } } } },
    {
      ["Fixture 1"] = {
        module = "0",
        definition = {
          modules = {
            ["0"] = { PAN = { ambiguous = true } },
          },
        },
      },
    },
    {}
  )
  lu.assertEquals(result.samples, {})
  lu.assertEquals(#result.skipped, 1)
end

return tests
