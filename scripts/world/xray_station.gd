class_name XrayStation
extends Node2D
## The Receita's inspection post, standing in the yard beside gate bay G3.
##
## The scanner used to be a key on the HUD, which made it a menu. It is a place
## now: an abandoned post the player finds on the quay, repairs (the purchase),
## and walks back to whenever its lamp turns red. Tapping it is the only way
## into the scan, so an inspection is something you go and do, not something
## that is done to you.
##
## Presentation only. Main owns the service and tells this node what state to
## show (`set_state`); the world routes taps here through `hit_test`.

enum State { ABANDONED, IDLE, DUE }

const SHEET := preload("res://assets/sprites/xray_station.png")
const FRAME := Vector2(34, 46)

var state: State = State.ABANDONED
## A purchase is within reach: the abandoned post shows a wrench bubble.
var repairable := false

var _sprite: Sprite2D
var _atlas: AtlasTexture
var _bubble: Node2D
var _t := 0.0


func _ready() -> void:
	position = PortLayout.xray_station_position()
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(3, 44), Vector2(36, 44),
		Vector2(37, 47), Vector2(4, 47)])
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


func hit_test(world_pos: Vector2) -> bool:
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
