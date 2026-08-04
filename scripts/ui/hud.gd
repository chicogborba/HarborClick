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
## Whatever the berth is doing hangs under the bar on its own enamel tag. It is
## the only line of the interface that changes every few seconds, so it is a
## separate object: a status that grows from "Descarga" to a full sentence can
## never move the counter beside it.

signal job_tick

## The gantry's height, and the one number `PortClock` has to agree with. It is
## sized off the instrument it carries: the glass counter plus the panel's lit
## lip and its amber edge.
const BAR_H := 40.0
## Where the tag hangs, measured from the bottom of the bar.
const TAG_DROP := 3.0
## A berth lamp and the space after it.
const PIP_W := 5.0
const PIP_GAP := 2.0

var _bar: PanelContainer
var _readout: Readout
var _berth_chip: PanelContainer
var _berth_clip: Control
var _led: TextureRect
var _job_label: Label
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _pips: Array[TextureRect] = []
var _quay: Array = []
var _progress := -1.0
var _tick := 0.0
var _blink := 0.0
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
	add_child(_readout)

	# The berth state is its own tag, outside the bar, so a long status string
	# can never move the counter's geometry.
	_berth_chip = UiTheme.panel(UiTheme.tag_style(3))
	_berth_chip.visible = false
	add_child(_berth_chip)

	# A plain Control deliberately breaks minimum-size propagation. Otherwise a
	# long status string makes PanelContainer wider even with clip_text=true.
	_berth_clip = Control.new()
	_berth_clip.name = "Clip"
	_berth_clip.clip_contents = true
	_berth_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_berth_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_berth_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_chip.add_child(_berth_clip)

	_led = UiTheme.led(UiTheme.Led.RUNNING)
	_berth_clip.add_child(_led)
	_job_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.STEEL_TEXT)
	_job_label.clip_text = true
	_job_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_berth_clip.add_child(_job_label)

	# Without this the player could watch "Descarga" for a minute with no idea
	# how much of the hull was left. Two rectangles buy that back.
	_progress_bg = ColorRect.new()
	_progress_bg.color = UiTheme.HULL_EDGE
	_progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_clip.add_child(_progress_bg)
	_progress_fill = ColorRect.new()
	_progress_fill.color = UiTheme.DIGIT
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_clip.add_child(_progress_fill)


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 0.4:
		_tick = 0.0
		job_tick.emit()
	# A berth that pays for a tap blinks; one that is just running holds steady.
	# It is the only thing on the bar that moves on its own, which is what makes
	# it worth looking at.
	if _progress >= 0.0 and UserPreferences.can_animate():
		_blink = fmod(_blink + delta, 1.4)
		_led.texture = UiTheme.led_texture(UiTheme.Led.ATTENTION
			if _blink < 0.95 else UiTheme.Led.RUNNING)


func readout_rect() -> Rect2:
	## Where the tally actually is on screen — the tutorial spotlight and the
	## responsive tests both ask for this instead of reaching into a node.
	return _readout.get_global_rect() if _readout != null else Rect2()


func bar_rect() -> Rect2:
	return _bar.get_global_rect() if _bar != null else Rect2()


func berth_text() -> String:
	return _job_label.text


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
	while _pips.size() < _quay.size():
		var pip := UiTheme.led(UiTheme.Led.OFF)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_berth_clip.add_child(pip)
		_pips.append(pip)
	for index in _pips.size():
		_pips[index].visible = _quay.size() > 1 and index < _quay.size()
	_fit_berth_chip()


