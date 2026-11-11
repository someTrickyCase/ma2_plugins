local lu = require("luaunit")
local flow = require("ma.cleanup-flow")
local runtime = require("ma.cleanup-runtime")

local SOURCE = [[<MA><Sequ index="0"><Cue><Number number="1"/><CueDatas>
<CueData><Channel fixture_id="1" channel_id="0" attribute_name="DIM"/>
<Value>0</Value></CueData><CueData><Channel fixture_id="2" channel_id="0"
attribute_name="DIM"/><Value>100</Value></CueData><CueData>
<Channel fixture_id="2" channel_id="0" attribute_name="PAN"/>
<Value>10</Value></CueData></CueDatas></Cue></Sequ></MA>]]
local TYPE = [[<MA><FixtureType index="1"><Modules><Module index="0">
<ChannelType attribute="DIM" preset="DIMMER" default="0"/>
<ChannelType attribute="PAN" preset="POSITION"/>
</Module></Modules></FixtureType></MA>]]

local function setup(effects, existing, mode)
  mode = mode or "combined"
  local input = SOURCE
  if existing then
    input = input:gsub(
      "</CueDatas>",
      [[<CueData><Channel fixture_id="2"
channel_id="0" attribute_name="COLOR1"/><Value>10</Value>
<Preset><No>1</No><No>4</No><No>90</No></Preset></CueData></CueDatas>]]
    )
  end
  if effects then
    input = input:gsub(
      "<Value>100</Value>",
      '<Value>100</Value><EffectFlags form_index="1"/>'
    )
  end
  local events, messages, saved, prompts = {}, {}, {}, {}
  local sequence = { number = "1", class = "CMD_SEQUENCE", children = {} }
  local objects = {
    ["Sequence 1"] = sequence,
    ["Executor 1.1 Cue 1"] = { parent = sequence },
  }
  for id = 1, 2 do
    objects["Fixture " .. id] = {
      children = {
        { properties = { ["Fixture|Type"] = "2 Generic" } },
      },
    }
  end
  local files = {
    save = function(tag, content)
      saved[tag] = content
    end,
    command = function(command)
      events[#events + 1] = command
      if command == "Copy Sequence 1 At Sequence 2" then
        objects["Sequence 2"] = {}
      end
    end,
    import = function(address)
      events[#events + 1] = "Import " .. address
      objects[address] = objects[address] or {}
    end,
    export = function(_, tag)
      if tag == "type-2" then
        return TYPE
      end
      assert(tag == "input", "Unexpected verification export: " .. tag)
      return input
    end,
  }
  local gma = {
    echo = function() end,
    sleep = function() end,
    gettime = function()
      return 1
    end,
    export_json = function() end,
    textinput = function(title)
      prompts[#prompts + 1] = title
      if title == "Sequence to clean" then
        return "1"
      end
      return "5"
    end,
    user = {
      getselectedexec = function()
        return { number = "1.1" }
      end,
    },
    show = {
      getobj = {
        handle = function(address)
          return objects[address]
        end,
        number = function(handle)
          return handle.number
        end,
        class = function(handle)
          return handle.class
        end,
        parent = function(handle)
          return handle.parent
        end,
        amount = function(handle)
          return #handle.children
        end,
        child = function(handle, index)
          return handle.children[index + 1]
        end,
        label = function() end,
      },
      property = {
        get = function(handle, name)
          if name == "Track" then
            return "On"
          end
          return handle.properties[name]
        end,
      },
    },
    gui = {
      confirm = function()
        return true
      end,
      msgbox = function(_, text)
        messages[#messages + 1] = text
      end,
      progress = {
        start = function()
          return 1
        end,
        setrange = function() end,
        set = function() end,
        settext = function() end,
        stop = function() end,
      },
    },
  }
  local instance = flow.new(gma, function()
    return runtime.new(gma, { files = files, mode = mode })
  end)
  return instance, events, messages, saved, prompts
end

local tests = {}

function tests.testRejectsUnknownModeBeforeConsoleAccess()
  local gma = setmetatable({}, {
    __index = function()
      error("console accessed")
    end,
  })
  lu.assertErrorMsgContains(
    "Unknown sequence workflow mode",
    runtime.new,
    gma,
    { mode = "typo" }
  )
end

function tests.testCompleteSessionBacksUpImportsAndFinishesStaticTracking()
  local instance, events, messages, saved = setup()
  instance.start()
  lu.assertEquals(events, {
    "SelectDrive 1",
    "Copy Sequence 1 At Sequence 2",
    "Import Preset 2.1",
    "Import Sequence 1",
    "Assign Sequence 1 /Track=On",
    "Block Sequence 1",
    "Unblock Sequence 1",
    "Appearance Preset 2.1 /r=0 /g=100 /b=0",
  })
  lu.assertNotStrContains(saved.output, 'fixture_id="1"')
  lu.assertStrContains(saved.output, "<No>2</No><No>1</No>")
  lu.assertStrContains(messages[#messages], "Done")
end

function tests.testWriteCompletesWithoutSequenceVerification()
  local instance, events, messages = setup()
  instance.start()
  lu.assertEquals(events[#events - 1], "Unblock Sequence 1")
  lu.assertStrContains(messages[#messages], "Done")
  lu.assertStrContains(messages[#messages], "Sequence 2")
end

function tests.testEffectSequencesFinishWithManualTrackingInstructions()
  local instance, events, messages = setup(true)
  instance.start()
  lu.assertEquals(events[#events], "Appearance Preset 2.1 /r=0 /g=100 /b=0")
  lu.assertStrContains(messages[#messages], "Finish Tracking/Block/Unblock")
  lu.assertStrContains(messages[#messages], "manually")
end

function tests.testMarksExistingSequencePresetsAlongsideNewPresets()
  local instance, events, messages = setup(false, true)
  instance.start()
  lu.assertEquals(events[#events - 1], "Appearance Preset 2.1 /r=0 /g=100 /b=0")
  lu.assertEquals(events[#events], "Appearance Preset 4.90 /r=0 /g=100 /b=0")
  lu.assertStrContains(messages[#messages], "Done")
end

function tests.testUnusedModeDoesNotPromptForToleranceOrTouchPresets()
  local instance, events, _, saved, prompts = setup(false, true, "unused")
  instance.start()
  lu.assertEquals(prompts, { "Sequence to clean" })
  lu.assertNotStrContains(table.concat(events, "|"), "Preset")
  lu.assertNil(saved["preset-1"])
end

function tests.testPositionModeRestoresPromptAndRetainsDarkFixtures()
  local instance, events, _, saved, prompts = setup(false, true, "position")
  instance.start()
  lu.assertEquals(prompts, {
    "Sequence to clean",
    "Position tolerance (stored values)",
  })
  lu.assertStrContains(saved.output, 'fixture_id="1"')
  lu.assertNotStrContains(table.concat(events, "|"), "Preset 4.")
end

function tests.testPositionSuccessReportsOnlyPresetsAndReplacedValues()
  local instance, _, messages = setup(false, false, "position")
  instance.start()
  local message = messages[#messages]
  lu.assertStrContains(
    message,
    "Position presets created: 1; values replaced: 1."
  )
  lu.assertNotStrContains(message, "fixtures")
  lu.assertNotStrContains(message, "Remove")
  lu.assertStrContains(message, "Sequence 2")
end

return tests
