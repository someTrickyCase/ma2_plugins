# k_ma2programming

Kirk's grandMA2 Lua plugins, developed outside MA2 and delivered to it
with a script. Runs on Windows 11 with grandMA2 onPC 3.9.60.

What we know about MA2 itself (the `gma` API, the patch tree, probes)
is **not** in this repo. It is in Kirk's local Claude skill
`ma2-plugins`. Load it before writing code that calls `gma`, and update
it after every probe.

## Hard rules

- **Never commit to `main`.** Work on a branch; changes reach `main`
  only through a pull request. The `pre-commit` CI check must be green.
- **Test what you ship.** MA2 runs Lua 5.3, so tests run on Lua 5.3.
- **Safety on stage.** A plugin checks everything first and never
  touches a fixture with a conflict. It marks them for the designer
  instead (a `Conflicts` group + layout) and asks before changing
  anything else. It reads back every change. Never block
  MA's main loop (no long loops without `gma.sleep`, no waiting
  `os.execute`).
- **TDD always:** red (failing test), green (smallest code), refactor.
- SOLID and OOP best practices, BUT simplicity always wins.

## Tools

| Tool            | Version | Where                 | Config               |
| --------------- | ------- | --------------------- | -------------------- |
| `lua53`         | 5.3.6   | `C:\lua-executables`  |                      |
| `luacheck`      | 1.2.0   | `C:\lua-executables`  | `.luacheckrc`        |
| `stylua`        | 2.3.1   | `C:\lua-executables`  | `stylua.toml`        |
| LuaUnit         | 3.4     | `third_party/luaunit.lua` |                 |
| `go`            | 1.27.0  | winget                | `go.mod`             |
| `golangci-lint` | 2.15.0  | winget                | `.golangci.yml`      |
| `task`          | 3.54.0  | winget                | `Taskfile.yml`       |

CI installs the same versions (`.github/workflows/ci.yml`). When you
upgrade a tool, change both places.

## Commands

All commands go through Task. `task` alone lists them.

| Command                                | What it does                        |
| -------------------------------------- | ----------------------------------- |
| `task check`                           | rules + Lua + Go                    |
| `task rules`                           | code rules on the Lua and Go files  |
| `task lua` / `task go`                 | only one half                       |
| `task fmt`                             | format all Lua and Go files         |
| `task coverage`                        | Go coverage per package + total     |
| `task build`                           | build `dist/ma2kit.exe`             |
| `task bundle`                          | build every plugin into `dist/`     |
| `task golden`                          | rebuild the committed test bundles  |
| `task install -- <plugin>`             | check, then install into MA2        |
| `task tui`                             | check, then pick the plugins        |
| `ma2kit check-rules <file>...`         | report violations, exit 1 on any    |
| `ma2kit new <plugin-name>`             | scaffold a new plugin               |
| `ma2kit bundle <name> --out <dir>`     | build one plugin, print commands    |
| `ma2kit install <name> [--dry-run]`    | install one plugin into MA2         |
| `ma2kit tui [--dry-run]`               | pick the plugins, then install      |
| `lua53 test/run.lua <files>`           | run some Lua test files             |
| `go test ./internal/<pkg>`             | run one Go package's tests          |

`task check` must pass before every commit. `task install` runs it
first, so an install never ships a broken plugin. The `--` in
`task install -- <plugin>` is needed: Task reads the words after it as
arguments for `ma2kit`, without it Task looks for a task with that
name.

## CI

`.github/workflows/ci.yml` runs on every pull request and every push to
`main`, on Ubuntu, with two parallel jobs: `lua` runs `task lua`, `go`
runs `task go`, then `task rules` and then `task coverage`. The rules job
needs Go, because the rules checker is a Go program, and it checks the
Lua files too. CI only calls Task, so the laptop and CI run exactly the
same commands. Keep the Taskfile working on Windows and Linux.

## Go code

