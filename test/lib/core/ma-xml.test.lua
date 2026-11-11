local lu = require("luaunit")
local xml = require("core.ma-xml")

local tests = {}

function tests.testAcceptsUtf8BomWithoutChangingSourceSpans()
  local source = string.char(239, 187, 191) .. "<MA/>"
  local node = xml.parse(source)
  lu.assertEquals(node.first, 4)
  lu.assertEquals(source:sub(node.first, node.last), "<MA/>")
end

function tests.testReadsAttributesChildrenAndText()
  local node =
    xml.parse('<MA version="3"><Value unit="percent">12</Value></MA>')
  lu.assertEquals(node.tag, "MA")
  lu.assertEquals(node.attributes, { version = "3" })
  lu.assertEquals(node.children[1].tag, "Value")
  lu.assertEquals(node.children[1].text, "12")
end

function tests.testPreservesExactSourceSpans()
  local source = '<MA>\n <Value x="1"> 2 </Value>\n</MA>'
  local node = xml.parse(source).children[1]
  lu.assertEquals(source:sub(node.first, node.last), '<Value x="1"> 2 </Value>')
end

function tests.testReadsSelfClosingNodesAndNamespacedAttributes()
  local node = xml.parse('<MA><Cue xsi:nil="true" /></MA>').children[1]
  lu.assertEquals(node.attributes["xsi:nil"], "true")
  lu.assertEquals(node.children, {})
end

function tests.testQuotedGreaterThanDoesNotEndTag()
  local node = xml.parse([[<MA label='A > B' other="C > D"/>]])
  lu.assertEquals(node.attributes.label, "A > B")
  lu.assertEquals(node.attributes.other, "C > D")
end

function tests.testDecodesEntitiesExactlyOnce()
  local node = xml.parse('<MA x="&amp;lt;">&lt;&gt;&amp;&quot;&apos;</MA>')
  lu.assertEquals(node.attributes.x, "&lt;")
  lu.assertEquals(node.text, [[<>&"']])
end

function tests.testDecodesNumericUnicodeReferences()
  local node = xml.parse("<MA>&#65;&#x42;&#x1F600;</MA>")
  lu.assertEquals(node.text, "AB" .. utf8.char(0x1F600))
end

function tests.testSkipsDeclarationsAndComments()
  local node = xml.parse('<?xml version="1.0"?>\n<!-- note -->\n<MA/>')
  lu.assertEquals(node.tag, "MA")
end

function tests.testCdataDoesNotDecodeEntities()
  local node = xml.parse("<MA><![CDATA[A < B &amp; C]]></MA>")
  lu.assertEquals(node.text, "A < B &amp; C")
end

function tests.testRejectsMalformedOrUnsupportedXml()
  for _, source in ipairs({
    "",
    "<MA>",
    "<MA></Other>",
    "<MA/><Other/>",
    '<MA x="1" x="2"/>',
    "<MA>&unknown;</MA>",
    '<!DOCTYPE MA SYSTEM "external.xml"><MA/>',
    "<MA x=1/>",
    "<MA>&#0;</MA>",
    "<MA>&#xD800;</MA>",
    "<MA/ >",
    "text<MA/>",
    "<MA/><!-- unfinished",
  }) do
    lu.assertError(xml.parse, source)
  end
end

function tests.testRejectsDeepNesting()
  lu.assertError(xml.parse, string.rep("<A>", 65) .. string.rep("</A>", 65))
end

function tests.testYieldsDuringLargeReads()
  local calls = 0
  local function yield()
    calls = calls + 1
  end
  local source = "<MA>" .. string.rep('<Channel x="1"/>', 2048) .. "</MA>"
  local node = xml.parse(source, yield)
  lu.assertEquals(#node.children, 2048)
  lu.assertTrue(calls > 0)
end

function tests.testReportsMonotonicByteProgressAndCompletion()
  local source = "<MA>" .. string.rep('<Channel x="1"/>', 2048) .. "</MA>"
  local previous = 0
  xml.parse(source, function(position, total)
    lu.assertEquals(total, #source)
    lu.assertTrue(position >= previous and position <= total)
    previous = position
  end)
  lu.assertEquals(previous, #source)
end

function tests.testStreamsWithoutBuildingElementTrees()
  local nextToken = xml.tokens('<MA><Value x="1">A&amp;B</Value><Empty/></MA>')
  local tags = {}
  while true do
    local token = nextToken()
    if not token then
      break
    end
    lu.assertNil(token.children)
    tags[#tags + 1] = token.kind .. ":" .. token.tag
  end
  lu.assertEquals(tags, {
    "open:MA",
    "open:Value",
    "text:Value",
    "close:Value",
    "open:Empty",
    "close:Empty",
    "close:MA",
  })
end

function tests.testStreamingRejectsMalformedXml()
  for _, source in ipairs({
    "<MA><A></B></MA>",
    '<MA x="1" x="2"/>',
    "<!DOCTYPE MA><MA/>",
    "<MA/>extra",
    "<MA/><Other/>",
    "<MA>",
  }) do
    lu.assertError(function()
      local nextToken = xml.tokens(source)
      while nextToken() do
      end
    end)
  end
end

return tests
