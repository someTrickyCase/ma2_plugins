# Sequence cleanup plugin development

Current source status: Sequence Cleanup v0.2.0 removes unused fixture data;
Sequence Position Presets v0.1.1 converts eligible raw positions. The
positive-stored-dimmer policy remains in effect. Position effects conversion
and full workflow console validation remain pending. The sections below
record development history; dated claims do not override current behavior.
`core/xml-verify.lua` remains an offline comparison helper for tests and
probe analysis. Neither shipped sequence entry point loads it at runtime.

## Historical combined-workflow requirements

- Work on the sequence assigned to the selected executor.
- Remove all sequence data for fixtures whose dimmer never exceeds zero.
- For fixtures without a dimmer, evaluate the fixture's shutter instead.
  A closed shutter must not qualify a dimmer fixture for removal.
  The user subsequently agreed to disable shutter-only removal until a
  suitable test fixture is available. These fixtures remain for review.
- Convert raw position and color values into newly allocated presets.
- Keep existing preset references unchanged.
- Position tolerance defaults to 5 in stored attribute values, adjustable
  by the user. Color mixing tolerance is also user configurable.
- Name new unnamed looks unknown_N, avoiding occupied names and slots.
- For color wheels, use the fixture-type color label where available.
- Automate Tracking, Block and Unblock if verified straightforward;
  otherwise provide manual steps.
- Use sequence numbers below 512 for testing. Standard pool.slot preset
  numbering, including preset 2.9002, is confirmed acceptable.

## Implemented and tested

core/preset-clusters groups numeric attribute vectors within tolerance.
The first vector remains the representative; chained similarity cannot
extend a cluster beyond tolerance. All attributes must match within the
limit, with identical attribute sets and compatible caller-defined scopes.
Existing preset references and unknown/nonnumeric vectors are skipped.
Zero tolerance requires exact equality. Input vectors are not mutated.

core/preset-xml writes the exported Preset/Values/Channels/PresetValue
structure with explicit fixture and attribute identities. It validates
finite numeric values, slot numbers, identifiers, duplicate attributes
and XML control characters, escapes XML text and retains double precision.
The position import/readback probe passed: both attribute identities and
numeric values matched exactly, as did the preset slot and generated name.
MA2 reformatted numeric text to its usual shorter representation; it
matched the original console export. This verifies one position preset,
not color presets or sequence-reference replacement.
Lua formatting, lint and all 98 tests passed after this addition.

core/ma-xml reads MA2 XML, handles the UTF-8 BOM, entities, quoted
attributes and source spans, and offers periodic yield callbacks. It
rejects unsupported declarations and malformed structure. It parsed
fixture-type, sequence and blocked-sequence exports locally.
core/fixture-type reads module channels, native DMX ranges, defaults,
wheel slots and labels. Its wheel label lookup accepts native DMX values,
distinguishes fixed selection from spin functions, preserves split labels
and returns unknown for ambiguous or missing ranges. Stored-value to DMX
conversion has not been verified. All 119 Lua tests and task rules pass.

ma/cleanup-context resolves the selected sequence through the selected
executor's Cue 1 parent. If that cue cannot be found it returns an error,
never an unrelated sequence. It reads single-instance fixture-type links
from the instance's Fixture|Type property and marks unsupported mappings
uncertain. Multi-instance mapping and cue-1-free sequences need more work.

core/sequence-data reads cue numbers, parts, attribute identities, numeric
and special values, effect presence and preset reference paths while
retaining source spans. The older conservative removal policy described
below was replaced by the positive-stored-dimmer rule documented in the
current workflow section. Shutter-only removal remains disabled.

core/sequence-edits removes every planned fixture row across cues/parts
and adds references only to eligible raw static rows. It preserves all
other XML bytes and rejects foreign/removed rows and existing references.
Synthetic regression data verifies removal while preserving retained
sequence content. No production show write is claimed by this test.
All 144 Lua tests and task rules pass.

## Verified research

