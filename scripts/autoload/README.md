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
  Music is six generated loops — `music_dawn/day/dusk/night/fog/rain`
  (`tools/audio/gen_music.py`) — chosen by `update_music()` from the weather
  first (rain, fog) then the day phase, crossfaded. Ambience beds (sea, port hum
  scaled by production, rain, wind, thunder) run on their own bus under the
  music. 16 voices, mute on focus loss, unlock on first gesture (web).
- `AdService` — the one seam to ad SDKs. `show_rewarded(placement, on_reward)`
  with daily caps and cooldowns enforced by the pure `AdPolicy`
  (`scripts/monetization/`); the placeholder provider plays a 3-2-1 test panel.
  Swap in a real provider by replacing one class; screens never change.
- `UserPreferences` — player-facing local options.

Use an autoload only when state or service lifetime genuinely spans scenes.
Physical cargo belongs to registered `PortWorld` providers, not `GameState`.
When adding persisted fields, update default restore behavior and the relevant
core/backup/profile regression.

Read `docs/architecture/persistence.md` before touching saves or profiles.

