extends Node
## Throwaway: capture the Title scene at a given size.
## godot --path . tools/capture/titleshot.tscn -- 320x568

var _size := Vector2i(320, 568)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and "x" in args[0]:
		var parts := args[0].split("x")
		_size = Vector2i(int(parts[0]), int(parts[1]))
	get_window().size = _size
	await get_tree().process_frame
	await get_tree().process_frame
	var title: Control = load("res://scenes/Title.tscn").instantiate()
	add_child(title)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://uishots/title_%dx%d.png" % [_size.x, _size.y])
	print("[titleshot] title_%dx%d" % [_size.x, _size.y])
	get_tree().quit(0)
