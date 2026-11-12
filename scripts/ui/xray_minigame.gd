class_name XrayMinigame
extends MinigameBoard
## The Receita Federal's inspection: read the lorry's X-ray through its views.
##
## Three beats. A lorry drives through the drive-through scanner on the quay —
## a real container portal over a real lane — and the monitor under the scene
## builds its picture one column at a time as the beam crosses it, cab first.
## The software boots. Then the scan is up and the clock runs.
##
## The scan is one picture and four views (`XrayScan.Filter`). The raw view is
## what the beam sees: cartons, machinery, a ghost of something in every box —
## and nothing that can be seized. METAL paints the metal blue, ORGANIC the
## organics orange, RAIO+ sees through the machinery. The player switches views
## with the bar under the monitor (or 1-4) and taps each contraband in the
## view that shows it. A wrong tap costs seconds; the raw view only asks for a
## filter.
##
## The images are built pixel by pixel at a low resolution, one per view, and
## drawn with nearest filtering, so they read as pixel art and not a photo.
## Switching view wipes the new picture across the old one like a re-render.
##
## The rules are `XrayScan`; this file builds the images, draws and reads input.

const Filter := XrayScan.Filter
const ITEMS_TEX := preload("res://assets/sprites/ui_xray_items.png")
const PORTAL := preload("res://assets/sprites/ui_xray_portal.png")
const TRUCK := preload("res://assets/sprites/ui_xray_truck.png")
const BRAND := "CREATUS SECURITY e VWI"
const ROLL_TIME := 3.4
const BOOT_TIME := 0.8
const WIPE_TIME := 0.22
## The portal and lorry sheets (`tools/sprites/gen_customs.py`).
const PORTAL_FRAME := Vector2(76, 74)
const PORTAL_ROAD := 70.0
const PORTAL_BEAM_X := 36.0
const TRUCK_FRAME := Vector2(112, 44)
## The scan image, in its own pixels: the lorry side-on, the box on the left,
## the cab on the right. `INNER` is the cargo space, and item centres live
## there normalised by `XrayScan` (0..1 over `INNER`).
const IMG := Vector2i(256, 116)
const BOX := Rect2i(6, 10, 196, 90)
const WALL := 3
const INNER := Rect2(9.0, 13.0, 190.0, 84.0)
## A thing is the sheet's 16px sprite at 2x, so 32px in image pixels.
const SPRITE := 16
const SPRITE_SCALE := 2
const RETICLE_R := 20.0
const BEZEL := Color8(20, 22, 32)
const BAR := Color8(18, 40, 58)

## What each view looks like: the film, the steel of the lorry, the cartons,
## the machinery and the ramp a shown thing is painted in.
const LOOK := {
	Filter.RAW: {"bg": Color8(232, 236, 230), "steel": Color8(92, 96, 100),
		"steel_hi": Color8(140, 144, 146), "tyre": Color8(58, 60, 64),
		"carton": Color8(204, 204, 196), "carton_edge": Color8(170, 170, 162),
		"block": Color8(68, 70, 74), "block_hi": Color8(104, 106, 110),
		"accent": Color8(210, 214, 206)},
	Filter.METAL: {"bg": Color8(14, 20, 38), "steel": Color8(34, 64, 128),
		"steel_hi": Color8(56, 96, 170), "tyre": Color8(24, 34, 60),
		"carton": Color8(0, 0, 0, 0), "carton_edge": Color8(34, 44, 72),
		"block": Color8(96, 156, 250), "block_hi": Color8(170, 210, 255),
		"accent": Color8(70, 170, 255)},
	Filter.ORGANIC: {"bg": Color8(28, 18, 12), "steel": Color8(62, 52, 46),
		"steel_hi": Color8(84, 72, 62), "tyre": Color8(130, 66, 24),
		"carton": Color8(58, 36, 20), "carton_edge": Color8(96, 62, 32),
		"block": Color8(10, 6, 6), "block_hi": Color8(36, 24, 18),
		"accent": Color8(255, 150, 60)},
	Filter.DENSE: {"bg": Color8(230, 226, 240), "steel": Color8(164, 158, 188),
		"steel_hi": Color8(196, 192, 214), "tyre": Color8(140, 132, 166),
		"carton": Color8(206, 202, 220), "carton_edge": Color8(172, 166, 196),
		"block": Color8(150, 140, 180), "block_hi": Color8(120, 110, 156),
		"accent": Color8(140, 96, 230)},
}
## Ramps, darkest first, for a thing a view shows.
const RAMP_METAL := [Color8(30, 70, 170), Color8(76, 146, 244), Color8(186, 228, 255)]
const RAMP_ORGANIC := [Color8(156, 62, 18), Color8(240, 134, 46), Color8(255, 210, 136)]
const RAMP_GLASS := [Color8(30, 110, 60), Color8(92, 192, 102), Color8(196, 252, 186)]
const RAMP_DENSE := [Color8(36, 20, 66), Color8(84, 56, 140), Color8(150, 126, 204)]
## The bar's own chip colour per view.
const CHIP := {Filter.RAW: Color8(200, 204, 196), Filter.METAL: Color8(76, 146, 244),
	Filter.ORGANIC: Color8(240, 134, 46), Filter.DENSE: Color8(150, 110, 230)}
const FILTER_KEYS := {Filter.RAW: "raw", Filter.METAL: "metal",
	Filter.ORGANIC: "organic", Filter.DENSE: "dense"}

enum Phase { ROLL, BOOT, SCAN }

