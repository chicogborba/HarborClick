class_name LuckyWheelPanel
extends CanvasLayer
## The Roda da Sorte board: the carnival wheel bolted to a clipboard, opened
## from the small key under the gantry.
##
## Pixel art cannot be rotated — a sprite turned 13 degrees is resampled into
## mush — so the disc is not one picture spun in-engine. `ui_wheel_disc` is 64
## pre-turned frames (see tools/sprites/gen_wheel.py), and a spin is just the
## atlas region advancing frame by frame while the icons ride their quantised
## angle, so every segment edge stays crisp at every step.
##
## Everything is built once in `_ready` and only rewritten in place afterwards:
## text, atlas regions and positions. Rebuilding controls per frame eats taps.

signal open_changed(opened: bool)

const TEX_DISC := preload("res://assets/sprites/ui_wheel_disc.png")
const TEX_SHEEN := preload("res://assets/sprites/ui_wheel_sheen.png")
const TEX_RIM := preload("res://assets/sprites/ui_wheel_rim.png")
const TEX_BULBS := preload("res://assets/sprites/ui_wheel_bulbs.png")
const TEX_POINTER := preload("res://assets/sprites/ui_wheel_pointer.png")
const TEX_HUB := preload("res://assets/sprites/ui_wheel_hub.png")
const TEX_ICONS := preload("res://assets/sprites/ui_wheel_icons.png")
const TEX_STAND := preload("res://assets/sprites/ui_wheel_stand.png")

const DISC := 104
const DISC_FRAMES := 64
const FRAME_DEG := 360.0 / 64.0 ## 5.625: frame k is the disc turned k * FRAME_DEG clockwise
const RIM := 124
const POINTER_SIZE := Vector2(15, 19)
const HUB := 22
const ICON := 14
const ICON_RADIUS := 31.0
const SEGMENT_DEG := 45.0
## The wheel view's own rect: the wheel centre sits at (66, 64) inside it.
const VIEW_SIZE := Vector2(132, 150)
const CENTER := Vector2(66, 64)
const SPIN_TIME := 4.2
const SPIN_TURNS := 5.0
const JITTER := 14.0
const PEG_OFFSET := 22.5 ## a peg is under the pointer at angle + PEG_OFFSET over SEGMENT_DEG

var _service: WheelService
## True from the key press to the first frame of the rise: the state says the
## wheel is open while the board is still being measured, so nothing else can
## claim the screen in that window and a close in it is honoured.
var _opening := false
var _scrim: ColorRect
var _board: PanelContainer
var _column: VBoxContainer
var _wheel_view: Control
var _disc_atlas: AtlasTexture
var _bulbs_atlas: AtlasTexture
var _pointer_atlas: AtlasTexture
var _coin_atlas: AtlasTexture
var _icons: Array[TextureRect] = []
var _status: Label
## How the next token is earned, and how close it is. A wheel with no spin left
## and no word on how to get one is a locked door with no handle.
var _earn: Label
var _prize: Label
var _detail: Label
var _spin_button: Button
var _close_button: Button
var _safe_rect := Rect2()
var _angle := 0.0
var _spinning := false
var _spin_t := 0.0
var _spin_start := 0.0
var _spin_delta := 0.0
var _last_peg := -1
var _peg_t := 0.0
var _bulb_tick := 0.0
var _bulb_frame := 0
var _flash_t := 0.0
var _status_tick := 0.0
var _last_amount := 0.0
## The two places the wheel offers a rewarded ad: a spin when none is left, and
## doubling a cash prize once it has landed. Never required — the wheel works
## without either, and each goes away when its daily cap is spent.
var _ad_spin_button: Button
var _ad_double_button: Button
var _shake_t := 0.0
var _board_home := Vector2.ZERO
var _coins: Array[Dictionary] = []
var _pop_tween: Tween


