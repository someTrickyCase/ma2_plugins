# k_ma2programming

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
3. **PowerShell may run local scripts.** If you ever see
   *"running scripts is disabled on this system"*, run this once:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

Check it in a **new** terminal window (an old window keeps its old
PATH):

```powershell
lua53 -v          # Lua 5.3.6
luacheck --version
stylua --version
git --version
```

## 2. Install a plugin

```powershell
cd C:\k_ma2programming
.\install.ps1 -Plugin channel-to-fixture -WhatIf   # dry run, copies nothing
.\install.ps1 -Plugin channel-to-fixture           # real install
```

The script:

1. runs every check (`check.ps1`) and **stops if anything is red**
2. builds one Lua file and one XML file in `dist\`
3. checks the built file (valid Lua 5.3, our code rules)
4. copies both files to the plugins folder of the **newest** MA2
   version: `C:\ProgramData\MA Lighting Technologies\grandma\
   gma2_V_<version>\plugins\`

It only ever writes files that start with `k-`, so it can never
overwrite MA's own files.

Several MA2 versions installed? Pick one:

```powershell
.\install.ps1 -Plugin channel-to-fixture -MaVersion 3.9.60
```

## 3. Import it in MA2

At the end, `install.ps1` prints the MA2 commands and puts the import
line **into your clipboard**. Click the MA2 command line, press
`Ctrl+V`, then `Enter`:

```
Import "k-channel-to-fixture.xml" At Plugin 101
```

Each plugin has its own pool slot in its `plugin.lua` (`slot = 101`).
Is that slot taken in your show? Change it there, or pick another one
just for this time:

```powershell
.\install.ps1 -Plugin channel-to-fixture -At 5
```

The pasted line never deletes or runs anything. Run the plugin yourself
with the second printed line (`Plugin 101`).

The **System Monitor** then shows the version stamp:

```
Channel to Fixture 0.1.0 (e8482d2, 2026-10-24)
```

`e8482d2` is the Git commit it was built from. If it says
`e8482d2-dirty`, it was built from changes that were not committed yet.

## 4. Update to a new version

MA2 keeps **its own copy** of a plugin inside the show. Copying new files
is not enough. After `install.ps1`:

```
Delete Plugin 101
Import "k-channel-to-fixture.xml" At Plugin 101
```

(The second line is in your clipboard again.)

Then check the version stamp in the System Monitor.

## 5. Use it

**Always try it on a copy of the show first.**

Run the plugin (`Plugin 1`, or press its pool button). It:

1. reads the whole patch
2. if two fixtures would end up with the **same ID**: shows a list of
   these **conflicts** and **changes nothing**. Fix them by hand in the
   patch, then run the plugin again.
3. if no fixture has the ID to move: says so and changes nothing
4. asks: *"Move 230 fixtures from Channel ID to Fixture ID?"*
5. on OK: moves the IDs one by one with a progress window, and checks
   every change by reading it back
6. says *"Done: 230 fixtures moved ..."*

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
| `FAILED: checks are red`                  | Run `.\check.ps1` to see what is wrong      |
| `FAILED: unknown plugin 'x'`              | Use a folder name from `plugins\`           |
| `FAILED: no MA2 data folder found`        | Is MA2 onPC installed? Check `-MaVersion`   |
| `lua53 is not recognized`                 | Open a new terminal. Check the PATH         |
| `running scripts is disabled`             | See one-time setup, step 3                  |
| MA2 still runs the old version            | `Delete Plugin N`, then import again        |
| Conflict popup                            | Fix the listed IDs in the patch, run again  |

## For developers

Rules, layout and conventions: `CLAUDE.md`. Everything we know about
the MA2 Lua API: `ma2research.md`. Run `.\check.ps1` before every
commit.
