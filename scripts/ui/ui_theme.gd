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
## **Container** is everything you open: a board is the end wall of a shipping
## container — corrugated steel in one of the yard's liveries, a cream manifest
## sheet sunk into it, hung from a crane spreader. Cards are cargo labels and
## the price is a green key. How any of it moves is `UiMotion`.
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

# --- ink on the manifest sheet ---
# Every colour used for functional text is chosen so it clears WCAG AA (4.5:1)
# against every surface it can land on. `tests/contrast_test_runner.gd` fails
# the build if that stops being true.
# `KEY_INK` is the label on an amber key.
const INK := Color8(58, 44, 46)
const INK_SOFT := Color8(84, 68, 64)
const PAPER := Color8(244, 232, 206)
const PAPER_DEEP := Color8(210, 190, 154)
const CREAM := Color8(250, 240, 218)
const KEY_INK := Color8(44, 30, 22)
## The diaries are still bound paper: these are the inks that go on a page.
const BOOK_INK := Color8(58, 44, 46)
const BOOK_INK_SOFT := Color8(84, 68, 64)

# --- accents (same two the yard machines wear) ---
# The *_DEEP pair are the accents as text on the sheet.
const AMBER := Color8(252, 202, 96)
const AMBER_DEEP := Color8(128, 78, 18)
const TEAL := Color8(44, 116, 110)
const TEAL_DEEP := Color8(28, 80, 80)
const TEAL_LIGHT := Color8(104, 194, 176)
const DANGER := Color8(150, 60, 48)

# --- hull-green enamelled steel: the HUD's own material ---
## The gantry, the console and the keys bolted to them. Dark enough that cream
## and amber both clear AA on it, blue enough that it never reads as a grey box
## over the warm greys of the yard.
const HULL := Color8(28, 68, 76)
const HULL_DEEP := Color8(18, 48, 56)
const HULL_EDGE := Color8(10, 30, 36)
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
	&"card": Color8(244, 232, 206),
	&"card_ready": Color8(255, 248, 228),
	&"card_locked": Color8(218, 206, 186),
	&"card_done": Color8(212, 234, 216),
	&"sheet": Color8(228, 210, 174),
	&"slate": Color8(34, 30, 44),
	&"btn_amber": Color8(232, 160, 48),
	&"btn_alt": Color8(44, 116, 110),
	&"btn_go": Color8(36, 114, 52),
	&"btn_danger": Color8(150, 60, 48),
	&"btn_ghost": Color8(244, 232, 206),
	&"btn_off": Color8(214, 198, 170),
	&"seg_off": Color8(232, 218, 190),
	&"tab_on": Color8(255, 248, 228),
	&"tab_off": Color8(210, 188, 152),
	&"header": Color8(200, 88, 38),
	&"gantry": Color8(28, 68, 76),
	&"glass": Color8(25, 31, 46),
	&"tag": Color8(18, 48, 56),
	&"btn_steel": Color8(28, 68, 76),
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
	CHAT, CREW, TRAIN,
}

const ICON_COUNT := 21

## The 16x16 outlined sheet (`tools/sprites/gen_icons16.py`, same order): the
## icons the new HUD reads alone, with no label beside them. The 12px sheet
## above stays for the controls already built on it.
enum Icon16 {
	LEVEL, XP, AD, BOOST, COMBO, BUILD, SKILL_OVERTIME, SKILL_MUTIRAO,
	SKILL_PILOT, ALBUM, MISSION, TOKEN, TAP, SHIP, TEU, GEAR,
}
const ICONS16 := preload("res://assets/sprites/ui_icons16.png")


## The command rail's glyphs, drawn at 24px for the size they are shown at
## (`tools/sprites/gen_hud24.py`). Order matches the sheet.
enum Hud24 { SHOP, ROUTES, LOGBOOK, SETTINGS, TROPHY }
const HUD24 := preload("res://assets/sprites/ui_hud24.png")


