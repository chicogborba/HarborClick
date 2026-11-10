extends Node
## Global signal hub. Everything talks through here to stay decoupled.
## Signals are emitted from all over the project, so the unused-signal warning
## is noise here.
@warning_ignore_start("unused_signal")

signal teus_changed(total: float)
signal cps_changed(cps: float)
signal container_unloaded(world_pos: Vector2, value: float, crit: bool)
signal structure_bought(id: String, count: int)
## A purchase went into the build queue / a build finished (units, not totals).
signal build_queued(id: String, qty: int)
signal build_completed(id: String, qty: int)
signal structure_purchase_committed(payload: Dictionary)
signal upgrade_bought(id: String)
signal land_bought(id: String)
signal route_bought(id: String)
signal ship_arrived
signal ship_departed
signal day_phase_changed(phase: StringName)
signal fog_changed(active: bool)
signal rain_changed(active: bool)
signal new_day(day: int)
signal prestiged(shares: int)
## The decoration shelf changed: something was bought, or switched on or off.
## Deliberately payload-free — every listener rebuilds from `GameState`, because
## half of them care about two items at once and none of them care which one
## moved.
signal cosmetics_changed
signal toast(text: String)
# A committed manual reward is deliberately separate from the visual click
# event.  Network/replay callers can safely retry it by transaction id.
signal manual_reward_committed(payload: Dictionary)
signal notification_requested(payload: Dictionary)
signal save_finished(ok: bool, reason: StringName)
signal save_recovered(source: StringName)
signal teu_credited(payload: Dictionary)
signal cargo_transfer_committed(payload: Dictionary)
signal berth_call_completed(payload: Dictionary)
signal achievement_completed(payload: Dictionary)
signal objective_changed(payload: Dictionary)
signal contract_changed(payload: Dictionary)
signal contract_completed(payload: Dictionary)
signal prestige_committed(payload: Dictionary)
signal prestige_tree_changed(id: StringName)
signal tutorial_step_changed(payload: Dictionary)
signal offline_summary_ready(payload: Dictionary)
