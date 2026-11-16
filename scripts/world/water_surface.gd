class_name WaterSurface
extends Node2D
## The harbour water, rendered at one fragment per world pixel.
##
## It used to be a ColorRect in the world with the shader on it, so the shader
## ran once per *screen* pixel: at the camera's 3x on a phone that was nine
## identical evaluations of every world pixel, and the cure was to give phones
## the cheapest path — four flat bands, which is the water most players saw. Here
## the shader paints a SubViewport exactly the size of the water in world pixels
## and a sprite shows it, nearest-filtered, where the ColorRect was. The cost no
## longer depends on the screen at all, and every device gets the full surface.
##
## It also only paints the rows the camera can see. A bought-out port is nearly
## four thousand pixels of quay, and repainting all of it every frame to show
## four hundred was most of the water's cost. The target is a window the height
## of the view (plus a margin) that slides down the sea with the camera; sliding
## it is a uniform and a sprite offset, never a reallocation, and the pattern is
## hashed on world pixels so nothing swims as it moves.
##
## Presentation only. `PortWorld` sets uniforms on `water_material`.

var water_material: ShaderMaterial
## Size in world pixels. Setting it resizes the render target.
var size := Vector2.ZERO:
	set(value):
		size = Vector2(maxf(1.0, roundf(value.x)), maxf(1.0, roundf(value.y)))
		_apply_size()

## Rows painted above and below the view, so a fling never shows an edge.
const MARGIN := 24

var _viewport: SubViewport
## World row the painted window currently starts at, relative to `position`.
var _window_top := -1
var _window_h := 0
var _canvas: ColorRect
var _display: Sprite2D


func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Target"
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	_canvas = ColorRect.new()
	_canvas.name = "Surface"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_canvas)
	water_material = ShaderMaterial.new()
	_canvas.material = water_material
	_display = Sprite2D.new()
	_display.name = "Display"
	_display.centered = false
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_display)


func _ready() -> void:
	_display.texture = _viewport.get_texture()
	_apply_size()


func _process(_delta: float) -> void:
	follow_view(_visible_world_rect())


func follow_view(view: Rect2) -> void:
	## Slides the painted window to cover `view` (world space).
	var want_h := mini(int(size.y), int(ceil(view.size.y)) + MARGIN * 2)
	if want_h != _window_h:
		_window_h = want_h
		_viewport.size = Vector2i(int(size.x), _window_h)
		_canvas.size = Vector2(size.x, _window_h)
		_window_top = -1
	var top := clampi(int(floor(view.position.y - position.y)) - MARGIN,
		0, maxi(0, int(size.y) - _window_h))
	if top == _window_top:
		return
	_window_top = top
	_display.position = Vector2(0.0, top)
	water_material.set_shader_parameter("world_offset",
		position + Vector2(0.0, top))


func painted_rows() -> Vector2i:
	## (first row, row count) of the window, for tests.
	return Vector2i(_window_top, _window_h)


func _visible_world_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(position, size)
	var screen := Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	return vp.get_canvas_transform().affine_inverse() * screen


func set_shader(shader: Shader) -> void:
	water_material.shader = shader


func viewport() -> SubViewport:
	return _viewport


func _apply_size() -> void:
	if _viewport == null:
		return
	# Until the first `follow_view` the whole sea is painted, which is also what
	# a harness without a camera gets.
	_window_h = int(size.y)
	_window_top = -1
	_viewport.size = Vector2i(size)
	_canvas.position = Vector2.ZERO
	_canvas.size = size
	_display.position = Vector2.ZERO
	if is_inside_tree():
		_display.texture = _viewport.get_texture()
