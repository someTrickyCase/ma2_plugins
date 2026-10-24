package.path = "./?.lua;" .. package.path

local checkRules = require("dev.lint.code-rules")

local function readFile(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("a")
  file:close()
  return text
end

local files = {}
for _, path in ipairs(arg) do
  files[#files + 1] = { path = path, text = readFile(path) }
end

local lines = checkRules.report(files)
for _, line in ipairs(lines) do
  print(line)
end

os.exit(#lines == 0)
