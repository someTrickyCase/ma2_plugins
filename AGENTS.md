# ma2_plugins agent and development guide

Develop and edit this project only in `C:\k_ma2programming`.
Lua runs inside grandMA2 onPC 3.9.60; Go provides development tools and the
standalone Windows distribution installer. There are no PowerShell
scripts in the repository. User instructions and commands: [README.md](README.md).

MA2 API facts, patch-tree research and probe recipes live in Kirk's local
`C:\Users\snowi\.claude\skills\ma2-plugins` skill. Consult it before
writing code that calls `gma`, and update it after verified probes.
Keep console research there rather than copying it into this repository.

## Working with Kirk

Preserve existing uncommitted work. Use simple English and explain why.
Kirk is learning programming and English; explain unfamiliar terms and
correct language gently. Do not create a duplicate project under .claude.

His shared personal preferences are in
`C:\Users\snowi\.claude\CLAUDE.md`. Relevant project and feedback notes are
indexed by
`C:\Users\snowi\.claude\projects\C--Users-snowi--claude\memory\MEMORY.md`.
Read relevant notes, but verify current files and Git state when older
status entries disagree. This AGENTS.md is the sole project instruction
and development guide; README.md covers user workflows.

## Hard rules

- Never commit to main. Use a branch and a pull request with green CI.
- TDD: failing test, smallest passing implementation, then refactor.
- Test the Lua shipped to MA2 on Lua 5.3.
- Read and plan before changing a show. Skip conflicting fixtures, mark
  them for the designer and ask before changing other fixtures.
- Read back changes; stop at unexpected results. Do not block the MA2
  main loop with long work without yielding or waiting `os.execute`.
- Follow SOLID and OOP practices where useful; simplicity wins.
- Never weaken linting or type/code checks to make a change pass.
- Do not install tools for Kirk. Explain what is needed and let him do it.
- Do not alter the clipboard. Print MA2 commands as a numbered list,
  each command on its own line with its explanation above.
- Keep documentation and relevant local memory current as work proceeds.
  Ordinary new docs use `.claude.md`; keep recognized filenames such as
  README.md, AGENTS.md and SKILL.md unchanged.

## Tools and configuration

| Tool | Version | Location/configuration |
| --- | --- | --- |
| Lua / luac | 5.3.6 | `C:\lua-executables`, lua53 / luac53 |
| luacheck | 1.2.0 | `C:\lua-executables`, `.luacheckrc` |
| StyLua | 2.3.1 | `C:\lua-executables`, `stylua.toml` |
| LuaUnit | 3.4 | `third_party/luaunit.lua` |
| Go | 1.27.0 | `go.mod` |
| golangci-lint | 2.15.0 | `.golangci.yml` |
| Task | 3.54.0 | `Taskfile.yml` |

Keep tool versions aligned with `.github/workflows/ci.yml` when upgrading.
Go dependencies are in go.mod/go.sum and the module cache. Do not add a
root vendor/ folder: it activates Go vendoring. third_party/ holds the
Lua dependency and is excluded from project linting. Do not edit it.

## Commands

Run from the repository root. `task` lists available tasks.

| Command | Behaviour |
| --- | --- |
| `task check` | Rules, Lua checks, Go lint and tests |
| `task rules` | ASCII/no-comments rules on project Lua and Go |
| `task lua` | StyLua check, luacheck, LuaUnit tests |
| `task go` | golangci-lint and Go tests |
| `task fmt` | Format Lua and Go |
| `task coverage` | Measure Go coverage; write dist/coverage.out |
| `task build` | Build dist/ma2kit.exe on Windows |
| `task bundle` | Build Task's explicit PLUGINS list into dist/ |
| `task golden` | Rebuild that list in test/bundles/ with a fixed stamp |
| `task install -- <name> [flags]` | Run checks, build and install one plugin |
| `task tui -- [flags]` | Run checks, select and install source plugins |
| `task dist` | Build install.exe, discovered plugins and plugins.json |

`task install` needs the `--` separator; otherwise Task treats the plugin
name as a task. The bare `task tui` is also valid. Only install/tui run
all checks automatically. Run `task check` before committing or building
a distribution. Go commands never shell out to Task.

Developer commands (after task build):

