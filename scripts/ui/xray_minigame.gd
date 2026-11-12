class_name XrayMinigame
extends MinigameBoard
## The Receita Federal's inspection: find the contraband on the X-ray.
##
## Three beats. A container rolls along the belt and through the portal (lamp
## red, the beam lit, the scanner beeping); the monitor boots into the Creatus
## Security e VWI software; then the scan is up and the clock runs.
##
## The scan is one picture and one verb. The picture is the container in false
## colour — a real X-ray's orange organics, blue metals, green glass — with
## every crate drawn big, outlined and grounded on a shadow, each inside its
## own cell so no two blur together. The verb is TAP: one crate in the picture
## is contraband (a pistol, a rifle, taped bricks, a grenade) and the shapes
## shaped like one (the hair dryer, the drill) are there to make the player
## look. There is no loupe and no filter: the only hidden thing is *which*
## crate, never *where* — the skill is recognising the shape, which is exactly
## the real scanner operator's skill. A wrong tap costs seconds and the same
## spot costs nothing twice.
##
## The image is built pixel by pixel at a low resolution and drawn with nearest
## filtering, so it reads as pixel art, not a photo.
##
## The rules are `XrayScan`; this file builds the image, draws and reads input.

const ITEMS_TEX := preload("res://assets/sprites/ui_xray_items.png")
const PORTAL := preload("res://assets/sprites/ui_xray_portal.png")
const CONTAINERS := preload("res://assets/sprites/container_sheet.png")
const BRAND := "CREATUS SECURITY e VWI"
const ROLL_TIME := 1.8
const BOOT_TIME := 1.0
## The scan image, in its own pixels: the container from the side, doors open.
## INNER is the opening the crates show through, and item centres live there
## normalised by `XrayScan` (0..1 over `INNER`). The drawing clamps each crate
## into its own cell so two never touch, whatever the deal jittered.
const IMG := Vector2i(240, 116)
const INNER := Rect2(14.0, 14.0, 212.0, 88.0)
## A crate is the sheet's 16px sprite at 2x, so 32px in image pixels.
const SPRITE := 16
const SPRITE_SCALE := 2
## The reticle: a chunky ring that follows finger, mouse or arrow keys. It is
## a pointer, not a tool — the centre cross is where Space/Enter seizes.
const RETICLE_R := 22.0
const BEZEL := Color8(28, 30, 40)
const BAR := Color8(18, 62, 70)
const FILM := Color(0.94, 0.97, 0.95)
const STEEL_DARK := 0.40
const STEEL_RIB := 0.52
## The steel band around the opening, in pixels.
const BAND := 6

enum Phase { ROLL, BOOT, SCAN }

var game: XrayScan
var phase := Phase.ROLL
var _phase_t := 0.0
var _screen: Control
var _img_rect := Rect2()
var _reticle := Vector2(-1, -1)   # where the finger last pointed, in screen px
var _marks: Array[Dictionary] = []
var _beep_t := 0.0
var _scan_no := 1
var _found_t := 0.0
var _portal_atlas: Array[AtlasTexture] = []
var _box: AtlasTexture
var _base_tex: ImageTexture
## The first scan teaches itself: a card over the monitor that says what to
## look for and shows the four contraband shapes. The clock does not run while
## it is up, and it never comes back once dismissed (`flags.xray_coached`).
var _coach: PanelContainer


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
	# A screen the instructions have to explain away is an instruction lost:
	# the accessibility description says the whole rule, verb first.
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
	_build_coach(bezel)


func _build_coach(over: Control) -> void:
	_coach = UiTheme.panel(UiTheme.paper_style(6), false)
	_coach.name = "Coach"
	_coach.visible = false
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP
	over.add_child(_coach)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
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
	# The four shapes to tap, as the scanner draws them.
	var shapes := HBoxContainer.new()
	shapes.alignment = BoxContainer.ALIGNMENT_CENTER
	shapes.add_theme_constant_override(&"separation", 6)
	column.add_child(shapes)
	for index in XrayScan.ITEMS.size():
		if not bool(XrayScan.ITEMS[index].contraband):
			continue
		var cell := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = ITEMS_TEX
		atlas.region = Rect2(index * SPRITE, 0, SPRITE, SPRITE)
		cell.texture = atlas
		cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cell.custom_minimum_size = Vector2(SPRITE, SPRITE) * 2.0
		cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shapes.add_child(cell)
	var ok := UiTheme.button(Loc.t("xray.coach.ok"), &"amber", UiTheme.SIZE_SMALL)
	ok.custom_minimum_size = Vector2(110, 30)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_dismiss_coach)
	column.add_child(ok)


func _show_coach() -> bool:
	if _coach == null or GameState.flags.get("xray_coached", false):
		return false
	_coach.visible = true
	return true


func _dismiss_coach() -> void:
	if _coach == null or not _coach.visible:
		return
	_coach.visible = false
	GameState.flags["xray_coached"] = true
	AudioManager.play_sfx("tap")
	_screen.grab_focus()


func coach_visible() -> bool:
	return _coach != null and _coach.visible


