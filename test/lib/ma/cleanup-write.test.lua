local lu = require("luaunit")
local writer = require("ma.cleanup-write")

local SOURCE = '<MA><Sequ index="0"><CuePart fade="3"/></Sequ></MA>'
local PRESET = '<MA><Preset index="19" name="unknown_1"/></MA>'

local function setup()
  local objects = { ["Sequence 1"] = {} }
  local imports = {}
  local gma = {
    show = {
      getobj = {
        handle = function(address)
          return objects[address]
        end,
        amount = function()
          return 1
        end,
      },
    },
    echo = function() end,
  }
  local files = {
    command = function()
      objects["Sequence 2"] = {}
    end,
    save = function() end,
    import = function(address)
      imports[#imports + 1] = address
      objects[address] = {}
    end,
    export = function(_, tag)
      error("Unexpected verification export: " .. tag)
    end,
  }
  return writer.new(gma, files), imports
end

local function input()
  return { number = "1", sequence = { source = SOURCE } }
end

local tests = {}

function tests.testSkipsVerificationExports()
  local instance, imports = setup()
  instance.apply(input(), {
    presets = { { pool = 2, slot = 20, xml = PRESET } },
    xml = SOURCE,
  })
  lu.assertEquals(imports, { "Preset 2.20", "Sequence 1" })
end
function tests.testSuccessfulWriteKeepsBackup()
  local instance, imports = setup()
  lu.assertEquals(
    instance.apply(input(), { presets = {}, xml = SOURCE }),
    SOURCE
  )
  lu.assertEquals(imports, { "Sequence 1" })
  lu.assertStrContains(instance.recovery(), "Sequence 2")
end

return tests
