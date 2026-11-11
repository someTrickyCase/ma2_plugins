local lu = require("luaunit")
local cooperate = require("ma.cooperate")

local tests = {}

function tests.testCheapCheckpointsDoNotEachSleep()
  local sleeps = 0
  local tick = cooperate.new({
    gettime = function()
      return 0
    end,
    sleep = function()
      sleeps = sleeps + 1
    end,
  })
  for _ = 1, 100 do
    tick()
  end
  lu.assertTrue(sleeps > 0)
  lu.assertTrue(sleeps < 20)
end

function tests.testElapsedWorkBudgetYieldsBeforeTheCheckpointCap()
  local now, sleeps = 0, 0
  local tick = cooperate.new({
    gettime = function()
      return now
    end,
    sleep = function(seconds)
      lu.assertEquals(seconds, 0.01)
      sleeps = sleeps + 1
    end,
  })
  now = 0.1
  tick()
  lu.assertEquals(sleeps, 1)
end

return tests
