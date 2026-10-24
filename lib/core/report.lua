local LABELS = { fixId = "Fixture ID", chaId = "Channel ID" }

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
  local lines = {
    "Cannot move: " .. counted(#list, "conflict") .. ". Nothing was changed.",
  }
  for _, conflict in ipairs(list) do
    lines[#lines + 1] = conflictLine(conflict, to)
  end
  return lines
end

local function direction(from, to)
  return string.format("from %s to %s", LABELS[from], LABELS[to])
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
  question = question,
  done = done,
  nothingToDo = nothingToDo,
}