- Module `github.com/someTrickyCase/ma2_plugins`. `cmd/ma2kit/main.go`
  only calls `internal/cli.Run`; all logic lives in `internal/`.
- The Go modules come from the module cache, not from a `vendor/` folder.
  A `vendor/` folder at the root turns on Go's vendoring mode, so the Lua
  library lives in `third_party/` instead.
- golangci-lint runs **every** linter. Only these are off, each for a
  reason: `wsl`, `gomodguard`, `exhaustruct` (deprecated, their `_v2` /
  `_v5` successors are on), revive `exported` and `package-comments`
  (they demand doc comments; our rule is no comments). Nothing is
  excluded per file: gosec `G304` is on everywhere, and the code reads
  files through `internal/readfile`, which cannot leave the folder it
  was given.
- `depguard` allows only the Go standard library, this module and
  Bubble Tea with lipgloss (the terminal UI of the picker). A new
  dependency must be added to `.golangci.yml` on purpose.
- `ireturn` allows the Bubble Tea model, because the framework asks
  the model to return its own interface.
- Tests follow Go's convention: `x_test.go` next to `x.go`, in the
  external `x_test` package. Table tests for many cases of one function,
  small `expect...` helpers instead of repeated checks.
- No comments, as in Lua. Code explains itself through names.
- The code rules live in `internal/rules`: one file per language for the
  comment syntax (`lua.go`, `golang.go`), `rules.go` for the shared part.
  The language comes from the file extension.
- `internal/scaffold` builds a new plugin: the manifest, the entry
  point and the test. The Lua it writes is a template in the Go source,
  so you can read it there.

## Layout

```
lib/        shared modules, required as "core.x" or "ma.x"
  core/     pure logic, no gma
  ma/       thin adapters around the gma API
plugins/    one folder per plugin (kebab-case)
  <name>/plugin.json  manifest: name, file (k- prefix), version, slot
  <name>/main.lua     entry, returns start[, cleanup]
test/       mirrors lib/ and plugins/ one to one
  support/  fake-gma.lua: a fake MA for ma/ tests
  session/  end to end: a whole plugin against the fake MA
  bundles/  the built plugins, the golden files of the Go tests
cmd/ma2kit/ Go entry point, one line of logic
internal/   Go packages, each with its _test.go files
  cli/      command dispatch, reads the files the commands work on
  rules/    the code rules: ASCII only, no comments
  bundle/   the bundler: one plugin file and one XML for MA2
  manifest/ the plugin manifest, read and written
  scaffold/ builds a new plugin from a template
  readfile/ reads a file by name, without leaving its folder
  buildinfo/ version and commit stamp
  mahome/   where MA2 keeps its data: the version folders
  install/  the install: check the rules, copy the files
  tui/      the picker: a small terminal program (Bubble Tea)
.github/    CI workflow
Taskfile.yml    the one entry point for every check and build
third_party/ other people's code. Do not edit. Not linted.
scratch/    experiments and probes. Ignored by Git and tools.
dist/       build output. Ignored by Git.
```

## Architecture

