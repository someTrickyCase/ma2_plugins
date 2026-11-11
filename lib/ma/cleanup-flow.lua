local function new(gma, factory)
  local active

  local function cleanup()
    if active then
      local current = active
      active = nil
      current.cleanup()
    end
  end

  local function run()
    if factory then
      active = factory(gma)
    else
      active = require("ma.cleanup-runtime").new(gma)
    end
    local input = active.prepare()
    if not input then
      return
    end
    local plan = active.plan(input)
    active.mark(plan)
    if not active.confirm(input, plan) then
      gma.echo("Sequence cleanup cancelled; sequence data unchanged.")
      return
    end
    active.apply(input, plan)
    active.done(input, plan)
  end

  local function start()
    local ok, problem = pcall(run)
    local title = active and active.title or "Sequence workflow"
    local recovery = ""
    if active then
      local recovered, result = pcall(active.recovery)
      recovery = recovered and result
        or "Recovery status unavailable: " .. tostring(result)
    end
    local cleaned, cleanupProblem = pcall(cleanup)
    if not cleaned then
      recovery = recovery .. "|Cleanup failed: " .. tostring(cleanupProblem)
    end
    if not ok then
      if gma.export_json then
        pcall(gma.export_json, "sequence-cleanup-error.json", {
          tostring(problem):gsub('[\r\n"]', " "),
          (recovery:gsub('[\r\n"]', " ")),
        })
      end
      gma.gui.msgbox(title .. " stopped", tostring(problem) .. "|" .. recovery)
    end
  end

  return { start = start, cleanup = cleanup }
end

return { new = new }
