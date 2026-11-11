local context = require("ma.cleanup-context")
local sequenceData = require("core.sequence-data")
local fixtureType = require("core.fixture-type")

local function chosenSequence(gma)
  local suggested = context.sequence(gma) or "1"
  local number = gma.textinput("Sequence to clean", suggested)
  if not number then
    return nil
  end
  assert(
    number:match("^%d+$") and tonumber(number) > 0 and tonumber(number) < 512,
    "Use a sequence number from 1 to 511"
  )
  return number
end

local function definitionsFor(gma, files, sequence, yield, progress)
  local function fixtureProgress(index, total)
    if progress and (index % 8 == 0 or index == total) then
      progress(
        20 + math.floor(5 * index / total),
        "Reading fixture links " .. index .. " of " .. total
      )
    end
  end
  local located =
    context.fixtures(gma, sequence.addresses, yield, fixtureProgress)
  local types, definitions = {}, {}
  for index, number in ipairs(located.types) do
    if progress then
      progress(
        25 + math.floor(5 * index / #located.types),
        "Reading fixture type " .. index .. " of " .. #located.types
      )
    end
    local exported =
      files.export("FixtureType " .. number, "type-" .. number, "library")
    types[number] = fixtureType.read(exported, yield)
  end
  for address, entry in pairs(located.fixtures) do
    definitions[address] = {
      definition = types[entry.type],
      module = entry.module,
    }
  end
  return definitions
end

local function parseSequence(gma, source, yield, progress)
  local last = gma.gettime()
  return sequenceData.read(source, function(position, total)
    local now = gma.gettime()
    if progress and position and (now - last >= 0.25 or position == total) then
      local percent = math.floor(100 * position / total)
      progress(
        10 + math.floor(percent / 10),
        "Parsing sequence XML: " .. percent .. "%"
      )
      last = now
    end
    if yield then
      yield()
    end
  end)
end

local function read(gma, files, yield, number, progress)
  number = number or chosenSequence(gma)
  if not number then
    return nil
  end
  local handle = gma.show.getobj.handle("Sequence " .. number)
  assert(handle, "Sequence not found")
  if progress then
    progress(6, "Exporting Sequence " .. number)
  end
  files.command("SelectDrive 1")
  local source = files.export("Sequence " .. number, "input")
  local sequence = parseSequence(gma, source, yield, progress)
  assert(#sequence.cues > 0, "Sequence has no cues")
  return {
    number = number,
    sequence = sequence,
    definitions = definitionsFor(gma, files, sequence, yield, progress),
  }
end

local function hintedSeed(gma, pool, sequence, yield)
  if not sequence then
    return nil
  end
  local seen = {}
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      local reference = row.preset
      if
        reference
        and reference[2] == tostring(pool)
        and not seen[reference[3]]
      then
        seen[reference[3]] = true
        local handle =
          gma.show.getobj.handle("Preset " .. pool .. "." .. reference[3])
        if handle then
          return handle
        end
      end
    end
    if yield then
      yield()
    end
  end
end

local function poolHandle(gma, pool, sequence, yield)
  local getobj = gma.show.getobj
  local seed = getobj.handle("Preset " .. pool .. ".1")
    or hintedSeed(gma, pool, sequence, yield)
  if not seed then
    for slot = 2, 10000 do
      seed = getobj.handle("Preset " .. pool .. "." .. slot)
      if seed then
        break
      end
      if yield and slot % 64 == 0 then
        yield()
      end
    end
  end
  if not seed then
    return nil
  end
  local parent = getobj.parent(seed)
  assert(
    parent
      and getobj.class(parent) == "CMD_PRESET_POOL"
      and tostring(getobj.number(parent)) == tostring(pool),
    "Unexpected preset pool"
  )
  return parent
end

local function readPool(gma, parent, pool, occupied, names, yield, progress)
  local getobj = gma.show.getobj
  local total = getobj.amount(parent)
  for index = 0, total - 1 do
    local handle = getobj.child(parent, index)
    if handle then
      local number = getobj.number(handle)
      local slot = tostring(number):match("^" .. pool .. "%.(%d+)$")
      assert(slot, "Unexpected preset address in pool")
      occupied[tonumber(slot)] = true
      local label = getobj.label(handle)
      if label then
        names[label] = true
      end
    end
    if progress and (index % 128 == 0 or index == total - 1) then
      progress(pool, index + 1, total)
    end
    if yield and index % 64 == 0 then
      yield()
    end
  end
end

local function pools(gma, yield, sequence, progress, selected)
  local occupied, names = { [2] = {}, [4] = {} }, {}
  for _, pool in ipairs(selected or { 2, 4 }) do
    local parent = poolHandle(gma, pool, sequence, yield)
    if parent then
      readPool(gma, parent, pool, occupied[pool], names, yield, progress)
    end
  end
  return occupied, names
end

return { read = read, pools = pools, choose = chosenSequence }
