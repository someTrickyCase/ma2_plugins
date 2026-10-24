local swapFlow = require("ma.swap-flow")

local flow = swapFlow.new(gma, {
  title = "Channel to Fixture",
  from = "chaId",
  to = "fixId",
})

return flow.start, flow.cleanup
