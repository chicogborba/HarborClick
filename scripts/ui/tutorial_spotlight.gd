class_name TutorialSpotlight
extends CanvasLayer
## The first minutes, walked through by Alisson, the terminal's project manager.
##
## He talks from a dialogue box (portrait, name plate, typed-out line) and every
## step either waits for a tap on the box or for the player to *do* the thing:
## tap the ship, open the shop, hire a docker. The rest of the screen is behind
## a veil that swallows every press — the old tour drew a dark veil that let
## taps straight through, so a new player could open boards, buy things and
## pan away mid-step and leave the tour pointing at nothing. Only the
## highlighted rectangle reaches the game underneath (`_Veil._has_point`).
##
## Targets come from Main as screen rects, resolved every frame, so the
## highlight follows the camera, the shop sliding open and a rotated phone.

signal step_changed(index: int, step: Dictionary)
signal finished(skipped: bool)

## `until`: "ok" waits for a tap on the box (or anywhere on the veil), "ready"
## for the `wait` callback, "taps" for `goal` paid taps, "shop_open" for the
## shop sheet, "buy" for a machine purchase. `target` is a key Main resolves to
## a screen rect; empty means nothing is highlighted and nothing gets through.
const STEPS := [
	{"id": "intro", "say": "guide.intro", "until": "ok", "target": ""},
	{"id": "wait", "say": "guide.wait", "until": "ready", "target": "",
		"wait": "ship_ready"},
	{"id": "navio", "say": "guide.ship", "until": "taps", "goal": 15,
		"target": "ship"},
	{"id": "teu", "say": "guide.teu", "until": "ok", "target": "teu"},
	{"id": "loja", "say": "guide.shop", "until": "shop_open", "target": "shop"},
	{"id": "compra", "say": "guide.buy", "until": "buy", "target": "shop_card"},
	{"id": "desafios", "say": "guide.challenges", "until": "ok",
		"target": "journal_key"},
	{"id": "fim", "say": "guide.done", "until": "ok", "target": ""},
]

const PORTRAIT := preload("res://assets/sprites/ui_guide.png")
const FRAME := 64
const PORTRAIT_SCALE := 2
## Characters per second of the typed line, and the mouth's flap while typing.
const TYPE_SPEED := 42.0
const MOUTH_PERIOD := 0.11
const BLINK_EVERY := 3.4
const BLINK_TIME := 0.13
const PANEL_H := 150.0

var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _index := 0
var _active := false
var _taps := 0
var _veil: _Veil
var _panel: PanelContainer
var _face: TextureRect
var _face_atlas: AtlasTexture
var _name: Label
var _role: Label
var _body: Label
var _hint: Label
var _skip: Button
var _typed := 0.0
var _mouth_t := 0.0
var _blink_t := 0.0


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_callbacks = manager_or_callbacks.duplicate() if manager_or_callbacks is Dictionary \
		else callbacks.duplicate()


func _ready() -> void:
	layer = 20
	_veil = _Veil.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.gui_input.connect(_on_veil_input)
	add_child(_veil)

	_panel = UiTheme.panel(UiTheme.board_style(9), false)
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_face_atlas = AtlasTexture.new()
	_face_atlas.atlas = PORTRAIT
	_face_atlas.region = Rect2(0, 0, FRAME, FRAME)
	var frame := UiTheme.panel(UiTheme.well_style(2))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	_face = TextureRect.new()
	_face.texture = _face_atlas
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.custom_minimum_size = Vector2(FRAME, FRAME) * PORTRAIT_SCALE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_face)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var plate := HBoxContainer.new()
	plate.add_theme_constant_override(&"separation", 6)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(plate)
	_name = UiTheme.label("ALISSON", UiTheme.SIZE_BODY, UiTheme.AMBER_DEEP)
	plate.add_child(_name)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(gap)
	_skip = UiTheme.button("", &"ghost", UiTheme.SIZE_SMALL)
	_skip.custom_minimum_size = Vector2(54, 22)
	_skip.pressed.connect(func() -> void: _finish(true))
	plate.add_child(_skip)
	# The role on its own line: beside the name it lost half its words to the
	# skip key on a phone.
	_role = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_role.clip_text = true
	col.add_child(_role)
	col.add_child(UiTheme.divider())
	_body = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A real width before the first layout pass, or autowrap measures one glyph
	# per line and the box comes out the height of the screen.
	_body.custom_minimum_size = Vector2(150.0, 40.0)
	col.add_child(_body)
	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.clip_text = true
	col.add_child(_hint)

	EventBus.manual_reward_committed.connect(_on_tap_paid)
	EventBus.structure_purchase_committed.connect(_on_purchase)
	visible = false


