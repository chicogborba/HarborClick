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
## How many levels the last grant crossed — Main pays one wheel token each.
signal levels_gained(count: int)
## A pass tier was collected and its reward paid: {tier, kind, ...reward}.
signal reward_claimed(reward: Dictionary)

const SECTION_ID := &"terminal_level"
## A legacy save from before this section existed has no level at all. A
## profile that already moved this many TEU could use every system the unlock
## table gates, so migration starts it at the level that unlocks them all.
const LEGACY_FULL_UNLOCK_TEUS := 1000.0
const LEGACY_FULL_UNLOCK_LEVEL := 18

var rules: TerminalLevel
var _wheel_service: WheelService


func _ready() -> void:
	rules = TerminalLevel.new()
	FeatureGate.bind(rules)
	SaveManager.register_section(SECTION_ID, rules.snapshot, _restore, _seed_new)
	EventBus.cargo_transfer_committed.connect(_on_cargo_transfer_committed)
	EventBus.ship_departed.connect(_on_ship_departed)
	EventBus.structure_purchase_committed.connect(_on_structure_purchase)
	EventBus.upgrade_bought.connect(_on_upgrade_bought)
	EventBus.achievement_completed.connect(_on_achievement_completed)


func _exit_tree() -> void:
	FeatureGate.unbind(rules)
	EventBus.cargo_transfer_committed.disconnect(_on_cargo_transfer_committed)
	EventBus.ship_departed.disconnect(_on_ship_departed)
	EventBus.structure_purchase_committed.disconnect(_on_structure_purchase)
	EventBus.upgrade_bought.disconnect(_on_upgrade_bought)
	EventBus.achievement_completed.disconnect(_on_achievement_completed)
	SaveManager.unregister_section(SECTION_ID)


func setup(wheel_service: WheelService) -> void:
	## The wheel that pass tokens are paid into.
	_wheel_service = wheel_service


func claimable_count() -> int:
	return rules.claimable_tiers().size()


func claim(tier: int) -> Dictionary:
	## Collect one pass tier; a non-empty reward has been paid for real.
	var reward := rules.claim(tier)
	if reward.is_empty():
		return {}
	reward = reward.duplicate()
	reward["tier"] = tier
	_pay(reward)
	Telemetry.track(&"pass_claimed", {"tier": tier})
	reward_claimed.emit(reward)
	xp_changed.emit()
	SaveManager.request_save(&"pass")
	return reward


func claim_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tier in rules.claimable_tiers():
		var reward := claim(tier)
		if not reward.is_empty():
			out.append(reward)
	return out


func cash_for(minutes: int) -> float:
	## Minutes of the port as it stands, with a floor so the first crates of a
	## new terminal are not a handful of boxes.
	return maxf(60.0 * float(minutes), GameState.base_cps * 60.0 * float(minutes))


func _pay(reward: Dictionary) -> void:
	var tokens := _as_int(reward.get("tokens", 0), 0)
	if tokens > 0 and _wheel_service != null:
		_wheel_service.grant_token(tokens)
	match StringName(reward.get("kind", &"")):
		&"cash":
			var amount := cash_for(_as_int(reward.get("minutes", 0), 0))
			reward["amount"] = amount
			GameState.grant_nonproductive_reward(amount)
		&"surge":
			GameState.grant_surge(float(reward.get("mult", 1.0)),
				float(reward.get("seconds", 0.0)))


func note_mission() -> void:
	## A daily mission was claimed — Main connects this to
	## `DailyOrdersService.mission_claimed`.
	_add(TerminalLevel.XP_PER_MISSION_CLAIMED)


func _add(amount: int) -> void:
	var before := rules.level
	var gained := rules.add_xp(amount)
	xp_changed.emit()
	if gained > 0:
		# Every level is worth something: +2% production (`GameState`), read
		# through FeatureGate, so the rate has to be recomputed now.
		GameState.recompute()
		var features: Array = []
		for lvl in range(before + 1, rules.level + 1):
			features.append_array(rules.unlocks_at(lvl))
		leveled_up.emit(rules.level, features)
		levels_gained.emit(gained)


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


func _on_achievement_completed(payload: Dictionary) -> void:
	var reward: Dictionary = payload.get("reward", {})
	if String(reward.get("kind", "")) == "xp":
		_add(maxi(0, _as_int(reward.get("amount", 0), 0)))


# -------------------------------------------------------------- persistence

func _restore(data: Dictionary) -> void:
	rules.restore(data)
	GameState.recompute()
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
