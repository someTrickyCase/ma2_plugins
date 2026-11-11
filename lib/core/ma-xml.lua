local ENTITIES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }

local function validCodepoint(number)
  for _, range in ipairs({
    { 9, 10 },
    { 13, 13 },
    { 32, 0xD7FF },
    { 0xE000, 0xFFFD },
    { 0x10000, 0x10FFFF },
  }) do
    if number >= range[1] and number <= range[2] then
      return true
    end
  end
  return false
end

local function codepoint(value)
  local hex = value:match("^#x([%da-fA-F]+)$")
  local decimal = value:match("^#(%d+)$")
  local number = hex and tonumber(hex, 16) or tonumber(decimal or "")
  assert(number, "Unknown XML entity")
  assert(validCodepoint(number), "Invalid XML code point")
  return utf8.char(number)
end

local function decode(value)
  local stripped = value:gsub("&[^;]*;", "")
  assert(not stripped:find("&", 1, true), "Unclosed XML entity")
  local decoded = value:gsub("&([^;]*);", function(entity)
    return ENTITIES[entity] or codepoint(entity)
  end)
  return decoded
end

local function attributes(rest)
  local found = {}
  while rest:find("%S") do
    local key, quote, first =
      rest:match("^%s+([%a_:][%w_:.-]*)%s*=%s*([\"'])()")
    assert(key, "Invalid XML attribute")
    assert(found[key] == nil, "Duplicate XML attribute")
    local last = assert(rest:find(quote, first, true), "Unclosed attribute")
    local value = rest:sub(first, last - 1)
    assert(not value:find("<", 1, true), "Invalid attribute value")
    found[key] = decode(value)
    rest = rest:sub(last + 1)
  end
  return found
end

local function tagEnd(source, position)
  while true do
    local nextIndex = assert(source:find("[\"'>]", position), "Unclosed tag")
    local character = source:sub(nextIndex, nextIndex)
    if character == ">" then
      return nextIndex
    end
    position = assert(
      source:find(character, nextIndex + 1, true),
      "Unclosed tag quote"
    ) + 1
  end
end