func start() -> void:
	_active = true
	_index = 0
	_taps = 0
	visible = true
	_show_step()


func replay() -> void:
	start()


func is_active() -> bool:
	return _active


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func next() -> void:
	if not _active:
		return
	_index += 1
	_taps = 0
	if _index >= STEPS.size():
		_finish(false)
	else:
		_show_step()


func _until() -> String:
	return str(STEPS[_index].get("until", "ok"))


func _typing() -> bool:
	return _body.visible_characters >= 0 \
		and _body.visible_characters < _body.get_total_character_count()


# ------------------------------------------------------------------- events

func _on_tap_paid(_payload: Dictionary) -> void:
	if not _active or _until() != "taps":
		return
	_taps += 1
	var goal := int(STEPS[_index].get("goal", 1))
	if _taps >= goal:
		next()
	else:
		_refresh_hint()


func _on_purchase(_quote: Dictionary) -> void:
	if not _active or _until() != "buy":
		return
	# The shop has done its job; close it so the next thing he points at is not
	# behind the sheet.
	_call(&"close_shop")
	next()


func _on_veil_input(event: InputEvent) -> void:
	if _is_release(event):
		_advance_by_tap()
	get_viewport().set_input_as_handled()


func _on_panel_input(event: InputEvent) -> void:
	if _is_release(event):
		_advance_by_tap()


func _advance_by_tap() -> void:
	## A tap finishes the line being typed first; only a tap on a finished line
	## of a talking step moves on. An action step waits for its action.
	if _typing():
		_body.visible_characters = -1
		return
	if _until() == "ok":
		AudioManager.play_sfx("tap", 0.1)
		next()


static func _is_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not event.pressed
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			if _index > 0:
				_finish(true)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_advance_by_tap()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active:
		return
	match _until():
		"ready":
			if bool(_call(&"ship_ready", true)):
				next()
				return
		"shop_open":
			if bool(_call(&"shop_open", false)):
				next()
				return
		"buy":
			# Closed the shop without buying: point at the key again.
			if not bool(_call(&"shop_open", true)):
				_index -= 1
				_show_step()
				return
	if _typing():
		_typed += delta * TYPE_SPEED
		_body.visible_characters = mini(int(_typed), _body.get_total_character_count())
		if _body.visible_characters >= _body.get_total_character_count():
			_body.visible_characters = -1
	_animate_face(delta)
	# Targets move (camera, a sheet sliding in, rotation): follow them.
	_veil.cutout = _target_rect()
	_veil.queue_redraw()
	_layout()


func _animate_face(delta: float) -> void:
	var frame := 0
	if _typing():
		_mouth_t += delta
		frame = 1 if int(_mouth_t / MOUTH_PERIOD) % 2 == 0 else 0
	else:
		frame = 0 if str(STEPS[_index].get("target", "")).is_empty() else 3
		_blink_t += delta
		if _blink_t >= BLINK_EVERY:
			frame = 2
			if _blink_t >= BLINK_EVERY + BLINK_TIME:
				_blink_t = 0.0
	_face_atlas.region = Rect2(frame * FRAME, 0, FRAME, FRAME)


