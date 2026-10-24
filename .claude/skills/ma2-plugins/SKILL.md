---
name: ma2-plugins
description: >-
  Facts and recipes for writing grandMA2 (onPC 3.9.60) Lua plugins: the gma
  API, plugin XML/Lua anatomy, gma.cmd and the command line, the EditSetup
  patch tree, Fixture/Channel IDs, files, sockets and the probe-plugin
  workflow for learning unknown MA2 behaviour. Use before writing or
  reviewing any code that calls gma, before designing a new plugin, when an
  MA2 behaviour is unknown or surprising, and after every probe to record
  what was learned.
---

# grandMA2 Lua plugins

Everything we know about writing Lua plugins for grandMA2.
Started 2026-10-24 on grandMA2 onPC 3.9.60 (Windows 11).

## How sure are we?

Every fact has a tag:

| Tag    | Meaning                                                     |
| ------ | ----------------------------------------------------------- |
| `[V]`  | **Verified** on Kirk's laptop (probe plugin, files on disk) |
| `[MA]` | Written in MA's own example plugins that ship with onPC     |
| `[M]`  | From Claude's memory. Probably right, but **test it first** |
| `[?]`  | Open question. Nobody has checked yet                       |

Build only on `[V]` and `[MA]`. For `[M]` or `[?]`, run a probe first
(see `references/probing.md`).

## The ten things that bite

1. MA2 runs **Lua 5.3**. Test on `lua53`. `[V]`
2. A plugin file must **return** its entry function, optionally a
   cleanup function: `return start, cleanup`. `[MA]`
3. **File-level state survives between runs.** Reset tables inside the
   entry function. `[V]`
4. Plugins are coroutines. Anything that blocks without `gma.sleep`
   **freezes the whole console**. `[MA]` `[M]`
5. There are no setters. Change the show only with `gma.cmd(...)`. `[MA]`
6. `gma.cmd` returns an error text on failure and **no value at all** on
   success. Store it first: `local problem = gma.cmd(x)`. `[V]`
7. `cd` moves the **user's** command line too. Always end with
   `gma.cmd("cd /")`. `[MA]`
8. EditSetup is an edit session: changes apply on `cd /`, and are
   readable at once after it. `[V]`
9. MA **silently steals duplicate IDs**. Never create a duplicate, not
   even for a moment. `[V]`
10. Read properties **by name**, never by index. Child and property
    indexes are 0-based; `assign` positions are 1-based. `[V]`

## Where to look

| Topic                                         | File                           |
| --------------------------------------------- | ------------------------------ |
| Paths, Lua environment, files, sockets        | `references/environment.md`    |
| Plugin XML + Lua file, import, threading      | `references/plugin-anatomy.md` |
| Full `gma` API list for 3.9                   | `references/gma-api.md`        |
| `gma.cmd`, `cd`, `assign`, ID change recipe   | `references/command-line.md`   |
| EditSetup patch tree, fixture properties, IDs | `references/patch-tree.md`     |
| How to learn new facts with probe plugins     | `references/probing.md`        |
| What we still don't know                      | `references/open-questions.md` |

## Keep it true

- After every probe, update the matching reference file. Change the tag
  (`[M]` -> `[V]`), note the probe name, and close the open question.
- New fact without a home? Add it to the closest file. If a fact
  bites often, add it to the list above.
- Project rules (TDD, no comments, layout) live in the repo's
  `CLAUDE.md`, not here.
