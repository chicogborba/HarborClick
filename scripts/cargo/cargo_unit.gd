class_name CargoUnit
extends RefCounted
## A single traceable container.  Cargo is deliberately data first: the
## sprites in the yard and on the ship are only views of these units.

const IMPORT := &"IMPORT"
const EXPORT := &"EXPORT"

var uid: String
var sector: StringName = IMPORT
var color: int = 0
var origin_uid: String = ""
var call_id: String = ""


func _init(p_uid: String = "", p_sector: StringName = IMPORT,
		p_color: int = 0, p_origin_uid: String = "", p_call_id: String = "") -> void:
	uid = p_uid if not p_uid.is_empty() else new_uid()
	sector = p_sector
	color = posmod(p_color, 8)
	origin_uid = p_origin_uid
	call_id = p_call_id


static func new_uid(prefix: String = "ctr") -> String:
	return "%s_%s_%s" % [prefix, Time.get_ticks_usec(), randi()]


func can_export_for(import_uid: String) -> bool:
	return sector == EXPORT and uid != import_uid and origin_uid != import_uid


func snapshot() -> Dictionary:
	return {"uid": uid, "sector": String(sector), "color": color,
		"origin_uid": origin_uid, "call_id": call_id}


static func from_snapshot(data: Dictionary) -> CargoUnit:
	return CargoUnit.new(str(data.get("uid", "")), StringName(data.get("sector", IMPORT)),
		int(data.get("color", 0)), str(data.get("origin_uid", "")),
		str(data.get("call_id", "")))
