extends Node
## The harbour water on its own, for tuning the shader at the pixel.
##
##   godot --path . tools/capture/water_lab.tscn -- [port_id] [seconds]
##
## Lays a moored hull, a hull under way with a fresh track behind it and a tug
## track on a strip of sea the size of the real one, waits, and writes
## `user://uishots/water_lab.png` at 4x. Much faster than booting Main.

const SHOT_DIR := "user://uishots"


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if args.size() > 0 and not String(args[0]).is_valid_float():
		PortDB.set_active(StringName(args[0]))
		args.remove_at(0)
	var wait := float(args[0]) if args.size() > 0 else 2.0
	DisplayServer.window_set_size(Vector2i(480, 900))
	var water := WaterSurface.new()
	var width := PortLayout.WORLD_W - PortLayout.WATER_X0 + 12.0
	water.position = Vector2(PortLayout.WATER_X0 - 12.0, 0.0)
	water.size = Vector2(width, 520.0)
	water.set_shader(load("res://assets/shaders/water_top.gdshader"))
	add_child(water)
	var mat := water.water_material
	mat.set_shader_parameter("world_offset", water.position)
	mat.set_shader_parameter("shore_x", PortLayout.WATER_X0)
	mat.set_shader_parameter("water_span", PortLayout.WORLD_W - PortLayout.WATER_X0)
	mat.set_shader_parameter("quality_level", 0 if args.has("low") else 2)
	var sea := PortDB.water_colors()
	if sea.size() == 4:
		for i in 4:
			mat.set_shader_parameter(["col_shallow", "col_mid", "col_deep", "col_abyss"][i], sea[i])
	# A moored hull alongside, and one making way up the fairway.
	var moored := Vector2(PortLayout.SHIP_X + PortLayout.SHIP_W * 0.5, 120.0)
	var moving := Vector2(PortLayout.FAIRWAY_X + PortLayout.SHIP_W * 0.5, 300.0)
	var hulls := PackedVector4Array([
		Vector4(moored.x, moored.y, PortLayout.SHIP_W * 0.5, 90.0),
		Vector4(moving.x, moving.y, PortLayout.SHIP_W * 0.5, 70.0),
		Vector4(-9999, -9999, 1, 1)])
	mat.set_shader_parameter("hulls", hulls)
	mat.set_shader_parameter("hull_count", 2)
	mat.set_shader_parameter("ship_centre", moving)
	mat.set_shader_parameter("ship_half", Vector2(PortLayout.SHIP_W * 0.5, 70.0))
	mat.set_shader_parameter("ship_speed", 1.0)
	mat.set_shader_parameter("rain", 1.0 if args.has("rain") else 0.0)
	mat.set_shader_parameter("chop", 0.6 if args.has("rain") else 0.0)
	var wakes := WaterWakes.new()
	# Feed a track as if the hull had steamed up from below at 70 px/s.
	var stern_y := 300.0 + 64.0 + 160.0
	var t := 0.0
	while stern_y > 300.0 + 64.0:
		wakes.feed(&"ship", Vector2(moving.x, stern_y), PortLayout.SHIP_W * 0.24, 1.0)
		wakes.tick(1.0 / 30.0)
		stern_y -= 70.0 / 30.0
		t += 1.0 / 30.0
	var tug := Vector2(PortLayout.WORLD_W - 18.0, 500.0)
	for i in 90:
		wakes.feed(&"tug", tug, 2.5, 1.0, 7.0, 4.5)
		wakes.tick(1.0 / 30.0)
		tug += Vector2(-0.25, -1.5)
	var packed := wakes.pack(Vector2.ZERO)
	mat.set_shader_parameter("trail_count", packed.size())
	while packed.size() < WaterWakes.MAX_POINTS:
		packed.append(Vector4(-9999, -9999, 99, -1))
	mat.set_shader_parameter("trail", packed)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var image := water.viewport().get_texture().get_image()
	image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	image.save_png(SHOT_DIR + "/water_lab.png")
	print("[water_lab] ", image.get_size(), " trail points ", wakes.point_count())
	get_tree().quit(0)
