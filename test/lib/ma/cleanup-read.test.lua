local lu = require("luaunit")
local reader = require("ma.cleanup-read")

local tests = {}

function tests.testSelectedExecutorWithoutNumberStillOffersSequenceChoice()
  local suggested
  local gma = {
    user = {
      getselectedexec = function()
        return {}
      end,
    },
    show = { getobj = { number = function() end } },
    textinput = function(_, default)
      suggested = default
      return "7"
    end,
  }
  lu.assertEquals(reader.choose(gma), "7")
  lu.assertEquals(suggested, "1")
end

function tests.testAlwaysOffersSequenceChoiceEvenWithASelectedSequence()
  local default
  local sequence = { number = "1", class = "CMD_SEQUENCE" }
  local gma = {
    user = {
      getselectedexec = function()
        return { number = "1.6" }
      end,
    },
    show = {
      getobj = {
        number = function(handle)
          return handle.number
        end,
        handle = function()
          return { parent = sequence }
        end,
        parent = function(handle)
          return handle.parent
        end,
        class = function(handle)
          return handle.class
        end,
      },
    },
    textinput = function(_, suggested)
      default = suggested
      return "7"
    end,
  }
  lu.assertEquals(reader.choose(gma), "7")
  lu.assertEquals(default, "1")
end

function tests.testCancelledSequenceChoiceDoesNotExportAnything()
  local called = false
  local gma = {
    user = { getselectedexec = function() end },
    textinput = function() end,
    show = { getobj = {} },
  }
  local files = {
    command = function()
      called = true
    end,
  }
  lu.assertNil(reader.read(gma, files))
  lu.assertFalse(called)
end

function tests.testRejectsSequenceNumbersOutsideRequestedRange()
  local gma = {
    user = { getselectedexec = function() end },
    textinput = function()
      return "512"
    end,
    show = { getobj = {} },
  }
  lu.assertError(reader.read, gma, {})
end

function tests.testReadsSparsePoolChildrenWithoutThousandsOfNameLookups()
  local roots = {
    [2] = { number = "2", class = "CMD_PRESET_POOL", amount = 9002 },
    [4] = { number = "4", class = "CMD_PRESET_POOL", amount = 9002 },
  }
  local function preset(pool, slot, label)
    return { number = pool .. "." .. slot, label = label, parent = roots[pool] }
  end
  roots[2].children = {
    [0] = preset(2, 1, "Existing"),
    [9001] = preset(2, 9002, "High position"),
  }
  roots[4].children = { [0] = preset(4, 1, "Red"), [7] = preset(4, 8, "Blue") }
  local calls = 0
  local gma = {
    show = {
      getobj = {
        handle = function(address)
          calls = calls + 1
          if address == "Preset 2.1" then
            return roots[2].children[0]
          end
          if address == "Preset 4.1" then
            return roots[4].children[0]
          end
          error("Unexpected preset name lookup")
        end,
        parent = function(node)
          return node.parent
        end,
        class = function(node)
          return node.class
        end,
        number = function(node)
          return node.number
        end,
        amount = function(node)
          return node.amount
        end,
        child = function(node, index)
          return node.children[index]
        end,
        label = function(node)
          return node.label
        end,
      },
    },
  }
  local occupied, names = reader.pools(gma)
  lu.assertEquals(calls, 2)
  lu.assertTrue(occupied[2][1])
  lu.assertTrue(occupied[2][9002])
  lu.assertNil(occupied[2][2])
  lu.assertTrue(occupied[4][8])
  lu.assertTrue(names.Existing)
  lu.assertTrue(names.Blue)
end

function tests.testRejectsASeedFromAnUnexpectedPool()
  local gma = {
    show = {
      getobj = {
        handle = function()
          return {}
        end,
        parent = function()
          return {}
        end,
        class = function()
          return "CMD_PRESET_POOL"
        end,
        number = function()
          return "4"
        end,
      },
    },
  }
  lu.assertErrorMsgContains("Unexpected preset pool", reader.pools, gma)
end

function tests.testUsesSequenceReferencesWhenTheFirstPresetSlotIsEmpty()
  local roots = {
    [2] = { number = "2", class = "CMD_PRESET_POOL", amount = 14 },
    [4] = { number = "4", class = "CMD_PRESET_POOL", amount = 1 },
  }
  local position = { number = "2.14", parent = roots[2] }
  local color = { number = "4.1", parent = roots[4] }
  local calls = 0
  local gma = {
    show = {
      getobj = {
        handle = function(address)
          calls = calls + 1
          if address == "Preset 2.1" then
            return nil
          end
          if address == "Preset 2.14" then
            return position
          end
          if address == "Preset 4.1" then
            return color
          end
          error("Unexpected preset name lookup")
        end,
        parent = function(node)
          return node.parent
        end,
        class = function(node)
          return node.class
        end,
        number = function(node)
          return node.number
        end,
        amount = function(node)
          return node.amount
        end,
        child = function(node, index)
          if node == roots[2] and index == 13 then
            return position
          end
          if node == roots[4] and index == 0 then
            return color
          end
        end,
        label = function() end,
      },
    },
  }
  local sequence =
    { cues = { { rows = {
      { preset = { "1", "2", "14" } },
    } } } }
  local occupied = reader.pools(gma, nil, sequence)
  lu.assertEquals(calls, 3)
  lu.assertTrue(occupied[2][14])
end

return tests
