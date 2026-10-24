# grandMA2 + Lua research notes

Everything we know about writing Lua plugins for grandMA2.
Started 2026-10-24 on grandMA2 onPC 3.9.60 (Windows 11).

## How sure are we?

Every fact has a tag:

| Tag    | Meaning                                                       |
| ------ | ------------------------------------------------------------- |
| `[V]`  | **Verified** on Kirk's laptop (probe plugin, files on disk)   |
| `[MA]` | Written in MA's own example plugins that ship with onPC       |
| `[M]`  | From Claude's memory. Probably right, but **test it first**   |
| `[?]`  | Open question. Nobody has checked yet                         |

When a `[M]` or `[?]` fact gets tested, change its tag.

---

## 1. Where things live on Windows

| What                     | Path                                                           |
| ------------------------ | -------------------------------------------------------------- |
| Program                  | `C:\Program Files\MA Lighting Technologies\grandma\grandMA2 onPC 3.9.60.65\` `[V]` |
| Data root                | `C:\ProgramData\MA Lighting Technologies\grandma\gma2_V_3.9.60\` `[V]` |
| Plugins folder           | `<data root>\plugins\` `[V]`                                   |
| MA example plugins       | `<data root>\plugins\plugin_1.lua`, `plugins\systemtests\*.lua` `[V]` |
| LuaSocket (Lua part)     | `<data root>\plugins\requirements\socket\*.lua` `[V]`          |
| Shows                    | `<data root>\shows\*.show.gz` `[V]`                            |
| `gma.export_json` output | `<data root>\temp\` `[V]`                                      |

- Two onPC builds are installed (3.9.60.45 and 3.9.60.65). They share
  one data root. `[V]`
- There is **no Lua DLL** in the program folder. Lua is built into
  `gma2onpc.exe` itself (statically linked). `[V]`
- MA2 does **not** write the System Monitor to a log file. `[V]`
  Workaround: collect lines in a table and `gma.export_json()` them.

## 2. Lua environment

| Check                | Result                     |
| -------------------- | -------------------------- |
| `_VERSION`           | `Lua 5.3` `[V]`            |
| `os.execute`         | function `[V]`             |
| `io.popen`           | function `[V]`             |
| `require`            | function `[V]`             |
| `package.loadlib`    | function `[V]`             |

Lua 5.3 details that matter `[M]`:

- Numbers have two subtypes: integer and float (`math.type(x)`).
  `3 // 2 == 1` (integer division), `3 / 2 == 1.5`.
- `utf8` library exists. `goto` exists. `setfenv` does **not**.
- `table.unpack`, not `unpack`.

## 3. Plugin anatomy

### 3.1 The two files

An imported plugin is an XML file that points to a Lua file. `[V]`

```xml
<?xml version="1.0" encoding="utf-8"?>
<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns="http://schemas.malighting.de/grandma2/xml/MA"
    xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA
      http://schemas.malighting.de/grandma2/xml/3.0.187/MA.xsd"
    major_vers="3" minor_vers="0" stream_vers="187">
    <Info datetime="2026-10-24T12:00:00" showfile="probe" />
    <Plugin index="1" execute_on_load="0" name="Probe Patch"
            luafile="probe-patch.lua" />
</MA>
```

- `name` is the label in the Plugins pool. A `|` in it becomes a line
  break on the pool button (`name="API|Test"`). `[MA]`
- `execute_on_load="1"` runs the plugin when the show loads. `[MA]` `[?]`
- Import: `Import "probe-patch.xml" At Plugin 99`. Run: `Plugin 99`. `[V]`
- MA2 keeps its **own copy** of the plugin after import. After you edit
  the Lua file: `Delete Plugin 99`, import again. `[V]`
- The copy is stored inside the show file, so plugins travel with the
  show to other consoles. `[M]`

### 3.2 The Lua file

```lua
local internalName = select(1, ...)
local visibleName = select(2, ...)

local function start()
  gma.echo("hello from " .. visibleName)
end

local function cleanup()
end

return start, cleanup
```

- The file is run once when the plugin **loads**. It receives two
  arguments: internal name and visible name. `[MA]`
- It **must return** the entry function. It may also return a cleanup
  function, called when the plugin is stopped. `[MA]`
- `Plugin N` calls the entry function. `[V]`

### 3.3 Threading and blocking