```text
ma2kit version
ma2kit check-rules <file>...
ma2kit new <plugin-name>
ma2kit bundle <plugin-name> [flags]
ma2kit bundle --all [flags]
ma2kit manifest --out <dir>
ma2kit install <plugin-name> [flags]
ma2kit tui [flags]
```

- bundle: `--out`, `--at`, `--commit`, `--date`.
- install: `--at`, `--ma-version`, `--ma-root`, `--dry-run`.
- tui: `--ma-root`, `--dry-run`.
- manifest: `--out`; writes plugins.json but does not build plugin files.
- setup executable: `--box`, `--ma-root`, `--all`. No dry-run/slot flag.

Task uses `go run -buildvcs=true` for bundle/install/TUI stamps. A plain
`go run` may omit VCS metadata and show dev. A dirty suffix records
uncommitted changes. Bundle commit/date flags make golden tests stable.

## File ownership and layout

```text
plugins/<name>/
  main.lua         entry point, reads gma and passes it down
  plugin.json      name, file base, version, default slot
lib/
  core/            pure ID planning and report text
  ma/              patch access, conflict marking and swap workflow

test/
  lib/             mirrors the Lua library
  plugins/         mirrors plugin entry points
  support/         fake-gma and whole-session helpers
  session/         exact MA2 command-sequence assertions
  bundles/         tracked reference Lua/XML artifacts
  run.lua          Lua test runner

cmd/
  ma2kit/main.go   developer CLI entry point
  setup/main.go    distribution installer entry point
internal/
  cli/             ma2kit argument parsing, IO and command dispatch
  scaffold/        new-plugin templates and free slot selection
  rules/           shared reporting and Lua/Go lexical checks
  bundle/          dependency discovery, Lua bundle, XML and commands
  manifest/        per-plugin metadata and distribution list JSON
  buildinfo/       VCS version/commit description
  readfile/        file reads using DirFS and a base filename
  mahome/          MA2 data root, numeric versions and plugin folders
  install/         source-build installation and shared validation
  box/             prebuilt package loading, validation and copying
  setup/           distribution installer arguments and workflow
  tui/             developer terminal picker and terminal results
  native/          Windows Walk controls and pure selection validation

third_party/       dependency code, not project code
.github/workflows/ CI configuration
Taskfile.yml       shared commands
scratch/           ignored local probes and experiments
dist/              ignored generated output
```

Go tests sit next to their implementation as *_test.go. Lua tests mirror
source paths under test/. dist/ can be rebuilt; test/bundles/ is tracked
and must be updated deliberately. scratch/ can contain old experiments
and dependencies: it is not the maintained source tree.

## Current architecture

### MA2 runtime

```text
plugins/<name>/main.lua
  -> lib/ma/swap-flow
       -> lib/ma/patch-reader
       -> lib/core/swap-ids and report
       -> lib/ma/conflict-group
       -> lib/ma/patch-writer
```

Only plugin entry points read global gma. Modules receive it as an
argument; core/ never uses it. The two ID-conversion plugins share
swap-flow with their source/target fields exchanged.

The reader opens EditSetup and gathers plain fixture tables. The planner
skips final duplicate IDs, including conflicts introduced by keeping
other fixtures unchanged; it repeats planning until no new conflict
appears. Move phases clear overwritten target IDs, set new target IDs,
then clear old source IDs, avoiding temporary duplicates.

Conflict marking creates a new Group and Layout at free numbers, both
named Conflicts. It uses fixture selection; recalling the stored group
and checking SELECTEDFIXTURESCOUNT verifies the result. A previous group
with that name is not reused. Cancel leaves these objects but moves no
IDs. Current fixture selection may be cleared; programmer values stay.

The writer locates each fixture again by its current ID, checks its name,
assigns the value, commits with cd / and reads the result back. It stops
at the first surprise. Progress cleanup handles an interrupted run.
A fixture with both IDs has its target overwritten. Earlier successful
changes are not rolled back on a later failure.

### Source-built installation

```text
cmd/ma2kit -> cli -> manifest/bundle -> install -> MA2 plugin folder
                   tui -> selected folders -> same install path
```

