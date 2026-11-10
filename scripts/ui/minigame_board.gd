class_name MinigameBoard
extends CanvasLayer
## The shell every charter minigame is played on: the scrim, the board, the three
## stats across the top, the shout in the middle and the settle at the end.
##
## Only the middle of it differs between games — a well with a tower in it, a
## maze with a tractor in it — so only that is left to the subclass. Everything a
## player learns once (where the clock is, what the big word means, that the whole
## screen is the button) is learned once.

signal finished(won: bool, summary: Dictionary)
signal open_changed(opened: bool)

var _scrim: ColorRect
var _board: PanelContainer
var _column: VBoxContainer
var _title: Label
var _clock: Label
var _tally: Label
var _lives: Label
var _shout: Label
var _hint: Label
## A lost charter offers one more try for a rewarded ad, for a few seconds
## before the loss is booked. Never required: ignoring it books the loss as it
## always did.
const RETRY_WINDOW := 6.0
var _retry_button: Button
var _retry_wait := 0.0
var _retried := false
var _pending_won := false
var _pending_summary: Dictionary = {}
var _safe_rect := Rect2()
var _offer: Dictionary = {}
var _shake := 0.0
var _shout_time := 0.0
var _closing := false


func _ready() -> void:
	layer = 14
	visible = false
	_scrim = UiTheme.scrim(0.82)
	# The scrim consumes input so nothing reaches the port underneath — which also
	# means `_unhandled_input` never sees a tap on it. Games that want the whole
	# screen as their button wire it here.
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_board = UiTheme.panel(UiTheme.board_style(10), false)
	add_child(_board)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 4)
	_board.add_child(_column)

	_title = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_title.clip_text = true
	_column.add_child(_title)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 5)
	_column.add_child(stats)
	_clock = _stat(stats, UiTheme.AMBER)
	_tally = _stat(stats, UiTheme.TEAL_LIGHT)
	_lives = _stat(stats, UiTheme.DANGER)

	_build_field(_column)

	_shout = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.AMBER)
	_shout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout.clip_text = true
	_shout.modulate.a = 0.0
	_column.add_child(_shout)

	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wrapped, because a Label without it reports its whole string as a minimum
	# width and a Control cannot be laid out narrower than its minimum: one long
	# line of instructions was enough to push the board off a 320px viewport.
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_hint)

	_retry_button = UiTheme.button(Loc.t("minigame.retry"), &"steel", UiTheme.SIZE_SMALL)
	_retry_button.icon = UiTheme.icon16_texture(UiTheme.Icon16.AD)
	_retry_button.custom_minimum_size.y = UiTheme.TOUCH_MIN
	_retry_button.visible = false
	_retry_button.pressed.connect(_on_retry)
	_column.add_child(_retry_button)

	_build_controls(_column)
	_layout()


func _stat(row: HBoxContainer, colour: Color) -> Label:
	var stamp := UiTheme.stamp("", colour, UiTheme.SIZE_SMALL)
	stamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stamp)
	return UiTheme.stamp_label(stamp)


# ------------------------------------------------------------- for subclasses

func _build_field(_column_node: VBoxContainer) -> void:
	pass


func _build_controls(_column_node: VBoxContainer) -> void:
	pass


func _begin(_offer_data: Dictionary) -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_scrim_input(_event: InputEvent) -> void:
	pass


func _summary() -> Dictionary:
	return {}


func _won() -> bool:
	return false


func _over() -> bool:
	return true


func _closing_hint() -> String:
	return ""


# -------------------------------------------------------------------- shared

func open(offer: Dictionary) -> void:
	_offer = offer.duplicate(true)
	_closing = false
	_retried = false
	_retry_wait = 0.0
	if _retry_button != null:
		_retry_button.visible = false
	_shake = 0.0
	_shout_time = 0.0
	_shout.text = ""
	_shout.modulate.a = 0.0
	_title.text = str(_offer.get("title", "Escala especial"))
	visible = true
	_layout()
	# pop_open captures board.position as the resting point; the layout above
	# settles one frame after the width is set, so let it land first.
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible:
		return
	_begin(_offer)
	open_changed.emit(true)
	AudioManager.play_sfx("horn", 0.03, -3.0)
	UiTheme.pop_open(_board, _scrim)


