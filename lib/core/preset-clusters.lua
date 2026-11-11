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