- Plugins run as **coroutines** inside MA's main loop. `gma.sleep(s)` is
  the same as `coroutine.yield(s)`: it gives control back to MA. `[MA]`
- Any call that blocks without yielding **freezes the whole console**:
  long loops, `os.execute("x.bat")`, `io.popen`, network waits. `[M]`
  For Windows programs use fire-and-forget:
  `os.execute('start "" /b script.bat')`. `[M]` `[?]`
- `gma.timer(fn, dt, maxCount, cleanup)` calls `fn(t, n)` every `dt`
  seconds, `maxCount` times. `[MA]`
- **File-level state survives between runs.** MA keeps the loaded chunk
  in memory, so a `local report = {}` at the top of the file still holds
  the lines of the previous run. Reset state inside the entry
  function. `[V]`

## 4. The `gma` API (complete list for 3.9)

Source: `plugin_1.lua` and `systemtests\api_test.lua` `[MA]`.
There are **no setter functions** for objects. To change the show, run
commands with `gma.cmd()`. `[MA]`

### 4.1 Core

| Function                                     | Notes                                       |
| -------------------------------------------- | ------------------------------------------- |
| `gma.echo(...)`                              | Prints to the **System Monitor**            |
| `gma.feedback(...)`                          | Prints to the **command line feedback**     |
| `gma.cmd(command) -> errorText or nil`       | Runs a command line. `nil` = success `[MA]` |
| `gma.sleep(seconds)`                         | Yields (see 3.3)                            |
| `gma.timer(fn, dt, maxCount, [cleanup])`     | Repeated callback `fn(t, n)`                |
| `gma.gettime() -> number`                    | Current time                                |
| `gma.build_date()`, `gma.build_time()`       | Strings                                     |
| `gma.git_version()`                          | Version hash string                         |
| `gma.gethardwaretype() -> string`            |                                             |
| `gma.textinput(title, [old]) -> string`      | Text input popup                            |

### 4.2 Files

| Function                                 | Notes                                    |
| ---------------------------------------- | ---------------------------------------- |
| `gma.export(file, table)`                | XML                                      |
| `gma.export_csv(file, table)`            | CSV                                      |
| `gma.export_json(file, table)`           | JSON, lands in `<data root>\temp\` `[V]`. Does **not** escape `"` in strings: invalid JSON `[V]` |
| `gma.import(file, [subfolder]) -> table` | Reads **XML from `gma.export` only** `[MA]` |

### 4.3 GUI

| Function                                         | Notes                         |
| ------------------------------------------------ | ----------------------------- |
| `gma.gui.confirm(title, msg) -> bool`            | Modal OK / Cancel             |
| `gma.gui.msgbox(title, msg)`                     | Non-modal, since 3.2.1 `[MA]` |
| `gma.gui.progress.start(name) -> handle`         | Progress bar                  |
| `gma.gui.progress.setrange(h, from, to)`         |                               |
| `gma.gui.progress.set(h, value)`                 |                               |
| `gma.gui.progress.settext(h, text)`              |                               |
| `gma.gui.progress.stop(h)`                       |                               |

A `|` in a message text is a line break. `[MA]`

### 4.4 Show objects (read only)

| Function                                    | Returns                                  |
| ------------------------------------------- | ---------------------------------------- |
| `getobj.handle(name)`                       | number handle, or nil (`"sequence 1"`)   |
| `getobj.verify(h)`                          | bool: handle still valid                 |
| `getobj.class(h)`                           | class name, e.g. `CMD_SEQUENCE`          |
| `getobj.index(h)`                           | index in parent (0-based) `[MA]`         |
| `getobj.number(h)`                          | command line number **as a string** `[MA]` |
| `getobj.name(h)`                            | label + `" "` + number: `"test_seq 1"` `[MA]` |
| `getobj.label(h)`                           | label, or nil if none                    |
| `getobj.amount(h)`                          | number of children                       |
| `getobj.child(h, i)`                        | child handle, **i is 0-based** `[V]`     |
| `getobj.parent(h)`                          | parent handle                            |
| `getobj.compare(h1, h2)`                    | bool: same object                        |
| `property.amount(h)`                        | number of properties                     |
| `property.name(h, i)`                       | property name, **i is 0-based** `[V]`    |
| `property.get(h, i or name)`                | value **as a string**                    |

(`getobj` = `gma.show.getobj`, `property` = `gma.show.property`.)

