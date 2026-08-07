extends Control
## The first thing the game shows.
##
## Two pages in one screen, because a title has one job — get the player into the
## terminal — and everything else it offers is a detour it should not charge for.
##
##   * **the marquee**: the plate, JOGAR, CONTINUAR and AJUSTES down the middle,
##     four corner keys and the plate at the foot;
##   * **the board**: the three terminals, reached from JOGAR, and the only place
##     a run can be started or erased.
##
## CONTINUAR is the interesting one. It is the single button that gets a returning
## player back where they were, and it only exists when there *is* a where: the
## slot is remembered in `UserPreferences`, not in a save file, because the title
## has to answer "continue which one?" before any profile has been loaded.
##
## Deleting a run is the most destructive button in the game, so it arms first and
## only the armed slot can be confirmed — arming one and confirming another is
## exactly how somebody loses the wrong terminal.

const SLOT_HEIGHT := 76.0
## The berth photographs on the slots, one per terminal, at 1:1. They are 64px
## paintings and the card is sized around them rather than the other way round.
const BADGE_SIZE := 64.0
const BERTH_ART := [
	preload("res://assets/sprites/ui_berth_a.png"),
	preload("res://assets/sprites/ui_berth_b.png"),
	preload("res://assets/sprites/ui_berth_c.png"),
]
## The four corner keys, and what each of them opens.
const CORNERS := [
	{"id": "feedback", "label": "FEEDBACK", "icon": UiTheme.Icon.CHAT,
		"corner": "tl"},
	{"id": "site", "label": "SITE", "icon": UiTheme.Icon.GLOBE, "corner": "tr"},
	{"id": "comunidade", "label": "COMUNIDADE", "icon": UiTheme.Icon.CREW,
		"corner": "bl"},
	{"id": "creditos", "label": "CRÉDITOS", "icon": UiTheme.Icon.TROPHY,
		"corner": "br"},
]
const REPO_URL := "https://github.com/chicogborba/HarborClick"
const VERSION_LINE := "v1.0.0"
const STUDIO_LINE := "PORTSTACK STUDIOS"

## How far the backdrop is allowed to creep, and how long one pass takes. The
## port is a photograph of a place that is working; a still one says it stopped.
const DRIFT := 14.0
const DRIFT_SECONDS := 26.0
## Gulls over the water. Four is what the world uses; the title is the same port.
const GULL_COUNT := 3
## The backdrop's own size, and the three gantries standing on its quay. Both
## are `tools/sprites/gen_title.py`'s numbers: the picture is baked with the
## booms on it and the trolleys left off, because a trolley that never moves is
## the one part of a working terminal that says nothing is happening.
const PORT_SIZE := Vector2(320, 720)
const CRANE_YS := [208.0, 372.0, 536.0]
## Where a trolley can go: out over the ship, and back in over the apron.
const TROLLEY_OUT := 282.0
const TROLLEY_IN := 224.0

var _backdrop: TextureRect
var _marquee: Control
var _plate: PanelContainer
var _ribbon: PanelContainer
var _crest: TextureRect
var _scrim: TextureRect
var _play_key: Button
var _continue_detail: Label
var _actions: VBoxContainer
var _continue_key: Button
var _corner_keys: Dictionary = {}     # id -> Control
var _footer: VBoxContainer
var _board_page: Control
var _board: PanelContainer
var _clip: TextureRect
var _slots: VBoxContainer
var _status: Label
var _sheet: Control
var _armed_delete := 0
var _port_layer: Node2D
var _gulls: Array[AnimatedSprite2D] = []
var _gull_time := 0.0
var _trolleys: Array[Node2D] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.install_window_theme(get_window())
	_build()
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_show_marquee()
	_layout()
	_start_motion()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _sheet != null:
		_close_sheet()
		accept_event()
	elif _board_page.visible:
		_show_marquee()
		accept_event()


# ------------------------------------------------------------------- building

func _build() -> void:
	_backdrop = TextureRect.new()
	_backdrop.name = "HarborPanorama"
	_backdrop.texture = preload("res://assets/sprites/ui_title_port.png")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Overscanned by `DRIFT` on every side so the picture can be moved without a
	# gap opening at an edge. It is drawn COVERED, so the extra is cropped
	# anyway — this only decides *which* crop is on screen right now.
	_backdrop.offset_left = -DRIFT
	_backdrop.offset_top = -DRIFT
	_backdrop.offset_right = DRIFT
	_backdrop.offset_bottom = DRIFT
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# A thin wash, not a curtain. It used to be a third of the way to black,
	# which is what a night title needs and what a late-afternoon one cannot
	# survive: the yard behind this is the game's own daylight, and dimming it
	# that far made the first screen darker than every screen after it. What the
	# type actually needs is the scrim under the keys, which is local.
	var shade := ColorRect.new()
	shade.color = Color(0.055, 0.065, 0.11, 0.16)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_port_actors()
	_build_marquee()
	_build_board()


