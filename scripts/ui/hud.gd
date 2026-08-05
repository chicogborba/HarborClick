class_name Hud
extends CanvasLayer
## The gantry across the top of the port: the tally, the clock and the berth.
##
## A signal gantry is the one piece of structure a container terminal actually
## has spanning the quay, so that is what the permanent readout is built as — a
## navy enamel panel bolted across the top of the world with instruments set
## into it. It replaced a tally of bare outlined text floating on a gradient,
## which had no edges, no material and nothing holding it to the port.
##
## The bar frames the world rather than the window. `PortClock` mounts its dial
## into the right-hand end of this same bar; `Hud.BAR_H` is the contract between
## them.
##
## The berth tag is gone. It hung under the gantry restating what the port was
## already showing — "Descarga: toque no navio" over a ship visibly being worked
## by cranes — and it cost a strip of screen on a phone to do it. The berth state
## still travels through `set_berth_status`, because the accessibility tree and
## the tests read it, but nothing draws it. What the berth is doing is the ship.

signal job_tick
## Forwarded from the rate tag: the player asked what the number is made of.
signal breakdown_requested

## The gantry's height, and the one number `PortClock` has to agree with. It is
## sized off the instrument it carries: the glass counter plus the panel's lit
## lip and its amber edge.
const BAR_H := 40.0
## Width the clock and the notice bell own at the right-hand end of the bar. The
## tally is clamped to what is left, so the two instruments can never overlap.
const CLOCK_RESERVE := 96.0
var _bar: PanelContainer
var _readout: Readout
var _quay: Array = []
var _berth_text := ""
var _progress := -1.0
var _tick := 0.0
var _safe_rect := Rect2()
var _world_rect := Rect2()


func _ready() -> void:
	layer = 6
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	_bar = UiTheme.panel(UiTheme.gantry_style())
	add_child(_bar)

	_readout = Readout.new()
	_readout.setup()
	_readout.breakdown_requested.connect(func() -> void: breakdown_requested.emit())
	add_child(_readout)


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 0.4:
		_tick = 0.0
		job_tick.emit()


func readout_rect() -> Rect2:
	## Where the tally actually is on screen — the tutorial spotlight and the
	## responsive tests both ask for this instead of reaching into a node.
	return _readout.get_global_rect() if _readout != null else Rect2()


func bar_rect() -> Rect2:
	return _bar.get_global_rect() if _bar != null else Rect2()


func berth_text() -> String:
	## State, not a widget. Nothing draws this any more.
	return _berth_text


func berth_progress() -> float:
	## 0..1 while a hull is being worked, -1 otherwise.
	return _progress


func set_job_hint(text: String) -> void:
	set_berth_status({"text": text})


func set_quay(quay: Array) -> void:
	## One lamp per berth, lit for the ones under the cranes and outlined for the
	## one the tag is talking about.
	##
	## A second and third ship were invisible on a phone: the tag names its own
	## berth, but nothing said how many others existed, so a player with three
	## hulls alongside had no reason to believe there was more than the one they
	## were tapping. Below two berths this draws nothing — a single lamp beside a
	## line about the only berth there is says nothing at all.
	_quay = quay.duplicate(true)


func set_berth_status(status: Dictionary) -> void:
	## Public structured entry point for berth controllers. Common forms:
	## {text}, {phase, current, total}, or {label, progress}.
	var supplied_text := status.has("text") or status.has("label")
	var text := str(status.get("text", status.get("label", status.get("phase", ""))))
	var current: Variant = status.get("current", status.get("progress", null))
	var total: Variant = status.get("total", null)
	if not supplied_text and current != null and total != null:
		text += " %s/%s" % [current, total]
	_berth_text = text.strip_edges()
	_progress = -1.0
	if current != null and total != null and float(total) > 0.0:
		_progress = clampf(float(current) / float(total), 0.0, 1.0)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var area := _resolved_world_rect(view)
	_bar.position = area.position
	_bar.size = Vector2(area.size.x, BAR_H)
	var height := _readout.get_combined_minimum_size().y
	# Centred in the panel's face, not in its full height: the amber hairline and
	# the shadow under it are the panel's edge, not room for an instrument.
	_readout.position = Vector2(area.position.x + 7.0,
		area.position.y + floorf((BAR_H - 4.0 - height) * 0.5))
	# Hard stop before the clock. The tally is a fixed window but the rate tag
	# beside it grows with its text, and the clock is anchored to the far end of
	# the same bar — without a ceiling the two drew on top of each other.
	_readout.set_width_budget(maxf(60.0, area.size.x - CLOCK_RESERVE - 14.0))


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_world_rect = metrics.get("world_rect", _safe_rect)
	_layout()


func _resolved_world_rect(view: Vector2) -> Rect2:
	## The bar belongs to the port, not to the window, so an inset on the world
	## rect moves the gantry with it rather than leaving it spanning the glass.
	var viewport_rect := Rect2(Vector2.ZERO, view)
	var safe := _safe_rect.intersection(viewport_rect) if _safe_rect.size.x > 0.0 \
		and _safe_rect.size.y > 0.0 else viewport_rect
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = viewport_rect
	if _world_rect.size.x <= 0.0 or _world_rect.size.y <= 0.0:
		return safe
	var world := _world_rect.intersection(safe)
	return world if world.size.x > 0.0 and world.size.y > 0.0 else safe