func _ready() -> void:
	layer = 13
	visible = false
	_scrim = UiTheme.scrim(0.7)
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_board = UiTheme.panel(UiTheme.board_style(11), false)
	add_child(_board)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 6)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_column)

	var header := UiTheme.header(Loc.t("wheel.title"), close)
	_column.add_child(header.root)
	_close_button = header.close
	_close_button.tooltip_text = Loc.t("common.close_hint")

	_build_wheel_view()

	_status = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_status)
	_earn = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_earn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Clipped, never wrapped: a wrapping label with no width yet reports a
	# fantasy height, which is the bug that once pushed this board off a phone.
	_earn.clip_text = true
	_column.add_child(_earn)
	# The thick dark outline is what FloatText uses so bright type survives
	# over any pixel art; a prize name is exactly that kind of loud.
	_prize = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.AMBER)
	_prize.label_settings = UiTheme.settings(UiTheme.SIZE_TITLE, UiTheme.AMBER, 3)
	_prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prize.visible = false
	_column.add_child(_prize)
	_detail = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.visible = false
	_column.add_child(_detail)

	_spin_button = UiTheme.button(Loc.t("wheel.spin"), &"amber")
	_spin_button.custom_minimum_size.y = 34.0
	_spin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_button.pressed.connect(_on_spin_pressed)
	_column.add_child(_spin_button)
	_ad_spin_button = UiTheme.button(Loc.t("wheel.ad_spin"), &"steel", UiTheme.SIZE_SMALL)
	_ad_spin_button.icon = UiTheme.icon16_texture(UiTheme.Icon16.AD)
	_ad_spin_button.custom_minimum_size.y = 28.0
	_ad_spin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ad_spin_button.pressed.connect(_on_ad_spin)
	_ad_spin_button.visible = false
	_column.add_child(_ad_spin_button)
	_ad_double_button = UiTheme.button(Loc.t("wheel.ad_double"), &"steel", UiTheme.SIZE_SMALL)
	_ad_double_button.icon = UiTheme.icon16_texture(UiTheme.Icon16.AD)
	_ad_double_button.custom_minimum_size.y = 28.0
	_ad_double_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ad_double_button.pressed.connect(_on_ad_double)
	_ad_double_button.visible = false
	_column.add_child(_ad_double_button)

	_connect_service()
	_apply_angle()
	_refresh_status()
	_layout()


func _build_wheel_view() -> void:
	_wheel_view = Control.new()
	_wheel_view.custom_minimum_size = VIEW_SIZE
	_wheel_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wheel_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_wheel_view)
	# Draw order: pedestal, disc, segment icons, sheen, rim, bulbs, hub,
	# pointer. Every position is a whole pixel; nothing here is ever rotated
	# or non-integer-scaled.
	_wheel_view.add_child(_layer(TEX_STAND,
		Rect2(Vector2.ZERO, Vector2(56, 26)), Vector2(38, 124), Vector2(56, 26)))
	var disc := _layer(TEX_DISC, Rect2(0, 0, DISC, DISC),
		Vector2(14, 12), Vector2(DISC, DISC))
	_disc_atlas = disc.texture as AtlasTexture
	_wheel_view.add_child(disc)
	_coin_atlas = AtlasTexture.new()
	_coin_atlas.atlas = TEX_ICONS
	_coin_atlas.region = Rect2(0, 0, ICON, ICON)
	for i in LuckyWheel.SEGMENTS.size():
		var icon := _layer(TEX_ICONS, Rect2(i * ICON, 0, ICON, ICON),
			CENTER - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON))
		_icons.append(icon)
		_wheel_view.add_child(icon)
	_wheel_view.add_child(_layer(TEX_SHEEN,
		Rect2(Vector2.ZERO, Vector2(DISC, DISC)), Vector2(14, 12), Vector2(DISC, DISC)))
	_wheel_view.add_child(_layer(TEX_RIM,
		Rect2(Vector2.ZERO, Vector2(RIM, RIM)), Vector2(4, 2), Vector2(RIM, RIM)))
	var bulbs := _layer(TEX_BULBS, Rect2(0, 0, RIM, RIM),
		Vector2(4, 2), Vector2(RIM, RIM))
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bulbs.material = additive
	_bulbs_atlas = bulbs.texture as AtlasTexture
	_wheel_view.add_child(bulbs)
	_wheel_view.add_child(_layer(TEX_HUB,
		Rect2(Vector2.ZERO, Vector2(HUB, HUB)), Vector2(55, 53), Vector2(HUB, HUB)))
	# The pointer's pivot/cap is at its local (7, 2) and its tip points down;
	# placed so the tip lands on the top edge of the disc.
	var pointer := _layer(TEX_POINTER, Rect2(0, 0, POINTER_SIZE.x, POINTER_SIZE.y),
		Vector2(59, -7), POINTER_SIZE)
	pointer.pivot_offset = Vector2(7, 2)
	_pointer_atlas = pointer.texture as AtlasTexture
	_wheel_view.add_child(pointer)


