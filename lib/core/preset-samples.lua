local function wheel(channel)
  for _, fn in ipairs(channel.functions or {}) do
    if fn.wheel then
      return true
    end
  end
  return false
end

local function targetAttribute(channel, attribute)
  if attribute == "PAN" or attribute == "TILT" then
    return true
  end
  for _, alternative in ipairs(channel.alternatives or {}) do
    if alternative.preset == "COLOR" then
      return true
    end
  end
  return false
end

local function family(definition, row)
  local module = definition.definition.modules[definition.module]
  local channel = module and module[row.attribute]
  if not channel then
    return nil
  end
  if channel.ambiguous then
    if targetAttribute(channel, row.attribute) then
      return nil, nil, "Ambiguous fixture attribute"
    end
    return nil
  end
  if row.attribute == "PAN" or row.attribute == "TILT" then
    return "position", 2
  end
  if channel.preset == "COLOR" then
    return wheel(channel) and "wheel" or "mix", 4
  end
  return nil
end

local function selectedFamily(definition, row, positionOnly)
  if positionOnly and row.attribute ~= "PAN" and row.attribute ~= "TILT" then
    return nil
  end
  return family(definition, row)
end

local function eligible(row)
  return type(row.value) == "number"
    and row.value == row.value
    and math.abs(row.value) < math.huge
    and not row.hasEffect
end

local function labelFor(options, row)
  if options.wheelLabel then
    return options.wheelLabel(row.address, row.attribute, row.value)
  end
end

local function sampleFor(groups, result, row, kind, pool, cue, options)
  local scope = kind
  local label
  if kind == "wheel" then
    label = labelFor(options, row)
    scope = scope .. ":" .. row.attribute .. ":" .. (label or "unknown")
  end
  local key = row.address .. ":" .. scope .. ":part:" .. row.part
  if not groups[key] then
    groups[key] = {
      scope = scope,
      pool = pool,
      kind = kind,
      label = label,
      cue = cue.number,
      values = {},
      rows = {},
    }
    result.samples[#result.samples + 1] = groups[key]
  end
  return groups[key]
end

local function collectCue(cue, definitions, removed, result, options)
  local groups = {}
  for _, row in ipairs(cue.rows) do
    local definition = definitions[row.address]
    if definition and not removed[row.address] and not row.preset then
      local kind, pool, problem =
        selectedFamily(definition, row, options.positionOnly)
      if problem then
        result.skipped[#result.skipped + 1] = { row = row, reason = problem }
      elseif kind and (not options.positionOnly or kind == "position") then
        if eligible(row) then
          local sample =
            sampleFor(groups, result, row, kind, pool, cue, options)
          assert(sample.values[row.attribute] == nil, "Ambiguous raw values")
          sample.values[row.attribute] = row.value
          sample.rows[#sample.rows + 1] = row
        else
          result.skipped[#result.skipped + 1] = {
            row = row,
            reason = "Effect or unknown raw value",
          }
        end
      end
    end
  end
end

local function collect(sequence, definitions, options)
  local result = { samples = {}, skipped = {} }
  local removed = {}
  for _, address in ipairs(options.removed or {}) do
    removed[address] = true
  end
  for _, cue in ipairs(sequence.cues) do
    collectCue(cue, definitions, removed, result, options)
    if options.yield then
      options.yield()
    end
  end
  return result
end

return { collect = collect }
