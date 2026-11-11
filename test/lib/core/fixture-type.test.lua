local lu = require("luaunit")
local fixtureType = require("core.fixture-type")

local SOURCE = [[<MA><FixtureType index="1"><Modules><Module index="0">
<ChannelType attribute="DIM" coarse="1"/>
<ChannelType attribute="COLOR1" coarse="2">
<ChannelFunction subattribute="COLOR1" wheel="1">
<ChannelSet name="clear" from_dmx="0" to_dmx="9" slot_index="0"/>
<ChannelSet name="custom red" from_dmx="10" to_dmx="19" slot_index="1"/>
</ChannelFunction>
<ChannelFunction subattribute="COLOR1_SPIN">
<ChannelSet name="rotation" from_dmx="20" to_dmx="255"/>
</ChannelFunction></ChannelType>
<ChannelType attribute="SHUTTER" coarse="3" default="40">
<ChannelFunction subattribute="SHUTTER">
<ChannelSet name="closed" from_dmx="0" to_dmx="31"/>
<ChannelSet name="open" from_dmx="32" to_dmx="63"/>
</ChannelFunction></ChannelType></Module></Modules>
<Wheels><Wheel index="0" attribute="COLOR1">
<Slot index="0" media_name="Open"/>
<Slot index="1" media_name="Red"/>
</Wheel></Wheels></FixtureType></MA>]]

local tests = {}

function tests.testReadsFixtureModuleAttributesAndDefaults()
  local definition = fixtureType.read(SOURCE)
  lu.assertEquals(definition.index, "1")
  lu.assertNotNil(definition.modules["0"].DIM)
  lu.assertEquals(definition.modules["0"].SHUTTER.default, 40)
end

function tests.testWheelLabelsUseFixtureWheelSlotsAtRangeBoundaries()
  local definition = fixtureType.read(SOURCE)
  lu.assertEquals(fixtureType.wheelLabel(definition, "0", "COLOR1", 0), "Open")
  lu.assertEquals(fixtureType.wheelLabel(definition, "0", "COLOR1", 9), "Open")
  lu.assertEquals(fixtureType.wheelLabel(definition, "0", "COLOR1", 10), "Red")
  lu.assertEquals(fixtureType.wheelLabel(definition, "0", "COLOR1", 19), "Red")
end

function tests.testDoesNotNameRotationAsAFixedColor()
  local definition = fixtureType.read(SOURCE)
  lu.assertNil(fixtureType.wheelLabel(definition, "0", "COLOR1", 20))
end

function tests.testUnknownModulesAttributesAndRangesStayUnknown()
  local definition = fixtureType.read(SOURCE)
  lu.assertNil(fixtureType.wheelLabel(definition, "9", "COLOR1", 0))
  lu.assertNil(fixtureType.wheelLabel(definition, "0", "COLOR2", 0))
  lu.assertNil(fixtureType.wheelLabel(definition, "0", "COLOR1", -1))
end

function tests.testFallsBackToChannelSetLabelWhenWheelMediaIsMissing()
  local source = SOURCE:gsub('media_name="Red"', 'media_name=""')
  lu.assertEquals(
    fixtureType.wheelLabel(fixtureType.read(source), "0", "COLOR1", 15),
    "custom red"
  )
end

function tests.testRejectsAmbiguousOverlappingColorRanges()
  local source = SOURCE:gsub('from_dmx="10"', 'from_dmx="9"')
  lu.assertNil(
    fixtureType.wheelLabel(fixtureType.read(source), "0", "COLOR1", 9)
  )
end

function tests.testRetainsSplitColorSetName()
  local source = SOURCE:gsub(
    'name="custom red"',
    'name="Open / Red" slot_from="0" slot_to="1"'
  )
  lu.assertEquals(
    fixtureType.wheelLabel(fixtureType.read(source), "0", "COLOR1", 15),
    "Open / Red"
  )
end

function tests.testReadsNativeDmxPrecisionWithoutConvertingStoredValues()
  local source = SOURCE:gsub(
    'attribute="COLOR1" coarse="2"',
    'attribute="COLOR1" coarse="2" fine="4"'
  )
  lu.assertEquals(fixtureType.read(source).modules["0"].COLOR1.bits, 16)
  lu.assertEquals(fixtureType.read(SOURCE).modules["0"].COLOR1.bits, 8)
end

function tests.testRetainsDuplicateChannelsAsAmbiguous()
  local source = SOURCE:gsub(
    '<ChannelType attribute="DIM" coarse="1"/>',
    '<ChannelType attribute="DUMMY" coarse="1"/>'
      .. '<ChannelType attribute="DUMMY" coarse="2"/>'
  )
  local definition = fixtureType.read(source)
  local entry = definition.modules["0"].DUMMY
  lu.assertTrue(entry.ambiguous)
  lu.assertEquals(#entry.alternatives, 2)
  lu.assertNil(fixtureType.wheelLabel(definition, "0", "DUMMY", 0))
end

function tests.testRejectsMalformedDefinitions()
  lu.assertError(fixtureType.read, "<MA/>")
  lu.assertError(fixtureType.read, SOURCE:gsub('to_dmx="9"', 'to_dmx="-1"'))
end

return tests
