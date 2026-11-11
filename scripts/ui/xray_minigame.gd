class_name XrayMinigame
extends MinigameBoard
## The Receita Federal's inspection: find the contraband on the X-ray.
##
## Three beats. A container rolls along the belt and through the portal (lamp
## red, the beam lit, the scanner beeping); the monitor boots into the Creatus
## Security e VWI software; then the scan is up and the clock runs.
##
## The scan is drawn like the real thing: a grey transmission image of the
## whole trailer seen from the side — chassis, wheels, the container's ribs —
## with the cargo a dark, lumpy mass of bales filling it. Whatever is hidden in
## that mass is nearly invisible to the naked eye. The player's tool is the
## **loupe**: drag it over the image and it shows that spot magnified, through
## a material filter — ORGANIC (drugs, wood, cloth) or METAL (weapons,
## electronics) — with the bales stripped away and the goods in false colour.
## Put the crosshair on the illegal one and press SEIZE. Seizing the wrong
## thing costs seconds. The image is built pixel by pixel at a low resolution
## and drawn with nearest filtering, so it reads as pixel art, not a photo.
##
## The rules are `XrayScan`; this file builds the images, draws and reads input.

const ITEMS_TEX := preload("res://assets/sprites/ui_xray_items.png")
const PORTAL := preload("res://assets/sprites/ui_xray_portal.png")
const CONTAINERS := preload("res://assets/sprites/container_sheet.png")
const BRAND := "CREATUS SECURITY e VWI"
const ROLL_TIME := 2.4
const BOOT_TIME := 1.1
## The scan image, in its own pixels: the whole trailer from the side.
const IMG := Vector2i(180, 84)
## The container's inside, and the rect item centres live in (inset half a
## sprite, so an item jittered into a corner stays inside the walls).
const INTERIOR := Rect2i(12, 10, 154, 47)
const INNER := Rect2(20.0, 18.0, 138.0, 31.0)
## The loupe: its radius on screen, how much it magnifies, how far above the
## finger it floats so the finger never covers what it shows.
const LENS_R := 36.0
const LENS_ZOOM := 2.2
const LENS_LIFT := 46.0
const BEZEL := Color8(28, 30, 40)
const BAR := Color8(18, 62, 70)

enum Phase { ROLL, BOOT, SCAN }
enum Filter { ORGANIC, METAL }

var game: XrayScan
var phase := Phase.ROLL
var filter := Filter.METAL
var _phase_t := 0.0
var _screen: Control
var _img_rect := Rect2()
var _lens := Vector2(-1, -1)        # centre, in screen coordinates
var _marks: Array[Dictionary] = []
var _beep_t := 0.0
var _scan_no := 1
var _found_t := 0.0
var _portal_atlas: Array[AtlasTexture] = []
var _box: AtlasTexture
var _base_tex: ImageTexture
var _filter_tex: Array[ImageTexture] = []
var _filter_keys: Array[Button] = []
var _seize: Button


func _build_field(column: VBoxContainer) -> void:
	var bezel := UiTheme.panel(UiTheme.arcade_style(6), false)
	bezel.custom_minimum_size.y = 150.0
	bezel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bezel)
	_screen = Control.new()
	_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.focus_mode = Control.FOCUS_ALL
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.gui_input.connect(_on_screen_input)
	_screen.draw.connect(_draw_screen)
	UiTheme.describe(_screen, BRAND, Loc.t("xray.hint"))
	bezel.add_child(_screen)
	for index in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = PORTAL
		atlas.region = Rect2(index * 44, 0, 44, 36)
		_portal_atlas.append(atlas)
	_box = AtlasTexture.new()
	_box.atlas = CONTAINERS
	_box.region = Rect2(2 * 24, 0, 24, 13)


