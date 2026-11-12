class_name Ship
extends Node2D
## View of the berth manifest.  BerthCallController owns the workflow; this
## node only animates and exposes the legacy interaction API used by Main.

signal departed
signal phase_changed(phase: int)

enum Phase { AWAY, ARRIVING, DISCHARGING, WAITING_EXPORT, LOADING, DEPARTING }
const COLS := PortLayout.SHIP_BAY_COLS
const ROWS := PortLayout.SHIP_BAY_ROWS
const BAY_X := [8.0, 34.0]
const BAY_Y0 := 44.0
const BAY_PITCH := 11.0
const BOX_VISUAL_CENTRE := Vector2(12.0, 6.5)
## The longest hull, used before a class has been chosen and as the fallback for a
## variant naming a sprite that is not there.
const HULL_FALLBACK := preload("res://assets/sprites/ship_top.png")
## The livery layer: only the painted hull and the funnel band, on the same
## 66x232 canvas as `ship_top.png`. The livery tints this and nothing else.
const HULL_PAINT := preload("res://assets/sprites/ship_paint.png")
const ROPE := preload("res://assets/sprites/prop_rope.png")
const ROPE_KNOT := preload("res://assets/sprites/prop_rope_knot.png")
## One line forward, one aft. Four — with springs — read as spaghetti at this
## scale: a top-down hull is 66 px wide and every extra rope crosses the others.
const MOORING_LINES := 2
## Enough segments for the sag to read as a curve at this scale.
const MOORING_SEGMENTS := 8
## The port bulwark, where every fairlead is.
const MOORING_LEAD_X := 3.0
## Light comes from the upper left across the whole game, so the hull's shadow
## falls down and to the right of it.
const HULL_SHADOW_OFFSET := Vector2(3.0, 4.0)

## A box *landing on the deck* shakes the hull: a short, fast tremor that dies
## away, felt on both sides because that is what a shock does. Taking a box off
## does nothing — the crane lifts it clear, the hull is not struck.
##
## `SHUDDER_SPEED` over the life of `SHUDDER_DECAY` is several cycles, which is a
## vibration rather than the slow one-cycle roll this used to be.
const SHUDDER_REACH := 1.5
const SHUDDER_DECAY := 3.4
const SHUDDER_SPEED := 27.0

var phase: Phase = Phase.AWAY
## Which berth this hull works. Berth 0 is the northmost, hard against the top of
## the quay; the others run south down it.
var berth_index := 0
var _outline: Node2D
var _paint: Sprite2D
var _hull: Sprite2D
var _shadow: Sprite2D
var _cargo: Node2D
var _wake: ShipWake
var _moorings: Node2D
var _mooring_lines: Array[Line2D] = []
var _mooring_plan: Array[Dictionary] = []   # {from, to, sag}
var _mooring_knots: Array[Sprite2D] = []
var _mooring_throw := 0.0                   # 0 = let go, 1 = all fast
var _made_fast := false
var _lights_root: Node2D
var _light_glows: Array[Sprite2D] = []
var _slots: Array = [] # [column][row] -> {sprite, unit} | null
var _imports: Array[CargoUnit] = []
var _export_target := 0
var _exported := 0
var _export_claimed := 0
var _reserved: Dictionary = {}
var _flights_in_progress := 0
var _t := 0.0
var _roll_amp := 0.0
var _roll_phase := 0.0
var _roll_side := 1.0
var _roll_repeats := 0
var _last_y := 0.0
var _wake_strength := 0.0
## Making way up or down the channel under her own power, as opposed to being
## warped sideways on and off the wall. Only the first makes a wake.
var _under_way := false
var ship_variant: Dictionary = {}
## The call's progress drawn over the hull: a bar plus "18/24", redrawn only
# when the fraction changes. Drawn, not a Control, so it can never eat a tap.
var _scale_bar_frac := -1.0
var _scale_label: Label
var variant_history: Array[String] = []
@onready var _containers: Texture2D = PortDB.tex("container_sheet")


func _ready() -> void:
	# The foam a hull throws when it is making way: bow wave, V, collar and
	# propeller wash, drawn in whole pixels over the shader's swell.
	_wake = ShipWake.new()
	_wake.name = "Wake"
	_wake.z_index = -1
	_wake.visible = false
	add_child(_wake)
	_build_moorings()
	# A contact shadow under the hull: the same silhouette, offset and darkened.
	# Without it the ship reads as a sticker on the water rather than as a mass
	# sitting in it, which is the whole difference between flat 2D and 2D with
	# depth in a top-down view.
	_shadow = Sprite2D.new()
	_shadow.texture = HULL_FALLBACK
	_shadow.centered = false
	_shadow.modulate = Color(0.05, 0.08, 0.14, 0.34)
	_shadow.z_index = -2
	_shadow.position = HULL_SHADOW_OFFSET
	add_child(_shadow)
	_outline = _make_outline(HULL_FALLBACK, false)
	_outline.visible = false
	add_child(_outline)
	_hull = Sprite2D.new()
	_hull.texture = HULL_FALLBACK
	_hull.centered = false
	add_child(_hull)
	# A child of the hull, so it inherits every scale, offset and shudder the
	# hull is given without being told about any of them.
	_paint = Sprite2D.new()
	_paint.name = "Paint"
	_paint.texture = HULL_PAINT
	_paint.centered = false
	_hull.add_child(_paint)
	_cargo = Node2D.new()
	add_child(_cargo)
	_build_navigation_lights()
	if ship_variant.is_empty():
		ship_variant = ShipCatalog.select_variant(0, 0, [])
	_apply_ship_variant()
	_refresh_wake_state()