Two tracks. **Lua** is what MA2 runs. **Go** is the tooling that builds
and checks the Lua. They never mix: the Go code never ships to MA2, and
the Lua code never calls the Go tool at runtime. The Go track takes
over the dev tooling one piece at a time (issue #3, phases 1 to 6).

### Lua: the plugins

```
plugins/<name>/main.lua   reads the global gma, passes it down
        |
lib/ma/swap-flow.lua      the whole run: read -> plan -> ask -> write
   |            |
lib/ma/*      lib/core/*
talks to MA   pure logic, no gma, easy to test
```

- `main.lua` is 3 lines and the **only** place that reads the global
  `gma`. Everything below gets `gma` as an argument, so tests can pass
  `test/support/fake-gma.lua` instead.
- `core/` never sees `gma`. It works on plain tables like
  `{ name = "Dim 1", layer = "fren", fixId = 1001, chaId = nil }`.

### Go: the tool

```
cmd/ma2kit/main.go   calls internal/cli.Run and nothing else
        |
internal/cli/        one file per command, reads the files
        |
internal/rules/      the code rules, one file per language
internal/bundle/     the bundler: the plugin file and the MA2 XML
internal/manifest/   the plugin manifest, read and written
internal/mahome/     where MA2 keeps its data: the version folders
internal/install/    the install: check the rules, copy the files
internal/tui/        the picker: the terminal program
```

- `main.go` is a wrapper: it hands the arguments and the streams to
  `cli.Run` and exits with the code it returns. `cli.Run` returns the
  exit code instead of calling `os.Exit`, so the tests can call it and
  look at the result.
- `internal/cli` owns the IO: it reads the files a command works on and
  maps the file extension to the language.
- `internal/rules` is pure: text in, violations out. It never touches
  the disk, so every rule is tested with a string.
- The rules are per language, because the comment syntax is: `lua.go`
  knows `--` and `--[[ ]]`, `golang.go` knows `//` and `/* */`.
  `rules.go` holds what both share: the ASCII rule, the report format
  and the sorting.
- `internal/bundle` is pure too: paths and text in, text out. The
  bundler follows the `require("...")` calls of the entry point into
  `lib/`, packs everything into one Lua file with its own small
  `require`, and writes the MA2 XML next to it.
- `internal/manifest` holds the plugin manifest. It is JSON, because Go
  cannot run a Lua table. `ma2kit new` writes it, the bundler reads it.
- `internal/mahome` knows where MA2 keeps its data. The versions are
  compared as numbers, so 3.10.0 is newer than 3.9.60.
- `internal/install` is the install itself: check the built file
  against the code rules, refuse a file name that is not ours, copy
  the files and return the MA2 commands.
- `internal/tui` is the picker. The model is a small state machine
  (plugins, versions, done) and the view draws the list. Every key
  comes in as `key.String()`, so the switch is on a string and not on
  the huge key type of the framework.

### The ID-swap plugins

`channel-to-fixture` and `fixture-to-channel` are the same code with
`from` and `to` swapped (`swap-flow.new(gma, { from, to, title })`).

1. `ma/patch-reader` reads all fixtures from EditSetup into plain
   tables.
2. `core/swap-ids.plan` builds the steps. Fixtures that would end with
   the same ID are a conflict and are **skipped**: they keep their IDs.
   A skipped fixture's target ID can block another mover, so planning
   repeats until no new conflict appears. Steps come in 3 phases, so MA
   never sees a duplicate (MA silently steals IDs): clear `to` IDs that
   get overwritten, set the new `to` IDs, clear the old `from` IDs.
3. Conflicts -> `ma/conflict-group` selects the skipped fixtures,
   stores Group + Layout `Conflicts` (first free numbers) and checks the
   group by recalling it and counting `$SELECTEDFIXTURESCOUNT`. Then ask
   "move the others?". Only conflicts -> show the list, no ID changes.
   No steps -> say so. Otherwise ask OK / Cancel (`core/report` makes
   all texts).
4. `ma/patch-writer` applies the steps one by one: locate the fixture
   fresh by its current ID and check the name, `assign`, `cd /`, read
   back. It stops at the first surprise.
5. A progress window runs during step 4. `cleanup` closes it if the
   plugin is stopped halfway.

### Build and install

- `ma2kit bundle` starts at `plugins/<name>/main.lua`, follows every
  `require("...")` into `lib/`, and packs everything into **one** Lua
  file with its own small `require`. One file travels inside the show
  file; loose modules would not. It also writes the MA2 XML and a stamp
  (version, commit, date).
- The built files live in `test/bundles/` as the **golden files**: the
  Go test compares its own output with them, byte for byte. They were
  made by the Lua bundler before it was replaced by the Go one, so they
  are the proof that the two produce the same file. `task golden`
  rebuilds them; only run it when the change is wanted.
- The session tests load `test/bundles/<file>.lua`, so they run the
  real artifact that MA2 gets, not a rebuild in memory.
- `ma2kit install <plugin>` finds MA's plugins folder (the newest
  `gma2_V_*`, or the one `--ma-version` names), builds the plugin,
  checks the built file against the code rules, copies both files and
  prints the MA2 commands as a numbered list. It never touches the
  clipboard. `--dry-run` does everything but the copying.