The bundler follows requires from main.lua into lib/, emits one Lua file
with its own module loader, and writes MA2 XML. One Lua file can travel
inside the show. The JSON manifest is consumed by Go and stays outside
the MA2 runtime. `ma2kit new` creates a manifest, entry and test, choosing
the first free source-manifest slot from 101.

install.Do builds Lua/XML, validates the filename and Lua code rules,
prepares import commands, then copies unless dry-run. Multi-plugin source
installation processes plugins sequentially; it is not a batch transaction.
MA2 versions compare numerically. No Lua executable is needed by ma2kit
at install time, although Task's developer checks require the Lua tools.

### Prebuilt distribution installation

```text
cmd/setup -> setup -> box -> plugins.json and prebuilt Lua/XML
                 native (Windows) / tui (Linux/macOS) -> selection
```

The Windows executable is named install.exe. The default package folder
is its own directory, not the shell's current directory. --box overrides
that location; --all skips the picker and uses the newest MA2 version.
Interactive setup presents a result screen after success or failure and
waits for explicit close. --all does not wait. setup.Interactive accepts
a result presenter; native.ShowResult uses a selectable read-only text
box with Close, and tui.Result supplies the terminal fallback. Cancel
exits cleanly without showing an error result or installing files.
It copies files and prints commands; it does not control MA2 or inspect
occupied show slots. End users need no development toolchain.

box preloads all selected files before writes. It rejects empty
selections, duplicate file bases, invalid filenames, Lua rule violations,
missing files and import-command errors. Shared install.Validate enforces
the filename and Lua rules for both installation paths. File bases must
start with k-, contain a nonempty suffix and have no slash, backslash,
colon or dot. Existing corresponding plugin files can be overwritten.
XML is copied without semantic validation. Filesystem write failures may
still leave partial output; there is no rollback.

The Windows installer uses checkboxes, editable slot fields, a version
dropdown and Install/Cancel buttons. The developer terminal picker
supports S to edit a per-plugin slot. Validate
positive, distinct selected slots before installation. Both source and
package workflows use the edited slots in printed import commands.
Choices apply to the current install only; do not persist them (Kirk).

The source and prebuilt paths still have separate copy implementations.
Do not describe them as a unified installer. A shared prepared-files
installation service is the proposed next refactor; it is not implemented.
Renaming box for clarity was suggested, not performed.

### Build and distribution