func _build_controls(column: VBoxContainer) -> void:
	## The console under the monitor: the loupe's two filters and SEIZE.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	column.add_child(row)
	for index in 2:
		var key := UiTheme.segment(Loc.t("xray.legend.organic" if index == Filter.ORGANIC
			else "xray.legend.metal"), index == filter)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.custom_minimum_size.y = UiTheme.TOUCH_MIN
		key.clip_text = true
		key.pressed.connect(_set_filter.bind(index))
		row.add_child(key)
		_filter_keys.append(key)
	# Steel, not amber: amber is the lit filter, and the two must never be
	# mistaken for each other.
	_seize = UiTheme.button(Loc.t("xray.mark"), &"steel", UiTheme.SIZE_SMALL)
	_seize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seize.custom_minimum_size.y = UiTheme.TOUCH_MIN
	_seize.clip_text = true
	_seize.pressed.connect(_on_seize)
	row.add_child(_seize)


func _begin(offer: Dictionary) -> void:
	game = XrayScan.new()
	game.setup(int(offer.get("seed", 1)), int(offer.get("level", 0)))
	_scan_no = int(offer.get("scan_no", 1))
	_marks.clear()
	_found_t = 0.0
	_beep_t = 0.0
	_lens = Vector2(-1, -1)
	_build_images(int(offer.get("seed", 1)))
	# A retry after an ad goes straight back to the scan: the box already went
	# through the portal once.
	_set_phase(Phase.SCAN if _retried or not UserPreferences.can_animate()
		else Phase.ROLL)
	_screen.grab_focus()
	_refresh()


func _set_phase(next: Phase) -> void:
	phase = next
	_phase_t = 0.0
	var scanning := phase == Phase.SCAN
	for key in _filter_keys:
		key.disabled = not scanning
	if _seize != null:
		_seize.disabled = not scanning
	match phase:
		Phase.ROLL:
			_hint.text = Loc.t("xray.rolling")
		Phase.BOOT:
			_hint.text = Loc.t("xray.booting")
			AudioManager.play_sfx("ui_open", 0.02, -6.0)
		Phase.SCAN:
			_hint.text = Loc.t("xray.hint")
			AudioManager.play_sfx("click", 0.04, -4.0)


func _set_filter(which: int) -> void:
	filter = which as Filter
	for index in _filter_keys.size():
		UiTheme.style_segment(_filter_keys[index], index == which)
	AudioManager.play_sfx("ui_tab", 0.03, -4.0)
	_screen.queue_redraw()


func _tick(delta: float) -> void:
	if game == null:
		return
	_phase_t += delta
	match phase:
		Phase.ROLL:
			if _box_inside():
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
			game.advance(delta)
	for mark: Dictionary in _marks:
		mark.t = float(mark.t) + delta
	_found_t += delta
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
	elif motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
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
	# The loupe floats above the finger, inside the image.
	_move_lens(at - Vector2(0.0, LENS_LIFT))


func _move_lens(to: Vector2) -> void:
	if _img_rect.size.x <= 0.0:
		return
	_lens = Vector2(clampf(to.x, _img_rect.position.x, _img_rect.end.x),
		clampf(to.y, _img_rect.position.y, _img_rect.end.y))
	_screen.queue_redraw()


func _on_seize() -> void:
	if game == null or _closing or phase != Phase.SCAN:
		return
	_seize_at(_lens_centre())


func _seize_at(at: Vector2) -> void:
	## Seize whatever is under `at` (screen coordinates).
	if _img_rect.size.x <= 0.0:
		return
	var result := game.tap(_to_norm(at))
	if bool(result.hit):
		_found_t = 0.0
		_say(Loc.t("xray.found"), UiTheme.TEAL_LIGHT)
		AudioManager.play_sfx("milestone", 0.02, -2.0)
	else:
		_marks.append({"at": at, "t": 0.0})
		if float(result.penalty) > 0.0:
			_shake = maxf(_shake, 0.4)
			_say("-%.1fs" % XrayScan.WRONG_PENALTY, UiTheme.DANGER)
			AudioManager.play_sfx("deny", 0.06, -4.0)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	## Space/Enter skips the intro, then seizes; arrows walk the loupe; 1/2 pick
	## the filter. Nothing here is only reachable by pointing.
	if not visible or _closing or game == null:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var step := Vector2.ZERO
	match key.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if key.echo:
				return
			if phase != Phase.SCAN:
				_set_phase(Phase.SCAN)
			else:
				_on_seize()
		KEY_1:
			_set_filter(Filter.ORGANIC)
		KEY_2:
			_set_filter(Filter.METAL)
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
		_move_lens(_lens_centre() + step)
	get_viewport().set_input_as_handled()