static func hud24(kind: Hud24) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = HUD24
	atlas.region = Rect2(int(kind) * 24, 0, 24, 24)
	var node := TextureRect.new()
	node.texture = atlas
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.custom_minimum_size = Vector2(24, 24)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func icon16_texture(kind: Icon16) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = ICONS16
	at.region = Rect2(int(kind) * 16, 0, 16, 16)
	return at


static func icon16(kind: Icon16, scale: int = 1) -> TextureRect:
	var node := TextureRect.new()
	node.texture = icon16_texture(kind)
	node.custom_minimum_size = Vector2(16, 16) * scale
	# Exactly its own square, wherever it is put: left to fill a row it was
	# stretched to the row's height and the pixels came out unequal.
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


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
	# Never stretched by a tall row: next to wrapped text an icon used to become
	# a smear the height of the paragraph.
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


static func title_plate_style() -> StyleBoxTexture:
	## The board the wordmark is bolted to. Navy enamel with rivets and the same
	## amber lip the gantry wears, so the first screen is made of the material the
	## rest of the game's permanent chrome is made of.
	return nine("ui_title_plate", 12, 8)


static func title_button_style(kind: StringName,
		down: bool = false) -> StyleBoxTexture:
	## The title's own keys. Everywhere else in the game a button is a 1px-edged
	## slab, because everywhere else it sits on paper or on navy. Here it sits on
	## a photograph of a working terminal, and only a two-pixel ink edge with the
	## corners knocked off survives that. Same material as the plate above it, so
	## the sign and its keys read as one object bolted to the same wall.
	var sprite := "ui_title_key" if kind == &"amber" else "ui_title_key_steel"
	# 13, matching the 34px slab `gen_title.py` draws: the bevel bands and the
	# rivets live inside that corner, so a smaller margin would stretch them into
	# streaks down the middle of every key.
	return nine(sprite + ("_down" if down else ""), 13, 7)


static func arcade_style(content: int = 8) -> StyleBoxTexture:
	## The cabinet the maze charter is played on: moulded plastic with a recess
	## for the glass. The screen and the controls are drawn into it at runtime.
	return nine("ui_arcade_bezel", 9, content)


static func title_key_style() -> StyleBoxTexture:
	## The same enamel as the plate with a tighter inset, because a corner key is
	## 78px wide and COMUNIDADE needs every one of them.
	return nine("ui_title_key_steel", 10, 3)


static func title_ribbon_style() -> StyleBoxTexture:
	return nine("ui_title_ribbon", 7, 4)


## The container liveries a board can be painted in. `board_style` remembers the
## one it was last asked for so the nameplate built right after it matches,
## which is how every panel builds: frame first, then `header()`.
const LIVERIES: Array[StringName] = [&"rust", &"sea", &"green", &"steel", &"gold"]
## Each livery's body colour, for the contrast suite and anything tinted to match.
const LIVERY_PAINT := {
	&"rust": Color8(200, 88, 38), &"sea": Color8(38, 106, 156),
	&"green": Color8(48, 126, 74), &"steel": Color8(102, 108, 124),
	&"gold": Color8(176, 118, 18),
}
static var _livery: StringName = &"rust"


static func _livery_sprite(base: String, tone: StringName) -> String:
	return base if tone == &"rust" or not LIVERIES.has(tone) \
		else "%s_%s" % [base, tone]


static func board_style(content: int = 12,
		tone: StringName = &"rust") -> StyleBoxTexture:
	## The end wall of a container: painted corrugated steel in one of the
	## yard's liveries, a corner casting in each corner, the manifest sheet
	## sunk into it.
	_livery = tone
	return nine(_livery_sprite("ui_board", tone), 12, content)


static func book_style(content: int = 11) -> StyleBoxTexture:
	## The third material. Steel is the terminal, paper is what it hands you,
	## and leather is what the port *keeps*: the logbook. Only the two diaries
	## are bound in it (`PortJournal`, `NoticeBell`), and `BookFx` is how one
	## opens.
	return nine("ui_book", 14, content)


static func book_header_style() -> StyleBoxTexture:
	## The title label pasted on the binding: dark morocco, one gold rule.
	var box := nine("ui_book_plate", 5, 4)
	box.content_margin_left = 8
	box.content_margin_bottom = 5
	return box


