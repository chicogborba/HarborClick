class_name LuckyWheelPanel
extends CanvasLayer
## The Guindaste da Sorte: a prize crane over a belt of sealed containers,
## opened from the small key under the gantry.
##
## It was a carnival wheel, and a wheel is the one game of chance with nothing
## to do with a port — a disc turned, a pointer stopped, a word appeared. The
## rules are unchanged (`LuckyWheel`: eight prizes, the same weights, the same
## tokens) but the thing you watch is now the terminal's own: eight boxes ride
## a belt under a spreader, the belt runs and slows, the spreader drops on the
## one that stopped under it, lifts it out, and the doors come open on the
## prize. The belt slowing is the suspense and the lift is the reveal — two
## beats where the wheel had one.
##
## `_Machine` draws all of it in whole pixels; nothing is rotated or scaled.
## Everything is built once in `_ready` and only rewritten in place afterwards.

signal open_changed(opened: bool)

const TEX_ICONS := preload("res://assets/sprites/ui_wheel_icons.png")

const ICON := 14
## The belt runs for REEL seconds, then the spreader drops and lifts for GRAB.
const REEL_TIME := 3.0
const GRAB_TIME := 1.1
const SPIN_TIME := REEL_TIME + GRAB_TIME
const SPIN_LAPS := 3
const VIEW_SIZE := Vector2(216, 132)

var _service: WheelService
## True from the key press to the first frame of the rise: the state says the
## wheel is open while the board is still being measured, so nothing else can
## claim the screen in that window and a close in it is honoured.
var _opening := false
var _scrim: ColorRect
var _board: PanelContainer
var _column: VBoxContainer
var _wheel_view: _Machine
var _coin_atlas: AtlasTexture
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

	_board = UiTheme.panel(UiTheme.board_style(11, &"gold"), false)
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
	_earn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_wheel_view = _Machine.new()
	_wheel_view.custom_minimum_size = VIEW_SIZE
	_wheel_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wheel_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_wheel_view)
	_coin_atlas = AtlasTexture.new()
	_coin_atlas.atlas = TEX_ICONS
	_coin_atlas.region = Rect2(0, 0, ICON, ICON)


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
	# Laid out for real, but unseen: a hidden layer does not sort its
	# containers, so the wrapped labels kept a stale width and the board was
	# measured hundreds of pixels too tall. `pop_open` restores both alphas.
	_board.modulate.a = 0.0
	_scrim.modulate.a = 0.0
	visible = true
	_layout()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _opening:
		return
	_opening = false
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
	_wheel_view.held = posmod(int(round(_angle)), LuckyWheel.SEGMENTS.size())
	_wheel_view.grab = 1.0
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
	# The belt is measured in boxes: box i is under the spreader at offset i.
	var count := float(LuckyWheel.SEGMENTS.size())
	var current := fposmod(_angle, count)
	var delta := SPIN_LAPS * count + fposmod(float(index) - current, count)
	_wheel_view.held = -1
	_wheel_view.grab = 0.0
	if not UserPreferences.can_animate():
		_angle = current + delta
		_wheel_view.held = index
		_wheel_view.grab = 1.0
		_apply_angle()
		_finish_spin()
		return
	_angle = current
	_spinning = true
	_spin_t = 0.0
	_spin_start = _angle
	_spin_delta = delta
	_last_peg = int(round(_angle))
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
	_wheel_view.offset = _angle
	_wheel_view.queue_redraw()