func wake_strength() -> float:
	## Measured from the hull actually moving, not from the phase: a tween that
	## has not started yet, or one easing to a stop at the berth, should not be
	## throwing water either way.
	return _wake_strength


func hull_centre() -> Vector2:
	return global_position + Vector2(PortLayout.SHIP_W, hull_height()) * 0.5


func _process(delta: float) -> void:
	var travelled := absf(position.y - _last_y) / maxf(delta, 0.0001)
	_last_y = position.y
	var driving := 0.0 if not (phase == Phase.ARRIVING or phase == Phase.DEPARTING) \
		else clampf(travelled / 70.0, 0.0, 1.0)
	_wake_strength = move_toward(_wake_strength, driving, delta * 1.6)
	_wake.strength = _wake_strength
	_t += delta
	_advance_roll(delta)
	if is_working():
		var hull_offset: Vector2 = ship_variant.get("hull_offset", Vector2.ZERO)
		_hull.position = hull_offset + Vector2(
			sin(_t * 0.8) * 0.8 + roll_offset(), sin(_t * 0.55) * 1.2)
		_cargo.position = _hull.position
		_outline.position = _hull.position
		_lights_root.position = _hull.position
		_shadow.position = _hull.position + HULL_SHADOW_OFFSET
		_update_moorings()
		_update_navigation_lights()
	_update_scale_bar()


func _update_scale_bar() -> void:
	## DESCARGA 18/24 as a bar over the deck — the number the whole loop is
	# about, visible where the work happens instead of in a corner of the HUD.
	if not is_working():
		if _scale_bar_frac >= 0.0:
			_scale_bar_frac = -1.0
			queue_redraw()
			if _scale_label != null:
				_scale_label.visible = false
		return
	var capacity := bay_capacity()
	var done := float(capacity - cargo_left()) if is_discharging() \
		else float(export_progress().x)
	var total := float(capacity) if is_discharging() else float(export_progress().y)
	var frac := clampf(done / maxf(total, 1.0), 0.0, 1.0) if total > 0.0 else -1.0
	if is_equal_approx(frac, _scale_bar_frac):
		return
	_scale_bar_frac = frac
	queue_redraw()
	if _scale_label == null:
		_scale_label = Label.new()
		_scale_label.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL,
			Color8(255, 236, 190), 3)
		_scale_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_scale_label)
	_scale_label.visible = true
	# Claimed can overshoot the target for a beat when the last boxes land
	# together; the bar clamps but the number must not read "29/24".
	_scale_label.text = "%d/%d" % [mini(int(done), int(total)), int(total)]
	_scale_label.position = Vector2(PortLayout.SHIP_W * 0.5, -26.0) \
		- _scale_label.get_combined_minimum_size() * 0.5


var _clock_label: Label
var _clock_shown := ""


func set_deadline(left: float, total: float, is_late: bool) -> void:
	## The laytime badge above the progress bar: green while there is room,
	## amber under half, red in the last fifth, and ATRASADO once it ran out.
	## Rewritten only when the text changes.
	if total <= 0.0 or left < 0.0 and not is_late:
		if _clock_label != null:
			_clock_label.visible = false
		_clock_shown = ""
		return
	var text := "ATRASADO" if is_late else BerthDeadline.clock_text(left)
	if _clock_label == null:
		_clock_label = Label.new()
		_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_clock_label)
	var frac := left / total
	var color := Color8(220, 70, 60) if is_late or frac < 0.2 \
		else (Color8(240, 180, 60) if frac < 0.5 else Color8(110, 214, 150))
	if text == _clock_shown and _clock_label.visible:
		return
	_clock_shown = text
	_clock_label.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL, color, 3)
	_clock_label.text = text
	_clock_label.visible = true
	_clock_label.position = Vector2(PortLayout.SHIP_W * 0.5, -42.0) \
		- _clock_label.get_combined_minimum_size() * 0.5
	queue_redraw()


func _draw() -> void:
	if _scale_bar_frac < 0.0 or not is_working():
		return
	var w := 56.0
	var top := Vector2(PortLayout.SHIP_W * 0.5 - w * 0.5, -14.0)
	draw_rect(Rect2(top, Vector2(w, 6.0)), Color(0.04, 0.05, 0.1, 0.78))
	var fill := Color8(232, 176, 62) if is_discharging() else Color8(104, 194, 176)
	draw_rect(Rect2(top + Vector2(1, 1), Vector2((w - 2.0) * _scale_bar_frac, 4.0)),
		fill)
	# Placa atrás do contador: à noite casco e água escurecem juntos e o texto
	# claro apagava sem fundo próprio.
	if _clock_label != null and _clock_label.visible:
		var ct: Vector2 = _clock_label.position
		var cs: Vector2 = _clock_label.get_combined_minimum_size()
		draw_rect(Rect2(ct - Vector2(3, 2), cs + Vector2(6, 4)),
			Color(0.04, 0.05, 0.1, 0.78))
	if _scale_label != null and _scale_label.visible:
		var lt: Vector2 = _scale_label.position
		var ls: Vector2 = _scale_label.get_combined_minimum_size()
		draw_rect(Rect2(lt - Vector2(3, 2), ls + Vector2(6, 4)),
			Color(0.04, 0.05, 0.1, 0.72))