var game: XrayScan
var phase := Phase.ROLL
var filter: Filter = Filter.RAW
var _phase_t := 0.0
var _screen: Control
var _img_rect := Rect2()
var _reticle := Vector2(-1, -1)   # where the finger last pointed, in screen px
var _marks: Array[Dictionary] = []
var _beep_t := 0.0
var _scan_no := 1
var _found_t := 0.0
var _livery := 0
var _portal: Array[AtlasTexture] = []
var _truck: Array[AtlasTexture] = []
var _tex: Dictionary = {}          # Filter -> ImageTexture
var _wipe_t := 1.0
var _wipe_from: Filter = Filter.RAW
var _bar: HBoxContainer
var _filter_buttons: Dictionary = {}   # Filter -> Button
var _nudge_t := 0.0
## The first scan of these rules teaches itself: a card over the monitor that
## says what each view finds. The clock does not run while it is up, and it
## never comes back once dismissed (`flags.xray_coached2`).
var _coach: PanelContainer


func _build_field(column: VBoxContainer) -> void:
	var bezel := UiTheme.panel(UiTheme.arcade_style(6), false)
	bezel.custom_minimum_size.y = 168.0
	bezel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bezel)
	_screen = Control.new()
	_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.focus_mode = Control.FOCUS_ALL
	_screen.clip_contents = true
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.gui_input.connect(_on_screen_input)
	_screen.draw.connect(_draw_screen)
	UiTheme.describe(_screen, BRAND, Loc.t("xray.hint"))
	bezel.add_child(_screen)
	for index in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = PORTAL
		atlas.region = Rect2(Vector2(index * PORTAL_FRAME.x, 0), PORTAL_FRAME)
		_portal.append(atlas)
	for index in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas = TRUCK
		atlas.region = Rect2(Vector2(index * TRUCK_FRAME.x, 0), TRUCK_FRAME)
		_truck.append(atlas)
	_build_bar(column)
	_build_coach(bezel)


func _build_bar(column: VBoxContainer) -> void:
	## The four views, as keys under the monitor: the active one lit amber,
	## each with its own colour chip so the key matches what it paints.
	_bar = HBoxContainer.new()
	_bar.name = "Filters"
	_bar.add_theme_constant_override(&"separation", 3)
	column.add_child(_bar)
	for f: Filter in [Filter.RAW, Filter.METAL, Filter.ORGANIC, Filter.DENSE]:
		var key := UiTheme.button(Loc.t("xray.filter." + FILTER_KEYS[f]), &"steel",
			UiTheme.SIZE_SMALL)
		key.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.icon = _chip_texture(CHIP[f])
		key.clip_text = true
		key.pressed.connect(_pick_filter.bind(f))
		UiTheme.describe(key, key.text, Loc.t("xray.tip." + FILTER_KEYS[f]))
		_bar.add_child(key)
		_filter_buttons[f] = key


static func _chip_texture(colour: Color) -> ImageTexture:
	var img := Image.create_empty(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color8(20, 18, 28))
	img.fill_rect(Rect2i(1, 1, 4, 4), colour)
	img.set_pixel(1, 1, colour.lightened(0.4))
	return ImageTexture.create_from_image(img)


func _build_coach(over: Control) -> void:
	_coach = UiTheme.panel(UiTheme.paper_style(6), false)
	_coach.name = "Coach"
	_coach.visible = false
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP
	over.add_child(_coach)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_coach.add_child(column)
	var title := UiTheme.label(Loc.t("xray.coach.title"), UiTheme.SIZE_BODY,
		UiTheme.AMBER_DEEP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var body := UiTheme.label(Loc.t("xray.coach.body"), UiTheme.SIZE_SMALL,
		UiTheme.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size.x = 160.0
	column.add_child(body)
	# One row per view: its chip, what it finds, and the shapes it finds.
	var rows: Array = [
		[Filter.METAL, "xray.coach.metal", [&"pistol", &"rifle", &"grenade"]],
		[Filter.ORGANIC, "xray.coach.organic", [&"bricks", &"macaw"]],
		[Filter.DENSE, "xray.coach.dense", []],
	]
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 4)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(line)
		var chip := TextureRect.new()
		chip.texture = _chip_texture(CHIP[row[0]])
		chip.custom_minimum_size = Vector2(12, 12)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(chip)
		line.add_child(UiTheme.label(Loc.t(row[1]), UiTheme.SIZE_SMALL, UiTheme.INK))
		for id: StringName in row[2]:
			var cell := TextureRect.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = ITEMS_TEX
			atlas.region = Rect2(XrayScan.item_index(id) * SPRITE, 0, SPRITE, SPRITE)
			cell.texture = atlas
			cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cell.custom_minimum_size = Vector2(SPRITE, SPRITE)
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			line.add_child(cell)
	var ok := UiTheme.button(Loc.t("xray.coach.ok"), &"amber", UiTheme.SIZE_SMALL)
	ok.custom_minimum_size = Vector2(110, 28)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_dismiss_coach)
	column.add_child(ok)


func _show_coach() -> bool:
	if _coach == null or GameState.flags.get("xray_coached2", false):
		return false
	_coach.visible = true
	return true


func _dismiss_coach() -> void:
	if _coach == null or not _coach.visible:
		return
	_coach.visible = false
	GameState.flags["xray_coached2"] = true
	AudioManager.play_sfx("tap")
	_screen.grab_focus()


func coach_visible() -> bool:
	return _coach != null and _coach.visible


func _begin(offer: Dictionary) -> void:
	game = XrayScan.new()
	var scan_seed := int(offer.get("seed", 1))
	game.setup(scan_seed, int(offer.get("level", 0)))
	_scan_no = int(offer.get("scan_no", 1))
	_livery = absi(scan_seed) % 3
	_marks.clear()
	_found_t = 0.0
	_beep_t = 0.0
	_wipe_t = 1.0
	_reticle = Vector2(-1, -1)
	filter = Filter.RAW
	_build_images(scan_seed)
	# A retry after an ad goes straight back to the scan: the lorry already
	# went through the portal once.
	_set_phase(Phase.SCAN if _retried or not UserPreferences.can_animate()
		else Phase.ROLL)
	_refresh_bar()
	_screen.grab_focus()
	_refresh()