func _on_peg() -> void:
	AudioManager.play_sfx("wheel_tick", 0.1, -4.0)


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
		coin.position = _wheel_view.hook_point()
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
	# Lamps round the cabinet: a slow chase idle, fast while the belt runs,
	# and a flash for a beat after a win.
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
		_wheel_view.lamps = _bulb_frame
		_wheel_view.queue_redraw()
	_wheel_view.running = _spinning and _spin_t < REEL_TIME
	_wheel_view.glow = _flash_t
	if _spinning:
		_spin_t += delta
		var t := clampf(_spin_t / REEL_TIME, 0.0, 1.0)
		# Ease-out quart: the belt leaves fast and takes its time arriving.
		_angle = _spin_start + _spin_delta * (1.0 - pow(1.0 - t, 4.0))
		var peg := int(round(_angle))
		if peg != _last_peg and t < 1.0:
			_last_peg = peg
			_on_peg()
		if _spin_t >= REEL_TIME:
			# Stopped. The spreader comes down on the box, and takes it up.
			if _wheel_view.held < 0:
				_wheel_view.held = posmod(int(round(_angle)), LuckyWheel.SEGMENTS.size())
				AudioManager.play_sfx("thunk", 0.05, -3.0)
			_wheel_view.grab = clampf((_spin_t - REEL_TIME) / GRAB_TIME, 0.0, 1.0)
		_apply_angle()
		if _spin_t >= SPIN_TIME:
			_finish_spin()
	elif _flash_t > 0.0:
		_wheel_view.queue_redraw()
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



