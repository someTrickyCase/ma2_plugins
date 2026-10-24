# k_ma2programming

Kirk's grandMA2 Lua plugins, developed outside MA2 and delivered to it
with a script. Runs on Windows 11 with grandMA2 onPC 3.9.60.

Everything we know about MA2 and its Lua API is in `ma2research.md`.
Read it before writing plugin code. Update it after every probe.

## Hard rules

- **Never commit to `main`.** Work on a branch; changes reach `main`
  only through a pull request.
- **Test what you ship.** MA2 runs Lua 5.3, so tests run on Lua 5.3.
- **Safety on stage.** A plugin checks everything first and changes
  nothing if there is any conflict. It shows a list instead. Never block
  MA's main loop (no long loops without `gma.sleep`, no waiting
  `os.execute`).
- **TDD always:** red (failing test), green (smallest code), refactor.
- SOLID and OOP best practices, BUT simplicity always wins.

## Tools

All in `C:\lua-executables` (user PATH):

| Tool       | Version | Config          |
| ---------- | ------- | --------------- |
| `lua53`    | 5.3.6   |                 |
| `luacheck` | 1.2.0   | `.luacheckrc`   |
| `stylua`   | 2.3.1   | `stylua.toml`   |
| LuaUnit    | 3.4     | `vendor/luaunit.lua` |

## Commands

| Command                    | What it does                              |
| -------------------------- | ----------------------------------------- |
| `.\check.ps1`              | format check + lint + rules + tests       |
| `.\install.ps1 -Plugin <name>` | check, bundle to `dist/`, copy to MA  |
| `.\install.ps1 -Plugin <name> -WhatIf` | same, but copy nothing        |
| `stylua .`                 | format all files                          |
| `lua53 test/run.lua <files>` | run some test files                     |

`.\check.ps1` must pass before every commit.

## Layout

```
lib/        shared modules, required as "core.x" or "ma.x"
  core/     pure logic, no gma
  ma/       thin adapters around the gma API
plugins/    one folder per plugin (kebab-case)
  <name>/plugin.lua   manifest: display name, file (k- prefix), version
  <name>/main.lua     entry, returns start[, cleanup]
tools/      bundler, rule checker, installer
test/       mirrors lib/, plugins/ and tools/ one to one
vendor/     other people's code. Do not edit. Not linted.
scratch/    experiments and probes. Ignored by Git and tools.
dist/       build output. Ignored by Git.
```

## Code conventions

Enforced by tools:

- Max line width 80. Lua 5.3 syntax only (StyLua `syntax = "Lua53"`,
  luacheck `std = "lua53"`).
- Only printable ASCII and LF line endings. Build non-ASCII characters
  with `string.char(...)` or `utf8.char(...)`.
- No comments in code files (`tools/check-rules.lua`). No inline
  luacheck config (`inline = false`).
- Cyclomatic complexity at most 10 per function.
- Never make a tool less strict. If a rule blocks you, change the code.

Not enforced, but expected:

- No globals. Modules return a table. The only global we read is `gma`,
  and only in `plugins/*/main.lua`, which passes it on to `ma/` code.
- Read MA properties **by name**, never by index.
- Always end `gma.cmd` work with `cd /`. Check the return value of every
  `gma.cmd` (nil = success).

## Tests

- File `lib/core/x.lua` -> test `test/lib/core/x.test.lua`.
- A test file returns a table of functions named `test...`.
- `core/` tests use plain tables. `ma/` tests use a fake `gma`.