`task dist` emits dist/bundle/install.exe, one Lua/XML pair per discovered
plugin, and plugins.json with a plugins array of name/file/version/slot
objects. bundle --all and manifest discover plugins/*/plugin.json.
Task's ordinary bundle/golden tasks and the Go golden test cases still
list plugins explicitly; update them when adding one.

The distribution task does not clean old files or run checks. Build from
a fresh output folder before sharing, excluding obsolete executables.
Release ZIPs are currently staged and published manually; there is no
tag-triggered release workflow. Go ships as the Windows installer, while
only Lua/XML go into MA2's plugin folder.

Windows builds use Walk, pinned in go.mod, and the windowsgui subsystem.
cmd/setup/install.manifest declares Common Controls 6, DPI awareness and
asInvoker privileges. task setup:resources uses pinned rsrc v0.10.2 to
generate resource_windows_amd64.syso; commit it with manifest changes.
The current native binary/resource targets Windows amd64. No extra DLL
or manifest is required beside install.exe. Keep GUI work on the locked
OS thread. Linux/macOS entry points retain the terminal fallback.

## Tests and CI

- Lua 5.3 tests use LuaUnit; files return tables of test... functions.
- lib/core/x.lua maps to test/lib/core/x.test.lua. core tests use plain
  tables; ma tests receive the fake gma in test/support/fake-gma.lua.
- Session tests load committed test/bundles/*.lua and assert the exact
  MA2 command sequence through test/support/session.lua.
- Go golden tests compare fresh Lua/XML bytes with those references.
  The initial port was independently compared with the old Lua bundler.
  After regeneration, golden files are regression baselines, not a new
  independent proof of equivalence with the deleted implementation.
- task golden regenerates fixed-stamp files. Review their diff; do not
  regenerate only to hide a failing test.
- Go uses external *_test packages, table tests and small helpers.
- task coverage measures Go only. Refresh the manual README badge when
  the total changes; there is no Lua coverage number.

ci.yml runs on pull requests and pushes to main on Ubuntu 24.04. Its Lua
job runs task lua; its Go job runs task go, task rules and task coverage.
Both use Task, but the parallel CI ordering differs from task check's
local sequential ordering. A Windows 2025 job runs strict lint, Go tests
and task dist, covering Windows-only code. No release workflow exists.
Keep commands compatible with Windows and Linux.

## Code conventions

- 80-column code, ASCII-only, LF line endings. Go permits indentation
  tabs; Lua uses spaces. Construct non-ASCII output with code points.
- No code comments except a required license note. No inline lint bypasses.
  Lua luacheck inline configuration is disabled.
- Lua 5.3 syntax. Modules return tables; avoid globals.
- Cyclomatic complexity at most 10 per function; follow all configured
  function-size and cognitive-complexity limits as well.
- Read MA properties by name. Finish command-line navigation with cd /.
  gma.cmd returns no value on success; check returned error text.
- Go module: github.com/someTrickyCase/ma2_plugins. main functions wire
  streams/arguments and exit codes; keep behaviour in internal packages.
- golangci uses default: all, disabling deprecated exhaustruct,
  gomodguard and wsl. revive exported/package-comments are disabled
  because they require comments. Do not add weaker exclusions.
- depguard permits the standard library, this module, Bubble Tea,
  lipgloss and Walk. Review new dependencies explicitly. ireturn permits
  the Bubble Tea model interface required by the framework.
- gosec G304 remains enabled; readfile.Read uses a named directory and
  base filename. That helper alone does not constrain paths to a package
  root: validate package-supplied filenames before joining paths.
- Use the existing XML namespace construction; do not disable URL linting.

## Status and next work

End-of-day state, 2026-11-05: PRs #12, #16, #17 and #18 are merged.
Installer issues #13, #14 and #15 are completed. No open feature issue
remains at this checkpoint; check GitHub again when starting new work.

The Windows x64 release v0.1.0 is published from merged commit 1cafa95:
https://github.com/someTrickyCase/ma2_plugins/releases/tag/v0.1.0

Assets are ma2-plugins-v0.1.0-windows-amd64.zip and SHA256SUMS.txt.
The annotated release tag is fixed to the tested source commit; later
documentation changes must not move it. Plugin versions remain 0.2.0.

Implemented: the two v0.2.0 plugins; Go rules, scaffolding and bundling;
source installation; developer terminal picker; native Windows installer;
per-install slots; persistent result windows; plugin-list generation;
package validation; and a Windows CI job. No PowerShell scripts remain.
Local task check/task dist and Linux/Windows CI passed. Go coverage is
77.6%; the separate GUI exercises are not part of that measurement.

Automated Windows control testing exercised checkbox selection, slot 205,
newest-version installation, readable persistent results and Close. The
copied files matched the package and unselected/older targets were intact.
Screenshots were inspected and a collapsed result field was fixed.

The release was built from a clean tree into a fresh staging folder with
an explicit file list, excluding the obsolete installer in old output.
Its eight files are install.exe, plugins.json, four Lua/XML files,
README.claude.md and THIRD-PARTY-NOTICES.claude.md. The notices include
runtime dependency licenses and the Go license.

Verification included Windows amd64 GUI PE headers, archive file hashes,
the extracted executable's --all mode against a temporary MA2 root, and
byte-for-byte installed files/import commands. GitHub asset sizes and
SHA256 digests matched local files before publication. Build/release
artifacts are under ignored dist/releases/; do not treat them as source.

Still unverified: interactive distribution picker operation by Kirk,
latest installer on real onPC, and hardware consoles. Earlier onPC plugin
runs verified the ID/conflict behaviour; fake MA2 is not a console test.

Possible next work, after Kirk's release test:

1. Refactor the two copy paths into one prepared-files installer with
   shared validation, while retaining source and package readers.
2. Expand invalid/empty-manifest and failure-path regression tests.
3. Make package output fresh and reproducible; exclude old build files.
4. Test install.exe interactively and run the actual onPC import workflow.
5. Automate release staging, notices, checksums and v*-tag publication.
6. Later: more agent tools (probe/api/docs) and a separate MA2 skills repo.
