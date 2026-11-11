local cleanupFlow = require("ma.cleanup-flow")
local runtime = require("ma.cleanup-runtime")

local flow = cleanupFlow.new(gma, function(console)
  return runtime.new(console, { mode = "unused" })
end)

return flow.start, flow.cleanup