func _build_port_actors() -> void:
	## Everything on this screen that moves lives in one Node2D whose transform
	## is the backdrop's own, so its children are positioned in *port* pixels —
	## the same coordinates `gen_title.py` painted the picture in. Without that
	## every actor would need the COVERED scale worked out for it, and a drifting
	## backdrop would leave all of them behind.
	_port_layer = Node2D.new()
	_port_layer.name = "PortActors"
	add_child(_port_layer)

	# The trolleys. The booms are baked into the backdrop; what rides them is
	# not, because this is the one thing on the title that shows work being done
	# — a box comes off the ship, crosses the apron and is set down.
	for index in CRANE_YS.size():
		var trolley := Node2D.new()
		trolley.position = Vector2(TROLLEY_OUT, CRANE_YS[index] + 16.0)
		var cargo := Sprite2D.new()
		cargo.name = "Cargo"
		cargo.texture = _container_frame(index * 3 + 1)
		cargo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cargo.position = Vector2(0, 3)
		trolley.add_child(cargo)
		var frame := Sprite2D.new()
		frame.texture = preload("res://assets/sprites/sts_trolley.png")
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		trolley.add_child(frame)
		_port_layer.add_child(trolley)
		_trolleys.append(trolley)

	## The same birds that wheel over the terminal in `Critters`, over the same
	## water, from the same four-frame sheet. The title is a picture of the port
	## the player is about to open; the port has gulls in it, so this does.
	if not UserPreferences.can_animate():
		return
	var sheet: Texture2D = preload("res://assets/sprites/prop_seagull.png")
	for index in GULL_COUNT:
		var gull := AnimatedSprite2D.new()
		var frames := SpriteFrames.new()
		frames.set_animation_speed(&"default", 8.0)
		for step in 4:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(step * 14, 0, 14, 12)
			frames.add_frame(&"default", region)
		gull.sprite_frames = frames
		gull.frame = index
		gull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gull.modulate = Color(0.92, 0.94, 1.0, 0.92)
		gull.play()
		_port_layer.add_child(gull)
		_gulls.append(gull)


func _container_frame(color: int) -> AtlasTexture:
	## One livery off the yard's own eight-box sheet, so the thing under the
	## spreader is the same object the game is about to hand the player.
	var frame := AtlasTexture.new()
	frame.atlas = preload("res://assets/sprites/container_sheet.png")
	frame.region = Rect2(posmod(color, 8) * 24, 0, 24, 13)
	return frame


func _process(delta: float) -> void:
	if _port_layer == null:
		return
	# The backdrop is drawn COVERED and it drifts, so its transform is recomputed
	# every frame rather than at layout: the actors have to sit on the picture,
	# not near it.
	var rect := _backdrop.size
	if rect.x > 0.0 and rect.y > 0.0:
		var scale := maxf(rect.x / PORT_SIZE.x, rect.y / PORT_SIZE.y)
		_port_layer.scale = Vector2(scale, scale)
		_port_layer.position = _backdrop.position \
			+ (rect - PORT_SIZE * scale) * 0.5

	if _gulls.is_empty():
		return
	_gull_time += delta
	for index in _gulls.size():
		## Ellipses over the water, each at its own phase and radius. Straight
		## lines across the frame would be a screensaver; a bird that comes back
		## is a bird that lives here.
		var gull: AnimatedSprite2D = _gulls[index]
		var phase := _gull_time * (0.2 + index * 0.04) + index * 2.1
		var centre := Vector2(276.0 + 8.0 * (index % 2), 220.0 + 120.0 * index)
		gull.position = centre + Vector2(cos(phase) * (26.0 + index * 5.0),
			sin(phase * 1.4) * 42.0)
		# Turned to face the way it is going, the way the world's gulls are.
		gull.scale.x = 1.0 if sin(phase) > 0.0 else -1.0


