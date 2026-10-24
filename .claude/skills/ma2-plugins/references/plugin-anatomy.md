# Plugin anatomy

## The two files

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
- Our bundler (`dev/build/bundler.lua`) writes this XML for every plugin.

## Import and update

- Import: `Import "probe-patch.xml" At Plugin 99`. Run: `Plugin 99`. `[V]`
- MA2 keeps its **own copy** of the plugin after import. After you edit
  the Lua file: `Delete Plugin 99`, import again. `[V]`
- The copy is stored inside the show file, so plugins travel with the
  show to other consoles. `[M]`

## The Lua file

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
- **File-level state survives between runs.** MA keeps the loaded chunk
  in memory, so a `local report = {}` at the top of the file still holds
  the lines of the previous run. Reset state inside the entry
  function. `[V]`

## Threading and blocking

- Plugins run as **coroutines** inside MA's main loop. `gma.sleep(s)` is
  the same as `coroutine.yield(s)`: it gives control back to MA. `[MA]`
- Any call that blocks without yielding **freezes the whole console**:
  long loops, `os.execute("x.bat")`, `io.popen`, network waits. `[M]`
- `gma.timer(fn, dt, maxCount, cleanup)` calls `fn(t, n)` every `dt`
  seconds, `maxCount` times. `[MA]`

## Progress window `[V]` (probe 5)

`gma.gui.progress.start(title)`, `setrange(h, 0, n)`, `settext(h, t)`,
`set(h, i)`, `stop(h)` work. Return a cleanup function from the plugin
(`return start, cleanup`) that stops the progress window, so it also
closes when the plugin is stopped halfway.
