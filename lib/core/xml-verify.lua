local xml = require("core.ma-xml")
local sequenceData = require("core.sequence-data")

local function valueEqual(left, right)
  if left == right then
    return true
  end
  local a, b = tonumber(left), tonumber(right)
  if not a or not b or a == 0 or b == 0 then
    return false
  end
  return math.abs(a - b) <= math.max(math.abs(a), math.abs(b)) * 0.000001
end

local function ignored(node, key, options)
  return (options.referenceNames and node.tag == "Preset" and key == "name")
    or (options.index and node.tag == "Sequ" and key == "index")
    or (options.name and node.tag == "Sequ" and key == "name")
end

local function attributes(left, right, options)
  for key, value in pairs(left.attributes) do
    if not ignored(left, key, options) then
      local other = right.attributes[key]
      local equal = value == other
      if key == "Value" then
        equal = valueEqual(value, other)
      end
      assert(equal, "Different XML attribute: " .. left.tag .. "." .. key)
    end
  end
  for key in pairs(right.attributes) do
    assert(
      ignored(right, key, options) or left.attributes[key] ~= nil,
      "Unexpected XML attribute: " .. right.tag .. "." .. key
    )
  end
end

local function channelKey(node)
  for _, child in ipairs(node.children) do
    if child.tag == "Channel" then
      local attrs = child.attributes
      return (attrs.fixture_id or "")
        .. ":"
        .. (attrs.channel_id or "")
        .. ":"
        .. (attrs.attribute_name or "")
    end
  end
  return node.tag
end

local function ordered(node)
  if node.tag ~= "Channels" then
    return node.children
  end
  local found = {}
  for index, child in ipairs(node.children) do
    found[index] = child
  end
  table.sort(found, function(left, right)
    return channelKey(left) < channelKey(right)
  end)
  return found
end

