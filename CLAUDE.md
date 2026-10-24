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

All in `C:\lua-executables` (user PATH):

| Tool       | Version | Config               |
| ---------- | ------- | -------------------- |
| `lua53`    | 5.3.6   |                      |
| `luacheck` | 1.2.0   | `.luacheckrc`        |
| `stylua`   | 2.3.1   | `stylua.toml`        |
| LuaUnit    | 3.4     | `vendor/luaunit.lua` |

CI installs the same versions (`.github/workflows/pre-commit.yml`).
When you upgrade a tool, change both places.

## Commands

| Command                                | What it does                        |
| -------------------------------------- | ----------------------------------- |
| `.\pre-commit.ps1`                     | format check + lint + rules + tests |
| `.\install.ps1 -Plugin <name>`         | check, bundle to `dist/`, copy      |
| `.\install.ps1 -Plugin <name> -WhatIf` | same, but copy nothing              |
| `stylua .`                             | format all files                    |
| `lua53 test/run.lua <files>`           | run some test files                 |

`.\pre-commit.ps1` must pass before every commit.

## CI

GitHub Actions runs `pre-commit.ps1` on every pull request and on every
push to `main`, on Ubuntu with PowerShell 7. It is the same script as on
the laptop, so a check can't pass locally and fail in CI (or the other
way round). Keep `pre-commit.ps1` working on both Windows and Linux:
accept `\` and `/` in paths.

## Layout

```
lib/        shared modules, required as "core.x" or "ma.x"
  core/     pure logic, no gma
  ma/       thin adapters around the gma API
plugins/    one folder per plugin (kebab-case)
  <name>/plugin.lua   manifest: name, file (k- prefix), version, slot
  <name>/main.lua     entry, returns start[, cleanup]
dev/        developer scripts, never shipped to MA
  build/    bundler.lua (logic), bundle-plugin.lua (command line)
  lint/     code-rules.lua (logic), check-code-rules.lua (command line)
test/       mirrors lib/, plugins/ and dev/ one to one
  support/  fake-gma.lua: a fake MA for ma/ tests
.github/    CI workflow
pre-commit.ps1  format check + lint + code rules + tests
install.ps1     pre-commit, bundle to dist/, copy to MA
vendor/     other people's code. Do not edit. Not linted.
scratch/    experiments and probes. Ignored by Git and tools.
dist/       build output. Ignored by Git.
```

## Architecture

### Layers

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

- `dev/build/bundler.lua` starts at `plugins/<name>/main.lua`, follows
  every `require("...")` into `lib/`, and packs everything into **one**
  Lua file with its own small `require`. One file travels inside the
  show file; loose modules would not. It also writes the MA2 XML and a
  stamp (version, commit, date).
- `install.ps1` runs `pre-commit.ps1`, bundles to `dist/`, checks the
  bundle again (`luac53 -p` + code rules), copies it to MA's plugins
  folder and prints the MA2 commands as a numbered list. It never
  touches the clipboard.

### Decisions

- A fixture with both IDs: the target ID is overwritten.
- Plugins are developed here and installed by script, never edited in
  MA's own folder.
- Folder and file names are kebab-case. The tools are Lua (bundler,
  rules) and PowerShell (scripts).

## Code conventions

Enforced by tools:

- Max line width 80. Lua 5.3 syntax only (StyLua `syntax = "Lua53"`,
  luacheck `std = "lua53"`).
- Only printable ASCII and LF line endings. Build non-ASCII characters
  with `string.char(...)` or `utf8.char(...)`.
- No comments in code files (`dev/lint/code-rules.lua`). No inline
  luacheck config (`inline = false`).
- Cyclomatic complexity at most 10 per function.
- Never make a tool less strict. If a rule blocks you, change the code.

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
