class_name UiTheme
## The one place the interface is described.
##
## The interface is made of two materials, and which one a thing is made of says
## what kind of thing it is.
##
## **Steel** is the terminal itself: the gantry bolted across the top of the port
## carrying the tally and the clock, the console the keys sit on, the dark glass
## a lit number sits behind. Navy enamel, a brushed pinstripe, one amber hairline
## along the edge that faces the water. Anything permanently over the port is
## steel, so it reads as part of the terminal rather than a panel floating on it.
##
## **Paper** is the paperwork: every overlay is the foreman's clipboard — a
## weathered wooden board, a steel spring clip, manifest sheets underneath, and
## cards torn off them. Anything you *open* is paper, so it reads as something
## handed to you rather than part of the scenery.
##
## Numbers are lit amber behind glass, keys are amber, service tags are teal —
## the two accents the machines already wear out in the yard.
##
## Nothing here draws a rounded rectangle at runtime: every surface is a
## nine-patch on the pixel grid, so the UI is made of the same material as the
## port instead of floating above it as a web panel.

const FONT := preload("res://assets/fonts/harbor_font.fnt")
const ICONS := preload("res://assets/sprites/ui_icons.png")
const LEDS := preload("res://assets/sprites/ui_led.png")
const PIP := preload("res://assets/sprites/ui_pip.png")
const CLIP := preload("res://assets/sprites/ui_clip.png")

## The bitmap font is authored at 10px; only integer multiples stay crisp.
const SIZE_SMALL := 10
const SIZE_BODY := 10
const SIZE_TITLE := 20
const SIZE_HUGE := 30

# --- ink on paper ---
# Every colour used for functional text is chosen so it clears WCAG AA (4.5:1)
# against every surface it can land on. `tests/contrast_test_runner.gd` fails
# the build if that stops being true.
const INK := Color8(58, 44, 46)
const INK_SOFT := Color8(84, 68, 64)
const PAPER := Color8(238, 224, 198)
const PAPER_DEEP := Color8(206, 188, 156)
const CREAM := Color8(250, 240, 218)

# --- accents (same two the yard machines wear) ---
const AMBER := Color8(252, 202, 96)
const AMBER_DEEP := Color8(128, 78, 18)
const TEAL := Color8(44, 116, 110)
const TEAL_DEEP := Color8(28, 80, 80)
const TEAL_LIGHT := Color8(104, 194, 176)
const DANGER := Color8(150, 60, 48)

# --- enamelled navy steel: the HUD's own material ---
## The gantry, the console and the keys bolted to them. Dark enough that cream
## and amber both clear AA on it, blue enough that it never reads as a grey box
## over the warm greys of the yard.
const HULL := Color8(42, 54, 74)
const HULL_DEEP := Color8(28, 37, 54)
const HULL_EDGE := Color8(16, 22, 34)
## The dark glass a lit number sits behind, and the two inks that light up on it.
const GLASS := Color8(25, 31, 46)
const DIGIT := Color8(252, 202, 96)
## Text on steel. `STEEL_DIM` is the quiet one — deliberately lighter than
## `SLATE_DIM`, which is tuned for the near-black slate of a price stamp and
## drops under AA on the lighter navy.
const STEEL_TEXT := Color8(226, 232, 242)
const STEEL_DIM := Color8(176, 190, 212)

## Surfaces text is allowed to land on, keyed by the sprite that draws them.
## Kept next to the ink so a palette change and its contrast proof stay in one
## place.
const SURFACE := {
	&"card": Color8(238, 224, 198),
	&"card_ready": Color8(250, 240, 218),
	&"card_locked": Color8(200, 190, 176),
	&"sheet": Color8(206, 188, 156),
	&"slate": Color8(34, 30, 44),
	&"btn_amber": Color8(232, 160, 48),
	&"btn_alt": Color8(44, 116, 110),
	&"btn_danger": Color8(150, 60, 48),
	&"btn_ghost": Color8(238, 224, 198),
	&"btn_off": Color8(176, 166, 154),
	&"seg_off": Color8(224, 210, 184),
	&"tab_off": Color8(196, 178, 150),
	&"gantry": Color8(42, 54, 74),
	&"glass": Color8(25, 31, 46),
	&"tag": Color8(28, 37, 54),
	&"btn_steel": Color8(42, 54, 74),
}

