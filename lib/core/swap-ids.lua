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

local function finalId(fixture, from, to)
  return fixture[from] or fixture[to]
end

local function ownersByFinalId(fixtures, from, to)
  local owners, ids = {}, {}
  for _, fixture in ipairs(fixtures) do
    local id = finalId(fixture, from, to)
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

local function conflictsFor(fixtures, from, to)
  local owners, ids = ownersByFinalId(fixtures, from, to)
  local conflicts = {}
  for _, id in ipairs(ids) do
    if #owners[id] > 1 then
      conflicts[#conflicts + 1] = { id = id, fixtures = owners[id] }
    end
  end
  return conflicts
end

local function plan(fixtures, from, to)
  local conflicts = conflictsFor(fixtures, from, to)
  if #conflicts > 0 then
    return { steps = {}, conflicts = conflicts }
  end
  return { steps = stepsFor(movers(fixtures, from), from, to), conflicts = {} }
end

return { plan = plan }
