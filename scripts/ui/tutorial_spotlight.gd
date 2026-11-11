class_name TutorialSpotlight
extends CanvasLayer
## Alisson, on foot. The first minutes, and every "olha isso, chefe!" after.
##
## He is a little pictogram worker who hops across the screen to whatever he is
## talking about, stands beside it, and talks out of a speech bubble that rides
## above or below him — with a babble of voice blips while the line types out.
## The old tour was a fixed dialogue box at the bottom of the screen with a
## portrait in it: correct, and lifeless. A guide who *walks over* to the ship
## is a guide the player follows with their eyes, which is the whole job.
##
## Two modes:
## - **Tour** (`start`): the scripted first minutes in `STEPS`. Every step either
##   waits for a tap or for the player to *do* the thing. The rest of the screen
##   is behind a veil that swallows every press except inside the highlighted
##   rectangle (`_Veil._has_point`), so the tour can never be pointing at
##   something the player has wandered away from.
## - **Tip** (`tip`): after the tour, Main calls him back for a moment worth a
##   word — the first parcel affordable, the wheel unlocked. No veil, nothing
##   blocked: he hops in, says one line, and hops out on a tap or after a while.
##
## A tip names its speaker (`SPEAKERS`): Alisson, or Neide from the Receita
## Federal, who arrives right after the tour to announce the X-ray scanner and
## comes back whenever a box needs inspecting. Same walk, same bubble; each has
## a body sheet with the same seven-frame layout, a Simlish voice family in
## `AudioManager.VARIANTS`, and an idle habit — his futsal ball, her stamp.
##
## Targets come from Main as screen rects, resolved every frame, so he follows
## the camera, the shop sliding open and a rotated phone.

signal step_changed(index: int, step: Dictionary)
signal finished(skipped: bool)
signal tip_closed(id: String)

## `until`: "ok" waits for a tap, "ready" for the `wait` callback, "taps" for
## `goal` paid taps, "shop_open" for the shop sheet, "buy" for a machine
## purchase, "journal_open" for the challenges board. `target` is a key Main resolves to a screen rect; empty means he
## stands centre stage and nothing gets through the veil.
const STEPS := [
	{"id": "intro", "say": "guide.intro", "until": "ok", "target": ""},
	{"id": "intro2", "say": "guide.intro2", "until": "ok", "target": ""},
	{"id": "wait", "say": "guide.wait", "until": "ready", "target": "",
		"wait": "ship_ready"},
	{"id": "navio", "say": "guide.ship", "until": "taps", "goal": 15,
		"target": "ship"},
	{"id": "teu", "say": "guide.teu", "until": "ok", "target": "teu"},
	{"id": "loja", "say": "guide.shop", "until": "shop_open", "target": "shop"},
	{"id": "compra", "say": "guide.buy", "until": "buy", "target": "shop_card"},
	# Waits for the board itself: a tap on the highlighted key went through to
	# the key and opened the board under the veil, while the step sat waiting
	# for a tap on the veil — the tour looked frozen on its last screen.
	{"id": "desafios", "say": "guide.challenges", "until": "journal_open",
		"target": "journal_key"},
	{"id": "fim", "say": "guide.done", "until": "ok", "target": ""},
]

const BODY := preload("res://assets/sprites/ui_guide_body.png")
const CUSTOMS_BODY := preload("res://assets/sprites/ui_customs_body.png")
## Who can stand in the bubble. `role` is a `Loc` key; `voice` an AudioManager
## family; `habit` what they do while they wait (`ball`: keepy-uppy, `stamp`:
## a rubber stamp brought down on an invisible form every couple of seconds).
const SPEAKERS := {
	&"alisson": {"name": "ALISSON", "role": "guide.role", "body": BODY,
		"voice": "voice", "habit": &"ball"},
	&"receita": {"name": "NEIDE", "role": "receita.role", "body": CUSTOMS_BODY,
		"voice": "voice_rf", "habit": &"stamp"},
}
const BALL := preload("res://assets/sprites/ui_guide_ball.png")
## One cell of the body sheet and the scale it is drawn at: big flat pixels.
const CELL := Vector2(18, 22)
const SCALE := 3.0
const F_IDLE := 0
const F_BOB := 1
const F_STEP_A := 2
const F_STEP_B := 3
const F_JUMP := 4
const F_TALK := 5
const F_WAVE := 6
## Characters per second of the typed line; one voice blip every few letters.
const TYPE_SPEED := 40.0
const BLIP_EVERY := 3
const MOUTH_PERIOD := 0.1
## A hop: how far one covers, how long it takes, how high it goes.
const HOP_LEN := 72.0
const HOP_TIME := 0.26
const HOP_HEIGHT := 20.0
const BUBBLE_W := 250.0
## A tip leaves on its own after this long if nobody taps it.
const TIP_TIME := 9.0

