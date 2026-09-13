# Duel Spoofer — Admin → Tester (over GitHub)

Admin picks a brainrot; the **tester, on a different account/PC, sees it** —
name, `$/s` generation, and the real 3D model. No server to host, nothing to
keep running: **GitHub is the middleman.**

```
ADMIN client ──PATCH /gists/:id──▶  GitHub Gist  ◀──GET (ETag)──  TESTER client
  Amdim_side                     spoof-<room>.json                "Tester side"
```

---

## Why it goes through GitHub at all

Roblox executor scripts run **client-side**. Any `Instance` an executor creates —
folders, attributes, `RemoteEvent`s — lives only inside that one client and is
**never replicated** to the server or to other players.

The original script broadcast by writing attributes to a locally-created
`ReplicatedStorage.DuelSpoofSync` folder, which only a receiver in the *same*
client could read. For two different accounts it was a no-op. A Gist is a
shared scratchpad both machines can reach, so the admin writes and the tester
reads.

---

## Setup

### 1. Admin token (write access)

1. Go to <https://github.com/settings/tokens> → **Generate new token (classic)**.
2. Tick **only** the `gist` scope. That scope cannot touch your repositories.
3. Copy the token into `TOKEN` at the top of **`Amdim_side`**.

### 2. Run the admin script once

It creates the Gist and prints (and copies to your clipboard) the ID:

```
📡 Created sync Gist. PUT THIS ID IN BOTH SCRIPTS:
     GIST_ID = "a1b2c3d4e5f6…"
```

Paste that into `GIST_ID` in **both** scripts.

### 3. Tester token (read access)

The tester needs its own token too. Any classic token works — no scopes
required if you flip `PUBLIC_GIST = true`; use the `gist` scope to read the
default secret gist.

> **Why the tester needs one.** Polling uses conditional requests
> (`ETag` / `If-None-Match`). GitHub only exempts a `304` from the rate limit
> when the request is **authenticated**; the docs attach that condition
> explicitly, and unauthenticated `304`s really do decrement the counter.
>
> | | limit | does a 304 cost quota? | practical poll rate |
> |---|---|---|---|
> | **With token** | 5000/hr | **no — free** | ~1.5 s |
> | No token | 60/hr | yes | ~60 s |
>
> Measured: 40 rapid authenticated conditional polls consumed **0** quota.
> The tester refuses to poll faster than once a minute without a token, so a
> missing token degrades gracefully instead of getting you rate-limited.

### 4. Match the room and run

`ROOM` must be identical in both scripts (it selects `spoof-<room>.json` inside
the Gist, so several sessions can share one Gist). Then execute **`Amdim_side`**
on the admin account and **`Tester side`** on the tester account.

---

## Configuration

```lua
-- Amdim_side
local CONFIG = {
    TOKEN   = "ghp_…",   -- classic token, "gist" scope
    GIST_ID = "",        -- blank on first run; script creates one and prints it
    ROOM    = "default",
    PUBLIC_GIST  = false,
    LOCAL_MIRROR = true, -- also write local attributes (same-client receivers)
}

-- Tester side
local CONFIG = {
    TOKEN      = "ghp_…",
    GIST_ID    = "a1b2c3…",  -- from the admin script
    ROOM       = "default",  -- must match
    POLL       = 1.5,
}
```

---

## Using it

**Admin** — pick `MAIN`/`OTHER`, click a brainrot. It swaps locally *and* syncs.
The panel shows `📡 synced → room "default"` when the write lands.

| Control | Action |
|---|---|
| Click brainrot | Swap the selected slot + sync to tester |
| `REPLACE` | Quick-swap to Dragon Cannelloni |
| `REVERT` | Reset both slots, clears the tester too |
| `CLEAN PLOT` | Remove brainrots from your plot |
| `F1` / `F5` / `F6` | Quick swap / refresh / clean plot |

**Tester** — read-only panel: both slot cards with a spinning 3D model, live
`$/s`, an event feed, and a connection indicator. `F2` toggles the panel.

---

## Behaviour worth knowing

**Writes are coalesced.** GitHub asks for ≥1 s between mutating requests, and
two in-flight `PATCH`es can clobber each other. The admin queues and collapses
rapid spoofs: spamming 10 in a row produced **2** API writes, ≥1 s apart, and
the final state still matched the last spoof. So click as fast as you like.

**Latency.** A change lands on the tester in roughly 1–2 s (one write plus one
poll interval). Idle polling is ~free: in a 12 s idle window, 15 of 16 polls
returned `304`.

**The admin needs a real executor.** Writing requires `POST`/`PATCH` with
headers. `game:HttpGet` is GET-only, so an executor without a `request()`
function can't be the admin. The panel says so plainly rather than failing
silently. The tester can fall back to `game:HttpGet`, but unauthenticated and
without ETags, so it polls slowly.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Admin: `no TOKEN set` | `TOKEN` is empty — see step 1 |
| Admin: `executor can't POST` | Executor exposes no `request()`; use one that does |
| Admin: `sync FAILED: Bad credentials` | Token wrong, expired, or missing the `gist` scope |
| Tester: `No GIST_ID set` | Paste the ID the admin script printed |
| Tester: `Gist not found — check GIST_ID` | Typo'd ID, or it's a secret gist and the tester has no token |
| Tester: `no file "spoof-x.json" (ROOM mismatch?)` | `ROOM` differs between the two scripts |
| Tester live but slow | No `TOKEN` → capped at one poll/minute by design |
| Name + `$/s` show, model doesn't | Model assets aren't in that client's `ReplicatedStorage`; falls back to a text badge. Harmless |
| Nothing happens on the admin | The duel GUI (`DuelsMachineSession`) isn't open |

---

## Security notes

* The `gist` scope cannot read or write your repositories.
* A "secret" gist is unlisted, **not** private — anyone with the ID can read it.
  Don't put anything sensitive in `ROOM` names.
* Tokens are stored in plaintext in the scripts. Don't commit a filled-in copy
  or share it; revoke at <https://github.com/settings/tokens> if it leaks.

---

## Layout

```
Amdim_side     Admin client — swapper GUI + Gist writer
Tester side    Tester client — receiver GUI + ETag Gist poller
```
