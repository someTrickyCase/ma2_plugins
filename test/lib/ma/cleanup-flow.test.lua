local lu = require("luaunit")
local cleanupFlow = require("ma.cleanup-flow")

local function setup(accepted, failure)
  local events = {}
  local messages = {}
  local reports = {}
  local service = {
    prepare = function()
      return {}
    end,
    plan = function()
      return {}
    end,
    mark = function() end,
    confirm = function()
      return accepted
    end,
    apply = function()
      events[#events + 1] = "apply"
      if failure then
        error("Readback mismatch")
      end
    end,
    done = function()
      events[#events + 1] = "done"
    end,
    cleanup = function()
      events[#events + 1] = "cleanup"
    end,
    recovery = function()
      return "Backup Sequence 2"
    end,
  }
  local gma = {
    echo = function() end,
    export_json = function(name, report)
      reports[name] = report
    end,
    gui = {
      msgbox = function(_, text)
        messages[#messages + 1] = text
      end,
    },
  }
  local flow = cleanupFlow.new(gma, function()
    return service
  end)
  return flow, events, messages, reports, service
end

local tests = {}

function tests.testCancelDoesNotApplyAnyPlan()
  local flow, events = setup(false)
  flow.start()
  lu.assertEquals(events, { "cleanup" })
end

function tests.testReadbackFailureStopsBeforeDoneAndReportsRecovery()
  local flow, events, messages, reports = setup(true, true)
  flow.start()
  lu.assertEquals(events, { "apply", "cleanup" })
  lu.assertStrContains(messages[1], "Readback mismatch")
  lu.assertStrContains(messages[1], "Backup Sequence 2")
  local report = reports["sequence-cleanup-error.json"]
  lu.assertNotNil(report)
  lu.assertStrContains(report[1], "Readback mismatch")
  lu.assertEquals(report[2], "Backup Sequence 2")
end

function tests.testSuccessfulRunCleansUpAndCanBeRepeated()
  local flow, events = setup(true)
  flow.start()
  flow.start()
  lu.assertEquals(
    events,
    { "apply", "done", "cleanup", "apply", "done", "cleanup" }
  )
end

function tests.testSecondaryFailuresKeepTheOriginalErrorVisible()
  local instance, events, messages, _, service = setup(true, true)
  service.recovery = function()
    error("recovery failed")
  end
  service.cleanup = function()
    events[#events + 1] = "cleanup"
    error("cleanup failed")
  end
  instance.start()
  lu.assertEquals(events, { "apply", "cleanup" })
  lu.assertStrContains(messages[1], "Readback mismatch")
  lu.assertStrContains(messages[1], "recovery failed")
  lu.assertStrContains(messages[1], "cleanup failed")
end

return tests
