local unused = require("core.unused-fixtures")
local samples = require("core.preset-samples")
local clusters = require("core.preset-clusters")
local presetXml = require("core.preset-xml")
local sequenceEdits = require("core.sequence-edits")

local function copy(source)
  local found = {}
  for key, value in pairs(source or {}) do
    found[key] = value
  end
  return found
end

local function lightDefinition(module, calibrated)
  local dimmer = module.DIM
  if dimmer then
    return { hasDimmer = true, default = dimmer.default }
  end
  return calibrated or { hasDimmer = false }
end

local function lightsFor(definitions)
  local found = {}
  for address, entry in pairs(definitions) do
    local module = entry.definition.modules[entry.module]
    local dimmer = module and module.DIM
    if module and not (dimmer and dimmer.ambiguous) then
      found[address] = lightDefinition(module, entry.light)
    end
  end
  return found
end

local function positionValues(group, options)
  group.valuesByRow = {}
  local grouped =
    clusters.plan(group.members, options.positionStep or 0, options.yield)
  for _, cluster in ipairs(grouped.groups) do
    for _, member in ipairs(cluster.members) do
      for _, row in ipairs(member.rows) do
        group.valuesByRow[row] = cluster.values[row.attribute]
      end
    end
  end
end

local function positionGroups(samplesList, found, options)
  local positions = {}
  for _, sample in ipairs(samplesList) do
    local part = sample.rows[1].part
    local key = sample.cue .. ":" .. part
    if not positions[key] then
      local label = "cue_" .. sample.cue
      if part ~= "0" then
        label = label .. "_part_" .. part
      end
      positions[key] = { members = {}, label = label, position = true }
      found[#found + 1] = positions[key]
    end
    local members = positions[key].members
    members[#members + 1] = sample
  end
  if options.mode == "position" then
    for _, group in pairs(positions) do
      positionValues(group, options)
    end
  end
end

local function groupsFor(collected, options)
  local lists = { position = {}, mix = {}, wheel = {} }
  for _, sample in ipairs(collected.samples) do
    local list = lists[sample.kind]
    list[#list + 1] = sample
  end
  local found = {}
  local steps = { mix = options.colorStep or 5, wheel = 0 }
  local kinds = options.mode == "position" and {} or { "mix", "wheel" }
  for _, kind in ipairs(kinds) do
    local plan = clusters.plan(lists[kind], steps[kind], options.yield)
    for _, group in ipairs(plan.groups) do
      found[#found + 1] = group
    end
  end
  positionGroups(lists.position, found, options)
  return found
end

local function storedValue(group, row)
  if group.valuesByRow then
    return group.valuesByRow[row]
  end
  return group.position and row.value or group.values[row.attribute]
end

local function freeSlot(occupied)
  for slot = 1, 10000 do
    if not occupied[slot] then
      occupied[slot] = true
      return slot
    end
  end
  error("No free preset slots")
end

local function freeName(names, label)
  local base = label or "unknown"
  if label and not names[base] then
    names[base] = true
    return base
  end
  for suffix = 1, 10000 do
    local candidate = base .. "_" .. suffix
    if not names[candidate] then
      names[candidate] = true
      return candidate
    end
  end
  error("No free preset names")
end

local function presetFor(group, occupied, names)
  local sample = group.members[1]
  local slot = freeSlot(occupied[sample.pool])
  local name = freeName(names, group.label or sample.label)
  local channels = {}
  local seen = {}
  for _, member in ipairs(group.members) do
    for _, row in ipairs(member.rows) do
      local key = row.fixture .. ":" .. row.channel .. ":" .. row.attribute
      if not seen[key] then
        seen[key] = true
        channels[#channels + 1] = {
          fixture = row.fixture,
          channel = row.channel,
          attribute = row.attribute,
          value = storedValue(group, row),
        }
      end
    end
  end
  return {
    pool = sample.pool,
    slot = slot,
    name = name,
    channels = channels,
    xml = presetXml.build(slot, name, channels),
  }
end

local function addReferences(references, group, preset)
  for _, member in ipairs(group.members) do
    for _, row in ipairs(member.rows) do
      references[#references + 1] = {
        row = row,
        pool = preset.pool,
        slot = preset.slot,
        name = preset.name,
        value = storedValue(group, row),
      }
    end
  end
end

local function removalPlan(sequence, definitions, options)
  if options.mode ~= "position" then
    return unused.plan(sequence, lightsFor(definitions), options.yield)
  end
  local result = { remove = {}, uncertain = {} }
  for _, address in ipairs(sequence.addresses) do
    if not definitions[address] then
      result.uncertain[#result.uncertain + 1] = {
        address = address,
        reason = "Fixture mapping is not verified",
      }
    end
  end
  return result
end

local function plan(sequence, definitions, options)
  local removal = removalPlan(sequence, definitions, options)
  local collected = { samples = {}, skipped = {} }
  if options.mode ~= "unused" then
    collected = samples.collect(sequence, definitions, {
      removed = removal.remove,
      wheelLabel = options.wheelLabel,
      yield = options.yield,
      positionOnly = options.mode == "position",
    })
  end
  local occupied = options.occupied or {}
  occupied = { [2] = copy(occupied[2]), [4] = copy(occupied[4]) }
  local names = copy(options.names)
  local result = {
    remove = removal.remove,
    uncertain = removal.uncertain,
    skipped = collected.skipped,
    presets = {},
    references = {},
  }
  for _, group in ipairs(groupsFor(collected, options)) do
    local preset = presetFor(group, occupied, names)
    result.presets[#result.presets + 1] = preset
    addReferences(result.references, group, preset)
    if options.yield then
      options.yield()
    end
  end
  result.xml = sequenceEdits.apply(sequence, result.remove, result.references)
  return result
end

return { plan = plan }