func is_working() -> bool:
	return phase == Phase.DISCHARGING or phase == Phase.WAITING_EXPORT or phase == Phase.LOADING

func is_discharging() -> bool: return phase == Phase.DISCHARGING
func is_loading() -> bool: return phase == Phase.LOADING
func cargo_left() -> int:
	var total := 0
	for col: Array in _slots:
		for item in col:
			if item != null:
				total += 1
	return total
func export_progress() -> Vector2i: return Vector2i(_export_claimed, _export_target)
func import_manifest_uids() -> PackedStringArray:
	var ids := PackedStringArray()
	for unit in _imports: ids.append(unit.uid)
	return ids
func hit_test(world_pos: Vector2) -> bool:
	return Rect2(global_position + Vector2(-8, -8),
		Vector2(PortLayout.SHIP_W + 16, hull_height() + 16)).has_point(world_pos)
func nudge(bay_column: int = -1, weight_added: bool = true) -> void:
	## A box has landed on the deck. Shake the hull for it.
	##
	## Only landings call this. A discharge lifts a box *off* — nothing strikes the
	## ship, so nothing shakes — and the berth is what enforces that. The shock
	## starts on the side that took the weight and rings through the other, which
	## is why it is signed: the first version was an unsigned shove that decayed to
	## zero, so a working berth listed permanently to the same side.
	if not weight_added:
		return
	_roll_side = _roll_side_for(bay_column)
	_roll_amp = 1.0
	_roll_phase = 0.0


func roll_offset() -> float:
	## Signed athwartships tremor in pixels: negative is to port, positive to
	## starboard. Public so the vessel suite can watch one landing cross the
	## centreline rather than infer it from a screenshot.
	if _roll_amp <= 0.0:
		return 0.0
	return sin(_roll_phase) * _roll_amp * _roll_side * SHUDDER_REACH


func roll_side() -> float:
	return _roll_side


func _advance_roll(delta: float) -> void:
	if _roll_amp <= 0.0:
		return
	_roll_phase += delta * SHUDDER_SPEED
	_roll_amp = maxf(0.0, _roll_amp - delta * SHUDDER_DECAY)


func _roll_side_for(bay_column: int) -> float:
	## The deck is two columns wide, so a bay is either port or starboard, and the
	## weight lands on the side its bay is on.
	if bay_column >= 0:
		return -1.0 if bay_column < COLS - bay_column - 1 else 1.0
	# Nothing said which bay it was. Alternate rather than lean, but not as a
	# metronome — and never the same side three times running.
	var fallback := _roll_side if randf() < 0.35 else -_roll_side
	if is_equal_approx(fallback, _roll_side):
		_roll_repeats += 1
		if _roll_repeats >= 2:
			fallback = -_roll_side
			_roll_repeats = 0
	else:
		_roll_repeats = 0
	return fallback
func set_flights_in_progress(total: int) -> void: _flights_in_progress = maxi(0, total)


func moorings_visible() -> bool:
	## Whether the ship is *made fast*, not whether the ropes are still on screen.
	## Letting go is instant; hauling the lines back aboard takes half a second,
	## and the berth state must not wait on an animation.
	return _made_fast


func _build_moorings() -> void:
	## Four lines, made fast the way a ship actually is: a head line and a stern
	## line leading away from the hull, and a spring at each end leading back
	## along it — springs are what stop a ship ranging up and down its berth, and
	## without them the pair of straight diagonals read as two drawn lines rather
	## than as mooring.
	##
	## Each one runs from a real fairlead on the hull to a real bollard on the
	## quay, sags under its own weight, and is thrown rather than appearing.
	_moorings = Node2D.new()
	_moorings.name = "MooringLines"
	_moorings.z_index = -1
	# Nothing is fast until the ship is alongside, and a Node2D is visible by
	# default: leaving that alone hung four ropes off a hull still at sea.
	_moorings.visible = false
	add_child(_moorings)
	for index in MOORING_LINES:
		var line := Line2D.new()
		line.name = "Line%d" % index
		line.width = 3.0
		line.texture = ROPE
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_NONE
		line.end_cap_mode = Line2D.LINE_CAP_NONE
		line.antialiased = false
		line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_moorings.add_child(line)
		_mooring_lines.append(line)
		var knot := Sprite2D.new()
		knot.texture = ROPE_KNOT
		knot.centered = true
		knot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		knot.visible = false
		_moorings.add_child(knot)
		_mooring_knots.append(knot)
	_plan_moorings()
	_refresh_mooring_state()


func _plan_moorings() -> void:
	## Where each line is made fast, in the hull's own space. Recomputed whenever
	## the class changes, because a feeder's fairleads are not a ULCV's.
	_mooring_plan.clear()
	var leads := _fairleads()
	if leads.is_empty():
		return
	var bow: float = leads[0]
	var stern: float = leads[leads.size() - 1]
	# A head line off the forward fairlead and a stern line off the aft one, each
	# leading away from the hull the way it actually would.
	for spec in [[bow, true], [stern, false]]:
		var lead_y: float = spec[0]
		var forward: bool = spec[1]
		var bollard := PortLayout.nearest_bollard(position.y + lead_y, forward) \
			+ PortLayout.BOLLARD_CENTRE - position
		var ship_end := Vector2(MOORING_LEAD_X, lead_y)
		_mooring_plan.append({
			"from": ship_end, "to": bollard,
			# A mooring line under tension barely hangs. The generous sag was what
			# turned these into draped noodles.
			"sag": clampf(ship_end.distance_to(bollard) * 0.045, 0.8, 2.4),
		})


