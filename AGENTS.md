# ma2_plugins agent and development guide

Develop and edit this project directly in its checkout.
Lua runs inside grandMA2 onPC 3.9.60; Go provides development tools and the
standalone Windows distribution installer. There are no PowerShell
scripts in the repository. User instructions and commands: [README.md](README.md).

Consult available MA2 API research and probe recipes before writing code
that calls `gma`. Verify unknown console behaviour with a probe and record
the findings in the appropriate knowledge base. Keep private reference
material outside this public repository.

## Working in this repository

Preserve existing uncommitted work and explain changes clearly. Work in
the original checkout. Verify current files and Git state when historical
status entries disagree. This AGENTS.md is the sole project instruction
and development guide; README.md covers user workflows.

## Hard rules

- PERSONAL, CONFIDENTIAL OR SENSITIVE INFORMATION MUST NEVER BE EXPOSED
  PUBLICLY. This includes public docs, articles, repositories, code,
  commits, issues, pull requests, releases, screenshots, logs and any
  other public output. Keep private notes and local setup outside the
  repository. Use generic examples and check content before publishing.

- Never commit to main. Use a branch and a pull request with green CI.
- TDD: failing test, smallest passing implementation, then refactor.
- Test the Lua shipped to MA2 on Lua 5.3.
- Read and plan before changing a show. Skip conflicting fixtures, mark
  them for the designer and ask before changing other fixtures.
- Read back changes; stop at unexpected results. Do not block the MA2
  main loop with long work without yielding or waiting `os.execute`.
- Follow SOLID and OOP practices where useful; simplicity wins.
- Never weaken linting or type/code checks to make a change pass.
- Let the user install host tools; provide the required commands.
- Do not alter the clipboard. Print MA2 commands as a numbered list,
  each command on its own line with its explanation above.
- Keep documentation and relevant local memory current as work proceeds.
  Ordinary new docs use `.claude.md`; keep recognized filenames such as
  README.md, AGENTS.md and SKILL.md unchanged.
- README.md is public user documentation: project description, download,
  launching and usage only. Never include personal information, personal
  preferences, absolute local workspace paths or machine-specific setup.
  Keep development details in this guide and personal notes in local memory.

## Tools and configuration

| Tool | Version | Location/configuration |
| --- | --- | --- |
| Lua / luac | 5.3.6 | lua53 / luac53 on PATH |
| luacheck | 1.2.0 | `.luacheckrc` |
| StyLua | 2.3.1 | `stylua.toml` |
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
ma2kit package-stage
ma2kit package-promote
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
Bundled project dependencies must use one direct `require("module.name")`
per line, optionally assigned to a local or simple variable. Missing
`core.*` and `ma.*` modules fail the build; external requires remain
external. Do not hide a project require in a string or use a dynamic name.

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
Choices apply to the current install only; do not persist them.

The source and prebuilt paths still have separate copy implementations.
Do not describe them as a unified installer. A shared prepared-files
installation service is the proposed next refactor; it is not implemented.
Renaming box for clarity was suggested, not performed.

### Build and distribution

