# Architecture

## Layout

```
src/
  shared/            services shared by both sides
    Config.lua         all tunables, theme, catalogue, game paths
    Env.lua            the ONLY file that touches Roblox services/executor globals
    Log.lua            levelled logging + ring buffer
    Signal.lua         tiny observer
    Util.lua           pure helpers (formatting, fuzzy search)
    Protocol.lua       payload construction + validation (pure)
    Transport.lua      global / folder / remote delivery channels
    Sync.lua           fan-out, sequencing, replay rejection
    Catalogue.lua      brainrot metadata, memoised
    PlotService.lua    plot discovery + the classification rules for cleaning
    DuelService.lua    reading/writing the in-game duel GUI
    Ui.lua             widget helpers (window, button, list, draggable)
  admin/init.lua     controlling side: pick, apply, publish
  tester/init.lua    receiving side: listen, apply, show link health

build/bundle.py      flattens src/ into single-file executor scripts
dist/                generated: Admin.lua, Tester.lua  (do not hand-edit)
tests/               offline suite + Roblox stubs
tools/               syntax checker and Lua runner used by CI
```

## Design rules

**1. One place touches Roblox.** `Env.lua` owns every `GetService`, every
executor global (`gethui`, `getgenv`, `http_request`), and every fallback. That
is what makes the rest of the code loadable by a plain Lua interpreter, and it
means executor quirks are handled once instead of being re-`pcall`ed at each of
the forty-odd call sites the original had.

**2. Decisions are pure functions.** Anything that decides *whether* to do
something — is this payload valid, should this model be deleted, does this name
match the search — is a pure function taking a plain table. Anything that
*performs* an effect is a thin wrapper around it. `PlotService.classify` is the
clearest example: the deletion rules are a pure function with a 10-case test,
while `PlotService.clean` just walks Workspace and feeds it.

**3. Config is data, not code.** Radii, intervals, keybinds, colours, the
catalogue and the game object paths all live in `Config.lua`. A game update
that renames `AnimalPodiums` is a one-line change, not a grep.

**4. Failures are visible, not swallowed.** The original wrapped nearly
everything in a bare `pcall(function() ... end)` and discarded the error. Here
`pcall` is still used at boundaries, but the failure is logged with context
through `Log`, and user-facing operations return `ok, reason` so the UI can say
*why* something did not work.

## Notable fixes carried over from the original

| Issue | Original | Now |
|---|---|---|
| Cross-client sync | Client-set attributes that never replicate | Honest transport abstraction; UI states plainly when only same-machine sync is live (see `docs/SYNC.md`) |
| Tester side | Empty file | Implemented receiver with link-health indicator |
| Plot cleaning | Deleted any Model with a Humanoid within 60 studs — including other players' characters | Ordered rule set with an absolute exclusion for player characters; requires a catalogue name match |
| Search performance | Rebuilt 65 rows and re-`require`d the game data module on every keystroke | Debounced input, memoised metadata |
| Duplicate swap work | Every swap ran a full plot clean inside `SwapBrainrot`, then the caller cleaned again | Single clean per action |
| Drag handling | Leaked a global `UserInputService` connection per window, forever | Connections tracked and disconnected when the GUI is destroyed |
| Cloned models | Parented into the viewport as-is, scripts included | Scripts stripped, parts anchored and made non-collidable/non-queryable |
| Logging | `print` with emoji from a dozen sites, unsilenceable | Levelled `Log` with a ring buffer |
| Config | Magic numbers inline (8, 60, 0.3, 1) | Named entries in `Config.Behaviour` |
| Testing | None possible | 70 assertions runnable offline |

## Build

`dist/*.lua` is generated. `build/bundle.py` inlines each module into a
registry and rewrites `require(script.Parent.X)` into `__require("X")`, because
executors load exactly one file.

```bash
python3 build/bundle.py          # regenerate
python3 build/bundle.py --check  # CI: fail if dist/ is stale
```

Never edit `dist/` by hand — CI will fail on the freshness check.