Correct loops `[MA]`:

```lua
for i = 0, getobj.amount(h) - 1 do ... getobj.child(h, i) ... end
for i = 0, property.amount(h) - 1 do ... property.name(h, i) ... end
```

Gotcha: a sequence with cues 1..3 has **4** children. Child 0 is the
hidden cue 0. `[MA]`

Handles by name, tested in Kirk's show `[V]`:

| Call                          | Result                                  |
| ----------------------------- | --------------------------------------- |
| `handle("Fixture 1001")`      | `CMD_FIXTURE` "Dim 1 1001" (FixId 1001) |
| `handle("Channel 801")`       | `CMD_FIXTURE` "Dim 1 801" (ChaId 801)   |
| `handle("Fixture 801")`       | nil (801 is only a Channel ID)          |

So `Fixture N` and `Channel N` find a fixture **without any `cd`**, and
they return the same `CMD_FIXTURE` objects as the patch tree.

### 4.5 DMX

| Function                                         | Notes                       |
| ------------------------------------------------ | --------------------------- |
| `gma.show.getdmx(addr) -> value`                 | One DMX value               |
| `gma.show.getdmx(recycle, addr, amount) -> table`| Many values, reuses a table |

`addr` is probably an absolute address, 1-based:
`(universe - 1) * 512 + channel`. `[M]` `[?]`

### 4.6 Variables

| Function                         | Scope                    |
| -------------------------------- | ------------------------ |
| `gma.show.getvar(name)`          | Show (global) variables  |
| `gma.show.setvar(name, value)`   |                          |
| `gma.user.getvar(name)`          | Current user's variables |
| `gma.user.setvar(name, value)`   |                          |
| `gma.user.getcmddest() -> h`     | Handle of the current `cd` location |
| `gma.user.getselectedexec() -> h`| Selected executor        |

Built-in show variables seen in MA's tests `[MA]`: `VERSION`,
`SHOWFILE`, `HOSTTYPE`, `HOSTSUBTYPE`, `HOSTIP`, `SELECTEDEXEC`.
Values are strings. In the command line they are `$VERSION` etc. `[M]`

### 4.7 Network (MA-Net session)

`gma.network.`: `gethosttype`, `gethostsubtype`, `getprimaryip`,
`getsecondaryip`, `getstatus`, `getsessionnumber`, `getsessionname`,
`getslot`, `gethostdata(ip, [recycle])`, `getmanetslot(slot,
[recycle])`, `getperformance(slot, [recycle])`. `[MA]`
`gethostdata(nil)` returns a table about this host with a `version`
key. `[MA]`

### 4.8 Undocumented

- `gma.canbus.hardkey(keyCode, pressed, ?) -> bool` presses a virtual
  key. MA's test uses 54 = Esc, 106 = Please. `[MA]`

## 5. The command line from Lua

- Several commands in one call, separated by `;`. `[MA]`
  `gma.cmd('cd /; cd "EditSetup"; cd "Layers"')`
- `/nc` = no confirmation, `/o` = overwrite. `[MA]`
- `cd` walks the object tree like folders. It changes the **user's**
  command line location too, so always finish with `gma.cmd("cd /")`.
  `[MA]`
- `assign <objects> /<Property>=<value>` changes properties of objects
  at the current `cd` location. `[MA]`
  `assign thru /FixId=101`, `assign 1 /Patch=1.001`
- `gma.cmd` returns an error text on failure. On success it returns
  **no value at all** (not even `nil`), so `tostring(gma.cmd(x))`
  crashes with "value expected". Store it first:
  `local problem = gma.cmd(x)`. `[V]`
- **Duplicate IDs are stolen, silently.** Assigning FixId 9002 to a
  fixture while another fixture has 9002 moves the ID: the old owner
  loses it, no error. `[V]` So a plugin must never create a duplicate,
  not even for a moment.
- `cd /; cd "EditSetup"; cd "Layers"; cd 3` enters the layer with
  **number** 3 ("fren", index 2). `[V]`
- **Gotcha:** `getobj.compare(getcmddest(), layer)` returned **false**
  although both were layer "fren 3" (same class, name and index). So
  `compare` is not reliable for "same object". Compare class + name +
  index instead. `[V]`
