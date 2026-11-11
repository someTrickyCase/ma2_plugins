local modules = {}
local loaded = {}
local realRequire = require
local function require(name)
  local loader = modules[name]
  if not loader then
    return realRequire(name)
  end
  if loaded[name] == nil then
    loaded[name] = loader()
  end
  return loaded[name]
end
modules["ma.cleanup-flow"] = function()
local function new(gma, factory)
  local active

  local function cleanup()
    if active then
      local current = active
      active = nil
      current.cleanup()
    end
  end

  local function run()
    if factory then
      active = factory(gma)
    else
      active = require("ma.cleanup-runtime").new(gma)
    end
    local input = active.prepare()
    if not input then
      return
    end
    local plan = active.plan(input)
    active.mark(plan)
    if not active.confirm(input, plan) then
      gma.echo("Sequence cleanup cancelled; sequence data unchanged.")
      return
    end
    active.apply(input, plan)
    active.done(input, plan)
  end

  local function start()
    local ok, problem = pcall(run)
    local title = active and active.title or "Sequence workflow"
    local recovery = ""
    if active then
      local recovered, result = pcall(active.recovery)
      recovery = recovered and result
        or "Recovery status unavailable: " .. tostring(result)
    end
    local cleaned, cleanupProblem = pcall(cleanup)
    if not cleaned then
      recovery = recovery .. "|Cleanup failed: " .. tostring(cleanupProblem)
    end
    if not ok then
      if gma.export_json then
        pcall(gma.export_json, "sequence-cleanup-error.json", {
          tostring(problem):gsub('[\r\n"]', " "),
          (recovery:gsub('[\r\n"]', " ")),
        })
      end
      gma.gui.msgbox(title .. " stopped", tostring(problem) .. "|" .. recovery)
    end
  end

  return { start = start, cleanup = cleanup }
end

return { new = new }

end
modules["ma.cleanup-runtime"] = function()
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

end
modules["ma.cleanup-files"] = function()
local function read(path)
  local file, problem = io.open(path, "rb")
  assert(file, problem)
  local content, failure = file:read("*a")
  local closed, closing = file:close()
  assert(content, failure)
  assert(closed, closing)
  return content
end

local function write(path, content)
  local file, problem = io.open(path, "wb")
  assert(file, problem)
  local written, failure = file:write(content)
  local closed, closing = file:close()
  assert(written, failure)
  assert(closed, closing)
end

local function new(gma, storage)
  storage = storage or { read = read, write = write }
  local root = gma.show.getvar("PATH")
  assert(type(root) == "string" and root ~= "", "Missing MA2 data path")
  local prefix = "k-sequence-cleanup-"
    .. string.format("%.0f", gma.gettime() * 1000000)
    .. "-"

  local function basename(tag)
    assert(tag:match("^[a-z0-9-]+$"), "Invalid internal filename")
    return prefix .. tag
  end

  local function path(tag, folder)
    return root
      .. "/"
      .. (folder or "importexport")
      .. "/"
      .. basename(tag)
      .. ".xml"
  end

  local function command(text)
    local problem = gma.cmd(text)
    assert(not problem, tostring(problem))
    gma.sleep(0.01)
  end

  local function export(object, tag, folder)
    command("Export " .. object .. ' "' .. basename(tag) .. '" /o')
    return storage.read(path(tag, folder))
  end

  local function save(tag, content)
    storage.write(path(tag), content)
  end

  local function import(object, tag)
    command('Import "' .. basename(tag) .. '.xml" At ' .. object .. " /o")
  end

  return { command = command, export = export, save = save, import = import }
end

return { new = new }

end
modules["ma.cleanup-read"] = function()
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

end
modules["ma.cleanup-context"] = function()
local function sequence(gma)
  local getobj = gma.show.getobj
  local selected = gma.user.getselectedexec()
  if not selected then
    return nil, "No selected executor"
  end
  local address = getobj.number(selected)
  if not address or address == "" then
    return nil, "Selected executor has no readable number"
  end
  local cue = getobj.handle("Executor " .. address .. " Cue 1")
  if not cue then
    return nil, "Cannot resolve selected sequence through Cue 1"
  end
  local parent = getobj.parent(cue)
  if not parent or getobj.class(parent) ~= "CMD_SEQUENCE" then
    return nil, "Executor cue has no sequence parent"
  end
  return getobj.number(parent)
