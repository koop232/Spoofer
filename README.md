# Duel Spoofer — one script, both sides

`Spoofer.lua` is the whole thing. Run the **same file** on every account; it
reads the Roblox username and picks its own role.

| Running as | Header | Role |
|---|---|---|
| `fmly_funke` | ⚡ **ADMIN DETECTED** | Picks brainrots. Everything you pick goes out as a dragon. |
| anyone else | 👋 **WELCOME** | Tester. Sees whatever the admin pushed — name, `$/s`, 3D model. |

The tester **only** accepts a spoof authored by `fmly_funke`. A push from any
other name is ignored and logged.

```
fmly_funke ──PATCH /gists/:id──▶  GitHub Gist  ◀──GET (ETag)──  everyone else
                               spoof-<room>.json
```

---

## Why it goes through GitHub

Roblox executor scripts run **client-side**. Instances an executor creates —
folders, attributes, `RemoteEvent`s — exist only in that one client and are
**never replicated** to the server or to other players. Two accounts can't see
each other's local state, so the spoof travels through a Gist instead. Nothing
to host, nothing to keep running.

---

## Setup

### 1. Admin token

1. <https://github.com/settings/tokens> → **Generate new token (classic)**.
2. Tick **only** the `gist` scope. It cannot touch your repositories.
3. Paste it into `TOKEN` at the top of `Spoofer.lua`.

### 2. Run it once as `fmly_funke`

It creates the Gist and prints (and clipboards) the ID:

```
📡 Created sync Gist. PUT THIS ID IN THE SCRIPT (both copies):
     GIST_ID = "a1b2c3d4e5f6…"
```

Paste that into `GIST_ID`.

### 3. Give the tester the same file

Same `GIST_ID`, same `ROOM`, but **their own token**. Any classic token works —
no scopes needed if you set `PUBLIC_GIST = true`; `gist` scope to read the
default secret gist.

> **Why the tester needs a token too.** Polling uses conditional requests
> (`ETag` / `If-None-Match`). GitHub only exempts a `304` from the rate limit
> when the request is **authenticated**, and unauthenticated `304`s really do
> decrement the counter.
>
> | | limit | 304 costs quota? | poll rate |
> |---|---|---|---|
> | **With token** | 5000/hr | **no — free** | ~1.5 s |
> | No token | 60/hr | yes | ~60 s |
>
> Measured: 40 rapid authenticated conditional polls consumed **0** quota. The
> tester self-throttles to one poll a minute without a token, so a missing
> token degrades gracefully instead of getting you rate-limited.

---

## Config

Everything lives in one block at the top:

```lua
local CONFIG = {
    ADMIN_USER   = "fmly_funke",  -- case-insensitive
    TOKEN        = "",            -- your GitHub token
    GIST_ID      = "",            -- blank on the admin's first run
    ROOM         = "default",     -- must match on both accounts
    PUBLIC_GIST  = false,

    FORCE_DRAGON = true,               -- every pick goes out as…
    DRAGON_NAME  = "Dragon Cannelloni", -- …this
    POLL         = 1.5,
}
```

`FORCE_DRAGON = true` is the behaviour you asked for: the admin can click
*anything* and both the admin's own duel card and the tester show
**Dragon Cannelloni**. Set it to `false` to send exactly what was picked.

---

## Using it

**Admin** (`fmly_funke`) — pick `MAIN`/`OTHER`, then click a brainrot.

| Control | Action |
|---|---|
| Click any brainrot | Swap that slot + push to testers |
| `DRAGON` | Jump straight to Dragon Cannelloni |
| `REVERT` | Reset both slots, clears testers too |
| `CLEAN` | Remove brainrots from your plot |
| `F1` / `F5` / `F6` | Dragon / refresh list / clean plot |
| `F2` | Hide or show the panel |

**Tester** — read-only: both slot cards with a spinning 3D model, live `$/s`,
an event feed, and a connection dot. `F2` toggles the panel.

---

## Behaviour worth knowing

**Writes are coalesced.** GitHub wants ≥1 s between mutating requests, and two
in-flight `PATCH`es can clobber each other. Rapid picks collapse: spamming 10
produced **2** API writes, ≥1 s apart, with the final state still correct. Click
as fast as you like.

**Latency.** ~1–2 s (one write plus one poll). Idle polling is nearly free — 15
of 16 polls in a 12 s idle window returned `304`.

**The admin needs a real executor.** Writing needs `POST`/`PATCH` with headers;
`game:HttpGet` is GET-only, so an executor without a `request()` function can't
be the admin. The panel says so plainly instead of failing silently. Testers can
fall back to `game:HttpGet`, but unauthenticated and without ETags, so slowly.

**Missing model assets are survivable.** If the brainrot's model isn't in that
client's `ReplicatedStorage`, the card still shows the name and `$/s` with a 🐉
text badge instead of the 3D model.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Says WELCOME but you *are* the admin | Roblox username ≠ `ADMIN_USER`. It's the username, not the display name |
| `no TOKEN set` | `TOKEN` is empty — see step 1 |
| `executor can't POST` | Your executor exposes no `request()`; the admin needs one that does |
| `sync FAILED: Bad credentials` | Token wrong, expired, or missing the `gist` scope |
| `No GIST_ID set` | Paste the ID the admin run printed |
| `Gist not found — check GIST_ID` | Typo'd ID, or it's secret and the tester has no token |
| `no file "spoof-x.json" (ROOM mismatch?)` | `ROOM` differs between the two copies |
| `ignoring push from "x"` | Someone who isn't `fmly_funke` wrote to the gist. Working as intended |
| Tester live but slow | No `TOKEN` → capped at one poll/minute by design |
| Admin: nothing happens on click | The duel GUI (`DuelsMachineSession`) isn't open |

---

## Security notes

* The `gist` scope cannot read or write your repositories.
* A "secret" gist is **unlisted, not private** — anyone with the ID can read it.
* Tokens sit in plaintext in the script. Don't commit a filled-in copy or share
  it; revoke at <https://github.com/settings/tokens> if it leaks.
* Username gating is a convenience, not real security: anyone holding the gist
  ID and a write token could author a push claiming to be `fmly_funke`.

---

## Layout

```
Spoofer.lua    ← the one script. Run this on every account.
Amdim_side     previous split version (admin half), kept for reference
Tester side    previous split version (tester half), kept for reference
```
