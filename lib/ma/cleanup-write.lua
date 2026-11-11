local function new(gma, files, yield, progress)
  local backup

  local function notify(percent, text, force)
    if progress then
      progress(percent, text, force)
    end
  end

  local function freeSequence()
    for number = 1, 511 do
      if not gma.show.getobj.handle("Sequence " .. number) then
        return number
      end
    end
    error("No free backup sequence below 512")
  end

  local function makeBackup(input)
    notify(70, "Creating backup sequence")
    local number = freeSequence()
    files.command("Copy Sequence " .. input.number .. " At Sequence " .. number)
    assert(
      gma.show.getobj.handle("Sequence " .. number),
      "Backup sequence was not created"
    )
    backup = number
    gma.echo("Sequence cleanup backup: Sequence " .. number)
  end

  local function createPreset(preset, index)
    local address = "Preset " .. preset.pool .. "." .. preset.slot
    assert(not gma.show.getobj.handle(address), "Preset slot became occupied")
    local tag = "preset-" .. index
    files.save(tag, preset.xml)
    files.import(address, tag)
  end

  local function apply(input, plan)
    makeBackup(input)
    for index, preset in ipairs(plan.presets) do
      notify(
        74 + math.floor(10 * index / #plan.presets),
        "Importing preset " .. index .. " of " .. #plan.presets,
        index == 1
      )
      createPreset(preset, index)
      if yield then
        yield()
      end
    end
    files.save("output", plan.xml)
    notify(86, "Importing cleaned sequence")
    files.import("Sequence " .. input.number, "output")
    return plan.xml
  end

  local function recovery()
    if backup then
      return "Original data is backed up in Sequence "
        .. backup
        .. ". Earlier successful changes are not rolled back automatically."
    end
    return "No backup was created; sequence import did not start."
  end

  return { apply = apply, recovery = recovery }
end

return { new = new }
