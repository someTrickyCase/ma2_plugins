local lu = require("luaunit")
local planner = require("core.cleanup-plan")
local sequenceData = require("core.sequence-data")

local SOURCE = [[<MA><Sequ index="0"><Cue><Number number="1"/>
<CueDatas><CueData><Channel fixture_id="1" channel_id="0"
attribute_name="PAN"/><Value>10</Value></CueData></CueDatas></Cue>
<Cue><Number number="2"/><CueDatas><CueData><Channel fixture_id="1"
channel_id="0" attribute_name="PAN"/><Value>14</Value></CueData>
</CueDatas></Cue></Sequ></MA>]]

local DEFINITIONS = {
  ["Fixture 1"] = {
    module = "0",
    definition = { modules = { ["0"] = { PAN = {} } } },
  },
}

local tests = {}

function tests.testCreatesExactPositionPresetPerCue()
  local result = planner.plan(
    sequenceData.read(SOURCE),
    DEFINITIONS,
    { positionStep = 5, colorStep = 5 }
  )
  lu.assertEquals(#result.presets, 2)
  lu.assertEquals(result.presets[1].pool, 2)
  lu.assertEquals(result.presets[1].name, "cue_1")
  local sequence = sequenceData.read(result.xml)
  lu.assertEquals(sequence.cues[2].rows[1].value, 14)
  lu.assertEquals(sequence.cues[2].rows[1].preset, { "1", "2", "2" })
end

function tests.testDimmerReleaseAffectsRemovalWithoutRewritingKeptValues()
  local source = SOURCE:gsub("PAN", "DIM")
    :gsub("<Value>10</Value>", "<Value>Release</Value>")
  local definitions = {
    ["Fixture 1"] = {
      module = "0",
      definition = { modules = { ["0"] = { DIM = {} } } },
    },
  }
  local kept = planner.plan(sequenceData.read(source), definitions, {})
  lu.assertEquals(kept.remove, {})
  lu.assertEquals(kept.xml, source)
  local dark = source:gsub("<Value>14</Value>", "<Value>0</Value>")
  local removed = planner.plan(sequenceData.read(dark), definitions, {})
  lu.assertEquals(removed.remove, { "Fixture 1" })
  lu.assertNotStrContains(removed.xml, 'fixture_id="1"')
end

function tests.testAvoidsExistingSlotsAndNamesWithoutMutatingInputs()
  local occupied = { [2] = { [1] = true, [2] = true } }
  local names = { cue_1 = true }
  local result = planner.plan(sequenceData.read(SOURCE), DEFINITIONS, {
    positionStep = 0,
    colorStep = 0,
    occupied = occupied,
    names = names,
  })
  lu.assertEquals(#result.presets, 2)
  lu.assertEquals(result.presets[1].slot, 3)
  lu.assertEquals(result.presets[1].name, "cue_1_1")
  lu.assertNil(occupied[2][3])
  lu.assertNil(names.cue_1_1)
end

function tests.testKeepsUnknownFixtureInsteadOfRemovingIt()
  local result = planner.plan(
    sequenceData.read(SOURCE),
    DEFINITIONS,
    { positionStep = 5, colorStep = 5 }
  )
  lu.assertEquals(result.remove, {})
  lu.assertEquals(#result.uncertain, 1)
end

function tests.testShutterOnlyRemovalRequiresCalibratedStoredValueRanges()
  local source = SOURCE:gsub("PAN", "SHUTTER")
    :gsub("<Value>10</Value>", "<Value>0</Value>")
    :gsub("<Value>14</Value>", "<Value>0</Value>")
  local definitions = {
    ["Fixture 1"] = {
      module = "0",
      definition = {
        modules = {
          ["0"] = {
            SHUTTER = {
              bits = 8,
              functions = {
                {
                  subattribute = "SHUTTER",
                  sets = { { minimum = 0, maximum = 31, name = "closed" } },
                },
              },
            },
          },
        },
      },
    },
  }
  local result = planner.plan(sequenceData.read(source), definitions, {})
  lu.assertEquals(result.remove, {})
  lu.assertEquals(#result.uncertain, 1)
  definitions["Fixture 1"].light = {
    hasDimmer = false,
    closedRanges = { { minimum = 0, maximum = 0 } },
  }
  result = planner.plan(sequenceData.read(source), definitions, {})
  lu.assertEquals(result.remove, { "Fixture 1" })
end

local function colorSource()
  local function row(id, value, reference)
    return '<CueData><Channel fixture_id="'
      .. id
      .. '" channel_id="0" attribute_name="COLORRGB1"/><Value>'
      .. value
      .. "</Value>"
      .. (reference or "")
      .. "</CueData>"
  end
  return '<MA><Sequ><Cue><Number number="1"/><CueDatas>'
    .. row("1", "10")
    .. row("2", "12")
    .. row("3", "40")
    .. row("4", "10", "<Preset><No>1</No><No>4</No><No>90</No></Preset>")
    .. '</CueDatas></Cue><Cue><Number number="2"/><CueDatas>'
    .. row("1", "11")
    .. "</CueDatas></Cue></Sequ></MA>"
end

function tests.testSameColorsSharePresetAcrossFixturesAndCues()
  local definitions = {}
  for id = 1, 4 do
    definitions["Fixture " .. id] = {
      module = "0",
      definition = {
        modules = { ["0"] = { COLORRGB1 = { preset = "COLOR" } } },
      },
    }
  end
  local result = planner.plan(sequenceData.read(colorSource()), definitions, {
    colorStep = 5,
  })
  lu.assertEquals(#result.presets, 2)
  lu.assertEquals(#result.presets[1].channels, 2)
  lu.assertEquals(result.presets[1].channels[2].fixture, "2")
  lu.assertEquals(result.presets[1].channels[2].value, 10)
  local sequence = sequenceData.read(result.xml)
  local rows = sequence.cues[1].rows
  lu.assertEquals(rows[1].preset, rows[2].preset)
  lu.assertNotEquals(rows[1].preset, rows[3].preset)
  lu.assertEquals(rows[4].preset, { "1", "4", "90" })
  lu.assertEquals(sequence.cues[2].rows[1].preset, rows[1].preset)
end

function tests.testPositionsCombineFixturesAndPreserveExistingReferences()
  local source = colorSource():gsub("COLORRGB1", "PAN")
  local definitions = {}
  for id = 1, 4 do
    definitions["Fixture " .. id] = DEFINITIONS["Fixture 1"]
  end
  local result = planner.plan(sequenceData.read(source), definitions, {})
  lu.assertEquals(#result.presets, 2)
  lu.assertEquals(#result.presets[1].channels, 3)
  lu.assertEquals(result.presets[1].name, "cue_1")
  lu.assertEquals(result.presets[2].name, "cue_2")
  local rows = sequenceData.read(result.xml).cues[1].rows
  lu.assertEquals(rows[1].preset, rows[3].preset)
  lu.assertEquals(rows[2].value, 12)
  lu.assertEquals(rows[4].preset, { "1", "4", "90" })
end

function tests.testSeparatesPositionPartsAndNamesDecimalCues()
  local source = SOURCE:gsub('number="1"', 'number="1" sub_number="250"')
  source = source:gsub(
    "</CueDatas>",
    [[<CueData value_multipart_index="2"><Channel fixture_id="1"
channel_id="0" attribute_name="PAN"/><Value>30</Value></CueData>
</CueDatas>]],
    1
  )
  local result = planner.plan(sequenceData.read(source), DEFINITIONS, {})
  lu.assertEquals(#result.presets, 3)
  lu.assertEquals(result.presets[1].name, "cue_1.25")
  lu.assertEquals(result.presets[2].name, "cue_1.25_part_2")
  lu.assertEquals(result.presets[2].channels[1].value, 30)
end

function tests.testColorWheelSharesExactValuesAcrossFixtures()
  local source = colorSource():gsub("COLORRGB1", "COLOR1")
  local definitions = {}
  for id = 1, 4 do
    definitions["Fixture " .. id] = {
      module = "0",
      definition = {
        modules = {
          ["0"] = {
            COLOR1 = { preset = "COLOR", functions = { { wheel = "0" } } },
          },
        },
      },
    }
  end
  source = source:gsub("<Value>12</Value>", "<Value>10</Value>")
  local result = planner.plan(sequenceData.read(source), definitions, {})
  lu.assertEquals(#result.presets, 3)
  lu.assertEquals(#result.presets[1].channels, 2)
end

function tests.testUnusedModeNeverCreatesPresets()
  local result = planner.plan(sequenceData.read(SOURCE), DEFINITIONS, {
    mode = "unused",
  })
  lu.assertEquals(result.presets, {})
  lu.assertEquals(result.references, {})
  lu.assertEquals(result.xml, SOURCE)
end

function tests.testPositionModeNeverRemovesDarkFixtures()
  local source = SOURCE:gsub("PAN", "DIM")
    :gsub("<Value>10</Value>", "<Value>0</Value>")
    :gsub("<Value>14</Value>", "<Value>0</Value>")
  local definitions = {
    ["Fixture 1"] = {
      module = "0",
      definition = { modules = { ["0"] = { DIM = {} } } },
    },
  }
  local result = planner.plan(sequenceData.read(source), definitions, {
    mode = "position",
    positionStep = 0,
  })
  lu.assertEquals(result.remove, {})
  lu.assertEquals(result.xml, source)
  lu.assertEquals(result.presets, {})
end

function tests.testPositionToleranceAppliesWithinEachCueWithoutMergingCues()
  local extra = [[<CueData><Channel fixture_id="2" channel_id="0"
attribute_name="PAN"/><Value>12</Value></CueData>]]
  local source = SOURCE:gsub("</CueDatas>", extra .. "</CueDatas>")
  local definitions = {
    ["Fixture 1"] = DEFINITIONS["Fixture 1"],
    ["Fixture 2"] = DEFINITIONS["Fixture 1"],
  }
  for _, tolerance in ipairs({ 0, 2 }) do
    local result = planner.plan(sequenceData.read(source), definitions, {
      mode = "position",
      positionStep = tolerance,
    })
    lu.assertEquals(#result.presets, 2)
    lu.assertEquals(result.presets[1].name, "cue_1")
    lu.assertEquals(result.presets[2].name, "cue_2")
    local cues = sequenceData.read(result.xml).cues
    lu.assertEquals(cues[1].rows[2].value, tolerance == 0 and 12 or 10)
    lu.assertEquals(cues[2].rows[2].value, tolerance == 0 and 12 or 14)
    lu.assertEquals(result.presets[1].channels[2].value, cues[1].rows[2].value)
    lu.assertEquals(result.presets[2].channels[2].value, cues[2].rows[2].value)
  end
end

function tests.testPositionModeLeavesRawColorAndReferencesUntouched()
  local extra = [[<CueData><Channel fixture_id="1" channel_id="0"
attribute_name="COLORRGB1"/><Value>12</Value></CueData>]]
  local source = SOURCE:gsub("</CueDatas>", extra .. "</CueDatas>")
  local definitions = {
    ["Fixture 1"] = {
      module = "0",
      definition = {
        modules = {
          ["0"] = {
            PAN = {},
            COLORRGB1 = { preset = "COLOR" },
          },
        },
      },
    },
  }
  local result = planner.plan(sequenceData.read(source), definitions, {
    mode = "position",
    positionStep = 5,
  })
  lu.assertEquals(#result.presets, 2)
  lu.assertStrContains(result.xml, extra)
  for _, preset in ipairs(result.presets) do
    lu.assertEquals(preset.pool, 2)
  end
end

return tests
