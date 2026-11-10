class_name TerminalLevelService
extends Node
## Nível do Terminal as a live node. Owns one `TerminalLevel`, persists it as
## the `terminal_level` save section, and feeds it the EventBus events that
## are worth XP — the rules themselves never touch the bus.
##
## The level is meta progress, like the wheel's tokens: the section is a
## registered save section like any other and is deliberately NOT re-seeded by
## a prestige — `GameState.do_prestige` resets the run, and only a full profile
## wipe calls `seed_new` on sections.

signal xp_changed
## A level was reached. `features` is every feature the new level(s) unlocked.
signal leveled_up(level: int, features: Array)

const SECTION_ID := &"terminal_level"
## A legacy save from before this section existed has no level at all. A
## profile that already moved this many TEU could use every system the unlock
## table gates, so migration starts it at the level that unlocks them all.
const LEGACY_FULL_UNLOCK_TEUS := 1000.0
const LEGACY_FULL_UNLOCK_LEVEL := 12

var rules: TerminalLevel


func _ready() -> void:
	rules = TerminalLevel.new()
	SaveManager.register_section(SECTION_ID, rules.snapshot, _restore, _seed_new)
	EventBus.cargo_transfer_committed.connect(_on_cargo_transfer_committed)
	EventBus.ship_departed.connect(_on_ship_departed)
	EventBus.structure_purchase_committed.connect(_on_structure_purchase)
	EventBus.upgrade_bought.connect(_on_upgrade_bought)


func _exit_tree() -> void:
	EventBus.cargo_transfer_committed.disconnect(_on_cargo_transfer_committed)
	EventBus.ship_departed.disconnect(_on_ship_departed)
	EventBus.structure_purchase_committed.disconnect(_on_structure_purchase)
	EventBus.upgrade_bought.disconnect(_on_upgrade_bought)
	SaveManager.unregister_section(SECTION_ID)


func note_mission() -> void:
	## A daily mission was claimed — Main connects this to
	## `DailyOrdersService.mission_claimed`.
	_add(TerminalLevel.XP_PER_MISSION_CLAIMED)


func _add(amount: int) -> void:
	var before := rules.level
	var gained := rules.add_xp(amount)
	xp_changed.emit()
	if gained > 0:
		var features: Array = []
		for lvl in range(before + 1, rules.level + 1):
			features.append_array(rules.unlocks_at(lvl))
		leveled_up.emit(rules.level, features)


# ------------------------------------------------------------- event wiring

func _on_cargo_transfer_committed(_payload: Dictionary) -> void:
	## One committed cargo transfer — ship, road or rail.
	_add(TerminalLevel.XP_PER_TRANSFER)


func _on_ship_departed() -> void:
	_add(TerminalLevel.XP_PER_SHIP_DEPARTED)


func _on_structure_purchase(quote: Dictionary) -> void:
	## Units actually bought, from the committed quote, same as the daily
	## service: `structure_bought` carries the machine's total owned.
	_add(TerminalLevel.XP_PER_MACHINE * maxi(1, _as_int(quote.get("quantity", 1), 1)))


func _on_upgrade_bought(_id: String) -> void:
	_add(TerminalLevel.XP_PER_UPGRADE)


# -------------------------------------------------------------- persistence

func _restore(data: Dictionary) -> void:
	rules.restore(data)
	xp_changed.emit()


func _seed_new() -> void:
	rules.restore(TerminalLevel.seed_new())
	if maxf(GameState.lifetime_teus, GameState.all_time_teus) > 0.0:
		_migrate_legacy()
	xp_changed.emit()


func _migrate_legacy() -> void:
	## A save with no `terminal_level` section but a played profile: one that
	## already moved a thousand TEU was using everything the table gates, so it
	## starts at the level that unlocks all of it; anything smaller starts
	## honestly from zero XP at level 1.
	# All-time as well as this run: a profile that has just rebuilt its port has
	# a small lifetime and a long history, and must not be sent back to level 1.
	if maxf(GameState.lifetime_teus, GameState.all_time_teus) >= LEGACY_FULL_UNLOCK_TEUS:
		rules.xp = TerminalLevel.xp_for_level(LEGACY_FULL_UNLOCK_LEVEL)
		rules.level = LEGACY_FULL_UNLOCK_LEVEL


static func _as_int(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and (raw as String).is_valid_int():
		return (raw as String).to_int()
	return fallback