func _begin(offer: Dictionary) -> void:
	game = XrayScan.new()
	game.setup(int(offer.get("seed", 1)), int(offer.get("level", 0)))
	_scan_no = int(offer.get("scan_no", 1))
	_marks.clear()
	_found_t = 0.0
	_beep_t = 0.0
	_reticle = Vector2(-1, -1)
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
	match phase:
		Phase.ROLL:
			_hint.text = Loc.t("xray.rolling")
		Phase.BOOT:
			_hint.text = Loc.t("xray.booting")
			AudioManager.play_sfx("ui_open", 0.02, -6.0)
		Phase.SCAN:
			_hint.text = Loc.t("xray.hint")
			AudioManager.play_sfx("click", 0.04, -4.0)
			_show_coach()


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
			# The clock waits for the player to have read how the game works.
			if not coach_visible():
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
	# One verb. A press seizes where the finger pressed; a drag only points,
	# which is enough rehearsal for the press never to feel like a guess.
	_reticle = _clamp_into_image(at)
	if press:
		_seize_at(at)


func _seize_at(at: Vector2) -> void:
	## Tap the picture at `at`, in screen coordinates.
	if game == null or _closing or phase != Phase.SCAN or _img_rect.size.x <= 0.0:
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
	## Space/Enter taps where the reticle is; arrows walk the reticle. Nothing
	## here is only reachable by pointing.
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
	## Where the reticle is on screen: where the finger last was, or the middle
	## of the picture until there is one.
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


# --------------------------------------------------------------- scan painting

