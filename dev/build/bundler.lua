local REQUIRE_PATTERN = 'require%("([%w%.%-_]+)"%)'
local MA_SCHEMAS = "http://schemas.malighting.de/grandma2/xml/"
local MA_NAMESPACE = MA_SCHEMAS .. "MA"
local MA_SCHEMA_FILE = MA_SCHEMAS .. "3.0.187/MA.xsd"
local XML_ESCAPES = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
}

local PRELUDE = {
  "local modules = {}",
  "local loaded = {}",
  "local realRequire = require",
  "local function require(name)",
  "  local loader = modules[name]",
  "  if not loader then",
  "    return realRequire(name)",
  "  end",
  "  if loaded[name] == nil then",
  "    loaded[name] = loader()",
  "  end",
  "  return loaded[name]",
  "end",
}

local function modulePath(name)
  return "lib/" .. name:gsub("%.", "/") .. ".lua"
end

local function discover(text, readFile, found, seen)
  for name in text:gmatch(REQUIRE_PATTERN) do
    if not seen[name] then
      seen[name] = true
      local moduleText = readFile(modulePath(name))
      if moduleText then
        found[#found + 1] = { name = name, text = moduleText }
        discover(moduleText, readFile, found, seen)
      end
    end
  end
  return found
end

local function readRequired(readFile, path)
  return assert(readFile(path), "missing file " .. path)
end

local function collect(pluginName, readFile, stamp)
  local folder = "plugins/" .. pluginName .. "/"
  local manifestText = readRequired(readFile, folder .. "plugin.lua")
  local manifest = assert(load(manifestText, "=manifest", "t", {}))()
  local main = readRequired(readFile, folder .. "main.lua")
  return {
    name = manifest.name,
    file = manifest.file,
    version = manifest.version,
    slot = manifest.slot,
    commit = stamp.commit,
    date = stamp.date,
    modules = discover(main, readFile, {}, {}),
    main = main,
  }
end

local function stampText(parts)
  local build = parts.commit .. ", " .. parts.date
  return parts.name .. " " .. parts.version .. " (" .. build .. ")"
end

local function lua(parts)
  local lines = { table.unpack(PRELUDE) }
  for _, module in ipairs(parts.modules) do
    lines[#lines + 1] = string.format("modules[%q] = function()", module.name)
    lines[#lines + 1] = module.text
    lines[#lines + 1] = "end"
  end
  lines[#lines + 1] = string.format("gma.echo(%q)", stampText(parts))
  lines[#lines + 1] = "return (function(...)"
  lines[#lines + 1] = parts.main
  lines[#lines + 1] = "end)(...)"
  return table.concat(lines, "\n") .. "\n"
end

local function escapeXml(text)
  return (text:gsub('[&<>"]', XML_ESCAPES))
end

local function attribute(name, value)
  return name .. '="' .. escapeXml(value) .. '"'
end

local function xml(parts)
  local ma = table.concat({
    "<MA",
    attribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"),
    attribute("xmlns", MA_NAMESPACE),
    attribute("xsi:schemaLocation", MA_NAMESPACE .. " " .. MA_SCHEMA_FILE),
    attribute("major_vers", "3"),
    attribute("minor_vers", "0"),
    attribute("stream_vers", "187") .. ">",
  }, " ")
  local info = table.concat({
    "    <Info",
    attribute("datetime", parts.date .. "T00:00:00"),
    attribute("showfile", parts.file),
    "/>",
  }, " ")
  local plugin = table.concat({
    "    <Plugin",
    attribute("index", "1"),
    attribute("execute_on_load", "0"),
    attribute("name", parts.name),
    attribute("luafile", parts.file .. ".lua"),
    "/>",
  }, " ")
  return table.concat({
    '<?xml version="1.0" encoding="utf-8"?>',
    ma,
    info,
    plugin,
    "</MA>",
  }, "\n") .. "\n"
end

local function instructions(parts, slot)
  local target = slot or parts.slot
  if not target then
    error("no plugin slot: add slot to plugin.lua or pass one", 2)
  end
  local pool = "Plugin " .. target
  return {
    "MA2 commands, paste them in this order:",
    "",
    "  1. Only when updating, remove the old copy:",
    "     Delete " .. pool,
    "  2. Load the plugin into the pool:",
    string.format('     Import "%s.xml" At %s', parts.file, pool),
    "  3. Run it (on a show copy first!):",
    "     " .. pool,
  }
end

return {
  modulePath = modulePath,
  collect = collect,
  lua = lua,
  xml = xml,
  instructions = instructions,
}
