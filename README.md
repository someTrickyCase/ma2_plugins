# ma2_plugins

[![CI](https://github.com/someTrickyCase/ma2_plugins/actions/workflows/ci.yml/badge.svg)](https://github.com/someTrickyCase/ma2_plugins/actions/workflows/ci.yml)
[![Go coverage](https://img.shields.io/badge/go%20coverage-87.0%25-brightgreen)](https://github.com/someTrickyCase/ma2_plugins)

Lua plugins for grandMA2, with Go tools for developing, testing, building
and installing them. Developed on Windows 11 with MA2 onPC 3.9.60.

| Plugin | Version | Default pool slot | Action |
| --- | --- | --- | --- |
| Channel to Fixture | 0.2.0 | 101 | Move Channel IDs to Fixture IDs |
| Fixture to Channel | 0.2.0 | 102 | Move Fixture IDs to Channel IDs |

The plugins share their implementation. They skip conflicting fixtures,
mark them in a Group and Layout, ask before moving IDs, and read back
changes to check the result. Try them on a copy of your show first.

## Install a built package

The standalone installer is implemented. Automated release ZIPs are still
planned; the current package is built locally with `task dist`.

Keep these files together:

```text
bundle/
  install.exe
  plugins.json
  k-channel-to-fixture.lua
  k-channel-to-fixture.xml
  k-fixture-to-channel.lua
  k-fixture-to-channel.xml
```

Open PowerShell in that folder and run:

```powershell
.\install.exe
```

Use the arrow keys to move, Space to select plugins and Enter to continue.
Choose an MA2 version and press Enter to install. Esc goes back from the
version list or exits from the plugin list. The installer then prints
MA2 import commands. It does not import or run plugins inside your show.

Go, Lua, Task and the source repository are not needed for this workflow.
The executable finds `plugins.json` beside itself, even when started from
another directory. The list contains each plugin's name, version, file
base and slot; `.lua` and `.xml` are the corresponding file suffixes.

| Installer option | Effect |
| --- | --- |
| `--all` | Install all listed plugins into the newest MA2 version |
| `--box DIR` | Read the package from another folder |
| `--ma-root DIR` | Look for MA2 version folders under another root |

The default root is
`C:\ProgramData\MA Lighting Technologies\grandma`. Version folders are
compared numerically: `3.10.0` is newer than `3.9.60`.

The packaged installer currently has no `--dry-run`, `--at` or
`--ma-version` option. Use its picker for a specific MA2 version, or the
developer commands below for a dry run or a different pool slot.

Before copying, it checks selected filenames, duplicate file bases,
import-command requirements, Lua code rules and all selected source
files. These validation failures leave the destination untouched.
An operating-system write failure can still leave a partial install;
there is no rollback. XML files are copied, not semantically validated.

## Import and run in MA2

Copy each command from the installer's numbered output into MA2.
For Channel to Fixture at its default slot, the commands are:

1. Only when updating, remove the previous plugin from that slot:

   ```text
   Delete Plugin 101
   ```

2. Import the plugin:

   ```text
   Import "k-channel-to-fixture.xml" At Plugin 101
   ```

3. Run it on a copy of the show:

   ```text
   Plugin 101
   ```

Check the target pool slot before importing. The installer does not query
which slots are occupied in your show. Fixture to Channel uses slot 102.
Commands are printed for copying; the clipboard is never changed.

MA2 keeps its own copy of the plugin inside the show. Updating files on
disk alone does not update that copy: delete the old pool plugin and
import again. The version/commit/date stamp appears in System Monitor.
A `-dirty` commit suffix means the source had uncommitted changes.

## Plugin behaviour

1. Read the patch and calculate the ID moves.
2. If no IDs can move, show the reason.
3. Mark conflicts in a new Group and Layout named `Conflicts`, using free
   numbers. Conflicting fixtures keep their IDs. Ask whether to move the
   remaining fixtures; if only conflicts remain, report them instead.
4. Ask for confirmation before changing IDs.
5. Apply moves with a progress window and read back each change.
6. Report the result in a message box and System Monitor.

On Cancel, IDs are unchanged, but any conflict Group and Layout remain.
Creating them clears the current fixture selection; programmer values
stay. Existing groups with the same name are not reused.

A fixture with both IDs has its target ID overwritten. For example,
Channel ID 5 and Fixture ID 7 become Fixture ID 5 when moving Channel to
Fixture. Planning orders the steps to avoid temporary duplicate IDs.
The plugin stops on an unexpected result; earlier successful changes
are not rolled back. Already completed moves can be skipped on a rerun.

The Lua plugins have been exercised on onPC. Real hardware consoles are
still unverified. Importing on onPC and transferring the show is a
possible console workflow, not a tested guarantee.

## Develop from source

Work in `C:\k_ma2programming`. Development needs Git, Go 1.27.0,
Task 3.54.0, golangci-lint 2.15.0, Lua 5.3.6, luacheck 1.2.0 and
StyLua 2.3.1. LuaUnit is included in `third_party/`.
Kirk's Lua executables live in `C:\lua-executables` on PATH.
There are no PowerShell scripts in the repository; PowerShell is simply
the terminal used for these examples.

```powershell
cd C:\k_ma2programming
task check
```

Use the source picker:

```powershell
task tui
```

Or install one source plugin, first without copying files:

```powershell
task install -- channel-to-fixture --dry-run
task install -- channel-to-fixture
```

These two tasks run `task check` before building and installing. The
`--` passes the following arguments through Task to `ma2kit`.

Choose a version or override the pool slot:

```powershell
task install -- channel-to-fixture --ma-version 3.9.60 --at 5
```

`ma2kit install` also accepts `--ma-root DIR`. The source picker accepts
`--ma-root DIR` and `--dry-run`, passed through `task tui -- ...`.
Direct `ma2kit` commands do not run Task or the whole test suite.

## Build and check commands

| Command | Result |
| --- | --- |
| `task` | List available tasks |
| `task check` | Code rules, Lua checks, Go lint and tests |
| `task lua` / `task go` | Check one language |
| `task rules` | Check ASCII and no-comments rules |
| `task fmt` | Format Lua and Go |
| `task coverage` | Go coverage report in `dist/coverage.out` |
| `task build` | Developer tool: `dist/ma2kit.exe` on Windows |
| `task bundle` | Bundle the plugins named in Task's `PLUGINS` variable |
| `task golden` | Rebuild committed reference bundles |
| `task dist` | Build `dist/bundle/install.exe`, bundles and plugin list |

Run `task check` before commits and before `task dist`: the distribution
build does not run checks automatically. It discovers every
`plugins/*/plugin.json`; the ordinary bundle and golden tasks still use
Task's explicit `PLUGINS` list. Add new plugins there and to the golden
test cases when extending the test suite.

Build a new plugin template with the developer executable:

```powershell
.\dist\ma2kit.exe new my-plugin
```

Run source commands from the repository root. Other developer commands:

```text
ma2kit version
ma2kit check-rules <file>...
ma2kit bundle <name> --out <dir>
ma2kit bundle --all --out <dir>
ma2kit manifest --out <dir>
ma2kit install <name> [flags]
ma2kit tui [flags]
```

`bundle` also accepts `--at`, `--commit` and `--date`. Task's bundle and
install commands use `go run -buildvcs=true` for the Git stamp; a plain
`go run` may instead report `dev`.

`task dist` does not remove old output. Use a fresh package folder before
sharing a build, and exclude obsolete files such as the former
`ma2-plugins-setup.exe`. ZIP creation and tag-triggered GitHub Releases
are not implemented yet.

## File structure

```text
plugins/<name>/     Lua entry point and plugin.json for each plugin
lib/core/          ID planning and messages, without the MA2 API
lib/ma/            MA2 patch operations and plugin workflow

test/lib/          Lua library tests, mirroring lib/
test/plugins/      Lua entry-point tests
test/support/      Fake MA2 and session helpers
test/session/      Whole-plugin command-sequence tests
test/bundles/      Committed Lua/XML reference files

cmd/ma2kit/        Developer executable entry point
cmd/setup/         Distribution install.exe entry point
internal/          Go implementation and adjacent *_test.go files
third_party/       Included LuaUnit library
.github/workflows/ GitHub Actions checks

dist/              Generated output, ignored by Git
scratch/           Local experiments and probes, ignored by Git
Taskfile.yml       Shared local/CI commands
AGENTS.md          Development rules and detailed architecture
```

The Go bundler compares fresh output against `test/bundles/` byte for
byte. Lua session tests load those same files. Rebuild them deliberately
with `task golden` after relevant plugin changes; inspect the diff.
The original Lua-to-Go port was also checked for byte-for-byte equality.

Current architecture and remaining design work: [AGENTS.md](AGENTS.md).
GitHub Actions runs Lua and Go checks on pull requests and main pushes.
The coverage badge is a manually updated local measurement, not a live
coverage service. Lua coverage is not measured.

## Troubleshooting

| Problem | Action |
| --- | --- |
| Missing `plugins.json` | Keep it beside install.exe, or use `--box` |
| Missing Lua/XML file | Restore the complete package before installing |
| No MA2 version folder | Check onPC installation or use `--ma-root` |
| Filename or Lua rule error | Fix/rebuild the package; keep checks strict |
| Task cannot find the plugin task | Add `--` before the plugin name |
| Development tool missing from PATH | Open a new terminal after setup |
| Old plugin still runs | Delete its pool copy and import again |
| Conflict message | Inspect the Conflicts Group/Layout and fix the patch |