static func style_book_tab(node: Button, active: bool) -> void:
	## Index tabs cut into the fore-edge: the open one is the page's own
	## cream, the rest are older stock. Ink on both — never steel text.
	var box := nine("ui_book_tab_on" if active else "ui_book_tab_off", 5, 5)
	node.add_theme_stylebox_override(&"normal", box)
	node.add_theme_stylebox_override(&"hover", box)
	node.add_theme_stylebox_override(&"pressed", nine("ui_book_tab_on", 5, 5))
	node.add_theme_stylebox_override(&"focus", _focus_style())
	for key: StringName in [&"font_color", &"font_hover_color",
			&"font_pressed_color", &"font_focus_color"]:
		node.add_theme_color_override(key, BOOK_INK if active else BOOK_INK_SOFT)


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
## The sheet is two halves of four: index 0-3 are drawn masculine, 4-7
## feminine. `portrait_index()` below picks a half by the person, not by hash,
## so the count matters to more than just the atlas math.
const PORTRAIT_COUNT := 8


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
	## rolled when the card opens. Which half of the sheet is not left to the
	## hash at all — `profile.presents_feminine()` picks it, and only the face
	## within that half is.
	if profile == null:
		return 0
	var key := profile.uid if not profile.uid.is_empty() else profile.slot
	var half := PORTRAIT_COUNT / 2
	var offset := posmod(key.hash(), half)
	return offset + half if profile.presents_feminine() else offset


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


static func header_style() -> StyleBoxTexture:
	## The nameplate across the top of a board: the frame's enamel with an
	## amber hairline under it. Bottom margin is thicker so the title never
	## sits on the stripe.
	var box := nine(_livery_sprite("ui_header", _livery), 5, 4)
	box.content_margin_left = 8
	box.content_margin_bottom = 7
	return box


static func header(title: String, close: Callable = Callable(),
		kind: int = -1, plate_style: StyleBox = null) -> Dictionary:
	## One nameplate for every board: optional icon, the title in amber on
	## enamel, and the close key bolted to its right end. Returns
	## {root, title, close} so a board can restyle or retitle it later.
	var plate := panel(plate_style if plate_style != null else header_style(),
		false)
	plate.custom_minimum_size.y = 34
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	plate.add_child(row)
	if kind >= 0:
		var glyph := icon(kind as Icon)
		glyph.modulate = CREAM
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var text := label(title, SIZE_TITLE, CREAM)
	text.label_settings = settings(SIZE_TITLE, CREAM, 2)
	text.label_settings.outline_color = Color8(44, 26, 22)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.clip_text = true
	# A long title (German, a long board name) steps down to body size rather
	# than being cut mid-word; it steps back up when the board grows again.
	text.resized.connect(fit_title.bind(text))
	row.add_child(text)
	var key: Button = null
	if close.is_valid():
		key = icon_button(Icon.CLOSE, &"ghost", 24.0, Loc.t("common.close"))
		key.custom_minimum_size = Vector2(32, 24)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.pressed.connect(close)
		row.add_child(key)
	return {"root": plate, "title": text, "close": key}


static func fit_title(text: Label) -> void:
	if text.size.x <= 0.0:
		return
	var wide := FONT.get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		SIZE_TITLE).x
	var size := SIZE_TITLE if wide <= text.size.x else SIZE_BODY
	if text.label_settings.font_size != size:
		text.label_settings.font_size = size


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
	node.color = Color(0.09, 0.06, 0.07, alpha)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	# The port behind the board goes out of focus rather than merely darker.
	UiMotion.dress_scrim(node)
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
	var top := board.position.y - CLIP_RISE
	# It needs real air above it. A clip drawn into the top strip of the screen
	# lands on the status bar or the TEU readout, which is worse than no clip.
	clip.visible = board.visible and top >= safe.position.y + 26.0
	clip.position = Vector2(
		board.position.x + (board.size.x - CLIP_SIZE.x) * 0.5, top)
	# The board's motion carries its clip (`_carry_clip`); it finds it here.
	board.set_meta(&"clip", clip)


const CLIP_RISE := 11.0