func _build_marquee() -> void:
	_marquee = Control.new()
	_marquee.name = "Marquee"
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_marquee)

	_plate = UiTheme.panel(UiTheme.title_plate_style())
	_plate.name = "TitlePlate"
	_marquee.add_child(_plate)
	# Lamplight on the enamel behind the type. A navy rectangle is a sign; a
	# navy rectangle with a light on it is a sign somebody switched on.
	var lit := TextureRect.new()
	lit.name = "PlateGlow"
	lit.texture = _plate_glow()
	lit.stretch_mode = TextureRect.STRETCH_SCALE
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(lit)

	var plate_column := VBoxContainer.new()
	plate_column.alignment = BoxContainer.ALIGNMENT_CENTER
	plate_column.add_theme_constant_override(&"separation", 0)
	_plate.add_child(plate_column)
	plate_column.add_child(_wordmark())

	# The ribbon hangs off the plate rather than sitting inside it, the way a
	# painted board and its motto strip are two objects screwed to a wall.
	_ribbon = UiTheme.panel(UiTheme.title_ribbon_style())
	_ribbon.name = "Motto"
	_marquee.add_child(_ribbon)
	var motto_row := HBoxContainer.new()
	motto_row.alignment = BoxContainer.ALIGNMENT_CENTER
	motto_row.add_theme_constant_override(&"separation", 4)
	motto_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.add_child(motto_row)
	# Stars as icons, not as text: the pixel font is drawn glyph by glyph in
	# `tools/sprites/gen_font.py` and has no dingbats, so a literal star is a
	# missing-glyph box.
	motto_row.add_child(UiTheme.icon(UiTheme.Icon.STAR, 1))
	motto_row.add_child(UiTheme.label("CONSTRUA. EXPANDA. FATURE.",
		UiTheme.SIZE_SMALL, UiTheme.AMBER))
	motto_row.add_child(UiTheme.icon(UiTheme.Icon.STAR, 1))

	# The mark, astride the top edge of the plate. Placed in the layout pass, not
	# here: it straddles the plate, so it needs the plate's final rectangle.
	#
	# It is a crest rather than the old flat anchor, and it is drawn at 1:1. The
	# art is `tools/sprites/pixellab` work — the one asset in this game where the
	# value is in the drawing and a nested loop was the wrong instrument — and
	# anything other than an integer scale would sand the pixels off it.
	_crest = TextureRect.new()
	_crest.name = "Crest"
	_crest.texture = preload("res://assets/sprites/ui_title_crest.png")
	_crest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.add_child(_crest)

	# A pool of dusk under the keys. The backdrop is a working terminal, which
	# means the middle of it is containers: without this the three most important
	# words on the screen are read off a chequerboard.
	_scrim = TextureRect.new()
	_scrim.name = "KeyScrim"
	_scrim.texture = _key_scrim()
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.add_child(_scrim)

	_actions = VBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override(&"separation", 6)
	_marquee.add_child(_actions)

	# JOGAR is the whole point of the screen, so it is the only amber thing on it
	# and the only key wearing stars. Everything else is navy: a title with three
	# equally loud buttons makes the player read all three.
	var play := UiTheme.button("", &"amber", UiTheme.SIZE_TITLE)
	_dress_key(play, &"amber")
	play.custom_minimum_size.y = 48.0
	UiTheme.describe(play, "Jogar", "Escolher um dos três terminais")
	play.pressed.connect(_show_board)
	_actions.add_child(play)
	_play_key = play
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override(&"separation", 10)
	play_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play.add_child(play_row)
	var left_star := UiTheme.icon(UiTheme.Icon.STAR, 1)
	left_star.modulate = UiTheme.AMBER_DEEP
	left_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play_row.add_child(left_star)
	var play_word := UiTheme.label("JOGAR", UiTheme.SIZE_TITLE, UiTheme.INK)
	play_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	play_row.add_child(play_word)
	var right_star := UiTheme.icon(UiTheme.Icon.STAR, 1)
	right_star.modulate = UiTheme.AMBER_DEEP
	right_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play_row.add_child(right_star)

	# CONTINUAR carries a second line, because "continue" without "which day" is
	# a promise the player has to press to find out the value of.
	_continue_key = UiTheme.button("", &"steel", UiTheme.SIZE_BODY)
	_dress_key(_continue_key, &"steel")
	_continue_key.custom_minimum_size.y = 42.0
	_continue_key.pressed.connect(_continue_last)
	_actions.add_child(_continue_key)
	var continue_column := VBoxContainer.new()
	continue_column.alignment = BoxContainer.ALIGNMENT_CENTER
	continue_column.add_theme_constant_override(&"separation", 0)
	continue_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_continue_key.add_child(continue_column)
	var continue_word := UiTheme.label("CONTINUAR", UiTheme.SIZE_BODY,
		UiTheme.TEAL_LIGHT)
	continue_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_column.add_child(continue_word)
	_continue_detail = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.STEEL_DIM)
	_continue_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_column.add_child(_continue_detail)

	var settings := UiTheme.button("", &"steel", UiTheme.SIZE_BODY)
	_dress_key(settings, &"steel")
	settings.custom_minimum_size.y = 38.0
	UiTheme.describe(settings, "Ajustes", "Som, movimento e tela")
	settings.pressed.connect(_open_options)
	_actions.add_child(settings)
	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override(&"separation", 6)
	settings_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.add_child(settings_row)
	var gear := UiTheme.icon(UiTheme.Icon.GEAR, 1)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_row.add_child(gear)
	var settings_word := UiTheme.label("AJUSTES", UiTheme.SIZE_BODY,
		UiTheme.STEEL_TEXT)
	settings_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_row.add_child(settings_word)

	for spec: Dictionary in CORNERS:
		var key := _corner_key(spec)
		_marquee.add_child(key)
		_corner_keys[str(spec.id)] = key

	_footer = VBoxContainer.new()
	_footer.name = "Footer"
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override(&"separation", 0)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.add_child(_footer)
	# An anchor either side of the version, which is the one place on the screen
	# where a small ornament costs nothing and says "this is a harbour game".
	var version_row := HBoxContainer.new()
	version_row.alignment = BoxContainer.ALIGNMENT_CENTER
	version_row.add_theme_constant_override(&"separation", 5)
	version_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(version_row)
	for side in 2:
		if side == 1:
			var version := UiTheme.label(VERSION_LINE, UiTheme.SIZE_SMALL,
				UiTheme.STEEL_DIM)
			version_row.add_child(version)
		# Drawn at the size it is used at rather than a 28px mark squeezed into
		# nine: a non-integer downscale of pixel art loses whole rows of it.
		var mark := TextureRect.new()
		mark.texture = preload("res://assets/sprites/ui_title_pip.png")
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.modulate = Color(1, 1, 1, 0.5)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		version_row.add_child(mark)
	var studio := UiTheme.label(STUDIO_LINE, UiTheme.SIZE_SMALL, UiTheme.STEEL_DIM)
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_child(studio)