func is_open() -> bool:
	return visible


func offer() -> Dictionary:
	return _offer.duplicate(true)


func _process(delta: float) -> void:
	if not visible:
		return
	if _retry_wait > 0.0:
		_retry_wait -= delta
		if _retry_wait <= 0.0:
			_retry_button.visible = false
			_finalize()
		return
	if not _closing:
		_tick(delta)
		if _over():
			_settle()
			return
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.4)
		# No shake under reduced motion; the board still settles on its home.
		var kick := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* _shake * 4.0 if UserPreferences.can_animate() else Vector2.ZERO
		_board.position = _board_home() + kick
	if _shout_time > 0.0:
		_shout_time = maxf(0.0, _shout_time - delta)
		_shout.modulate.a = clampf(_shout_time * 2.0, 0.0, 1.0)


func _say(text: String, colour: Color) -> void:
	_shout.text = text
	_shout.label_settings = UiTheme.settings(UiTheme.SIZE_TITLE, colour)
	_shout.modulate.a = 1.0
	_shout_time = 1.1


func _set_stats(clock: String, tally: String, lives: String) -> void:
	_clock.text = clock
	_tally.text = tally
	_lives.text = lives


func _settle() -> void:
	if _closing:
		return
	_closing = true
	var won := _won()
	_say("ESCALA FEITA!" if won else "ESCALA PERDIDA",
		UiTheme.TEAL_LIGHT if won else UiTheme.DANGER)
	_hint.text = _closing_hint()
	AudioManager.play_sfx("prestige" if won else "deny", 0.03)
	_pending_won = won
	_pending_summary = _summary()
	if not won and not _retried and AdService.available(&"minigame_retry"):
		_retried = true
		_retry_button.visible = true
		_retry_wait = RETRY_WINDOW
		return
	await get_tree().create_timer(1.35).timeout
	_finalize()


func _finalize() -> void:
	## Book the result: the board closes and the charter director is told.
	visible = false
	open_changed.emit(false)
	finished.emit(_pending_won, _pending_summary)


func _on_retry() -> void:
	if _retry_wait <= 0.0:
		return
	_retry_wait = 0.0001 + _retry_wait   # hold the window while the ad is up
	_retry_button.disabled = true
	AdService.show_rewarded(&"minigame_retry", func() -> void:
		_retry_wait = 0.0
		_retry_button.visible = false
		_retry_button.disabled = false
		_closing = false
		_begin(_offer)
		_say(Loc.t("minigame.again"), UiTheme.AMBER))


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


var _layout_pending := false


func _layout() -> void:
	if _board == null or not is_instance_valid(_board):
		return
	var safe := _safe()
	var width := minf(300.0, safe.size.x - 16.0)
	# Width first, height one frame later — the same trap as the wheel panel:
	# measured before the width propagates, the autowrapped labels report a
	# fantasy minimum height and the engine grows the board past the screen.
	_board.size = Vector2(width, _board.size.y)
	if _layout_pending:
		return
	_layout_pending = true
	await get_tree().process_frame
	_layout_pending = false
	if _board == null or not is_instance_valid(_board):
		return
	_board.size = Vector2(width,
		minf(maxf(300.0, safe.size.y * 0.82), safe.size.y - 16.0))
	_board.position = _board_home()


func _safe() -> Rect2:
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if _safe_rect.size == Vector2.ZERO:
		return view
	# Metrics can lag a window resize by a frame. Never trust a safe rect larger
	# than the live viewport: a board sized for a screen that no longer exists
	# spills off the real one (the 320x568 matrix pass caught exactly that).
	var clipped := _safe_rect.intersection(view)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else view


func _board_home() -> Vector2:
	var safe := _safe()
	return safe.position + (safe.size - _board.size) * 0.5
