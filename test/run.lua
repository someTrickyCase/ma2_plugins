package.path = "./lib/?.lua;./?.lua;./vendor/?.lua;" .. package.path

local lu = require("luaunit")

local function suiteName(path)
  return (path:gsub("^%./", ""):gsub("%.test%.lua$", ""))
end

local suites = {}
for _, path in ipairs(arg) do
  suites[#suites + 1] = { suiteName(path), dofile(path) }
end

os.exit(lu.LuaUnit.new():runSuiteByInstances(suites, "--verbose"))
