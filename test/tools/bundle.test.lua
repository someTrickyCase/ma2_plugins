local lu = require("luaunit")
local bundle = require("tools.bundle")
local checkRules = require("tools.check-rules")
local fakeGma = require("test.support.fake-gma")

local STAMP = { commit = "abc1234", date = "2026-10-24" }

local MANIFEST = [[
return { name = "Answer", file = "k-answer", version = "1.2.3" }
]]

local function fileSystem(files)
  return function(path)
    return files[path]
  end
end

local function partsWith(main, modules)
  return {
    name = "Answer",
    file = "k-answer",
    version = "1.2.3",
    commit = STAMP.commit,
    date = STAMP.date,
    modules = modules or {},
    main = main,
  }
end

local function run(parts, environment, ...)
  environment = environment or {}
  environment.gma = environment.gma or { echo = function() end }
  setmetatable(environment, { __index = _G })
  local chunk = assert(load(bundle.lua(parts), "=bundle", "t", environment))
  return chunk(...)
end

local function readRealFile(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local text = file:read("a")
  file:close()
  return text
end

local tests = {}

function tests.testModulePathMapsDotsToFolders()
  lu.assertEquals(bundle.modulePath("core.swap-ids"), "lib/core/swap-ids.lua")
end

function tests.testCollectReadsManifestAndStamp()
  local read = fileSystem({
    ["plugins/answer/plugin.lua"] = MANIFEST,
    ["plugins/answer/main.lua"] = "return 1\n",
  })
  local parts = bundle.collect("answer", read, STAMP)
  lu.assertEquals(parts, partsWith("return 1\n"))
end

function tests.testCollectFollowsRequiresOnce()
  local read = fileSystem({
    ["plugins/answer/plugin.lua"] = MANIFEST,
    ["plugins/answer/main.lua"] = 'local a = require("ma.a")\n'
      .. 'local b = require("core.b")\n',
    ["lib/ma/a.lua"] = 'return require("core.b")\n',
    ["lib/core/b.lua"] = "return {}\n",
  })
  local parts = bundle.collect("answer", read, STAMP)
  lu.assertEquals(parts.modules, {
    { name = "ma.a", text = 'return require("core.b")\n' },
    { name = "core.b", text = "return {}\n" },
  })
end

function tests.testCollectLeavesOutsideModulesToMa()
  local read = fileSystem({
    ["plugins/answer/plugin.lua"] = MANIFEST,
    ["plugins/answer/main.lua"] = 'local socket = require("socket.core")\n',
  })
  lu.assertEquals(bundle.collect("answer", read, STAMP).modules, {})
end

function tests.testBundleReturnsWhatMainReturns()
  lu.assertEquals(run(partsWith("return 42\n")), 42)
end

function tests.testMainGetsThePluginArguments()
  local first, second =
    run(partsWith("return ...\n"), nil, "plugin_1", "Answer")
  lu.assertEquals({ first, second }, { "plugin_1", "Answer" })
end

function tests.testMainCanRequireBundledModule()
  local parts = partsWith('return require("core.b").value\n', {
    { name = "core.b", text = "return { value = 42 }\n" },
  })
  lu.assertEquals(run(parts), 42)
end

function tests.testModulesCanRequireEachOther()
  local parts = partsWith('return require("ma.a").value\n', {
    { name = "ma.a", text = 'return { value = require("core.b") }\n' },
    { name = "core.b", text = "return 42\n" },
  })
  local environment = {
    require = function(name)
      error("real require used for " .. name)
    end,
  }
  lu.assertEquals(run(parts, environment), 42)
end

function tests.testModuleIsLoadedOnlyOnce()
  local parts = partsWith(
    'return rawequal(require("core.b"), require("core.b"))\n',
    { { name = "core.b", text = "return {}\n" } }
  )
  lu.assertTrue(run(parts))
end

function tests.testUnknownModuleFallsBackToRealRequire()
  local environment = {
    require = function(name)
      return "real " .. name
    end,
  }
  local parts = partsWith('return require("socket.core")\n')
  lu.assertEquals(run(parts, environment), "real socket.core")
end

function tests.testBundleEchoesVersionStampOnLoad()
  local echoes = {}
  local environment = {
    gma = {
      echo = function(text)
        echoes[#echoes + 1] = text
      end,
    },
  }
  run(partsWith("return 1\n"), environment)
  lu.assertEquals(echoes, { "Answer 1.2.3 (abc1234, 2026-10-24)" })
end

function tests.testBundleFollowsOurOwnRules()
  local parts = partsWith("return 1\n", {
    { name = "core.b", text = "return 2\n" },
  })
  lu.assertEquals(checkRules.findViolations(bundle.lua(parts)), {})
end

function tests.testXmlPointsToTheLuaFile()
  local xml = bundle.xml(partsWith("return 1\n"))
  lu.assertStrContains(xml, 'name="Answer"')
  lu.assertStrContains(xml, 'luafile="k-answer.lua"')
  lu.assertStrContains(xml, 'datetime="2026-10-24T00:00:00"')
end

function tests.testXmlEscapesSpecialCharacters()
  local parts = partsWith("return 1\n")
  parts.name = 'Fix & "Cha" <1>'
  local xml = bundle.xml(parts)
  lu.assertStrContains(xml, 'name="Fix &amp; &quot;Cha&quot; &lt;1&gt;"')
end

function tests.testCollectReadsPluginSlot()
  local read = fileSystem({
    ["plugins/answer/plugin.lua"] = 'return { name = "Answer", slot = 101 }',
    ["plugins/answer/main.lua"] = "return 1\n",
  })
  lu.assertEquals(bundle.collect("answer", read, STAMP).slot, 101)
end

local function partsInSlot(slot)
  local parts = partsWith("return 1\n")
  parts.slot = slot
  return parts
end

function tests.testInstructionsListCommandsInOrder()
  lu.assertEquals(bundle.instructions(partsInSlot(101)), {
    "MA2 commands, paste them in this order:",
    "",
    "  1. Only when updating, remove the old copy:",
    "     Delete Plugin 101",
    "  2. Load the plugin into the pool:",
    '     Import "k-answer.xml" At Plugin 101',
    "  3. Run it (on a show copy first!):",
    "     Plugin 101",
  })
end

function tests.testInstructionsSlotCanBeOverridden()
  local lines = bundle.instructions(partsInSlot(101), 5)
  lu.assertEquals(lines[4], "     Delete Plugin 5")
  lu.assertEquals(lines[6], '     Import "k-answer.xml" At Plugin 5')
  lu.assertEquals(lines[8], "     Plugin 5")
end

function tests.testCommandLinesHoldOnlyTheCommand()
  local lines = bundle.instructions(partsInSlot(101))
  for _, index in ipairs({ 4, 6, 8 }) do
    lu.assertStrMatches(lines[index], "     %S.*%S")
    lu.assertNil(lines[index]:find("  ", 6, true))
  end
end

function tests.testInstructionsNeedASlot()
  lu.assertErrorMsgContains("no plugin slot", function()
    bundle.instructions(partsWith("return 1\n"))
  end)
end

function tests.testRealChannelToFixtureBundleMovesIds()
  local parts = bundle.collect("channel-to-fixture", readRealFile, STAMP)
  local fake = fakeGma.new({
    layers = {
      { name = "fren", fixtures = { { name = "Dim 1", chaId = "801" } } },
    },
  })
  local environment = {
    gma = fake.gma,
    require = function(name)
      error("real require used for " .. name)
    end,
  }
  local start = run(parts, environment, "plugin_1", "Channel to Fixture")
  start()
  lu.assertEquals(fake.propsAt(1, 1).FixId, "801")
  lu.assertEquals(fake.propsAt(1, 1).ChaId, "-")
end

return tests
