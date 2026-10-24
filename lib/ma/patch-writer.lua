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