# ------------------------------------------------------------------ drawing

func _show_step() -> void:
	Telemetry.track(&"tutorial_step", {"index": _index})
	var step: Dictionary = STEPS[_index]
	_role.text = Loc.t("guide.role")
	_skip.text = Loc.t("spot.skip")
	# Nobody skips the hello.
	_skip.visible = _index > 0
	_body.text = Loc.t(str(step.say))
	_typed = 0.0
	_mouth_t = 0.0
	_body.visible_characters = -1 if not UserPreferences.can_animate() else 0
	_refresh_hint()
	_veil.cutout = _target_rect()
	_veil.queue_redraw()
	_layout()
	step_changed.emit(_index, step.duplicate(true))


func _refresh_hint() -> void:
	match _until():
		"taps":
			_hint.text = Loc.t("guide.progress", {"n": str(_taps),
				"goal": str(int(STEPS[_index].get("goal", 1)))})
		"ok":
			_hint.text = Loc.t("guide.continue")
		_:
			_hint.text = ""


func _target_rect() -> Rect2:
	var key := str(STEPS[_index].get("target", "")) if _active else ""
	if key.is_empty():
		return Rect2()
	var callback: Callable = _callbacks.get("get_target_rect", Callable())
	if callback.is_valid():
		var result: Variant = callback.call(key)
		if result is Rect2 and not (result as Rect2).size.is_zero_approx():
			return (result as Rect2).grow(4.0)
	return Rect2()


func _call(name: StringName, fallback: Variant = null) -> Variant:
	var callback: Callable = _callbacks.get(String(name), Callable())
	return callback.call() if callback.is_valid() else fallback


func _layout() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var width := minf(380.0, safe.size.x - 16.0)
	_panel.size = Vector2(width, PANEL_H)
	var x := safe.get_center().x - width * 0.5
	var bottom := Vector2(x, safe.end.y - PANEL_H - 8.0)
	var top := Vector2(x, safe.position.y + 8.0)
	var target := _veil.cutout
	var at := bottom
	if not target.size.is_zero_approx() and Rect2(bottom, _panel.size).intersects(target.grow(6.0)):
		at = top
		# A target near the top as well (a tall ship): sit just above it.
		if Rect2(top, _panel.size).intersects(target.grow(6.0)):
			at = Vector2(x, clampf(target.position.y - PANEL_H - 10.0,
				safe.position.y, safe.end.y - PANEL_H))
	_panel.position = at.round()


func _finish(skipped: bool) -> void:
	Telemetry.track(&"tutorial_finished", {"skipped": skipped})
	_active = false
	visible = false
	finished.emit(skipped)


class _Veil extends Control:
	## Dark everywhere but the target, and solid everywhere but the target: a
	## press inside the cutout is not ours (`_has_point` false), so it reaches
	## the control or the port underneath; anywhere else it stops here.
	var cutout := Rect2()

	func _has_point(point: Vector2) -> bool:
		return not cutout.has_point(point)

	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		var shade := Color(0.02, 0.02, 0.06, 0.68)
		if cutout.size == Vector2.ZERO:
			draw_rect(full, shade)
			return
		draw_rect(Rect2(0, 0, full.size.x, cutout.position.y), shade)
		draw_rect(Rect2(0, cutout.end.y, full.size.x, maxf(0.0, full.end.y - cutout.end.y)), shade)
		draw_rect(Rect2(0, cutout.position.y, cutout.position.x, cutout.size.y), shade)
		draw_rect(Rect2(cutout.end.x, cutout.position.y,
			maxf(0.0, full.end.x - cutout.end.x), cutout.size.y), shade)
		# A two-tone frame so it reads on the dark water and on the cream sheet.
		draw_rect(cutout.grow(1.0), UiTheme.HULL_EDGE, false, 2.0)
		draw_rect(cutout, UiTheme.AMBER, false, 2.0)