local function compare(left, right, options)
  assert(left.tag == right.tag, "Different XML element")
  attributes(left, right, options)
  local a = left.text:match("^%s*(.-)%s*$")
  local b = right.text:match("^%s*(.-)%s*$")
  if left.tag == "Value" then
    assert(valueEqual(a, b), "Different stored value")
  else
    assert(a == b, "Different XML text: " .. left.tag)
  end
  local before, after = ordered(left), ordered(right)
  assert(#before == #after, "Different child count: " .. left.tag)
  for index, node in ipairs(before) do
    compare(node, after[index], options)
  end
  options.count = options.count + 1
  if options.yield and options.count % 1024 == 0 then
    options.yield()
  end
end

local function object(source, tag, yield)
  local root = xml.parse(source, yield)
  local result
  for _, node in ipairs(root.children) do
    if node.tag == tag then
      assert(not result, "Multiple XML objects")
      result = node
    end
  end
  return assert(result, "Missing XML object")
end

local function check(expected, actual, tag, options)
  options.count = 0
  local ok, problem = pcall(function()
    compare(
      object(expected, tag, options.yield),
      object(actual, tag, options.yield),
      options
    )
  end)
  if not ok then
    return nil, tostring(problem)
  end
  return true
end

local function normalized(source, yield)
  local nextToken = xml.tokens(source, yield)
  local pending
  return function()
    while true do
      local token = pending or nextToken()
      pending = nil
      if not token or token.kind ~= "text" then
        return token
      end
      local parts = { token.text }
      local nextItem = nextToken()
      while nextItem and nextItem.kind == "text" do
        parts[#parts + 1] = nextItem.text
        nextItem = nextToken()
      end
      pending = nextItem
      token.text = table.concat(parts):match("^%s*(.-)%s*$")
      if token.text ~= "" then
        return token
      end
    end
  end
end

local function sequenceStart(nextToken)
  while true do
    local token = nextToken()
    assert(token, "Missing XML sequence")
    if token.kind == "open" and token.tag == "Sequ" and token.depth == 2 then
      return token
    end
  end
end

local function finishDocument(nextToken)
  while true do
    local token = nextToken()
    if not token then
      return
    end
    assert(
      not (token.kind == "open" and token.tag == "Sequ" and token.depth == 2),
      "Multiple XML sequences"
    )
  end
end

local function compareToken(left, right, options)
  assert(
    left.kind == right.kind and left.tag == right.tag,
    "Different XML sequence structure"
  )
  if left.kind == "open" then
    attributes(left, right, options)
  elseif left.kind == "text" then
    local equal = left.text == right.text
    if left.tag == "Value" then
      equal = valueEqual(left.text, right.text)
    end
    assert(equal, "Different XML sequence text: " .. left.tag)
  end
end

local function compareSequence(expected, actual, options)
  local left = normalized(expected, options.yield)
  local right = normalized(actual, options.yield)
  local before, after = sequenceStart(left), sequenceStart(right)
  while true do
    assert(before and after, "Incomplete XML sequence")
    compareToken(before, after, options)
    if
      before.kind == "close"
      and before.tag == "Sequ"
      and before.depth == 2
    then
      break
    end
    before, after = left(), right()
  end
  finishDocument(left)
  finishDocument(right)
end

local function sequence(expected, actual, ignoreIndex, yield, ignoreName)
  local ok, problem = pcall(compareSequence, expected, actual, {
    referenceNames = true,
    index = ignoreIndex,
    name = ignoreName,
    yield = yield,
  })
  if not ok then
    return nil, tostring(problem)
  end
  return true
end

local function envelope(source, yield)
  local nextToken = xml.tokens(source, yield)
  local count = 0
  while true do
    local token = nextToken()
    if not token then
      break
    end
    if token.kind == "open" and token.tag == "Sequ" and token.depth == 2 then
      count = count + 1
      assert(count == 1, "Multiple XML sequences")
    end
  end
  assert(count == 1, "Missing XML sequence")
end

local function snapshotEqual(parsed, actual, options)
  local expected = parsed.node
  local opening = sequenceStart(xml.tokens(actual, options.yield))
  attributes(expected, opening, options)
  local body = parsed.source:sub(expected.openLast + 1, expected.last)
  local last = opening.last + #body
  if actual:sub(opening.last + 1, last) ~= body then
    return false
  end
  envelope(
    actual:sub(1, opening.last) .. "</Sequ>" .. actual:sub(last + 1),
    options.yield
  )
  return true
end

local function snapshot(parsed, actual, ignoreIndex, yield, ignoreName)
  if parsed.node and parsed.node.openLast then
    local ok, equal = pcall(snapshotEqual, parsed, actual, {
      referenceNames = true,
      index = ignoreIndex,
      name = ignoreName,
      yield = yield,
    })
    if ok and equal then
      return true
    end
  end
  return sequence(parsed.source, actual, ignoreIndex, yield, ignoreName)
end

local function preset(expected, actual, yield)
  return check(expected, actual, "Preset", { yield = yield })
end

local function metadata(node)
  local result = {
    tag = node.tag,
    attributes = node.attributes,
    text = node.text,
    children = {},
  }
  for _, child in ipairs(node.children) do
    if child.tag ~= "CueDatas" then
      result.children[#result.children + 1] = child
    end
  end
  return result
end

local function update(state, rows)
  for _, row in ipairs(rows) do
    if row.valueText ~= nil then
      local key = row.fixture .. ":" .. row.channel .. ":" .. row.attribute
      state[key] = {
        value = row.valueText,
        preset = row.preset and table.concat(row.preset, ".") or "",
      }
    end
  end
end

local function compareTracking(expected, actual, yield)
  local before = sequenceData.read(expected, yield)
  local after = sequenceData.read(actual, yield)
  assert(#before.cues == #after.cues, "Cue count changed during tracking")
  local left, right = {}, {}
  local options = { count = 0, referenceNames = true, yield = yield }
  for index, cue in ipairs(before.cues) do
    local other = after.cues[index]
    compare(metadata(cue.node), metadata(other.node), options)
    update(left, cue.rows)
    update(right, other.rows)
    for key, value in pairs(left) do
      local readback = right[key]
      assert(
        readback
          and valueEqual(value.value, readback.value)
          and value.preset == readback.preset,
        "Tracked value/reference changed"
      )
    end
    if yield then
      yield()
    end
  end
end

local function tracking(expected, actual, yield)
  local ok, problem = pcall(compareTracking, expected, actual, yield)
  if not ok then
    return nil, tostring(problem)
  end
  return true
end

return {
  sequence = sequence,
  snapshot = snapshot,
  preset = preset,
  tracking = tracking,
}
