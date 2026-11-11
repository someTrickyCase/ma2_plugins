local lu = require("luaunit")
local files = require("ma.cleanup-files")

local tests = {}

function tests.testExportsReadFromTheCorrectConsoleFolder()
  local commands, paths = {}, {}
  local gma = {
    gettime = function()
      return 12
    end,
    sleep = function() end,
    cmd = function(text)
      commands[#commands + 1] = text
    end,
    show = {
      getvar = function()
        return "data"
      end,
    },
  }
  local storage = {
    read = function(path)
      paths[#paths + 1] = path
      return "<MA/>"
    end,
  }
  local instance = files.new(gma, storage)
  lu.assertEquals(
    instance.export("FixtureType 4", "type-4", "library"),
    "<MA/>"
  )
  lu.assertStrContains(paths[1], "data/library/k-sequence-cleanup-")
  lu.assertStrContains(commands[1], "Export FixtureType 4")
end

function tests.testCommandFailureCannotReadAStaleExport()
  local reads = 0
  local gma = {
    gettime = function()
      return 12
    end,
    sleep = function() end,
    cmd = function()
      return "Export failed"
    end,
    show = {
      getvar = function()
        return "data"
      end,
    },
  }
  local instance = files.new(gma, {
    read = function()
      reads = reads + 1
    end,
  })
  lu.assertError(instance.export, "Sequence 1", "input")
  lu.assertEquals(reads, 0)
end

return tests
