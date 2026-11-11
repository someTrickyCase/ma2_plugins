local lu = require("luaunit")
local verify = require("core.xml-verify")
local sequenceData = require("core.sequence-data")

local tests = {}

function tests.testSequenceIgnoresReferenceLabelsAndOptionalTargetIndex()
  local a =
    '<MA><Sequ index="0"><Preset name="A"><No>2</No></Preset></Sequ></MA>'
  local b =
    '<MA><Sequ index="1"><Preset name="B"><No>2</No></Preset></Sequ></MA>'
  lu.assertTrue(verify.sequence(a, b, true))
  lu.assertNil(verify.sequence(a, b, false))
end

function tests.testBackupMayHaveAnAutomaticNameWhileSourceChecksStayStrict()
  local a = '<MA><Sequ index="0" name="Original"><Value>10</Value></Sequ></MA>'
  local b =
    '<MA><Sequ index="1" name="Original copy"><Value>10</Value></Sequ></MA>'
  lu.assertNil(verify.sequence(a, b, true))
  lu.assertTrue(verify.sequence(a, b, true, nil, true))
  lu.assertNil(verify.sequence(a, b:gsub(">10<", ">20<"), true, nil, true))
end

function tests.testSequenceComparisonValidatesTheWholeDocument()
  local valid = "<MA><Sequ><Value>1</Value></Sequ></MA>"
  lu.assertNil(verify.sequence(valid, valid:gsub("</MA>", "<Sequ/></MA>")))
  lu.assertNil(verify.sequence(valid, valid:gsub("</MA>", "")))
  lu.assertTrue(
    verify.sequence(
      valid,
      '<?xml version="1.0"?><MA><!-- note --><Sequ><Value>1</Value></Sequ></MA>'
    )
  )
end

function tests.testSnapshotChecksEveryBodyByteAndTheDocumentEnvelope()
  local source = '<MA><Info time="1"/><Sequ index="0" name="A"><Cue>'
    .. '<Number number="1"/><CueDatas><CueData><Channel fixture_id="1"'
    .. ' channel_id="0" attribute_name="DIM"/><Value>50</Value>'
    .. "</CueData></CueDatas></Cue></Sequ></MA>"
  local parsed = sequenceData.read(source)
  local backup = source
    :gsub('index="0"', 'index="2"')
    :gsub('name="A"', 'name="A copy"')
    :gsub('time="1"', 'time="2"')
  lu.assertTrue(verify.snapshot(parsed, backup, true, nil, true))
  lu.assertNil(verify.snapshot(parsed, backup, false))
  lu.assertNil(
    verify.snapshot(parsed, backup:gsub(">50<", ">60<"), true, nil, true)
  )
  lu.assertNil(verify.snapshot(parsed, source:gsub("</MA>", "<Sequ/></MA>")))
  lu.assertNil(verify.snapshot(parsed, source:gsub("</MA>", "")))
end

function tests.testSequenceRejectsLostValuesOrChangedTimings()
  local a = '<MA><Sequ><CuePart fade="3"/><Value>10</Value></Sequ></MA>'
  lu.assertNil(verify.sequence(a, a:gsub('fade="3"', 'fade="4"')))
  lu.assertNil(verify.sequence(a, a:gsub("<Value>10</Value>", "")))
end

function tests.testPresetMatchesChannelIdentityRatherThanEntryOrder()
  local a = '<PresetValue Value="1"><Channel fixture_id="1"'
    .. ' attribute_name="PAN"/></PresetValue>'
  local b = '<PresetValue Value="2"><Channel fixture_id="1"'
    .. ' attribute_name="TILT"/></PresetValue>'
  local function document(values)
    return '<MA><Preset name="unknown_1"><Values><Channels>'
      .. values
      .. "</Channels></Values></Preset></MA>"
  end
  lu.assertTrue(verify.preset(document(a .. b), document(b .. a)))
  lu.assertNil(verify.preset(document(a .. b), document(a .. a)))
end

function tests.testAllowsConsoleNumericRoundingButRejectsMeaningfulChanges()
  local a = "<MA><Sequ><Value>10.123456789</Value></Sequ></MA>"
  lu.assertTrue(verify.sequence(a, a:gsub("10.123456789", "10.123457")))
  lu.assertNil(verify.sequence(a, a:gsub("10.123456789", "10.13")))
end

function tests.testTrackingAllowsRedundantValuesToBecomeTracked()
  local row = '<CueData><Channel fixture_id="1" channel_id="0"'
    .. ' attribute_name="DIM"/><Value>50</Value></CueData>'
  local function document(second)
    return '<MA><Sequ><Cue><Number number="1"/><CueDatas>'
      .. row
      .. '</CueDatas></Cue><Cue><Number number="2"/><CueDatas>'
      .. second
      .. "</CueDatas></Cue></Sequ></MA>"
  end
  lu.assertTrue(verify.tracking(document(row), document("")))
  lu.assertNil(
    verify.tracking(
      document(row),
      document(row:gsub("<Value>50</Value>", "<Value>60</Value>"))
    )
  )
end

return tests