func _layer(atlas: Texture2D, region: Rect2, pos: Vector2, size: Vector2) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = atlas
	at.region = region
	var node := TextureRect.new()
	node.texture = at
	node.custom_minimum_size = size
	node.size = size
	node.position = pos
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


# ------------------------------------------------------------------ service

func setup(service: WheelService) -> void:
	_service = service
	_connect_service()
	_refresh_status()


func _connect_service() -> void:
	if _service == null:
		return
	if not _service.state_changed.is_connected(_refresh_status):
		_service.state_changed.connect(_refresh_status)
	if not _service.prize_applied.is_connected(_on_prize_applied):
		_service.prize_applied.connect(_on_prize_applied)


func _on_prize_applied(_p: Dictionary, amount: float) -> void:
	# The amount arrives here, not on the return value: claim_and_apply emits
	# prize_applied and returns the prize, and the panel keeps the two apart.
	_last_amount = amount


# ------------------------------------------------------------------ open/close

func open() -> void:
	if visible or _opening:
		return
	_opening = true
	# Open to the game from the press itself, not from the first drawn frame:
	# a charter that arrives two frames later must find this screen taken.
	open_changed.emit(true)
	# The board fits its content one frame after its width is set (the labels
	# wrap to that width), so the fit is measured with the panel still hidden
	# and only then does it appear — shown and already travelling in the same
	# frame, never resting one frame before the rise.
	_prize.visible = false
	_detail.visible = false
	_refresh_status()
	_layout()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _opening:
		return
	_opening = false
	visible = true
	UiTheme.pop_open(_board, _scrim)
	if _spin_button.disabled:
		_close_button.grab_focus()
	else:
		_spin_button.grab_focus()


func close() -> void:
	if not visible and not _opening:
		return
	_opening = false
	if _spinning:
		# A spin already decided its prize; closing must not eat it.
		finish_now()
	if visible:
		# The rise has a drop to answer it: a board that comes up travelling
		# and vanishes standing still is half a gesture.
		UiTheme.pop_close(_board, _scrim, func() -> void: visible = false)
	open_changed.emit(false)


func is_open() -> bool:
	return visible


