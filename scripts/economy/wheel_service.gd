class_name WheelService
extends Node
## The Roda da Sorte as a live node. Owns one `LuckyWheel`, persists it as the
## `lucky_wheel` save section, feeds it ship departures, and is the only place
## a claimed prize touches the economy — the rules themselves never do.
##
## Tokens and the free-spin clock are meta progress, so the section is a
## registered save section like any other and is deliberately NOT re-seeded by
## a prestige: `GameState.do_prestige` resets the run, and only a full profile
## wipe calls `seed_new` on sections.

signal state_changed
signal token_earned
signal prize_applied(prize: Dictionary, amount: float)
## A spin decided a prize (the daily "spin" mission listens to this).
signal spun

const SECTION_ID := &"lucky_wheel"

var wheel: LuckyWheel
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	wheel = LuckyWheel.new()
	_rng.randomize()
	SaveManager.register_section(SECTION_ID, wheel.snapshot, _restore, _seed_new)


func _exit_tree() -> void:
	SaveManager.unregister_section(SECTION_ID)


func spin() -> Dictionary:
	## One spin on the real clock. Returns the decided prize, or {} when the
	## wheel cannot spin right now (nothing ready, or a prize still unclaimed).
	var prize := wheel.spin(Time.get_unix_time_from_system(), _rng)
	if not prize.is_empty():
		spun.emit()
		state_changed.emit()
	return prize


func claim_and_apply() -> Dictionary:
	## Claim the pending prize and apply it to the port. Cash is prize money:
	## `grant_nonproductive_reward` credits the wallet without counting toward
	## prestige. Returns the prize, or {} when there was nothing to claim.
	var prize := wheel.claim()
	if prize.is_empty():
		return {}
	var amount := wheel.prize_amount(prize, GameState.base_cps)
	match StringName(prize.get("kind", &"")):
		&"cash":
			GameState.grant_nonproductive_reward(amount)
		&"surge":
			GameState.grant_surge(float(prize.get("mult", 1.0)),
				float(prize.get("seconds", 0.0)))
		&"token":
			wheel.tokens = mini(wheel.tokens + int(prize.get("tokens", 1)),
				LuckyWheel.MAX_TOKENS)
	prize_applied.emit(prize, amount)
	state_changed.emit()
	return prize


func grant_token(count: int = 1) -> void:
	## A bonus source outside the wheel itself (the golden gull) handing tokens
	## straight to the rack. Capped at `LuckyWheel.MAX_TOKENS`; `token_earned`
	## fires only when a token was actually added, `state_changed` on every
	## grant so the panel and the button refresh either way.
	var before := wheel.tokens
	wheel.tokens = mini(wheel.tokens + maxi(0, count), LuckyWheel.MAX_TOKENS)
	if wheel.tokens > before:
		token_earned.emit()
	state_changed.emit()


func _restore(data: Dictionary) -> void:
	wheel.restore(data)
	state_changed.emit()
	if not wheel.pending.is_empty():
		# A prize decided before the reload is applied now, exactly once —
		# nothing half-happens.
		claim_and_apply.call_deferred()


func _seed_new() -> void:
	wheel.restore(LuckyWheel.seed_new(Time.get_unix_time_from_system()))
	state_changed.emit()
