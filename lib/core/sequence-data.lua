local xml = require("core.ma-xml")

local function children(node, tag)
  local found = {}
  for _, item in ipairs(node.children) do
    if item.tag == tag then
      found[#found + 1] = item
    end
  end
  return found
end

local function child(node, tag)
  return children(node, tag)[1]
end

local function identifier(value)
  assert(type(value) == "string", "Missing channel identity")
  assert(
    value:match("^%d+$") or value:match("^%d+%.%d+$"),
    "Invalid channel identity"
  )
  return value
end

local function address(fixture, channel)
  if tonumber(fixture) > 0 then
    return "Fixture " .. fixture
  end
  assert(tonumber(channel) > 0, "Channel has no addressable identity")
  return "Channel " .. channel
end

local function preset(node)
  if not node then
    return nil
  end
  local numbers = {}
  for _, item in ipairs(children(node, "No")) do
    numbers[#numbers + 1] = identifier(item.text)
  end
  assert(#numbers == 3, "Unsupported preset reference")
  return numbers
end

local function row(node)
  local channel = assert(child(node, "Channel"), "Missing channel")
  local attrs = channel.attributes
  local fixtureId = identifier(attrs.fixture_id)
  local channelId = identifier(attrs.channel_id)
  local value = child(node, "Value")
  local valueText = value and value.text
  return {
    fixture = fixtureId,
    channel = channelId,
    address = address(fixtureId, channelId),
    attribute = assert(attrs.attribute_name, "Missing attribute name"),
    value = tonumber(valueText),
    valueText = valueText,
    preset = preset(child(node, "Preset")),
    hasEffect = child(node, "Effect") ~= nil
      or child(node, "EffectFlags") ~= nil,
    part = node.attributes.value_multipart_index or "0",
    effectPart = node.attributes.effect_multipart_index or "0",
    node = { first = node.first, last = node.last },
  }
end

local function cueNumber(node)
  local whole = identifier(node.attributes.number)
  local sub = tonumber(node.attributes.sub_number or "0")
  assert(
    sub and sub >= 0 and sub < 1000 and sub % 1 == 0,
    "Invalid cue sub-number"
  )
  if sub == 0 then
    return whole
  end
  local suffix = string.format("%03d", sub):gsub("0+$", "")
  return whole .. "." .. suffix
end

local function cue(node, rows)
  local number = child(node, "Number")
  if not number then
    assert(node.attributes["xsi:nil"] == "true", "Cue has no number")
    return nil
  end
  local result = { number = cueNumber(number), rows = {}, node = node }
  local seen = {}
  for _, entry in ipairs(rows) do
    local key = entry.address .. ":" .. entry.attribute .. ":" .. entry.part
    assert(not seen[key], "Duplicate channel value within cue part")
    seen[key] = true
    result.rows[#result.rows + 1] = entry
  end
  return result
end

local function openNode(state, token)
  local node = {
    tag = token.tag,
    attributes = token.attributes,
    text = "",
    children = {},
    first = token.first,
    last = token.last,
    openLast = token.last,
  }
  local parent = state.stack[#state.stack]
  local transient = state.rows
    and parent
    and parent.tag == "CueDatas"
    and node.tag == "CueData"
  if parent and not transient then
    parent.children[#parent.children + 1] = node
  end
  if token.tag == "Sequ" and token.depth == 2 then
    assert(not state.result.node, "Multiple sequences")
    state.result.node = node
  end
  if parent == state.result.node and node.tag == "Cue" then
    state.activeCue, state.rows = node, {}
  end
  state.stack[#state.stack + 1] = node
end

local function retainCue(state, node)
  local entry = cue(node, state.rows)
  if entry then
    state.result.cues[#state.result.cues + 1] = entry
    for _, channel in ipairs(entry.rows) do
      if not state.seen[channel.address] then
        state.seen[channel.address] = true
        local addresses = state.result.addresses
        addresses[#addresses + 1] = channel.address
      end
    end
  end
  state.activeCue, state.rows = nil, nil
end

local function closeNode(state, token)
  local node = state.stack[#state.stack]
  state.stack[#state.stack] = nil
  node.last = token.last
  local parent = state.stack[#state.stack]
  if node.tag == "CueData" and state.rows and parent.tag == "CueDatas" then
    state.rows[#state.rows + 1] = row(node)
  elseif node == state.activeCue then
    retainCue(state, node)
  end
end

local function read(source, yield)
  local state = {
    stack = {},
    seen = {},
    result = { source = source, cues = {}, addresses = {} },
  }
  local nextToken = xml.tokens(source, yield)
  while true do
    local token = nextToken()
    if not token then
      break
    end
    if token.kind == "open" then
      openNode(state, token)
    elseif token.kind == "close" then
      closeNode(state, token)
    else
      local node = state.stack[#state.stack]
      node.text = node.text .. token.text
    end
  end
  assert(state.result.node, "Expected one sequence")
  return state.result
end

return { read = read }
