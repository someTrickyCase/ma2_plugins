# ma2_plugins

Plugins for grandMA2 with a native Windows installer. The installer
copies the plugin files and provides the commands to import them into
your show.

| Plugin | Version | Default slot | Action |
| --- | --- | --- | --- |
| Channel to Fixture | 0.2.0 | 101 | Move Channel IDs to Fixture IDs |
| Fixture to Channel | 0.2.0 | 102 | Move Fixture IDs to Channel IDs |

Both plugins check for conflicts, ask before moving IDs and verify each
change. Try them on a copy of your show first.

## Download

Download `ma2-plugins-v0.1.0-windows-amd64.zip` from the
[v0.1.0 release](https://github.com/someTrickyCase/ma2_plugins/releases/tag/v0.1.0).
The release currently supports Windows x64 only.

`SHA256SUMS.txt` is available on the release page to verify the ZIP.
The package version is v0.1.0; individual plugin versions are independent.

## Install

1. Extract the complete ZIP into a folder.
2. Double-click `install.exe`.
3. Select the plugins you want to install.
4. Edit their pool slots if needed and choose an installed MA2 version.
5. Click Install.
6. Read and copy the MA2 commands from the result window, then click Close.

Keep these files together:

```text
ma2-plugins-v0.1.0-windows-amd64/
  install.exe
  plugins.json
  k-channel-to-fixture.lua
  k-channel-to-fixture.xml
  k-fixture-to-channel.lua
  k-fixture-to-channel.xml
  README.claude.md
  THIRD-PARTY-NOTICES.claude.md
```

No development tools or extra GUI runtime are required. The installer
finds the package beside its executable.

Slots must be positive whole numbers, and selected plugins must use
different slots. Your choices apply to this installation only and are
not saved. Cancel closes the installer without installing anything.
The installer cannot check which pool slots are already occupied in
your show; check them before importing.

The result window stays open until you close it. Errors are shown there
as well. Copying files does not import or run a plugin inside MA2.

## Import and run in MA2

Use the numbered commands displayed by the installer. For Channel to
Fixture at its default slot:

1. Only when updating an existing copy, delete the old plugin:

   ```text
   Delete Plugin 101
   ```

2. Import it into the show:

   ```text
   Import "k-channel-to-fixture.xml" At Plugin 101
   ```

3. Run it:

   ```text
   Plugin 101
   ```

Fixture to Channel uses slot 102 by default. If you chose a different
slot in the installer, use the commands it generated for that slot.

MA2 stores a copy of the plugin inside the show. Updating files on disk
alone does not update that copy: delete the old pool plugin and import
again. The plugin's version appears in System Monitor when it runs.

## Plugin behaviour

The plugins read the patch, plan the ID moves and ask for confirmation.
During the operation, a progress window shows activity and each change
is checked by reading it back.

Fixtures with conflicting IDs are skipped and placed in a new Group and
Layout named `Conflicts`. You can move the remaining fixtures, or cancel.
On Cancel, IDs remain unchanged, but the conflict Group and Layout stay.
Creating these objects clears the current fixture selection; programmer
values stay.

Fix the conflicting IDs by hand, then run the plugin again. If only
conflicts remain, the plugin reports them without moving IDs.

A fixture that already has both IDs has its target ID overwritten.
For example, Channel ID 5 and Fixture ID 7 become Fixture ID 5 when
running Channel to Fixture.

The plugin stops on an unexpected result. Earlier completed changes are
not rolled back. Installation write failures can also leave partial
output. Hardware consoles have not been verified.

## Sequence tools (unreleased)

These plugins are not included in the v0.1.0 download. Test them on a
show copy first. Each asks for a sequence number, shows a plan for
confirmation and creates a backup in a free sequence slot below 512.
Sequence numbers 1 through 511 are supported.

| Plugin | Version | Default slot | Action |
| --- | --- | --- | --- |
| Sequence Cleanup | 0.2.0 | 103 | Remove unused fixture data |
| Sequence Position Presets | 0.1.1 | 104 | Convert raw positions to presets |

Sequence Cleanup keeps known dimmer fixtures only when at least one cue
has a positive stored dimmer value. Missing initial values, defaults,
Release `(R)`, effects and preset links do not retain a fixture without
such a value. Unsupported mappings and shutter-only fixtures remain for
review. This plugin does not create or change presets.

Sequence Position Presets asks for position tolerance in stored attribute
values. It creates one `cue_<cue number>` position preset per cue,
combining participating fixtures. Separate cue parts use separate presets.
Within each cue part, fixtures with matching Pan/Tilt attribute sets and
values within tolerance use the first matching fixture's values. Each
attribute stays within tolerance of its original value. Zero keeps exact
values. Different cues retain separate presets. Partial raw positions
create partial presets; existing references remain. Values with effects
and special values remain for review. No fixtures are removed and color
presetting is disabled. Occupied preset slots and names are preserved.
Existing and new position presets referenced by the sequence receive
green borders, which also appear wherever those presets are used.

Fixtures needing review are marked in a new `Conflicts` Group and Layout.
For position presetting, these identify skipped effects or special values
and unsupported or ambiguous fixture mappings. The affected values stay
unchanged; the name does not necessarily indicate an ID conflict.
Marking clears fixture selection but preserves programmer values. Cancel
keeps review objects and leaves sequence data unchanged.

Static sequences finish with Tracking, Block and Unblock automatically.
Sequences with effects require that pass manually; numbered commands are
printed in System Monitor. Multi-instance mapping remains unsupported.
Command errors stop the plugin. Runtime XML readback is skipped; earlier
successful changes and created presets are not rolled back automatically.

## Command-line options

You can also launch the installer from PowerShell:

```powershell
.\install.exe
```

| Option | Effect |
| --- | --- |
| `--all` | Install all packaged plugins into the newest MA2 version |
| `--box DIR` | Read the plugin package from another folder |
| `--ma-root DIR` | Look for installed MA2 versions under another root |

`--all` runs without opening windows. Capture stdout and stderr when
using it in scripts, since the Windows installer does not open a console.
The installer has no dry-run option.

## Troubleshooting

| Problem | Action |
| --- | --- |
| Missing plugin list or Lua/XML file | Extract the complete package again |
| No MA2 version found | Check that onPC is installed, or use `--ma-root` |
| Invalid slot | Enter positive, different slots for selected plugins |
| Old plugin still runs | Delete its pool copy and import again |
| Conflict message | Inspect the Conflicts Group/Layout; fix ID conflicts or review skipped sequence values as applicable |
