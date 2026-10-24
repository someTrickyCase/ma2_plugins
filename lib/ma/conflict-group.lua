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