func _key_scrim() -> GradientTexture2D:
	## Dusk that fades in and out again, so it has no edge to notice. A flat
	## panel behind the keys would be a fourth material on a screen that has
	## exactly two, and the player would read it as a thing rather than as light.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.66, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.04, 0.05, 0.09, 0.0), Color(0.04, 0.05, 0.09, 0.72),
		Color(0.04, 0.05, 0.09, 0.72), Color(0.04, 0.05, 0.09, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 128
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture


# -------------------------------------------------------------------- motion

func _start_motion() -> void:
	## An arrival, then two loops, all of them optional. Everything here animates
	## `modulate` or the backdrop's own rect — never a control the layout pass
	## owns — so a resize mid-tween cannot leave a key parked off its mark.
	##
	## The loops wait for the arrival to finish. Both touch `modulate`, and a
	## looping tint running against a fade is the one way two correct animations
	## make a control flicker.
	if not UserPreferences.can_animate():
		# Motion off still leaves three cranes holding three boxes over the ship,
		# which is a picture of a working terminal rather than a paused one.
		return
	_arrive()
	await get_tree().create_timer(0.46).timeout
	if not is_inside_tree():
		return

	var drift := create_tween().set_loops()
	drift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(_backdrop, ^"position", Vector2(-DRIFT, -2.0),
		DRIFT_SECONDS).from(Vector2(-DRIFT, -DRIFT * 2.0 + 2.0))
	drift.tween_property(_backdrop, ^"position", Vector2(-DRIFT, -DRIFT * 2.0 + 2.0),
		DRIFT_SECONDS)

	# The crest catches the light the way a brass thing on a wall does.
	var shine := create_tween().set_loops()
	shine.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shine.tween_property(_crest, ^"modulate", Color(1.12, 1.10, 1.04), 2.4)
	shine.tween_property(_crest, ^"modulate", Color(0.94, 0.94, 0.96), 2.4)

	# JOGAR is the only thing on this screen the player has to find.
	var pulse := create_tween().set_loops()
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_play_key, ^"modulate", Color(1.09, 1.06, 1.0), 1.5)
	pulse.tween_property(_play_key, ^"modulate", Color(1, 1, 1), 1.5)

	_work_the_ship()


