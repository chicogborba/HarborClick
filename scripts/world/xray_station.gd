class_name XrayStation
extends Node2D
## The Receita's drive-through scanner, standing on the second parcel.
##
## It is not there at all until that ground is paved (`LandDB.SCANNER_PARCEL`).
## Then it turns up with the parcel: boarded, rusted, weeds in the lane — the
## last owner's — and repairing it is the purchase. `_Loop` draws the two feeder
## lanes that join its lane to the road, so the lane is a loop off the road
## rather than a strip of concrete that starts and stops in the open.
##
## The scanner used to be a key on the HUD, which made it a menu. It is a place
## now: a short lane under a scanning gantry, with the source tower and the
## operator's booth beside it. The player finds it abandoned, repairs it (the
## purchase), and walks back to it whenever its lamp turns red — which is when
## a lorry is stopped under the beam waiting to be read. Tapping it is the only way
## into the scan, so an inspection is something you go and do, not something
## that is done to you.
##
## Presentation only. Main owns the service and tells this node what state to
## show (`set_state`); the world routes taps here through `hit_test`.

enum State { ABANDONED, IDLE, DUE }

const SHEET := preload("res://assets/sprites/xray_station.png")
const FRAME := Vector2(42, 60)

var state: State = State.ABANDONED
## A purchase is within reach: the abandoned post shows a wrench bubble.
var repairable := false

var _sprite: Sprite2D
var _loop: _Loop
var _atlas: AtlasTexture
var _bubble: Node2D
var _t := 0.0


func _ready() -> void:
	position = PortLayout.xray_station_position()
	_loop = _Loop.new()
	add_child(_loop)
	EventBus.land_bought.connect(_on_land_changed)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(28, 4), Vector2(42, 6),
		Vector2(43, 52), Vector2(28, 52)])
	shadow.color = Color(0.1, 0.08, 0.14, 0.32)
	add_child(shadow)
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(Vector2.ZERO, FRAME)
	_sprite = Sprite2D.new()
	_sprite.texture = _atlas
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	# Always tappable: abandoned it opens the repair, working it shows the
	# next inspection, lit it opens the scan.
	ClickOutline.attach(_sprite)
	_bubble = _Bubble.new()
	_bubble.position = Vector2(FRAME.x * 0.5, -8.0)
	_bubble.visible = false
	add_child(_bubble)
	_apply()


func set_state(next: State, can_repair: bool = false) -> void:
	if next == state and can_repair == repairable:
		return
	state = next
	repairable = can_repair
	_apply()


func _on_land_changed(_id: String = "") -> void:
	position = PortLayout.xray_station_position()
	_apply()


func on_parcel() -> bool:
	return GameState.land.has(LandDB.SCANNER_PARCEL)


func hit_test(world_pos: Vector2) -> bool:
	if not visible:
		return false
	## Generous, like every touch target in the yard: a few pixels round the
	## drawing, and the bubble above it counts.
	return Rect2(global_position + Vector2(-4, -18), FRAME + Vector2(8, 22)) \
		.has_point(world_pos)


func centre() -> Vector2:
	return global_position + FRAME * 0.5


func sprite() -> Sprite2D:
	return _sprite


func _apply() -> void:
	if _bubble == null:
		return
	var show_bubble := state == State.DUE or (state == State.ABANDONED and repairable)
	_bubble.visible = show_bubble
	(_bubble as _Bubble).kind = &"alert" if state == State.DUE else &"wrench"
	_bubble.queue_redraw()
	# No parcel, no post — unless it was repaired back when it stood at the gate.
	visible = on_parcel() or state != State.ABANDONED
	_loop.visible = on_parcel()
	_loop.worn = state == State.ABANDONED
	_loop.queue_redraw()
	_frame()


func _frame() -> void:
	var index := 0
	match state:
		State.IDLE:
			index = 1
		State.DUE:
			index = 2 if int(_t * 3.0) % 2 == 0 else 3
	_atlas.region = Rect2(Vector2(index * FRAME.x, 0), FRAME)


func _process(delta: float) -> void:
	_t += delta
	if state == State.DUE:
		_frame()
	if _bubble.visible and UserPreferences.can_animate():
		_bubble.position.y = -8.0 + roundf(sin(_t * 4.0) * 1.5)


