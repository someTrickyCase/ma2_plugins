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
