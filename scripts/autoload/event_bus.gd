extends Node
## Global signal hub. Everything talks through here to stay decoupled.
## Signals are emitted from all over the project, so the unused-signal warning
## is noise here.
@warning_ignore_start("unused_signal")

signal teus_changed(total: float)
signal cps_changed(cps: float)
signal container_unloaded(world_pos: Vector2, value: float, crit: bool)
signal structure_bought(id: String, count: int)
signal upgrade_bought(id: String)
signal land_bought(id: String)
signal ship_arrived
signal ship_departed
signal day_phase_changed(phase: StringName)
signal fog_changed(active: bool)
signal new_day(day: int)
signal prestiged(shares: int)
signal toast(text: String)