The object API inspection exposed cue settings and part timings, but no
fixture values in inspected cue parts. This inspection was partial.
Sequence XML exports contain CueData entries with Channel identities,
Value, Preset references, effect references and effect flags. Values may
use scientific notation or special strings such as Release/DefaultLink.
Multipart association is stored separately for values and effects.

Real exports and detailed research stay outside tracked source. Tests
must use synthetic data. Local probe recipes are in scratch/probe.

## Required before show-writing code

- Verify effect-layer semantics through the tracking pass. Sequence copy,
  Assign /Track=On, Block Sequence and Unblock Sequence completed on a
  user-confirmed test copy. Export comparison preserved cue/part metadata
  and carried-forward Value plus Preset reference tokens wherever the
  original sequence had established them. This comparison does not prove
  physical output or effect-layer equivalence.
- Verify raw-to-preset replacement preserves cue/part boundaries,
  existing preset references, effects and individual timings beyond the
  tested static position pair. The reference import probe passed for one
  raw PAN/TILT pair: preset identities/values matched, references survived,
  and the full sequence XML matched after ignoring preset display names.
  MA2 may reorder preset channel entries; compare by channel identity.
- Read fixture-type metadata for shutter closure and color-wheel labels.
  One type export verified named channel ranges and wheel slots. A
  read-only context probe is installed to investigate fixture/type links
  and selected-sequence resolution; its console result is pending.
  Its first result verified instance-level Fixture|Type properties and
  the PATH variable. Selected-sequence resolution remains open; an
  updated probe will inspect executor cue parents and export used types.
  Follow-up verified Cue 1's parent as the selected sequence and exported
  the referenced types. Their definitions now parse successfully;
  duplicate dummy channels are retained as ambiguous alternatives.
- Resolve tracked values, preset/default links and effects before proving
  that a fixture is unused; report uncertain cases instead of deleting.
- Plan and report changes before applying, then read back each change.
- Confirm XML import/export preserves all data before using it to write.
  New-sequence import passed. The prepared overwrite probe copies the
  earlier test sequence 102 to unused 103, imports fixture-removal XML
  into that copy with /o, and exports before/after for comparison. Its
  console result is pending; replacement-versus-merge is still unknown.
  The overwrite probe has now passed: omitted records were removed. The
  full retained Sequ XML matched prepared input after normalizing only the
  target sequence index. Cue nodes and preset references remained. This
  verifies the sampled import,
  not concurrent editing, rollback or playback-output equivalence.
- Color import/reference probe prepared for one complete six-channel
  mixing vector and one non-open 8-bit color-wheel value. It uses Presets
  4.9001/4.9002 and unused Sequence 104. Stored percentage to native DMX
  conversion was subsequently confirmed for the sampled wheel as recorded
  below.

## Current runnable workflow

The color probe passed: sampled mixing and wheel values matched
numerically, their references survived and retained sequence content
matched. Visual inspection confirmed the sampled 8-bit naming conversion.

plugins/sequence-cleanup now wires cleanup-flow to cleanup-runtime.
The runtime prompts for a sequence number and tolerances, exports it and
used fixture types, scans occupied preset slots/names, prepares a complete
plan, marks review fixtures, asks for confirmation, creates a verified
backup below 512, imports/verifies presets and the edited sequence, and
then performs static tracking cleanup or prints manual effect-case steps.
Source freshness is checked before imports. Errors stop later work and
report the backup; earlier successful writes and new presets remain.

Raw samples are grouped by fixture, attribute family and cue part.
Partial data gets a partial preset rather than replacing another
attribute's existing reference. Wheel values use exact matching. Numeric
representatives are written alongside new references, so tolerance-based
look changes are explicit. New names/slots avoid current occupancy.

The release ZIP and tag remain unchanged. README describes this plugin
as unreleased. Golden files for the new plugin are generated regression
baselines, not independent proof. The final golden/full-check refresh
passed: rules, Lua lint/format/tests, Go lint and Go tests. An additional
effect/manual-finish integration case also passed, bringing Lua to 174
tests. The installed bundled Lua passed Lua 5.3 syntax validation and
contains all 17 required modules. The complete onPC trial remains pending.