func _set_phase(next: Phase) -> void:
	phase = next
	_phase_t = 0.0
	match phase:
		Phase.ROLL:
			_hint.text = Loc.t("xray.rolling")
		Phase.BOOT:
			_hint.text = Loc.t("xray.booting")
			AudioManager.play_sfx("ui_open", 0.02, -6.0)
		Phase.SCAN:
			_hint.text = Loc.t("xray.tip." + FILTER_KEYS[filter])
			AudioManager.play_sfx("click", 0.04, -4.0)
			_show_coach()
	_refresh_bar()


func _pick_filter(next: Filter) -> void:
	if game == null or _closing:
		return
	if phase != Phase.SCAN:
		_set_phase(Phase.SCAN)
	if next == filter:
		return
	_wipe_from = filter
	filter = next
	_wipe_t = 0.0 if UserPreferences.can_animate() else 1.0
	_hint.text = Loc.t("xray.tip." + FILTER_KEYS[filter])
	AudioManager.play_sfx_pitched("wheel_tick", 0.8 + 0.15 * float(int(next)), -6.0)
	_refresh_bar()
	_screen.queue_redraw()


func _refresh_bar() -> void:
	for f: Filter in _filter_buttons:
		var key: Button = _filter_buttons[f]
		UiTheme.style_button(key, &"amber" if f == filter else &"steel")


func _tick(delta: float) -> void:
	if game == null:
		return
	_phase_t += delta
	match phase:
		Phase.ROLL:
			if _scanning():
				_beep_t -= delta
				if _beep_t <= 0.0:
					_beep_t = 0.22
					AudioManager.play_sfx_pitched("wheel_tick", 1.6, -8.0)
			if _phase_t >= ROLL_TIME:
				_set_phase(Phase.BOOT)
		Phase.BOOT:
			if _phase_t >= BOOT_TIME:
				_set_phase(Phase.SCAN)
		Phase.SCAN:
			# The clock waits for the player to have read how the game works.
			if not coach_visible():
				game.advance(delta)
	for mark: Dictionary in _marks:
		mark.t = float(mark.t) + delta
	_found_t += delta
	_wipe_t = minf(1.0, _wipe_t + delta / WIPE_TIME)
	_nudge_t = maxf(0.0, _nudge_t - delta)
	if _bar != null:
		# A tap in the raw view pulses the bar: that is where the answer is.
		var pulse := 1.0 + 0.35 * sin(_nudge_t * 18.0) * _nudge_t
		_bar.modulate = Color(pulse, pulse, pulse)
	_screen.queue_redraw()
	_refresh()


# --------------------------------------------------------------------- input

func _on_screen_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	var press := false
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	var drag := event as InputEventScreenDrag
	var motion := event as InputEventMouseMotion
	if touch != null and touch.pressed:
		at = touch.position
		press = true
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		at = click.position
		press = true
	elif drag != null:
		at = drag.position
	elif motion != null:
		at = motion.position
	else:
		return
	_screen.accept_event()
	if game == null or _closing:
		return
	if phase != Phase.SCAN:
		# The intro is a show, not a wait: a tap skips straight to the scan.
		if press:
			_set_phase(Phase.SCAN)
		return
	_reticle = _clamp_into_image(at)
	if press:
		_seize_at(at)


func _seize_at(at: Vector2) -> void:
	## Tap the picture at `at`, in screen coordinates, in the current view.
	if game == null or _closing or phase != Phase.SCAN or _img_rect.size.x <= 0.0:
		return
	var result := game.tap(_to_norm(at), filter)
	if bool(result.raw):
		_nudge_t = 1.0
		_say(Loc.t("xray.need_filter"), UiTheme.AMBER)
		AudioManager.play_sfx("deny", 0.04, -10.0)
	elif bool(result.hit):
		_found_t = 0.0
		_say(Loc.t("xray.found"), UiTheme.TEAL_LIGHT)
		AudioManager.play_sfx("milestone", 0.02, -2.0)
	elif not bool(result.again):
		_marks.append({"at": at, "t": 0.0})
		if float(result.penalty) > 0.0:
			_shake = maxf(_shake, 0.4)
			_say("-%.1fs" % XrayScan.WRONG_PENALTY, UiTheme.DANGER)
			AudioManager.play_sfx("deny", 0.06, -4.0)
	if game.over and not game.victory:
		_show_answer()
	_refresh()


func _show_answer() -> void:
	## A lost scan turns to the view that shows what got away.
	var missed := game.contraband()
	if not missed.is_empty() and not bool(missed.seized):
		var view := XrayScan.filter_for(missed)
		if view != filter:
			_wipe_from = filter
			filter = view
			_wipe_t = 0.0
			_refresh_bar()


func _unhandled_key_input(event: InputEvent) -> void:
	## 1-4 pick a view, Space/Enter taps where the reticle is, arrows walk it.
	## Nothing here is only reachable by pointing.
	if not visible or _closing or game == null:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var step := Vector2.ZERO
	match key.keycode:
		KEY_1, KEY_KP_1:
			_pick_filter(Filter.RAW)
		KEY_2, KEY_KP_2:
			_pick_filter(Filter.METAL)
		KEY_3, KEY_KP_3:
			_pick_filter(Filter.ORGANIC)
		KEY_4, KEY_KP_4:
			_pick_filter(Filter.DENSE)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if key.echo:
				return
			if phase != Phase.SCAN:
				_set_phase(Phase.SCAN)
			else:
				_seize_at(_reticle_point())
		KEY_LEFT, KEY_A:
			step = Vector2(-8, 0)
		KEY_RIGHT, KEY_D:
			step = Vector2(8, 0)
		KEY_UP, KEY_W:
			step = Vector2(0, -8)
		KEY_DOWN, KEY_S:
			step = Vector2(0, 8)
		_:
			return
	if step != Vector2.ZERO and phase == Phase.SCAN:
		_reticle = _clamp_into_image(_reticle_point() + step * _image_scale())
	get_viewport().set_input_as_handled()
	_screen.queue_redraw()


