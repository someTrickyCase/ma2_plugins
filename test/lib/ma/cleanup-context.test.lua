local lu = require("luaunit")
local context = require("ma.cleanup-context")

local function fake(options)
  local getobj = {
    number = function(handle)
      return handle.number
    end,
    class = function(handle)
      return handle.class
    end,
    parent = function(handle)
      return handle.parent
    end,
    handle = function(address)
      return options.objects[address]
    end,
    amount = function(handle)
      return #handle.children
    end,
    child = function(handle, index)
      return handle.children[index + 1]
    end,
  }
  return {
    user = {
      getselectedexec = function()
        return options.selected
      end,
    },
    show = {
      getobj = getobj,
      property = {
        get = function(handle, name)
          return handle.properties[name]
        end,
      },
    },
    sleep = function() end,
  }
end

local tests = {}

function tests.testResolvesSequenceThroughSelectedExecutorCue()
  local sequence = { class = "CMD_SEQUENCE", number = "7" }
  local gma = fake({
    selected = { number = "2.6" },
    objects = {
      ["Executor 2.6 Cue 1"] = { parent = sequence },
    },
  })
  lu.assertEquals(context.sequence(gma), "7")
end

function tests.testMissingCueDoesNotSelectAnUnrelatedSequence()
  local gma = fake({ selected = { number = "2.6" }, objects = {} })
  local number, problem = context.sequence(gma)
  lu.assertNil(number)
  lu.assertNotNil(problem)
end

function tests.testSelectedExecutorWithoutNumberStaysUnresolved()
  local gma = fake({ selected = {}, objects = {} })
  local number, problem = context.sequence(gma)
  lu.assertNil(number)
  lu.assertStrContains(problem, "number")
end

function tests.testMissingExecutorAndWrongParentStayUnresolved()
  lu.assertNil(context.sequence(fake({ objects = {} })))
  local gma = fake({
    selected = { number = "2.6" },
    objects = {
      ["Executor 2.6 Cue 1"] = { parent = { class = "CMD_EFFECT" } },
    },
  })
  lu.assertNil(context.sequence(gma))
end

function tests.testReadsTypeFromChildInstanceProperty()
  local gma = fake({
    objects = {
      ["Fixture 10"] = {
        children = {
          { properties = { ["Fixture|Type"] = "4 Example fixture" } },
        },
      },
    },
  })
  local result = context.fixtures(gma, { "Fixture 10" })
  lu.assertEquals(result.types, { "4" })
  lu.assertEquals(result.fixtures["Fixture 10"], { type = "4", module = "0" })
  lu.assertEquals(result.uncertain, {})
end

function tests.testDeduplicatesTypeExportsAndSortsNumerically()
  local objects = {}
  for address, number in pairs({
    ["Fixture 1"] = 12,
    ["Fixture 2"] = 4,
    ["Channel 3"] = 4,
  }) do
    objects[address] = {
      children = {
        { properties = { ["Fixture|Type"] = number .. " Example" } },
      },
    }
  end
  local result = context.fixtures(
    fake({ objects = objects }),
    { "Fixture 1", "Fixture 2", "Channel 3" }
  )
  lu.assertEquals(result.types, { "4", "12" })
end

function tests.testUnknownAndMultiInstanceFixturesAreMarkedUncertain()
  local instance = { properties = { ["Fixture|Type"] = "4 Example" } }
  local gma = fake({
    objects = {
      ["Fixture 2"] = { children = { instance, instance } },
      ["Fixture 3"] = { children = { { properties = {} } } },
    },
  })
  local result =
    context.fixtures(gma, { "Fixture 1", "Fixture 2", "Fixture 3" })
  lu.assertEquals(result.types, {})
  lu.assertEquals(result.fixtures, {})
  lu.assertEquals(#result.uncertain, 3)
end

return tests