local function text(state, value, literal)
  local parent = state.stack[#state.stack]
  if parent then
    parent.text = parent.text .. (literal and value or decode(value))
  else
    assert(not value:find("%S"), "Text outside root element")
  end
end

local function skip(state, opening, ending)
  local first = state.position + #opening
  local last = assert(
    state.source:find(ending, first, true),
    "Unclosed XML declaration or comment"
  )
  state.position = last + #ending
  return state.source:sub(first, last - 1)
end

local function close(state, body, last)
  local name = body:match("^/([%a_:][%w_:.-]*)%s*$")
  local node = state.stack[#state.stack]
  assert(node and node.tag == name, "Mismatched XML closing tag")
  node.last = last
  state.stack[#state.stack] = nil
end

local function open(state, body, last)
  local empty = body:sub(-1) == "/"
  if empty then
    body = body:sub(1, -2)
  end
  local name, rest = body:match("^([%a_:][%w_:.-]*)(.*)$")
  assert(name, "Invalid XML element name")
  local node = {
    tag = name,
    attributes = attributes(rest),
    children = {},
    text = "",
    first = state.position,
    last = empty and last or nil,
  }
  local parent = state.stack[#state.stack]
  if parent then
    parent.children[#parent.children + 1] = node
  else
    assert(not state.root, "Multiple XML root elements")
    state.root = node
  end
  if not empty then
    assert(#state.stack < 64, "XML nesting limit reached")
    state.stack[#state.stack + 1] = node
  end
end

local function markup(state)
  local start = state.position
  local source = state.source
  if source:sub(start, start + 3) == "<!--" then
    skip(state, "<!--", "-->")
  elseif source:sub(start, start + 8) == "<![CDATA[" then
    text(state, skip(state, "<![CDATA[", "]]>"), true)
  elseif source:sub(start, start + 1) == "<?" then
    skip(state, "<?", "?>")
  else
    assert(source:sub(start, start + 1) ~= "<!", "Unsupported XML declaration")
    local last = tagEnd(source, start + 1)
    local body = source:sub(start + 1, last - 1)
    if body:sub(1, 1) == "/" then
      close(state, body, last)
    else
      open(state, body, last)
    end
    state.position = last + 1
  end
end

local function advance(state)
  local first = state.source:find("<", state.position, true)
  if not first then
    text(state, state.source:sub(state.position))
    state.position = #state.source + 1
    return
  end
  text(state, state.source:sub(state.position, first - 1))
  state.position = first
  markup(state)
end

local function parse(source, yield)
  assert(not source:find("[%z\1-\8\11\12\14-\31]"), "Invalid XML character")
  local position = source:sub(1, 3) == string.char(239, 187, 191) and 4 or 1
  local state = { source = source, position = position, stack = {} }
  local amount = 0
  local reported = 0
  while state.position <= #source do
    local previous = state.position
    advance(state)
    assert(state.position > previous, "XML reader made no progress")
    amount = amount + 1
    assert(amount <= 1000000, "XML size limit reached")
    if yield and amount % 1024 == 0 then
      reported = math.min(state.position, #source)
      yield(reported, #source)
    end
  end
  assert(state.root and #state.stack == 0, "Incomplete XML document")
  if yield and reported < #source then
    yield(#source, #source)
  end
  return state.root
end

local function streamClose(state, name, last)
  local depth = #state.stack
  assert(state.stack[depth] == name, "Mismatched XML closing tag")
  state.stack[depth] = nil
  return { kind = "close", tag = name, depth = depth, last = last }
end

local function streamOpen(state, body, first, last)
  local empty = body:sub(-1) == "/"
  if empty then
    body = body:sub(1, -2)
  end
  local name, rest = body:match("^([%a_:][%w_:.-]*)(.*)$")
  assert(name, "Invalid XML element name")
  if #state.stack == 0 then
    assert(not state.root, "Multiple XML root elements")
    state.root = true
  end
  assert(#state.stack < 64, "XML nesting limit reached")
  state.stack[#state.stack + 1] = name
  if empty then
    state.pending = { name = name, last = last }
  end
  return {
    kind = "open",
    tag = name,
    attributes = attributes(rest),
    depth = #state.stack,
    first = first,
    last = last,
  }
end

local function streamText(state, value, literal)
  local parent = state.stack[#state.stack]
  if not parent then
    assert(not value:find("%S"), "Text outside root element")
    return nil
  end
  return {
    kind = "text",
    tag = parent,
    text = literal and value or decode(value),
    depth = #state.stack,
  }
end

local function streamMarkup(state)
  local start, source = state.position, state.source
  if source:sub(start, start + 3) == "<!--" then
    skip(state, "<!--", "-->")
  elseif source:sub(start, start + 8) == "<![CDATA[" then
    return streamText(state, skip(state, "<![CDATA[", "]]>"), true)
  elseif source:sub(start, start + 1) == "<?" then
    skip(state, "<?", "?>")
  else
    assert(source:sub(start, start + 1) ~= "<!", "Unsupported XML declaration")
    local last = tagEnd(source, start + 1)
    local body = source:sub(start + 1, last - 1)
    state.position = last + 1
    if body:sub(1, 1) == "/" then
      local name = body:match("^/([%a_:][%w_:.-]*)%s*$")
      assert(name, "Invalid XML closing tag")
      return streamClose(state, name, last)
    end
    return streamOpen(state, body, start, last)
  end
end

local function streamAdvance(state)
  if state.source:sub(state.position, state.position) == "<" then
    return streamMarkup(state)
  end
  local first = state.position
  state.position = state.source:find("<", first, true) or #state.source + 1
  return streamText(state, state.source:sub(first, state.position - 1))
end

local function tokens(source, yield)
  assert(not source:find("[%z\1-\8\11\12\14-\31]"), "Invalid XML character")
  local state = {
    source = source,
    stack = {},
    position = source:sub(1, 3) == string.char(239, 187, 191) and 4 or 1,
  }
  local amount = 0
  return function()
    if state.pending then
      local pending = state.pending
      state.pending = nil
      return streamClose(state, pending.name, pending.last)
    end
    while state.position <= #source do
      local previous = state.position
      local token = streamAdvance(state)
      assert(state.position > previous, "XML stream made no progress")
      amount = amount + 1
      assert(amount <= 2000000, "XML size limit reached")
      if amount % 256 == 0 then
        collectgarbage("step", 256)
      end
      if yield and amount % 2048 == 0 then
        yield(math.min(state.position, #source), #source)
      end
      if token then
        return token
      end
    end
    assert(state.root and #state.stack == 0, "Incomplete XML document")
    if not state.finished then
      state.finished = true
      if yield then
        yield(#source, #source)
      end
    end
    return nil
  end
end

return { parse = parse, tokens = tokens }
