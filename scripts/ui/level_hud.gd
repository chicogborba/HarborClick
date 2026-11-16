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
	&"decor": "level.feature.decor",
	&"prestige": "level.feature.prestige",
}

## Inside width of the card in px; the labels wrap to it.
const CARD_INNER := 220.0
## The medal, its light and its ribbon are laid out in this box.
const STAGE_SIZE := Vector2(240, 196)
## From this level on the card offers a rewarded bonus. The first levels land in
## the first minutes: a new player is shown the game, not an ad.
const AD_FROM_LEVEL := 3

## The badge is a key: pressing it opens the level roadmap.
signal roadmap_requested

var _service: TerminalLevelService
var _badge: PanelContainer
var _level_label: Label
var _bar: ProgressBar
## Lit while a pass tier is waiting to be collected.
var _pip: TextureRect
## The level-up moment: light, medal, ribbon, and a paper tag of what opened.
var _stage: Control
var _rays: TextureRect
var _medal: Control
var _medal_number: Label
var _ribbon: PanelContainer
var _ribbon_text: Label
var _confetti: _Confetti
var _card: PanelContainer
var _card_title: Label
var _card_text: Label
var _card_reward: Label
var _card_ad: Button
var _card_tween: Tween
var _card_level := 1
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
	_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_badge.tooltip_text = Loc.t("roadmap.title")
	_badge.gui_input.connect(func(event: InputEvent) -> void:
		var released: bool = (event is InputEventMouseButton and not event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and not event.pressed)
		if released:
			AudioManager.play_sfx("tap")
			roadmap_requested.emit())
	add_child(_badge)
	_pip = UiTheme.pip()
	_pip.visible = false
	add_child(_pip)

	# --- the moment itself: a medal on a sunburst, a ribbon under it ---
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.visible = false
	_stage.size = STAGE_SIZE
	_stage.pivot_offset = STAGE_SIZE * 0.5
	add_child(_stage)
	_rays = _sprite(preload("res://assets/sprites/ui_levelup_rays.png"), 2)
	_rays.position = (STAGE_SIZE - _rays.size) * 0.5 + Vector2(0, -18)
	_rays.pivot_offset = _rays.size * 0.5
	_rays.modulate = Color(1.0, 0.92, 0.7, 0.0)
	_stage.add_child(_rays)
	_confetti = _Confetti.new()
	_confetti.position = STAGE_SIZE * 0.5 + Vector2(0, -18)
	_stage.add_child(_confetti)
	_medal = Control.new()
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shield := _sprite(preload("res://assets/sprites/ui_levelup_shield.png"), 2)
	_medal.size = shield.size
	_medal.pivot_offset = shield.size * 0.5
	_medal.position = (STAGE_SIZE - shield.size) * 0.5 + Vector2(0, -18)
	_medal.add_child(shield)
	# The number on the navy field, under the star: the biggest thing on screen.
	_medal_number = UiTheme.label("", UiTheme.SIZE_HUGE, UiTheme.CREAM)
	_medal_number.label_settings = UiTheme.settings(UiTheme.SIZE_HUGE * 2, UiTheme.CREAM,
		4, UiTheme.HULL_EDGE)
	_medal_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_medal_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_medal_number.position = Vector2(0, 46)
	_medal_number.size = Vector2(shield.size.x, 64)
	_medal.add_child(_medal_number)
	_stage.add_child(_medal)
	# The band tiles between its rolled tails; top and bottom are the hem.
	var ribbon_style := UiTheme.nine("ui_levelup_ribbon", 9, 0)
	ribbon_style.texture_margin_top = 4
	ribbon_style.texture_margin_bottom = 6
	ribbon_style.content_margin_left = 18
	ribbon_style.content_margin_right = 18
	ribbon_style.content_margin_top = 4
	ribbon_style.content_margin_bottom = 8
	_ribbon = UiTheme.panel(ribbon_style, false)
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon_text = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.CREAM)
	_ribbon_text.label_settings = UiTheme.settings(UiTheme.SIZE_TITLE, UiTheme.CREAM,
		2, Color8(92, 30, 34))
	_ribbon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ribbon.add_child(_ribbon_text)
	_stage.add_child(_ribbon)

	# --- what the level opened, on a paper tag hung under the ribbon ---
	_card = UiTheme.panel(UiTheme.board_style(6), false)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	_card_title = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.visible = false
	col.add_child(_card_title)
	# Wrapped, never clipped: a long feature name or a longer translation must
	# grow the card, not lose its ends. The label's width is the card's inside.
	_card_text = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size.x = CARD_INNER
	col.add_child(_card_text)
	_card_reward = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.AMBER_DEEP)
	_card_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_reward.custom_minimum_size.x = CARD_INNER
	col.add_child(_card_reward)
	_card_ad = UiTheme.button("", &"amber", UiTheme.SIZE_SMALL)
	_card_ad.icon = UiTheme.icon16_texture(UiTheme.Icon16.AD)
	_card_ad.visible = false
	_card_ad.pressed.connect(_on_ad_pressed)
	col.add_child(_card_ad)
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
	_pip.visible = _service.claimable_count() > 0
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
	for item: Dictionary in CosmeticDb.at_level(int(entry[0])):
		names.append(str(item.name))
	# Every level pays, so every level gets its card: what it opened (or a word
	# from the crew when it opened nothing) and the bonus every level carries.
	_card_level = int(entry[0])
	_card_title.text = Loc.t("level.up", {"n": str(_card_level)})
	_medal_number.text = str(_card_level)
	_ribbon_text.text = Loc.t("level.banner")
	UiTheme.describe(_stage, Loc.t("level.up", {"n": str(_card_level)}), "")
	if names.is_empty():
		_card_text.text = Loc.t("level.flavor.%d" % (1 + _card_level % 3))
	else:
		_card_text.text = Loc.t("level.new", {"names": ", ".join(names)})
	_card_reward.text = Loc.t("level.reward")
	# One offer per card, on the last of a queued batch, and only when the ad
	# service would show it: the card never advertises what cannot play.
	var minutes := _bonus_seconds(_card_level) / 60
	var offer := _queue.is_empty() and _card_level >= AD_FROM_LEVEL \
		and AdService.available(&"level_bonus")
	_card_ad.visible = offer
	_card_ad.text = Loc.t("level.ad", {"min": str(minutes)})
	_card_ad.accessibility_name = _card_ad.text
	_card.mouse_filter = Control.MOUSE_FILTER_PASS if offer else Control.MOUSE_FILTER_IGNORE
	_stage.visible = true
	_card.visible = true
	_layout()
	AudioManager.play_sfx("achievement", 0.0, -3.0)
	Fx.haptic(30)
	var hold := 6.5 if offer else 3.0
	if _card_tween != null:
		_card_tween.kill()
	_stage.modulate.a = 1.0
	_card.modulate.a = 1.0
	if not UserPreferences.can_animate():
		_rays.modulate.a = 0.55
		_medal.scale = Vector2.ONE
		_ribbon.scale = Vector2.ONE
		_card_tween = _card.create_tween()
		_card_tween.tween_interval(hold + 0.4)
		_card_tween.tween_callback(_hide_card)
		return
	# The medal is struck: it slams in oversized and settles, the light opens
	# behind it, the ribbon unrolls across it, confetti, then the tag drops.
	_medal.scale = Vector2(2.4, 2.4)
	_medal.modulate.a = 0.0
	_rays.modulate.a = 0.0
	_rays.scale = Vector2(0.4, 0.4)
	_ribbon.scale = Vector2(0.0, 1.0)
	var card_home := _card.position
	_card.position = card_home - Vector2(0.0, 18.0)
	_card.modulate.a = 0.0
	_card_tween = _stage.create_tween()
	_card_tween.tween_property(_medal, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.parallel().tween_property(_medal, "modulate:a", 1.0, 0.12)
	_card_tween.parallel().tween_property(_rays, "modulate:a", 0.6, 0.4).set_delay(0.18)
	_card_tween.parallel().tween_property(_rays, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.18)
	_card_tween.parallel().tween_callback(_confetti.burst).set_delay(0.26)
	_card_tween.parallel().tween_callback(func() -> void:
		Fx.haptic(15)).set_delay(0.26)
	_card_tween.parallel().tween_property(_ribbon, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	_card_tween.parallel().tween_property(_card, "position", card_home, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.5)
	_card_tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.2).set_delay(0.5)
	_card_tween.tween_interval(hold)
	_card_tween.tween_property(_stage, "modulate:a", 0.0, 0.35)
	_card_tween.parallel().tween_property(_card, "modulate:a", 0.0, 0.35)
	_card_tween.parallel().tween_property(_medal, "scale", Vector2(0.8, 0.8), 0.35)
	_card_tween.tween_callback(_hide_card)


func _process(delta: float) -> void:
	if _stage != null and _stage.visible and UserPreferences.can_animate():
		_rays.rotation += delta * 0.35


static func _sprite(texture: Texture2D, scale: int) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = texture.get_size() * scale
	node.custom_minimum_size = node.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func _bonus_seconds(level: int) -> int:
	## Two minutes of double output; every fifth level is a milestone and pays
	## five. Short enough to be a treat, long enough to be noticed on the counter.
	return 300 if level % 5 == 0 else 120


func _on_ad_pressed() -> void:
	var level := _card_level
	var seconds := _bonus_seconds(level)
	var shown := AdService.show_rewarded(&"level_bonus", func() -> void:
		GameState.grant_surge(2.0, float(seconds))
		EventBus.notification_requested.emit({
			"id": "level_bonus", "kind": &"milestone", "priority": 1,
			"text": Loc.t("level.ad.done", {"min": str(seconds / 60)}),
		}))
	if shown:
		# Whatever the ad does, the card has said its piece.
		_card_ad.visible = false
		if _card_tween != null:
			_card_tween.kill()
		_hide_card()


func _hide_card() -> void:
	_card.visible = false
	_card.modulate.a = 1.0
	_stage.visible = false
	_stage.modulate.a = 1.0
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
	if _pip != null:
		_pip.position = _badge.position + Vector2(_badge.size.x - 6.0, -3.0)
	var top := area.position.y + Hud.BAR_H + 30.0
	_stage.position = Vector2(area.position.x + (area.size.x - STAGE_SIZE.x) * 0.5,
		top).round()
	_ribbon.reset_size()
	_ribbon.size.x = maxf(_ribbon.size.x, 150.0)
	_ribbon.position = Vector2((STAGE_SIZE.x - _ribbon.size.x) * 0.5,
		_medal.position.y + _medal.size.y - 22.0).round()
	_ribbon.pivot_offset = _ribbon.size * 0.5
	_card.size = Vector2(minf(256.0, area.size.x - 24.0), 0.0)
	_card.reset_size()
	if not _card.visible or _card.get_tree() == null or _card.get_tree().get_processed_tweens().is_empty():
		_card.position = Vector2(area.position.x + (area.size.x - _card.size.x) * 0.5,
			_stage.position.y + _ribbon.position.y + _ribbon.size.y + 4.0).round()


class _Confetti extends Node2D:
	## A burst of paper squares from behind the medal, falling and tumbling out.
	## Drawn, not particles: forty rectangles is nothing, and a CPUParticles2D
	## would smooth them into sub-pixel smears.
	const COLOURS := [Color8(252, 202, 96), Color8(200, 72, 60), Color8(92, 178, 166),
		Color8(250, 240, 218), Color8(62, 126, 158)]
	var _bits: Array[Dictionary] = []

	func burst() -> void:
		_bits.clear()
		for i in 40:
			var a := randf_range(-PI, 0.0) if i % 3 else randf_range(-PI * 1.1, 0.1)
			var speed := randf_range(90.0, 210.0)
			_bits.append({"p": Vector2.ZERO, "v": Vector2(cos(a), sin(a)) * speed,
				"c": COLOURS[i % COLOURS.size()], "s": randf_range(0.0, TAU),
				"w": randf_range(-9.0, 9.0), "life": randf_range(1.2, 2.0)})
		set_process(true)

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		var alive := false
		for b: Dictionary in _bits:
			b.life -= delta
			if b.life <= 0.0:
				continue
			alive = true
			b.v = b.v * (1.0 - 1.8 * delta) + Vector2(0, 240.0) * delta
			b.p += b.v * delta
			b.s += b.w * delta
		if not alive:
			_bits.clear()
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		for b: Dictionary in _bits:
			if b.life <= 0.0:
				continue
			# A square seen tumbling is a square, then a line, then a square.
			var w := maxf(1.0, roundf(absf(cos(b.s)) * 4.0))
			var c: Color = b.c
			c.a = clampf(b.life * 2.0, 0.0, 1.0)
			draw_rect(Rect2((b.p - Vector2(w, 3) * 0.5).round(), Vector2(w, 3)), c)