The user explicitly agreed to keep shutter-only removal disabled for now.
The planner requires calibrated stored-value closure ranges before it can
remove a shutter-only fixture; the live reader supplies none yet. Dimmer
fixtures always use the dimmer rule, regardless of shutter state.

## First full trial and v0.1.1

The user reported a reading-stage stall while the progress bar stayed at
5/100. The input XML was exported, but no per-type exports appeared. This
localizes the stall to sequence reading or the work before type exports;
it does not prove an infinite parser loop or a specific sleep duration.

v0.1.1 always prompts for the sequence number first, using the selected
executor's sequence only as a suggestion. The XML reader reports byte
progress and asserts forward movement. Reading reports fixture-link and
type counts. Yield calls now share a 50 ms work budget with an eight-call
fallback cap and a verified 0.01-second sleep request, rather than sleeping
on every checkpoint. Fixture context reading uses the same budget.

Major phases and periodic progress are written to the console's temp/
sequence-cleanup-status.json for diagnosis. Local parsing completed with
cooperative checkpoints and simulated scheduler yields;
that is not a console timing measurement. Full checks and 178 Lua tests
pass. The versioned golden bundle passed Go bundle tests, and installed
Lua passed Lua 5.3 syntax validation. Actual console retry remains needed.

## Stage-70 investigation and v0.1.2

The subsequent run exported input, preflight and backup XML but no preset
or final sequence files. The backup's Sequ subtree matched the input
exactly after normalizing index and its automatically generated name.
The old verifier incorrectly rejected this legitimate backup identity.

The old verification benchmark retained the parsed sequence and reparsed
two more full trees: a local sample showed substantially higher memory use
and slower verification. The new reader consumes XML tokens, retains
compact channel rows and source spans, and discards transient CueData trees.
Sequence verification streams tokens instead of retaining more trees.

Freshness/backup checks use the already validated snapshot: compare all
body bytes, check root attributes with narrowly scoped identity allowances,
and validate the remaining document envelope. Differences fall back to
streaming semantic comparison. No data checks were removed. The local
snapshot check used less memory and completed faster.
This is not an onPC timing measurement.

Backup checks alone may ignore root sequence name/index differences;
source freshness and final sequence checks remain strict. Write progress
now reports source checks, backup verification, individual preset counts
and final sequence import/readback separately. Full checks and 184 Lua
tests pass, golden artifacts were refreshed, v0.1.2 was installed and its
bundled Lua passed Lua 5.3 syntax validation.

The remaining 20,000 preset handle lookups were investigated with the
read-only probe-preset-pools. Results and the follow-up are below.

## Native preset-pool traversal and v0.1.3

The probe verified that the parent of a qualified preset is a
CMD_PRESET_POOL with the expected pool number. Bare Preset N instead
resolved a preset in the current type, so it must not be used as a pool
address. The inspected pools each exposed 9002 indexed children, including
holes; child 0 was slot 1 and child 9001 was slot 9002.

The reader now finds a qualified seed (slot 1 first, then references in
the chosen sequence), validates its parent, and iterates native children.
Names and occupied numbers come only from non-nil children. The populated
test pools need two name lookups instead of 20,000; sparse holes and high
slots remain preserved. If no seed is found, a bounded discovery scan
remains as a fallback, including genuinely empty pools. That fallback is
not described as a constant-time empty-pool lookup.

The probe measured requested sleeps of 0.001/0.01 seconds at roughly
0.016 seconds, and 0.05 at roughly 0.047 seconds. This is one onPC sample,
not a timing guarantee. No sleep changes were inferred without evidence.

