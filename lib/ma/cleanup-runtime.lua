local filesAdapter = require("ma.cleanup-files")
local reader = require("ma.cleanup-read")
local writer = require("ma.cleanup-write")
local planner = require("core.cleanup-plan")
local fixtureType = require("core.fixture-type")
local conflictGroup = require("ma.conflict-group")
local cooperate = require("ma.cooperate")
local sequencePresets = require("core.sequence-presets")

local TITLE = "Sequence cleanup"

local function step(gma, title)
  local text = gma.textinput(title .. " tolerance (stored values)", "5")
  if not text then
    return nil
  end
  local value = tonumber(text)
  assert(
    value and value == value and value >= 0 and value < math.huge,
    "Tolerance must be a finite nonnegative number"
  )
  return value
end

local function wheelLabel(definitions, address, attribute, value)
  local entry = definitions[address]
  local module = entry.definition.modules[entry.module]
  local channel = module and module[attribute]
  if not channel or channel.bits ~= 8 or value < 0 or value > 100 then
    return nil
  end
  local dmx = math.floor(value * 255 / 100 + 0.5)
  return fixtureType.wheelLabel(entry.definition, entry.module, attribute, dmx)
end

local function reviewFixtures(plan)
  local found, seen = {}, {}
  local function add(address)
    if seen[address] then
      return
    end
    local kind, id = address:match("^(%a+) ([%d.]+)$")
    assert(kind and id, "Unknown review fixture address")
    local fixture = { name = address }
    fixture[kind == "Fixture" and "fixId" or "chaId"] = id
    found[#found + 1] = fixture
    seen[address] = true
  end
  for _, entry in ipairs(plan.uncertain) do
    add(entry.address)
  end
  for _, entry in ipairs(plan.skipped) do
    add(entry.row.address)
  end
  return found
end

local function hasEffects(sequence)
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      if row.hasEffect then
        return true
      end
    end
  end
  return false
end

local function manualTracking(gma, number)
  local lines = {
    {
      "Enable tracking for the cleaned sequence.",
      "Assign Sequence " .. number .. " /Track=On",
    },
    { "Block the sequence's cues.", "Block Sequence " .. number },
    { "Remove redundant blocks.", "Unblock Sequence " .. number },
  }
  for index, item in ipairs(lines) do
    gma.echo(item[1])
    gma.echo(index .. ". " .. item[2])
  end
end

local function finishTracking(files, input)
  local object = "Sequence " .. input.number
  files.command("Assign " .. object .. " /Track=On")
  files.command("Block " .. object)
  files.command("Unblock " .. object)
end
local function summary(plan, mode)
  if mode == "position" then
    return string.format(
      "Create %d position presets; replace %d values.",
      #plan.presets,
      #plan.references
    )
  end
  return string.format(
    "Remove %d fixtures; create %d presets; replace %d values.",
    #plan.remove,
    #plan.presets,
    #plan.references
  )
end

local function new(gma, dependencies)
  dependencies = dependencies or {}
  local mode = dependencies.mode
  assert(
    mode == "unused" or mode == "position" or mode == "combined",
    "Unknown sequence workflow mode"
  )
  local title = mode == "position" and "Sequence position presets" or TITLE
  local files = dependencies.files or filesAdapter.new(gma)
  local progress, settings, pools, manual
  local yield = cooperate.new(gma)
  local lastStatus = -math.huge
  local writes

  local function cleanup()
    if progress then
      gma.gui.progress.stop(progress)
      progress = nil
    end
  end

  local function stage(percent, text, force)
    if not progress then
      progress = gma.gui.progress.start(title)
      gma.gui.progress.setrange(progress, 0, 100)
    end
    gma.gui.progress.settext(progress, text)
    gma.gui.progress.set(progress, percent)
    local now = gma.gettime()
    if force ~= false or now - lastStatus >= 1 then
      gma.export_json("sequence-cleanup-status.json", {
        text,
        "Progress " .. percent .. "/100",
        "Time " .. now,
      })
      lastStatus = now
    end
    yield()
  end

  writes = writer.new(gma, files, yield, function(percent, text, force)
    stage(percent, text, force)
  end)

  local function prepare()
    local number = reader.choose(gma)
    if not number then
      return nil
    end
    settings = { mode = mode, yield = yield }
    if mode ~= "unused" then
      local tolerance =
        step(gma, mode == "position" and "Position" or "Mixing color")
      if tolerance == nil then
        return nil
      end
      settings[mode == "position" and "positionStep" or "colorStep"] = tolerance
    end
    stage(5, "Reading sequence and fixture definitions")
    return reader.read(gma, files, yield, number, function(percent, text)
      stage(percent, text, false)
    end)
  end

  local function plan(input)
    if mode == "unused" then
      return planner.plan(input.sequence, input.definitions, settings)
    end
    stage(30, "Finding unused preset slots and names")
    settings.occupied, settings.names = reader.pools(
      gma,
      yield,
      input.sequence,
      function(pool, done, total)
        local base = pool == 2 and 30 or 35
        stage(
          base + math.floor(5 * done / total),
          "Reading preset pool " .. pool .. ": " .. done .. " of " .. total,
          false
        )
      end,
      mode == "position" and { 2 } or nil
    )
    settings.yield = yield
    settings.wheelLabel = function(address, attribute, value)
      return wheelLabel(input.definitions, address, attribute, value)
    end
    stage(45, "Planning fixture cleanup and presets")
    return planner.plan(input.sequence, input.definitions, settings)
  end

  local function presetAddresses(input, prepared)
    if mode == "unused" then
      return {}
    end
    local addresses = sequencePresets.collect(input.sequence, prepared)
    if mode ~= "position" then
      return addresses
    end
    local positions = {}
    for _, address in ipairs(addresses) do
      if address:match("^Preset 2%.") then
        positions[#positions + 1] = address
      end
    end
    return positions
  end

  local function mark(prepared)
    stage(60, "Marking fixtures that need review")
    gma.echo(summary(prepared, mode))
    for _, address in ipairs(prepared.remove) do
      gma.echo("Removal candidate: " .. address)
    end
    local fixtures = reviewFixtures(prepared)
    if #fixtures > 0 then
      local problem
      pools, problem = conflictGroup.create(gma, fixtures)
      assert(pools, problem)
    end
  end

  local function confirm(input, prepared)
    cleanup()
    if
      #prepared.remove == 0
      and #prepared.references == 0
      and #presetAddresses(input, prepared) == 0
    then
      gma.gui.msgbox(title, "No eligible changes. Review uncertain fixtures.")
      return false
    end
    local text = "Sequence "
      .. input.number
      .. "|"
      .. summary(prepared, mode)
      .. "|Uncertain fixtures are not removed. Unsupported raw values are kept."
      .. "|A backup sequence below 512 will be created first."
    if mode == "position" then
      text = text
        .. "|Position tolerance: "
        .. settings.positionStep
        .. ". Nearby values within each cue part may change."
    end
    if mode ~= "unused" then
      text = text .. "|Position presets will receive green borders."
    end
    if pools then
      text = text
        .. "|Review Conflicts Group "
        .. pools.group
        .. " and Layout "
        .. pools.layout
        .. "."
    end
    return gma.gui.confirm(title, text .. "|Apply this plan?")
  end

  local function apply(input, prepared)
    stage(70, "Backing up and applying the plan")
    writes.apply(input, prepared)
    manual = hasEffects(input.sequence)
    if not manual then
      stage(90, "Enabling tracking, blocking and unblocking")
      finishTracking(files, input)
    end
    local addresses = presetAddresses(input, prepared)
    for index, address in ipairs(addresses) do
      stage(
        95 + math.floor(5 * index / #addresses),
        "Marking sequence preset " .. index .. " of " .. #addresses,
        false
      )
      files.command("Appearance " .. address .. " /r=0 /g=100 /b=0")
    end
  end

  local function done(input, prepared)
    cleanup()
    local result = summary(prepared, mode)
    if mode == "position" then
      result = string.format(
        "Position presets created: %d; values replaced: %d.",
        #prepared.presets,
        #prepared.references
      )
    end
    local text = "Done. " .. result .. "|" .. writes.recovery()
    if manual then
      manualTracking(gma, input.number)
      text = text
        .. "|Effects are present. Finish Tracking/Block/Unblock"
        .. " manually using the numbered commands in System Monitor."
    end
    gma.gui.msgbox(title, text)
  end

  return {
    title = title,
    prepare = prepare,
    plan = plan,
    mark = mark,
    confirm = confirm,
    apply = apply,
    done = done,
    cleanup = cleanup,
    recovery = writes.recovery,
  }
end

return { new = new }
