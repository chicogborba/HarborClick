class_name LevelHud
extends CanvasLayer
## The terminal's level, and the moment it grows.
##
## A small badge under the gantry (the level, and a bar to the next one) answers
## "am I getting anywhere" at a glance; and when a level opens something — a tab,
## a key, a skill — a card drops in from the top naming it, so the new thing is
## announced instead of simply appearing. Built once, rewritten in place.

const FEATURE_NAMES := {
	&"objective": "level.feature.objective", &"upgrades": "level.feature.upgrades",
	&"daily": "level.feature.daily",
	&"land": "level.feature.land",
	&"gull": "level.feature.gull", &"wheel": "level.feature.wheel",
	&"journal": "level.feature.journal", &"routes": "level.feature.routes",
	&"charters": "level.feature.charters",
	&"decor": "level.feature.decor", &"orders": "level.feature.orders",
	&"prestige": "level.feature.prestige",
}

var _service: TerminalLevelService
var _badge: PanelContainer
var _level_label: Label
var _bar: ProgressBar
var _card: PanelContainer
var _card_title: Label
var _card_text: Label
var _queue: Array[Array] = []
var _showing := false
var _safe_rect := Rect2()
var _world_rect := Rect2()


func _ready() -> void:
	layer = 9
	_badge = UiTheme.panel(UiTheme.tag_style(3))
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(box)
	box.add_child(UiTheme.icon16(UiTheme.Icon16.LEVEL))
	_level_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_level_label)
	_bar = ProgressBar.new()
	var styles := UiTheme.bar_styles()
	_bar.add_theme_stylebox_override(&"background", styles[0])
	_bar.add_theme_stylebox_override(&"fill", styles[1])
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(42.0, 7.0)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar)
	add_child(_badge)

	_card = UiTheme.panel(UiTheme.board_style(8), false)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	_card_title = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.TEAL_DEEP)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_title)
	_card_text = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.INK)
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.clip_text = true
	col.add_child(_card_text)
	add_child(_card)
	refresh()
	_layout()


func setup(service: TerminalLevelService) -> void:
	_service = service
	if _service != null:
		if not _service.xp_changed.is_connected(refresh):
			_service.xp_changed.connect(refresh)
		if not _service.leveled_up.is_connected(_on_leveled_up):
			_service.leveled_up.connect(_on_leveled_up)
	refresh()


func refresh() -> void:
	if _service == null or _service.rules == null or _level_label == null:
		return
	_level_label.text = Loc.t("level.short", {"n": str(_service.rules.level)})
	_bar.value = _service.rules.progress_to_next()
	_layout()


func _on_leveled_up(level: int, features: Array) -> void:
	Telemetry.track(&"level_up", {"level": level, "day": TimeManager.day})
	# Several levels at once (a long absence, a legacy save) queue up one by one.
	_queue.append([level, features])
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var entry: Array = _queue.pop_front()
	var features: Array = entry[1]
	var names := PackedStringArray()
	for f in features:
		if FEATURE_NAMES.has(f):
			names.append(Loc.t(str(FEATURE_NAMES[f])))
	if names.is_empty():
		# A level that opens nothing is just a number on the badge.
		_show_next()
		return
	_card_title.text = Loc.t("level.up", {"n": str(entry[0])})
	_card_text.text = ", ".join(names)
	_card.visible = true
	_layout()
	AudioManager.play_sfx("achievement", 0.0, -3.0)
	Fx.haptic(30)
	if not UserPreferences.can_animate():
		_card.modulate.a = 1.0
		get_tree().create_timer(2.6).timeout.connect(_hide_card)
		return
	var home := _card.position
	_card.position = home - Vector2(0.0, 24.0)
	_card.modulate.a = 0.0
	var tween := _card.create_tween()
	tween.tween_property(_card, "position", home, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.15)
	tween.tween_interval(2.4)
	tween.tween_property(_card, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_hide_card)


func _hide_card() -> void:
	_card.visible = false
	_card.modulate.a = 1.0
	_show_next()


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_world_rect = metrics.get("world_rect", _safe_rect)
	_layout()


func _layout() -> void:
	if _badge == null or not is_instance_valid(_badge):
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	var area := safe
	if _world_rect.size.x > 0.0 and _world_rect.size.y > 0.0:
		var inside := _world_rect.intersection(safe)
		if inside.size.x > 0.0 and inside.size.y > 0.0:
			area = inside
	_badge.reset_size()
	_badge.position = (area.position + Vector2(6.0, Hud.BAR_H + 4.0)).round()
	_card.size = Vector2(minf(280.0, area.size.x - 24.0), 0.0)
	_card.reset_size()
	if not _card.visible or _card.get_tree() == null or _card.get_tree().get_processed_tweens().is_empty():
		_card.position = Vector2(area.position.x + (area.size.x - _card.size.x) * 0.5,
			area.position.y + Hud.BAR_H + 40.0).round()
