class_name SkillService
extends Node
## Applies what a skill does, and keeps the recharge clocks as a save section.
##
##  - Turno Extra: a x2 skill bonus on everything for 30 s (the skill slot, which
##    multiplies with a luck surge instead of being replaced by it).
##  - Mutirão: for 10 s the combo is pinned at its top step and the crew works
##    the ship for you, ten taps a second through the real tap path.
##  - Prático a Bordo: the next completed call pays its departure bonus x3.
##
## Meta progress: survives a prestige like the wheel's tokens.

signal state_changed
signal activated(id: StringName)

const SECTION_ID := &"skills"

var book: SkillBook
## Set by Main: the callable that works the ship once (the berth's own tap).
var tap_ship := Callable()
var _auto_left := 0.0
var _auto_carry := 0.0


func _ready() -> void:
	book = SkillBook.new()
	SaveManager.register_section(SECTION_ID, book.snapshot, _restore, _seed_new)


func _exit_tree() -> void:
	SaveManager.unregister_section(SECTION_ID)


func now() -> float:
	return Time.get_unix_time_from_system()


func unlocked(id: StringName) -> bool:
	var skill := SkillBook.get_skill(id)
	return not skill.is_empty() and FeatureGate.unlocked(StringName(skill.feature))


func activate(id: StringName) -> bool:
	if not unlocked(id) or not book.use(id, now()):
		return false
	var skill := SkillBook.get_skill(id)
	match id:
		&"skill_overtime":
			GameState.grant_skill(float(skill.mult), float(skill.seconds))
		&"skill_mutirao":
			GameState.combo.pin(GameState.combo_now(), float(skill.seconds))
			_auto_left = float(skill.seconds)
			_auto_carry = 0.0
		&"skill_pilot":
			GameState.pilot_pending = float(skill.bonus_mult)
	AudioManager.play_sfx("skill", 0.02, -2.0)
	Fx.haptic(24)
	activated.emit(id)
	state_changed.emit()
	return true


func mutirao_active() -> bool:
	return _auto_left > 0.0


func reset_cooldown(id: StringName) -> void:
	book.reset(id)
	state_changed.emit()


func _process(delta: float) -> void:
	if _auto_left <= 0.0:
		return
	_auto_left = maxf(0.0, _auto_left - delta)
	_auto_carry += delta * float(SkillBook.get_skill(&"skill_mutirao").taps_per_second)
	while _auto_carry >= 1.0:
		_auto_carry -= 1.0
		if tap_ship.is_valid():
			tap_ship.call()
	if _auto_left == 0.0:
		state_changed.emit()


func _restore(data: Dictionary) -> void:
	book.restore(data)
	state_changed.emit()


func _seed_new() -> void:
	book.restore(SkillBook.seed_new())
	state_changed.emit()