- **Gotcha:** inside a layer, `assign 2 /FixId=9002` and
  `assign 802 /FixId=9002` both returned `nil`, but reading the fixture
  **right after** showed no change, even after `gma.sleep(0.5)`. `[V]`
  The change **did** appear later: "fren" showed `Fixtures=[9002..9002]`
  after the plugin had ended with `cd /`. `[V]`
- **EditSetup is an edit session.** Changes made inside it are applied
  when you leave it with `cd /`, and are readable **at once** after
  that. No sleep needed. `[V]` (probe 4)

### Changing IDs: the recipe `[V]` (probe 4)

```
cd /; cd "EditSetup"; cd "Layers"; cd <layer number>; assign <pos> /FixId=5
cd /
```

- `<pos>` is the fixture's **position** in the layer, 1-based
  (= `getobj.index(fixture) + 1`). Not its ID.
- Clear an ID with an **empty** value: `/FixId=` or `/ChaId=`.
- A fixture may have only a FixId or only a ChaId.
- Children of a layer are **not** sorted by ID: in `tr_profiles`
  (Fixtures 201..402) Fixture 401 is at index 0. Probably creation
  order. `[V]` Still, find the position fresh before every command.

### Locating a fixture without walking the tree `[V]` (probe 5)

```lua
local fixture = getobj.handle("Channel 802")   -- or "Fixture 1001"
local layer = getobj.parent(fixture)           -- CMD_FIXTURE_LAYER
local layerNumber = getobj.number(layer)       -- "3" -> cd 3
local position = getobj.index(fixture) + 1     -- 2   -> assign 2
```

`getobj.child(layer, getobj.index(fixture))` returns the same fixture
again. The layer's parent is `Layers` (`CMD_FIXTURE_LAYER_COLLECT`).

### GUI progress window `[V]` (probe 5)

`gma.gui.progress.start(title)`, `setrange(h, 0, n)`, `settext(h, t)`,
`set(h, i)`, `stop(h)` work. Return a cleanup function from the plugin
(`return start, cleanup`) that stops the progress window, so it also
closes when the plugin is stopped halfway.
- MA's own test patches like this: `cd <position>` into the fixture,
  `assign 1 /Patch=1.001` (child 1 = the instance), `cd ..`. And it
  moves fixtures without `cd`: `assign Fixture 101 /posx=2`. `[MA]`

## 6. The patch tree (EditSetup)

Verified by the probe on show `plugins_testing` `[V]`:

```
cd /; cd "EditSetup"; cd "Layers"
Layers                       [CMD_FIXTURE_LAYER_COLLECT]
 +- layer 0 "Auto-Created"   [CMD_FIXTURE_LAYER]
 |   +- "[Preset] Dim"       [CMD_FIXTURE]  FixId=-  ChaId=-
 +- layer 7 "dimmers"        [CMD_FIXTURE_LAYER]  Channels=[1..24]
     +- "Dim 1"              [CMD_FIXTURE]  FixId=-  ChaId=1
         +- child 0          [CMD_SUBFIXTURE]  FixId=-  ChaId=1
```

### Layer properties

`Name`, `Fixtures` (range text like `[1001..1010] `, empty if none),
`Channels` (same format), `Info`.

### Fixture properties (`CMD_FIXTURE`)

| Index | Name           | Example                              |
| ----- | -------------- | ------------------------------------ |
| 0     | `Name`         | `Dim 1`                              |
| 1     | `FixId`        | `1001`, or `-` when empty            |
| 2     | `ChaId`        | `801`, or `-` when empty             |
| 3     | `Fixture Type` | `2 Dimmer 00` (number + name)        |
| 4     | `Patch`        | `1.401` (universe.address) or ` (-)` |
| 5     | `No\|Parameters` |                                    |
| 6-11  | `Pos\|X` .. `Rot\|Z` | `0.00`                         |
| 12    | `Info`         |                                      |
| 13    | `RDM\|ID`      |                                      |

