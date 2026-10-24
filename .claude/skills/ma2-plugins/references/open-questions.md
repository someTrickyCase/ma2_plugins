# Open questions (next probes)

When one is answered: move the fact to its topic file with a `[V]` tag
and add it to "Answered" below.

## Still open

1. Does `os.execute('start "" /b ...')` return at once?
2. Multi-instance fixtures: where do instance IDs live?
3. Does `assign Fixture 1001 /FixId=...` work **without** `cd`?
4. How fast is one `cd /` commit in a big show (hundreds of fixtures)?
5. Does `Import "x.xml" At Plugin N` on an **occupied** slot ask to
   overwrite, refuse, or overwrite silently?
6. Is `gma.sleep(0.01)` after every step needed to keep the console
   and the progress window alive? (see `lib/ma/swap-flow.lua`)
7. Does a plugin travel inside the show file to a real console?
8. Can a patched fixture (not a `[Preset]` one) lose both IDs?
9. Does `execute_on_load="1"` really run the plugin on show load?
10. `require("socket")` or `require("socket.socket")`?
11. `io.open` with a relative path: which folder is "current"?
12. Is the `getdmx` address `(universe - 1) * 512 + channel`?

## Answered

| Question                                         | Answer                         |
| ------------------------------------------------ | ------------------------------ |
| How to clear `FixId` / `ChaId`?                  | Empty value: `/FixId=` `[V]`   |
| Does `pcall(require, "socket.core")` work?       | Yes, built in `[V]`            |
| Does `io.open` work?                             | Yes, to `%TEMP%` `[V]`         |
| Does `getobj.handle("Fixture 101")` work?        | Yes, no `cd` needed `[V]`      |
| Where does `cd <number>` inside `Layers` land?   | Layer with that number `[V]`   |
| `getobj.parent(handle("Channel 802"))` = layer?  | Yes `[V]`                      |
