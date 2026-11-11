local lu = require("luaunit")
local clusters = require("core.preset-clusters")

local function sample(scope, values, preset)
  return { scope = scope, values = values, preset = preset }
end

local tests = {}

function tests.testEmptyInput()
  lu.assertEquals(clusters.plan({}, 5), { groups = {}, skipped = {} })
end

function tests.testGroupsByStoredValuesIncludingToleranceBoundary()
  local first = sample("position:1", { PAN = -120, TILT = 20 })
  local close = sample("position:1", { PAN = -115, TILT = 16 })
  local result = clusters.plan({ first, close }, 5)
  lu.assertEquals(result.groups, {
    {
      scope = "position:1",
      values = { PAN = -120, TILT = 20 },
      members = { first, close },
    },
  })
end

function tests.testDoesNotChainToleranceAcrossMembers()
  local a = sample("position:1", { PAN = 0, TILT = 0 })
  local b = sample("position:1", { PAN = 5, TILT = 0 })
  local c = sample("position:1", { PAN = 10, TILT = 0 })
  local result = clusters.plan({ a, b, c }, 5)
  lu.assertEquals(#result.groups, 2)
  lu.assertEquals(result.groups[1].members, { a, b })
  lu.assertEquals(result.groups[2].members, { c })
end

function tests.testEveryAttributeMustBeWithinTolerance()
  local a = sample("color:1", { R = 20, G = 40, B = 60, W = 0 })
  local b = sample("color:1", { R = 21, G = 40, B = 60, W = 6 })
  lu.assertEquals(#clusters.plan({ a, b }, 5).groups, 2)
end

function tests.testDoesNotMergeDifferentScopesOrAttributeSets()
  local a = sample("position:1", { PAN = 10, TILT = 20 })
  local b = sample("position:2", { PAN = 10, TILT = 20 })
  local c = sample("position:1", { PAN = 10 })
  lu.assertEquals(#clusters.plan({ a, b, c }, 5).groups, 3)
end

function tests.testPreservesExistingPresetReferences()
  local existing = sample("position:1", { PAN = 10, TILT = 20 }, "2.1")
  local raw = sample("position:1", { PAN = 10, TILT = 20 })
  local result = clusters.plan({ existing, raw }, 5)
  lu.assertEquals(result.skipped, { existing })
  lu.assertEquals(result.groups[1].members, { raw })
end

function tests.testZeroToleranceKeepsExactValuesOnly()
  local a = sample("color:1", { R = 0 })
  local b = sample("color:1", { R = 0.00001 })
  lu.assertEquals(#clusters.plan({ a, b }, 0).groups, 2)
end

function tests.testRejectsInvalidTolerance()
  for _, value in ipairs({ -1, math.huge, 0 / 0, "5" }) do
    lu.assertError(clusters.plan, {}, value)
  end
end

function tests.testSkipsUnknownOrInvalidVectors()
  local rows = {
    sample("color:1", { R = "Release" }),
    sample("color:1", {}),
    sample("color:1", { R = math.huge }),
    sample("color:1", { R = 0 / 0 }),
  }
  local result = clusters.plan(rows, 5)
  lu.assertEquals(result.groups, {})
  lu.assertEquals(#result.skipped, #rows)
  for index, row in ipairs(rows) do
    lu.assertIs(result.skipped[index], row)
  end
end

function tests.testRepresentativeDoesNotAliasInputValues()
  local row = sample("position:1", { PAN = 10, TILT = 20 })
  local result = clusters.plan({ row }, 5)
  row.values.PAN = 99
  lu.assertEquals(result.groups[1].values.PAN, 10)
end

return tests
