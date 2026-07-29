class_name UiTheme
## Central place for the game's UI look: the pixel font, the nine-patch
## stylebox set and the icon atlas. Every screen builds from these so the
## whole interface stays one thing.

const FONT := preload("res://assets/fonts/harbor_font.fnt")
const ICONS := preload("res://assets/sprites/ui_icons.png")

## The bitmap font is authored at 10px; only integer multiples stay crisp.
const SIZE_SMALL := 10
const SIZE_BODY := 10
const SIZE_TITLE := 20
const SIZE_HUGE := 30

const INK := Color8(58, 44, 46)
const INK_SOFT := Color8(116, 98, 92)
const PAPER := Color8(238, 224, 198)
const CREAM := Color8(250, 240, 218)
const AMBER := Color8(252, 202, 96)
const AMBER_DEEP := Color8(232, 160, 48)
const TEAL := Color8(104, 194, 176)
const PLATE_TEXT := Color8(240, 232, 214)
const DANGER := Color8(232, 118, 96)

enum Icon { TEU, CRANE, SHIP, LAND, STAR, GEAR, SOUND, CLOCK, PAW }


static func label(text: String, size: int = SIZE_BODY,
		color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.label_settings = settings(size, color)
	return node


static func settings(size: int = SIZE_BODY, color: Color = INK,
		outline: int = 0, outline_color: Color = Color8(34, 30, 44)) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = FONT
	s.font_size = size
	s.font_color = color
	if outline > 0:
		s.outline_size = outline
		s.outline_color = outline_color
	return s


static func icon(kind: Icon, scale: int = 1) -> TextureRect:
	var node := TextureRect.new()
	node.texture = icon_texture(kind)
	node.custom_minimum_size = Vector2(12, 12) * scale
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func icon_texture(kind: Icon) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = ICONS
	at.region = Rect2(int(kind) * 12, 0, 12, 12)
	return at


static func nine(sprite: String, margin: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/sprites/%s.png" % sprite)
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(margin)
	return box


static func panel_style() -> StyleBoxTexture:
	return nine("ui_panel", 6)


static func plate_style() -> StyleBoxTexture:
	return nine("ui_plate", 6)


static func row_style(enabled: bool = true) -> StyleBoxTexture:
	return nine("ui_row" if enabled else "ui_row_off", 4)


static func apply_panel(control: Control, style: StyleBox) -> void:
	control.add_theme_stylebox_override(&"panel", style)


static func dark_panel(radius: int = 8, border: Color = Color8(82, 71, 103)) -> StyleBoxFlat:
	## Runtime surfaces stay legible even where the original paper nine-patch
	## would stretch across a desktop drawer.
	var box := StyleBoxFlat.new()
	box.bg_color = Color8(34, 30, 44)
	box.border_color = border
	box.set_border_width_all(2)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func button(text: String, kind: String = "amber",
		size: int = SIZE_BODY) -> Button:
	## Chunky pixel button. `kind`: amber | alt | off
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_override(&"font", FONT)
	node.add_theme_font_size_override(&"font_size", size)
	var sprites := {"amber": "ui_btn", "alt": "ui_btn_alt", "off": "ui_btn_off"}
	var normal_sprite: String = sprites.get(kind, "ui_btn")
	var normal := nine(normal_sprite, 4)
	var pressed := nine("ui_btn_down", 4)
	node.add_theme_stylebox_override(&"normal", normal)
	node.add_theme_stylebox_override(&"hover", normal)
	node.add_theme_stylebox_override(&"focus", normal)
	node.add_theme_stylebox_override(&"pressed", pressed)
	node.add_theme_stylebox_override(&"disabled", nine("ui_btn_off", 4))
	var text_color := INK if kind != "off" else Color8(96, 88, 96)
	node.add_theme_color_override(&"font_color", text_color)
	node.add_theme_color_override(&"font_hover_color", text_color)
	node.add_theme_color_override(&"font_pressed_color", CREAM)
	node.add_theme_color_override(&"font_disabled_color", Color8(120, 112, 118))
	return node


static func icon_button(kind: Icon, style: String = "alt") -> Button:
	var node := button("", style)
	node.custom_minimum_size = Vector2(26, 26)
	var glyph := icon(kind)
	glyph.custom_minimum_size = Vector2(20, 20)
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.offset_left = -10
	glyph.offset_top = -10
	glyph.offset_right = 10
	glyph.offset_bottom = 10
	node.add_child(glyph)
	return node
