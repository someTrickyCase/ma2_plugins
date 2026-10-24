# The patch tree (EditSetup)

Verified by the probe on show `plugins_testing` `[V]`:

```
cd /; cd "EditSetup"; cd "Layers"
Layers                       [CMD_FIXTURE_LAYER_COLLECT]
 +- layer 0 "Auto-Created"   [CMD_FIXTURE_LAYER]
 |   +- "[Preset] Dim"       [CMD_FIXTURE]  FixId=-  ChaId=-
 +- layer 7 "dimmers"        [CMD_FIXTURE_LAYER]  Channels=[1..24]
     +- "Dim 1"              [CMD_FIXTURE]  FixId=-  ChaId=1
         +- child 0          [CMD_SUBFIXTURE]  FixId=-  ChaId=1
```

## Layer properties

`Name`, `Fixtures` (range text like `[1001..1010] `, empty if none),
`Channels` (same format), `Info`.

## Fixture properties (`CMD_FIXTURE`)

| Index | Name                 | Example                              |
| ----- | -------------------- | ------------------------------------ |
| 0     | `Name`               | `Dim 1`                              |
| 1     | `FixId`              | `1001`, or `-` when empty            |
| 2     | `ChaId`              | `801`, or `-` when empty             |
| 3     | `Fixture Type`       | `2 Dimmer 00` (number + name)        |
| 4     | `Patch`              | `1.401` (universe.address) or ` (-)` |
| 5     | `No\|Parameters`     |                                      |
| 6-11  | `Pos\|X` .. `Rot\|Z` | `0.00`                               |
| 12    | `Info`               |                                      |
| 13    | `RDM\|ID`            |                                      |

(In MA the names contain a real `|`, e.g. `No|Parameters`. The `\` is
only Markdown escaping.)

## Subfixture properties (`CMD_SUBFIXTURE`)

Same IDs in a different order: `0 FixId`, `1 ChaId`, `2 Name`, then
`Fixture|Type`, `Patch`, `React to|Master`, `Pan DMX|Invert`,
`Tilt DMX|Invert`, `Pan Enc.|Invert`, `Tilt Enc.|Invert`,
`Pan|Offset`, `Tilt|Offset`, `Swap`, `Bitmap|Disable`, `Color`,
`Pos|X..Z`, `Rot|X..Z`, `No|Parameters`, `RDM|ID`.

Lesson: **read properties by name, never by index**. The order is
different on different classes.

## Facts about IDs

- An empty ID is the text `-`. `[V]`
- Clear an ID with an empty value: `/FixId=` or `/ChaId=`. `[V]`
- Fixture IDs and Channel IDs are **separate number spaces**. Fixture
  101 and Channel 101 can exist at the same time (Kirk's show does). `[V]`
- A fixture may have only a FixId or only a ChaId. `[V]`
- Layer 0 "Auto-Created" holds `[Preset]` fixtures with **no** IDs at
  all (`FixId=-`, `ChaId=-`). Skip them. `[V]`
- Can a **patched** fixture lose both IDs? Unknown, so never leave one
  without an ID: set the new ID first, then clear the old one. `[?]`
- `getobj.name(fixture)` = name + `" "` + ID (`"Dim 1 1001"`). Use the
  `Name` property for the clean name. `[V]`
- Children of a layer are **not** sorted by ID: in `tr_profiles`
  (Fixtures 201..402) Fixture 401 is at index 0. Probably creation
  order. `[V]`
- Multi-instance fixtures: every instance is a `CMD_SUBFIXTURE`. Can
  instances have their own IDs? `[?]`
