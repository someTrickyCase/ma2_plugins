local function collect(sequence, plan)
  local found, seen, removed = {}, {}, {}
  for _, address in ipairs(plan.remove or {}) do
    removed[address] = true
  end
  local function add(pool, slot)
    pool, slot = tonumber(pool), tonumber(slot)
    assert(pool and slot and pool >= 1 and slot >= 1, "Invalid preset")
    local address = "Preset " .. pool .. "." .. slot
    if not seen[address] then
      seen[address] = true
      found[#found + 1] = { pool = pool, slot = slot, address = address }
    end
  end
  for _, cue in ipairs(sequence.cues) do
    for _, row in ipairs(cue.rows) do
      if row.preset and not removed[row.address] then
        add(row.preset[2], row.preset[3])
      end
    end
  end
  for _, preset in ipairs(plan.presets) do
    add(preset.pool, preset.slot)
  end
  table.sort(found, function(left, right)
    if left.pool == right.pool then
      return left.slot < right.slot
    end
    return left.pool < right.pool
  end)
  local addresses = {}
  for _, item in ipairs(found) do
    addresses[#addresses + 1] = item.address
  end
  return addresses
end

return { collect = collect }
