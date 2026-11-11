local lu = require("luaunit")
local presets = require("core.sequence-presets")

local tests = {}

function tests.testIncludesAllRetainedOldAndNewPresetsOnce()
  local sequence = {
    cues = {
      {
        rows = {
          { address = "Fixture 1", preset = { "1", "2", "90" } },
          { address = "Fixture 2", preset = { "1", "2", "90" } },
          { address = "Fixture 1", preset = { "1", "1", "12" } },
          { address = "Fixture 3", preset = { "1", "4", "100" } },
        },
      },
    },
  }
  lu.assertEquals(
    presets.collect(sequence, {
      remove = { "Fixture 3" },
      presets = { { pool = 4, slot = 5 } },
    }),
    { "Preset 1.12", "Preset 2.90", "Preset 4.5" }
  )
end

return tests
