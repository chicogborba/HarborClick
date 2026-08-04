class_name SpecialCallDirector
extends RefCounted
## When a special call turns up, which berth it takes, and what it pays.
##
## Rarity is the point. The director offers a charter every few minutes at most,
## never while one is already running, and never before the terminal is warm
## enough for the stake to mean anything. Everything about the offer itself lives
## in `SpecialCallDB`; this is the clock and the state machine.
##
## The flow, and every step of it is refusable or interruptible:
##
##   idle -> offered -> (accepted) -> booked -> alongside -> minigame -> resolved
##                   \- (declined) -> idle, on a shorter cooldown
##
## `booked` is the interesting state: the next call to be seeded at a free berth
## becomes the special one, so the special vessel *arrives* rather than appearing.

signal offer_ready(offer: Dictionary)
signal offer_closed
signal minigame_requested(offer: Dictionary)
signal resolved(offer: Dictionary, won: bool, outcome: Dictionary)

## Real seconds between charters. A rare event that fires twice in a minute is not
## a rare event.
const COOLDOWN := Vector2(240.0, 420.0)
## A refusal costs less than a completed one: the charter goes away, the next one
## comes sooner than it otherwise would.
const DECLINE_COOLDOWN := Vector2(90.0, 150.0)
## An offer nobody answers expires rather than sitting on screen for ever.
const OFFER_TIMEOUT := 30.0
## Below this the port has nothing worth staking, so no charter is offered.
const MIN_LIFETIME_TEUS := 500.0

var world: PortWorld
var offer: Dictionary = {}          # the charter currently on the table
var booked: Dictionary = {}         # accepted, waiting for a berth
var active: Dictionary = {}         # alongside or being played
var active_berth := -1
var _cooldown := 0.0
var _offer_age := 0.0
var _index := 0
var _played := 0
var _won := 0


func setup(p_world: PortWorld) -> void:
	world = p_world
	_cooldown = randf_range(COOLDOWN.x, COOLDOWN.y) * 0.5


func tick(delta: float) -> void:
	if not offer.is_empty():
		_offer_age += delta
		if _offer_age >= OFFER_TIMEOUT:
			decline()
		return
	if not booked.is_empty() or not active.is_empty():
		return
	if GameState.all_time_teus < MIN_LIFETIME_TEUS:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_open_offer()


func _open_offer() -> void:
	offer = SpecialCallDB.materialize(Progression.career_seed, _index)
	if offer.is_empty():
		_cooldown = randf_range(COOLDOWN.x, COOLDOWN.y)
		return
	_index += 1
	_offer_age = 0.0
	offer_ready.emit(offer.duplicate(true))


func accept() -> bool:
	if offer.is_empty():
		return false
	booked = offer.duplicate(true)
	offer = {}
	_offer_age = 0.0
	offer_closed.emit()
	EventBus.notification_requested.emit({
		"id": "special_booked", "kind": &"milestone", "priority": 2,
		"text": "%s aceita. O navio já vem entrando." % booked.get("title", "Escala"),
	})
	return true


func decline() -> void:
	if offer.is_empty():
		return
	offer = {}
	_offer_age = 0.0
	_cooldown = randf_range(DECLINE_COOLDOWN.x, DECLINE_COOLDOWN.y)
	offer_closed.emit()


func claim_variant(berth_index: int) -> Dictionary:
	## Called as a berth seeds its next call. If a charter is booked, this is the
	## call that becomes it, and the hull that turns up is the special one.
	if booked.is_empty() or not active.is_empty():
		return {}
	active = booked
	booked = {}
	active_berth = berth_index
	return ShipCatalog.special_variant(StringName(active.get("hull", "panamax")))


func notify_alongside(berth_index: int) -> void:
	## The special hull has berthed. That is the cue for the minigame, and it is
	## deliberately the *arrival* rather than the acceptance: the player watches the
	## thing they agreed to come up the fairway first.
	if active.is_empty() or berth_index != active_berth:
		return
	if bool(active.get("played", false)):
		return
	active["played"] = true
	minigame_requested.emit(active.duplicate(true))


func resolve(won: bool) -> Dictionary:
	## Pay the prize or take the forfeit, then stand down.
	if active.is_empty():
		return {}
	var finished := active.duplicate(true)
	var outcome := SpecialCallDB.apply_reward(finished) if won \
		else SpecialCallDB.apply_penalty(finished)
	active = {}
	active_berth = -1
	_cooldown = randf_range(COOLDOWN.x, COOLDOWN.y)
	_played += 1
	if won:
		_won += 1
	Progression.ingest_event(&"special_call_finished",
		{"id": finished.get("id", ""), "won": won})
	EventBus.notification_requested.emit({
		"id": "special_result", "kind": &"milestone" if won else &"blocked",
		"priority": 2,
		"text": "%s %s %s" % [finished.get("title", "Escala"),
			"concluída." if won else "perdida.", outcome.get("text", "")],
	})
	resolved.emit(finished, won, outcome)
	return outcome


func abandon() -> void:
	## The vessel left without the game being played — a reload mid-call, a
	## prestige. No prize, no forfeit: nothing happened.
	active = {}
	active_berth = -1
	_cooldown = randf_range(DECLINE_COOLDOWN.x, DECLINE_COOLDOWN.y)


func is_special_berth(berth_index: int) -> bool:
	return not active.is_empty() and berth_index == active_berth


func stats() -> Dictionary:
	return {"played": _played, "won": _won}


# ----------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	return {
		"version": 1,
		"cooldown": _cooldown,
		"index": _index,
		"played": _played,
		"won": _won,
		# An offer on screen is not persisted: it is a live interruption, and one
		# restored into a loading screen would be answered by nobody. A charter
		# already accepted *is* kept, because the player agreed to it.
		"booked": booked.duplicate(true),
		"active": active.duplicate(true),
		"active_berth": active_berth,
	}


func restore(data: Dictionary) -> void:
	_cooldown = maxf(20.0, float(data.get("cooldown", COOLDOWN.x)))
	_index = maxi(0, int(data.get("index", 0)))
	_played = maxi(0, int(data.get("played", 0)))
	_won = maxi(0, int(data.get("won", 0)))
	offer = {}
	_offer_age = 0.0
	booked = _restore_offer(data.get("booked", {}))
	var restored_active := _restore_offer(data.get("active", {}))
	active_berth = int(data.get("active_berth", -1))
	if restored_active.is_empty():
		active = {}
		active_berth = -1
		return
	# A charter caught mid-play comes back as one still to play: the minigame is a
	# single burst of input and half of one cannot be restored honestly.
	restored_active["played"] = false
	active = restored_active


func seed_new() -> void:
	offer = {}
	booked = {}
	active = {}
	active_berth = -1
	_index = 0
	_played = 0
	_won = 0
	_cooldown = randf_range(COOLDOWN.x, COOLDOWN.y) * 0.5


func _restore_offer(raw: Variant) -> Dictionary:
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return {}
	var canonical := SpecialCallDB.get_offer(
		StringName((raw as Dictionary).get("id", "")))
	if canonical.is_empty():
		return {}
	# The catalogue is the authority on goal, timer and payout; the save only says
	# *which* charter it was.
	canonical["index"] = int((raw as Dictionary).get("index", 0))
	return canonical
