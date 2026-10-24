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