- The install is in `internal/install`, not in the CLI, so the TUI of
  phase 5 can use the same code. `internal/mahome` knows where MA2
  keeps its data and compares the versions as numbers, not as text.

### Decisions

- A fixture with both IDs: the target ID is overwritten.
- Plugins are developed here and installed by script, never edited in
  MA's own folder.
- Folder and file names are kebab-case. The tools are Go (the rules,
  the bundler and the installer), Lua (the plugins) and Task (the one
  entry point).

### Next

Phases 4 and 5 are done: the install is a Go command, the PowerShell is
gone, and `ma2kit tui` picks the plugins in a small window.

- Phase 6: the release zip on tag `v*`. CI builds every plugin, writes
  `dist/plugins.json` (name, version, slot, files), zips the installer
  and the bundles -> GitHub Release. The picker must read
  `plugins.json` there, next to the bundles, and not
  `plugins/*/plugin.json` from the repo.
- Still open from the four requirements: more agent tools (`ma2kit
  probe` to query MA2, `ma2kit api`/`docs`), and the skills repo.

## Code conventions

Enforced by tools:

- Max line width 80. Lua 5.3 syntax only (StyLua `syntax = "Lua53"`,
  luacheck `std = "lua53"`).
- Only printable ASCII and LF line endings. Build non-ASCII characters
  with `string.char(...)` or `utf8.char(...)`. In Go, a tab is allowed:
  `gofumpt` indents with tabs, so the rule keeps tabs and rejects every
  other control character.
- No comments in code files (`ma2kit check-rules`, `internal/rules`). No
  inline luacheck config (`inline = false`).
- Cyclomatic complexity at most 10 per function.
- Never make a tool less strict. If a rule blocks you, change the code.
  The MA2 XML needs `http://` namespace URLs and revive's
  `unsecure-url-scheme` does not like them, so they are built from
  `httpScheme + "//..."` in `internal/bundle/xml.go` instead of turning
  the rule off.

Not enforced, but expected:

- No globals. Modules return a table. The only global we read is `gma`,
  and only in `plugins/*/main.lua`, which passes it on to `ma/` code.
- Read MA properties **by name**, never by index.
- Always end `gma.cmd` work with `cd /`. Check the return value of every
  `gma.cmd` (no value = success).

## Tests

- File `lib/core/x.lua` -> test `test/lib/core/x.test.lua`.
- A test file returns a table of functions named `test...`.
- `core/` tests use plain tables. `ma/` tests use a fake `gma`.
- `test/session/` holds the end to end tests. They load the built
  plugin from `test/bundles/` and run it against the fake MA2, then
  assert the exact command session MA2 would receive. One wrong
  command fails the test, and the diff shows which one.
- `test/bundles/` holds the built plugins. `internal/bundle` compares
  its own output with those files, byte for byte. They were made by
  the old Lua bundler, so they are the proof that the Go one builds the
  same file. Rebuild them with `task golden`, and only when the change
  is wanted.
- `test/support/session.lua` runs a plugin against the fake MA. Use it
  instead of writing the setup again.
- Go tests live next to the code: `internal/rules/rules.go` ->
  `internal/rules/rules_test.go`, in the external `rules_test` package.
- `task coverage` prints the Go coverage per package and the total. The
  README badge shows that total; refresh the badge when it moves.
