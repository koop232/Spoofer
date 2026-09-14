# The Admin → Tester link

This document explains how the two sides talk to each other, and — more
importantly — **what is and is not actually possible**, because the original
implementation promised something it could not deliver.

## The bug in the original design

`Amdim_side` published its selection like this:

```lua
local rsFolder = Instance.new("Folder")
rsFolder.Name = "DuelSpoofSync"
rsFolder.Parent = game:GetService("ReplicatedStorage")
rsFolder:SetAttribute("Brainrot", currentBrainrot)
```

That code runs on the **client**. In Roblox's replication model:

* Instances created by a client exist **only on that client**. They are never
  sent to the server, and therefore never to any other player.
* Attributes set by a client on a replicated instance are **not** replicated
  upward either. The server never sees them.

So the folder and its attributes were invisible to everyone except the machine
that created them. A "Tester side" running on a friend's computer would have
sat there forever reading attributes that did not exist. (It never got the
chance — `Tester side` was an empty file.)

The one-second loop that re-set the attributes did not help; it re-wrote
local-only state once per second.

## What this version does instead

Delivery is abstracted behind `Transport` objects, each of which honestly
declares whether it can cross machines:

| Transport | `crossClient` | Mechanism | Works when |
|---|---|---|---|
| `global` | ✗ | Shared `getgenv()` table | Both scripts run in the same executor on one machine |
| `folder` | ✗ | Attributes on a `ReplicatedStorage` folder | Same client; survives a script restart |
| `remote`  | ✓ | `FireServer` on an existing game `RemoteEvent` | Only if the game exposes a remote that relays arbitrary data back out to other clients |

`Sync` fans every publish out to all available transports and de-duplicates on
receipt, so enabling more transports is never harmful.

### Why `remote` is conditional

Genuine cross-machine delivery **requires the server to cooperate**. A client
cannot push data to another client directly. The only lever an exploit has is
to call a `RemoteEvent` the game already exposes and hope the server echoes the
payload to other players.

`Transport.Remote` therefore:

1. Breadth-first searches `ReplicatedStorage` (depth capped by
   `Config.Sync.RemoteSearchDepth`) for a `RemoteEvent` whose name matches one
   of `Config.Sync.RemoteHints`.
2. Reports `isAvailable() == false` when it finds nothing, rather than
   pretending to have sent the message.
3. Namespaces every payload with `Config.Sync.Channel` so an unrelated remote
   does not get confused by our traffic.

The admin UI reflects this. If no cross-client transport is live you get:

```
Ready · same-machine sync only (global+folder)
```

instead of a false sense of a working link.

**Be aware:** firing a remote the game did not intend you to fire is exactly
the pattern server-side anti-cheat looks for. Most games do not expose a
general purpose relay, and `RemoteHints` will need to be pointed at a real
remote for your specific game before cross-client sync does anything.

## Wire format

```lua
{
    protocol = 2,           -- must equal Config.Sync.Protocol
    slot     = "Main",      -- "Main" | "Other"
    brainrot = "Griffin",   -- "" means "clear this slot"
    sequence = 17,          -- monotonic per session; rejects replays
    session  = "a1b2c3d4",  -- identifies the broadcasting admin
    sentAt   = 1234.5,      -- sender clock, drives the staleness indicator
}
```

`Protocol.validate` enforces every field. `Protocol.isNewer` drops replays and
out-of-order deliveries (important now that a payload can arrive via three
transports at once). `Protocol.isStale` powers the receiver's link indicator so
"the admin is idle" is visually distinct from "the link is broken".

All of these rules are pure functions and are covered by `tests/run_tests.lua`.

## Heartbeat

The admin republishes its latest payload every
`Config.Behaviour.HeartbeatInterval` seconds. This lets a tester that joins
late converge on the current state, and keeps `sentAt` fresh so the receiver's
indicator stays green. Because the sequence number does not change, the
receiver de-duplicates it rather than re-rendering the model every second —
which the original loop would have done.