static func _carry_clip(board: Control, lift: float = 0.0) -> void:
	## Keeps the spring clip on a board that is travelling. `lift` is how far
	## the jaw stands open above its bite.
	if not board.has_meta(&"clip"):
		return
	var clip := board.get_meta(&"clip") as Control
	if clip == null or not is_instance_valid(clip):
		return
	clip.position = Vector2(
		board.position.x + (board.size.x - CLIP_SIZE.x) * 0.5,
		board.position.y - CLIP_RISE - lift).round()


# ------------------------------------------------------------------ motion

## Why overlays move at all: a board that appears in a single frame reads as a
## glitch. A board is a clipboard somebody lifts into view — so it comes up
## from below the screen, runs a few pixels past its mark, settles back, and
## its spring clip snaps shut on the sheet. `pop_open` is that motion, and it
## moves `position`, never `scale`, so the pixel font is never resampled while
## the board travels. `board_up.wav` is cut to the same clock: air, wood at
## 0.20 s, the clip at 0.27 s.
const RISE_TIME := 0.30
const RISE_LAND := 0.68       # fraction of RISE_TIME at which the board lands
const RISE_OVERSHOOT := 5.0
const DROP_TIME := 0.15


static func _rise_offset(t: float, travel: float) -> float:
	## Cubic out to a small overshoot, then eased back onto the mark.
	if t < RISE_LAND:
		var u := 1.0 - t / RISE_LAND
		return roundf(lerpf(-RISE_OVERSHOOT, travel, u * u * u))
	var v := (t - RISE_LAND) / (1.0 - RISE_LAND)
	return roundf(lerpf(-RISE_OVERSHOOT, 0.0, v * v * (3.0 - 2.0 * v)))


static func _kill_pop(board: Control) -> void:
	## Stops a board mid-flight and puts it back on its mark. A killed tween
	## leaves the board wherever the last frame put it, and with a rise that
	## starts off-screen "wherever" can be under the bottom edge.
	# has_meta first: get_meta errors on a missing key even with a default.
	if board.has_meta(&"pop_tween"):
		var previous := board.get_meta(&"pop_tween") as Tween
		if previous != null and previous.is_running():
			previous.kill()
	if board.has_meta(&"pop_state"):
		var state: Dictionary = board.get_meta(&"pop_state")
		# Only if nothing else has laid the board out since the last frame.
		if board.position == state.last:
			board.position = state.final
		board.remove_meta(&"pop_state")


