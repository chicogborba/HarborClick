class_name CargoInventory
extends RefCounted
## Small ownership ledger used by yards, ships and offline saves.

var _units: Dictionary = {} # uid -> CargoUnit
var _reservations: Dictionary = {} # token -> uid


func add(unit: CargoUnit) -> bool:
	if unit == null or unit.uid.is_empty() or _units.has(unit.uid):
		return false
	_units[unit.uid] = unit
	return true


func get_unit(uid: String) -> CargoUnit:
	return _units.get(uid) as CargoUnit


func has(uid: String) -> bool:
	return _units.has(uid)


func count(sector: StringName = &"") -> int:
	if sector == &"":
		return _units.size()
	var total := 0
	for unit: CargoUnit in _units.values():
		if unit.sector == sector:
			total += 1
	return total


func reserve(uid: String, token: String) -> bool:
	if not has(uid) or token.is_empty() or _reservations.has(token):
		return false
	for claimed: String in _reservations.values():
		if claimed == uid:
			return false
	_reservations[token] = uid
	return true


func release(token: String) -> CargoUnit:
	var uid := str(_reservations.get(token, ""))
	_reservations.erase(token)
	return get_unit(uid)


func remove_reserved(token: String) -> CargoUnit:
	var unit := release(token)
	if unit != null:
		_units.erase(unit.uid)
	return unit


func remove(uid: String) -> CargoUnit:
	for token: String in _reservations.keys():
		if _reservations[token] == uid:
			_reservations.erase(token)
	var unit := get_unit(uid)
	_units.erase(uid)
	return unit


func clear() -> void:
	_units.clear()
	_reservations.clear()


func snapshot() -> Array:
	var out: Array = []
	for unit: CargoUnit in _units.values():
		out.append(unit.snapshot())
	return out


func restore(data: Array) -> void:
	clear()
	for raw in data:
		if raw is Dictionary:
			add(CargoUnit.from_snapshot(raw))
