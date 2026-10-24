# The command line from Lua

## Basics

- Several commands in one call, separated by `;`. `[MA]`
  `gma.cmd('cd /; cd "EditSetup"; cd "Layers"')`
- `/nc` = no confirmation, `/o` = overwrite. `[MA]`
- `cd` walks the object tree like folders. It changes the **user's**
  command line location too, so always finish with `gma.cmd("cd /")`.
  `[MA]`
- `assign <objects> /<Property>=<value>` changes properties of objects
  at the current `cd` location. `[MA]`
  `assign thru /FixId=101`, `assign 1 /Patch=1.001`
- To check where a `cd` really landed, read `gma.user.getcmddest()`.
  Don't trust the return value of `gma.cmd` for that. `[V]`

## Return value of `gma.cmd` `[V]`

`gma.cmd` returns an error text on failure. On success it returns
**no value at all** (not even `nil`), so `tostring(gma.cmd(x))` crashes
with "value expected". Store it first:

```lua
local problem = gma.cmd(x)
if problem then ... end
```

## EditSetup is an edit session `[V]` (probe 4)

- Changes made inside EditSetup are applied when you leave it with
  `cd /`, and are readable **at once** after that. No sleep needed.
- Before `cd /`, `assign 2 /FixId=9002` returned no error, but reading
  the fixture right after showed no change, even after
  `gma.sleep(0.5)`. So: change, `cd /`, **then** read back.

## Duplicate IDs are stolen, silently `[V]`

Assigning FixId 9002 to a fixture while another fixture has 9002 moves
the ID: the old owner loses it, no error. A plugin must never create a
duplicate, not even for a moment. Plan the order of changes first.

## Recipe: change a Fixture or Channel ID `[V]` (probe 4)

```
cd /; cd "EditSetup"; cd "Layers"; cd <layer number>; assign <pos> /FixId=5
cd /
```

- `cd <number>` inside `Layers` enters the layer with that **number**
  (`cd 3` -> layer "fren", index 2).
- `<pos>` is the fixture's **position** in the layer, 1-based
  (= `getobj.index(fixture) + 1`). Not its ID.
- Clear an ID with an **empty** value: `/FixId=` or `/ChaId=`.
- Children of a layer are **not** sorted by ID (see `patch-tree.md`).
  Find the position fresh before every command.

## Recipe: locate a fixture without walking the tree `[V]` (probe 5)

```lua
local fixture = getobj.handle("Channel 802")
local layer = getobj.parent(fixture)
local layerNumber = getobj.number(layer)
local position = getobj.index(fixture) + 1
```

- `layer` is a `CMD_FIXTURE_LAYER`; its parent is `Layers`
  (`CMD_FIXTURE_LAYER_COLLECT`).
- `layerNumber` is a string like `"3"` -> `cd 3`.
- `position` like `2` -> `assign 2`.
- `getobj.child(layer, getobj.index(fixture))` returns the same fixture
  again.

## How MA's own tests do it `[MA]`

- Set IDs: `assign thru /FixId=N`, `assign thru /ChaId=N` inside a
  layer.
- Patch: `cd <position>` into the fixture, `assign 1 /Patch=1.001`
  (child 1 = the instance), `cd ..`.
- Move without `cd`: `assign Fixture 101 /posx=2`. Whether this also
  works for `/FixId` is an open question.