func _fairleads() -> Array[float]:
	## The mooring bitts `tools/sprites/gen_ship.py` draws down the port bulwark,
	## so a rope leaves the hull where the hull has something to make it fast to.
	var leads: Array[float] = []
	var limit := hull_height() - 52.0
	var y := 60.0
	while y < limit:
		leads.append(y)
		y += 34.0
	if leads.size() < 2:
		leads = [60.0, maxf(80.0, hull_height() - 56.0)]
	return leads


func _update_moorings() -> void:
	if _moorings == null or not _moorings.visible or _mooring_plan.is_empty():
		return
	var hull_offset := _hull.position if _hull != null else Vector2.ZERO
	for index in _mooring_lines.size():
		var line := _mooring_lines[index]
		if index >= _mooring_plan.size():
			line.visible = false
			_mooring_knots[index].visible = false
			continue
		var plan: Dictionary = _mooring_plan[index]
		# Each line is thrown a little after the one before it, so the four go on
		# as a sequence rather than as one snap.
		var thrown := clampf((_mooring_throw - float(index) * 0.18) / 0.72, 0.0, 1.0)
		line.visible = thrown > 0.02
		_mooring_knots[index].visible = thrown > 0.92
		if not line.visible:
			continue
		# The hull end breathes with the ship's working bob; the quay end is
		# nailed to its bollard.
		var ship_end: Vector2 = plan.from + hull_offset
		var quay_end: Vector2 = plan.to
		var reach := ship_end.lerp(quay_end, thrown)
		var sag := float(plan.sag) * thrown
		var points := PackedVector2Array()
		for step in MOORING_SEGMENTS + 1:
			var t := float(step) / float(MOORING_SEGMENTS)
			var point := ship_end.lerp(reach, t)
			# A catenary is close enough to a parabola over this span, and the
			# straight line it replaces is exactly what made these read as wires.
			point.y += sin(t * PI) * sag
			points.append(point)
		line.points = points
		_mooring_knots[index].position = quay_end


