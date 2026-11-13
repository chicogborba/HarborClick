class_name XrayPanel
extends CanvasLayer
## The scanner's board: buy it, see when the next inspection is due, start
## one. Built once and rewritten in place twice a second — never rebuilt, so
## the button under a finger survives the per-frame income tick.

signal inspect_requested
signal open_changed(opened: bool)

const PORTAL := preload("res://assets/sprites/ui_xray_portal.png")

var _service: XrayService
var _scrim: ColorRect
var _board: PanelContainer
var _portal: AtlasTexture
var _pitch: Label
var _status: Label
var _stats: Label
var _action: Button
var _safe_rect := Rect2()
var _tick := 0.0


func _ready() -> void:
	layer = 13
	visible = false
	_scrim = UiTheme.scrim(0.66)
	_scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed:
			close())
	add_child(_scrim)
	_board = UiTheme.panel(UiTheme.board_style(10, &"steel"), false)
	add_child(_board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_board.add_child(column)
	column.add_child(UiTheme.header(Loc.t("xray.panel.title"), close).root)

	var art := TextureRect.new()
	_portal = AtlasTexture.new()
	_portal.atlas = PORTAL
	_portal.region = Rect2(0, 0, 44, 36)
	art.texture = _portal
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(88, 72)
	column.add_child(art)
	var brand := UiTheme.label("CREATUS SECURITY e VWI", UiTheme.SIZE_SMALL,
		UiTheme.TEAL_DEEP)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(brand)

	_pitch = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pitch.custom_minimum_size.x = 200.0
	column.add_child(_pitch)
	column.add_child(UiTheme.divider())
	_status = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_stats = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_stats)
	_action = UiTheme.button("", &"amber", UiTheme.SIZE_SMALL)
	_action.custom_minimum_size.y = UiTheme.TOUCH_MIN
	_action.pressed.connect(_on_action)
	column.add_child(_action)
	column.minimum_size_changed.connect(_layout)
	_layout()


func setup(service: XrayService) -> void:
	_service = service
	if not _service.state_changed.is_connected(_refresh):
		_service.state_changed.connect(_refresh)


func open() -> void:
	if _service == null:
		return
	visible = true
	_refresh()
	_layout()
	open_changed.emit(true)
	AudioManager.play_sfx("ui_open", 0.02)
	# The panel folds to its content synchronously (`reset_size` in `_layout`),
	# so nothing has to settle first: it rises like every other board.
	UiTheme.pop_open(_board, _scrim)
	_action.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	open_changed.emit(false)
	AudioManager.play_sfx("ui_close", 0.02)


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		_refresh()


func _refresh() -> void:
	if _service == null or _pitch == null:
		return
	var policy := _service.policy
	_portal.region = Rect2(44 if policy.ready else 0, 0, 44, 36)
	if not policy.owned:
		_pitch.text = Loc.t("xray.panel.pitch")
		_status.text = Loc.t("xray.panel.price",
			{"price": GameState.fmt(_service.price())})
		_stats.text = ""
		_action.text = Loc.t("xray.panel.buy")
		_action.disabled = not _service.can_buy()
		return
	_pitch.text = Loc.t("xray.panel.owned")
	if policy.ready:
		_status.text = Loc.t("xray.panel.due")
		_action.text = Loc.t("xray.panel.inspect")
		_action.disabled = false
	else:
		var left := int(ceilf(policy.until_next))
		_status.text = Loc.t("xray.panel.next",
			{"time": "%d:%02d" % [left / 60, left % 60]})
		_action.text = Loc.t("xray.panel.wait")
		_action.disabled = true
	_stats.text = Loc.t("xray.panel.stats", {"played": str(policy.played),
		"won": str(policy.won), "streak": str(policy.best_streak)})


func _on_action() -> void:
	if _service == null:
		return
	if not _service.owned():
		if _service.buy():
			AudioManager.play_sfx("build", 0.03)
			EventBus.notification_requested.emit({"id": "xray_bought",
				"kind": &"unlock", "priority": 2, "text": Loc.t("xray.bought")})
		else:
			AudioManager.play_sfx("deny")
		_refresh()
		return
	if _service.is_due():
		close()
		inspect_requested.emit()


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _layout() -> void:
	if _board == null or not is_instance_valid(_board):
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var width := minf(290.0, safe.size.x - 20.0)
	_pitch.custom_minimum_size.x = width - 32.0
	_board.size = Vector2(width, 0.0)
	_board.reset_size()
	_board.size.x = width
	_board.size.y = minf(_board.size.y, safe.size.y - 20.0)
	_board.position = (safe.position + (safe.size - _board.size) * 0.5).round()
