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