`task dist` builds into a fresh dist/bundle-stage directory, verifies the
installer, plugins.json and every discovered Lua/XML pair, then replaces
dist/bundle while retaining the previous complete package on build failure.
The package-stage and package-promote commands implement this workflow.
bundle --all and manifest discover plugins/*/plugin.json.
Task's ordinary bundle/golden tasks and the Go golden test cases still
list plugins explicitly; update them when adding one.

The distribution task does not run checks. Run task check before sharing.
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
- task coverage measures Go only; there is no Lua coverage number.

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

Current source workflows: Sequence Cleanup v0.2.0 (slot 103) removes
unused fixture data; Sequence Position Presets v0.1.1 (slot 104)
creates cue-based position presets. Both preserve the explicit
positive-stored-dimmer policy and leave effect positions for review.
Runtime XML readback was removed by user request. `core/xml-verify.lua`
is retained only for offline comparison tests and probe analysis; it is
not a runtime safety check. The dated checkpoints below are historical.

Sequence Cleanup v0.1.7: the user explicitly requires known dimmer
fixtures to have at least one positive stored dimmer value to be kept.
No positive value means removal, regardless of missing initial values,
defaults, effects or preset links. Unsupported mappings and shutter-only
fixtures remain for review. This supersedes earlier conservative dimmer
policy descriptions. Remaining raw positions include numeric bases with
effects, currently skipped; probe-position-effects is prepared to verify
converting those bases without losing effects. Do not enable this path
before checking the probe result.

Sequence Cleanup v0.1.6 fixes an immediate startup error confirmed at
bundle line 584: selected executor number may be nil. The optional
suggestion now stays unresolved and the explicit sequence prompt still
opens. Errors are also saved to temp/sequence-cleanup-error.json without
masking the original dialog. Console retry is pending.

Sequence Cleanup v0.1.5: by explicit user instruction, DIM Release (R)
counts as zero only for unused-fixture planning. Positive values in other
cues still retain the fixture. Effects, preset links, other special
values and unknown initial output still require review; shutter Release
is not interpreted as closed. Retained sequence XML is unchanged by this
classification. Console trial remains pending.

Sequence Cleanup v0.1.4 checkpoint, 2026-11-08: the user requested
shared color presets across fixtures/cues and per-cue position presets
named cue_<cue number>, preserving existing references. Position values
remain exact; separate parts use separate presets. Mixing tolerance and
exact wheel matching remain. Every participating fixture is included in
shared preset XML. Runtime XML verification/readback exports and source
freshness checks are removed by explicit user request; backup copying,
slot checks, plan confirmation and command error handling remain.
Existing and new sequence presets receive green borders using documented
Appearance commands. The focused appearance probe and full v0.1.4 console
trial are pending. Full task check passes with 192 Lua tests and refreshed
golden artifacts. This checkpoint supersedes earlier runtime verification
and per-fixture preset-grouping descriptions below. See
sequence-cleanup.claude.md for details.

Sequence Cleanup development checkpoint, 2026-11-08: an unreleased
v0.1.3 source plugin now exists at plugins/sequence-cleanup, default slot
103. It uses cleanup-flow/runtime/read/write/files and the pure XML,
fixture-type, sequence-data, unused-fixtures and preset-planning modules.
The explicit Task and Go golden lists include it. The published v0.1.0
release below is unchanged and does not contain this plugin.

The runtime always asks for a sequence number. The selected executor's
Cue 1 parent supplies only a suggested default. Sequence and backup numbers
are limited to 1..511. It exports console data, plans before applying,
marks review fixtures using the existing conflict-group helper, confirms
the plan, verifies a backup, imports new presets, checks source freshness,
imports edited sequence XML and reads it back. Programmer values stay;
fixture selection can be cleared during review marking. Files use the
console PATH and internal drive, never a hardcoded machine path.

Tolerances apply to stored values; zero means exact. Partial raw data
creates partial presets. Existing preset references are retained. Wheel
values use exact matching; the sampled 8-bit percentage-to-DMX color-name
mapping was visually confirmed. Shutter-only removal remains disabled
by user agreement pending a dedicated test. Multi-instance mapping is
unverified and retained for review. Effects cause the final tracking pass
to remain manual; static sequences use Track/Block/Unblock with readback.
Earlier successful changes are not rolled back automatically.

Individual console probes verified new preset creation, raw position and
color references, existing-sequence overwrite/removal and static tracked
values. Real exports stay outside tracked source; regression tests use
synthetic data. The first full onPC run stalled in the reading stage.
v0.1.1 adds explicit sequence choice, byte/fixture/type progress, a bounded
cooperative yield budget and temp/sequence-cleanup-status.json diagnostics.
The input export parses locally; the cause of the console stall is still
unverified. Full checks and 178 Lua tests pass; the updated console trial
is pending. The subsequent run reached stage 70. Its exported backup
differed only in sequence index and an automatically generated name.
v0.1.2 accepts those identity differences only when checking backups,
uses compact streamed sequence records, fast unchanged-body comparisons
with validated envelopes and streaming fallback verification. Local peak
memory fell from about 271 MB to 47 MB, and the sampled unchanged check
from 5.1 to 0.3 seconds. These are host measurements, not console timings.
Write progress now separates freshness, backup, presets and final import.
The preset-pool probe verified parent/child traversal through a qualified
preset. Bare Preset N resolves in the current preset type, not a pool.
v0.1.3 finds a qualified seed, validates CMD_PRESET_POOL and its number,
then iterates sparse children directly. Sequence references supply seed
hints when slot 1 is empty. Unseeded/empty pools retain a bounded fallback
search. The populated test pools now need two name lookups rather than
20,000; actual console speed remains to be measured. The sampled 0.001
and 0.01 sleep requests both measured about 16 ms. There are 187 Lua tests.
See sequence-cleanup.claude.md for detailed development state.

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

Still unverified: end-user interactive distribution picker operation,
latest installer on real onPC, and hardware consoles. Earlier onPC plugin
runs verified the ID/conflict behaviour; fake MA2 is not a console test.

Possible next work, after end-user release testing:

1. Refactor the two copy paths into one prepared-files installer with
   shared validation, while retaining source and package readers.
2. Expand invalid/empty-manifest and failure-path regression tests.
3. Make package output fresh and reproducible; exclude old build files.
4. Test install.exe interactively and run the actual onPC import workflow.
5. Automate release staging, notices, checksums and v*-tag publication.
6. Later: more agent tools (probe/api/docs) and a separate MA2 skills repo.

Latest sequence workflow split: Sequence Cleanup v0.2.0 (slot 103)
removes unused fixture data only. Sequence Position Presets v0.1.0
(slot 104) creates cue_ position presets only, with a restored tolerance
prompt. Matching fixture Pan/Tilt sets within each cue part may use a
representative within tolerance; zero preserves exact values. Separate
cues/parts retain separate presets. Both entry points disable colors.
Effects conversion and identity-error debugging remain deferred.

Console feedback: the user confirmed fixture cleanup works. Sequence
Position Presets v0.1.1 removes the fixture-removal counter from its
result and plan summaries. Conflicts Group/Layout means fixtures needing
review for skipped values or unsupported mappings in this workflow.
