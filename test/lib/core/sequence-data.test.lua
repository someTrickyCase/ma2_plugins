local lu = require("luaunit")
local sequenceData = require("core.sequence-data")

local SOURCE = [[<MA><Sequ index="0"><Cue xsi:nil="true"/>
<Cue index="1"><Number number="8" sub_number="100"/><CueDatas>
<CueData value_multipart_index="2" effect_multipart_index="0">
<Channel fixture_id="1" channel_id="2" attribute_name="PAN"/>
<Value>-12.5</Value></CueData>
<CueData value_multipart_index="2"><Channel fixture_id="1" channel_id="2"
attribute_name="TILT"/><Value>1e-05</Value>
<Preset name="Existing"><No>1</No><No>2</No><No>14</No></Preset></CueData>
<CueData><Channel fixture_id="0" channel_id="3" attribute_name="DIM"/>
<Value>Release</Value><EffectFlags form_index="1"/></CueData>
</CueDatas><CuePart index="2" basic_fade="3"/></Cue></Sequ></MA>]]

local tests = {}

function tests.testReadsCueNumberPartsAndAttributeIdentities()
  local result = sequenceData.read(SOURCE)
  lu.assertEquals(#result.cues, 1)
  local cue = result.cues[1]
  lu.assertEquals(cue.number, "8.1")
  lu.assertEquals(#cue.rows, 3)
  lu.assertEquals(cue.rows[1].fixture, "1")
  lu.assertEquals(cue.rows[1].channel, "2")
  lu.assertEquals(cue.rows[1].attribute, "PAN")
  lu.assertEquals(cue.rows[1].value, -12.5)
  lu.assertEquals(cue.rows[1].part, "2")
  lu.assertEquals(cue.rows[1].effectPart, "0")
end

function tests.testPreservesPresetReferencesAndSpecialValues()
  local rows = sequenceData.read(SOURCE).cues[1].rows
  lu.assertEquals(rows[2].value, 0.00001)
  lu.assertEquals(rows[2].preset, { "1", "2", "14" })
  lu.assertNil(rows[3].value)
  lu.assertEquals(rows[3].valueText, "Release")
  lu.assertTrue(rows[3].hasEffect)
end

function tests.testCollectsUniqueFixtureAndChannelAddresses()
  lu.assertEquals(
    sequenceData.read(SOURCE).addresses,
    { "Fixture 1", "Channel 3" }
  )
end

function tests.testRetainsSourceSpansForSurgicalEdits()
  local row = sequenceData.read(SOURCE).cues[1].rows[1]
  lu.assertStrContains(
    SOURCE:sub(row.node.first, row.node.last),
    "<Value>-12.5</Value>"
  )
end

function tests.testRetainsCompactRowsRatherThanCueDataTrees()
  local result = sequenceData.read(SOURCE)
  lu.assertNil(result.cues[1].rows[1].node.children)
  for _, node in ipairs(result.cues[1].node.children) do
    if node.tag == "CueDatas" then
      lu.assertEquals(node.children, {})
    end
  end
end

function tests.testRejectsAmbiguousChannelRowsAndMissingIdentities()
  local extra =
    [[<CueData value_multipart_index="2"><Channel fixture_id="1" channel_id="2"
attribute_name="PAN"/><Value>10</Value></CueData>]]
  lu.assertError(
    sequenceData.read,
    SOURCE:gsub("</CueDatas>", extra .. "</CueDatas>")
  )
  lu.assertError(
    sequenceData.read,
    SOURCE:gsub('fixture_id="1"', 'fixture_id="bad"', 1)
  )
end

function tests.testRejectsMissingOrMultipleSequences()
  lu.assertError(sequenceData.read, "<MA/>")
  lu.assertError(sequenceData.read, "<MA><Sequ/><Sequ/></MA>")
end

return tests
