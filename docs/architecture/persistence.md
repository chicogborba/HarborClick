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