# --- the slate a number is stamped on ---
const SLATE := Color8(34, 30, 44)
const SLATE_TEXT := Color8(240, 232, 214)
const SLATE_DIM := Color8(150, 140, 154)

## Anything smaller than this is not a reliable touch target.
const TOUCH_MIN := 44.0

enum Icon {
	TEU, CRANE, SHIP, LAND, STAR, GEAR, SOUND, CLOCK, PAW,
	GLOVE, GLOBE, LOCK, CHECK, CLOSE, CHEVRON, TRUCK, TROPHY, BELL,
}

const ICON_COUNT := 18


# ---------------------------------------------------------------- typography

static func label(text: String, size: int = SIZE_BODY,
		color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.label_settings = settings(size, color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func settings(size: int = SIZE_BODY, color: Color = INK,
		outline: int = 0, outline_color: Color = Color8(26, 23, 34)) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = FONT
	s.font_size = size
	s.font_color = color
	if outline > 0:
		s.outline_size = outline
		s.outline_color = outline_color
	return s


static func apply_font(control: Control, size: int = SIZE_BODY) -> void:
	control.add_theme_font_override(&"font", FONT)
	control.add_theme_font_size_override(&"font_size", size)


# --------------------------------------------------------------------- icons

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


# ------------------------------------------------------------------ surfaces

static func nine(sprite: String, margin: int,
		content: int = -1) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/sprites/%s.png" % sprite)
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(margin if content < 0 else content)
	# Tiled, not stretched. A stretched centre smears one row of pixels across
	# the whole panel, which is why the paper could never carry fibre or ruling
	# before — every surface had to be a flat colour to survive being widened.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box


static func board_style(content: int = 12) -> StyleBoxTexture:
	## The clipboard itself: wood with grain, steel corner protectors, and the
	## manifest sunk into a well.
	return nine("ui_board", 12, content)


static func paper_style(content: int = 5) -> StyleBoxTexture:
	## A ruled manifest sheet, for regions already inside a board.
	return nine("ui_paper", 5, content)


static func card_style(state: StringName = &"normal") -> StyleBoxTexture:
	## `normal` | `ready` (affordable) | `locked` | `done`
	match state:
		&"ready":
			return nine("ui_card_hi", 5, 6)
		&"locked":
			return nine("ui_card_off", 5, 6)
		&"done":
			return nine("ui_card_done", 5, 6)
		_:
			return nine("ui_card", 5, 6)


static func slate_style(lit: bool = false, content: int = 4) -> StyleBoxTexture:
	## Dark readout. Numbers live here so they never sit on textured paper.
	return nine("ui_slate_lit" if lit else "ui_slate", 5, content)


static func well_style(content: int = 3) -> StyleBoxTexture:
	## Recessed socket a port sprite sits in.
	return nine("ui_well", 5, content)


static func gantry_style() -> StyleBoxTexture:
	## The enamel panel bolted across the top of the port. Its amber hairline is
	## on the bottom edge, so the content margin there is thicker: text sitting on
	## the stripe would read as an underline nobody asked for.
	var box := nine("ui_gantry", 11, 4)
	box.content_margin_bottom = 6
	return box


static func console_style() -> StyleBoxTexture:
	## The same panel at the bottom of the screen, with the hairline on the top
	## edge instead. It is what the keys are bolted to.
	var box := nine("ui_console", 11, 4)
	box.content_margin_top = 6
	return box


static func glass_style(content: int = 4) -> StyleBoxTexture:
	## Dark glass set into steel. A tally is an instrument, not a caption, so its
	## digits are lit behind this rather than printed on the panel.
	return nine("ui_glass", 5, content)


static func tag_style(content: int = 4) -> StyleBoxTexture:
	## The enamel job tag that hangs off the gantry, with a teal service spine.
	## Whatever the berth is doing is the one line that changes every few seconds,
	## so it gets an object of its own instead of a slab of the bar.
	var box := nine("ui_tag", 5, content)
	box.content_margin_left = 7
	return box


enum Led { OFF, RUNNING, ATTENTION }


static func led(state: Led = Led.OFF) -> TextureRect:
	## The lamp a control panel uses when there is no room for a word.
	var node := TextureRect.new()
	node.texture = led_texture(state)
	node.custom_minimum_size = Vector2(8, 8)
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func led_texture(state: Led) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = LEDS
	at.region = Rect2(int(state) * 8, 0, 8, 8)
	return at


static func pip() -> TextureRect:
	## The amber dot that says a key has something waiting behind it.
	var node := TextureRect.new()
	node.texture = PIP
	node.custom_minimum_size = Vector2(6, 6)
	node.size = node.custom_minimum_size
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


const PORTRAITS := preload("res://assets/sprites/portrait_sheet.png")
const PORTRAIT_HAT := preload("res://assets/sprites/portrait_hat.png")
const BADGE_CLIP := preload("res://assets/sprites/ui_badge_clip.png")
const PORTRAIT_SIZE := Vector2(24, 28)
const PORTRAIT_COUNT := 6


static func badge_style(content: int = 6) -> StyleBoxTexture:
	## The laminated staff card. The one overlay that is not paper off the
	## manifest, because it is not paperwork: it is the thing clipped to the
	## person's vest.
	return nine("ui_badge", 5, content)


static func badge_head_style() -> StyleBoxTexture:
	return nine("ui_badge_head", 4, 4)


static func photo_style() -> StyleBoxTexture:
	## The white print border a badge photograph is mounted in. The content inset
	## is what makes it a border: at zero the picture is laid over the frame and
	## the mount may as well not be drawn.
	return nine("ui_photo", 4, 4)


static func portrait(index: int, hat: Color = Color(0, 0, 0, 0),
		wears_hat: bool = true, scale: int = 2) -> Control:
	## One staff photograph, at an integer multiple of its authored size.
	##
	## The hard hat is a separate greyscale overlay so a named crew member's
	## helmet colour multiplies into a shaded hat instead of flattening it. An
	## unset colour means the standard yellow everybody else wears; `wears_hat`
	## is for the two roles that never put one on.
	var frame := Control.new()
	frame.custom_minimum_size = PORTRAIT_SIZE * scale
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := _portrait_layer(PORTRAITS,
		Rect2(Vector2(posmod(index, PORTRAIT_COUNT) * PORTRAIT_SIZE.x, 0.0),
			PORTRAIT_SIZE), scale)
	frame.add_child(face)
	if not wears_hat:
		return frame
	var helmet := _portrait_layer(PORTRAIT_HAT,
		Rect2(Vector2.ZERO, PORTRAIT_SIZE), scale)
	helmet.modulate = hat if hat.a > 0.0 else Color8(240, 196, 66)
	frame.add_child(helmet)
	return frame


static func _portrait_layer(atlas: Texture2D, region: Rect2,
		scale: int) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = atlas
	at.region = region
	var node := TextureRect.new()
	node.texture = at
	node.custom_minimum_size = PORTRAIT_SIZE * scale
	node.size = node.custom_minimum_size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func portrait_index(profile: NpcProfile) -> int:
	## Stable per person: the same operator has the same face for the whole run,
	## and across a reload, because it is derived from the identity rather than
	## rolled when the card opens.
	if profile == null:
		return 0
	var key := profile.uid if not profile.uid.is_empty() else profile.slot
	return posmod(key.hash(), PORTRAIT_COUNT)


static func badge_clip() -> TextureRect:
	## The bulldog clip the card hangs from.
	var node := TextureRect.new()
	node.texture = BADGE_CLIP
	node.custom_minimum_size = BADGE_CLIP.get_size()
	node.size = BADGE_CLIP.get_size()
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func tab_style(active: bool) -> StyleBoxTexture:
	return nine("ui_tab_on" if active else "ui_tab_off", 5, 5)


static func bar_styles() -> Array[StyleBoxTexture]:
	return [nine("ui_bar_bg", 4, 1), nine("ui_bar_fill", 4, 1)]


static func apply_panel(control: Control, style: StyleBox) -> void:
	control.add_theme_stylebox_override(&"panel", style)


static func panel(style: StyleBox, ignore_mouse: bool = true) -> PanelContainer:
	var node := PanelContainer.new()
	apply_panel(node, style)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE if ignore_mouse \
		else Control.MOUSE_FILTER_STOP
	return node


static func scrim(alpha: float = 0.74) -> ColorRect:
	## Full-screen dim behind a modal. It always consumes the event, so closing
	## an overlay can never reach the port underneath.
	var node := ColorRect.new()
	node.color = Color(0.055, 0.045, 0.078, alpha)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node


const CLIP_SIZE := Vector2(72, 22)


static func clip_badge() -> TextureRect:
	## The steel spring clip that tops every board.
	var node := TextureRect.new()
	node.texture = CLIP
	node.custom_minimum_size = CLIP_SIZE
	node.size = CLIP_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func desk_prop(sprite: String, rotation_degrees: float = 0.0) -> TextureRect:
	## A loose object resting on the paper. Ornament, and worth it: a board with
	## nothing but printed rows reads as a form, one with a pencil across it
	## reads as something a person was just holding.
	var node := TextureRect.new()
	node.texture = load("res://assets/sprites/%s.png" % sprite)
	node.custom_minimum_size = node.texture.get_size()
	node.size = node.texture.get_size()
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.pivot_offset = node.size * 0.5
	node.rotation_degrees = rotation_degrees
	return node


static func place_clip(clip: TextureRect, board: Control, safe: Rect2) -> void:
	## Straddles the board's top edge, and stands down entirely when the board
	## is tall enough to reach the top of the safe area — a clip drawn over the
	## status bar or the TEU readout is worse than no clip.
	var top := board.position.y - 11.0
	# It needs real air above it. A clip drawn into the top strip of the screen
	# lands on the status bar or the TEU readout, which is worse than no clip.
	clip.visible = board.visible and top >= safe.position.y + 26.0
	clip.position = Vector2(
		board.position.x + (board.size.x - CLIP_SIZE.x) * 0.5, top)


# ------------------------------------------------------------------ controls

const _BUTTON_SPRITES := {
	&"amber": "ui_btn", &"alt": "ui_btn_alt", &"ghost": "ui_btn_ghost",
	&"off": "ui_btn_off", &"danger": "ui_btn_danger", &"steel": "ui_btn_steel",
}
const _BUTTON_TEXT := {
	&"amber": INK, &"alt": CREAM, &"ghost": INK,
	&"off": INK, &"danger": CREAM, &"steel": STEEL_TEXT,
}
## A key sinks into its own material when pressed. Amber sinking into amber is
## the default; a steel key on a steel console needs its own darker face, or
## pressing it flashes an unrelated colour.
const _BUTTON_DOWN := {&"steel": "ui_btn_steel_down"}


static func button(text: String, kind: StringName = &"amber",
		size: int = SIZE_BODY) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_ALL
	node.accessibility_name = text
	apply_font(node, size)
	style_button(node, kind)
	return node


static func install_window_theme(window: Window) -> void:
	## The engine draws a few things for itself, and until now they were the only
	## parts of the interface the game had not drawn: Godot's stock tooltip is a
	## grey rounded slab in the default sans font, which over a pixel port reads
	## as a screenshot of a different program.
	##
	## A Theme on the `Window` is the only place that reaches them, because a
	## tooltip is a popup the engine parents to the window rather than to the
	## control that asked for it.
	if window == null or window.theme != null:
		return
	var theme := Theme.new()
	theme.set_stylebox(&"panel", &"TooltipPanel", nine("ui_tag", 5, 5))
	theme.set_font(&"font", &"TooltipLabel", FONT)
	theme.set_font_size(&"font_size", &"TooltipLabel", SIZE_SMALL)
	theme.set_color(&"font_color", &"TooltipLabel", STEEL_TEXT)
	# The default label draws a soft drop shadow, which on a bitmap font is a
	# smear one pixel off the glyph rather than a shadow.
	theme.set_color(&"font_shadow_color", &"TooltipLabel", Color(0, 0, 0, 0))
	theme.set_constant(&"shadow_offset_x", &"TooltipLabel", 0)
	theme.set_constant(&"shadow_offset_y", &"TooltipLabel", 0)
	theme.set_constant(&"outline_size", &"TooltipLabel", 0)
	window.theme = theme


static func describe(control: Control, control_name: String,
		description: String = "") -> void:
	## A screen reader has no icon to look at, and a tooltip only exists for a
	## mouse. Anything whose label is a picture needs to say what it is here.
	control.accessibility_name = control_name
	if not description.is_empty():
		control.accessibility_description = description
	if control.tooltip_text.is_empty():
		control.tooltip_text = control_name


static func focus_first(root: Node) -> Control:
	## Depth-first, so opening an overlay lands the caret on its first real
	## control rather than leaving focus behind on the button that opened it.
	for child in root.get_children():
		var control := child as Control
		if control != null and control.focus_mode == Control.FOCUS_ALL \
				and control.is_visible_in_tree() and not control.is_queued_for_deletion():
			control.grab_focus()
			return control
		var found := focus_first(child)
		if found != null:
			return found
	return null


static func restore_focus(control: Control) -> void:
	## Closing an overlay must hand the caret back where it came from, or
	## keyboard users are dumped at the top of the tree every time.
	if control != null and is_instance_valid(control) \
			and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL:
		control.grab_focus()


static func style_button(node: Button, kind: StringName) -> void:
	## Restyling in place keeps signal connections and focus state intact.
	var normal := nine(str(_BUTTON_SPRITES.get(kind, "ui_btn")), 5, 5)
	node.add_theme_stylebox_override(&"normal", normal)
	node.add_theme_stylebox_override(&"hover", normal)
	node.add_theme_stylebox_override(&"pressed",
		nine(str(_BUTTON_DOWN.get(kind, "ui_btn_down")), 5, 5))
	node.add_theme_stylebox_override(&"disabled", nine("ui_btn_off", 5, 5))
	node.add_theme_stylebox_override(&"focus", _focus_style())
	var text_color: Color = _BUTTON_TEXT.get(kind, INK)
	node.add_theme_color_override(&"font_color", text_color)
	node.add_theme_color_override(&"font_hover_color", text_color)
	node.add_theme_color_override(&"font_pressed_color", CREAM)
	node.add_theme_color_override(&"font_focus_color", text_color)
	# WCAG 1.4.3 exempts inactive controls from the contrast floor, but a key
	# nobody can read is still a bad key, so it stays as legible as a disabled
	# state is allowed to look.
	node.add_theme_color_override(&"font_disabled_color", Color8(86, 78, 74))
	# The glyph on a key follows the key's own text colour. Leaving it white
	# made an amber star on a cream ghost key read as an empty box.
	node.add_theme_color_override(&"icon_normal_color", text_color)
	node.add_theme_color_override(&"icon_hover_color", text_color)
	node.add_theme_color_override(&"icon_pressed_color", CREAM)
	node.add_theme_color_override(&"icon_focus_color", text_color)
	node.add_theme_color_override(&"icon_disabled_color", Color8(120, 112, 104))


## The two tones of the focus ring. A single colour cannot be visible on both
## cream paper and near-black slate, so the ring carries one of each and
## whichever surface it lands on, one of them reads.
const FOCUS_OUTER := INK
const FOCUS_INNER := CREAM


static func focus_ring() -> StyleBoxTexture:
	return _focus_style()


static func _focus_style() -> StyleBoxTexture:
	## Keyboard focus must not depend on colour alone, so it is a hollow ring
	## drawn outside the key rather than a tint of it.
	var box := nine("ui_focus", 4, 0)
	box.expand_margin_left = 2
	box.expand_margin_right = 2
	box.expand_margin_top = 2
	box.expand_margin_bottom = 2
	return box


static func icon_button(kind: Icon, style: StringName = &"alt",
		size: float = TOUCH_MIN, control_name: String = "") -> Button:
	var node := button("", style)
	node.custom_minimum_size = Vector2(size, size)
	node.size = node.custom_minimum_size
	node.icon = icon_texture(kind)
	node.expand_icon = false
	node.add_theme_constant_override(&"icon_max_width", 20)
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not control_name.is_empty():
		describe(node, control_name)
	return node


static func segment(text: String, active: bool) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_ALL
	node.accessibility_name = text
	apply_font(node, SIZE_SMALL)
	style_segment(node, active)
	return node


static func style_segment(node: Button, active: bool) -> void:
	var sprite := "ui_seg_on" if active else "ui_seg_off"
	var box := nine(sprite, 4, 4)
	node.add_theme_stylebox_override(&"normal", box)
	node.add_theme_stylebox_override(&"hover", box)
	node.add_theme_stylebox_override(&"pressed", nine("ui_seg_on", 3, 3))
	node.add_theme_stylebox_override(&"focus", _focus_style())
	var color := INK if active else INK_SOFT
	node.add_theme_color_override(&"font_color", color)
	node.add_theme_color_override(&"font_hover_color", INK)
	node.add_theme_color_override(&"font_pressed_color", INK)
	node.add_theme_color_override(&"font_focus_color", color)


static func style_tab(node: Button, active: bool) -> void:
	var box := tab_style(active)
	node.add_theme_stylebox_override(&"normal", box)
	node.add_theme_stylebox_override(&"hover", box)
	node.add_theme_stylebox_override(&"pressed", tab_style(true))
	node.add_theme_stylebox_override(&"focus", _focus_style())
	var color := INK if active else Color8(66, 52, 44)
	node.add_theme_color_override(&"font_color", color)
	node.add_theme_color_override(&"font_hover_color", INK)
	node.add_theme_color_override(&"font_pressed_color", INK)
	node.add_theme_color_override(&"font_focus_color", color)


const SCROLL_WIDTH := 8.0


static func style_scroll(scroll: ScrollContainer) -> void:
	## Godot's default scrollbar is a flat grey slab; this one is a sunk trough
	## with a wooden grip, and it is always reserved rather than overlaid.
	##
	## `SCROLL_MODE_RESERVE` is the point: on AUTO the bar appears only when the
	## content overflows and is drawn over the last few pixels of every card,
	## which is exactly the "scroll in front, half broken" the playtest saw.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	var bar := scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.add_theme_stylebox_override(&"scroll", nine("ui_scroll_bg", 4, 0))
	for state in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		bar.add_theme_stylebox_override(state, nine("ui_scroll_grab", 4, 0))
	bar.custom_minimum_size.x = SCROLL_WIDTH


# ----------------------------------------------------------------- fragments

static func stamp(text: String, color: Color = AMBER,
		size: int = SIZE_BODY, lit: bool = false) -> PanelContainer:
	## A number pressed into dark slate. Returns the panel; the label is its
	## only child, so callers keep a reference with `stamp_label()`.
	var box := panel(slate_style(lit, 3))
	var value := label(text, size, color)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(value)
	return box


static func stamp_label(node: PanelContainer) -> Label:
	return node.get_node(^"Value") as Label


static func divider() -> Control:
	var line := ColorRect.new()
	line.color = PAPER_DEEP
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
