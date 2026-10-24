local swapFlow = require("ma.swap-flow")

local flow = swapFlow.new(gma, {
  title = "Fixture to Channel",
  from = "fixId",
  to = "chaId",
})

return flow.start, flow.cleanup
