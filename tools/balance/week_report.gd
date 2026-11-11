extends SceneTree
## When does a week-long player first own each thing?
##
##   Godot --headless --path . -s res://tools/balance/week_report.gd -- casual_week
##
## Prints the day (and hour) each machine and parcel is first bought, how many
## upgrades are owned at the end of each day, production per day and resets.
## This is the pacing check behind "most of the catalogue opens in a week".

const EconomySimulator = preload("res://scripts/economy/economy_simulator.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scenarios: Array = args if not args.is_empty() else ["casual_week", "engaged_week"]
	for name in scenarios:
		_report(EconomySimulator.run_scenario(StringName(name)))
	quit(0)


static func _when(seconds: float) -> String:
	if seconds < 0.0:
		return "never"
	return "d%d %02dh" % [int(seconds / 86400.0) + 1, int(fmod(seconds, 86400.0) / 3600.0)]


func _report(result: Dictionary) -> void:
	print("== %s  cps=%s  resets=%d  level=%d  upgrades_now=%d" % [result.scenario,
		String.num_scientific(result.production_per_second), result.prestige_count, result.prestige_level,
		result.upgrades.size()])
	var first := {}
	var upgrades_by_day := {}
	var seen_upgrades := {}
	for p: Dictionary in result.purchases:
		var key := "%s:%s" % [p.kind, p.id]
		if not first.has(key):
			first[key] = float(p.at)
		if String(p.kind) == "upgrade" and not seen_upgrades.has(p.id):
			seen_upgrades[p.id] = true
			var day := int(float(p.at) / 86400.0) + 1
			upgrades_by_day[day] = int(upgrades_by_day.get(day, 0)) + 1
	for item in StructureDB.ITEMS:
		print("  machine %-14s %s" % [item.id, _when(float(first.get("structure:" + item.id, -1.0)))])
	for parcel in LandDB.ITEMS:
		print("  land    %-14s %s" % [parcel.id, _when(float(first.get("land:" + parcel.id, -1.0)))])
	var total := 0
	for day in range(1, 8):
		total += int(upgrades_by_day.get(day, 0))
		print("  upgrades distinct by end of day %d: %d / %d" % [day, total, UpgradeDB.ITEMS.size()])
	for run: Dictionary in result.runs:
		print("  reset at %s  gain=%d  peak=%s" % [_when(float(run.ended_at)), int(run.gain),
			String.num_scientific(float(run.peak_production))])
