# Spoofer

A Roblox duel-GUI brainrot swapper, split into an **admin** side that chooses
what to display and a **tester** side that mirrors the choice.

> **Status:** v2.0.0 — restructured from a single 1,155-line script into tested
> modules. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the layout and
> [`docs/SYNC.md`](docs/SYNC.md) for how the two sides communicate.

## Quick start

Load the generated single-file builds with your executor:

```lua
-- Admin (the machine that picks)
loadstring(readfile("dist/Admin.lua"))()

-- Tester (the machine that mirrors)
loadstring(readfile("dist/Tester.lua"))()
```

Both files in `dist/` are self-contained; nothing else needs to be present.

### Controls

| Key | Action |
|---|---|
| `F1` | Apply the quick-swap brainrot to the selected slot |
| `F5` | Rebuild the list and refresh slot readouts |
| `F6` | Clean brainrots from your plot |
| `]`  | Show / hide the window |

The search box is fuzzy: `dgc` finds *Dragon Cannelloni*.

## Read this before expecting cross-machine sync

The admin can only reach a tester **on another computer** if the game happens
to expose a `RemoteEvent` that relays arbitrary data back out to other clients.
A Roblox client cannot send data to another client directly — the server has to
cooperate.

The original version appeared to support this but could not: it set attributes
on a client-created `ReplicatedStorage` folder, which never replicates anywhere.

This version is explicit about it. When no relay remote is found the admin
status line reads:

```
Ready · same-machine sync only (global+folder)
```

Point `Config.Sync.RemoteHints` at a real remote for your game to enable the
cross-client path. The full explanation is in [`docs/SYNC.md`](docs/SYNC.md).

## Development

```bash
./scripts/setup.sh   # one-time: local Lua runtime for the tests
./scripts/test.sh    # syntax check + 70 unit tests + bundle freshness
```

Edit modules under `src/`, then regenerate the bundles:

```bash
python3 build/bundle.py
```

`dist/` is generated output — CI fails if it is stale relative to `src/`.

### Project layout

```
src/shared/     services (config, sync, plot, duel, ui, logging)
src/admin/      controlling side
src/tester/     receiving side
build/          bundler
dist/           generated executor-ready scripts
tests/          offline suite with Roblox stubs
tools/          syntax checker + Lua runner used by CI
```

Configuration — radii, intervals, keybinds, theme colours, the brainrot
catalogue and all game object paths — lives in `src/shared/Config.lua`.

## Tests

The suite runs without Roblox by stubbing `Color3`, `Vector3`, `Enum` and
friends, so the decision logic is verifiable on any machine:

* payload validation, replay rejection, staleness, attribute round-tripping
* plot-cleaning rules, including a regression test that player characters are
  never deleted
* number formatting, truncation, fuzzy search ranking
* catalogue integrity (sorted, no duplicates, referenced names exist)
* signal dispatch and listener isolation

## Legal

Provided for educational purposes. Using it may violate Roblox's Terms of
Service and the rules of any game you run it in. You are responsible for how
you use it.
