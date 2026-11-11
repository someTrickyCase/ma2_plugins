local lu = require("luaunit")

local tests = {}

function tests.testLoadingReturnsCallbacksWithoutReadingConsoleState()
  local gma = setmetatable({}, {
    __index = function()
      error("Console state was read during plugin loading")
    end,
  })
  local environment = setmetatable({ gma = gma }, { __index = _G })
  local chunk =
    assert(loadfile("plugins/sequence-cleanup/main.lua", "t", environment))
  local start, cleanup = chunk()
  lu.assertEquals(type(start), "function")
  lu.assertEquals(type(cleanup), "function")
  cleanup()
end

return tests
