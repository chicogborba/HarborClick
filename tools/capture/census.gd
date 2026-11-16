extends "res://tools/capture/perf.gd"
## The perf stress scene, counted instead of timed: which subtrees hold the
## nodes, and which of them run `_process` every frame. Runs headless.
##
##   godot --headless --path . tools/capture/census.tscn


func _ready() -> void:
	SaveManager.set_save_path_for_tests("user://capture/harborclick_census.json")
	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	await _build_stress()
	await get_tree().create_timer(1.0).timeout
	var by_branch := {}
	var processing := {}
	var timed := {}
	_walk(_main, "", by_branch, processing)
	var rows := []
	for key in by_branch:
		rows.append([by_branch[key], processing.get(key, 0), key])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for row in rows.slice(0, 24):
		print("[census] %6d nodes  %5d processing  %s" % row)
	# Per-script cost of one `_process`, the expensive ones only.
	var scripts := {}
	_time_scripts(_main, scripts)
	var cost := []
	for key in scripts:
		cost.append([scripts[key][0], scripts[key][1], key])
	cost.sort_custom(func(a, b): return a[0] > b[0])
	for row in cost.slice(0, 16):
		print("[census] %8.3f ms/frame  x%-4d %s" % row)
	var world: PortWorld = _main.world
	var parts := {
		"water+wakes": func() -> void: world._feed_water_shader(1.0 / 60.0),
		"cranes": func() -> void: world._allocate_cranes(),
		"berths": func() -> void:
			for c in world.berths: c.tick(1.0 / 60.0),
		"specials": func() -> void: if world.specials: world.specials.tick(1.0 / 60.0),
		"gate": func() -> void: if world.gate: world.gate.tick(1.0 / 60.0),
		"rail": func() -> void: if world.rail: world.rail.tick(1.0 / 60.0),
		"arrivals": func() -> void: world._drive_arrivals(1.0 / 60.0),
		"outlines (8 Hz)": func() -> void: world._refresh_interaction_outlines(),
	}
	for key in parts:
		var t0 := Time.get_ticks_usec()
		for i in 20:
			parts[key].call()
		print("[census] world %-16s %.3f ms" % [key, float(Time.get_ticks_usec() - t0) / 20000.0])
	get_tree().quit(0)


func _walk(node: Node, branch: String, by_branch: Dictionary, processing: Dictionary) -> void:
	for child in node.get_children():
		var key := branch
		if branch.count("/") < 2:
			key = "%s/%s" % [branch, child.name]
		by_branch[key] = int(by_branch.get(key, 0)) + 1
		if child.is_processing():
			processing[key] = int(processing.get(key, 0)) + 1
		_walk(child, key, by_branch, processing)


func _time_scripts(node: Node, scripts: Dictionary) -> void:
	for child in node.get_children():
		var script: Script = child.get_script()
		if script != null and child.is_processing() and child.has_method("_process") \
				and child != self:
			var t0 := Time.get_ticks_usec()
			for i in 5:
				child._process(1.0 / 60.0)
			var ms := float(Time.get_ticks_usec() - t0) / 5000.0
			var key := script.resource_path.get_file()
			var entry: Array = scripts.get(key, [0.0, 0])
			entry[0] += ms
			entry[1] += 1
			scripts[key] = entry
		_time_scripts(child, scripts)