Tests cover sparse pools, qualified addresses, wrong-parent rejection and
sequence-reference seeds when slot 1 is empty. All 187 Lua tests pass;
the complete task check also passed, including Go lint/tests and golden
comparison. v0.1.3 was installed and its bundled Lua passed Lua 5.3 syntax
validation. The actual v0.1.3 console trial remains pending.

## Shared presets and faster writes, v0.1.4

Console feedback prompted fewer presets, removal of verification and green
preset borders.

Positions now combine raw fixture values in one cue_<cue number> preset
per cue part, preserving exact stored values. Nonzero parts have a
_part_<index> suffix; decimal cue numbers remain in names. The position
tolerance prompt is removed. Matching color vectors share presets across
fixtures and cues, using the existing mixing tolerance and exact wheel
matching. Preset XML includes every participating fixture once. Different
attribute sets and wheel labels remain separate. Existing preset links
are preserved, and occupied slots/names are avoided.

By explicit user request, runtime XML freshness checks and backup,
preset, sequence and tracking readback exports/comparisons are removed.
The backup copy, free-slot checks, planning and confirmation remain.
Command errors still stop execution. Pure XML verification modules/tests
remain available for development but are no longer bundled by this plugin.

Existing and new presets referenced by retained sequence rows are marked
with Appearance Preset <pool>.<slot> /r=0 /g=100 /b=0, once per address.
This changes shared preset borders globally. Removed fixture references
are excluded. The command is documented in the MA2 3.9 Appearance manual;
visual behavior is pending console confirmation. A focused copy-only
probe is prepared under scratch/probe/probe-preset-appearance.lua and XML.
It retains a newly allocated position preset and exports before/after;
it does not recolor its source preset.

Full task check passes with 192 Lua 5.3 tests, Go lint/tests and refreshed
golden artifacts. Console timing, multi-fixture preset import and visual
green-border confirmation remain pending. Test the original sequence or
its backup to measure reduced creation; existing generated references
are deliberately retained on reruns.

## Dimmer Release rule, v0.1.5

By user instruction, DIM rows whose exported value text is Release count
as zero when deciding whether a fixture is unused. This is a cleanup
policy, not a claim that released fixtures cannot receive output from
other playback sources. Positive dimmer values elsewhere still keep the
fixture. Effects, preset-linked rows, unknown initial output and other
special values remain conservative. Shutter Release is not treated as
closed. Retained XML keeps its original Release text; no zero values are
written into retained cues.

Regression tests cover Release-only and mixed zero/Release removal,
positive values before/after Release, effects, preset links, shutters and
end-to-end XML removal/preservation. Full task check passes with 196 Lua
5.3 tests and Go lint/tests; golden artifacts are refreshed. Console trial
remains pending.

## Missing selected executor number, v0.1.6

The user reported an immediate nil-concatenation error at bundle line
584. That line concatenated getobj.number(selected) into a cue address
without checking for nil. This is reproducible with a selected executor
whose number is unavailable. It now returns an unresolved suggestion,
allowing the explicit sequence prompt to open with default 1. No fallback
sequence is selected automatically. Missing-number context and prompt
regression tests cover the failure. Error handling also saves sanitized
error and recovery text to temp/sequence-cleanup-error.json; export failure
does not hide the original message. Full task check passes with 198 Lua
5.3 tests and Go lint/tests; golden artifacts are refreshed. Console retry
remains pending.

## Post-run dimmer retention review

A user-requested fresh console export semantically matched the prepared
sequence output. Remaining dark-looking fixtures were retained because
they had no first-cue dimmer value and their fixture-type XML omitted the
default attribute. The reader correctly represented that absence as nil;
the planner therefore classified initial brightness as unknown even when
all later stored dimmer values were zero or Release. This is separate
from Release handling and from sequence import. Treating missing initial
values as zero would change the cleanup policy and requires clarification.
Real exports and fixture-level analysis remain outside tracked source.

## Explicit positive-dimmer policy and position review, v0.1.7

