local lu = require("luaunit")
local checkRules = require("tools.check-rules")

local find = checkRules.findViolations

local function at(line, rule)
  return { line = line, rule = rule }
end

local tests = {}

function tests.testCleanCodeHasNoViolations()
  lu.assertEquals(find("local x = 1\nreturn x\n"), {})
end

function tests.testFindsNonAsciiByte()
  local text = "local a = 1\nlocal b = '" .. string.char(0xC3, 0xA9) .. "'\n"
  lu.assertEquals(find(text), { at(2, "ascii") })
end

function tests.testFindsTab()
  lu.assertEquals(find("if x then\n\treturn x\nend\n"), { at(2, "ascii") })
end

function tests.testFindsLineComment()
  lu.assertEquals(find("local x = 1\nlocal y = 2 -- note\n"), {
    at(2, "comment"),
  })
end

function tests.testFindsBlockCommentOnceAtItsStart()
  local text = "local x = 1\n--[[ one\ntwo ]]\nreturn x\n"
  lu.assertEquals(find(text), { at(2, "comment") })
end

function tests.testFindsLeveledBlockComment()
  local text = "--[==[ a ]] still -- inside ]==]\nreturn 1 -- tail\n"
  lu.assertEquals(find(text), { at(1, "comment"), at(2, "comment") })
end

function tests.testIgnoresDashesInDoubleQuotedString()
  lu.assertEquals(find('local s = "a -- b"\n'), {})
end

function tests.testIgnoresDashesInSingleQuotedStringWithEscapes()
  lu.assertEquals(find("local s = 'it\\'s -- fine'\n"), {})
end

function tests.testIgnoresDashesInLongStrings()
  local text = "local a = [[ -- ]]\nlocal b = [=[ ]] -- ]=]\n"
  lu.assertEquals(find(text), {})
end

function tests.testFindsCommentAfterLongString()
  lu.assertEquals(find("local s = [[a]] -- note\n"), { at(1, "comment") })
end

function tests.testSortsViolationsByLine()
  local text = "-- a\nlocal b = '" .. string.char(0xFF) .. "'\n"
  lu.assertEquals(find(text), { at(1, "comment"), at(2, "ascii") })
end

function tests.testReportFormatsOneLinePerViolation()
  local files = {
    { path = "a.lua", text = "return 1 -- hi\n" },
    { path = "b.lua", text = "return 2\n" },
  }
  lu.assertEquals(checkRules.report(files), {
    "a.lua:1: comment: code must explain itself, no comments",
  })
end

function tests.testReportNamesAsciiRule()
  local files = { { path = "c.lua", text = "\treturn 1\n" } }
  lu.assertEquals(checkRules.report(files), {
    "c.lua:1: ascii: only printable ASCII characters are allowed",
  })
end

return tests
