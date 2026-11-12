class_name SpecialCallAlert
extends CanvasLayer
## The interruption: a charter on the table, with what it pays and what it costs.
##
## This replaces the contract card that used to sit in the Diário. A contract you
## can read at your leisure between two other boards is a chore; one that stops
## the game, states the stake and asks for an answer is an event.

signal accepted
signal declined
signal open_changed(opened: bool)

## An offer that is not answered goes away on its own, and the player should be
## able to see that happening.
var _board: PanelContainer
var _scroll: ScrollContainer
var _column: VBoxContainer
var _scrim: ColorRect
var _title: Label
var _brief: Label
var _reward: Label
var _penalty: Label
var _clock: Label
var _accept: Button
var _decline: Button
var _safe_rect := Rect2()
var _offer: Dictionary = {}
var _left := 0.0


func _ready() -> void:
	layer = 13
	visible = false
	_scrim = UiTheme.scrim(0.66)
	add_child(_scrim)

	_board = UiTheme.panel(UiTheme.board_style(11), false)
	add_child(_board)
	# The brief is prose, and a panel sized from wrapped prose reports a minimum
	# height in the thousands. The board takes its size from the safe area and the
	# text scrolls inside it, exactly as the crew card does.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiTheme.style_scroll(_scroll)
	_board.add_child(_scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override(&"margin_right", 4)
	_scroll.add_child(gutter)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 6)
	gutter.add_child(column)
	_column = column

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 6)
	column.add_child(head)
	head.add_child(UiTheme.icon(UiTheme.Icon.SHIP, 2))
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override(&"separation", 0)
	head.add_child(heading)
	heading.add_child(UiTheme.label("ESCALA ESPECIAL", UiTheme.SIZE_SMALL,
		UiTheme.TEAL_DEEP))
	_title = UiTheme.label("", UiTheme.SIZE_TITLE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(_title)

	_brief = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_brief)

	column.add_child(UiTheme.divider())

	_reward = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_reward)
	_penalty = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DANGER)
	_penalty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_penalty)
	_clock = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	column.add_child(_clock)

	var keys := HBoxContainer.new()
	keys.add_theme_constant_override(&"separation", 6)
	column.add_child(keys)
	_decline = UiTheme.button("RECUSAR", &"ghost", UiTheme.SIZE_SMALL)
	_decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decline.custom_minimum_size.y = UiTheme.TOUCH_MIN
	_decline.pressed.connect(_on_decline)
	keys.add_child(_decline)
	_accept = UiTheme.button("ACEITAR", &"amber", UiTheme.SIZE_SMALL)
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.custom_minimum_size.y = UiTheme.TOUCH_MIN
	_accept.pressed.connect(_on_accept)
	keys.add_child(_accept)
	_layout()


func open(offer: Dictionary, seconds: float) -> void:
	if offer.is_empty():
		return
	_offer = offer.duplicate(true)
	_left = maxf(1.0, seconds)
	_title.text = str(_offer.get("title", "Escala"))
	_brief.text = str(_offer.get("brief", ""))
	_reward.text = "Se der conta: %s" % SpecialCallDB.reward_text(_offer)
	_penalty.text = "Se falhar: %s" % SpecialCallDB.penalty_text(_offer)
	_update_clock()
	visible = true
	_layout()
	open_changed.emit(true)
	AudioManager.play_sfx("milestone", 0.02, -2.0)
	_accept.grab_focus()
	# One frame for the wrapped brief to report its true height, then the
	# board rises like every other — an interrupting call that only fades in
	# asks nobody to look up; one that slams onto the counter does.
	if is_inside_tree():
		await get_tree().process_frame
		if not visible:
			return
	_fit_now()
	UiTheme.pop_open(_board, _scrim, true)


func close() -> void:
	if not visible:
		return
	visible = false
	_offer = {}
	open_changed.emit(false)


func is_open() -> bool:
	return visible


func offer() -> Dictionary:
	return _offer.duplicate(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_left = maxf(0.0, _left - delta)
	_update_clock()
	if _left <= 0.0:
		# Timed out on screen. The director decides what that means; the board just
		# stops asking.
		_on_decline()


func _update_clock() -> void:
	_clock.text = "O armador espera resposta: %ds" % int(ceilf(_left))


func _on_accept() -> void:
	var chosen := not _offer.is_empty()
	close()
	if chosen:
		AudioManager.play_sfx("build", 0.04)
		accepted.emit()


func _on_decline() -> void:
	var chosen := not _offer.is_empty()
	close()
	if chosen:
		declined.emit()


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _layout() -> void:
	if _board == null or not is_instance_valid(_board):
		return
	var safe := _safe_rect
	if safe.size == Vector2.ZERO:
		safe = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_board.size = Vector2(minf(292.0, safe.size.x - 20.0), _cap_height(safe))
	_place(safe)


func _place(safe: Rect2) -> void:
	_board.position = safe.position + (safe.size - _board.size) * 0.5


func _cap_height(safe: Rect2) -> float:
	return minf(maxf(200.0, safe.size.y * 0.62), safe.size.y - 20.0)


func _fit_now() -> void:
	## Shrink to the brief once it has wrapped, in the caller's own frame: a
	## board must never change size while it travels, so the fit happens
	## before the rise rather than a frame into it.
	if _board == null or not is_instance_valid(_board):
		return
	var safe := _safe_rect
	if safe.size == Vector2.ZERO:
		safe = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_board.size.y = clampf(_column.get_combined_minimum_size().y + 26.0,
		180.0, _cap_height(safe))
	_place(safe)