func _reticle_point() -> Vector2:
	if _reticle.x >= 0.0:
		return _reticle
	return _img_rect.get_center()


func _clamp_into_image(at: Vector2) -> Vector2:
	if _img_rect.size.x <= 0.0:
		return Vector2(-1, -1)
	var inner := _img_rect.grow(-_image_scale() * 4.0)
	return Vector2(clampf(at.x, inner.position.x, inner.end.x),
		clampf(at.y, inner.position.y, inner.end.y))


func _image_scale() -> float:
	## Screen pixels per image pixel.
	return _img_rect.size.x / float(IMG.x) if _img_rect.size.x > 0.0 else 1.0


func _to_norm(at: Vector2) -> Vector2:
	## Screen point -> the rules' normalised coordinates (0..1 over `INNER`).
	var img := (at - _img_rect.position) / _image_scale()
	return (img - INNER.position) / INNER.size


func _to_screen(norm: Vector2) -> Vector2:
	return _img_rect.position + (INNER.position + norm * INNER.size) * _image_scale()


func _refresh() -> void:
	if game == null:
		return
	var clock := "%4.1fs" % (game.time_left if phase == Phase.SCAN else game.time_total)
	_set_stats(clock, Loc.t("xray.found_n", {"n": str(game.found), "t": str(game.total())}),
		Loc.t("xray.level", {"n": str(game.level + 1)}))


func _over() -> bool:
	return game != null and game.over


func _won() -> bool:
	return game != null and game.victory


func _summary() -> Dictionary:
	return game.summary() if game != null else {}


func _result_text(won: bool) -> String:
	return Loc.t("xray.win") if won else Loc.t("xray.lose")


func _closing_hint() -> String:
	if game == null:
		return ""
	if game.victory:
		var mult := XrayPolicy.CLEAN_MULT if game.mistakes <= 0 else XrayPolicy.BENEFIT_MULT
		return Loc.t("xray.benefit", {"mult": str(int(mult)),
			"s": str(int(XrayPolicy.BENEFIT_SECONDS))})
	var id := String(game.contraband().get("id", ""))
	return Loc.t("xray.missed", {"item": Loc.t("xray.item." + id)})


# --------------------------------------------------------------- scan painting

func _build_images(scan_seed: int) -> void:
	## One picture per view, all of the same lorry. Big areas are filled with
	## `fill_rect` and only the things are walked pixel by pixel, so the four
	## images cost about what one used to.
	var sheet := ITEMS_TEX.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	_tex.clear()
	for f: Filter in [Filter.RAW, Filter.METAL, Filter.ORGANIC, Filter.DENSE]:
		var rng := RandomNumberGenerator.new()
		rng.seed = scan_seed * 31 + 5
		_tex[f] = ImageTexture.create_from_image(_paint_view(f, sheet, rng))


