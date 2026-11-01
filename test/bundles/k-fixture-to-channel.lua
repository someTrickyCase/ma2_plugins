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
modules["ma.swap-flow"] = function()
local swapIds = require("core.swap-ids")
local report = require("core.report")
local patchReader = require("ma.patch-reader")
local patchWriter = require("ma.patch-writer")
local conflictGroup = require("ma.conflict-group")

local YIELD_SECONDS = 0.01
local POPUP_LINE_BREAK = "|"

local function new(gma, options)
  local title, from, to = options.title, options.from, options.to
  local progress = nil

  local function echo(lines)
    for _, line in ipairs(lines) do
      gma.echo(title .. ": " .. line)
    end
  end

  local function show(lines)
    echo(lines)
    gma.gui.msgbox(title, table.concat(lines, POPUP_LINE_BREAK))
  end

  local function stopProgress()
    if progress then
      gma.gui.progress.stop(progress)
      progress = nil
    end
  end

  local function onStep(done, total)
    gma.gui.progress.settext(progress, "Step " .. done .. " of " .. total)
    gma.gui.progress.set(progress, done)
    gma.sleep(YIELD_SECONDS)
  end

  local function ask(lines)
    return gma.gui.confirm(title, table.concat(lines, POPUP_LINE_BREAK))
  end

  local function applyPlan(plan, doneLines)
    progress = gma.gui.progress.start(title)
    gma.gui.progress.setrange(progress, 0, #plan.steps)
    local ok, problem = patchWriter.apply(gma, plan.steps, onStep)
    stopProgress()
    if not ok then
      show({ problem })
      return
    end
    show(doneLines)
  end

  local function decideWithConflicts(plan)
    local pools, problem = conflictGroup.create(gma, plan.skipped)
    if not pools then
      show({ problem, report.cancelled() })
    elseif #plan.steps == 0 then
      show(report.onlyConflicts(plan.conflicts, to, pools))
    else
      echo(report.conflicts(plan.conflicts, to))
      if not ask(report.conflictQuestion(plan, from, to, pools)) then
        echo({ report.cancelled() })
        return
      end
      applyPlan(plan, {
        report.done(plan, from, to),
        report.skipped(plan, pools),
      })
    end
  end

  local function decide(plan)
    if #plan.conflicts > 0 then
      decideWithConflicts(plan)
    elseif #plan.steps == 0 then
      show({ report.nothingToDo(from) })
    elseif not ask({ report.question(plan, from, to) }) then
      echo({ report.cancelled() })
    else
      applyPlan(plan, { report.done(plan, from, to) })
    end
  end

  local function start()
    local fixtures, problem = patchReader.read(gma)
    if not fixtures then
      show({ problem })
      return
    end
    decide(swapIds.plan(fixtures, from, to))
  end

  return { start = start, cleanup = stopProgress }
end

return { new = new }

end
modules["core.swap-ids"] = function()
local function movers(fixtures, from)
  local found = {}
  for _, fixture in ipairs(fixtures) do
    if fixture[from] then
      found[#found + 1] = fixture
    end
  end
  return found
end

local function setStep(fixture, field, value)
  return { action = "set", fixture = fixture, field = field, value = value }
end

local function clearStep(fixture, field)
  return { action = "clear", fixture = fixture, field = field }
end

local function stepsFor(moving, from, to)
  local steps = {}
  for _, fixture in ipairs(moving) do
    if fixture[to] then
      steps[#steps + 1] = clearStep(fixture, to)
    end
  end
  for _, fixture in ipairs(moving) do
    steps[#steps + 1] = setStep(fixture, to, fixture[from])
  end
  for _, fixture in ipairs(moving) do
    steps[#steps + 1] = clearStep(fixture, from)
  end
  return steps
end

local function finalId(fixture, from, to, skipped)
  if skipped[fixture] then
    return fixture[to]
  end
  return fixture[from] or fixture[to]
end

local function ownersByFinalId(fixtures, from, to, skipped)
  local owners, ids = {}, {}
  for _, fixture in ipairs(fixtures) do
    local id = finalId(fixture, from, to, skipped)
    if id then
      if not owners[id] then
        owners[id] = {}
        ids[#ids + 1] = id
      end
      table.insert(owners[id], fixture)
    end
  end
  table.sort(ids)
  return owners, ids
end

local function conflictsFor(fixtures, from, to, skipped)
  local owners, ids = ownersByFinalId(fixtures, from, to, skipped)
  local conflicts = {}
  for _, id in ipairs(ids) do
    if #owners[id] > 1 then
      conflicts[#conflicts + 1] = { id = id, fixtures = owners[id] }
    end
  end
  return conflicts
end

local function skipAll(conflict, skipped)
  local added = false
  for _, fixture in ipairs(conflict.fixtures) do
    added = added or not skipped[fixture]
    skipped[fixture] = true
  end
  return added
end

local function byId(a, b)
  return a.id < b.id
end

local function skipUntilStable(fixtures, from, to)
  local skipped, found = {}, {}
  local changed = true
  while changed do
    changed = false
    for _, conflict in ipairs(conflictsFor(fixtures, from, to, skipped)) do
      if skipAll(conflict, skipped) then
        found[#found + 1] = conflict
        changed = true
      end
    end
  end
  table.sort(found, byId)
  return skipped, found
end

local function filter(fixtures, keep)
  local list = {}
  for _, fixture in ipairs(fixtures) do
    if keep(fixture) then
      list[#list + 1] = fixture
    end
  end
  return list
end

local function plan(fixtures, from, to)
  local skipped, conflicts = skipUntilStable(fixtures, from, to)
  local free = filter(fixtures, function(fixture)
    return not skipped[fixture]
  end)
  return {
    steps = stepsFor(movers(free, from), from, to),
    conflicts = conflicts,
    skipped = filter(fixtures, function(fixture)
      return skipped[fixture]
    end),
  }
end

return { plan = plan }

end
modules["core.report"] = function()
local LABELS = { fixId = "Fixture ID", chaId = "Channel ID" }
local POOL_LABEL = "Conflicts"

local function counted(count, word)
  if count == 1 then
    return count .. " " .. word
  end
  return count .. " " .. word .. "s"
end

local function movedCount(plan)
  local count = 0
  for _, step in ipairs(plan.steps) do
    if step.action == "set" then
      count = count + 1
    end
  end
  return count
end

local function describeFixture(fixture)
  return fixture.name .. " (" .. fixture.layer .. ")"
end

local function conflictLine(conflict, to)
  local names = {}
  for _, fixture in ipairs(conflict.fixtures) do
    names[#names + 1] = describeFixture(fixture)
  end
  return LABELS[to] .. " " .. conflict.id .. ": " .. table.concat(names, ", ")
end

local function conflicts(list, to)
  local lines = {}
  for _, conflict in ipairs(list) do
    lines[#lines + 1] = conflictLine(conflict, to)
  end
  return lines
end

local function poolsText(pools)
  return string.format(
    'Group %d and Layout %d "%s"',
    pools.group,
    pools.layout,
    POOL_LABEL
  )
end

local function onlyConflicts(list, to, pools)
  local lines = {
    "Cannot move: " .. counted(#list, "conflict") .. ". No ID was changed.",
    "See " .. poolsText(pools) .. ".",
  }
  for _, line in ipairs(conflicts(list, to)) do
    lines[#lines + 1] = line
  end
  return lines
end

local function direction(from, to)
  return string.format("from %s to %s", LABELS[from], LABELS[to])
end

local function conflictQuestion(plan, from, to, pools)
  local others = counted(movedCount(plan), "fixture")
  return {
    counted(#plan.conflicts, "conflict") .. ": see " .. poolsText(pools) .. ".",
    string.format("Move the other %s %s?", others, direction(from, to)),
  }
end

local function skipped(plan, pools)
  local fixtures = counted(#plan.skipped, "fixture")
  return "Skipped " .. fixtures .. ": see " .. poolsText(pools) .. "."
end

local function cancelled()
  return "Cancelled. No ID was changed."
end

local function question(plan, from, to)
  local fixtures = counted(movedCount(plan), "fixture")
  return string.format("Move %s %s?", fixtures, direction(from, to))
end

local function done(plan, from, to)
  local fixtures = counted(movedCount(plan), "fixture")
  return string.format("Done: %s moved %s.", fixtures, direction(from, to))
end

local function nothingToDo(from)
  return "Nothing to move: no fixture has a " .. LABELS[from] .. "."
end

return {
  conflicts = conflicts,
  onlyConflicts = onlyConflicts,
  conflictQuestion = conflictQuestion,
  skipped = skipped,
  cancelled = cancelled,
  question = question,
  done = done,
  nothingToDo = nothingToDo,
}

end
modules["ma.patch-reader"] = function()
local LAYERS_PATH = 'cd /; cd "EditSetup"; cd "Layers"'
local LAYERS_CLASS = "CMD_FIXTURE_LAYER_COLLECT"
local EMPTY_ID = "-"

local function parseId(text)
  if text == EMPTY_ID then
    return nil
  end
  return math.tointeger(tonumber(text))
end

local function children(gma, handle)
  local getobj = gma.show.getobj
  local found = {}
  for index = 0, getobj.amount(handle) - 1 do
    found[#found + 1] = getobj.child(handle, index)
  end
  return found
end

local function readFixture(gma, handle, layerName)
  local get = gma.show.property.get
  return {
    name = get(handle, "Name"),
    layer = layerName,
    fixId = parseId(get(handle, "FixId")),
    chaId = parseId(get(handle, "ChaId")),
  }
end

local function readLayers(gma, layers)
  local fixtures = {}
  for _, layer in ipairs(children(gma, layers)) do
    local layerName = gma.show.property.get(layer, "Name")
    for _, fixture in ipairs(children(gma, layer)) do
      fixtures[#fixtures + 1] = readFixture(gma, fixture, layerName)
    end
  end
  return fixtures
end

local function openLayers(gma)
  local problem = gma.cmd(LAYERS_PATH)
  if problem then
    return nil, problem
  end
  local layers = gma.user.getcmddest()
  local class = gma.show.getobj.class(layers)
  if class ~= LAYERS_CLASS then
    return nil, "landed in " .. tostring(class)
  end
  return layers
end

local function read(gma)
  local layers, problem = openLayers(gma)
  local fixtures = layers and readLayers(gma, layers)
  gma.cmd("cd /")
  if not layers then
    return nil, "cannot open the patch: " .. problem
  end
  return fixtures
end

return { read = read }

end
modules["ma.patch-writer"] = function()
local LAYERS_PATH = 'cd /; cd "EditSetup"; cd "Layers"'
local EMPTY_ID = "-"
local ID_FIELDS = {
  { field = "fixId", property = "FixId", locator = "Fixture" },
  { field = "chaId", property = "ChaId", locator = "Channel" },
}
local PROPERTIES = { fixId = "FixId", chaId = "ChaId" }

local function idText(id)
  if id == nil then
    return EMPTY_ID
  end
  return tostring(id)
end

local function locatorName(ids)
  for _, id in ipairs(ID_FIELDS) do
    if ids[id.field] then
      return id.locator .. " " .. ids[id.field]
    end
  end
  return nil
end

local function locate(gma, fixture, ids)
  local locator = locatorName(ids)
  local handle = locator and gma.show.getobj.handle(locator)
  if not handle then
    return nil, "cannot find it as " .. tostring(locator)
  end
  local name = gma.show.property.get(handle, "Name")
  if name ~= fixture.name then
    return nil, locator .. " is " .. tostring(name)
  end
  return handle
end

local function verify(gma, fixture, ids)
  local handle, problem = locate(gma, fixture, ids)
  if not handle then
    return nil, problem
  end
  for _, id in ipairs(ID_FIELDS) do
    local actual = gma.show.property.get(handle, id.property)
    local expected = idText(ids[id.field])
    if actual ~= expected then
      return nil, id.property .. " is " .. actual .. ", expected " .. expected
    end
  end
  return true
end

local function assignCommand(gma, handle, step)
  local getobj = gma.show.getobj
  local layer = getobj.number(getobj.parent(handle))
  local position = getobj.index(handle) + 1
  local value = step.action == "set" and tostring(step.value) or ""
  local property = PROPERTIES[step.field]
  return string.format(
    "%s; cd %s; assign %d /%s=%s",
    LAYERS_PATH,
    layer,
    position,
    property,
    value
  )
end

local function idsAfter(ids, step)
  local after = { fixId = ids.fixId, chaId = ids.chaId }
  after[step.field] = step.value
  return after
end

local function applyStep(gma, step, ids)
  local handle, problem = locate(gma, step.fixture, ids)
  if not handle then
    return nil, problem
  end
  problem = gma.cmd(assignCommand(gma, handle, step))
  gma.cmd("cd /")
  if problem then
    return nil, problem
  end
  local after = idsAfter(ids, step)
  local ok, mismatch = verify(gma, step.fixture, after)
  if not ok then
    return nil, mismatch
  end
  return after
end

local function describeStep(step)
  local fixture = step.fixture
  local target = fixture.name .. " (" .. fixture.layer .. ")"
  local property = PROPERTIES[step.field]
  if step.action == "set" then
    return "set " .. property .. "=" .. step.value .. " on " .. target
  end
  return "clear " .. property .. " on " .. target
end

local function failure(index, total, step, problem)
  local where = string.format("Step %d of %d failed", index, total)
  return where .. ": " .. describeStep(step) .. ": " .. problem
end

local function readIds(fixture)
  return { fixId = fixture.fixId, chaId = fixture.chaId }
end

local function apply(gma, steps, onStep)
  local current = {}
  for index, step in ipairs(steps) do
    local fixture = step.fixture
    local ids = current[fixture] or readIds(fixture)
    local after, problem = applyStep(gma, step, ids)
    if not after then
      return nil, failure(index, #steps, step, problem)
    end
    current[fixture] = after
    onStep(index, #steps)
  end
  return true
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
gma.echo("Fixture to Channel 0.2.0 (abc1234, 2026-10-24)")
return (function(...)
local swapFlow = require("ma.swap-flow")

local flow = swapFlow.new(gma, {
  title = "Fixture to Channel",
  from = "fixId",
  to = "chaId",
})

return flow.start, flow.cleanup

end)(...)
