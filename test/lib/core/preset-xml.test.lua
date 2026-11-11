local lu = require("luaunit")
local presetXml = require("core.preset-xml")

local function channel(attribute, value)
  return { fixture = "1", channel = "1", attribute = attribute, value = value }
end

local tests = {}

function tests.testWritesSelectivePositionPresetWithZeroBasedIndex()
  local xml = presetXml.build(15, "unknown_1", {
    channel("PAN", -120),
    channel("TILT", 30),
  })
  lu.assertStrContains(xml, '<Preset index="14" name="unknown_1"')
  lu.assertStrContains(xml, '<PresetValue Value="-120">')
  lu.assertStrContains(xml, 'attribute_name="PAN"')
  lu.assertStrContains(xml, '<PresetValue Value="30">')
  lu.assertStrContains(xml, 'attribute_name="TILT"')
  lu.assertStrContains(xml, 'fixture_id="1" channel_id="1"')
  lu.assertStrContains(xml, "<Values><Channels>")
  lu.assertStrContains(xml, "</Channels></Values></Preset></MA>")
end

function tests.testEscapesXmlNamesAndAttributes()
  local xml = presetXml.build(1, 'unknown_1 & "A"', {
    channel('A&B"<>', 0),
  })
  lu.assertStrContains(xml, 'name="unknown_1 &amp; &quot;A&quot;"')
  lu.assertStrContains(xml, 'attribute_name="A&amp;B&quot;&lt;&gt;"')
end

function tests.testRetainsTinyPositiveValues()
  local xml = presetXml.build(1, "unknown_1", { channel("DIM", 0.00001) })
  local value = xml:match('<PresetValue Value="([^"]+)"')
  lu.assertEquals(tonumber(value), 0.00001)
end

function tests.testRetainsDoublePrecision()
  local original = 64.1234567890123
  local xml = presetXml.build(1, "unknown_1", { channel("TILT", original) })
  lu.assertEquals(tonumber(xml:match('<PresetValue Value="([^"]+)"')), original)
end

function tests.testAllowsInstanceFixtureIdentifiers()
  local row = channel("PAN", 10)
  row.fixture = "10.2"
  local xml = presetXml.build(1, "unknown_1", { row })
  lu.assertStrContains(xml, 'fixture_id="10.2"')
end

function tests.testRejectsInvalidSlots()
  for _, slot in ipairs({ 0, -1, 1.5, math.huge, "1" }) do
    lu.assertError(presetXml.build, slot, "unknown_1", { channel("PAN", 0) })
  end
end

function tests.testRejectsInvalidValues()
  for _, value in ipairs({ "Release", math.huge, 0 / 0 }) do
    lu.assertError(presetXml.build, 1, "unknown_1", { channel("PAN", value) })
  end
end

function tests.testRejectsEmptyPresetsAndBadIdentifiers()
  lu.assertError(presetXml.build, 1, "unknown_1", {})
  local row = channel("PAN", 0)
  row.fixture = "1; ClearAll"
  lu.assertError(presetXml.build, 1, "unknown_1", { row })
end

function tests.testRejectsDuplicateFixtureAttributes()
  lu.assertError(presetXml.build, 1, "unknown_1", {
    channel("PAN", 10),
    channel("PAN", 20),
  })
end

function tests.testRejectsXmlControlCharacters()
  lu.assertError(presetXml.build, 1, "unknown" .. string.char(1), {
    channel("PAN", 0),
  })
end

return tests