func _paint_view(f: Filter, sheet: Image, rng: RandomNumberGenerator) -> Image:
	var look: Dictionary = LOOK[f]
	var img := Image.create_empty(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	var bg: Color = look.bg
	img.fill(bg)
	# Sensor noise, sparse and quantised: pixel art, not a gradient.
	var grain := bg.darkened(0.06) if bg.get_luminance() > 0.5 else bg.lightened(0.08)
	for i in 900:
		img.set_pixel(rng.randi_range(0, IMG.x - 1), rng.randi_range(0, IMG.y - 1), grain)
	_paint_truck(img, look)
	_paint_box(img, look)
	for cell: Dictionary in game.cells:
		var rect := _cell_rect(int(cell.cell))
		match StringName(cell.kind):
			&"carton":
				_paint_carton(img, rect, look)
			&"block":
				if f == Filter.DENSE:
					_paint_block_ghost(img, rect, look)
	for item: Dictionary in game.items:
		if XrayScan.shows(item, f):
			_paint_item(img, sheet, item, _ramp(item, f), true)
		elif f == Filter.RAW and item.behind == &"carton":
			# The raw view keeps a smudge in every carton: there is something
			# in each box, and only a filter says what — never its shape.
			_paint_smudge(img, _cell_rect(int(item.cell)), look.carton, rng)
	if f != Filter.DENSE:
		for cell: Dictionary in game.cells:
			if cell.kind == &"block":
				_paint_block(img, _cell_rect(int(cell.cell)), look, f, rng)
	return img


func _ramp(item: Dictionary, f: Filter) -> Array:
	match f:
		Filter.METAL:
			return RAMP_METAL
		Filter.ORGANIC:
			return RAMP_GLASS if item.material == &"glass" else RAMP_ORGANIC
		Filter.DENSE:
			return RAMP_DENSE
	return RAMP_DENSE


func _cell_rect(cell: int) -> Rect2i:
	var w := INNER.size.x / XrayScan.COLS
	var h := INNER.size.y / XrayScan.ROWS
	var x := INNER.position.x + float(cell % XrayScan.COLS) * w
	var y := INNER.position.y + float(cell / XrayScan.COLS) * h
	return Rect2i(int(round(x)) + 1, int(round(y)) + 1, int(w) - 2, int(h) - 2)


func _paint_truck(img: Image, look: Dictionary) -> void:
	## The lorry as the beam sees it: chassis rail, tyres, and the cab with
	## its engine block — the densest thing on the picture.
	var steel: Color = look.steel
	var hi: Color = look.steel_hi
	var tyre: Color = look.tyre
	img.fill_rect(Rect2i(2, BOX.end.y, 250, 4), steel)
	img.fill_rect(Rect2i(2, BOX.end.y, 250, 1), hi)
	for x: int in [30, 48, 216, 240]:
		_disc(img, Vector2i(x, BOX.end.y + 7), 6, tyre)
		_disc(img, Vector2i(x, BOX.end.y + 7), 3, hi)
		_disc(img, Vector2i(x, BOX.end.y + 7), 1, steel)
	# the cab: a frame round the windscreen and door, a seat, the engine
	var cab := Rect2i(208, 36, 40, BOX.end.y - 36)
	img.fill_rect(Rect2i(cab.position.x, cab.position.y, cab.size.x, 2), steel)
	img.fill_rect(Rect2i(cab.position.x, cab.position.y, 2, cab.size.y), steel)
	img.fill_rect(Rect2i(cab.end.x - 2, cab.position.y + 6, 2, cab.size.y - 6), steel)
	for i in 6:
		img.fill_rect(Rect2i(cab.end.x - 2 - (5 - i), cab.position.y + i, 2, 1), steel)
	img.fill_rect(Rect2i(cab.position.x, cab.position.y + 26, cab.size.x, 2), hi)
	img.fill_rect(Rect2i(214, 56, 8, 10), hi)          # seat back
	img.fill_rect(Rect2i(214, 66, 14, 3), hi)          # seat
	_disc(img, Vector2i(234, 58), 4, hi)               # steering wheel
	_disc(img, Vector2i(234, 58), 2, look.bg)
	var engine := Rect2i(226, 72, 18, BOX.end.y - 74)
	img.fill_rect(engine, look.block)
	img.fill_rect(Rect2i(engine.position.x, engine.position.y, engine.size.x, 1),
		look.block_hi)
	for y in range(engine.position.y + 3, engine.end.y - 1, 4):
		img.fill_rect(Rect2i(engine.position.x + 2, y, engine.size.x - 4, 1), look.block_hi)
	img.fill_rect(Rect2i(210, BOX.end.y - 6, 12, 6), hi)    # fuel tank
	img.fill_rect(Rect2i(202, BOX.end.y - 2, 6, 2), steel)  # fifth wheel


func _paint_box(img: Image, look: Dictionary) -> void:
	## The twenty-footer's steel: walls with their corrugation, corner posts.
	var steel: Color = look.steel
	var hi: Color = look.steel_hi
	img.fill_rect(Rect2i(BOX.position.x, BOX.position.y, BOX.size.x, WALL), steel)
	img.fill_rect(Rect2i(BOX.position.x, BOX.end.y - WALL, BOX.size.x, WALL), steel)
	img.fill_rect(Rect2i(BOX.position.x, BOX.position.y, WALL, BOX.size.y), steel)
	img.fill_rect(Rect2i(BOX.end.x - WALL, BOX.position.y, WALL, BOX.size.y), steel)
	for x in range(BOX.position.x + 4, BOX.end.x - 3, 6):
		img.fill_rect(Rect2i(x, BOX.position.y + 1, 2, 1), hi)
		img.fill_rect(Rect2i(x, BOX.end.y - 2, 2, 1), hi)
	for corner: Vector2i in [BOX.position, Vector2i(BOX.end.x - 5, BOX.position.y),
			Vector2i(BOX.position.x, BOX.end.y - 5), BOX.end - Vector2i(5, 5)]:
		img.fill_rect(Rect2i(corner, Vector2i(5, 5)), hi)
	# the door end's locking bars, and the floor the cargo stands on
	for x: int in [BOX.position.x + 6, BOX.position.x + 10]:
		img.fill_rect(Rect2i(x, BOX.position.y + WALL, 1, BOX.size.y - WALL * 2), hi)


func _paint_carton(img: Image, rect: Rect2i, look: Dictionary) -> void:
	var fill: Color = look.carton
	var edge: Color = look.carton_edge
	if fill.a > 0.0:
		img.fill_rect(rect, fill)
	img.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, 1), edge)
	img.fill_rect(Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1), edge)
	img.fill_rect(Rect2i(rect.position.x, rect.position.y, 1, rect.size.y), edge)
	img.fill_rect(Rect2i(rect.end.x - 1, rect.position.y, 1, rect.size.y), edge)
	if fill.a > 0.0:
		# the tape seam across the lid
		img.fill_rect(Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + 1,
			1, rect.size.y - 2), fill.lightened(0.08))


func _paint_smudge(img: Image, rect: Rect2i, carton: Color,
		rng: RandomNumberGenerator) -> void:
	var dark := carton.darkened(0.045)
	var inner := rect.grow(-7)
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			if (x + y) % 2 == 0 or rng.randf() < 0.3:
				img.set_pixel(x, y, dark)


func _paint_block(img: Image, rect: Rect2i, look: Dictionary, f: Filter,
		rng: RandomNumberGenerator) -> void:
	## Machinery: an engine block on a skid. Opaque in every view but RAIO+ —
	## saturated in METAL, black in ORGANIC, a dark mass on the raw film.
	var body: Color = look.block
	var hi: Color = look.block_hi
	img.fill_rect(rect, body)
	img.fill_rect(Rect2i(rect.position.x, rect.end.y - 4, rect.size.x, 4), hi)
	if f == Filter.METAL:
		# a detector saturated by dense steel: hard diagonal hatching
		for y in range(rect.position.y, rect.end.y - 4):
			for x in range(rect.position.x, rect.end.x):
				if (x + y) % 5 == 0:
					img.set_pixel(x, y, hi)
	else:
		# cylinder heads and bolts
		for i in 3:
			var cx := rect.position.x + 6 + i * (rect.size.x - 12) / 2
			_disc(img, Vector2i(cx, rect.position.y + 10), 4, hi)
			_disc(img, Vector2i(cx, rect.position.y + 10), 2, body)
		for x in range(rect.position.x + 3, rect.end.x - 3, 5):
			img.set_pixel(x, rect.position.y + 22 + rng.randi_range(0, 1), hi)


