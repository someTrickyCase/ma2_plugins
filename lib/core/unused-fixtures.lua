local function finite(value)
  return type(value) == "number"
    and value == value
    and value > -math.huge
    and value < math.huge
end

local function dimmer(value)
  if value > 0 then
    return "lit"
  end
  return value == 0 and "dark" or "unknown"
end

local function brightness(definition, value)
  if not finite(value) then
    return "unknown"
  end
  if definition.hasDimmer then
    return dimmer(value)
  end
  if not definition.closedRanges or #definition.closedRanges == 0 then
    return "unknown"
  end
  for _, range in ipairs(definition.closedRanges) do
    if value >= range.minimum and value <= range.maximum then
      return "dark"
    end
  end
  return "lit"
end

local function rowBrightness(definition, row)
  local value = row.value
  if definition.hasDimmer and row.valueText == "Release" then
    value = 0
  end
  return brightness(definition, value)
end

local function observe(state, definition, row, cueIndex)
  local attribute = definition.hasDimmer and "DIM" or "SHUTTER"
  if row.attribute ~= attribute then
    return
  end
  local status = rowBrightness(definition, row)
  state.lit = state.lit or status == "lit"
  state.unknown = state.unknown
    or status == "unknown"
    or row.hasEffect
    or row.preset ~= nil
  if cueIndex == 1 and row.valueText ~= nil then
    state.initial = true
  end
end

local function statesFor(sequence, definitions, yield)
  local states = {}
  for _, address in ipairs(sequence.addresses) do
    states[address] = { initial = false }
  end
  for index, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      local definition = definitions[row.address]
      if definition then
        observe(states[row.address], definition, row, index)
      end
    end
    if yield then
      yield()
    end
  end
  return states
end

local function shutterVerdict(state, definition)
  if not state.initial then
    local initial = brightness(definition, definition.default)
    state.lit = state.lit or initial == "lit"
    state.unknown = state.unknown or initial == "unknown"
  end
  if state.lit then
    return "keep"
  end
  return state.unknown and "uncertain" or "remove"
end

local function verdict(state, definition)
  if not definition or definition.hasDimmer == nil then
    return "uncertain"
  end
  if definition.hasDimmer then
    return state.lit and "keep" or "remove"
  end
  return shutterVerdict(state, definition)
end

local function plan(sequence, definitions, yield)
  local result = { remove = {}, keep = {}, uncertain = {} }
  local states = statesFor(sequence, definitions, yield)
  for _, address in ipairs(sequence.addresses) do
    local action = verdict(states[address], definitions[address])
    if action == "uncertain" then
      result.uncertain[#result.uncertain + 1] = {
        address = address,
        reason = "Light output cannot be proven dark",
      }
    else
      result[action][#result[action] + 1] = address
    end
  end
  return result
end

return { plan = plan }
