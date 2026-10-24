# Probing: how we learn MA2 facts

MA2 has little documentation, so we ask MA itself. A **probe** is a
small throwaway plugin that tries something and writes a report file
that Claude reads directly. Our first probes (2026-10-24) worked this
way.

## The loop

1. Claude writes `scratch/probe/probe-<topic>.lua` and `.xml`
   (`scratch/` is ignored by Git and by the tools).
2. Claude copies both files to `<data root>\plugins\`.
3. Claude prints the MA2 commands as a numbered list. **Never** touch
   Kirk's clipboard.
   1. `Delete Plugin 9x` (only if the slot is taken)
   2. `Import "probe-<topic>.xml" At Plugin 9x`
   3. `Plugin 9x`
4. Kirk runs them and says "done".
5. Claude reads `<data root>\temp\probe-<topic>.json`. No copy-paste
   from the System Monitor.
6. Claude updates the reference files: new tags, probe name, closed
   open questions.

## Rules that made it work

- Reset the report table **inside** the entry function (file-level
  state survives runs).
- Replace `"` with `'` in every line (`export_json` does not escape).
- Wrap the experiments in `pcall`, log the error, always export.
- Always `cd /` at the end.
- Read back after every change.
- Record where you landed (`gma.user.getcmddest()`), don't trust the
  return value of `gma.cmd`.
- Probes that **change** the show run only on Kirk's test show
  (`plugins_testing`), never on a real one.
- Probes are throwaway, so they skip TDD. Real plugin code never does.

## Template

`probe-<topic>.xml`: copy the XML from `plugin-anatomy.md`, change
`name` and `luafile`.

`probe-<topic>.lua`:

```lua
local REPORT_FILE = "probe-topic.json"

local getobj = gma.show.getobj
local property = gma.show.property

local report = {}

local function say(text)
  local clean = tostring(text):gsub('"', "'")
  gma.echo("probe: " .. clean)
  report[#report + 1] = clean
end

local function describe(handle)
  if not handle then
    return "nil"
  end
  return string.format(
    "class=%s name=%s number=%s index=%s",
    tostring(getobj.class(handle)),
    tostring(getobj.name(handle)),
    tostring(getobj.number(handle)),
    tostring(getobj.index(handle))
  )
end

local function experiments()
  local fixture = getobj.handle("Fixture 1001")
  say("fixture: " .. describe(fixture))
  say("FixId: " .. tostring(property.get(fixture, "FixId")))
end

local function probe()
  report = {}
  local ok, problem = pcall(experiments)
  if not ok then
    say("ERROR " .. tostring(problem))
  end
  gma.cmd("cd /")
  say("done")
  gma.export_json(REPORT_FILE, report)
end

return probe
```

For a long probe, add a progress window and `gma.sleep` between steps
(see `plugin-anatomy.md`), and return a cleanup that stops it.