func _paint_block_ghost(img: Image, rect: Rect2i, look: Dictionary) -> void:
	## RAIO+ sees through machinery: only its outline, dashed, is left.
	var edge: Color = look.block
	for x in range(rect.position.x, rect.end.x):
		if (x / 2) % 2 == 0:
			img.set_pixel(x, rect.position.y, edge)
			img.set_pixel(x, rect.end.y - 1, edge)
	for y in range(rect.position.y, rect.end.y):
		if (y / 2) % 2 == 0:
			img.set_pixel(rect.position.x, y, edge)
			img.set_pixel(rect.end.x - 1, y, edge)


func _paint_item(img: Image, sheet: Image, item: Dictionary, ramp: Array,
		outlined: bool) -> void:
	## One thing at 2x from the sheet, its shading mapped onto `ramp` by the
	## sprite's own lightness, outlined so it separates from its carton.
	var size_i := SPRITE * SPRITE_SCALE
	var cell := _cell_rect(int(item.cell))
	var centre := INNER.position + (item.pos as Vector2) * INNER.size
	var origin := Vector2i((centre - Vector2(size_i, size_i) * 0.5).round())
	origin.x = clampi(origin.x, cell.position.x + 1, cell.end.x - size_i - 1)
	origin.y = clampi(origin.y, cell.position.y + 1, cell.end.y - size_i - 1)
	var flip := bool(item.flip)
	var frame := int(item.frame)
	var dark: Color = ramp[0]
	var line := dark.darkened(0.45) if dark.get_luminance() < 0.5 \
		else dark.darkened(0.3)
	for sy in SPRITE:
		for sx in SPRITE:
			var c := _sheet_px(sheet, frame, sx, sy, flip)
			if c.a < 0.5:
				continue
			var lum := c.get_luminance()
			var tone: Color = ramp[0] if lum < 0.32 else (ramp[1] if lum < 0.62 else ramp[2])
			var q := origin + Vector2i(sx * SPRITE_SCALE, sy * SPRITE_SCALE)
			img.fill_rect(Rect2i(q, Vector2i(SPRITE_SCALE, SPRITE_SCALE)), tone)
			if not outlined:
				continue
			# a 1px edge on every side that faces empty sprite
			if _sheet_px(sheet, frame, sx - 1, sy, flip).a < 0.5:
				img.fill_rect(Rect2i(q.x - 1, q.y, 1, SPRITE_SCALE), line)
			if _sheet_px(sheet, frame, sx + 1, sy, flip).a < 0.5:
				img.fill_rect(Rect2i(q.x + SPRITE_SCALE, q.y, 1, SPRITE_SCALE), line)
			if _sheet_px(sheet, frame, sx, sy - 1, flip).a < 0.5:
				img.fill_rect(Rect2i(q.x, q.y - 1, SPRITE_SCALE, 1), line)
			if _sheet_px(sheet, frame, sx, sy + 1, flip).a < 0.5:
				img.fill_rect(Rect2i(q.x, q.y + SPRITE_SCALE, SPRITE_SCALE, 1), line)


static func _sheet_px(sheet: Image, frame: int, sx: int, sy: int, flip: bool) -> Color:
	if sx < 0 or sy < 0 or sx >= SPRITE or sy >= SPRITE:
		return Color(0, 0, 0, 0)
	return sheet.get_pixel(frame * SPRITE + (SPRITE - 1 - sx if flip else sx), sy)