class _Loop extends Node2D:
	## The feeders: off the road, along to the lane, and back. Painted to match
	## the lane in the sheet — bright concrete and yellow edge lines when the
	## post works, grey and faded with grass in the joints when it does not.
	var worn := true

	func _draw() -> void:
		var concrete := Color8(132, 126, 114) if worn else Color8(164, 160, 152)
		var paint := Color8(150, 130, 80) if worn else Color8(236, 196, 60)
		var ink := Color8(24, 20, 30)
		var h := PortLayout.SCANNER_FEEDER_H
		var x0 := PortLayout.ROAD_X1 - (get_parent() as Node2D).position.x
		var x1 := 26.0
		for side in 2:
			var top := -h if side == 0 else XrayStation.FRAME.y
			var outer := top if side == 0 else top + h - 1.0
			var inner := top + h - 1.0 if side == 0 else top
			draw_rect(Rect2(x0, top, x1 - x0, h), concrete)
			draw_rect(Rect2(x0, outer, x1 - x0 + 1.0, 1.0), ink)
			draw_rect(Rect2(x1, top, 1.0, h), ink)
			draw_rect(Rect2(x0, inner, 2.0 - x0, 1.0), ink)
			# Edge lines, turning the corner into the lane's own.
			var outer_line := top + 3.0 if side == 0 else top + h - 4.0
			var inner_line := top + h - 4.0 if side == 0 else top + 3.0
			draw_rect(Rect2(x0, outer_line, 24.0 - x0 + 1.0, 1.0), paint)
			draw_rect(Rect2(24.0, minf(outer_line, inner), 1.0,
				absf(inner - outer_line) + 1.0), paint)
			draw_rect(Rect2(x0, inner_line, 5.0 - x0 + 1.0, 1.0), paint)
			draw_rect(Rect2(5.0, minf(inner_line, inner), 1.0,
				absf(inner - inner_line) + 1.0), paint)
			# Which way: in along the top, out along the bottom.
			var mid := top + floorf(h * 0.5)
			var dir := 1.0 if side == 0 else -1.0
			var ax := x0 + (x1 - x0) * 0.45
			var arrow := Color(1, 1, 1, 0.3 if worn else 0.7)
			for i in 3:
				draw_rect(Rect2(ax + dir * (2 - i) * 2.0, mid - i * 2.0, 2.0, 2.0), arrow)
				draw_rect(Rect2(ax + dir * (2 - i) * 2.0, mid + i * 2.0, 2.0, 2.0), arrow)
			if worn:
				var rng := RandomNumberGenerator.new()
				rng.seed = 77 + side
				for i in 7:
					var gx := rng.randf_range(x0 + 2.0, x1 - 3.0)
					var gy := top + rng.randf_range(5.0, h - 6.0)
					draw_rect(Rect2(roundf(gx), roundf(gy), 1.0, 2.0), Color8(92, 140, 70))
					draw_rect(Rect2(roundf(gx) + 1.0, roundf(gy) + 1.0, 1.0, 1.0),
						Color8(70, 112, 58))


class _Bubble extends Node2D:
	## A speech bubble with a red "!" (inspection due) or a wrench (the
	## abandoned post can be repaired). Drawn, not a sprite: two shapes.
	var kind: StringName = &"alert"

	func _draw() -> void:
		var ink := Color8(24, 20, 30)
		var paper := Color8(250, 242, 220)
		draw_rect(Rect2(-7, -8, 14, 12), ink)
		draw_rect(Rect2(-6, -7, 12, 10), paper)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, 4), Vector2(2, 4),
			Vector2(0, 7)]), ink)
		draw_rect(Rect2(-1, 3, 2, 2), paper)
		if kind == &"alert":
			var red := Color8(220, 56, 48)
			draw_rect(Rect2(-1, -6, 2, 5), red)
			draw_rect(Rect2(-1, 0, 2, 2), red)
		else:
			var steel := Color8(92, 100, 118)
			for i in 6:
				draw_rect(Rect2(-3 + i, 1 - i, 2, 2), steel)
			draw_rect(Rect2(1, -6, 4, 2), steel)
			draw_rect(Rect2(3, -6, 2, 4), steel)
