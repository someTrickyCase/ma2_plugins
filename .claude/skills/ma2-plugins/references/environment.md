# Environment: paths, Lua, outside world

## Where things live on Windows

| What                     | Path                                                    |
| ------------------------ | ------------------------------------------------------- |
| Program                  | `C:\Program Files\MA Lighting Technologies\grandma\grandMA2 onPC 3.9.60.65\` `[V]` |
| Data root                | `C:\ProgramData\MA Lighting Technologies\grandma\gma2_V_3.9.60\` `[V]` |
| Plugins folder           | `<data root>\plugins\` `[V]`                            |
| MA example plugins       | `<data root>\plugins\plugin_1.lua`, `plugins\systemtests\*.lua` `[V]` |
| LuaSocket (Lua part)     | `<data root>\plugins\requirements\socket\*.lua` `[V]`   |
| Shows                    | `<data root>\shows\*.show.gz` `[V]`                     |
| `gma.export_json` output | `<data root>\temp\` `[V]`                               |

- Two onPC builds are installed (3.9.60.45 and 3.9.60.65). They share
  one data root. `[V]`
- There is **no Lua DLL** in the program folder. Lua is built into
  `gma2onpc.exe` itself (statically linked). `[V]`
- MA2 does **not** write the System Monitor to a log file. `[V]`
  Workaround: collect lines in a table and `gma.export_json()` them
  (see `probing.md`).

## Lua environment

| Check             | Result          |
| ----------------- | --------------- |
| `_VERSION`        | `Lua 5.3` `[V]` |
| `os.execute`      | function `[V]`  |
| `io.popen`        | function `[V]`  |
| `require`         | function `[V]`  |
| `package.loadlib` | function `[V]`  |

Lua 5.3 details that matter `[M]`:

- Numbers have two subtypes: integer and float (`math.type(x)`).
  `3 // 2 == 1` (integer division), `3 / 2 == 1.5`.
- `utf8` library exists. `goto` exists. `setfenv` does **not**.
- `table.unpack`, not `unpack`.

### `require` search paths `[V]`

```
package.path  = <data root>/plugins/?.lua;
                <data root>/plugins/requirements/?.lua
package.cpath = <data root>/plugins/?.dll;
                <data root>/plugins/requirements/?.dll
```

A plugin could `require` loose modules from the plugins folder. We
**bundle** anyway: the bundle travels inside the show file, loose module
files do not. `[M]`

## Talking to the outside world

| Way                              | Direction | Status                                     |
| -------------------------------- | --------- | ------------------------------------------ |
| `os.execute`, `io.popen`         | MA -> PC  | Exist on onPC `[V]`. Block MA!             |
| `io.open` (write a file)         | MA -> PC  | Works, wrote to `%TEMP%` `[V]`             |
| `gma.export_json` / `gma.import` | both      | Works `[V]`. Simple and safe               |
| LuaSocket                        | both      | **Built into MA2** `[V]`, see below        |
| DMX trigger channel              | MA -> PC  | MA outputs Art-Net, a PC service listens   |
| Telnet remote                    | PC -> MA  | Port 30000, must be enabled in Setup `[M]` |

- `os.execute` and `io.popen` wait for the program, so they freeze MA.
  Fire-and-forget might work: `os.execute('start "" /b script.bat')`.
  `[M]` `[?]`

### LuaSocket

- MA ships the Lua part of LuaSocket in `plugins\requirements\socket\`.
  It does `require("socket.core")`, the C part. `[V]`
- No `socket\core.dll` is on disk, but `pcall(require, "socket.core")`
  returns `true` and a table. So **`socket.core` is built into
  `gma2onpc.exe`**. `[V]` Real sockets (UDP/TCP) from a plugin are
  possible. Blocking calls still freeze MA: use timeouts of 0. `[M]`
- `require("socket")` would look for `plugins/requirements/socket.lua`.
  MA ships `requirements/socket/socket.lua`, so maybe
  `require("socket.socket")`. `[?]`
- **Never** load a downloaded `core.dll`: it brings its own copy of Lua.
  Two Lua runtimes in one process usually crash. We don't need it. `[M]`

### Real consoles

- A plugin runs on the machine that runs MA2. On a real console,
  `os.execute` runs on the **console's** operating system, not on a
  PC. `[M]`
- So anything that must work from a console needs a network way
  (DMX trigger, Telnet, MA-Net). `[M]`