var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _index := 0
var _active := false
var _taps := 0
var _veil: _Veil
var _walker: TextureRect
var _walker_atlas: AtlasTexture
var _bubble: PanelContainer
var _name: Label
var _role: Label
var _body: Label
var _hint: Label
var _skip: Button
var _typed := 0.0
var _blipped := 0
var _anim_t := 0.0
## Personality: a shadow on the quay, squash on landing, a little hop of
## excitement at every new line, a "!" when he arrives with news, and the
## futsal ball he keeps up while he waits. He is the futsal star, after all.
var _shadow: _Shadow
var _ball: TextureRect
var _excl: Label
var _ground_y := 0.0
var _squash := 0.0
var _perk := 0.0
var _excl_t := 0.0
var _juggle_t := 0.0

## Where he stands (top-left of the sprite) and where he is hopping to.
var _pos := Vector2.ZERO
var _from := Vector2.ZERO
var _dest := Vector2.ZERO
var _hop_t := -1.0
var _hops := 1
var _facing_left := false
## Set while he hops off screen; called when he is gone.
var _on_gone := Callable()

## Tip mode.
var _tip_id := ""
var _tip_target := ""
var _tip_left := 0.0
var _speaker: Dictionary = SPEAKERS[&"alisson"]
var _speaker_id: StringName = &"alisson"
var _stamp_down := false


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

	_walker_atlas = AtlasTexture.new()
	_walker_atlas.atlas = BODY
	_walker_atlas.region = Rect2(Vector2.ZERO, CELL)
	_walker = TextureRect.new()
	_walker.texture = _walker_atlas
	_walker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_walker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_walker.stretch_mode = TextureRect.STRETCH_SCALE
	_walker.size = CELL * SCALE
	_walker.mouse_filter = Control.MOUSE_FILTER_STOP
	_walker.gui_input.connect(_on_panel_input)
	_walker.pivot_offset = Vector2(CELL.x * SCALE * 0.5, CELL.y * SCALE)
	_shadow = _Shadow.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)
	add_child(_walker)
	_ball = TextureRect.new()
	_ball.texture = BALL
	_ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ball.stretch_mode = TextureRect.STRETCH_SCALE
	_ball.size = Vector2(18, 18)
	_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball.visible = false
	add_child(_ball)
	_excl = UiTheme.label("!", UiTheme.SIZE_HUGE, UiTheme.AMBER)
	_excl.add_theme_color_override(&"font_outline_color", UiTheme.HULL_EDGE)
	_excl.add_theme_constant_override(&"outline_size", 6)
	_excl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_excl.visible = false
	add_child(_excl)

	_bubble = UiTheme.panel(UiTheme.board_style(6), false)
	_bubble.gui_input.connect(_on_panel_input)
	add_child(_bubble)
	# Paper needs a margin: the frame's own padding put the first letter of
	# every line under the enamel.
	var pad := MarginContainer.new()
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		pad.add_theme_constant_override(side, 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	var plate := HBoxContainer.new()
	plate.add_theme_constant_override(&"separation", 6)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(plate)
	_name = UiTheme.label(str(_speaker.name), UiTheme.SIZE_BODY, UiTheme.AMBER_DEEP)
	plate.add_child(_name)
	_role = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_role.clip_text = true
	plate.add_child(_role)
	_skip = UiTheme.button("", &"ghost", UiTheme.SIZE_SMALL)
	_skip.custom_minimum_size = Vector2(50, 20)
	_skip.pressed.connect(_on_skip)
	plate.add_child(_skip)
	_body = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	# A real width before the first layout pass, or autowrap measures one glyph
	# per line and the bubble comes out the height of the screen.
	_body.custom_minimum_size = Vector2(BUBBLE_W - 40.0, 0.0)
	col.add_child(_body)
	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.clip_text = true
	col.add_child(_hint)

	EventBus.manual_reward_committed.connect(_on_tap_paid)
	EventBus.structure_purchase_committed.connect(_on_purchase)
	visible = false


# --------------------------------------------------------------- public API

func start() -> void:
	_tip_id = ""
	_set_speaker(&"alisson")
	_active = true
	_index = 0
	_taps = 0
	_on_gone = Callable()
	visible = true
	_veil.visible = true
	_enter_from_edge()
	_show_step()


func replay() -> void:
	start()


func is_active() -> bool:
	return _active


func tip_active() -> bool:
	return not _tip_id.is_empty()


func tip_id() -> String:
	return _tip_id


func speaker() -> StringName:
	return _speaker_id


func tip(id: String, say_key: String, target: String = "",
		who: StringName = &"alisson") -> bool:
	## Somebody hops in for one line about something the player can do now:
	## `who` is a key of `SPEAKERS`. Refused while the tour or another tip is
	## running, or for a speaker nobody has drawn.
	if _active or tip_active() or not SPEAKERS.has(who):
		return false
	_set_speaker(who)
	_tip_id = id
	_tip_target = target
	_tip_left = TIP_TIME
	_on_gone = Callable()
	visible = true
	_veil.visible = false
	_veil.cutout = Rect2()
	_skip.visible = false
	_role.text = Loc.t(str(_speaker.role))
	_hint.text = Loc.t("guide.continue")
	_say(Loc.t(say_key))
	_enter_from_edge()
	Telemetry.track(&"guide_tip", {"id": id, "who": String(who)})
	return true


func dismiss_tip() -> void:
	## Gone at once, no exit hop: a board is opening over the spot he stood on.
	if not tip_active():
		return
	var id := _tip_id
	_tip_id = ""
	_on_gone = Callable()
	_hop_t = -1.0
	visible = false
	_bubble.visible = true
	tip_closed.emit(id)


func _set_speaker(who: StringName) -> void:
	_speaker_id = who
	_speaker = SPEAKERS[who]
	if _walker_atlas != null:
		_walker_atlas.atlas = _speaker.body
	if _name != null:
		_name.text = str(_speaker.name)


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout_bubble()


func next() -> void:
	if not _active:
		return
	_index += 1
	_taps = 0
	if _index >= STEPS.size():
		# He runs off to his futsal game, and the tour ends when he is gone. The
		# index stays on the last step while he runs: everything reads it.
		_index = STEPS.size() - 1
		_leave(func() -> void: _finish(false))
	else:
		_show_step()


# ------------------------------------------------------------------- events

func _until() -> String:
	return str(STEPS[_index].get("until", "ok")) if _active else "ok"


func _typing() -> bool:
	return _body.visible_characters >= 0 \
		and _body.visible_characters < _body.get_total_character_count()


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
		get_viewport().set_input_as_handled()


func _on_skip() -> void:
	if _active:
		_leave(func() -> void: _finish(true))


func _advance_by_tap() -> void:
	## A tap finishes the line being typed first; only a tap on a finished line
	## of a talking step moves on. An action step waits for its action.
	if _on_gone.is_valid():
		return
	if _typing():
		_body.visible_characters = -1
		return
	if tip_active():
		_close_tip()
		return
	if _active and _until() == "ok":
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
				_on_skip()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_advance_by_tap()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ the loop

func _process(delta: float) -> void:
	if not visible:
		return
	if _active and not _on_gone.is_valid():
		match _until():
			"ready":
				if bool(_call(&"ship_ready", true)):
					next()
					return
			"shop_open":
				if bool(_call(&"shop_open", false)):
					next()
					return
			"journal_open":
				if bool(_call(&"journal_open", false)):
					next()
					return
			"buy":
				# Closed the shop without buying: point at the key again.
				if not bool(_call(&"shop_open", true)):
					_index -= 1
					_show_step()
					return
	if tip_active() and not _on_gone.is_valid() and not _typing():
		_tip_left -= delta
		if _tip_left <= 0.0:
			_close_tip()
	_type(delta)
	# Targets move (camera, a sheet sliding in, rotation): follow them.
	var target := _target_rect()
	if _active:
		_veil.cutout = target
		_veil.queue_redraw()
	if not _on_gone.is_valid():
		var spot := _spot_for(target)
		if spot.distance_to(_dest) > 24.0:
			_hop_to(spot)
		elif _hop_t < 0.0:
			_pos = _pos.lerp(spot, minf(1.0, delta * 8.0))
			_dest = spot
	_move(delta)
	_animate(delta)
	_stage_body(delta)
	_layout_bubble()


func _type(delta: float) -> void:
	if not _typing():
		return
	_typed += delta * TYPE_SPEED
	var shown := mini(int(_typed), _body.get_total_character_count())
	_body.visible_characters = shown
	# The voice: a babble syllable every couple of letters, never on a space.
	if shown - _blipped >= BLIP_EVERY:
		_blipped = shown
		var ch := _body.text.substr(maxi(0, shown - 1), 1)
		if ch != " ":
			AudioManager.play_sfx(str(_speaker.voice), 0.12, -3.0)
	if _body.visible_characters >= _body.get_total_character_count():
		_body.visible_characters = -1


func _hop_to(spot: Vector2) -> void:
	_from = _pos
	_dest = spot
	var dist := _from.distance_to(_dest)
	if not UserPreferences.can_animate():
		_pos = _dest
		_hop_t = -1.0
		return
	_hops = maxi(1, ceili(dist / HOP_LEN))
	_hop_t = 0.0
	if absf(_dest.x - _from.x) > 4.0:
		_facing_left = _dest.x < _from.x


func _move(delta: float) -> void:
	if _hop_t < 0.0:
		return
	var total := HOP_TIME * float(_hops)
	var before := int(_hop_t / HOP_TIME)
	_hop_t += delta
	var k := clampf(_hop_t / total, 0.0, 1.0)
	var within := fmod(_hop_t, HOP_TIME) / HOP_TIME if k < 1.0 else 1.0
	_ground_y = _from.lerp(_dest, k).y
	_pos = _from.lerp(_dest, k) - Vector2(0.0, sin(within * PI) * HOP_HEIGHT)
	if int(_hop_t / HOP_TIME) != before and k < 1.0:
		# A soft boot on the quay at every landing, and a squash.
		AudioManager.play_sfx("tap", 0.2, -16.0)
		_squash = 0.12
	if k >= 1.0:
		_hop_t = -1.0
		_pos = _dest
		_ground_y = _dest.y
		_squash = 0.14
		if _on_gone.is_valid():
			var done := _on_gone
			_on_gone = Callable()
			done.call()


func _stage_body(delta: float) -> void:
	## Everything that makes him a character rather than a sprite in a box.
	var me := CELL * SCALE
	if _hop_t < 0.0:
		_ground_y = _pos.y
	var animate := UserPreferences.can_animate()
	# A little hop of excitement when a new line starts.
	var lift := 0.0
	if _perk > 0.0 and animate:
		_perk = maxf(0.0, _perk - delta)
		lift = sin((1.0 - _perk / 0.24) * PI) * 10.0
	# Squash on landing, stretch in the air.
	var sc := Vector2.ONE
	if animate:
		if _squash > 0.0:
			_squash = maxf(0.0, _squash - delta)
			var q := _squash / 0.14
			sc = Vector2(1.0 + 0.2 * q, 1.0 - 0.2 * q)
		elif _hop_t >= 0.0:
			sc = Vector2(0.92, 1.1)
	_walker.scale = sc
	_walker.position = (_pos - Vector2(0.0, lift)).round()
	_walker.flip_h = _facing_left
	# The shadow stays on the quay and shrinks while he is up in the air.
	var height := clampf((_ground_y - _pos.y + lift) / HOP_HEIGHT, 0.0, 1.0)
	var w := (me.x - 12.0) * (1.0 - 0.35 * height)
	_shadow.position = Vector2(_pos.x + (me.x - w) * 0.5, _ground_y + me.y - 7.0).round()
	_shadow.size = Vector2(w, 9.0)
	_shadow.queue_redraw()
	# The "!" pops over his hat when he arrives with something to say.
	if _excl_t > 0.0:
		_excl_t = maxf(0.0, _excl_t - delta)
		_excl.visible = true
		var pop := 1.0 + 0.4 * maxf(0.0, (_excl_t - 0.6) / 0.2)
		_excl.scale = Vector2(pop, pop)
		_excl.position = (_walker.position + Vector2(me.x * 0.5 + 10.0, -34.0)).round()
	else:
		_excl.visible = false
	# Keepy-uppy while he waits: off his boot, up, and back down.
	var idle := _hop_t < 0.0 and not _typing() and not _on_gone.is_valid() \
		and _target_key().is_empty() and animate
	if _speaker.habit != &"ball":
		idle = false
	_ball.visible = idle
	if idle:
		var before := sin(_juggle_t * 5.0)
		_juggle_t += delta
		var phase := sin(_juggle_t * 5.0)
		if (before < 0.0) != (phase < 0.0) and phase > 0.0:
			AudioManager.play_sfx("tap", 0.15, -22.0)
		var foot_x := _pos.x + (me.x * 0.2 if _facing_left else me.x * 0.62)
		var up := absf(phase) * 40.0
		_ball.position = Vector2(foot_x, _ground_y + me.y - 30.0 - up).round()
	else:
		_juggle_t = 0.0


func _animate(delta: float) -> void:
	_anim_t += delta
	var frame := F_IDLE
	if _hop_t >= 0.0:
		frame = F_JUMP
	elif _typing():
		frame = F_TALK if int(_anim_t / MOUTH_PERIOD) % 2 == 0 else F_IDLE
	elif not _target_key().is_empty():
		# Pointing at it, with a little wave now and then.
		frame = F_WAVE if int(_anim_t / 0.6) % 3 != 2 else F_IDLE
	elif _speaker.habit == &"stamp":
		# Stamp up, and TUM: one form approved every second and a half.
		var up := int(_anim_t / 0.375) % 4 == 0
		frame = F_WAVE if up else F_IDLE
		if _stamp_down and not up and UserPreferences.can_animate():
			AudioManager.play_sfx("thunk", 0.1, -16.0)
			_squash = 0.08
		_stamp_down = up
	else:
		frame = F_BOB if int(_anim_t / 0.5) % 2 == 0 else F_IDLE
	_walker_atlas.region = Rect2(Vector2(frame * CELL.x, 0.0), CELL)


# ------------------------------------------------------------------ staging

func _show_step() -> void:
	Telemetry.track(&"tutorial_step", {"index": _index})
	var step: Dictionary = STEPS[_index]
	_set_speaker(&"alisson")
	_role.text = Loc.t("guide.role")
	_skip.text = Loc.t("spot.skip")
	# Nobody skips the hello.
	_skip.visible = _index > 0
	_say(Loc.t(str(step.say)))
	_refresh_hint()
	_veil.cutout = _target_rect()
	_veil.queue_redraw()
	step_changed.emit(_index, step.duplicate(true))


func _say(text: String) -> void:
	_perk = 0.24
	_excl_t = 0.8
	_body.text = text
	_typed = 0.0
	_blipped = 0
	_body.visible_characters = -1 if not UserPreferences.can_animate() else 0


func _refresh_hint() -> void:
	match _until():
		"taps":
			_hint.text = Loc.t("guide.progress", {"n": str(_taps),
				"goal": str(int(STEPS[_index].get("goal", 1)))})
		"ok":
			_hint.text = Loc.t("guide.continue")
		_:
			_hint.text = ""


func _safe() -> Rect2:
	return _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)


