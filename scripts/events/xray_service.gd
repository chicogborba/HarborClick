class_name XrayService
extends Node
## The scanner as a live node: owns one `XrayPolicy`, persists it as the
## `xray_scanner` save section, runs its clock while the port is playable, and
## is the only place a purchase or a Benefício Fiscal touches the economy.

signal state_changed
signal inspection_ready
signal benefit_granted(benefit: Dictionary)

const SECTION_ID := &"xray_scanner"

var policy := XrayPolicy.new()
## Main says when the clock may run: after the tour, with no board open.
var can_run: Callable = Callable()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	SaveManager.register_section(SECTION_ID, policy.snapshot, _restore, _seed_new)


func _exit_tree() -> void:
	SaveManager.unregister_section(SECTION_ID)


func _process(delta: float) -> void:
	var running: bool = bool(can_run.call()) if can_run.is_valid() else true
	if policy.tick(delta, running, _rng):
		inspection_ready.emit()
		state_changed.emit()
		SaveManager.request_save(&"xray")


func owned() -> bool:
	return policy.owned


func is_due() -> bool:
	return policy.ready


func price() -> float:
	return policy.price(GameState.base_cps)


func on_site() -> bool:
	## The abandoned post comes with the second parcel: until that ground is
	## paved there is nothing to repair.
	return GameState.land.has(LandDB.SCANNER_PARCEL)


func can_buy() -> bool:
	return not policy.owned and on_site() and GameState.can_afford(price())


func buy() -> bool:
	if policy.owned or not on_site() or not GameState.spend(price()):
		return false
	policy.buy()
	Telemetry.track(&"xray_bought", {})
	state_changed.emit()
	SaveManager.request_save(&"xray")
	return true


func make_offer() -> Dictionary:
	## What the minigame board is opened with.
	return {"title": Loc.t("xray.title"), "game": &"xray",
		"seed": policy.scan_seed(), "level": policy.level(),
		"scan_no": policy.played + 1}


func resolve(cleared: bool, summary: Dictionary) -> Dictionary:
	var benefit := policy.resolve(cleared, int(summary.get("mistakes", 0)))
	if StringName(benefit.get("kind", &"")) == &"surge":
		GameState.grant_surge(float(benefit.mult), float(benefit.seconds))
		benefit_granted.emit(benefit)
	Telemetry.track(&"xray_result", {"won": cleared,
		"mistakes": int(summary.get("mistakes", 0))})
	state_changed.emit()
	SaveManager.request_save(&"xray")
	return benefit


func _restore(data: Dictionary) -> void:
	policy.restore(data)
	state_changed.emit()


func _seed_new() -> void:
	policy.restore(XrayPolicy.seed_new())
	state_changed.emit()
