local lu = require("luaunit")

local SOURCE = [[<MA><Sequ index="0"><Cue><Number number="1"/><CueDatas>
<CueData><Channel fixture_id="1" channel_id="0" attribute_name="DIM"/>
<Value>0</Value></CueData><CueData><Channel fixture_id="1" channel_id="0"
attribute_name="PAN"/><Value>12</Value></CueData><CueData>
<Channel fixture_id="2" channel_id="0"
attribute_name="DIM"/><Value>100</Value></CueData><CueData>
<Channel fixture_id="2" channel_id="0" attribute_name="PAN"/>
<Value>10</Value></CueData></CueDatas></Cue></Sequ></MA>]]
local TYPE = [[<MA><FixtureType index="1"><Modules><Module index="0">
<ChannelType attribute="DIM" preset="DIMMER" default="0"/>
<ChannelType attribute="PAN" preset="POSITION"/>
</Module></Modules></FixtureType></MA>]]

local function memoryFiles(data)
  return {
    open = function(path, mode)
      if mode == "rb" then
        if not data[path] then
          return nil, "missing file " .. path
        end
        return {
          read = function()
            return data[path]
          end,
          close = function()
            return true
          end,
        }
      end
      assert(mode == "wb")
      return {
        write = function(_, content)
          data[path] = content
          return true
        end,
        close = function()
          return true
        end,
      }
    end,
  }
end

local function session(file, options)
  options = options or {}
  local events, messages, data, titles = {}, {}, {}, {}
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
  local gma = {
    echo = function() end,
    sleep = function() end,
    gettime = function()
      return 1
    end,
    export_json = function() end,
    textinput = function(title)
      return title == "Sequence to clean" and "1" or (options.tolerance or "0")
    end,
    cmd = function(command)
      events[#events + 1] = command
      local basename = command:match('Export Sequence 1 "([^"]+)"')
      if basename then
        data["MEM/importexport/" .. basename .. ".xml"] = SOURCE
      end
      basename = command:match('Export FixtureType 2 "([^"]+)"')
      if basename then
        data["MEM/library/" .. basename .. ".xml"] = TYPE
      end
      if command == "Copy Sequence 1 At Sequence 2" then
        objects["Sequence 2"] = {}
      end
      local imported = command:match('Import "[^"]+" At (Preset [^ ]+)')
      if imported then
        objects[imported] = {}
      end
      if command:find(" At Sequence 1 ", 1, true) then
        if options.failImport then
          return "sequence import failed"
        end
        local name = command:match('Import "([^"]+)"')
        data.output = data["MEM/importexport/" .. name]
      end
    end,
    user = {
      getselectedexec = function()
        return { number = "1.1" }
      end,
    },
    show = {
      getvar = function()
        return "MEM"
      end,
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
        return not options.cancel
      end,
      msgbox = function(title, message)
        titles[#titles + 1] = title
        messages[#messages + 1] = message
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
  local environment = setmetatable({ gma = gma, io = memoryFiles(data) }, {
    __index = _G,
  })
  local start = assert(loadfile("test/bundles/" .. file, "t", environment))()
  start()
  return events, messages, data, titles
end

local tests = {}

function tests.testCleanupBundleRemovesOnlyUnusedFixtures()
  local events, messages, data = session("k-sequence-cleanup.lua")
  lu.assertStrContains(
    table.concat(events, "|"),
    "Copy Sequence 1 At Sequence 2"
  )
  lu.assertNotStrContains(table.concat(events, "|"), "At Preset")
  lu.assertNotStrContains(data.output, 'fixture_id="1"')
  lu.assertStrContains(messages[#messages], "Done")
end

function tests.testPositionBundleRetainsFixturesAndCreatesPreset()
  local events, _, data = session("k-sequence-position-presets.lua")
  lu.assertStrContains(table.concat(events, "|"), "At Preset 2.1")
  lu.assertStrContains(data.output, 'fixture_id="1"')
  lu.assertStrContains(data.output, "<No>2</No><No>1</No>")
end

function tests.testPositionToleranceChangesOnlyEligiblePositionValues()
  local _, _, exact = session("k-sequence-position-presets.lua")
  local _, _, nearby = session("k-sequence-position-presets.lua", {
    tolerance = "5",
  })
  lu.assertStrContains(exact.output, "<Value>10</Value>")
  lu.assertNotStrContains(nearby.output, "<Value>10</Value>")
  lu.assertStrContains(nearby.output, "<Value>12</Value>")
end

function tests.testCancelChangesNoSequence()
  local events = session("k-sequence-cleanup.lua", { cancel = true })
  lu.assertNotStrContains(table.concat(events, "|"), "Copy Sequence")
end

function tests.testImportFailureReportsBackup()
  local _, messages = session("k-sequence-cleanup.lua", { failImport = true })
  lu.assertStrContains(messages[#messages], "sequence import failed")
  lu.assertStrContains(messages[#messages], "Sequence 2")
end

function tests.testPositionFailureUsesPositionTitle()
  local _, messages, _, titles =
    session("k-sequence-position-presets.lua", { failImport = true })
  lu.assertStrContains(messages[#messages], "sequence import failed")
  lu.assertEquals(titles[#titles], "Sequence position presets stopped")
end

return tests