func _enter_from_edge() -> void:
	## He hops in from the bottom-left corner, wherever he is headed.
	var safe := _safe()
	_pos = Vector2(safe.position.x - CELL.x * SCALE, safe.end.y - 170.0)
	_dest = _pos
	_hop_t = -1.0
	_facing_left = false


func _leave(then: Callable) -> void:
	## Off the right edge at a run, then `then`.
	var safe := _safe()
	_on_gone = Callable()
	_hop_to(Vector2(safe.end.x + 10.0, _pos.y))
	_bubble.visible = false
	if _hop_t < 0.0:
		then.call()
		return
	_on_gone = then


func _close_tip() -> void:
	var id := _tip_id
	_leave(func() -> void:
		_tip_id = ""
		visible = false
		_bubble.visible = true
		tip_closed.emit(id))


func _spot_for(target: Rect2) -> Vector2:
	## Where he stands: beside the target, on whichever side has the room for
	## him and his bubble; centre stage when there is nothing to point at.
	var safe := _safe()
	var me := CELL * SCALE
	if target.size.is_zero_approx():
		return Vector2(safe.get_center().x - me.x * 0.5,
			safe.position.y + safe.size.y * 0.62 - me.y * 0.5)
	var x := clampf(target.get_center().x - me.x * 0.5,
		safe.position.x + 4.0, safe.end.x - me.x - 4.0)
	var below := target.end.y + 6.0
	var above := target.position.y - me.y - 6.0
	if below + me.y + 90.0 <= safe.end.y:
		return Vector2(x, below)
	if above - 90.0 >= safe.position.y:
		return Vector2(x, above)
	# A tall target (the ship): stand on its inland side, half way down.
	var side := target.position.x - me.x - 4.0
	if side < safe.position.x:
		side = target.end.x + 4.0
	return Vector2(clampf(side, safe.position.x, safe.end.x - me.x),
		clampf(target.get_center().y, safe.position.y + 100.0, safe.end.y - me.y - 10.0))


