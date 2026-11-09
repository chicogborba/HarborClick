class_name DailyOrdersService
extends Node
## Missões do Dia as a live node. Owns one `DailyOrders`, persists it as the
## `daily_orders` save section, feeds it the EventBus counters the missions
## watch, and is the only place a claimed reward touches the wheel or the port —
## the rules themselves never do.
##
## The streak is meta progress, like the wheel's tokens: the section is a
## registered save section like any other and is deliberately NOT re-seeded by
## a prestige — `GameState.do_prestige` resets the run, and only a full profile
## wipe calls `seed_new` on sections.

signal state_changed

const SECTION_ID := &"daily_orders"
## The day is re-checked once a minute, so a session that crosses midnight
## rolls over without waiting for the next event.
const DAY_CHECK_SECONDS := 60.0

var orders: DailyOrders
var _wheel_service: WheelService
var _day: int = 0
var _day_timer: Timer


func _ready() -> void:
	orders = DailyOrders.new()
	_day = _current_day()
	SaveManager.register_section(SECTION_ID, orders.snapshot, _restore, _seed_new)
	orders.roll_day(_day)
	EventBus.cargo_transfer_committed.connect(_on_cargo_transfer_committed)
	EventBus.manual_reward_committed.connect(_on_manual_reward_committed)
	EventBus.ship_departed.connect(_on_ship_departed)
	EventBus.structure_purchase_committed.connect(_on_structure_purchase)
	EventBus.upgrade_bought.connect(_on_upgrade_bought)
	_day_timer = Timer.new()
	_day_timer.wait_time = DAY_CHECK_SECONDS
	_day_timer.timeout.connect(_on_day_timer)
	add_child(_day_timer)
	_day_timer.start()


func _exit_tree() -> void:
	EventBus.cargo_transfer_committed.disconnect(_on_cargo_transfer_committed)
	EventBus.manual_reward_committed.disconnect(_on_manual_reward_committed)
	EventBus.ship_departed.disconnect(_on_ship_departed)
	EventBus.structure_purchase_committed.disconnect(_on_structure_purchase)
	EventBus.upgrade_bought.disconnect(_on_upgrade_bought)
	SaveManager.unregister_section(SECTION_ID)


func setup(wheel_service: WheelService) -> void:
	## The wheel that mission tokens are paid into.
	_wheel_service = wheel_service


func note_spin() -> void:
	## The wheel spun and a prize was decided — Main calls this off
	## `WheelService.spun`.
	_note(&"spin", 1)


func note_gull() -> void:
	## A golden gull was caught — Main calls this off
	## `PortWorld.golden_gull_caught`.
	_note(&"gull", 1)


func claim(index: int) -> Dictionary:
	## Claim mission `index` on today; a non-empty reward is applied for real.
	var reward := orders.claim(index, _current_day())
	if not reward.is_empty():
		_apply_reward(reward)
		state_changed.emit()
	return reward


func claim_bonus() -> Dictionary:
	## Claim the all-three bonus on today; same reward path as `claim`.
	var reward := orders.claim_bonus(_current_day())
	if not reward.is_empty():
		_apply_reward(reward)
		state_changed.emit()
	return reward


func _note(event: StringName, amount: int) -> void:
	orders.note(event, amount, _current_day())
	state_changed.emit()


func _apply_reward(reward: Dictionary) -> void:
	## Tokens go to the wheel's rack, the surge to the port.
	var tokens := _as_int(reward.get("tokens", 0), 0)
	if tokens > 0 and _wheel_service != null:
		_wheel_service.grant_token(tokens)
	if reward.has("surge_mult"):
		GameState.grant_surge(float(reward.get("surge_mult", 1.0)),
			float(reward.get("surge_seconds", 0.0)))


# ------------------------------------------------------------- event wiring

func _on_cargo_transfer_committed(_payload: Dictionary) -> void:
	## One committed cargo transfer — ship, road or rail.
	_note(&"transfer", 1)


func _on_manual_reward_committed(_payload: Dictionary) -> void:
	_note(&"tap", 1)


func _on_ship_departed() -> void:
	_note(&"ship", 1)


func _on_structure_purchase(quote: Dictionary) -> void:
	## Units actually bought, from the committed quote. `structure_bought`
	## carries the machine's *total* owned, which would have finished "buy ten
	## machines" with one tap for any port that already ran a fleet.
	_note(&"machine", maxi(1, _as_int(quote.get("quantity", 1), 1)))


func _on_upgrade_bought(_id: String) -> void:
	_note(&"upgrade", 1)


func _on_day_timer() -> void:
	var today := _current_day()
	if today != _day:
		_day = today
		orders.roll_day(today)
		state_changed.emit()


func _current_day() -> int:
	## The local calendar day. The zone bias comes from the system, so the rules
	## in `DailyOrders` never need a clock of their own.
	var bias_seconds := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return DailyOrders.day_key(Time.get_unix_time_from_system(), bias_seconds)


func _restore(data: Dictionary) -> void:
	orders.restore(data)
	orders.roll_day(_current_day())
	state_changed.emit()


func _seed_new() -> void:
	orders.restore(DailyOrders.seed_new(_current_day()))
	state_changed.emit()


static func _as_int(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and (raw as String).is_valid_int():
		return (raw as String).to_int()
	return fallback
