class_name GroundSurface
extends Node
## Runs the ground's weathering pass (`ground_detail.gdshader`) over the baked
## ground, once, on the GPU, and hands back the result.
##
## GroundBaker places paint; it cannot afford per-pixel variation across a
## four-thousand-pixel terminal in GDScript, and tiles cannot give it. A
## SubViewport the size of the ground, drawn once (`UPDATE_ONCE`) and then left
## alone, does it in a single pass with no per-frame cost. Rebaking after a land
## purchase just swaps the source texture and asks for one more frame.

const SHADER := preload("res://assets/shaders/ground_detail.gdshader")

var _viewport: SubViewport
var _canvas: TextureRect
var _material: ShaderMaterial


func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Target"
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	_canvas = TextureRect.new()
	_canvas.name = "Source"
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport.add_child(_canvas)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_canvas.material = _material


func weather(source: Texture2D, rail_owned: bool) -> Texture2D:
	## Returns a texture that shows `source` weathered from the next drawn frame.
	var size := Vector2i(source.get_size())
	_viewport.size = size
	_canvas.texture = source
	_canvas.position = Vector2.ZERO
	_canvas.size = Vector2(size)
	_material.set_shader_parameter("ground_size", Vector2(size))
	_material.set_shader_parameter("paved_top", PortLayout.TOP_MARGIN)
	_material.set_shader_parameter("paved_bottom", PortLayout.paved_bottom())
	_material.set_shader_parameter("yard_x0", PortLayout.YARD_X0)
	_material.set_shader_parameter("road_x0", PortLayout.ROAD_X0)
	_material.set_shader_parameter("road_x1", PortLayout.ROAD_X1)
	_material.set_shader_parameter("quay_x0", PortLayout.QUAY_X0)
	_material.set_shader_parameter("water_x0", PortLayout.WATER_X0)
	_material.set_shader_parameter("crane_rails", Vector2(
		PortLayout.QUAY_X0 + 8.0, PortLayout.QUAY_X0 + 28.0))
	var bottom := PortLayout.rail_corridor_bottom()
	_material.set_shader_parameter("rail_band",
		Vector2(bottom - PortLayout.RAIL_BAND_H, bottom))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return _viewport.get_texture()


func viewport() -> SubViewport:
	return _viewport