class _Machine extends Control:
	## The cabinet: a lit frame, a belt of eight sealed boxes, and the spreader.
	const PITCH := 46.0
	const BOX := Vector2(38, 26)
	const BELT_Y := 96.0
	const RAIL_Y := 16.0
	const INK := Color8(24, 20, 30)
	const PAINTS := [Color8(196, 84, 40), Color8(44, 116, 142), Color8(54, 130, 78),
		Color8(196, 150, 40), Color8(150, 60, 110), Color8(70, 92, 160),
		Color8(120, 126, 136), Color8(190, 60, 52)]

	## Belt position, in boxes: box i is under the spreader at offset i.
	var offset := 0.0
	## The box the spreader has hold of (-1 none) and how far through the
	## drop-and-lift it is (0..0.4 down, 0.4..1 up).
	var held := -1
	var grab := 0.0
	var lamps := 0
	var running := false
	var glow := 0.0

	func _init() -> void:
		clip_contents = true

	func hook_point() -> Vector2:
		return Vector2(size.x * 0.5, RAIL_Y + 34.0)

	func _spreader_y() -> float:
		var rest := RAIL_Y + 12.0
		var down := BELT_Y - BOX.y - 5.0
		if held < 0:
			return rest
		if grab < 0.4:
			var d := grab / 0.4
			return roundf(lerpf(rest, down, d * d))
		var u := (grab - 0.4) / 0.6
		return roundf(lerpf(down, rest + 6.0, 1.0 - pow(1.0 - u, 3.0)))

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := roundf(w * 0.5)
		# Cabinet and glass.
		draw_rect(Rect2(0, 0, w, h), INK)
		draw_rect(Rect2(1, 1, w - 2, h - 2), Color8(176, 118, 18))
		draw_rect(Rect2(1, 1, w - 2, 2), Color8(240, 190, 64))
		draw_rect(Rect2(7, 7, w - 14, h - 14), INK)
		draw_rect(Rect2(8, 8, w - 16, h - 16), Color8(30, 44, 58))
		draw_rect(Rect2(8, 8, w - 16, 30), Color8(38, 58, 74))
		# The yard beyond the glass: far stacks, dim.
		for i in 7:
			draw_rect(Rect2(12 + i * 30, 54 - (i * 7 % 3) * 8, 26, 12 + (i * 7 % 3) * 8),
				Color8(36, 52, 66))
		# Belt.
		draw_rect(Rect2(8, BELT_Y, w - 16, 12), INK)
		draw_rect(Rect2(8, BELT_Y + 1, w - 16, 3), Color8(92, 100, 118))
		draw_rect(Rect2(8, BELT_Y + 4, w - 16, 7), Color8(58, 62, 78))
		var tick := fposmod(-offset * PITCH, 12.0)
		var x := 8.0 + tick
		while x < w - 8.0:
			draw_rect(Rect2(roundf(x), BELT_Y + 5, 2, 5), Color8(40, 42, 56))
			x += 12.0
		draw_rect(Rect2(8, BELT_Y + 12, w - 16, h - BELT_Y - 20), Color8(44, 40, 54))
		# Boxes. The one in the spreader rides up with it instead of the belt.
		var count := LuckyWheel.SEGMENTS.size()
		var base := int(floor(offset))
		var hook := _spreader_y()
		for step in range(-3, 4):
			var index := posmod(base + step, count)
			var bx := cx + (float(base + step) - offset) * PITCH - BOX.x * 0.5
			var by := BELT_Y - BOX.y
			var lifted := index == held and absf(float(base + step) - offset) < 0.5
			if lifted and grab >= 0.4:
				by = hook + 5.0
			_box(Vector2(roundf(bx), roundf(by)), index, lifted and grab >= 1.0)
		# The cabinet's sides again, over whatever rode in under them.
		for fx: float in [0.0, w - 8.0]:
			draw_rect(Rect2(fx, 7, 8, h - 14), Color8(176, 118, 18))
		draw_rect(Rect2(7, 7, 1, h - 14), INK)
		draw_rect(Rect2(w - 8.0, 7, 1, h - 14), INK)
		draw_rect(Rect2(0, 0, 1, h), INK)
		draw_rect(Rect2(w - 1.0, 0, 1, h), INK)
		# Rail, trolley, cable, spreader.
		draw_rect(Rect2(8, RAIL_Y, w - 16, 5), INK)
		draw_rect(Rect2(8, RAIL_Y + 1, w - 16, 2), Color8(240, 190, 52))
		draw_rect(Rect2(cx - 9, RAIL_Y - 3, 18, 10), INK)
		draw_rect(Rect2(cx - 8, RAIL_Y - 2, 16, 8), Color8(212, 84, 40))
		draw_rect(Rect2(cx - 1, RAIL_Y + 7, 2, hook - RAIL_Y - 7), Color8(170, 176, 188))
		draw_rect(Rect2(cx - 21, hook, 42, 6), INK)
		draw_rect(Rect2(cx - 20, hook + 1, 40, 3), Color8(240, 190, 52))
		for side: float in [-20.0, 17.0]:
			draw_rect(Rect2(cx + side, hook + 5, 3, 3), INK)
		# The mark on the glass: this is where it stops.
		for i in 3:
			draw_rect(Rect2(cx - 2 + i, BELT_Y + 14 + i, 5 - i * 2, 1), UiTheme.AMBER)
		# Lamps round the frame.
		var n := 0
		var lx := 12.0
		while lx < w - 10.0:
			for ly: float in [3.0, h - 5.0]:
				var on := (n + lamps) % 2 == 0
				draw_rect(Rect2(lx, ly, 2, 2), Color8(255, 236, 160) if on else Color8(120, 78, 18))
			lx += 12.0
			n += 1
		if glow > 0.0:
			draw_rect(Rect2(8, 8, w - 16, h - 16), Color(1.0, 0.92, 0.6, 0.18 * minf(1.0, glow)))

	func _box(at: Vector2, index: int, open: bool) -> void:
		var paint: Color = PAINTS[index % PAINTS.size()]
		draw_rect(Rect2(at + Vector2(2, 3), BOX), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(at, BOX), INK)
		draw_rect(Rect2(at + Vector2(1, 1), BOX - Vector2(2, 2)), paint)
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(BOX.x - 2.0, 2)), paint.lightened(0.3))
		draw_rect(Rect2(at + Vector2(1, BOX.y - 4.0), Vector2(BOX.x - 2.0, 3)), paint.darkened(0.3))
		var rx := at.x + 4.0
		while rx < at.x + BOX.x - 3.0:
			draw_rect(Rect2(rx, at.y + 4.0, 1, BOX.y - 9.0), paint.darkened(0.18))
			rx += 4.0
		# What is inside, stencilled on the door — or shown, once it is open.
		var plate := Rect2(at + Vector2((BOX.x - 18.0) * 0.5, 4.0), Vector2(18, 18))
		draw_rect(plate, INK if not open else Color8(255, 236, 160))
		draw_rect(plate.grow(-1.0), Color8(34, 30, 44) if not open else Color8(250, 244, 224))
		draw_texture_rect_region(LuckyWheelPanel.TEX_ICONS,
			Rect2(plate.position + Vector2(2, 2), Vector2(14, 14)),
			Rect2(index * 14, 0, 14, 14))