func finish_now() -> void:
	## Jumps a running spin to its final frame and reveals. Nothing decided is
	## ever lost — close() uses this mid-spin, and the tests drive it directly.
	if not _spinning:
		return
	_spinning = false
	_angle = _spin_start + _spin_delta
	_apply_angle()
	_finish_spin()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed \
			and (event.is_action_pressed(&"ui_cancel")
				or event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _on_scrim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ layout

func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


var _layout_pending := false


func _layout() -> void:
	if _board == null or not is_instance_valid(_board):
		return
	var safe := _safe_rect
	if safe.size == Vector2.ZERO:
		safe = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var width := minf(300.0, safe.size.x - 16.0)
	# Width first, height one frame later. The labels wrap to the board's
	# width, so a height measured before that width has propagated through the
	# container is a fantasy — at width 0 an autowrapped label reports dozens of
	# lines, and the board ended up taller than the screen, clipped at the top.
	_board.size = Vector2(width, _board.size.y)
	if _layout_pending:
		return
	_layout_pending = true
	await get_tree().process_frame
	_layout_pending = false
	if _board == null or not is_instance_valid(_board):
		return
	# Fitted to the content, capped at the safe area. The board's own content
	# margin is 11 on every side (board_style(11)).
	var content_h := _column.get_combined_minimum_size().y + 22.0
	_board.size = Vector2(width, minf(content_h, safe.size.y - 20.0))
	_board.position = safe.position + (safe.size - _board.size) * 0.5
	_board_home = _board.position


# ------------------------------------------------------------------ the spin

func _on_ad_spin() -> void:
	if _service == null or _spinning:
		return
	AdService.show_rewarded(&"wheel_spin", func() -> void:
		_service.grant_token(1)
		_refresh_status()
		_on_spin_pressed())


func _on_ad_double() -> void:
	## The prize in cash lands twice. Only offered for cash, where "twice" is
	## exact; a surge or a token has no honest doubling.
	var amount := _last_amount
	_ad_double_button.visible = false
	AdService.show_rewarded(&"wheel_double", func() -> void:
		GameState.grant_nonproductive_reward(amount)
		_detail.text = "%s %s" % [GameState.fmt(amount * 2.0), Loc.t("common.teus")]
		AudioManager.play_sfx("coins", 0.03))


func _on_spin_pressed() -> void:
	if _service == null or _service.wheel == null or _spinning:
		return
	var now := Time.get_unix_time_from_system()
	if not _service.wheel.can_spin(now):
		_refresh_status()
		return
	var prize := _service.spin()
	if prize.is_empty():
		return
	var index := int(prize.get("index", 0))
	_prize.visible = false
	_detail.visible = false
	_ad_double_button.visible = false
	# Segment i is centred under the pointer at rotation 360 - i*45, plus a
	# jitter so the peg does not always stop on the exact same pixel.
	var target := fposmod(360.0 - float(index) * SEGMENT_DEG, 360.0) \
		+ randf_range(-JITTER, JITTER)
	var current := fposmod(_angle, 360.0)
	var delta := SPIN_TURNS * 360.0 + fposmod(target - current, 360.0)
	if not UserPreferences.can_animate():
		_angle = current + delta
		_apply_angle()
		_finish_spin()
		return
	_spinning = true
	_spin_t = 0.0
	_spin_start = _angle
	_spin_delta = delta
	_last_peg = int(floor((_angle + PEG_OFFSET) / SEGMENT_DEG))
	_refresh_status()


func _finish_spin() -> void:
	_spinning = false
	_refresh_status()
	if _service == null:
		return
	var prize := _service.claim_and_apply()
	if prize.is_empty():
		return
	_reveal(prize)


func _apply_angle() -> void:
	## One quantised frame drives the disc sprite AND the icon positions, so
	## the icons stay glued to their segments at every step of the spin.
	var frame := posmod(int(round(_angle / FRAME_DEG)), DISC_FRAMES)
	_disc_atlas.region = Rect2(frame * DISC, 0.0, DISC, DISC)
	var frame_deg := float(frame) * FRAME_DEG
	for i in _icons.size():
		var a := deg_to_rad(float(i) * SEGMENT_DEG + frame_deg)
		var p := CENTER + Vector2(sin(a), -cos(a)) * ICON_RADIUS \
			- Vector2(ICON, ICON) * 0.5
		_icons[i].position = p.round()


func _on_peg() -> void:
	AudioManager.play_sfx("wheel_tick", 0.1, -4.0)
	_pointer_atlas.region = Rect2(POINTER_SIZE.x, 0, POINTER_SIZE.x, POINTER_SIZE.y)
	_peg_t = 0.06


# ------------------------------------------------------------------ the reveal

func _reveal(prize: Dictionary) -> void:
	var id := StringName(prize.get("id", &""))
	_prize.text = Loc.t("wheel.prize.%s" % id)
	match StringName(prize.get("kind", &"")):
		&"cash":
			_detail.text = "%s %s" % [GameState.fmt(_last_amount),
				Loc.t("common.teus")]
		&"surge":
			_detail.text = "x%d • %ds" % [int(prize.get("mult", 1.0)),
				int(prize.get("seconds", 0.0))]
		&"token":
			_detail.text = "+%d" % int(prize.get("tokens", 1))
		_:
			_detail.text = ""
	_prize.visible = true
	_detail.visible = true
	_ad_double_button.visible = StringName(prize.get("kind", &"")) == &"cash" \
		and _last_amount > 0.0 and AdService.available(&"wheel_double")
	_layout()
	AudioManager.play_sfx("wheel_win")
	AudioManager.play_sfx("coins", 0.05, -3.0)
	if id == &"jackpot":
		AudioManager.play_sfx("prestige")
	_flash_t = 1.2
	if UserPreferences.can_animate():
		_pop_prize()
		_spawn_burst()
		if id == &"jackpot" or id == &"frenzy":
			_shake_t = 0.35
	_refresh_status()


func _pop_prize() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_prize.pivot_offset = _prize.get_combined_minimum_size() * 0.5
	_prize.scale = Vector2(0.3, 0.3)
	_pop_tween = create_tween()
	_pop_tween.tween_property(_prize, "scale", Vector2(1.15, 1.15), 0.16) \
		.set_trans(Tween.TRANS_BACK)
	_pop_tween.tween_property(_prize, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK)


func _spawn_burst() -> void:
	for i in 18:
		var coin := Sprite2D.new()
		coin.texture = _coin_atlas
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.position = CENTER
		_wheel_view.add_child(coin)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		_coins.append({
			"node": coin,
			"vel": dir.normalized() * randf_range(50.0, 120.0) + Vector2(0, -30.0),
			"t": 0.0,
		})


func _update_burst(delta: float) -> void:
	for i in range(_coins.size() - 1, -1, -1):
		var c: Dictionary = _coins[i]
		var node: Sprite2D = c.node
		if not is_instance_valid(node):
			_coins.remove_at(i)
			continue
		var t: float = c.t + delta
		if t >= 0.9:
			node.queue_free()
			_coins.remove_at(i)
			continue
		c.t = t
		var vel: Vector2 = c.vel
		vel.y += 240.0 * delta
		c.vel = vel
		node.position += vel * delta
		node.modulate.a = 1.0 - t / 0.9


# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	if not visible:
		return
	# Status text at most once per second; nothing is ever rebuilt.
	_status_tick += delta
	if _status_tick >= 1.0:
		_status_tick = 0.0
		_refresh_status()
	# Bulbs: idle chase every 0.5 s, fast chase while spinning, fast flash for
	# 1.2 s after a win.
	_flash_t = maxf(0.0, _flash_t - delta)
	_bulb_tick += delta
	var interval := 0.5
	if _spinning:
		interval = 0.07
	elif _flash_t > 0.0:
		interval = 0.06
	if _bulb_tick >= interval:
		_bulb_tick = 0.0
		_bulb_frame = 1 - _bulb_frame
		_bulbs_atlas.region = Rect2(_bulb_frame * RIM, 0.0, RIM, RIM)
	if _peg_t > 0.0:
		_peg_t -= delta
		if _peg_t <= 0.0:
			_pointer_atlas.region = Rect2(0, 0, POINTER_SIZE.x, POINTER_SIZE.y)
	if _spinning:
		_spin_t += delta
		var t := clampf(_spin_t / SPIN_TIME, 0.0, 1.0)
		# Ease-out quart: fast off the peg, long settle on the prize.
		_angle = _spin_start + _spin_delta * (1.0 - pow(1.0 - t, 4.0))
		_apply_angle()
		var peg := int(floor((_angle + PEG_OFFSET) / SEGMENT_DEG))
		if peg != _last_peg:
			_last_peg = peg
			_on_peg()
		if t >= 1.0:
			_finish_spin()
	if _shake_t > 0.0:
		_shake_t -= delta
		if _shake_t <= 0.0:
			_board.position = _board_home
		else:
			_board.position = _board_home + Vector2(randf_range(-3.0, 3.0),
				randf_range(-3.0, 3.0))
	_update_burst(delta)


static func _hm(seconds: float) -> String:
	## Hours and minutes, rounded up so the clock never shows 0m while waiting.
	var minutes := ceili(seconds / 60.0)
	return "%dh %02dm" % [minutes / 60, minutes % 60] if minutes >= 60 \
		else "%dm" % maxi(1, minutes)


func _refresh_status() -> void:
	if _service == null or _service.wheel == null or _status == null:
		return
	var wheel := _service.wheel
	var now := Time.get_unix_time_from_system()
	var free := wheel.free_spin_ready(now)
	var wait := wheel.seconds_to_free(now)
	var time_str := ""
	if wait >= 3600.0:
		time_str = "%dh%02dm" % [int(wait / 3600.0), int(wait / 60.0) % 60]
	else:
		time_str = "%dm%02ds" % [int(wait / 60.0), int(wait) % 60]
	var state := Loc.t("wheel.free") if free \
		else Loc.t("wheel.next_free", {"time": time_str})
	_status.text = "%s  •  %s" % [Loc.t("wheel.tokens", {"n": wheel.tokens}), state]
	if _earn != null:
		_earn.text = Loc.t("wheel.earn",
			{"left": str(maxi(0, AdService.remaining_today(&"wheel_spin")))})
	_spin_button.disabled = _spinning or not wheel.can_spin(now)
	# The wait is the button's own face: a dead key with no clock gives no reason
	# to come back, a clock that says "5h 32m" does.
	if not _spinning and wheel.pending.is_empty():
		_spin_button.text = Loc.t("wheel.spin") if wheel.can_spin(now) \
			else Loc.t("wheel.spin_in", {"time": _hm(wait)})
	# Nothing to spin with, and an ad may stand in for a token.
	_ad_spin_button.visible = not _spinning and wheel.pending.is_empty() \
		and not wheel.can_spin(now) and AdService.available(&"wheel_spin")
