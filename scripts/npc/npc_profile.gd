class_name NpcProfile
extends RefCounted
## One person on the terminal's books.
##
## A profile outlives the actor that shows it: equipment is rebuilt on every land
## purchase, prestige and restore, and the operator is still the same operator
## afterwards. The identity therefore lives in `NpcRoster`, keyed by station
## slot, and the sprite only borrows it.

var uid := ""
var slot := ""                          # roster key, "<role>#<index>"
var role := ""
var display_name := ""
var special_id: StringName = &""
## Transparent means the standard yellow hard hat the sprite is drawn with.
var hat_color := Color(0.0, 0.0, 0.0, 0.0)
var joined_day := 1                     # the port's own calendar
var joined_unix := 0                    # wall clock, for "entrou em 30/07/2026"
var moves := 0
var dossier := ""
var trait_line := ""


func title() -> String:
	return NpcCatalog.title_of(role)


func station() -> StringName:
	return NpcCatalog.station_of(role)


func duty() -> String:
	return NpcCatalog.duty_of(role)


func is_special() -> bool:
	return special_id != &""


func wears_special_hat() -> bool:
	return hat_color.a > 0.0


func joined_text() -> String:
	## Both clocks, because both are true and the player only has one of them in
	## their head: the day of the run, and the day they actually hired the person.
	## The separator is a bullet because the game's bitmap font has one; it has no
	## middle dot and no em dash, and a missing glyph prints as an empty box.
	var stamp := "Dia %d" % joined_day
	if joined_unix > 0:
		var date := Time.get_datetime_dict_from_unix_time(joined_unix)
		stamp += " • %02d/%02d/%04d" % [int(date.day), int(date.month), int(date.year)]
	return stamp


func snapshot() -> Dictionary:
	return {
		"uid": uid, "slot": slot, "role": role, "name": display_name,
		"special": String(special_id), "hat": "#" + hat_color.to_html(true),
		"joined_day": joined_day, "joined_unix": joined_unix, "moves": moves,
		"dossier": dossier, "trait": trait_line,
	}


static func from_snapshot(data: Dictionary) -> NpcProfile:
	var profile := NpcProfile.new()
	profile.uid = str(data.get("uid", ""))
	profile.slot = str(data.get("slot", ""))
	profile.role = str(data.get("role", ""))
	profile.display_name = str(data.get("name", ""))
	profile.special_id = StringName(data.get("special", ""))
	var hat := str(data.get("hat", ""))
	profile.hat_color = Color(hat) if hat.begins_with("#") and Color.html_is_valid(hat) \
		else Color(0.0, 0.0, 0.0, 0.0)
	profile.joined_day = maxi(1, int(data.get("joined_day", 1)))
	profile.joined_unix = maxi(0, int(data.get("joined_unix", 0)))
	profile.moves = maxi(0, int(data.get("moves", 0)))
	profile.dossier = str(data.get("dossier", ""))
	profile.trait_line = str(data.get("trait", ""))
	return profile