static func _disc(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r + r:
				var q := c + Vector2i(x, y)
				if q.x >= 0 and q.y >= 0 and q.x < IMG.x and q.y < IMG.y:
					img.set_pixel(q.x, q.y, colour)


# ---------------------------------------------------------------------- view

func _truck_x(w: float) -> float:
	## The lorry's left edge, in screen px: it eases in, crawls under the beam
	## (a real drive-through runs at walking pace) and pulls away.
	var k := clampf(_phase_t / ROLL_TIME, 0.0, 1.0)
	var eased := k + sin(k * TAU) * -0.07
	return lerpf(-TRUCK_FRAME.x - 6.0, w + 6.0, eased)


func _beam_x(w: float) -> float:
	return roundf((w - PORTAL_FRAME.x) * 0.5) + PORTAL_BEAM_X


func _scanned(w: float) -> float:
	## How much of the lorry has passed the beam, 0..1, cab first.
	return clampf((_truck_x(w) + TRUCK_FRAME.x - _beam_x(w)) / TRUCK_FRAME.x, 0.0, 1.0)


func _scanning() -> bool:
	if _screen == null:
		return false
	var s := _scanned(_screen.size.x)
	return s > 0.0 and s < 1.0


func _draw_screen() -> void:
	if _screen == null or game == null:
		return
	var w := _screen.size.x
	var h := _screen.size.y
	if w <= 0.0 or h <= 0.0:
		return
	match phase:
		Phase.ROLL:
			_draw_roll(w, h)
		Phase.BOOT:
			_draw_boot(w, h)
		Phase.SCAN:
			_draw_scan(w, h)


func _draw_roll(w: float, h: float) -> void:
	## The quay at the scanner, above; the monitor building the picture, below.
	var scene_h := roundf(h * 0.56)
	var road_y := scene_h - 10.0
	# sky in three flat bands, a far quay with its cranes, a fence
	_screen.draw_rect(Rect2(0, 0, w, scene_h), Color8(146, 196, 228))
	_screen.draw_rect(Rect2(0, scene_h * 0.34, w, scene_h * 0.3), Color8(170, 212, 236))
	_screen.draw_rect(Rect2(0, scene_h * 0.56, w, road_y - scene_h * 0.56),
		Color8(196, 224, 238))
	# the sun and a few slow clouds
	var sun := Vector2(w - 30.0, 16.0)
	_screen.draw_circle(sun, 8.0, Color8(255, 236, 170))
	_screen.draw_circle(sun, 6.0, Color8(255, 248, 214))
	for i in 3:
		var cx := fmod(float(i) * w * 0.41 + _phase_t * 6.0, w + 60.0) - 30.0
		var cy := 10.0 + float(i % 2) * 14.0
		var cloud := Color8(248, 252, 255)
		_screen.draw_rect(Rect2(cx, cy, 26, 5), cloud)
		_screen.draw_rect(Rect2(cx + 5, cy - 3, 12, 3), cloud)
		_screen.draw_rect(Rect2(cx + 2, cy + 5, 22, 1), Color8(214, 232, 244))
	var far := Color8(126, 150, 176)
	for cx: float in [w * 0.12, w * 0.82]:
		_screen.draw_rect(Rect2(cx, road_y - 44, 3, 34), far)
		_screen.draw_rect(Rect2(cx + 14, road_y - 44, 3, 34), far)
		_screen.draw_rect(Rect2(cx - 10, road_y - 46, 40, 3), far)
		_screen.draw_rect(Rect2(cx - 2, road_y - 50, 22, 4), far)
	for i in int(w / 14.0) + 1:
		_screen.draw_rect(Rect2(i * 14.0, road_y - 10, 1, 9), Color8(150, 160, 170))
	_screen.draw_rect(Rect2(0, road_y - 10, w, 1), Color8(150, 160, 170))
	_screen.draw_rect(Rect2(0, road_y - 5, w, 1), Color8(150, 160, 170))
	# the lane: kerb, asphalt, a dashed edge line
	_screen.draw_rect(Rect2(0, road_y, w, scene_h - road_y), Color8(78, 80, 88))
	_screen.draw_rect(Rect2(0, road_y, w, 1), Color8(184, 182, 172))
	for i in int(w / 16.0) + 1:
		_screen.draw_rect(Rect2(i * 16.0 + 2.0, road_y + 5, 8, 1), Color8(232, 228, 210))
	var portal_pos := Vector2(roundf((w - PORTAL_FRAME.x) * 0.5),
		road_y - PORTAL_ROAD)
	var scanning := _scanning()
	_screen.draw_texture(_portal[1 if scanning else 0], portal_pos)
	var tx := roundf(_truck_x(w))
	var phase_i := int(absf(tx) / 3.0) % 2
	var bob := 0.0 if int(_phase_t * 8.0) % 2 == 0 else -1.0
	_screen.draw_texture(_truck[_livery * 2 + phase_i],
		Vector2(tx, road_y - TRUCK_FRAME.y + 1.0 + bob))
	_screen.draw_texture(_portal[3 if scanning else 2], portal_pos)
	_draw_brand_plate(Vector2(portal_pos.x + PORTAL_FRAME.x * 0.5, portal_pos.y - 1.0))
	# --- the monitor: the raw picture arriving column by column
	var mon := Rect2(0, scene_h, w, h - scene_h)
	_screen.draw_rect(mon, BEZEL)
	_screen.draw_rect(Rect2(0, scene_h, w, 1), Color8(60, 64, 80))
	var area := mon.grow(-4.0)
	var scale := minf(area.size.x / IMG.x, area.size.y / IMG.y)
	var size := Vector2(IMG) * scale
	var img_rect := Rect2((area.position + (area.size - size) * 0.5).round(), size)
	var s := _scanned(w)
	if s > 0.0 and _tex.has(Filter.RAW):
		var src_x := float(IMG.x) * (1.0 - s)
		_screen.draw_texture_rect_region(_tex[Filter.RAW],
			Rect2(img_rect.position.x + src_x * scale, img_rect.position.y,
				img_rect.size.x - src_x * scale, img_rect.size.y),
			Rect2(src_x, 0, IMG.x - src_x, IMG.y))
		if s < 1.0:
			_screen.draw_rect(Rect2(img_rect.position.x + src_x * scale - 1.0,
				img_rect.position.y, 2.0, img_rect.size.y), Color(0.6, 0.95, 1.0, 0.9))
	_draw_scanlines(mon)


func _draw_brand_plate(centre: Vector2) -> void:
	var size := UiTheme.FONT.get_string_size(BRAND, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.SIZE_SMALL)
	var plate := Rect2((centre - Vector2(size.x * 0.5 + 3.0, 6.0)).round(),
		Vector2(size.x + 6.0, 10.0))
	_screen.draw_rect(plate, Color(0.06, 0.07, 0.12, 0.92))
	_screen.draw_string(UiTheme.FONT, plate.position + Vector2(3.0, 8.0), BRAND,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, UiTheme.AMBER)


func _draw_boot(w: float, h: float) -> void:
	## The software's splash: the brand, a version line, a loading bar.
	_screen.draw_rect(Rect2(0, 0, w, h), BEZEL)
	var k := clampf(_phase_t / BOOT_TIME, 0.0, 1.0)
	var title_w := UiTheme.FONT.get_string_size(BRAND, HORIZONTAL_ALIGNMENT_LEFT,
		-1, UiTheme.SIZE_BODY).x
	_screen.draw_string(UiTheme.FONT, Vector2((w - title_w) * 0.5, h * 0.42), BRAND,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY, UiTheme.TEAL_LIGHT)
	var sub := "DUAL-ENERGY CARGO X-RAY  v5.0"
	var sub_w := UiTheme.FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.SIZE_SMALL).x
	_screen.draw_string(UiTheme.FONT, Vector2((w - sub_w) * 0.5, h * 0.42 + 16.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL,
		Color(UiTheme.CREAM, 0.6))
	var bar := Rect2(w * 0.2, h * 0.62, w * 0.6, 8.0)
	_screen.draw_rect(bar, Color(1, 1, 1, 0.12))
	_screen.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)),
		UiTheme.AMBER)
	_draw_scanlines(Rect2(0, 0, w, h))