func _lens_centre() -> Vector2:
	return _lens if _lens.x >= 0.0 else _img_rect.get_center()


func _to_norm(at: Vector2) -> Vector2:
	## Screen point -> the rules' normalised coordinates (0..1 over `INNER`).
	var scale := _img_rect.size.x / float(IMG.x)
	var img := (at - _img_rect.position) / scale
	return (img - INNER.position) / INNER.size


func _to_screen(norm: Vector2) -> Vector2:
	var scale := _img_rect.size.x / float(IMG.x)
	return _img_rect.position + (INNER.position + norm * INNER.size) * scale


func _refresh() -> void:
	if game == null:
		return
	var clock := "%4.1fs" % (game.time_left if phase == Phase.SCAN else game.time_total)
	_set_stats(clock, Loc.t("xray.mistakes", {"n": str(game.mistakes)}),
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


# ----------------------------------------------------------- the scan images

func _build_images(scan_seed: int) -> void:
	## Three images of the same trailer: what the monitor shows (grey, cargo
	## dark and lumpy, the goods barely there) and what the loupe shows through
	## each filter (bales stripped to a ghost, that material's goods in colour).
	var rng := RandomNumberGenerator.new()
	rng.seed = scan_seed * 31 + 5
	var base := Image.create_empty(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	var density := PackedFloat32Array()
	density.resize(IMG.x * IMG.y)
	# Film: near-white with a little sensor noise.
	for y in IMG.y:
		for x in IMG.x:
			density[y * IMG.x + x] = rng.randf_range(0.0, 0.04)
	_paint_trailer(density)
	var cargo := PackedFloat32Array()
	cargo.resize(IMG.x * IMG.y)
	_paint_bales(cargo, rng)
	# What the goods add, per material, so the filters can pick them apart.
	var organic := Image.create_empty(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	var metal := Image.create_empty(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	var sheet := ITEMS_TEX.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	for item: Dictionary in game.items:
		var centre := INNER.position + (item.pos as Vector2) * INNER.size
		var origin := Vector2i(roundi(centre.x) - 8, roundi(centre.y) - 8)
		var flip := bool(item.flip)
		for sy in 16:
			for sx in 16:
				var c := sheet.get_pixel(int(item.frame) * 16 + (15 - sx if flip else sx), sy)
				if c.a < 0.5:
					continue
				var p := origin + Vector2i(sx, sy)
				if p.x < 0 or p.y < 0 or p.x >= IMG.x or p.y >= IMG.y:
					continue
				var is_organic := c.r > c.b
				# Metal is dense: it reads a little darker even to the naked eye.
				var i := p.y * IMG.x + p.x
				density[i] += 0.30 if not is_organic else 0.10
				(organic if is_organic else metal).set_pixel(p.x, p.y, c)
	var filtered: Array[Image] = []
	for layer: Image in [organic, metal]:
		var out := Image.create_empty(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
		for y in IMG.y:
			for x in IMG.x:
				var i := y * IMG.x + x
				# The ghost: trailer and bales at a fifth of their weight.
				var g := 1.0 - clampf(density[i] * 0.35 + cargo[i] * 0.18, 0.0, 1.0)
				var film := Color(0.90 * g, 0.94 * g, 0.88 * g)
				var hit := layer.get_pixel(x, y)
				out.set_pixel(x, y, hit if hit.a > 0.5 else film)
		filtered.append(out)
	for y in IMG.y:
		for x in IMG.x:
			var i := y * IMG.x + x
			var v := 1.0 - clampf(density[i] + cargo[i], 0.0, 1.0)
			# Quantised to a few greys: pixel art, not a gradient.
			v = floorf(v * 12.0) / 12.0
			base.set_pixel(x, y, Color(v, v, v * 1.02))
	_base_tex = ImageTexture.create_from_image(base)
	_filter_tex = [ImageTexture.create_from_image(filtered[0]),
		ImageTexture.create_from_image(filtered[1])]


func _paint_trailer(d: PackedFloat32Array) -> void:
	## The steel: container walls and ribs, the chassis, the wheels, the cab.
	var box := Rect2i(8, 6, 162, 55)
	for x in range(box.position.x, box.end.x):
		_add(d, x, box.position.y, 0.55)
		_add(d, x, box.position.y + 1, 0.35)
		_add(d, x, box.end.y - 1, 0.6)
		_add(d, x, box.end.y - 2, 0.4)
	for y in range(box.position.y, box.end.y):
		for k in 3:
			_add(d, box.position.x + k, y, 0.55 - k * 0.12)
			_add(d, box.end.x - 1 - k, y, 0.55 - k * 0.12)
	# Corrugation ribs, faint, and the cross-members every so often.
	for x in range(box.position.x + 6, box.end.x - 4, 6):
		for y in range(box.position.y + 2, box.end.y - 2):
			_add(d, x, y, 0.06)
	for x in range(box.position.x + 20, box.end.x - 10, 38):
		for y in range(box.position.y + 2, box.end.y - 2):
			_add(d, x, y, 0.12)
	# The chassis beam under the box, and its gear.
	for x in range(6, 172):
		for y in range(61, 65):
			_add(d, x, y, 0.45 if y == 61 or y == 64 else 0.22)
	for x in range(80, 96):
		for y in range(65, 70):
			_add(d, x, y, 0.3)
	# Wheels: dark rings with a hub, three axles at the back, two under the cab.
	for cx: int in [30, 50, 70, 146, 164]:
		for y in range(64, IMG.y):
			for x in range(cx - 10, cx + 11):
				var r := Vector2(x - cx, y - 74).length()
				if r <= 9.5 and r >= 6.5:
					_add(d, x, y, 0.75)
				elif r < 2.5:
					_add(d, x, y, 0.6)
				elif r < 6.5:
					_add(d, x, y, 0.12)
	# The tractor's nose at the right edge.
	for x in range(171, IMG.x):
		for y in range(34, 66):
			_add(d, x, y, 0.4 if x == 171 or y == 34 else 0.18)


func _paint_bales(c: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	## The cargo: columns of sacks/bales filling the box, each a lumpy dark
	## stack with a rounded top, so whatever is inside hides in the mass.
	var x := INTERIOR.position.x + 1
	while x < INTERIOR.end.x - 2:
		var w := rng.randi_range(8, 11)
		var top := INTERIOR.position.y + rng.randi_range(1, 12)
		var lumps := rng.randf_range(0.0, TAU)
		for cx in range(x, mini(x + w, INTERIOR.end.x - 1)):
			var u := float(cx - x) / float(w)
			var edge := sin(u * PI)
			var col_top := top + int((1.0 - edge) * 4.0)
			for y in range(col_top, INTERIOR.end.y):
				var depth := clampf(float(y - col_top) / 8.0, 0.0, 1.0)
				# Stacked lumps, like sacks seen edge-on: each band is lighter
				# at its seam, and the seams wander from column to column.
				var band := fmod(float(y - col_top) + lumps * 2.0, 6.0) / 6.0
				var seam := 0.14 * (1.0 - sin(band * PI))
				var wobble := 0.06 * sin(float(cx) * 1.7 + float(y) * 0.6 + lumps) \
					+ rng.randf_range(-0.07, 0.07)
				var v := (0.46 + 0.40 * depth) * (0.72 + 0.28 * edge) - seam + wobble
				c[y * IMG.x + cx] = clampf(v, 0.0, 0.9)
		x += w + rng.randi_range(0, 1)


static func _add(d: PackedFloat32Array, x: int, y: int, v: float) -> void:
	if x >= 0 and y >= 0 and x < IMG.x and y < IMG.y:
		d[y * IMG.x + x] += v


# ---------------------------------------------------------------------- view

func _box_x(w: float) -> float:
	var k := clampf(_phase_t / ROLL_TIME, 0.0, 1.0)
	# Eases in, dawdles in the portal, eases out: a belt with a scan stop.
	var eased := k + sin(k * TAU) * -0.09
	return lerpf(-80.0, w + 8.0, eased)


func _box_inside() -> bool:
	if _screen == null:
		return false
	var w := _screen.size.x
	var x := _box_x(w) + 36.0
	return absf(x - w * 0.5) < 54.0


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
	## The quay: sky, the belt, the box, the portal over it.
	_screen.draw_rect(Rect2(0, 0, w, h), Color8(120, 176, 214))
	_screen.draw_rect(Rect2(0, h * 0.70, w, h * 0.30), Color8(108, 112, 120))
	_screen.draw_rect(Rect2(0, h * 0.70, w, 2), Color8(150, 154, 160))
	var belt_y := h * 0.70 + 12.0
	_screen.draw_rect(Rect2(0, belt_y, w, 8), Color8(40, 40, 48))
	var roll := fmod(_phase_t * 60.0, 12.0)
	for i in int(w / 12.0) + 2:
		var rx := float(i) * 12.0 - roll
		_screen.draw_rect(Rect2(rx, belt_y + 2, 6, 4), Color8(86, 88, 98))
	var bob := -1.0 if int(_phase_t * 10.0) % 2 == 0 else 0.0
	var box_pos := Vector2(_box_x(w), belt_y - 39.0 + bob)
	_screen.draw_texture_rect(_box, Rect2(box_pos, Vector2(72, 39)), false)
	var scanning := _box_inside()
	var portal_size := Vector2(132, 108)
	var portal_pos := Vector2((w - portal_size.x) * 0.5, belt_y + 8.0 - portal_size.y)
	_screen.draw_texture_rect(_portal_atlas[1 if scanning else 0],
		Rect2(portal_pos.round(), portal_size), false)
	if scanning and int(_phase_t * 8.0) % 2 == 0:
		_screen.draw_rect(Rect2(portal_pos + Vector2(27, 27), Vector2(78, 66)),
			Color(0.5, 0.95, 1.0, 0.12))
	_draw_brand_plate(Vector2(w * 0.5, portal_pos.y + 18.0))


func _draw_brand_plate(centre: Vector2) -> void:
	var size := UiTheme.FONT.get_string_size(BRAND, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.SIZE_SMALL)
	var plate := Rect2(centre - Vector2(size.x * 0.5 + 4.0, 7.0),
		Vector2(size.x + 8.0, 12.0))
	_screen.draw_rect(plate, Color(0.06, 0.07, 0.10, 0.88))
	_screen.draw_string(UiTheme.FONT, plate.position + Vector2(4.0, 10.0), BRAND,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, UiTheme.AMBER)


func _draw_boot(w: float, h: float) -> void:
	## The software's splash: the brand, a version line, a loading bar.
	_screen.draw_rect(Rect2(0, 0, w, h), BEZEL)
	var k := clampf(_phase_t / BOOT_TIME, 0.0, 1.0)
	var title_w := UiTheme.FONT.get_string_size(BRAND, HORIZONTAL_ALIGNMENT_LEFT,
		-1, UiTheme.SIZE_BODY).x
	_screen.draw_string(UiTheme.FONT, Vector2((w - title_w) * 0.5, h * 0.42), BRAND,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY, UiTheme.TEAL_LIGHT)
	var sub := "X-RAY CARGO INSPECTION  v4.2"
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
	## The monitor: title bar, the transmission image, the loupe over it.
	_screen.draw_rect(Rect2(0, 0, w, h), BEZEL)
	var bar_h := 14.0
	_screen.draw_rect(Rect2(0, 0, w, bar_h), BAR)
	_screen.draw_string(UiTheme.FONT, Vector2(4.0, bar_h - 3.0), BRAND,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, UiTheme.AMBER)
	var tag := "SCAN #%04d" % _scan_no
	var tag_w := UiTheme.FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.SIZE_SMALL).x
	_screen.draw_string(UiTheme.FONT, Vector2(w - tag_w - 4.0, bar_h - 3.0), tag,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, Color(UiTheme.CREAM, 0.8))
	var film := Rect2(3.0, bar_h + 3.0, w - 6.0, h - bar_h - 6.0)
	_screen.draw_rect(film, Color8(236, 238, 232))
	# The image, as big as fits with its aspect kept; nearest filtering keeps
	# its pixels square.
	var scale := minf(film.size.x / IMG.x, film.size.y / IMG.y)
	var size := Vector2(IMG) * scale
	_img_rect = Rect2((film.position + (film.size - size) * 0.5).round(), size)
	if _base_tex != null:
		_screen.draw_texture_rect(_base_tex, _img_rect, false)
	_draw_scanlines(film)
	# The answer, once the round is over: a blinking box round the contraband.
	if game.over:
		var target := game.contraband()
		if not target.is_empty() and int(_found_t * 6.0) % 2 == 0:
			var c := _to_screen(target.pos)
			var side := 16.0 * scale
			_screen.draw_rect(Rect2(c - Vector2(side, side) * 0.65,
				Vector2(side, side) * 1.3), UiTheme.DANGER, false, 2.0)
	for mark: Dictionary in _marks:
		var fade := clampf(1.4 - float(mark.t), 0.0, 1.0)
		if fade <= 0.0:
			continue
		var at: Vector2 = mark.at
		var red := Color(UiTheme.DANGER, fade)
		_screen.draw_line(at - Vector2(5, 5), at + Vector2(5, 5), red, 2.0)
		_screen.draw_line(at + Vector2(-5, 5), at + Vector2(5, -5), red, 2.0)
	if not game.over:
		_draw_lens(scale)


func _draw_lens(scale: float) -> void:
	## The special loupe: a disc of the filtered image, magnified, in a chunky
	## steel ring with a handle, a glint and a crosshair.
	if _filter_tex.size() < 2:
		return
	var centre := _lens_centre()
	var img_centre := (centre - _img_rect.position) / scale
	var reach := LENS_R / (scale * LENS_ZOOM)    # image pixels under the lens
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for step in 32:
		var a := TAU * float(step) / 32.0
		var dir := Vector2(cos(a), sin(a))
		points.append(centre + dir * LENS_R)
		uvs.append((img_centre + dir * reach) / Vector2(IMG))
	# Handle first, so the ring sits over it.
	var handle_dir := Vector2(0.7, 0.7)
	_screen.draw_line(centre + handle_dir * (LENS_R + 2.0),
		centre + handle_dir * (LENS_R + 22.0), Color8(60, 44, 34), 9.0)
	_screen.draw_line(centre + handle_dir * (LENS_R + 2.0),
		centre + handle_dir * (LENS_R + 22.0), Color8(120, 86, 58), 5.0)
	_screen.draw_colored_polygon(points, Color.WHITE, uvs, _filter_tex[filter])
	var tint := Color8(238, 152, 66) if filter == Filter.ORGANIC else Color8(78, 128, 216)
	_screen.draw_arc(centre, LENS_R + 1.5, 0.0, TAU, 40, Color8(24, 22, 30), 5.0)
	_screen.draw_arc(centre, LENS_R - 1.0, 0.0, TAU, 40, tint, 2.0)
	_screen.draw_arc(centre, LENS_R - 7.0, PI * 1.1, PI * 1.45, 8,
		Color(1, 1, 1, 0.55), 2.0)
	var cross := Color(UiTheme.DANGER, 0.85)
	_screen.draw_line(centre - Vector2(7, 0), centre - Vector2(2, 0), cross, 1.0)
	_screen.draw_line(centre + Vector2(2, 0), centre + Vector2(7, 0), cross, 1.0)
	_screen.draw_line(centre - Vector2(0, 7), centre - Vector2(0, 2), cross, 1.0)
	_screen.draw_line(centre + Vector2(0, 2), centre + Vector2(0, 7), cross, 1.0)


func _draw_scanlines(area: Rect2) -> void:
	for y in range(int(area.position.y), int(area.end.y), 3):
		_screen.draw_rect(Rect2(area.position.x, y, area.size.x, 1.0),
			Color(0.0, 0.0, 0.0, 0.06))
