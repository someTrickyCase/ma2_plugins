local xml = require("core.ma-xml")

local function children(node, tag)
  local found = {}
  for _, child in ipairs(node.children) do
    if child.tag == tag then
      found[#found + 1] = child
    end
  end
  return found
end

local function child(node, tag)
  return children(node, tag)[1] or { children = {} }
end

local function ranges(node)
  local found = {}
  for _, item in ipairs(children(node, "ChannelSet")) do
    local attrs = item.attributes
    local low = tonumber(attrs.from_dmx)
    local high = tonumber(attrs.to_dmx)
    assert(low and high and low >= 0 and high >= low, "Invalid channel range")
    found[#found + 1] = {
      minimum = low,
      maximum = high,
      name = attrs.name,
      slot = attrs.slot_index,
      split = attrs.slot_from
        and attrs.slot_to
        and attrs.slot_from ~= attrs.slot_to,
    }
  end
  return found
end

local function channel(node)
  local attrs = node.attributes
  local bits = 8
  if attrs.fine then
    bits = 16
  end
  if attrs.ultra then
    bits = 24
  end
  local result = {
    default = tonumber(attrs.default),
    bits = bits,
    preset = attrs.preset,
    functions = {},
  }
  for _, fn in ipairs(children(node, "ChannelFunction")) do
    local wheel = tonumber(fn.attributes.wheel)
    result.functions[#result.functions + 1] = {
      subattribute = fn.attributes.subattribute,
      wheel = wheel and tostring(wheel - 1),
      sets = ranges(fn),
    }
  end
  return result
end

local function addChannel(channels, attribute, entry)
  local previous = channels[attribute]
  if not previous then
    channels[attribute] = entry
  elseif previous.ambiguous then
    previous.alternatives[#previous.alternatives + 1] = entry
  else
    channels[attribute] = {
      ambiguous = true,
      alternatives = { previous, entry },
      functions = {},
    }
  end
end

local function modules(node)
  local found = {}
  for _, item in ipairs(children(node, "Module")) do
    local index = assert(item.attributes.index, "Missing module index")
    assert(not found[index], "Duplicate module index")
    local channels = {}
    for _, entry in ipairs(children(item, "ChannelType")) do
      local attribute = assert(entry.attributes.attribute, "Missing attribute")
      addChannel(channels, attribute, channel(entry))
    end
    found[index] = channels
  end
  return found
end

local function wheels(node)
  local found = {}
  for _, item in ipairs(children(node, "Wheel")) do
    local index = assert(item.attributes.index, "Missing wheel index")
    assert(not found[index], "Duplicate wheel index")
    local slots = {}
    for _, slot in ipairs(children(item, "Slot")) do
      local key = assert(slot.attributes.index, "Missing slot index")
      assert(slots[key] == nil, "Duplicate wheel slot")
      slots[key] = slot.attributes.media_name or ""
    end
    found[index] = slots
  end
  return found
end

local function read(source, yield)
  local root = xml.parse(source, yield)
  local types = children(root, "FixtureType")
  assert(#types == 1, "Expected exactly one fixture type")
  local node = types[1]
  return {
    index = node.attributes.index,
    modules = modules(child(node, "Modules")),
    wheels = wheels(child(node, "Wheels")),
  }
end

local function setLabel(definition, fn, set)
  if not set.split then
    local wheel = definition.wheels[fn.wheel]
    local name = wheel and wheel[set.slot]
    if name and name ~= "" then
      return name
    end
  end
  return set.name
end

local function matchingSets(definition, selected, attribute, dmx)
  local labels = {}
  for _, fn in ipairs(selected.functions) do
    if fn.subattribute == attribute and fn.wheel then
      for _, set in ipairs(fn.sets) do
        if dmx >= set.minimum and dmx <= set.maximum then
          labels[#labels + 1] = setLabel(definition, fn, set) or ""
        end
      end
    end
  end
  return labels
end

local function wheelLabel(definition, moduleIndex, attribute, dmx)
  local module = definition.modules[moduleIndex]
  local selected = module and module[attribute]
  if not selected then
    return nil
  end
  local labels = matchingSets(definition, selected, attribute, dmx)
  if #labels == 1 and labels[1] ~= "" then
    return labels[1]
  end
  return nil
end

return { read = read, wheelLabel = wheelLabel }
