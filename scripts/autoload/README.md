# Autoload services

Configured in `project.godot`:

- `EventBus` — cross-system notifications, no durable state.
- `GameState` — economy inventory, routes, upgrades and calculated rates.
- `TimeManager` — day/time/weather clock.
- `Progression` — career records, achievements and contracts.
- `SaveManager` — profiles, sections, atomic writes, migration and offline gain.
- `AudioManager` — music/SFX playback, including sound *families*: a name in
  `VARIANTS` is played from several generated takes and a pitch ladder, drawn
  from shuffle bags so neither repeats back to back. Add takes in
  `tools/audio/gen_sfx.py` and the count here; call sites do not change.
- `UserPreferences` — player-facing local options.

Use an autoload only when state or service lifetime genuinely spans scenes.
Physical cargo belongs to registered `PortWorld` providers, not `GameState`.
When adding persisted fields, update default restore behavior and the relevant
core/backup/profile regression.

Read `docs/architecture/persistence.md` before touching saves or profiles.

