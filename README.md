# ma2_plugins

[![CI](https://github.com/someTrickyCase/ma2_plugins/actions/workflows/ci.yml/badge.svg)](https://github.com/someTrickyCase/ma2_plugins/actions/workflows/ci.yml)
[![Go coverage](https://img.shields.io/badge/go%20coverage-90.2%25-brightgreen)](https://github.com/someTrickyCase/ma2_plugins)

Lua plugins for grandMA2, written and tested on Windows, then delivered
to MA2 with one command.

| Plugin               | What it does                                       |
| -------------------- | -------------------------------------------------- |
| `channel-to-fixture` | Every fixture's Channel ID becomes its Fixture ID  |
| `fixture-to-channel` | Every fixture's Fixture ID becomes its Channel ID  |

## 1. One-time setup

You need this once per computer.

1. **Lua tools** in `C:\lua-executables`, and that folder in your
   **user** PATH: `lua53`, `luac53`, `luacheck`, `stylua`.
2. **Git** on PATH.
3. **Go and Task** on PATH. The installer runs the checks with Task, and
   the code rules checker, the bundler and the installer are Go programs
   (`ma2kit`).

Check it in a **new** terminal window (an old window keeps its old
PATH):

```powershell
lua53 -v          # Lua 5.3.6
luacheck --version
stylua --version
git --version
go version         # go1.27
task --version     # 3.54.0
```

## 2. Install a plugin

The easy way, with the picker:

```powershell
cd C:\k_ma2programming
task tui
```

It shows the plugins and the MA2 versions, and installs what you pick:

```
MA2 plugin installer

Plugins

> [x] Channel to Fixture  0.2.0  slot 101
  [ ] Fixture to Channel  0.2.0  slot 102

space: pick   enter: next   esc: quit
```

**space** picks a plugin, **enter** goes on to the versions, **esc** goes
back. The MA2 commands come after the picker closes, so you can copy
them.

One plugin at a time, without the picker:

```powershell
task install -- channel-to-fixture --dry-run   # dry run, copies nothing
task install -- channel-to-fixture             # real install
```

The `--` tells Task that the rest belongs to `ma2kit`, not to Task.
Without it, Task looks for a task with that name and stops.

The task:

1. runs every check (`task check`) and **stops if anything is red**
2. builds one Lua file and one XML file
3. checks the built file against our code rules
4. copies both files to the plugins folder of the **newest** MA2
   version: `C:\ProgramData\MA Lighting Technologies\grandma\
   gma2_V_<version>\plugins\`

It only ever writes files that start with `k-`, so it can never
overwrite MA's own files.

Several MA2 versions installed? Pick one:

```powershell
task install -- channel-to-fixture --ma-version 3.9.60
```

The versions are compared as numbers, so `3.10.0` is newer than `3.9.60`.

## 3. Import it in MA2

At the end, the install prints every MA2 command you need, in order.
Each command is on its own line, so it is easy to copy:

```
MA2 commands, paste them in this order:

  1. Only when updating, remove the old copy:
     Delete Plugin 101
  2. Load the plugin into the pool:
     Import "k-channel-to-fixture.xml" At Plugin 101
  3. Run it (on a show copy first!):
     Plugin 101
```

Each plugin has its own pool slot in its `plugin.json` (`"slot": 101`).
Is that slot taken in your show? Change it there, or pick another one
just for this time:

```powershell
task install -- channel-to-fixture --at 5
```

The **System Monitor** then shows the version stamp:

```
Channel to Fixture 0.2.0 (e8482d2, 2026-10-25)
```

`e8482d2` is the Git commit it was built from. If it says
`e8482d2-dirty`, it was built from changes that were not committed yet.

Build it with `task install` or `task bundle`: a plain `go run` leaves
the commit out of the stamp, and it then says `dev`.

## 4. Update to a new version

MA2 keeps **its own copy** of a plugin inside the show. Copying new files
is not enough. After the install, paste commands 1 and 2 from its list:

```
Delete Plugin 101
Import "k-channel-to-fixture.xml" At Plugin 101
```

Then check the version stamp in the System Monitor.

## 5. Use it

**Always try it on a copy of the show first.**

Run the plugin (`Plugin 1`, or press its pool button). It:

1. reads the whole patch
2. if no fixture has the ID to move: says so and changes nothing
3. if two fixtures would end up with the **same ID** (a **conflict**):
   - stores all conflicting fixtures in a new **Group** and a new
     **Layout**, both called `Conflicts` (first free numbers)
   - skips them: they keep their IDs
   - asks: *"2 conflicts: see Group 12 and Layout 4 "Conflicts". Move
     the other 228 fixtures from Channel ID to Fixture ID?"*
   - if **only** conflicting fixtures are left, it shows the list and
     changes no ID
4. without conflicts it asks: *"Move 230 fixtures from Channel ID to
   Fixture ID?"*
5. on OK: moves the IDs one by one with a progress window, and checks
   every change by reading it back
6. says *"Done: 230 fixtures moved ..."* (plus *"Skipped 2 fixtures:
   see Group 12 ..."* if there were conflicts)

Fix the conflicts by hand with the help of the `Conflicts` group and
layout, then run the plugin again. On Cancel, no ID changes, but the
group and the layout stay. Delete them when you don't need them anymore.
The plugin uses the **selection** for this, so your current selection
is cleared. Programmer values stay.

A fixture that already has **both** IDs gets its old target ID
**overwritten** (Fixture ID 7 + Channel ID 5 becomes Fixture ID 5).

If anything unexpected happens, the plugin **stops at once** and shows
the step that failed. The patch never has duplicate IDs, not even for a
moment. After you fixed the cause, just run it again: fixtures that are
already moved are skipped.

Every message also appears in the **System Monitor**, so a long
conflict list is never lost.

## 6. Real consoles

Not tested yet. Two ways that should work:

- Import the plugin on onPC, save the show, load the show on the
  console. The plugin travels inside the show file.
- Copy both files from `dist\` to the console's plugins folder (for
  example with a USB stick) and import them there.

## Troubleshooting

| You see                                   | Do this                                     |
| ----------------------------------------- | ------------------------------------------- |
| `checks are red`                          | Run `task check` to see what is wrong       |
| `missing file plugins/x/plugin.json`      | Use a folder name from `plugins\`           |
| `no MA2 version folder found`             | Is MA2 onPC installed? Try `--ma-version`   |
| `the built file breaks the code rules`    | Run `task check` to see the broken rule     |
| `lua53 is not recognized`                 | Open a new terminal. Check the PATH         |
| MA2 still runs the old version            | `Delete Plugin N`, then import again        |
| Conflict popup                            | Fix the listed IDs in the patch, run again  |

## Architecture

Two tracks live in this repo.

**Lua is what MA2 runs.** It travels to the console inside the show
file.

```
plugins/<name>/plugin.json  the manifest: name, file, version, slot
plugins/<name>/main.lua     the entry, reads the global gma, passes it down
        |
lib/ma/swap-flow.lua      the whole run: read -> plan -> ask -> write
   |            |
lib/ma/*      lib/core/*
talks to MA   pure logic, no gma, easy to test
```

`main.lua` is 3 lines and the only place that reads the global `gma`.
Everything below gets `gma` as an argument, so the tests pass a fake MA
instead. `core/` never sees `gma` at all.

The manifest is JSON, because the bundler is written in Go and Go cannot
run a Lua table.

**Go is the tooling.** It builds and checks the Lua, and never ships.

```
cmd/ma2kit/main.go   calls internal/cli.Run and nothing else
        |
internal/cli/        one file per command, reads the files
        |
internal/rules/      the code rules, one file per language
internal/bundle/     the bundler: the plugin file and the MA2 XML
internal/manifest/   the plugin manifest, read and written
internal/scaffold/   builds a new plugin from a template
internal/readfile/   reads a file by name, without leaving its folder
internal/mahome/     where MA2 keeps its data: the version folders
internal/install/    the install: check the rules, copy the files
internal/tui/        the picker: a small terminal program
```

The code rules are simple on purpose: **only printable ASCII, and no
comments.** One tool checks them, so the Lua and the Go files are held
to the same standard.

```
ma2kit check-rules lib/core/swap-ids.lua
```

The bundler packs a plugin and its modules into **one** Lua file, writes
the MA2 XML next to it and prints the commands to load it into MA2.

```
ma2kit bundle channel-to-fixture --out dist
```

The installer finds the MA2 folder, checks the built file, copies it and
prints the commands to load it into MA2.

```
ma2kit install channel-to-fixture --dry-run
```

The picker is the same thing with a window around it: Bubble Tea asks
for the plugin and the version, then the installer does the work.

```
ma2kit tui
```

## For developers

Rules, layout, architecture and conventions: `CLAUDE.md`. Run
`task check` before every commit. GitHub Actions runs the same
commands on every pull request. Developers need Go, Task and
golangci-lint too (versions in `CLAUDE.md`).

Start a new plugin with `ma2kit new <plugin-name>`. It writes the
manifest (`plugin.json`), the entry point and the test, picks a free
pool slot, and the result already passes every check.

The built plugins live in `test/bundles/`. The Go test compares its own
output with those files, byte for byte, so they must be rebuilt after a
change to a plugin: `task golden`. The end-to-end tests load the very
same files, so they run what MA2 gets.

`task bundle` builds every plugin into `dist/`, without copying anything
to MA2. That is the quickest way to look at a built file.

`task coverage` prints the Go test coverage per package and the total.
The badge above shows that total; after changing the code, run the task
and update the number if it moved.
