local function escape(value)
  assert(type(value) == "string", "Expected preset name")
  assert(not value:find("[%z\1-\8\11\12\14-\31]"), "Invalid XML character")
  local escaped = value:gsub("&", "&amp;"):gsub('"', "&quot;")
  return escaped:gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function number(value)
  assert(
    type(value) == "number"
      and value >= 1
      and value < math.huge
      and value % 1 == 0,
    "Invalid preset address"
  )
  return string.format("%.0f", value)
end

local function reference(entry)
  return '<Preset name="'
    .. escape(entry.name)
    .. '"><No>1</No><No>'
    .. number(entry.pool)
    .. "</No><No>"
    .. number(entry.slot)
    .. "</No></Preset>"
end

local function editedRow(original, entry)
  if entry.value ~= nil then
    assert(
      type(entry.value) == "number"
        and entry.value == entry.value
        and math.abs(entry.value) < math.huge,
      "Invalid representative value"
    )
    local value = string.format("%.17g", entry.value):gsub(",", ".")
    local count
    original, count = original:gsub("<Value>[^<]*</Value>", function()
      return "<Value>" .. value .. "</Value>"
    end)
    assert(count == 1, "Expected one raw value")
  end
  return original:gsub("</CueData>$", function()
    return reference(entry) .. "</CueData>"
  end)
end

local function referenceMap(sequence, removed, entries)
  local allowed, found = {}, {}
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      allowed[row] = true
    end
  end
  for _, entry in ipairs(entries) do
    local row = entry.row
    assert(allowed[row] and not removed[row.address], "Foreign or removed row")
    assert(
      not row.preset and not row.hasEffect,
      "Row is not a raw static value"
    )
    assert(
      row.value and row.value == row.value and math.abs(row.value) < math.huge,
      "Unknown raw value"
    )
    assert(not found[row], "Duplicate reference edit")
    reference(entry)
    found[row] = entry
  end
  return found
end

local function modifications(sequence, removed, references)
  local found = {}
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      if removed[row.address] or references[row] then
        local node = row.node
        local replacement = ""
        if references[row] then
          local original = sequence.source:sub(node.first, node.last)
          local amount
          replacement, amount = editedRow(original, references[row])
          assert(amount == 1, "Unexpected CueData source span")
        end
        found[#found + 1] = {
          first = node.first,
          last = node.last,
          text = replacement,
        }
      end
    end
  end
  table.sort(found, function(left, right)
    return left.first < right.first
  end)
  return found
end

local function apply(sequence, removals, entries)
  local removed = {}
  for _, address in ipairs(removals) do
    removed[address] = true
  end
  local references = referenceMap(sequence, removed, entries)
  local changes = modifications(sequence, removed, references)
  local parts, position = {}, 1
  for _, change in ipairs(changes) do
    assert(change.first >= position, "Overlapping sequence edits")
    parts[#parts + 1] = sequence.source:sub(position, change.first - 1)
    parts[#parts + 1] = change.text
    position = change.last + 1
  end
  parts[#parts + 1] = sequence.source:sub(position)
  return table.concat(parts)
end

return { apply = apply }