(In MA the names contain a real `|`, e.g. `No|Parameters`. The `\` is
only Markdown escaping.)

### Subfixture properties (`CMD_SUBFIXTURE`)

Same IDs in a different order: `0 FixId`, `1 ChaId`, `2 Name`, then
`Fixture|Type`, `Patch`, `React to|Master`, `Pan DMX|Invert`,
`Tilt DMX|Invert`, `Pan Enc.|Invert`, `Tilt Enc.|Invert`,
`Pan|Offset`, `Tilt|Offset`, `Swap`, `Bitmap|Disable`, `Color`,
`Pos|X..Z`, `Rot|X..Z`, `No|Parameters`, `RDM|ID`.

Lesson: **read properties by name, never by index**. The order is
different on different classes.

### Facts about IDs

- An empty ID is the text `-`. `[V]`
- Fixture IDs and Channel IDs are **separate number spaces**. Fixture
  101 and Channel 101 can exist at the same time (Kirk's show does). `[V]`
- Layer 0 "Auto-Created" holds `[Preset]` fixtures with no IDs.
  Skip them. `[V]`
- `getobj.name(fixture)` = name + `" "` + ID (`"Dim 1 1001"`). Use the
  `Name` property for the clean name. `[V]`
- MA's own test sets IDs with `assign thru /FixId=N` and
  `assign thru /ChaId=N` inside a layer. `[MA]`
- How to **clear** an ID (`/ChaId=`? `/ChaId=-`?) `[?]`
- Can a fixture have **no** ID at all? Probably not, so set the new ID
  first, then clear the old one. `[M]` `[?]`
- Multi-instance fixtures: every instance is a `CMD_SUBFIXTURE`. Can
  instances have their own IDs? `[?]`

## 7. Talking to the outside world

| Way                         | Direction | Status                                    |
| --------------------------- | --------- | ----------------------------------------- |
| `os.execute`, `io.popen`    | MA -> PC  | Exist on onPC `[V]`. Block MA! (see 3.3)  |
| `io.open` (write a file)    | MA -> PC  | Works, wrote to `%TEMP%` `[V]`            |
| `gma.export_json` / `gma.import` | both | Works `[V]`. Simple and safe            |
| LuaSocket                   | both      | **Built into MA2** `[V]`, see below       |
| DMX trigger channel         | MA -> PC  | MA outputs Art-Net, a PC service listens  |
| Telnet remote               | PC -> MA  | Port 30000, must be enabled in Setup `[M]` |

### LuaSocket

- MA ships the Lua part of LuaSocket in `plugins\requirements\socket\`.
  It does `require("socket.core")`, the C part. `[V]`
- No `socket\core.dll` is on disk, but `pcall(require, "socket.core")`
  returns `true` and a table. So **`socket.core` is built into
  `gma2onpc.exe`**. `[V]` Real sockets (UDP/TCP) from a plugin are
  possible. Blocking calls still freeze MA: use timeouts of 0. `[M]`
- **Never** load a downloaded `core.dll`: it brings its own copy of Lua.
  Two Lua runtimes in one process usually crash. We don't need it. `[M]`

### `require` search paths `[V]`

```
package.path  = <data root>/plugins/?.lua;
                <data root>/plugins/requirements/?.lua
package.cpath = <data root>/plugins/?.dll;
                <data root>/plugins/requirements/?.dll
```

So `require("socket")` finds `plugins/requirements/socket.lua`... if it
exists there (MA ships `requirements/socket/socket.lua`, so maybe
`require("socket.socket")`). `[?]`
A plugin could also `require` our own modules from the plugins folder.
We bundle anyway: the bundle travels inside the show file, loose module
files do not. `[M]`

### Real consoles

- A plugin runs on the machine that runs MA2. On a real console,
  `os.execute` runs on the **console's** operating system, not on a
  PC. `[M]`
- So anything that must work from a console needs a network way
  (DMX trigger, Telnet, MA-Net). `[M]`

## 8. Open questions (next probes)

1. ~~How to clear `FixId` / `ChaId`?~~ Empty value: `/FixId=`. `[V]`
2. ~~Does `pcall(require, "socket.core")` work?~~ Yes, built in. `[V]`
3. ~~Does `io.open` work?~~ Yes, to `%TEMP%`. Current folder still `[?]`
4. Does `os.execute('start "" /b ...')` return at once?
5. Multi-instance fixtures: where do instance IDs live?
6. ~~Does `getobj.handle("Fixture 101")` work?~~ Yes, see 4.4. `[V]`
7. ~~Where does `cd <number>` inside `Layers` land?~~ In the layer with
   that number. `[V]`
9. ~~Does `getobj.parent(handle("Channel 802"))` return the layer?~~
   Yes. `[V]`
10. How fast is one `cd /` commit in a big show (hundreds of fixtures)?
8. Does `assign Fixture 1001 /FixId=...` work **without** `cd`?
