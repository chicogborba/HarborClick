class_name Hud
extends CanvasLayer
## The readout over the port, in portrait only.
##
## On a wide screen the same numbers live in the command rail instead — a
## second copy floating over the world would just be clutter next to it — so
## this whole layer stands down there. The shared `Readout` control means the
## two are never two implementations.
##
## There is deliberately no panel behind the tally: a 188x48 plate was the
## loudest object on a phone screen and fought the port for attention. A short
## gradient at the top of the viewport buys the same legibility for none of the
## weight.

signal job_tick

var _fade: TextureRect
var _readout: Readout
var _berth_chip: PanelContainer
var _job_label: Label
var _tick := 0.0
var _desktop := false
var _safe_rect := Rect2()


func _ready() -> void:
	layer = 6
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	_fade = UiTheme.top_fade(78.0)
	add_child(_fade)

	_readout = Readout.new()
	_readout.setup(Readout.Style.WORLD)
	add_child(_readout)

	# The berth state is its own chip, outside the tally, so a long status
	# string can never move the counter's geometry.
	_berth_chip = UiTheme.panel(UiTheme.slate_style(false, 3))
	_berth_chip.visible = false
	add_child(_berth_chip)

	# A plain Control deliberately breaks minimum-size propagation. Otherwise a
	# long status string makes PanelContainer wider even with clip_text=true.
	var berth_clip := Control.new()
	berth_clip.name = "Clip"
	berth_clip.clip_contents = true
	berth_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	berth_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	berth_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_chip.add_child(berth_clip)
	_job_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_LIGHT)
	_job_label.clip_text = true
	_job_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	berth_clip.add_child(_job_label)
	_job_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 0.4:
		_tick = 0.0
		job_tick.emit()


func readout_rect() -> Rect2:
	## Where the tally actually is on screen — the tutorial spotlight and the
	## responsive tests both ask for this instead of reaching into a node.
	return _readout.get_global_rect() if _readout != null else Rect2()


func berth_text() -> String:
	return _job_label.text


func set_job_hint(text: String) -> void:
	set_berth_status({"text": text})


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
	_fit_berth_chip()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	_desktop = view.x >= 700.0 and view.x / maxf(view.y, 1.0) >= 1.25
	visible = not _desktop
	_fade.position = Vector2(0, safe.position.y)
	_fade.size = Vector2(view.x, 78.0)
	_readout.position = safe.position + Vector2(8, 6)
	_berth_chip.position = safe.position + Vector2(8, 50)
	_fit_berth_chip()


func set_profile(profile: String) -> void:
	## The shell knows the profile before the viewport ratio settles on mobile,
	## so it is authoritative when supplied.
	if profile.is_empty():
		return
	_desktop = profile == "desktop"
	visible = not _desktop


func _fit_berth_chip() -> void:
	## The chip hugs its text instead of holding a fixed slab: a short phase
	## like "Descarga 8/24" should not paint a bar across the port.
	# The berth can emit one last status while the scene is being torn down —
	# leaving to the menu does exactly that — and by then there is no viewport
	# to measure against.
	if _berth_chip == null or _job_label == null or not is_inside_tree():
		return
	_berth_chip.visible = not _job_label.text.is_empty()
	var safe := _resolved_safe_rect(get_viewport().get_visible_rect().size)
	var text_width := UiTheme.FONT.get_string_size(_job_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
	var width := clampf(text_width + 14.0, 80.0, safe.size.x - 16.0)
	_job_label.custom_minimum_size = Vector2.ZERO
	_berth_chip.size = Vector2(width, 18)
	_berth_chip.custom_minimum_size = _berth_chip.size


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_layout()
	set_profile(str(metrics.get("profile", "")))


func _resolved_safe_rect(view: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return viewport_rect
	var clipped := _safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 \
		else viewport_rect
