# Duel Spoofer — Admin → Tester

Admin picks a brainrot; the **tester, on a different account/PC, sees it instantly** —
name, `$/s` generation, and the real 3D model.

```
ADMIN client  ──POST /push──▶  RELAY (node)  ◀──long-poll /state──  TESTER client
  Amdim_side                  relay/server.js                       "Tester side"
```

---

## Why a relay is required

Roblox executor scripts run **client-side**. Any `Instance` an executor creates —
folders, attributes, `RemoteEvent`s — lives only inside that one client's
simulation and is **never replicated** to the server or to other players.

The original script broadcast by writing attributes to a locally-created
`ReplicatedStorage.DuelSpoofSync` folder. That can only ever be read by a
receiver running *in the same client*. For two different accounts it is a no-op —
the tester's client has no such folder and never will.

The relay is the out-of-band channel that actually carries the spoof between the
two machines. Local attribute mirroring is still written (`LOCAL_MIRROR = true`)
so same-client receivers keep working.

---

## Setup

### 1. Start the relay

```bash
node relay/server.js
```

Options: `PORT=3000`, `HOST=0.0.0.0`, `RELAY_KEY=<shared-secret>` (auth off when unset).

Open `http://<host>:3000/` for a live web dashboard of everything the tester sees.

### 2. Make it reachable by both players

Both Roblox clients must be able to reach the relay over HTTP.

| Setup | `RELAY_URL` |
|---|---|
| Both Roblox windows on the same PC as the relay | `http://localhost:3000` |
| Different PCs on the same LAN | `http://<relay-lan-ip>:3000` |
| Over the internet | Expose it (e.g. `cloudflared tunnel --url http://localhost:3000`) and use the public HTTPS URL |

> Internet exposure: set `RELAY_KEY` and put the same value in both scripts' `KEY`.

### 3. Configure both scripts

`Amdim_side` (top of file) and `Tester side` (top of file) must agree:

```lua
local CONFIG = {
    RELAY_URL = "http://localhost:3000",  -- identical in both
    ROOM      = "default",                -- identical in both
    KEY       = "",                       -- identical in both (match RELAY_KEY)
}
```

`ROOM` separates concurrent sessions — different rooms never see each other.

### 4. Run them

* Execute **`Amdim_side`** on the admin account.
* Execute **`Tester side`** on the tester account.

The admin panel shows `📡 relay online → room "default"` when linked.
The tester panel shows a green dot and `🟢 Live`.

---

## Using it

**Admin** — pick `MAIN`/`OTHER`, click a brainrot. It swaps locally *and* pushes to the tester.

| Control | Action |
|---|---|
| Click brainrot | Swap the selected slot + push to tester |
| `REPLACE` | Quick-swap to Dragon Cannelloni |
| `REVERT` | Reset both slots, tells tester to clear |
| `CLEAN PLOT` | Remove brainrots from your plot |
| `F1` / `F5` / `F6` | Quick swap / refresh / clean plot |

**Tester** — read-only panel: both slot cards with a spinning 3D model, live
`$/s`, an event feed, and a connection indicator. `F2` toggles the panel.

---

## Relay API

| Method | Route | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness + whether auth is on |
| `POST` | `/push` | `{room, key, slot, brainrot, gen, genText, admin}` |
| `POST` | `/revert` | `{room, key, admin}` — clears both slots |
| `GET` | `/state?room=&since=&wait=` | Read state; `wait=N` long-polls up to N s |
| `GET` | `/api/rooms` | All active rooms |
| `GET` | `/` | Web dashboard |

`GET /push` and `GET /revert` accept the same fields as query params, because some
executors have no POST-capable `request()` and can only use `game:HttpGet`.

**Updates are push-latency, not poll-latency.** `/state` long-polls: the request is
held open until the value changes, so the tester repaints in ~200 ms rather than
waiting out a fixed interval.

---

## Executor compatibility

Both scripts probe for a request function in order — `syn.request`, `http.request`,
`http_request`, `request`, `fluxus.request`, `krnl.request` — and fall back to
`game:HttpGet` (GET-only) if none exists. Each prints which transport it resolved:

```
📡 [Tester] HTTP transport: executor request()
```

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Admin: `relay OFFLINE` | Relay not running, or `RELAY_URL` unreachable from that PC |
| Tester: `🔴 Relay unreachable` | Same — check firewall / use LAN IP, not `localhost`, across machines |
| Tester live but nothing arrives | `ROOM` differs between the two scripts |
| `bad key` in console | `KEY` doesn't match the relay's `RELAY_KEY` |
| Name + `$/s` show, model doesn't | Model assets aren't in that client's `ReplicatedStorage`; the card falls back to a text badge. Harmless |
| Nothing happens on the admin | The duel GUI (`DuelsMachineSession`) isn't open |

---

## Layout

```
Amdim_side          Admin client — swapper GUI + relay push
Tester side         Tester client — receiver GUI + long-poll
relay/server.js     Zero-dependency Node relay
relay/public/       Live web dashboard
```