func _build_images(scan_seed: int) -> void:
	## The picture: a pale film, the container's steel band, and the crates —
	## each the sheet's own false-colour sprite at 2x, grounded on a shadow,
	## outlined in navy and clamped inside its own cell so no two touch.
	var rng := RandomNumberGenerator.new()
	rng.seed = scan_seed * 31 + 5
	var base := Image.create_empty(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	# The film: near-white with a whisper of sensor noise, quantised so it is
	# pixel art and not a gradient.
	for y in IMG.y:
		for x in IMG.x:
			var v := floorf((1.0 + rng.randf_range(-0.02, 0.02)) * 16.0) / 16.0
			base.set_pixel(x, y, Color(FILM.r * v, FILM.g * v, FILM.b * v))
	_paint_shell(base)
	var sheet := ITEMS_TEX.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	for item: Dictionary in game.items:
		_paint_item(base, sheet, item)
	_base_tex = ImageTexture.create_from_image(base)


func _paint_shell(img: Image) -> void:
	## The container seen end-on with its doors open: a corrugated steel band
	## around the opening, corner castings, and the floor the cargo sits on —
	## a dark edge so the pale film does not swallow the picture.
	var opening := Rect2i(int(INNER.position.x), int(INNER.position.y),
		int(INNER.size.x), int(INNER.size.y))
	var band := opening.grow(BAND)
	for y in IMG.y:
		for x in IMG.x:
			var depth := _band_depth(Vector2i(x, y), opening, band)
			if depth <= 0:
				continue
			# depth 1 is the opening's own edge, BAND the far side: the steel
			# darkens as it reaches the film's rim, and every 8th column is a
			# corrugation rib.
			var edge := 1.0 - depth / float(BAND + 1)
			var shade := lerpf(STEEL_RIB, STEEL_DARK, 0.55 + 0.45 * edge)
			if depth < BAND and (x % 8 == 0 or x % 8 == 1):
				shade *= 0.66
			img.set_pixel(x, y,
				Color(shade * 0.96, shade * 1.0, shade * 1.04))
	# Corner castings: the posts the crane lifts the whole container by.
	for corner: Vector2i in [
			opening.position - Vector2i(BAND, BAND),
			Vector2i(opening.end.x, opening.position.y - BAND),
			Vector2i(opening.position.x - BAND, opening.end.y),
			Vector2i(opening.end.x, opening.end.y)]:
		for dy in BAND:
			for dx in BAND:
				var q := corner + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= IMG.x or q.y >= IMG.y:
					continue
				img.set_pixel(q.x, q.y,
					Color(STEEL_DARK * 0.72, STEEL_DARK * 0.76, STEEL_DARK * 0.8))
	# The floor: a rail under the crates, so nothing floats.
	for x in range(opening.position.x + 1, opening.end.x - 1):
		img.set_pixel(x, opening.end.y - 1, Color(0.74, 0.78, 0.76))
		img.set_pixel(x, opening.end.y - 2, Color(0.82, 0.86, 0.84))


func _band_depth(p: Vector2i, opening: Rect2i, band: Rect2i) -> int:
	## How deep inside the steel band a point is: 0 outside the band, 1 at the
	## opening's own edge, BAND at the far rim.
	if not band.has_point(p) or opening.has_point(p):
		return 0
	var dx := mini(p.x - band.position.x, band.end.x - 1 - p.x)
	var dy := mini(p.y - band.position.y, band.end.y - 1 - p.y)
	return mini(dx, dy) + 1


func _paint_item(img: Image, sheet: Image, item: Dictionary) -> void:
	## One crate: the sprite at 2x from the sheet, a shadow ellipse under it
	## and a navy outline around it — and the whole thing clamped inside its
	## own grid cell, so two crates never visually merge whatever the deal
	## jittered.
	var size_i := SPRITE * SPRITE_SCALE

	## Kept as a full-image mask so the outline step can ask "is this film?"
	var mask := PackedByteArray()
	mask.resize(IMG.x * IMG.y)
	# Which cell the rules dealt this crate, and where its centre landed.
	var cell := Vector2(INNER.size.x / XrayScan.COLS, INNER.size.y / XrayScan.ROWS)
	var centre := INNER.position + (item.pos as Vector2) * INNER.size
	var cell_x := clampi(int((centre.x - INNER.position.x) / cell.x),
		0, XrayScan.COLS - 1)
	var cell_y := clampi(int((centre.y - INNER.position.y) / cell.y),
		0, XrayScan.ROWS - 1)
	var cell_begin := INNER.position + Vector2(cell_x, cell_y) * cell
	# The sprite (with its 1px outline) must stay inside its own cell.
	var slack := cell * 0.5 - Vector2(size_i + 3, size_i + 3) * 0.5
	var clamped := Vector2(
		clampf(centre.x, cell_begin.x + slack.x, cell_begin.x + cell.x - slack.x),
		clampf(centre.y, cell_begin.y + slack.y, cell_begin.y + cell.y - slack.y))
	var origin := Vector2i((clamped - Vector2(size_i, size_i) * 0.5).round())

	# The ground shadow: a darkening band under the crate's bottom edge.
	for dx in size_i + 4:
		var sx := origin.x - 2 + dx
		var falloff := sin(PI * float(dx) / float(size_i + 3))
		for dy in 3:
			_dim(img, sx, origin.y + size_i - 1 + dy,
				0.14 * (1.0 - float(dy) / 3.0) * falloff)
	# The sprite itself, at 2x, mirroring when the rules dealt it mirrored.
	var flip := bool(item.flip)
	for sy in SPRITE:
		for sx in SPRITE:
			var c := sheet.get_pixel(int(item.frame) * SPRITE
				+ (SPRITE - 1 - sx if flip else sx), sy)
			if c.a < 0.5:
				continue
			for by in SPRITE_SCALE:
				for bx in SPRITE_SCALE:
					var q := origin + Vector2i(sx * SPRITE_SCALE + bx,
						sy * SPRITE_SCALE + by)
					if q.x < 0 or q.y < 0 or q.x >= IMG.x or q.y >= IMG.y:
						continue
					mask[q.y * IMG.x + q.x] = 1
					img.set_pixel(q.x, q.y, Color(c.r, c.g, c.b))
	# The outline: dark navy where the crate meets the film, so even the
	# palest shape (the shoe, the ball) pops against it.
	for y in range(origin.y - 1, origin.y + size_i + 1):
		for x in range(origin.x - 1, origin.x + size_i + 1):
			if x < 0 or y < 0 or x >= IMG.x or y >= IMG.y:
				continue
			var q := Vector2i(x, y)
			if mask[q.y * IMG.x + q.x] != 0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := q + d
				if n.x < 0 or n.y < 0 or n.x >= IMG.x or n.y >= IMG.y:
					continue
				if mask[n.y * IMG.x + n.x] != 0:
					img.set_pixel(q.x, q.y, Color(0.16, 0.18, 0.30))
					break


func _dim(img: Image, x: int, y: int, amount: float) -> void:
	## Darken one pixel by `amount` (0..1).
	if x < 0 or y < 0 or x >= IMG.x or y >= IMG.y or amount <= 0.005:
		return
	var c := img.get_pixel(x, y)
	img.set_pixel(x, y, Color(c.r * (1.0 - amount), c.g * (1.0 - amount),
		c.b * (1.0 - amount), c.a))


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
	## The monitor: title bar, the X-ray in false colour, the reticle over it.
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
	_screen.draw_rect(film, Color8(238, 244, 242))
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
			var side := (SPRITE * SPRITE_SCALE + 10.0) * scale
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
	## Where the next press lands: a chunky ring big enough to hold a crate,
	## navy outside, amber inside, with a small centre cross.
	var centre := _reticle_point()
	if not _img_rect.has_point(centre):
		return
	var r := maxf(9.0, RETICLE_R * scale)
	_screen.draw_arc(centre, r + 2.0, 0.0, TAU, 40, Color8(24, 22, 30), 3.0)
	_screen.draw_arc(centre, r, 0.0, TAU, 40, UiTheme.AMBER, 1.5)
	var cross := Color(UiTheme.AMBER, 0.9)
	_screen.draw_line(centre - Vector2(4, 0), centre + Vector2(4, 0), cross, 1.0)
	_screen.draw_line(centre - Vector2(0, 4), centre + Vector2(0, 4), cross, 1.0)


func _draw_scanlines(area: Rect2) -> void:
	for y in range(int(area.position.y), int(area.end.y), 3):
		_screen.draw_rect(Rect2(area.position.x, y, area.size.x, 1.0),
			Color(0.0, 0.0, 0.0, 0.06))
