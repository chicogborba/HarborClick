extends SceneTree
## Usage: Godot --headless --path . -s res://tools/balance/run_balance.gd -- [scenario] [--json]

const EconomySimulator = preload("res://scripts/economy/economy_simulator.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var json := args.has("--json")
	var requested: Array[StringName] = []
	for arg in args:
		if arg != "--json":
			requested.append(StringName(arg))
	if requested.is_empty() or requested.has(&"all"):
		requested.assign(EconomySimulator.scenario_names())
	var results: Array[Dictionary] = []
	for name in requested:
		if not EconomySimulator.scenario_names().has(name):
			push_error("Unknown scenario: %s" % name)
			quit(2)
			return
		results.append(EconomySimulator.run_scenario(name))
	if json:
		print(JSON.stringify({"scenarios": results}, "  "))
	else:
		for result in results:
			_print_result(result)
	quit(0)


func _print_result(result: Dictionary) -> void:
	var m: Dictionary = result.markers
	print("%s | %0.0fs | productive=%0.3f | cps=%0.3f | owned=%d | prestige=%d" % [
		result.scenario, result.elapsed_seconds, result.all_time_productive,
		result.production_per_second, result.total_owned, result.prestige_potential,
	])
	print("  reward=%0.2fs passive=%0.2fs choice=%0.2fs three=%0.2fs prestige=%0.2fs purchases=%d" % [
		float(m.first_reward), float(m.first_passive), float(m.first_choice),
		float(m.three_owned), float(m.first_prestige), result.purchases.size(),
	])