func _refresh_mooring_state() -> void:
	if _moorings == null:
		return
	var fast := is_working()
	if fast == _made_fast:
		_update_moorings()
		return
	_made_fast = fast
	if fast:
		_moorings.visible = true
		_mooring_throw = 0.0
		_plan_moorings()
		var tween := create_tween()
		tween.tween_property(self, "_mooring_throw", 1.0, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# Let go: the lines come back aboard before the ship moves.
		var tween := create_tween()
		tween.tween_property(self, "_mooring_throw", 0.0, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if not is_working():
				_moorings.visible = false)
	_update_moorings()


func set_interaction_state(actionable: bool, hovered: bool) -> void:
	if _outline == null:
		return
	_outline.visible = actionable
	if not actionable:
		return
	# White, the colour every tappable thing in the yard is outlined in
	# (`ClickOutline`); brighter and wider under a pointer.
	var color := Color(1.0, 1.0, 1.0, 0.98) if hovered \
		else Color(1.0, 1.0, 1.0, 0.62)
	var width := 2.0 if hovered else 1.0
	for child in _outline.get_children():
		var copy := child as Sprite2D
		copy.position = copy.get_meta("outline_direction", Vector2.ZERO) * width
		(copy.material as ShaderMaterial).set_shader_parameter("outline_color", color)


func _make_outline(texture: Texture2D, centered: bool) -> Node2D:
	## Eight solid silhouettes behind the source produce a true outside border,
	## including on tightly cropped atlas regions where neighbour-sampling
	## shaders have no transparent pixel beyond the sprite quad to draw into.
	var root := Node2D.new()
	for direction in [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
	]:
		var copy := Sprite2D.new()
		copy.texture = texture
		copy.centered = centered
		copy.position = direction
		copy.set_meta("outline_direction", direction)
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/interaction_outline.gdshader")
		copy.material = material
		root.add_child(copy)
	return root


func select_variant(variant_seed: int, call_index: int,
		blocks: int = 9999, lane_classes: Array[String] = []) -> Dictionary:
	## Deterministic and history-aware. The route limits which of the three
	## GitHub silhouettes can call without introducing extra hull textures.
	ship_variant = ShipCatalog.select_variant(variant_seed, call_index,
		variant_history, blocks, lane_classes)
	if not ship_variant.is_empty():
		variant_history.append(str(ship_variant.id))
		while variant_history.size() > 8:
			variant_history.pop_front()
	_apply_ship_variant()
	return ship_variant.duplicate(true)


func apply_variant(variant: Dictionary) -> void:
	## Force a specific hull on this call — the way a special charter arrives on a
	## vessel nobody could have rolled. The *manifest* stays the controller's job,
	## because the class decides how many boxes the call moves and only one owner
	## may mint a UID.
	if variant.is_empty():
		return
	ship_variant = variant.duplicate(true)
	_apply_ship_variant()


func is_special() -> bool:
	return bool(ship_variant.get("special", false))


func variant_id() -> StringName:
	return StringName(ship_variant.get("id", ""))


func operational_capacity() -> int:
	## The vessel's nominal size in TEU, for flavour and for the journal.
	return int(ship_variant.get("capacity", 0))


func bay_rows() -> int:
	## GitHub's fleet always uses the same twelve-row source deck. Silhouette
	## variants scale that complete view; they do not swap hull textures or grids.
	return ROWS


func bay_capacity() -> int:
	## The number of boxes this call moves in each direction.
	return COLS * bay_rows()


func _apply_ship_variant() -> void:
	if _hull == null or _cargo == null or _wake == null or ship_variant.is_empty():
		return
	# The GitHub fleet is one source hull with small scale/offset variations.
	var texture := _hull_texture()
	_hull.texture = texture
	_shadow.texture = texture
	for child in _outline.get_children():
		(child as Sprite2D).texture = texture
	var paint := str(ship_variant.get("paint", ""))
	if not paint.is_empty() and ResourceLoader.exists("res://assets/sprites/%s.png" % paint):
		_paint.texture = load("res://assets/sprites/%s.png" % paint)
	var hull_scale: Vector2 = ship_variant.get("hull_scale", Vector2.ONE)
	var hull_offset: Vector2 = ship_variant.get("hull_offset", Vector2.ZERO)
	_hull.scale = hull_scale
	_hull.position = hull_offset
	_shadow.scale = hull_scale
	_shadow.position = hull_offset + HULL_SHADOW_OFFSET
	_outline.scale = hull_scale
	_outline.position = hull_offset
	_cargo.scale = hull_scale
	_cargo.position = hull_offset
	_lights_root.scale = hull_scale
	_lights_root.position = hull_offset
	_place_navigation_lights()
	_plan_moorings()
	_wake.fit(texture, hull_scale, hull_offset)
	# The livery is paint, so it goes on the paint. Tinting the whole hull
	# sprite multiplied the deck, the white house and the lifeboats by brick red
	# or bottle green, and every ship in the game came in one muddy colour.
	_hull.modulate = Color.WHITE
	_paint.self_modulate = Color(str(ship_variant.get("hull_color", "#ffffff")))
	# Foam is white whatever the livery; the palette only leans it a little.
	_wake.tint = Color.WHITE.lerp(
		Color(str(ship_variant.get("wake_color", "#ffffff"))), 0.25)


func _hull_texture() -> Texture2D:
	var sprite := str(ship_variant.get("sprite", ""))
	if sprite.is_empty():
		return HULL_FALLBACK
	# The active port's own deck and house when it has one (`PortDB`).
	var path := "res://assets/sprites/%s.png" % PortDB.sprite_name(sprite)
	if not ResourceLoader.exists(path):
		return HULL_FALLBACK
	return load(path)


func hull_height() -> float:
	## The one 232-px source hull after its catalogue scale is applied.
	if _hull != null and _hull.texture != null:
		return _hull.texture.get_height() * _hull.scale.y
	return PortLayout.SHIP_H


## Coordinates of the single GitHub sprite: bow at the top, cargo from y=44,
## accommodation block at the stern near the bottom.
const HOUSE_TOP := 180.0
const HOUSE_H := 30.0
const DECK_TOP := 44.0
const DECK_BOTTOM := 176.0
## The rails beside the source sprite's hatch covers.
const BULWARK_X := 5.0
const BULWARK_SPAN := 55.0

## One lamp on the shared hull source.
class ShipLight:
	extends RefCounted
	var glow: Sprite2D
	var base := Vector2.ZERO
	var from_stern := false
	var gain := 0.6
	var duty := 0.0        # extra while the berth is being worked
	var phase := 0.0       # so a row of lamps does not breathe in unison

var _lights: Array[ShipLight] = []
## Kept apart from the flat list because these are the ones whose position
## depends on how long this class's cargo deck is. Index arithmetic into
## `_lights` worked right up until a lamp was inserted in the middle of it.
var _deck_floods: Array[ShipLight] = []
var _stern_light: ShipLight
var _port_light: ShipLight
var _starboard_light: ShipLight
var _masthead_light: ShipLight


func _build_navigation_lights() -> void:
	## A ship at night is not a silhouette with two dots on it. It is a lit
	## object: sidelights and a masthead lamp at the bow, deck floodlights and a
	## stern lamp. The GitHub hull itself has no separate cabin-window layer.
	## The whole set follows nightfall and lifts again while the hull is worked,
	## because a berth being worked at 3am is lit up like a workshop.
	_lights_root = Node2D.new()
	_lights_root.name = "NavigationLights"
	add_child(_lights_root)

	# Sidelights, on the pixels the hull sprite already paints them on: red to
	# port, green to starboard, the way they are on the water. Both sit a fixed
	# distance up from the stem, so they are placed with the rest of the bow gear.
	_port_light = _add_light(Vector2(4.0, 0.0), Color8(255, 62, 52), 0.16, 0.95)
	_starboard_light = _add_light(Vector2(61.0, 0.0), Color8(72, 255, 140), 0.16, 0.95)
	# Masthead, over the bow mast.
	_masthead_light = _add_light(Vector2(33.0, 0.0), Color8(255, 246, 220), 0.13, 0.8)
	# Deck floods, on the bulwarks. Three down each rail, which is where the lamp
	# posts are on a real hull: the light comes from the sides of the deck and
	# falls inboard across the boxes. Sitting them over the middle of each bay
	# instead put a glow in the centre of the ship with nothing casting it.
	for row in 3:
		for side in 2:
			_deck_floods.append(_add_light(
				Vector2(BULWARK_X + side * (BULWARK_SPAN), 0.0),
				Color8(206, 228, 255), 0.46, 0.5, 0.34,
				float(row * 2 + side) * 0.9))
	# Stern lamp at the rounded transom, near the bottom of the source sprite.
	_stern_light = _add_light(Vector2(33.0, 0.0), Color8(255, 244, 210), 0.16, 0.8)
	_place_navigation_lights()


func _place_navigation_lights() -> void:
	## All positions are coordinates in the one 66x232 GitHub source sprite.
	for index in _deck_floods.size():
		@warning_ignore("integer_division") var row := index / 2
		_deck_floods[index].base.y = lerpf(DECK_TOP + 10.0, DECK_BOTTOM,
			float(row) / 2.0)
	if _stern_light != null:
		_stern_light.base.y = 226.0
	if _port_light != null:
		_port_light.base.y = 46.0
	if _starboard_light != null:
		_starboard_light.base.y = 46.0
	if _masthead_light != null:
		_masthead_light.base.y = 8.0
	for light in _lights:
		light.glow.position = light.base


func _add_light(pos: Vector2, color: Color, glow_scale: float, gain: float,
		duty: float = 0.0, phase: float = 0.0) -> ShipLight:
	var glow := Sprite2D.new()
	glow.texture = preload("res://assets/sprites/prop_glow.png")
	glow.position = pos
	glow.scale = Vector2.ONE * glow_scale
	glow.modulate = color
	glow.modulate.a = 0.0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	_lights_root.add_child(glow)
	_light_glows.append(glow)
	var light := ShipLight.new()
	light.glow = glow
	light.base = pos
	light.gain = gain
	light.duty = duty
	light.phase = phase
	_lights.append(light)
	return light


func _update_navigation_lights() -> void:
	if _lights_root == null:
		return
	var night := Skyscape._night_factor(TimeManager.time_of_day)
	# Fog is the other time a hull has to be seen, and it is the one the port
	# actually pays for, so the lamps come on for it too.
	var dim := maxf(clampf(night * 1.3, 0.0, 1.0),
		0.55 if TimeManager.fog_active else 0.0)
	var working := 1.0 if is_working() else 0.5 \
		if phase == Phase.ARRIVING or phase == Phase.DEPARTING else 0.0
	# Sidelights and the masthead are shown under way and alongside alike; the
	# deck floods are the ones that mean somebody is working down there.
	for light in _lights:
		var breath := 0.93 + sin(_t * 2.1 + light.phase) * 0.07
		var lit := dim * light.gain + working * light.duty
		light.glow.modulate.a = clampf(lit, 0.0, 1.0) * breath
func _set_phase(value: Phase) -> void:
	if phase == value: return
	phase = value
	_refresh_wake_state()
	_refresh_mooring_state()
	phase_changed.emit(value)


func _refresh_wake_state() -> void:
	if _wake == null or not is_instance_valid(_wake):
		return
	# Only the run up or down the channel makes a wake. A hull being warped off
	# the wall or in off the offing is going sideways under tow at walking pace,
	# and a wake streaming off a ship moving beam-on is the wrong picture.
	var moving := _under_way \
		and (phase == Phase.ARRIVING or phase == Phase.DEPARTING)
	_wake.visible = moving
	if moving:
		# Departure is the faster leg; both values stay deliberately restrained.
		_wake.speed_scale = 1.0 if phase == Phase.DEPARTING else 0.72
		if not _wake.is_playing():
			_wake.play()
	else:
		_wake.stop()

func set_manifest(imports: Array[CargoUnit], export_target: int = 0) -> void:
	_imports = imports.duplicate()
	_export_target = export_target if export_target > 0 else imports.size()
	_exported = 0
	_export_claimed = 0
	_build_import_view()

func set_import_manifest_reference(imports: Array[CargoUnit]) -> void:
	## Restore rebuilds the current deck independently; keep the full inbound
	## identity set for export validation without disturbing visible boxes.
	_imports = imports.duplicate()

func _empty_grid() -> void:
	for child in _cargo.get_children(): child.queue_free()
	_slots.clear()
	_reserved.clear()
	for c in COLS:
		var column: Array = []
		column.resize(bay_rows())
		_slots.append(column)

func _build_import_view() -> void:
	_empty_grid()
	for i in _imports.size():
		var col := i % COLS
		@warning_ignore("integer_division") var row := i / COLS
		if row < bay_rows(): _make_box(col, row, _imports[i])

func _make_box(col: int, row: int, unit: CargoUnit) -> void:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = _containers
	atlas.region = Rect2(unit.color * 24, 0, 24, 13)
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = Vector2(BAY_X[col] - 1.0, BAY_Y0 + row * BAY_PITCH - 1.0)
	# No cast shadow here on purpose. The deck rows are eleven pixels apart and a
	# box is thirteen tall, so an offset copy lands on the box *below* it and the
	# whole hold turns into dark bands. Boxes on the ground in the yard cast;
	# boxes packed in a hold do not have anywhere to cast onto.
	if unit.premiada:
		# The manifest's premiada box gleams gold on deck, with a spark that
		# runs while it waits — the x5 is visible before it is earned.
		sprite.modulate = Color(1.35, 1.12, 0.55)
		var glint := AnimatedSprite2D.new()
		var glint_frames := SpriteFrames.new()
		var spark_tex: Texture2D = load("res://assets/sprites/fx_spark.png")
		for f in 4:
			var at := AtlasTexture.new()
			at.atlas = spark_tex
			at.region = Rect2(f * 7, 0, 7, 7)
			glint_frames.add_frame(&"default", at)
		glint_frames.set_animation_speed(&"default", 6.0)
		glint.sprite_frames = glint_frames
		glint.centered = true
		glint.position = Vector2(12, 6)
		sprite.add_child(glint)
		if UserPreferences.can_animate():
			glint.play()
		else:
			glint.visible = false
	_cargo.add_child(sprite)
	_slots[col][row] = {"sprite": sprite, "unit": unit}

func take_container() -> Dictionary:
	for col in range(COLS - 1, -1, -1):
		for row in bay_rows():
			var item: Variant = _slots[col][row]
			if item != null:
				var sprite: Sprite2D = item.sprite
				var unit: CargoUnit = item.unit
				var out := {
					"col": col, "row": row,
					# `Sprite2D.global_position` is its top-left anchor here.
					# `to_global` also includes the selected hull's scale,
					# offset and current berth bob.
					"pos": sprite.to_global(BOX_VISUAL_CENTRE),
					"color": unit.color, "unit": unit,
				}
				sprite.queue_free()
				_slots[col][row] = null
				return out
	return {}

func restore_import(taken: Dictionary) -> void:
	if taken.is_empty() or not taken.has("unit"): return
	if _slots[int(taken.col)][int(taken.row)] == null: _make_box(int(taken.col), int(taken.row), taken.unit)

func wait_for_export() -> void:
	if cargo_left() == 0: _set_phase(Phase.WAITING_EXPORT)
func begin_loading() -> void:
	if cargo_left() == 0: _set_phase(Phase.LOADING)

func reserve_bay() -> Dictionary:
	if _export_claimed >= _export_target: return {}
	for col in COLS:
		for row in range(bay_rows() - 1, -1, -1):
			var key := "%d,%d" % [col, row]
			if _slots[col][row] == null and not _reserved.has(key):
				_reserved[key] = true
				_export_claimed += 1
				var top_left := Vector2(
					BAY_X[col] - 1.0,
					BAY_Y0 + row * BAY_PITCH - 1.0)
				# Cargo is scaled and offset with each hull variant. Going
				# through its transform makes the flight finish on the visible
				# slot rather than on the unscaled base-layout coordinate.
				return {"col": col, "row": row,
					"pos": _cargo.to_global(top_left + BOX_VISUAL_CENTRE)}
	return {}
func release_bay(bay: Dictionary) -> void:
	if bay.is_empty(): return
	var key := "%d,%d" % [int(bay.col), int(bay.row)]
	if _reserved.erase(key): _export_claimed = maxi(0, _export_claimed - 1)
func place_unit(col: int, row: int, unit: CargoUnit) -> bool:
	# Sector is not checked here any more. Since the yard tranships, a box being
	# loaded may well have arrived as an IMPORT on an earlier call — refusing it
	# made every such transfer roll back with "movimento cancelado" and the
	# berth could never finish loading.
	if unit == null or col < 0 or col >= COLS or row < 0 or row >= bay_rows():
		return false
	var key := "%d,%d" % [col, row]
	if not _reserved.has(key) or _slots[col][row] != null:
		return false
	_reserved.erase(key)
	_make_box(col, row, unit)
	_exported += 1
	return true
func place_container(col: int, row: int, color_idx: int) -> bool:
	return place_unit(col, row, CargoUnit.new("", CargoUnit.EXPORT, color_idx))
func ready_to_depart() -> bool:
	return _export_target > 0 and _exported >= _export_target and _flights_in_progress == 0

func arrive(open_channel: bool = true) -> void:
	if _imports.is_empty():
		var generated: Array[CargoUnit] = []
		for i in bay_capacity(): generated.append(CargoUnit.new("", CargoUnit.IMPORT, randi() % 8))
		set_manifest(generated, generated.size())
	_set_phase(Phase.ARRIVING)
	visible = true
	# The hull is drawn bow **up**, so a ship can only travel north bow-first. The
	# channel therefore runs south to north past the quay: in from the open water
	# below, out past the top. Which end this is has to agree with `gen_ship.py`,
	# or the ship reverses into its berth and reverses back out to sea — which is
	# exactly what it did between the sprite being flipped back and this being
	# noticed. `PortLayout.channel_entry_y/exit_y` own the two ends so the sign
	# lives in one place with the reason attached.
	var moored := berth_position()
	var tween := create_tween()
	if open_channel:
		# The full approach: down the fairway, outboard of the berth line, sliding
		# alongside over the last stretch. It is the set piece the port is built
		# around, and it is only available when nothing is moored between this berth
		# and the open water above it.
		_under_way = true
		position = Vector2(PortLayout.FAIRWAY_X, PortLayout.channel_entry_y())
		tween.tween_property(self, "position:y", moored.y, 5.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "position:x", moored.x, 2.1) \
			.set_delay(3.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		# Somebody is alongside between here and the sea, and the channel fits one
		# hull. Come in off the offing instead, beam-on under the tugs and straight
		# onto the berth: no part of that track crosses another ship.
		_under_way = false
		position = Vector2(PortLayout.OFFING_X, moored.y)
		tween.tween_property(self, "position:x", moored.x, 4.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_under_way = false
		_set_phase(Phase.DISCHARGING)
		EventBus.ship_arrived.emit()
		AudioManager.play_sfx("horn", 0.04, -4.0))
	_refresh_wake_state()


func depart(open_channel: bool = true) -> void:
	if phase == Phase.DEPARTING or phase == Phase.AWAY or not ready_to_depart(): return
	_set_phase(Phase.DEPARTING)
	AudioManager.play_sfx("horn", 0.04, -6.0)
	var tween := create_tween()
	# Lines let go, then off the wall. The sidestep is its own leg rather than
	# something that happens while the ship is already under way: a hull that
	# starts up the channel the instant it is freed reads as sliding along the
	# quay it was tied to.
	tween.tween_interval(0.9)
	tween.tween_property(self, "position:x", PortLayout.FAIRWAY_X, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if open_channel:
		tween.tween_callback(func() -> void:
			_under_way = true
			_refresh_wake_state())
		tween.tween_property(self, "position:y", PortLayout.channel_exit_y(), 4.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		# The way north is somebody else's berth. Out to sea instead, the way the
		# tugs took it off the wall: no crossing, and nothing to slide through.
		tween.tween_property(self, "position:x", PortLayout.OFFING_X, 3.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_under_way = false
		visible = false
		_set_phase(Phase.AWAY)
		departed.emit())
	_refresh_wake_state()


func berth_position() -> Vector2:
	return Vector2(PortLayout.SHIP_X, PortLayout.berth_y(berth_index))

func snapshot() -> Dictionary:
	var manifest: Array = []
	for col_index in _slots.size():
		var column: Array = _slots[col_index]
		for row_index in column.size():
			var item: Variant = column[row_index]
			if item != null:
				manifest.append({
					"col": col_index,
					"row": row_index,
					"unit": item.unit.snapshot(),
				})
	return {"phase": int(phase), "exports_target": _export_target, "exported": _exported,
		"claimed": _export_claimed, "manifest": manifest,
		"variant": ship_variant.duplicate(true), "variant_history": variant_history.duplicate()}


func restore(data: Dictionary) -> void:
	_export_target = int(data.get("exports_target", 0))
	_exported = int(data.get("exported", 0))
	_export_claimed = int(data.get("claimed", _exported))
	ship_variant = _restore_variant(data.get("variant", {}))
	variant_history = _restore_variant_history(data.get("variant_history", []))
	if ship_variant.is_empty():
		ship_variant = ShipCatalog.select_variant(0, 0, variant_history)
	_apply_ship_variant()
	_empty_grid()
	var manifest: Array = data.get("manifest", [])
	for i in manifest.size():
		var raw: Variant = manifest[i]
		if not (raw is Dictionary):
			continue
		var unit_raw: Variant = raw.get("unit", raw)
		if not (unit_raw is Dictionary):
			continue
		# v2.1 records retain the physical bay so a mid-flight restore leaves
		# the reserved origin empty. Older flat manifests remain readable.
		var col := int(raw.get("col", i % COLS))
		@warning_ignore("integer_division")
		var legacy_row := i / COLS
		var row := int(raw.get("row", legacy_row))
		# The grid is only as deep as this class stows, so a record from a bigger
		# hull cannot be indexed straight into it.
		if col >= 0 and col < COLS and row >= 0 and row < bay_rows() \
				and _slots[col][row] == null:
			_make_box(col, row, CargoUnit.from_snapshot(unit_raw))
	_set_phase(int(data.get("phase", Phase.AWAY)))


func _restore_variant(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var silhouette_id := StringName(raw.get("silhouette_id", ""))
	var palette_id := StringName(raw.get("palette_id", ""))
	var silhouette := ShipCatalog.get_silhouette(silhouette_id)
	var palette := ShipCatalog.get_palette(palette_id)
	if silhouette.is_empty() or palette.is_empty():
		return {}
	var variant := ShipCatalog.compose(silhouette, palette)
	if bool(raw.get("special", false)):
		variant["special"] = true
	return variant


func _restore_variant_history(raw: Variant) -> Array[String]:
	var restored: Array[String] = []
	if raw is Array:
		for item in raw:
			if item is String or item is StringName:
				restored.append(str(item))
	while restored.size() > 8:
		restored.pop_front()
	return restored

func normalize_after_restore() -> void:
	## Flights are reconciled by BerthCallController; transient tween phases are
	## resumed as a stable berth state at the physical dock.
	if phase == Phase.ARRIVING:
		visible = true
		position = berth_position()
		_set_phase(Phase.DISCHARGING)
	elif phase == Phase.DEPARTING:
		visible = true
		position = berth_position()
		_set_phase(Phase.LOADING)
	elif phase == Phase.AWAY:
		visible = false
	else:
		visible = true
		position = berth_position()
	_flights_in_progress = 0
	_reserved.clear()
	_export_claimed = _exported
func apply_view_metrics(metrics: Dictionary) -> void:
	visible = bool(metrics.get("ship_visible", visible))