func _work_the_ship() -> void:
	## The three gantries discharging her, each on its own clock.
	##
	## One cycle is the whole job in miniature: the trolley runs out over the
	## hold, a box appears under it, it crosses to the apron, sets the box down
	## and goes back for another. It is the only thing on this screen that is
	## *the game* rather than a picture of it, which is why it is worth the four
	## tweens it costs.
	for index in _trolleys.size():
		var trolley: Node2D = _trolleys[index]
		var cargo: Sprite2D = trolley.get_node(^"Cargo")
		var cycle := create_tween().set_loops()
		cycle.tween_interval(index * 2.6)
		cycle.tween_callback(func() -> void: cargo.modulate.a = 0.0)
		cycle.tween_interval(0.5)
		# Landing on the box: a beat with nothing moving reads as the spreader
		# taking the weight, and without it the run back looks like a glitch.
		cycle.tween_property(cargo, ^"modulate:a", 1.0, 0.25)
		cycle.tween_property(trolley, ^"position:x", TROLLEY_IN, 3.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cycle.tween_property(cargo, ^"modulate:a", 0.0, 0.2)
		cycle.tween_interval(0.4)
		cycle.tween_property(trolley, ^"position:x", TROLLEY_OUT, 2.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _arrive() -> void:
	## The marquee assembling itself, top to bottom, in a third of a second.
	## Fades only: the capture harness measures these rectangles a frame later
	## and an entrance that moved them would be measuring the animation.
	var order: Array[Control] = [_plate, _ribbon, _crest, _actions, _footer]
	for id: String in _corner_keys:
		order.append(_corner_keys[id] as Control)
	for step in order.size():
		var node: Control = order[step]
		node.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_interval(0.04 * step)
		fade.tween_property(node, ^"modulate:a", 1.0, 0.22)


func _plate_glow() -> GradientTexture2D:
	## A warm pool on the plate, brightest behind the type. Radial, so it has no
	## edge; an edge would read as a second panel bolted onto the first.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.82, 0.42, 0.20), Color(1.0, 0.78, 0.38, 0.07),
		Color(1.0, 0.78, 0.38, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 32
	return texture


func _wordmark() -> Control:
	## "HarborClick" as one drawn object, not as two Labels.
	##
	## It used to be the game's body font at title size with a shadow under it,
	## which is exactly what it looked like: a caption. A logo needs weight the
	## font does not have — an extruded body, an ink ring thick enough to survive
	## being read against a container yard, and a rim where the light catches the
	## top of every stroke. All three are set operations on the same stencil, so
	## `tools/sprites/gen_title.py` draws it out of the game's own glyphs and this
	## hangs the result on the plate at 1:1.
	var mark := TextureRect.new()
	mark.name = "Wordmark"
	mark.texture = preload("res://assets/sprites/ui_title_word.png")
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.custom_minimum_size = mark.texture.get_size()
	return mark


func _dress_key(key: Button, kind: StringName) -> void:
	## The title's keys wear the title's material. `UiTheme.button` gives them
	## the console's, which is right everywhere the console is — and wrong here,
	## where a key has to hold its own against a photograph rather than against
	## navy enamel.
	var normal := UiTheme.title_button_style(kind)
	key.add_theme_stylebox_override(&"normal", normal)
	key.add_theme_stylebox_override(&"hover", normal)
	key.add_theme_stylebox_override(&"pressed",
		UiTheme.title_button_style(kind, true))
	key.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())


func _corner_key(spec: Dictionary) -> PanelContainer:
	# Same navy enamel as the plate: four keys in a different material would read
	# as belonging to a different screen.
	var key := UiTheme.panel(UiTheme.title_key_style(), false)
	key.custom_minimum_size = Vector2(78, 50)
	key.focus_mode = Control.FOCUS_ALL
	key.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
	key.set_meta("corner", str(spec.corner))
	UiTheme.describe(key, str(spec.label))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(column)
	# 2x, like the console's keys: a 12px glyph over a word is a bullet point.
	var glyph := UiTheme.icon(spec.icon as UiTheme.Icon, 2)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(glyph)
	var caption := UiTheme.label(str(spec.label), UiTheme.SIZE_SMALL,
		UiTheme.STEEL_TEXT)
	caption.clip_text = true
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	key.gui_input.connect(_corner_input.bind(str(spec.id)))
	return key


func _corner_input(event: InputEvent, id: String) -> void:
	var pressed := false
	if event.is_action_pressed(&"ui_accept"):
		pressed = true
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		pressed = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		accept_event()
		_open_corner(id)


func _build_board() -> void:
	_board_page = Control.new()
	_board_page.name = "TerminalBoard"
	_board_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_page.visible = false
	add_child(_board_page)

	_board = PanelContainer.new()
	UiTheme.apply_panel(_board, UiTheme.board_style(10))
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_page.add_child(_board)
	_clip = UiTheme.clip_badge()
	_board_page.add_child(_clip)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	_board.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 4)
	column.add_child(header)
	var back := UiTheme.button("VOLTAR", &"ghost", UiTheme.SIZE_SMALL)
	back.custom_minimum_size = Vector2(56, 22)
	UiTheme.describe(back, "Voltar", "Voltar à tela inicial")
	back.pressed.connect(_show_marquee)
	header.add_child(back)
	var title := UiTheme.label("ESCOLHA SEU TERMINAL", UiTheme.SIZE_BODY,
		UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# Balances the back key so the heading sits on the board's centre line.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(56, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	column.add_child(UiTheme.divider())

	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	# Scrolled, and the bar's width reserved rather than drawn over the cards.
	# Three terminals fit a phone today; the board must not be the thing that
	# decides that, or a fourth slot or a taller card pushes it off the screen the
	# way the first version of this board went off a 320-wide one.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_child(scroll)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override(&"separation", 4)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slots)

	# A pencil clipped to the corner of the board, the way one actually would be.
	var pencil := UiTheme.desk_prop("ui_pencil", -8.0)
	pencil.name = "Pencil"
	_board_page.add_child(pencil)

	_status = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "PROGRESSO SALVO NESTE DISPOSITIVO"
	column.add_child(_status)


# --------------------------------------------------------------------- pages

func _show_marquee() -> void:
	_marquee.visible = true
	_board_page.visible = false
	_refresh_continue()
	_layout()


func _show_board() -> void:
	AudioManager.play_sfx("tap")
	_marquee.visible = false
	_board_page.visible = true
	_refresh()
	_layout()


func _refresh_continue() -> void:
	## CONTINUAR is only offered when there is something to continue. An enabled
	## key that starts a brand new run is the same betrayal as a save that was not
	## there — so a slot that has been deleted since it was last played takes the
	## key away with it.
	var slot := int(UserPreferences.last_profile)
	var summary := SaveManager.profile_summary(slot) if slot > 0 else {}
	var playable := slot > 0 and bool(summary.get("exists", false))
	_continue_key.visible = playable
	if not playable:
		return
	# No em dashes: the pixel font is drawn glyph by glyph in `gen_font.py` and
	# has no punctuation beyond ASCII, so anything fancier is a tofu box.
	_continue_detail.text = "DIA %d" % int(summary.get("day", 1))
	UiTheme.describe(_continue_key, "Continuar",
		"Terminal %d, dia %d" % [slot, int(summary.get("day", 1))])


func _continue_last() -> void:
	var slot := int(UserPreferences.last_profile)
	if slot <= 0 or not bool(SaveManager.profile_summary(slot).get("exists", false)):
		_show_board()
		return
	_play(slot)


# --------------------------------------------------------------------- sheets

func _open_options() -> void:
	_open_sheet("AJUSTES", [
		{"kind": "toggle", "label": "MÚSICA",
			"get": func() -> bool: return AudioManager.music_on,
			"set": func(on: bool) -> void: AudioManager.set_music_on(on)},
		{"kind": "toggle", "label": "EFEITOS",
			"get": func() -> bool: return AudioManager.sfx_on,
			"set": func(on: bool) -> void: AudioManager.set_sfx_on(on)},
		{"kind": "toggle", "label": "REDUZIR MOVIMENTO",
			"get": func() -> bool: return UserPreferences.reduce_motion,
			"set": func(on: bool) -> void: UserPreferences.set_reduce_motion(on)},
		{"kind": "toggle", "label": "NÚMEROS FLUTUANTES",
			"get": func() -> bool: return UserPreferences.floating_numbers,
			"set": func(on: bool) -> void: UserPreferences.set_floating_numbers(on)},
		{"kind": "toggle", "label": "TELA CHEIA",
			"get": func() -> bool: return UserPreferences.fullscreen,
			"set": func(on: bool) -> void: UserPreferences.set_fullscreen(on)},
		{"kind": "note", "label":
			"O resto dos ajustes — save, backup e tutorial — fica dentro do terminal, porque pertence a uma operação e não ao aparelho."},
	])


func _open_corner(id: String) -> void:
	AudioManager.play_sfx("tap")
	match id:
		"creditos":
			_open_sheet("CRÉDITOS", [
				{"kind": "note", "label": "HarborClick — %s" % VERSION_LINE},
				{"kind": "note", "label": "%s" % STUDIO_LINE},
				{"kind": "note", "label": "Feito em Godot 4. Cada sprite, fonte, efeito e trilha deste jogo é gerado por código: nada foi desenhado à mão."},
				{"kind": "note", "label": "Jargão de terminal conferido com quem trabalha em porto brasileiro."},
			])
		"site":
			_open_sheet("SITE", [
				{"kind": "note", "label": "O projeto inteiro é aberto, código e geradores de arte."},
				{"kind": "link", "label": "ABRIR REPOSITÓRIO", "url": REPO_URL},
			])
		"feedback":
			_open_sheet("FEEDBACK", [
				{"kind": "note", "label": "Achou um bug ou tem uma ideia? Abra uma issue — é o caminho que a gente lê."},
				{"kind": "link", "label": "ABRIR ISSUES", "url": REPO_URL + "/issues"},
			])
		_:
			_open_sheet("COMUNIDADE", [
				{"kind": "note", "label": "Estratégia, builds e reclamação sobre o pátio cheio."},
				{"kind": "link", "label": "ABRIR DISCUSSÕES",
					"url": REPO_URL + "/discussions"},
			])


func _open_sheet(title: String, rows: Array) -> void:
	_close_sheet()
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sheet)

	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.07, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_close_sheet())
	_sheet.add_child(scrim)

	var panel := PanelContainer.new()
	panel.name = "SheetPanel"
	UiTheme.apply_panel(panel, UiTheme.board_style(10))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 4)
	column.add_child(header)
	var heading := UiTheme.label(title, UiTheme.SIZE_BODY, UiTheme.INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := UiTheme.icon_button(UiTheme.Icon.CLOSE)
	UiTheme.describe(close, "Fechar")
	close.pressed.connect(_close_sheet)
	header.add_child(close)
	column.add_child(UiTheme.divider())

	for row: Dictionary in rows:
		match str(row.get("kind", "note")):
			"toggle":
				column.add_child(_toggle_row(row))
			"link":
				var open := UiTheme.button(str(row.label), &"amber",
					UiTheme.SIZE_SMALL)
				open.custom_minimum_size.y = 26.0
				var url := str(row.url)
				UiTheme.describe(open, str(row.label), url)
				open.pressed.connect(func() -> void: OS.shell_open(url))
				column.add_child(open)
			_:
				var note := UiTheme.label(str(row.label), UiTheme.SIZE_SMALL,
					UiTheme.INK_SOFT)
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				note.custom_minimum_size.x = 0.0
				column.add_child(note)
	_layout()


func _toggle_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 6)
	var label := UiTheme.label(str(row.label), UiTheme.SIZE_SMALL, UiTheme.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var getter: Callable = row.get
	var setter: Callable = row.set
	var key := UiTheme.button("", &"alt", UiTheme.SIZE_SMALL)
	key.custom_minimum_size = Vector2(58, 22)
	var paint := func() -> void:
		var on := bool(getter.call())
		key.text = "LIGADO" if on else "DESLIGADO"
		UiTheme.describe(key, str(row.label), "Ligado" if on else "Desligado")
	paint.call()
	key.pressed.connect(func() -> void:
		setter.call(not bool(getter.call()))
		paint.call())
	line.add_child(key)
	return line


func _close_sheet() -> void:
	if _sheet == null:
		return
	_sheet.queue_free()
	_sheet = null


# --------------------------------------------------------------------- slots

func _refresh() -> void:
	for child in _slots.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.PROFILE_COUNT + 1):
		_slots.add_child(_make_slot(SaveManager.profile_summary(slot)))
	if not SaveManager.storage_available():
		_status.text = "Este navegador não está guardando o progresso."
		_status.label_settings.font_color = UiTheme.DANGER
	_refresh_continue()


