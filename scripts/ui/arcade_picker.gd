class_name ArcadePicker
extends CanvasLayer
## The arcade cabinet: pick which machine to play.
##
## The Arcade key used to roll a game at random behind a rewarded ad, so the
## player paid for a surprise and never saw what the games were. Now the key
## opens this — one card per game with its cover art, its name and one line of
## what it is — and the card you tap is the game you get.

signal picked(game: StringName)
signal open_changed(opened: bool)

const ART := preload("res://assets/sprites/ui_minigame_art.png")
const ART_SIZE := Vector2(112, 56)

var _scrim: ColorRect
var _board: PanelContainer
var _column: VBoxContainer
var _safe_rect := Rect2()


static func cover(game: StringName) -> AtlasTexture:
	## The game's cover, for anything that offers it (this picker, the charter
	## alert). Unknown games show the stacker's.
	var atlas := AtlasTexture.new()
	atlas.atlas = ART
	var frame := int(SpecialCallDB.COVER.get(game, 0))
	atlas.region = Rect2(Vector2(frame * ART_SIZE.x, 0), ART_SIZE)
	return atlas


static func game_name(game: StringName) -> String:
	return Loc.t("game.%s.name" % String(game))


static func game_desc(game: StringName) -> String:
	return Loc.t("game.%s.desc" % String(game))


func _ready() -> void:
	layer = 13
	visible = false
	_scrim = UiTheme.scrim(0.7)
	_scrim.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			close())
	add_child(_scrim)
	_board = UiTheme.panel(UiTheme.arcade_style(9), false)
	add_child(_board)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 6)
	_board.add_child(_column)
	var header := UiTheme.header(Loc.t("arcade.cabinet"), close, UiTheme.Icon.TROPHY)
	_column.add_child(header.root)
	var sub := UiTheme.label(Loc.t("arcade.pick"), UiTheme.SIZE_SMALL, UiTheme.AMBER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(sub)
	for game: StringName in SpecialCallDB.GAMES:
		_column.add_child(_card(game))
	_layout()


func _card(game: StringName) -> Control:
	var key := Button.new()
	key.name = "Card_%s" % String(game)
	key.focus_mode = Control.FOCUS_ALL
	key.custom_minimum_size = Vector2(0, ART_SIZE.y + 10.0)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		key.add_theme_stylebox_override(state, UiTheme.card_style(
			&"ready" if state in [&"hover", &"focus", &"pressed"] else &"normal"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_top = 5
	row.offset_right = -5
	row.offset_bottom = -5
	key.add_child(row)
	var art := TextureRect.new()
	art.texture = cover(game)
	art.custom_minimum_size = ART_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := UiTheme.label(game_name(game), UiTheme.SIZE_BODY, UiTheme.INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var desc := UiTheme.label(game_desc(game), UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(desc)
	UiTheme.describe(key, game_name(game), game_desc(game))
	key.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		close()
		picked.emit(game))
	return key


func open() -> void:
	visible = true
	_layout()
	open_changed.emit(true)
	AudioManager.play_sfx("ui_open", 0.02)
	await get_tree().process_frame
	if not visible:
		return
	_fit()
	UiTheme.pop_open(_board, _scrim, true)
	var first := _column.get_node_or_null(NodePath("Card_%s" % String(SpecialCallDB.GAMES[0])))
	if first != null:
		(first as Control).grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	open_changed.emit(false)


func is_open() -> bool:
	return visible


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _safe() -> Rect2:
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if _safe_rect.size == Vector2.ZERO:
		return view
	var clipped := _safe_rect.intersection(view)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else view


func _layout() -> void:
	if _board == null:
		return
	var safe := _safe()
	_board.size = Vector2(minf(300.0, safe.size.x - 16.0), _board.size.y)
	_fit()


func _fit() -> void:
	var safe := _safe()
	_board.size.y = minf(_column.get_combined_minimum_size().y + 24.0, safe.size.y - 16.0)
	_board.position = (safe.position + (safe.size - _board.size) * 0.5).round()