func _layout_bubble() -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	var safe := _safe()
	var width := minf(BUBBLE_W, safe.size.x - 16.0)
	_body.custom_minimum_size.x = width - 40.0
	_bubble.size = Vector2(width, 0.0)
	_bubble.reset_size()
	var me := CELL * SCALE
	var h := _bubble.size.y
	var x := clampf(_pos.x + me.x * 0.5 - width * 0.5,
		safe.position.x + 8.0, safe.end.x - width - 8.0)
	# Above his hat when there is room and the target is not there; below his
	# boots otherwise. The bubble never covers what he is pointing at.
	var target := _target_rect()
	var up := Vector2(x, _pos.y - h - 6.0)
	var down := Vector2(x, _pos.y + me.y + 6.0)
	var at := up
	if up.y < safe.position.y or (not target.size.is_zero_approx()
			and Rect2(up, _bubble.size).intersects(target)):
		at = down
	if at.y + h > safe.end.y:
		at.y = maxf(safe.position.y, _pos.y - h - 6.0)
	_bubble.position = at.round()


func _target_key() -> String:
	if _active:
		return str(STEPS[_index].get("target", ""))
	return _tip_target


func _target_rect() -> Rect2:
	var key := _target_key()
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


func _finish(skipped: bool) -> void:
	Telemetry.track(&"tutorial_finished", {"skipped": skipped})
	_active = false
	visible = false
	_bubble.visible = true
	_veil.cutout = Rect2()
	finished.emit(skipped)


class _Shadow extends Control:
	## A soft pixel ellipse on the ground under him: two stacked bars.
	func _draw() -> void:
		var c := Color(0.02, 0.02, 0.06, 0.38)
		var w := size.x
		draw_rect(Rect2(3.0, 0.0, w - 6.0, size.y), c)
		draw_rect(Rect2(0.0, 3.0, w, size.y - 6.0), c)


class _Veil extends Control:
	## Dim everywhere but the target, and solid everywhere but the target: a
	## press inside the cutout is not ours (`_has_point` false), so it reaches
	## the control or the port underneath; anywhere else it stops here.
	var cutout := Rect2()

	func _has_point(point: Vector2) -> bool:
		return visible and not cutout.has_point(point)

	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		var shade := Color(0.02, 0.02, 0.06, 0.5)
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
