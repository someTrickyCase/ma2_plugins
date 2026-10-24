# The `gma` API (complete list for 3.9)

Source: `plugin_1.lua` and `systemtests\api_test.lua` `[MA]`.
There are **no setter functions** for objects. To change the show, run
commands with `gma.cmd()` (see `command-line.md`). `[MA]`

## Core

| Function                                 | Notes                                         |
| ---------------------------------------- | --------------------------------------------- |
| `gma.echo(...)`                          | Prints to the **System Monitor**              |
| `gma.feedback(...)`                      | Prints to the **command line feedback**       |
| `gma.cmd(command) -> [errorText]`        | Runs a command line. No value = success `[V]` |
| `gma.sleep(seconds)`                     | Yields to MA (see `plugin-anatomy.md`)        |
| `gma.timer(fn, dt, maxCount, [cleanup])` | Repeated callback `fn(t, n)`                  |
| `gma.gettime() -> number`                | Current time                                  |
| `gma.build_date()`, `gma.build_time()`   | Strings                                       |
| `gma.git_version()`                      | Version hash string                           |
| `gma.gethardwaretype() -> string`        |                                               |
| `gma.textinput(title, [old]) -> string`  | Text input popup                              |

## Files

| Function                                 | Notes                                      |
| ---------------------------------------- | ------------------------------------------ |
| `gma.export(file, table)`                | XML                                        |
| `gma.export_csv(file, table)`            | CSV                                        |
| `gma.export_json(file, table)`           | JSON, lands in `<data root>\temp\` `[V]`   |
| `gma.import(file, [subfolder]) -> table` | Reads **XML from `gma.export` only** `[MA]` |

`gma.export_json` does **not** escape `"` in strings, so the JSON is
invalid. Replace `"` with `'` before export. `[V]`

## GUI

| Function                                 | Notes                         |
| ---------------------------------------- | ----------------------------- |
| `gma.gui.confirm(title, msg) -> bool`    | Modal OK / Cancel             |
| `gma.gui.msgbox(title, msg)`             | Non-modal, since 3.2.1 `[MA]` |
| `gma.gui.progress.start(name) -> handle` | Progress bar `[V]`            |
| `gma.gui.progress.setrange(h, from, to)` | `[V]`                         |
| `gma.gui.progress.set(h, value)`         | `[V]`                         |
| `gma.gui.progress.settext(h, text)`      | `[V]`                         |
| `gma.gui.progress.stop(h)`               | `[V]`                         |

A `|` in a message text is a line break. `[MA]`

## Show objects (read only)

(`getobj` = `gma.show.getobj`, `property` = `gma.show.property`.)

| Function                     | Returns                                       |
| ---------------------------- | --------------------------------------------- |
| `getobj.handle(name)`        | number handle, or nil (`"sequence 1"`)        |
| `getobj.verify(h)`           | bool: handle still valid                      |
| `getobj.class(h)`            | class name, e.g. `CMD_SEQUENCE`               |
| `getobj.index(h)`            | index in parent (0-based) `[V]`               |
| `getobj.number(h)`           | command line number **as a string** `[V]`     |
| `getobj.name(h)`             | label + `" "` + number: `"Dim 1 1001"` `[V]`  |
| `getobj.label(h)`            | label, or nil if none                         |
| `getobj.amount(h)`           | number of children                            |
| `getobj.child(h, i)`         | child handle, **i is 0-based** `[V]`          |
| `getobj.parent(h)`           | parent handle                                 |
| `getobj.compare(h1, h2)`     | bool: same object. **Unreliable** `[V]`       |
| `property.amount(h)`         | number of properties                          |
| `property.name(h, i)`        | property name, **i is 0-based** `[V]`         |
| `property.get(h, i or name)` | value **as a string**                         |

Correct loops `[MA]`:

```lua
for i = 0, getobj.amount(h) - 1 do ... getobj.child(h, i) ... end
for i = 0, property.amount(h) - 1 do ... property.name(h, i) ... end
```

- A sequence with cues 1..3 has **4** children. Child 0 is the hidden
  cue 0. `[MA]`
- `getobj.compare(getcmddest(), layer)` returned **false** although both
  were layer "fren 3" (same class, name and index). Compare class +
  name + index instead. `[V]`

### Handles by name `[V]`

Tested in Kirk's show:

| Call                     | Result                                  |
| ------------------------ | --------------------------------------- |
| `handle("Fixture 1001")` | `CMD_FIXTURE` "Dim 1 1001" (FixId 1001) |
| `handle("Channel 801")`  | `CMD_FIXTURE` "Dim 1 801" (ChaId 801)   |
| `handle("Fixture 801")`  | nil (801 is only a Channel ID)          |

So `Fixture N` and `Channel N` find a fixture **without any `cd`**, and
they return the same `CMD_FIXTURE` objects as the patch tree. Recipe to
get the layer and position from such a handle: `command-line.md`.

## DMX

| Function                                          | Notes                       |
| ------------------------------------------------- | --------------------------- |
| `gma.show.getdmx(addr) -> value`                  | One DMX value               |
| `gma.show.getdmx(recycle, addr, amount) -> table` | Many values, reuses a table |

`addr` is probably an absolute address, 1-based:
`(universe - 1) * 512 + channel`. `[M]` `[?]`

## Variables

| Function                          | Scope                               |
| --------------------------------- | ----------------------------------- |
| `gma.show.getvar(name)`           | Show (global) variables             |
| `gma.show.setvar(name, value)`    |                                     |
| `gma.user.getvar(name)`           | Current user's variables            |
| `gma.user.setvar(name, value)`    |                                     |
| `gma.user.getcmddest() -> h`      | Handle of the current `cd` location |
| `gma.user.getselectedexec() -> h` | Selected executor                   |

Built-in show variables seen in MA's tests `[MA]`: `VERSION`,
`SHOWFILE`, `HOSTTYPE`, `HOSTSUBTYPE`, `HOSTIP`, `SELECTEDEXEC`.
Values are strings. In the command line they are `$VERSION` etc. `[M]`

## Network (MA-Net session)

`gma.network.`: `gethosttype`, `gethostsubtype`, `getprimaryip`,
`getsecondaryip`, `getstatus`, `getsessionnumber`, `getsessionname`,
`getslot`, `gethostdata(ip, [recycle])`, `getmanetslot(slot,
[recycle])`, `getperformance(slot, [recycle])`. `[MA]`
`gethostdata(nil)` returns a table about this host with a `version`
key. `[MA]`

## Undocumented

- `gma.canbus.hardkey(keyCode, pressed, ?) -> bool` presses a virtual
  key. MA's test uses 54 = Esc, 106 = Please. `[MA]`