func set_berth_status(status: Dictionary) -> void:
	## Public structured entry point for berth controllers. Common forms:
	## {text}, {phase, current, total}, or {label, progress}.
	var supplied_text := status.has("text") or status.has("label")
	var text := str(status.get("text", status.get("label", status.get("phase", ""))))
	var current: Variant = status.get("current", status.get("progress", null))
	var total: Variant = status.get("total", null)
	if not supplied_text and current != null and total != null:
		text += " %s/%s" % [current, total]
	_job_label.text = text
	# A hull under the cranes is the one state where a tap is worth something, and
	# it is exactly the state that reports a total. Nothing else has to be told.
	_progress = -1.0
	if current != null and total != null and float(total) > 0.0:
		_progress = clampf(float(current) / float(total), 0.0, 1.0)
	_led.texture = UiTheme.led_texture(
		UiTheme.Led.ATTENTION if _progress >= 0.0 else UiTheme.Led.RUNNING)
	# Described here rather than in the layout pass: the tag is re-fitted on every
	# resize and every profile change, and rewriting the accessibility tree for a
	# string that has not changed is noise a screen reader has to sit through.
	UiTheme.describe(_berth_chip, "Estado do berço", text)
	_fit_berth_chip()


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
	_fit_berth_chip()


func _fit_berth_chip() -> void:
	## The tag hugs its text instead of holding a fixed slab: a short phase like
	## "Descarga 8/24" should not paint a bar across the port.
	# The berth can emit one last status while the scene is being torn down —
	# leaving to the menu does exactly that — and by then there is no viewport
	# to measure against.
	if _berth_chip == null or _job_label == null or not is_inside_tree():
		return
	_berth_chip.visible = not _job_label.text.is_empty()
	if not _berth_chip.visible:
		return
	var area := _resolved_world_rect(get_viewport().get_visible_rect().size)
	var text_width := UiTheme.FONT.get_string_size(_job_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
	var lamp := _led.custom_minimum_size.x + 4.0
	var pips := _pip_strip_width()
	var width := clampf(text_width + lamp + pips + 20.0, 96.0, area.size.x - 12.0)
	var rows := 12.0 + (5.0 if _progress >= 0.0 else 0.0)
	_job_label.custom_minimum_size = Vector2.ZERO
	_berth_chip.size = Vector2(width, rows + 6.0)
	_berth_chip.custom_minimum_size = _berth_chip.size
	_berth_chip.position = Vector2(area.position.x + 6.0,
		area.position.y + BAR_H + TAG_DROP)

	# The chip's own content rect is only known after the panel has been sized,
	# so the tag's insides are placed against it rather than anchored.
	var inner := Vector2(width - 10.0, rows)
	_led.position = Vector2(0.0, floorf((12.0 - _led.custom_minimum_size.y) * 0.5))
	_job_label.position = Vector2(lamp, 0.0)
	_job_label.size = Vector2(maxf(0.0, inner.x - lamp - pips), 12.0)
	_place_pips(inner)
	_progress_bg.visible = _progress >= 0.0
	_progress_fill.visible = _progress >= 0.0
	if _progress >= 0.0:
		_progress_bg.position = Vector2(lamp, 14.0)
		_progress_bg.size = Vector2(maxf(0.0, inner.x - lamp), 3.0)
		_progress_fill.position = _progress_bg.position
		_progress_fill.size = Vector2(_progress_bg.size.x * _progress, 3.0)


func _pip_strip_width() -> float:
	if _quay.size() < 2:
		return 0.0
	return float(_quay.size()) * (PIP_W + PIP_GAP) + 2.0


func _place_pips(inner: Vector2) -> void:
	## Right-aligned on the tag's own line, so growing the status text pushes the
	## text's own ellipsis rather than the lamps.
	if _quay.size() < 2:
		return
	var x := inner.x - _pip_strip_width() + 2.0
	for index in _quay.size():
		var berth: Dictionary = _quay[index]
		var pip := _pips[index]
		# Lit under the cranes, dim when the berth is empty. The one the tag is
		# describing is the brighter of the two states it could be in, which is
		# the only distinction a 5px lamp can carry honestly.
		var working := bool(berth.get("working", false))
		pip.texture = UiTheme.led_texture(UiTheme.Led.ATTENTION if working \
			else UiTheme.Led.RUNNING if bool(berth.get("focused", false)) \
			else UiTheme.Led.OFF)
		pip.position = Vector2(x, floorf((12.0 - pip.custom_minimum_size.y) * 0.5))
		x += PIP_W + PIP_GAP


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
