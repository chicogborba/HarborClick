extends Node
## Run with: Godot --headless --path . res://tests/phase4_water_test_runner.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_quality_budget()
	await _test_foam_caps_and_assets()
	await _test_shader_contract()
	if failures.is_empty():
		print("PHASE 4 WATER TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)


func _test_quality_budget() -> void:
	_expect(WaterQuality.choose(Vector2(360, 800), false) == WaterQuality.Level.LOW, "narrow viewport selects low water quality")
	_expect(WaterQuality.choose(Vector2(800, 600), false) == WaterQuality.Level.MEDIUM, "mid desktop viewport selects medium water quality")
	_expect(WaterQuality.choose(Vector2(1200, 800), false) == WaterQuality.Level.HIGH, "wide desktop viewport selects high water quality")
	_expect(WaterQuality.choose(Vector2(1200, 800), true) == WaterQuality.Level.LOW, "mobile device always selects low quality")


func _test_foam_caps_and_assets() -> void:
	var foam := WaterFoam.new()
	add_child(foam)
	foam.setup(WaterQuality.Level.LOW, 900.0)
	await get_tree().process_frame
	_expect(foam.foam_count() <= WaterFoam.MAX_FOAM[WaterQuality.Level.LOW], "low foam is capped")
	_expect(foam.splash_count() == 0, "low quality skips splash animation")
	foam.set_quality(WaterQuality.Level.HIGH)
	await get_tree().process_frame
	_expect(foam.foam_count() <= WaterFoam.MAX_FOAM[WaterQuality.Level.HIGH], "high foam remains capped")
	_expect(foam.splash_count() == 2, "high quality uses two existing splash animations")
	foam.queue_free()
	await get_tree().process_frame


func _test_shader_contract() -> void:
	var shader := load("res://assets/shaders/water_top.gdshader") as Shader
	_expect(shader != null, "top-down water shader loads")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("quality_level", WaterQuality.Level.HIGH)
	material.set_shader_parameter("shore_x", PortLayout.WATER_X0)
	_expect(int(material.get_shader_parameter("quality_level")) == WaterQuality.Level.HIGH, "shader exposes quality level")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var water := ColorRect.new()
	water.size = Vector2(96, 64)
	water.material = material
	viewport.add_child(water)
	await get_tree().process_frame
	viewport.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