func _make_slot(summary: Dictionary) -> PanelContainer:
	var slot := int(summary.slot)
	var used := bool(summary.get("exists", false))
	var armed := _armed_delete == slot
	var card := PanelContainer.new()
	card.custom_minimum_size.y = SLOT_HEIGHT
	UiTheme.apply_panel(card, UiTheme.card_style(&"ready" if used else &"normal"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	card.add_child(row)

	# A photograph of the berth, mounted on the sheet. Three identical black
	# squares numbered 01, 02, 03 told the player which row they were on, which
	# the words beside them already did; a picture tells them there is a place
	# down there. An empty slot gets the same picture with the lights off.
	var badge := TextureRect.new()
	badge.texture = BERTH_ART[(slot - 1) % BERTH_ART.size()]
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.modulate = Color(1, 1, 1) if used else Color(0.52, 0.56, 0.64, 0.85)
	row.add_child(badge)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_line("TERMINAL %d" % slot, UiTheme.SIZE_BODY, UiTheme.INK))
	if used:
		text.add_child(_line("%s TEU  •  DIA %d" % [
			GameState.fmt(float(summary.get("teus", 0.0))),
			int(summary.get("day", 1))], UiTheme.SIZE_SMALL, UiTheme.INK_SOFT))
		var flotations := int(summary.get("prestige", 0))
		text.add_child(_line(
			"%d reconstrução(ões)" % flotations if flotations > 0
				else "primeira operação",
			UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP))
	else:
		text.add_child(_line("CAIS LIVRE", UiTheme.SIZE_SMALL,
			UiTheme.INK_SOFT))

	var keys := VBoxContainer.new()
	keys.add_theme_constant_override(&"separation", 3)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Trimmed from 84 when the berth photograph moved in beside it: the summary
	# line between them is the part that has to be readable, and it was the part
	# paying for the width.
	keys.custom_minimum_size.x = 76.0
	row.add_child(keys)

	var play := UiTheme.button("CONTINUAR" if used else "COMEÇAR", &"amber",
		UiTheme.SIZE_SMALL)
	play.custom_minimum_size.y = 26.0
	UiTheme.describe(play, "%s o terminal %d"
		% ["Continuar" if used else "Começar", slot])
	play.pressed.connect(_play.bind(slot))
	keys.add_child(play)

	if used:
		var erase := UiTheme.button("APAGAR?" if armed else "APAGAR",
			&"danger" if armed else &"ghost", UiTheme.SIZE_SMALL)
		erase.custom_minimum_size.y = 24.0
		UiTheme.describe(erase, "Apagar o terminal %d" % slot,
			"Toque duas vezes. A operação não pode ser desfeita.")
		erase.pressed.connect(_erase.bind(slot))
		keys.add_child(erase)
	return card


func _line(text: String, font_size: int, color: Color) -> Label:
	## Every label on a slot clips. A long terminal summary must never set the
	## board's minimum width — that is what pushed the whole card off a 320px
	## screen the first time.
	var label := UiTheme.label(text, font_size, color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 0.0
	return label


func _play(slot: int) -> void:
	AudioManager.play_sfx("build")
	UserPreferences.set_last_profile(slot)
	SaveManager.use_profile(slot)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _erase(slot: int) -> void:
	## Arming is per slot: confirming has to be the same terminal that was
	## armed, or a mis-tap deletes a run the player never selected.
	if _armed_delete != slot:
		_armed_delete = slot
		_status.text = "Apagar o terminal %d é definitivo. Toque em APAGAR? de novo." % slot
		_status.label_settings.font_color = UiTheme.DANGER
		AudioManager.play_sfx("deny")
		_refresh()
		return
	SaveManager.delete_profile(slot)
	if int(UserPreferences.last_profile) == slot:
		UserPreferences.set_last_profile(0)
	_armed_delete = 0
	_status.text = "Terminal %d apagado." % slot
	_status.label_settings.font_color = UiTheme.INK_SOFT
	AudioManager.play_sfx("tap")
	_refresh()


# -------------------------------------------------------------------- layout

func _layout() -> void:
	# This root is stretched by the project viewport. Its own rect is the logical
	# canvas; the OS window can be 2x or 3x larger and must not leak into control
	# coordinates.
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		view = get_viewport().get_visible_rect().size
	var width := clampf(view.x - 24.0, 260.0, 400.0)
	var left := (view.x - width) * 0.5
	var tight := view.y < 640.0
	var margin := 10.0 if tight else 16.0

	_layout_marquee(view, width, left, tight, margin)
	_layout_board(view, width, left, tight)
	_layout_sheet(view, width, left)


func _layout_marquee(view: Vector2, width: float, left: float, tight: bool,
		margin: float) -> void:
	# Wide enough for the longest caption: COMUNIDADE is ten characters, and a key
	# sized for FEEDBACK clips it to OMUNIDAD, which is worse than no word at all.
	var corner_size := Vector2(78, 50) if not tight else Vector2(70, 44)
	for id: String in _corner_keys:
		var key: Control = _corner_keys[id]
		key.custom_minimum_size = corner_size
		key.size = corner_size
		var corner := str(key.get_meta("corner", "tl"))
		key.position = Vector2(
			margin if corner.ends_with("l") else view.x - corner_size.x - margin,
			margin if corner.begins_with("t") else view.y - corner_size.y - margin)

	var plate_height := 52.0 if tight else 60.0
	var plate_width := clampf(width * 0.92, 220.0, 340.0)
	_plate.custom_minimum_size = Vector2(plate_width, plate_height)
	_plate.size = Vector2(plate_width, plate_height)
	# Below the top corner keys, never under them: at 320x568 the keys and the
	# plate both want the top of the frame and the plate is the one that can move.
	_plate.position = Vector2((view.x - plate_width) * 0.5,
		margin + corner_size.y + (6.0 if tight else 12.0))

	# The ribbon hangs under the plate, narrower than it, so the two read as a
	# board and a strip screwed to it rather than one tall panel.
	var ribbon_size := Vector2(clampf(plate_width * 0.86, 180.0, 300.0),
		16.0 if tight else 18.0)
	_ribbon.custom_minimum_size = ribbon_size
	_ribbon.size = ribbon_size
	_ribbon.position = Vector2((view.x - ribbon_size.x) * 0.5,
		_plate.position.y + plate_height - 3.0)

	# The crest straddles the plate's top edge: half on the enamel, half above
	# it. Centred on the plate rather than on the screen, so it stays with the
	# board when the board is narrower than the frame. Native size, always — the
	# drawing is 40x55 and every other number here would resample it.
	var crest_size := Vector2(_crest.texture.get_width(),
		_crest.texture.get_height())
	_crest.size = crest_size
	_crest.custom_minimum_size = crest_size
	_crest.position = Vector2(
		_plate.position.x + (plate_width - crest_size.x) * 0.5,
		_plate.position.y - crest_size.y * 0.74)

	var action_width := clampf(width * 0.78, 180.0, 260.0)
	_actions.custom_minimum_size.x = action_width
	_actions.size.x = action_width
	var action_height := _actions.get_combined_minimum_size().y
	_actions.position = Vector2((view.x - action_width) * 0.5,
		clampf(view.y * 0.62 - action_height * 0.5,
			_ribbon.position.y + _ribbon.size.y + 14.0,
			view.y - action_height - corner_size.y - margin * 3.0))

	# The pool of dusk under the keys, wider and taller than they are so its
	# fade has somewhere to happen. It follows the keys rather than the screen:
	# the keys are what it exists to make readable.
	var scrim_size := Vector2(minf(view.x, action_width + 96.0),
		action_height + 84.0)
	_scrim.size = scrim_size
	_scrim.position = Vector2((view.x - scrim_size.x) * 0.5,
		_actions.position.y - 42.0)

	var footer_height := _footer.get_combined_minimum_size().y
	_footer.custom_minimum_size.x = width
	_footer.size = Vector2(width, footer_height)
	_footer.position = Vector2(left,
		view.y - footer_height - margin - (2.0 if tight else 6.0))


func _layout_board(view: Vector2, width: float, left: float,
		tight: bool) -> void:
	var height := minf(view.y - 60.0, 372.0)
	_board.custom_minimum_size = Vector2(width, height)
	_board.size = Vector2(width, height)
	# PanelContainer may still be completing its first child sort when this
	# screen is built. Re-apply the authored rect after that sort so the old
	# default window height cannot survive into a smaller phone viewport.
	_board.set_deferred(&"size", Vector2(width, height))
	_board.position = Vector2(left, maxf(20.0,
		view.y - height - (14.0 if tight else 34.0)))
	UiTheme.place_clip(_clip, _board, Rect2(Vector2.ZERO, view))
	var pencil := _board_page.get_node_or_null(^"Pencil") as Control
	if pencil != null:
		pencil.position = _board.position + Vector2(
			_board.size.x - pencil.size.x - 16.0, _board.size.y - 14.0)


func _layout_sheet(view: Vector2, width: float, left: float) -> void:
	if _sheet == null:
		return
	var panel := _sheet.get_node_or_null(^"SheetPanel") as Control
	if panel == null:
		return
	panel.custom_minimum_size.x = width
	panel.size.x = width
	var height := minf(panel.get_combined_minimum_size().y, view.y - 48.0)
	panel.size = Vector2(width, height)
	panel.position = Vector2(left, clampf((view.y - height) * 0.5, 24.0,
		maxf(24.0, view.y - height - 24.0)))
