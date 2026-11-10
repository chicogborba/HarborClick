class_name BuildHud
extends CanvasLayer
## The works, as they happen: one row per build in progress.
##
## A row is the machine's name, a bar, the seconds left and — when an
## advertisement is allowed to skip the wait — a film-frame key for it. Tapping
## the row itself hurries the build a second a tap, so waiting is something the
## player can do with their hands. Rows are built once (three of them: two being
## worked and one waiting) and rewritten in place; a build that finishes simply
## stops being drawn.

const ROWS := 3
const WIDTH := 150.0

var _column: VBoxContainer
var _rows: Array[Dictionary] = []
var _safe_rect := Rect2()
var _world_rect := Rect2()
var _tick := 0.0


func _ready() -> void:
	layer = 7
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 3)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	for i in ROWS:
		_rows.append(_build_row(i))
	refresh()
	_layout()


func _build_row(index: int) -> Dictionary:
	var panel := UiTheme.panel(UiTheme.tag_style(3), false)
	panel.custom_minimum_size = Vector2(WIDTH, 30.0)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_row_input.bind(index))
	_column.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(UiTheme.icon16(UiTheme.Icon16.BUILD))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text)
	var name := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.CREAM)
	name.clip_text = true
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name)
	var bar := ProgressBar.new()
	var styles := UiTheme.bar_styles()
	bar.add_theme_stylebox_override(&"background", styles[0])
	bar.add_theme_stylebox_override(&"fill", styles[1])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(40.0, 7.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(bar)
	var left := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	left.custom_minimum_size.x = 28.0
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(left)
	var ad := UiTheme.icon_button(UiTheme.Icon.CHEVRON, &"amber", 28.0,
		Loc.t("build.speed_up"))
	ad.icon = UiTheme.icon16_texture(UiTheme.Icon16.AD)
	ad.pressed.connect(_on_ad.bind(index))
	box.add_child(ad)
	return {"panel": panel, "name": name, "bar": bar, "left": left, "ad": ad}


func refresh() -> void:
	if _rows.is_empty():
		return
	var queue := GameState.builds
	for i in ROWS:
		var row: Dictionary = _rows[i]
		var on := i < queue.size()
		(row.panel as Control).visible = on
		if not on:
			continue
		var b: Dictionary = queue[i]
		var working := i < BuildQueue.MAX_ACTIVE
		var item := StructureDB.get_item(str(b.id))
		var title := str(item.get("name", b.id))
		(row.name as Label).text = "%s x%d" % [title, int(b.qty)] if int(b.qty) > 1 else title
		var bar: ProgressBar = row.bar
		bar.max_value = maxf(0.1, float(b.total))
		bar.value = clampf(float(b.total) - float(b.left), 0.0, bar.max_value)
		(row.left as Label).text = _clock(float(b.left)) if working else "..."
		var ad: Button = row.ad
		ad.visible = working and AdService.available(&"build_speed")
	_layout()


static func _clock(seconds: float) -> String:
	var s := ceili(seconds)
	return "%ds" % s if s < 60 else "%d:%02d" % [s / 60, s % 60]


func _on_row_input(event: InputEvent, index: int) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		GameState.tap_build(index, 1.0)
		AudioManager.play_sfx("tap", 0.08, -6.0)
		refresh()


func _on_ad(index: int) -> void:
	# Rows shift as builds finish, so the ad is bound to the build, not the slot.
	if index >= GameState.builds.size():
		return
	var target: Dictionary = GameState.builds[index]
	AdService.show_rewarded(&"build_speed", func() -> void:
		var at := GameState.builds.find(target)
		if at >= 0:
			GameState.finish_build(at))


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.2:
		_tick = 0.0
		refresh()


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_world_rect = metrics.get("world_rect", _safe_rect)
	_layout()


func _layout() -> void:
	if _column == null or not is_instance_valid(_column):
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	var area := safe
	if _world_rect.size.x > 0.0 and _world_rect.size.y > 0.0:
		var inside := _world_rect.intersection(safe)
		if inside.size.x > 0.0 and inside.size.y > 0.0:
			area = inside
	_column.reset_size()
	# Under the boost chips, hung from the right edge.
	_column.position = Vector2(area.end.x - _column.size.x - 6.0,
		area.position.y + Hud.BAR_H + 4.0 + 26.0).round()
