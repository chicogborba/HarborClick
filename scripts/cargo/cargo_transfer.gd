class_name CargoTransfer
extends RefCounted
## One reversible movement.  Commit occurs only when the visual flight lands;
## freeing/cancelling a flight can therefore never duplicate or lose cargo.

enum State { PREPARED, COMMITTED, ROLLED_BACK }

var id: String = CargoUnit.new_uid("move")
var unit: CargoUnit
var state: State = State.PREPARED
var _commit: Callable
var _rollback: Callable


func _init(p_unit: CargoUnit = null, on_commit: Callable = Callable(),
		on_rollback: Callable = Callable()) -> void:
	unit = p_unit
	_commit = on_commit
	_rollback = on_rollback


func commit() -> bool:
	if state != State.PREPARED:
		return false
	var accepted := true
	if _commit.is_valid():
		accepted = bool(_commit.call(unit))
	if not accepted:
		rollback()
		return false
	state = State.COMMITTED
	return true


func rollback() -> bool:
	if state != State.PREPARED:
		return false
	state = State.ROLLED_BACK
	if _rollback.is_valid():
		_rollback.call(unit)
	return true
