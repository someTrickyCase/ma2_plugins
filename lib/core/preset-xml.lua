local NAMESPACE = "http://schemas.malighting.de/grandma2/xml/MA"
local SCHEMA = "http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd"

local function finite(value)
  return type(value) == "number"
    and value == value
    and value > -math.huge
    and value < math.huge
end

local function escape(value)
  assert(type(value) == "string", "Expected XML text")
  assert(not value:find("[%z\1-\8\11\12\14-\31]"), "Invalid XML character")
  local escaped = value:gsub("&", "&amp;"):gsub('"', "&quot;")
  escaped = escaped:gsub("<", "&lt;"):gsub(">", "&gt;")
  return escaped
end

local function identifier(value)
  assert(type(value) == "string", "Expected identifier string")
  assert(
    value:match("^%d+$") or value:match("^%d+%.%d+$"),
    "Invalid fixture or channel identifier"
  )
  return value
end

local function entry(row)
  assert(finite(row.value), "Expected a finite attribute value")
  assert(row.attribute ~= "", "Empty attribute")
  local value = string.format("%.17g", row.value):gsub(",", ".")
  return '<PresetValue Value="'
    .. value
    .. '"><Channel fixture_id="'
    .. identifier(row.fixture)
    .. '" channel_id="'
    .. identifier(row.channel)
    .. '" attribute_name="'
    .. escape(row.attribute)
    .. '" /></PresetValue>'
end

local function build(slot, name, channels)
  assert(finite(slot) and slot >= 1 and slot % 1 == 0, "Invalid preset slot")
  assert(#channels > 0, "Empty preset")
  local parts = {
    '<?xml version="1.0" encoding="utf-8"?>',
    '<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="'
      .. NAMESPACE
      .. '" xsi:schemaLocation="'
      .. NAMESPACE
      .. " "
      .. SCHEMA
      .. '" major_vers="3" minor_vers="9" stream_vers="60">',
    '<Preset index="'
      .. string.format("%.0f", slot - 1)
      .. '" name="'
      .. escape(name)
      .. '" SpecialUse="Normal"><Values><Channels>',
  }
  local seen = {}
  for _, row in ipairs(channels) do
    local xml = entry(row)
    local key = row.fixture .. ":" .. row.channel .. ":" .. row.attribute
    assert(not seen[key], "Duplicate fixture attribute")
    seen[key] = true
    parts[#parts + 1] = xml
  end
  parts[#parts + 1] = "</Channels></Values></Preset></MA>"
  return table.concat(parts, "\n")
end

return { build = build }
