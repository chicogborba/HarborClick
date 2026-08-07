class_name NotificationCoordinator
extends Node
## One place decides whether something deserves the player's attention.
##
## Before this, every system emitted straight into ToastLayer: the berth's
## phase changes, the cat, the tutorial, milestones and blocking errors all
## produced the same banner, so up to three big strips could stack over the
## port and a routine "navio se aproximando" competed with a career milestone.
##
## The policy here is deliberately small and testable:
##
## - **Routine state is not news.** Anything already visible somewhere on the
##   HUD — berth phase, ship arrival — is recorded and dropped. The berth chip
##   is the display for that.
## - **Repeats collapse.** The same `id` inside `DEDUPE_WINDOW` bumps a counter
##   instead of queueing again, so a blocked yard tapped ten times says
##   "x10" once.
## - **One at a time, and never faster than `MIN_SPACING`.** Higher priority
##   jumps the queue; equal priority is first come.
## - **Everything is kept.** Dropped, collapsed and shown alike land in the
##   history, which is what the Port Journal reads.

signal presented(notice: Dictionary)
signal history_changed

## Kinds that already have a permanent home on screen.
const ROUTINE_KINDS: Array[StringName] = [&"berth", &"phase", &"arrival", &"status"]
const DEDUPE_WINDOW := 8.0
const MIN_SPACING := 1.0
const HISTORY_MAX := 60

const ICONS := {
	&"milestone": UiTheme.Icon.TROPHY,
	&"unlock": UiTheme.Icon.LAND,
	&"prestige": UiTheme.Icon.STAR,
	&"blocked": UiTheme.Icon.LOCK,
	# The branch runs along the bottom of the world with nothing on the HUD
	# standing for it, so a rail notice is the only thing that says a service is
	# happening at all — it is news, not routine state.
	&"rail": UiTheme.Icon.TRAIN,
	&"cat": UiTheme.Icon.PAW,
	&"crew": UiTheme.Icon.GLOVE,
	&"tutorial": UiTheme.Icon.CHECK,
}

var history: Array[Dictionary] = []

var _queue: Array[Dictionary] = []
var _recent: Dictionary = {}          # id -> {at, notice}
var _showing := false
var _last_presented_at := -MIN_SPACING
var _clock := 0.0


func _ready() -> void:
	EventBus.notification_requested.connect(submit)
	EventBus.toast.connect(_submit_plain)


func _process(delta: float) -> void:
	_clock += delta
	_pump()


func submit(payload: Dictionary) -> Dictionary:
	## Returns the normalised notice, so callers and tests can see what the
	## policy decided without watching the screen.
	var notice := _normalise(payload)
	if notice.text.is_empty():
		return notice
	notice["at"] = _clock
	if ROUTINE_KINDS.has(StringName(notice.kind)):
		notice["outcome"] = &"routine"
		_record(notice)
		return notice
	var previous: Dictionary = _recent.get(notice.id, {})
	if not previous.is_empty() and _clock - float(previous.at) <= DEDUPE_WINDOW:
		previous["count"] = int(previous.get("count", 1)) + 1
		previous["at"] = _clock
		notice["outcome"] = &"collapsed"
		notice["count"] = previous.count
		_record(notice)
		return notice
	notice["count"] = 1
	_recent[notice.id] = notice
	notice["outcome"] = &"queued"
	_insert(notice)
	_record(notice)
	_pump()
	return notice


func notify_shown_finished() -> void:
	## ToastLayer calls this when its banner has gone, freeing the next slot.
	_showing = false
	_pump()


func clear() -> void:
	_queue.clear()
	_recent.clear()
	history.clear()
	_showing = false


func _submit_plain(text: String) -> void:
	submit({"text": text})


func _normalise(payload: Dictionary) -> Dictionary:
	var kind := StringName(payload.get("kind", payload.get("type", &"info")))
	var text := str(payload.get("text", ""))
	return {
		"id": StringName(payload.get("id", "%s:%s" % [kind, text])),
		"kind": kind,
		"priority": int(payload.get("priority", 0)),
		"text": text,
		"icon": payload.get("icon", ICONS.get(kind, UiTheme.Icon.TEU)),
		"duration": float(payload.get("duration", 3.2)),
		"action": payload.get("action", ""),
	}


func _insert(notice: Dictionary) -> void:
	var at := _queue.size()
	for i in _queue.size():
		if int(_queue[i].priority) < int(notice.priority):
			at = i
			break
	_queue.insert(at, notice)


func _pump() -> void:
	if _showing or _queue.is_empty():
		return
	if _clock - _last_presented_at < MIN_SPACING:
		return
	var notice: Dictionary = _queue.pop_front()
	_showing = true
	_last_presented_at = _clock
	presented.emit(notice)


func _record(notice: Dictionary) -> void:
	history.push_front(notice.duplicate(true))
	while history.size() > HISTORY_MAX:
		history.pop_back()
	history_changed.emit()
