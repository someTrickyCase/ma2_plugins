local swapIds = require("core.swap-ids")
local report = require("core.report")
local patchReader = require("ma.patch-reader")
local patchWriter = require("ma.patch-writer")

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

  local function applyPlan(plan)
    progress = gma.gui.progress.start(title)
    gma.gui.progress.setrange(progress, 0, #plan.steps)
    local ok, problem = patchWriter.apply(gma, plan.steps, onStep)
    stopProgress()
    if not ok then
      show({ problem })
      return
    end
    show({ report.done(plan, from, to) })
  end

  local function decide(plan)
    if #plan.conflicts > 0 then
      show(report.conflicts(plan.conflicts, to))
    elseif #plan.steps == 0 then
      show({ report.nothingToDo(from) })
    elseif not gma.gui.confirm(title, report.question(plan, from, to)) then
      echo({ "Cancelled. Nothing was changed." })
    else
      applyPlan(plan)
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
