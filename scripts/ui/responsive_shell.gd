class_name ResponsiveShell
extends CanvasLayer
## Single source of viewport metrics for UI, world framing and save lifecycle.
## Main owns the final connections so this shell remains safe to add gradually.

signal metrics_changed(metrics: Dictionary)
signal world_input_blocked_changed(blocked: bool)
signal save_requested(reason: StringName)

## The one profile the game has. It used to also classify a wide viewport as
## `desktop` and hand two thirds of it to the world so a command rail could own
## the rest — but `PortraitFrame` now clamps the aspect at 2:3, so the logical
## viewport is never wider than it is tall and that branch could not be reached
## from inside the game. It is gone rather than dormant: a layout no player can
## open still gets maintained, still gets tested, and still gets described in the
## roadmap as if it shipped.
const PROFILE := "portrait"

var metrics: Dictionary = {}
var _world_input_blocked := false


func _ready() -> void:
	layer = 1
	get_viewport().size_changed.connect(_rebuild_metrics)
	_rebuild_metrics()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		save_requested.emit(&"focus_lost")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_requested.emit(&"close_request")


func set_world_input_blocked(blocked: bool) -> void:
	if _world_input_blocked == blocked:
		return
	_world_input_blocked = blocked
	world_input_blocked_changed.emit(blocked)


func request_save(reason: StringName = &"ui") -> void:
	save_requested.emit(reason)


func _rebuild_metrics() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_rect := _safe_area(viewport_size)
	# The port gets the whole safe area. `world_rect` stays in the metrics because
	# the camera and the gantry frame the *port*, not the window, and a future
	# inset (a tablet layout, a cutout) belongs here rather than in each consumer.
	var world_rect := safe_rect
	metrics = {
		"profile": PROFILE,
		"viewport_size": viewport_size,
		"safe_rect": safe_rect,
		"world_rect": world_rect,
		"ui_scale": clampf(minf(viewport_size.x / 320.0, viewport_size.y / 480.0), 1.0, 2.0),
	}
	metrics_changed.emit(metrics)


func _safe_area(viewport_size: Vector2) -> Rect2:
	# Desktop safe-area APIs describe the monitor work area (menu bar/dock),
	# not in-window content. Applying that rectangle to a resizable game window
	# incorrectly creates a top inset. Mobile platforms expose the actual notch
	# and gesture-safe bounds, which are converted back to logical viewport
	# coordinates below.
	if not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, viewport_size)
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Rect2(Vector2.ZERO, viewport_size)
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)
	var logical_scale := viewport_size / window_size
	var rect := Rect2(Vector2(safe.position) * logical_scale,
		Vector2(safe.size) * logical_scale)
	return rect.intersection(Rect2(Vector2.ZERO, viewport_size))
