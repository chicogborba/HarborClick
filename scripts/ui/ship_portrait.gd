class_name ShipPortrait
extends Control
## One fleet ship side-on, bow to the right, for the album: the
## `ship_side_<hull>` sheet's layers stacked and tinted with the ship's livery
## (base, hull paint, house, one trim pattern — `tools/sprites/gen_ship.py`).
##
## Drawn, not built from TextureRects: four layers per card times forty-odd
## cards is a lot of nodes for a picture that only changes when a ship is seen.
## Unseen, it is the same outline in one flat colour — the silhouette the album
## promises, which already tells you how big the ship is.

const FRAME := Vector2(112, 34)
const SILHOUETTE := Color8(40, 34, 48)

var _ship: Dictionary = {}
var _sheet: Texture2D
var _seen := false


func _init() -> void:
	custom_minimum_size = FRAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_ship(ship: Dictionary, seen: bool) -> void:
	if ship == _ship and seen == _seen:
		return
	_ship = ship
	_seen = seen
	var path := "res://assets/sprites/ship_side_%s.png" % str(ship.get("hull", "feeder"))
	_sheet = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()


func _draw() -> void:
	if _sheet == null:
		return
	var origin := ((size - FRAME) * 0.5).floor()
	var target := Rect2(origin, FRAME)
	if not _seen:
		# Every opaque pixel of every layer in one colour: the base layer alone
		# already covers the whole outline.
		draw_texture_rect_region(_sheet, target, _frame(0), SILHOUETTE)
		return
	draw_texture_rect_region(_sheet, target, _frame(0))
	draw_texture_rect_region(_sheet, target, _frame(1),
		Color(str(_ship.get("hull_color", "#ffffff"))))
	draw_texture_rect_region(_sheet, target, _frame(2),
		Color(str(_ship.get("house_color", "#ffffff"))))
	draw_texture_rect_region(_sheet, target, _frame(3 + FleetDB.trim_index(_ship)),
		Color(str(_ship.get("trim_color", "#ffffff"))))


func _frame(index: int) -> Rect2:
	return Rect2(Vector2(index * FRAME.x, 0.0), FRAME)
