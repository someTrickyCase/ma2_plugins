local lu = require("luaunit")
local sequenceData = require("core.sequence-data")
local edits = require("core.sequence-edits")

local SOURCE = [[<MA><Sequ index="0"><Cue><Number number="1"/>
<CueDatas><CueData value_multipart_index="0"><Channel fixture_id="1"
channel_id="0" attribute_name="PAN"/><Value>10</Value></CueData>
<CueData value_multipart_index="1"><Channel fixture_id="2" channel_id="0"
attribute_name="DIM"/><Value>0</Value></CueData></CueDatas>
<CuePart index="1" basic_fade="3"/></Cue><Cue><Number number="2"/>
<CueDatas><CueData><Channel fixture_id="2" channel_id="0"
attribute_name="TILT"/><Value>30</Value></CueData></CueDatas>
</Cue></Sequ></MA>]]

local tests = {}

function tests.testEmptyPlanLeavesSourceBytesUnchanged()
  lu.assertEquals(edits.apply(sequenceData.read(SOURCE), {}, {}), SOURCE)
end

function tests.testRemovesAllFixtureRowsAcrossCuesAndParts()
  local output = edits.apply(sequenceData.read(SOURCE), { "Fixture 2" }, {})
  local result = sequenceData.read(output)
  lu.assertEquals(result.addresses, { "Fixture 1" })
  lu.assertEquals(#result.cues, 2)
  lu.assertStrContains(output, '<CuePart index="1" basic_fade="3"/>')
  lu.assertNotStrContains(output, 'fixture_id="2"')
end

function tests.testAddsReferenceWithoutChangingValueOrOtherData()
  local source = sequenceData.read(SOURCE)
  local output = edits.apply(source, {}, {
    { row = source.cues[1].rows[1], pool = 2, slot = 20, name = 'A & "B" 50%' },
  })
  local result = sequenceData.read(output)
  local row = result.cues[1].rows[1]
  lu.assertEquals(row.value, 10)
  lu.assertEquals(row.preset, { "1", "2", "20" })
  local stripped = output:gsub('<Preset name=".-">.-</Preset>', "", 1)
  lu.assertEquals(stripped, SOURCE)
  lu.assertStrContains(output, 'name="A &amp; &quot;B&quot; 50%"')
end

function tests.testRejectsReferencesToForeignRowsOrRemovedFixtures()
  local first = sequenceData.read(SOURCE)
  local second = sequenceData.read(SOURCE)
  lu.assertError(edits.apply, first, {}, {
    { row = second.cues[1].rows[1], pool = 2, slot = 20, name = "unknown_1" },
  })
  lu.assertError(edits.apply, first, { "Fixture 1" }, {
    { row = first.cues[1].rows[1], pool = 2, slot = 20, name = "unknown_1" },
  })
end

function tests.testCannotReplaceAnExistingReference()
  local source = SOURCE:gsub(
    "<Value>10</Value>",
    "<Value>10</Value><Preset><No>1</No><No>2</No><No>1</No></Preset>"
  )
  local data = sequenceData.read(source)
  lu.assertError(edits.apply, data, {}, {
    { row = data.cues[1].rows[1], pool = 2, slot = 20, name = "unknown_1" },
  })
end

function tests.testWritesTheRepresentativeValueAlongsideItsReference()
  local source = sequenceData.read(SOURCE)
  local output = edits.apply(source, {}, {
    {
      row = source.cues[1].rows[1],
      pool = 2,
      slot = 20,
      name = "unknown_1",
      value = 12,
    },
  })
  lu.assertEquals(sequenceData.read(output).cues[1].rows[1].value, 12)
end

return tests