func _draw_scan(w: float, h: float) -> void:
	## The monitor: title bar with the view's name, the picture, the stamps.
	_screen.draw_rect(Rect2(0, 0, w, h), BEZEL)
	var bar_h := 13.0
	_screen.draw_rect(Rect2(0, 0, w, bar_h), BAR)
	var view_name := Loc.t("xray.filter." + FILTER_KEYS[filter])
	_screen.draw_rect(Rect2(3, 3, 7, 7), CHIP[filter])
	_screen.draw_string(UiTheme.FONT, Vector2(13.0, bar_h - 3.0), view_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, CHIP[filter].lightened(0.25))
	var tag := "SCAN #%04d" % _scan_no
	var tag_w := UiTheme.FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.SIZE_SMALL).x
	_screen.draw_string(UiTheme.FONT, Vector2(w - tag_w - 4.0, bar_h - 3.0), tag,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, Color(UiTheme.CREAM, 0.7))
	var film := Rect2(2.0, bar_h + 2.0, w - 4.0, h - bar_h - 4.0)
	_screen.draw_rect(film, (LOOK[filter] as Dictionary).bg)
	var scale := minf(film.size.x / IMG.x, film.size.y / IMG.y)
	var size := Vector2(IMG) * scale
	_img_rect = Rect2((film.position + (film.size - size) * 0.5).round(), size)
	if _tex.has(filter):
		if _wipe_t < 1.0 and _tex.has(_wipe_from):
			# the new view re-renders across the old one, left to right
			_screen.draw_texture_rect(_tex[_wipe_from], _img_rect, false)
			var cut := float(IMG.x) * _wipe_t
			_screen.draw_texture_rect_region(_tex[filter],
				Rect2(_img_rect.position, Vector2(cut * scale, _img_rect.size.y)),
				Rect2(0, 0, cut, IMG.y))
			_screen.draw_rect(Rect2(_img_rect.position.x + cut * scale - 1.0,
				_img_rect.position.y, 2.0, _img_rect.size.y), CHIP[filter])
		else:
			_screen.draw_texture_rect(_tex[filter], _img_rect, false)
	_draw_scanlines(film)
	var side := (SPRITE * SPRITE_SCALE + 6.0) * scale
	# Seized things keep a stamp in every view.
	for item: Dictionary in game.items:
		if not bool(item.seized):
			continue
		var c := _to_screen(item.pos)
		var box := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
		_screen.draw_rect(box, Color(UiTheme.TEAL_LIGHT, 0.18))
		_screen.draw_rect(box, UiTheme.TEAL_LIGHT, false, 2.0)
		_screen.draw_line(c + Vector2(-5, 0), c + Vector2(-1, 4), UiTheme.TEAL_LIGHT, 2.0)
		_screen.draw_line(c + Vector2(-1, 4), c + Vector2(6, -4), UiTheme.TEAL_LIGHT, 2.0)
	# The answer, once the round is lost: a blinking box round what got away.
	if game.over and not game.victory and int(_found_t * 6.0) % 2 == 0:
		for item: Dictionary in game.contrabands():
			if bool(item.seized):
				continue
			var c := _to_screen(item.pos)
			_screen.draw_rect(Rect2(c - Vector2(side, side) * 0.5,
				Vector2(side, side)), UiTheme.DANGER, false, 2.0)
	for mark: Dictionary in _marks:
		var fade := clampf(1.4 - float(mark.t), 0.0, 1.0)
		if fade <= 0.0:
			continue
		var at: Vector2 = mark.at
		var red := Color(UiTheme.DANGER, fade)
		_screen.draw_line(at - Vector2(5, 5), at + Vector2(5, 5), red, 2.0)
		_screen.draw_line(at + Vector2(-5, 5), at + Vector2(5, -5), red, 2.0)
	if not game.over:
		_draw_reticle(scale)


func _draw_reticle(scale: float) -> void:
	# Only once something has pointed: on a phone a ring parked mid-picture
	# just covers a carton.
	if _reticle.x < 0.0:
		return
	var centre := _reticle_point()
	if not _img_rect.has_point(centre):
		return
	var r := maxf(9.0, RETICLE_R * scale)
	var ring: Color = CHIP[filter] if filter != Filter.RAW else UiTheme.AMBER
	_screen.draw_arc(centre, r + 2.0, 0.0, TAU, 40, Color8(10, 10, 16), 3.0)
	_screen.draw_arc(centre, r, 0.0, TAU, 40, ring, 1.5)
	_screen.draw_line(centre - Vector2(4, 0), centre + Vector2(4, 0), ring, 1.0)
	_screen.draw_line(centre - Vector2(0, 4), centre + Vector2(0, 4), ring, 1.0)


func _draw_scanlines(area: Rect2) -> void:
	for y in range(int(area.position.y), int(area.end.y), 3):
		_screen.draw_rect(Rect2(area.position.x, y, area.size.x, 1.0),
			Color(0.0, 0.0, 0.0, 0.06))
