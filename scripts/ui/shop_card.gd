class_name ShopCard
extends PanelContainer
## One buyable row on the manifest: icon, name + blurb, price and owned count.

signal pressed_card(id: String)

var id: String = ""
var kind: String = "structure"

var _name_label: Label
var _desc_label: Label
var _cost_label: Label
var _count_label: Label
var _icon: TextureRect
var _affordable := false


func setup(item_id: String, item_kind: String, icon_path: String,
		title: String, description: String) -> void:
	id = item_id
	kind = item_kind
	custom_minimum_size.y = 40.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.apply_panel(self, UiTheme.row_style(true))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	# icon sits on its own dark chip so every sprite reads at a glance
	var chip := PanelContainer.new()
	UiTheme.apply_panel(chip, UiTheme.plate_style())
	chip.custom_minimum_size = Vector2(34, 34)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
	chip.add_child(_icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override(&"separation", 0)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	_name_label = UiTheme.label(title, UiTheme.SIZE_BODY, UiTheme.INK)
	text_col.add_child(_name_label)

	_desc_label = UiTheme.label(description, UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	_desc_label.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size.x = 150.0
	text_col.add_child(_desc_label)

	var price_col := VBoxContainer.new()
	price_col.alignment = BoxContainer.ALIGNMENT_CENTER
	price_col.add_theme_constant_override(&"separation", 0)
	price_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_col)

	_cost_label = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.AMBER_DEEP)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_col.add_child(_cost_label)

	_count_label = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.INK)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_col.add_child(_count_label)


func refresh(cost: float, count: int, affordable: bool, sold_out: bool = false) -> void:
	_affordable = affordable
	_cost_label.text = "PRONTO" if sold_out else GameState.fmt(cost)
	_count_label.text = str(count) if count > 0 else ""
	_cost_label.label_settings.font_color = \
		UiTheme.AMBER_DEEP if affordable else Color8(150, 136, 128)
	UiTheme.apply_panel(self, UiTheme.row_style(affordable or sold_out))
	_name_label.label_settings.font_color = \
		UiTheme.INK if (affordable or sold_out) else Color8(122, 112, 106)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		pressed_card.emit(id)


func flash_ok() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.45, 1.2), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.24)


func shake_deny() -> void:
	var origin := position.x
	var tween := create_tween()
	for offset in [3.0, -3.0, 2.0, -2.0, 0.0]:
		tween.tween_property(self, "position:x", origin + offset, 0.04)