The user explicitly changed removal policy: a fixture with a known dimmer
is retained only if at least one stored numeric dimmer value exceeds
zero. Missing first-cue values, fixture defaults, effects, preset links
and special values do not prevent removal when there is no positive
stored dimmer value. Missing/ambiguous fixture mappings and shutter-only
fixtures retain their existing review behavior. The planner does not
claim to predict physical output under other playbacks or effect layers.

The fresh console review also identified remaining unpreseted positions:
numeric bases with attached effects were excluded by the static-only
eligibility rule; other rows had Release, DefaultLink or no numeric base.
Converting numeric bases while preserving effects needs a console probe
before enabling that path. The bundled probe-position-effects under
scratch/probe prompts for an existing sequence, allocates free targets,
creates one position preset and a separate sequence, then compares the
preset and full sequence readbacks with prepared XML. It never imports
over the source sequence. The probe is pending. Special values are not
converted to numeric presets. Full task check passes with 199 Lua 5.3
tests and Go lint/tests; golden artifacts are refreshed. v0.1.7 is
installed. The positive-stored-dimmer rule now removes zero/Release-only
data under the explicit policy. Actual
console cleanup retry and the position/effect probe remain pending.

## References

- https://help.malighting.com/grandMA2/en/help/key_search_replace_replace.html
- https://help.malighting.com/grandMA2/en/help/key_keyword_sequence.html
- https://help.malighting.com/grandMA2/en/help/key_keyword_unblock.html

## Cue naming and reported identity error

Position preset names now use cue_ instead of cur_ by user request.
Focused naming tests first failed, then passed with the prefix change.
The reported console error near installed line 675 matches Missing channel
identity in sequence-data identifier validation. The latest saved input
has both identity attributes on every Channel element; the original
failing input or saved error is needed to establish the cause. No parser
validation has been relaxed.


## v0.1.8 console test build

Version bumped to 0.1.8 for the cue_ position preset naming change.
The user deferred identity-error debugging and requested installation
for an onPC test. Shared color grouping is unchanged.


Full task check passed (199 Lua tests, Go lint/tests). Installed v0.1.8
into onPC 3.9.60 for slot 103; read back version and cue_ prefix.
User must reimport the plugin into the show before testing.


## Split sequence workflows

Sequence Cleanup v0.2.0 at slot 103 now runs unused-fixture removal only.
Sequence Position Presets v0.1.0 at slot 104 runs position presetting only.
Both share the existing read, backup, confirmation and import adapters.
The position tolerance prompt is restored (default 5, zero exact).
Each cue/part retains its cue_ preset; within that group matching raw
Pan/Tilt sets cluster against a representative within tolerance. XML
references and preset channels receive the same representative values.
Color presetting is disabled in both entry points. Removal does not scan
preset pools or alter appearance. Positions never run removal planning
and only scan/mark pool 2. Effects conversion remains disabled pending
the existing probe. Identity-error debugging remains deferred.


Validation: full task check passes, including 206 Lua 5.3 tests and
Go lint/tests. Both golden bundles were regenerated deliberately.
Installed both plugin builds into onPC 3.9.60 and read back mode/version
markers. Console import and live behavior testing remain pending.

## Position preset result text, v0.1.1

The user confirmed the removal-only cleanup works in onPC. Position
preset result text now reports position presets created and values
replaced without the shared fixture-removal counter. Plan summaries
for position mode likewise omit removal counts. Backup information
remains. Conflicts objects are review markers for skipped values or
unsupported mappings; they do not necessarily mean an ID conflict.


Full task check passes with 207 Lua 5.3 tests and Go lint/tests.
Installed position v0.1.1; verified result text/version in installed Lua.
The reported unpreseted positions in the latest local output are numeric
bases with effects, special values or effect-only rows. No unreferenced
raw static numeric positions remain. Exact local counts stay out of
tracked documentation. The position/effect probe was copied to the onPC
plugin folder, its bytes verified, and its Lua 5.3 syntax checked.
Console probe execution remains required before enabling conversion of
numeric bases with effects. Probe creates a separate sequence and preset.