static func pop_open(board: Control, scrim: CanvasItem = null,
		slide: bool = true, sound: String = "board_up") -> void:
	## The OPEN animation for every overlay board. Call it at the END of the
	## open path, after the board has been laid out for this open, so
	## `board.position` is already final. `scrim`, when given and visible, is
	## faded in alongside; its colour alpha is never touched. `slide = false`
	## animates the board's alpha only, for boards an async `_fit_to_content()`
	## moves a frame later — sliding those would land on a stale position.
	## `sound` is the wav for the whole gesture ("" when the caller plays its
	## own, as `BookFx` does).
	##
	## If the board is laid out again during the rise (a resize, a rotation),
	## the slide adopts the layout's new position as its resting place instead
	## of dragging the board back to the one it remembered. It used to do the
	## latter: a shop laid out for a tall viewport that shrank mid-open ended
	## 137px low with its bottom off the screen, until the next resize.
	if not sound.is_empty():
		if slide:
			AudioManager.play_sfx(sound, 0.02, -3.0)
		else:
			AudioManager.play_sfx("ui_open", 0.03, -4.0)
	_kill_pop(board)
	if scrim != null:
		scrim.modulate.a = 1.0
	if not UserPreferences.can_animate():
		board.modulate.a = 1.0
		_carry_clip(board)
		return
	var tween := board.create_tween().set_parallel()
	if slide:
		board.modulate.a = 1.0
		# From just under the bottom edge of the screen, wherever the board
		# rests: a dialog in the middle of the screen is lifted further than
		# a sheet docked at the bottom, in the same time.
		var travel := maxf(24.0,
			board.get_viewport_rect().size.y - board.position.y + 16.0)
		# `final` is where the layout put the board; `last` is where the slide
		# itself last put it. Any difference between `last` and the board's
		# actual position means something else moved it — that is the new
		# resting place.
		var state := {"final": board.position,
			"last": board.position + Vector2(0, travel)}
		board.position = state.last
		board.set_meta(&"pop_state", state)
		_carry_clip(board, 6.0)
		tween.tween_method(func(t: float) -> void:
			if not is_instance_valid(board):
				return
			if board.position != state.last:
				state.final = board.position
			state.last = state.final + Vector2(0, _rise_offset(t, travel))
			board.position = state.last
			# The jaw stands open until the board is nearly home, then bites.
			_carry_clip(board, 6.0 if t < 0.86 else 0.0), 0.0, 1.0, RISE_TIME)
		# What is on the board arrives in order as it lands.
		UiMotion.cascade(UiMotion.board_items(board), 0.0, 0.024)
	else:
		board.modulate.a = 0.0
		tween.tween_property(board, "modulate:a", 1.0, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if scrim != null and scrim.is_visible_in_tree():
		scrim.modulate.a = 0.0
		tween.tween_property(scrim, "modulate:a", 1.0, 0.18)
	board.set_meta(&"pop_tween", tween)


static func pop_close(board: Control, scrim: CanvasItem, done: Callable,
		sound: String = "board_down") -> void:
	## The CLOSE animation: the board drops back out of frame, then `done`
	## hides it. The overlay is already closed as far as the game is concerned
	## when this is called — `done` is presentation only, and it is called at
	## once when there is nothing to animate (motion off, no display, board
	## already hidden), so no caller ever waits on a tween to change state.
	## A `pop_open` during the drop kills it; `done` is then never called,
	## which is right, because the board is open again.
	_kill_pop(board)
	if not board.is_visible_in_tree() or not UserPreferences.can_animate() \
			or DisplayServer.get_name() == "headless":
		done.call()
		return
	if not sound.is_empty():
		AudioManager.play_sfx(sound, 0.02, -5.0)
	var state := {"final": board.position, "last": board.position}
	var travel := board.get_viewport_rect().size.y - board.position.y + 16.0
	board.set_meta(&"pop_state", state)
	var tween := board.create_tween().set_parallel()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(board):
			return
		state.last = state.final + Vector2(0, roundf(travel * t * t))
		board.position = state.last
		_carry_clip(board, 6.0), 0.0, 1.0, DROP_TIME)
	if scrim != null and scrim.is_visible_in_tree():
		tween.tween_property(scrim, "modulate:a", 0.0, DROP_TIME)
	tween.chain().tween_callback(func() -> void:
		if not is_instance_valid(board):
			return
		board.position = state.final
		board.remove_meta(&"pop_state")
		if scrim != null and is_instance_valid(scrim):
			scrim.modulate.a = 1.0
		done.call())
	board.set_meta(&"pop_tween", tween)


static func settle_open(board: Control) -> void:
	## Lands a board that is mid-`pop_open` right now: kills the stored tween
	## if it is still running and forces full alpha.
	_kill_pop(board)
	board.modulate.a = 1.0
	_carry_clip(board)


# ------------------------------------------------------------------ controls