end

local function fixture(gma, address)
  local getobj = gma.show.getobj
  local handle = getobj.handle(address)
  if not handle then
    return nil, "Fixture not found"
  end
  if getobj.amount(handle) ~= 1 then
    return nil, "Fixture instance mapping is not verified"
  end
  local instance = getobj.child(handle, 0)
  local value = gma.show.property.get(instance, "Fixture|Type")
  local number = type(value) == "string" and value:match("^(%d+)%s")
  if not number then
    return nil, "Fixture type cannot be read"
  end
  return { type = number, module = "0" }
end

local function fixtures(gma, addresses, yield, progress)
  local result = { fixtures = {}, types = {}, uncertain = {} }
  local seen = {}
  for index, address in ipairs(addresses) do
    local definition, problem = fixture(gma, address)
    if definition then
      result.fixtures[address] = definition
      if not seen[definition.type] then
        seen[definition.type] = true
        result.types[#result.types + 1] = definition.type
      end
    else
      result.uncertain[#result.uncertain + 1] = {
        address = address,
        problem = problem,
      }
    end
    if progress then
      progress(index, #addresses)
    end
    if yield then
      yield()
    else
      gma.sleep(0.01)
    end
  end
  table.sort(result.types, function(left, right)
    return tonumber(left) < tonumber(right)
  end)
  return result
end

return { sequence = sequence, fixtures = fixtures }

end
modules["core.sequence-data"] = function()
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

end
modules["core.ma-xml"] = function()
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

end
modules["core.fixture-type"] = function()
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

end
modules["ma.cleanup-write"] = function()
local function new(gma, files, yield, progress)
  local backup

  local function notify(percent, text, force)
    if progress then
      progress(percent, text, force)
    end
  end

  local function freeSequence()
    for number = 1, 511 do
      if not gma.show.getobj.handle("Sequence " .. number) then
        return number
      end
    end
    error("No free backup sequence below 512")
  end

  local function makeBackup(input)
    notify(70, "Creating backup sequence")
    local number = freeSequence()
    files.command("Copy Sequence " .. input.number .. " At Sequence " .. number)
    assert(
      gma.show.getobj.handle("Sequence " .. number),
      "Backup sequence was not created"
    )
    backup = number
    gma.echo("Sequence cleanup backup: Sequence " .. number)
  end

  local function createPreset(preset, index)
    local address = "Preset " .. preset.pool .. "." .. preset.slot
    assert(not gma.show.getobj.handle(address), "Preset slot became occupied")
    local tag = "preset-" .. index
    files.save(tag, preset.xml)
    files.import(address, tag)
  end

  local function apply(input, plan)
    makeBackup(input)
    for index, preset in ipairs(plan.presets) do
      notify(
        74 + math.floor(10 * index / #plan.presets),
        "Importing preset " .. index .. " of " .. #plan.presets,
        index == 1
      )
      createPreset(preset, index)
      if yield then
        yield()
      end
    end
    files.save("output", plan.xml)
    notify(86, "Importing cleaned sequence")
    files.import("Sequence " .. input.number, "output")
    return plan.xml
  end

  local function recovery()
    if backup then
      return "Original data is backed up in Sequence "
        .. backup
        .. ". Earlier successful changes are not rolled back automatically."
    end
    return "No backup was created; sequence import did not start."
  end

  return { apply = apply, recovery = recovery }
end

return { new = new }

end
modules["core.cleanup-plan"] = function()
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

end
modules["core.unused-fixtures"] = function()
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

end
modules["core.preset-samples"] = function()
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

end
modules["core.preset-clusters"] = function()
local function finite(value)
  return type(value) == "number"
    and value == value
    and value > -math.huge
    and value < math.huge
end

local function valid(values)
  if not next(values) then
    return false
  end
  for _, value in pairs(values) do
    if not finite(value) then
      return false
    end
  end
  return true
end

local function matches(left, right, tolerance)
  for attribute, value in pairs(left) do
    if
      right[attribute] == nil
      or math.abs(value - right[attribute]) > tolerance
    then
      return false
    end
  end
  for attribute in pairs(right) do
    if left[attribute] == nil then
      return false
    end
  end
  return true
end

local function find(groups, sample, tolerance)
  for _, group in ipairs(groups) do
    if
      group.scope == sample.scope
      and matches(group.values, sample.values, tolerance)
    then
      return group
    end
  end
end

local function newGroup(sample)
  local values = {}
  for attribute, value in pairs(sample.values) do
    values[attribute] = value
  end
  return { scope = sample.scope, values = values, members = {} }
end

local function plan(samples, tolerance, yield)
  assert(finite(tolerance) and tolerance >= 0, "Invalid tolerance")
  local result = { groups = {}, skipped = {} }
  for index, sample in ipairs(samples) do
    if sample.preset or not valid(sample.values) then
      result.skipped[#result.skipped + 1] = sample
    else
      local group = find(result.groups, sample, tolerance)
      if not group then
        group = newGroup(sample)
        result.groups[#result.groups + 1] = group
      end
      group.members[#group.members + 1] = sample
    end
    if yield and index % 64 == 0 then
      yield()
    end
  end
  return result
end

return { plan = plan }

end
modules["core.preset-xml"] = function()
local NAMESPACE = "http://schemas.malighting.de/grandma2/xml/MA"
local SCHEMA = "http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd"

local function finite(value)
  return type(value) == "number"
    and value == value
    and value > -math.huge
    and value < math.huge
end

local function escape(value)
  assert(type(value) == "string", "Expected XML text")
  assert(not value:find("[%z\1-\8\11\12\14-\31]"), "Invalid XML character")
  local escaped = value:gsub("&", "&amp;"):gsub('"', "&quot;")
  escaped = escaped:gsub("<", "&lt;"):gsub(">", "&gt;")
  return escaped
end

local function identifier(value)
  assert(type(value) == "string", "Expected identifier string")
  assert(
    value:match("^%d+$") or value:match("^%d+%.%d+$"),
    "Invalid fixture or channel identifier"
  )
  return value
end

local function entry(row)
  assert(finite(row.value), "Expected a finite attribute value")
  assert(row.attribute ~= "", "Empty attribute")
  local value = string.format("%.17g", row.value):gsub(",", ".")
  return '<PresetValue Value="'
    .. value
    .. '"><Channel fixture_id="'
    .. identifier(row.fixture)
    .. '" channel_id="'
    .. identifier(row.channel)
    .. '" attribute_name="'
    .. escape(row.attribute)
    .. '" /></PresetValue>'
end

local function build(slot, name, channels)
  assert(finite(slot) and slot >= 1 and slot % 1 == 0, "Invalid preset slot")
  assert(#channels > 0, "Empty preset")
  local parts = {
    '<?xml version="1.0" encoding="utf-8"?>',
    '<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="'
      .. NAMESPACE
      .. '" xsi:schemaLocation="'
      .. NAMESPACE
      .. " "
      .. SCHEMA
      .. '" major_vers="3" minor_vers="9" stream_vers="60">',
    '<Preset index="'
      .. string.format("%.0f", slot - 1)
      .. '" name="'
      .. escape(name)
      .. '" SpecialUse="Normal"><Values><Channels>',
  }
  local seen = {}
  for _, row in ipairs(channels) do
    local xml = entry(row)
    local key = row.fixture .. ":" .. row.channel .. ":" .. row.attribute
    assert(not seen[key], "Duplicate fixture attribute")
    seen[key] = true
    parts[#parts + 1] = xml
  end
  parts[#parts + 1] = "</Channels></Values></Preset></MA>"
  return table.concat(parts, "\n")
end

return { build = build }

end
modules["core.sequence-edits"] = function()
local function escape(value)
  assert(type(value) == "string", "Expected preset name")
  assert(not value:find("[%z\1-\8\11\12\14-\31]"), "Invalid XML character")
  local escaped = value:gsub("&", "&amp;"):gsub('"', "&quot;")
  return escaped:gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function number(value)
  assert(
    type(value) == "number"
      and value >= 1
      and value < math.huge
      and value % 1 == 0,
    "Invalid preset address"
  )
  return string.format("%.0f", value)
end

local function reference(entry)
  return '<Preset name="'
    .. escape(entry.name)
    .. '"><No>1</No><No>'
    .. number(entry.pool)
    .. "</No><No>"
    .. number(entry.slot)
    .. "</No></Preset>"
end

local function editedRow(original, entry)
  if entry.value ~= nil then
    assert(
      type(entry.value) == "number"
        and entry.value == entry.value
        and math.abs(entry.value) < math.huge,
      "Invalid representative value"
    )
    local value = string.format("%.17g", entry.value):gsub(",", ".")
    local count
    original, count = original:gsub("<Value>[^<]*</Value>", function()
      return "<Value>" .. value .. "</Value>"
    end)
    assert(count == 1, "Expected one raw value")
  end
  return original:gsub("</CueData>$", function()
    return reference(entry) .. "</CueData>"
  end)
end

local function referenceMap(sequence, removed, entries)
  local allowed, found = {}, {}
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      allowed[row] = true
    end
  end
  for _, entry in ipairs(entries) do
    local row = entry.row
    assert(allowed[row] and not removed[row.address], "Foreign or removed row")
    assert(
      not row.preset and not row.hasEffect,
      "Row is not a raw static value"
    )
    assert(
      row.value and row.value == row.value and math.abs(row.value) < math.huge,
      "Unknown raw value"
    )
    assert(not found[row], "Duplicate reference edit")
    reference(entry)
    found[row] = entry
  end
  return found
end

local function modifications(sequence, removed, references)
  local found = {}
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      if removed[row.address] or references[row] then
        local node = row.node
        local replacement = ""
        if references[row] then
          local original = sequence.source:sub(node.first, node.last)
          local amount
          replacement, amount = editedRow(original, references[row])
          assert(amount == 1, "Unexpected CueData source span")
        end
        found[#found + 1] = {
          first = node.first,
          last = node.last,
          text = replacement,
        }
      end
    end
  end
  table.sort(found, function(left, right)
    return left.first < right.first
  end)
  return found
end

local function apply(sequence, removals, entries)
  local removed = {}
  for _, address in ipairs(removals) do
    removed[address] = true
  end
  local references = referenceMap(sequence, removed, entries)
  local changes = modifications(sequence, removed, references)
  local parts, position = {}, 1
  for _, change in ipairs(changes) do
    assert(change.first >= position, "Overlapping sequence edits")
    parts[#parts + 1] = sequence.source:sub(position, change.first - 1)
    parts[#parts + 1] = change.text
    position = change.last + 1
  end
  parts[#parts + 1] = sequence.source:sub(position)
  return table.concat(parts)
end

return { apply = apply }

end
modules["ma.conflict-group"] = function()
local LABEL = "Conflicts"
local MAX_NUMBER = 10000
local SELECTED_COUNT = "SELECTEDFIXTURESCOUNT"
local LOCATORS = {
  { field = "fixId", keyword = "Fixture" },
  { field = "chaId", keyword = "Channel" },
}

local function locatorOf(fixture)
  for _, locator in ipairs(LOCATORS) do
    if fixture[locator.field] then
      return locator.keyword .. " " .. fixture[locator.field]
    end
  end
  return nil
end

local function locatorsFor(gma, fixtures)
  local locators = {}
  for _, fixture in ipairs(fixtures) do
    local locator = locatorOf(fixture)
    if not (locator and gma.show.getobj.handle(locator)) then
      local where = tostring(locator)
      return nil, "Cannot find " .. fixture.name .. " as " .. where .. "."
    end
    locators[#locators + 1] = locator
  end
  return locators
end

local function runAll(gma, commands)
  for _, command in ipairs(commands) do
    local problem = gma.cmd(command)
    if problem then
      return nil, command .. " failed: " .. tostring(problem)
    end
  end
  return true
end

local function selectedCount(gma)
  local value = gma.show.getvar(SELECTED_COUNT)
  return tonumber(value) or 0
end

local function firstFree(gma, pool)
  for number = 1, MAX_NUMBER do
    if not gma.show.getobj.handle(pool .. " " .. number) then
      return number
    end
  end
  return nil
end

local function selectFixtures(gma, locators)
  local commands = { "ClearSelection" }
  for _, locator in ipairs(locators) do
    commands[#commands + 1] = locator
  end
  local ok, problem = runAll(gma, commands)
  if not ok then
    return nil, problem
  end
  local selected = selectedCount(gma)
  if selected == 0 then
    return nil, "The conflict fixtures selected nothing."
  end
  return selected
end

local function storePool(gma, pool)
  local number = firstFree(gma, pool)
  if not number then
    return nil, "No free " .. pool .. " number."
  end
  local name = pool .. " " .. number
  local ok, problem =
    runAll(gma, { "Store " .. name .. ' "' .. LABEL .. '" /nc' })
  if not ok then
    return nil, problem
  end
  local handle = gma.show.getobj.handle(name)
  if not (handle and gma.show.getobj.label(handle) == LABEL) then
    return nil, name .. " " .. LABEL .. " was not created."
  end
  return number
end

local function countInGroup(gma, group)
  local ok, problem = runAll(gma, { "ClearSelection", "Group " .. group })
  if not ok then
    return nil, problem
  end
  local held = selectedCount(gma)
  ok, problem = runAll(gma, { "ClearSelection" })
  if not ok then
    return nil, problem
  end
  return held
end

local function create(gma, fixtures)
  local locators, problem = locatorsFor(gma, fixtures)
  if not locators then
    return nil, problem
  end
  local selected, group, layout, held, ok
  selected, problem = selectFixtures(gma, locators)
  if not selected then
    return nil, problem
  end
  group, problem = storePool(gma, "Group")
  if not group then
    return nil, problem
  end
  layout, problem = storePool(gma, "Layout")
  if not layout then
    return nil, problem
  end
  local assign = "Assign Group " .. group .. " Layout " .. layout
  ok, problem = runAll(gma, { assign })
  if not ok then
    return nil, problem
  end
  held, problem = countInGroup(gma, group)
  if not held then
    return nil, problem
  end
  if held ~= selected then
    local text = "Group %d holds %d of %d fixtures."
    return nil, string.format(text, group, held, selected)
  end
  return { group = group, layout = layout }
end

return { create = create }

end
modules["ma.cooperate"] = function()
local function new(gma)
  local last = gma.gettime()
  local calls = 0
  return function()
    calls = calls + 1
    if gma.gettime() - last >= 0.05 or calls >= 8 then
      gma.sleep(0.01)
      last = gma.gettime()
      calls = 0
    end
  end
end

return { new = new }

end
modules["core.sequence-presets"] = function()
local function collect(sequence, plan)
  local found, seen, removed = {}, {}, {}
  for _, address in ipairs(plan.remove or {}) do
    removed[address] = true
  end
  local function add(pool, slot)
    pool, slot = tonumber(pool), tonumber(slot)
    assert(pool and slot and pool >= 1 and slot >= 1, "Invalid preset")
    local address = "Preset " .. pool .. "." .. slot
    if not seen[address] then
      seen[address] = true
      found[#found + 1] = { pool = pool, slot = slot, address = address }
    end
  end
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      if row.preset and not removed[row.address] then
        add(row.preset[2], row.preset[3])
      end
    end
  end
  for _, preset in ipairs(plan.presets) do
    add(preset.pool, preset.slot)
  end
  table.sort(found, function(left, right)
    if left.pool == right.pool then
      return left.slot < right.slot
    end
    return left.pool < right.pool
  end)
  local addresses = {}
  for _, item in ipairs(found) do
    addresses[#addresses + 1] = item.address
  end
  return addresses
end

return { collect = collect }

end
gma.echo("Sequence Position Presets 0.1.1 (abc1234, 2026-10-24)")
return (function(...)
local cleanupFlow = require("ma.cleanup-flow")
local runtime = require("ma.cleanup-runtime")

local flow = cleanupFlow.new(gma, function(console)
  return runtime.new(console, { mode = "position" })
end)

return flow.start, flow.cleanup

end)(...)
