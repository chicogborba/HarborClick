# Persistence and profiles

`SaveManager` owns three profile paths and a versioned envelope:

```text
save_version
saved_at_unix
core        → GameState
time        → TimeManager
sections    → registered subsystem providers
```

Each section provider supplies:

1. `snapshot()` — stable serializable state;
2. `restore(data)` — restore without inventing live state;
3. optional `seed_new()` — explicit new-profile/wipe initialization.

## A port is a save file

A profile can run several ports (`PortDB`). The home port is the profile's own
`save.json` — which is why no profile needed migrating — and every other port
it opens is `port_<id>.json` beside it: a complete envelope with its own core,
clock and sections. `ports.json` is the ledger (`open`, `active`) and the only
thing ports share.

Switching port is the profile switch one level down: `SaveManager.use_port`
points the path, resets and loads, and it must be called with **no world
alive** — sections registered by a live world would be restored with another
port's cargo on their way out. `scenes/Voyage.tscn` is that gap. Because each
port is a whole envelope, every cargo contract (one UID exactly once, in-flight
reconciliation, the 24-box reserve) holds per port with no change to cargo
code, and a port left alone earns offline income the next time it is visited.

A first arrival has no file: the registered autoload sections are told to
`seed_new`, the world's sections seed themselves as the scene builds, and
`_seed_new_port` grants the port's working capital and marks the tour done.
`buy_port` writes the ledger before it debits the wallet. Deleting a profile
deletes every port file and the ledger. Focused suite: ports.

## Registration order

`PortWorld` registers `cargo_yard` before `berth_call`, then traffic and gate.
That order ensures physical yard stock exists before the first call arrives.
Providers registered after load receive their saved payload immediately.

## Cargo migrations

The yard manifest has its own version. `restore_saved()` is the SaveManager
adapter; raw `restore()` remains a literal restore used by transaction tests.
The v2→v3 migration repairs profiles drained by the historical 1-in/2-out road
rule with traceable `cidade` UIDs before rendering. A v3 empty snapshot remains
empty—migration is not runtime replenishment.

## Safety properties

- Writes rotate primary to backup only after a valid temporary file exists.
- Backup recovery repairs the primary before offline income is applied.
- In-flight cargo is persisted as transient ownership and reconciled on load.
- Deleting one profile never touches another.
- Wipe calls explicit seeds and then reloads the scene.

Focused suites: core, backup, profile, cargo, gate and wake.