const _BUTTON_SPRITES := {
	&"amber": "ui_btn", &"go": "ui_btn_go", &"alt": "ui_btn_alt", &"ghost": "ui_btn_ghost",
	&"off": "ui_btn_off", &"danger": "ui_btn_danger", &"steel": "ui_btn_steel",
}
const _BUTTON_TEXT := {
	&"amber": KEY_INK, &"go": CREAM, &"alt": CREAM, &"ghost": INK,
	&"off": INK_SOFT, &"danger": CREAM, &"steel": STEEL_TEXT,
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
	# `ui_tip`, not the gantry's job tag. The tag is a sixteen-pixel enamel sign
	# with a teal service spine, rivets and five pixels of margin all round —
	# correct bolted across the top of the quay, and a road sign when it is
	# hanging under the pointer around the word "RAMAL". A tooltip is a caption:
	# one pixel of ink, three of margin, and mostly the words.
	var tip := nine("ui_tip", 3, 3)
	tip.set_content_margin(SIDE_LEFT, 4)
	tip.set_content_margin(SIDE_RIGHT, 4)
	tip.set_content_margin(SIDE_TOP, 1)
	tip.set_content_margin(SIDE_BOTTOM, 1)
	theme.set_stylebox(&"panel", &"TooltipPanel", tip)
	theme.set_font(&"font", &"TooltipLabel", FONT)
	theme.set_font_size(&"font_size", &"TooltipLabel", SIZE_SMALL)
	theme.set_color(&"font_color", &"TooltipLabel", CREAM)
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
			# Focus lands here so a keyboard user can act at once, but the ring
			# stays hidden until they actually use the keyboard: on a phone it
			# was a white box drawn round the close key of every board.
			control.grab_focus(true)
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
	node.add_theme_color_override(&"font_pressed_color",
		KEY_INK if kind == &"amber" else CREAM)
	node.add_theme_color_override(&"font_focus_color", text_color)
	# WCAG 1.4.3 exempts inactive controls from the contrast floor, but a key
	# nobody can read is still a bad key, so it stays as legible as a disabled
	# state is allowed to look.
	node.add_theme_color_override(&"font_disabled_color", DISABLED_TEXT)
	# The glyph on a key follows the key's own text colour. Leaving it white
	# made an amber star on a cream ghost key read as an empty box.
	node.add_theme_color_override(&"icon_normal_color", text_color)
	node.add_theme_color_override(&"icon_hover_color", text_color)
	node.add_theme_color_override(&"icon_pressed_color",
		KEY_INK if kind == &"amber" else CREAM)
	node.add_theme_color_override(&"icon_focus_color", text_color)
	node.add_theme_color_override(&"icon_disabled_color", DISABLED_TEXT)
	UiMotion.wire_press(node)
	# Every amber key is something good to press, and they share one gloss.
	UiMotion.set_sheen(node, kind == &"amber" or kind == &"go")


## The two tones of the focus ring. A single colour cannot be visible on both
## cream paper and near-black slate, so the ring carries one of each and
## whichever surface it lands on, one of them reads.
const FOCUS_OUTER := Color8(58, 44, 46)
const FOCUS_INNER := CREAM
## A key that cannot be pressed: exempt from AA, held above 3:1 on `btn_off`.
const DISABLED_TEXT := Color8(104, 92, 84)


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
	# Button's icon is left-aligned by default whatever `alignment` says, which
	# sat the close cross and the bell off-centre in their keys.
	node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
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
	var color := KEY_INK if active else INK_SOFT
	node.add_theme_color_override(&"font_color", color)
	node.add_theme_color_override(&"font_hover_color", color)
	node.add_theme_color_override(&"font_pressed_color", KEY_INK)
	node.add_theme_color_override(&"font_focus_color", color)
	UiMotion.wire_press(node)


static func style_tab(node: Button, active: bool) -> void:
	var box := tab_style(active)
	node.add_theme_stylebox_override(&"normal", box)
	node.add_theme_stylebox_override(&"hover", box)
	node.add_theme_stylebox_override(&"pressed", tab_style(true))
	node.add_theme_stylebox_override(&"focus", _focus_style())
	var color := INK if active else INK_SOFT
	node.add_theme_color_override(&"font_color", color)
	node.add_theme_color_override(&"font_hover_color", color)
	node.add_theme_color_override(&"font_pressed_color", INK)
	node.add_theme_color_override(&"font_focus_color", color)
	UiMotion.wire_press(node)


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


static func count_pill(fill: Color, ink: Color = CREAM) -> PanelContainer:
	## The little number pinned to a key's corner ("1 waiting"). A bare
	## outlined digit floated off the key and read as stray text; a pill with an
	## ink edge reads as a badge that belongs to the key it sits on.
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = HULL_EDGE
	box.set_border_width_all(1)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	var pill := panel(box)
	pill.visible = false
	var value := label("", SIZE_SMALL, ink)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(value)
	return pill


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
