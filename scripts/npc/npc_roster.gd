class_name NpcRoster
extends RefCounted
## The terminal's payroll: who holds each station slot, since when.
##
## Actors are disposable — `StructureLayer` rebuilds every visible machine when a
## parcel is bought, on prestige and on restore — so the person cannot live on
## the sprite. A slot key (`"sts#0"`, `"estivador#1"`) is stable across all of
## that, and the roster maps it to one persistent `NpcProfile`.
##
## The roster is small on purpose. Only the roles in `NpcCatalog.ROLES` are
## staffed, and each of those is one link in the container chain, so the crew
## grows by a handful of named people rather than by a crowd.

signal hired(profile: NpcProfile)

var _profiles: Dictionary = {}      # slot key -> NpcProfile
var _order: Array[String] = []      # hire order, for a readable crew list
var _used_names: Dictionary = {}    # display name -> true
var _used_first_names: Dictionary = {}


func slot_key(role: String, index: int) -> String:
	return "%s#%d" % [role, maxi(0, index)]


func profile_for(role: String, index: int) -> NpcProfile:
	## The person at this station, hired on the spot the first time it is asked
	## for. Roles that are infrastructure rather than people return null, and
	## callers treat that as "this thing has no dossier".
	if not NpcCatalog.has_crew(role):
		return null
	var key := slot_key(role, index)
	var existing: NpcProfile = _profiles.get(key)
	if existing != null:
		return existing
	var profile := _hire(role, maxi(0, index), key)
	_profiles[key] = profile
	_order.append(key)
	hired.emit(profile)
	return profile


func find(key: String) -> NpcProfile:
	return _profiles.get(key)


func all() -> Array[NpcProfile]:
	var crew: Array[NpcProfile] = []
	for key in _order:
		var profile: NpcProfile = _profiles.get(key)
		if profile != null:
			crew.append(profile)
	return crew


func size() -> int:
	return _profiles.size()


func record_move(profile: NpcProfile, count: int = 1) -> void:
	## A completed task, on this person's tally. Deliberately not a save trigger:
	## the counter is flavour, and a box lands often enough that saving on each
	## one would be the busiest writer in the game. It rides along on the next
	## save like everything else in this section.
	if profile != null:
		profile.moves += maxi(0, count)


func _hire(role: String, index: int, key: String) -> NpcProfile:
	var profile := NpcProfile.new()
	profile.uid = CargoUnit.new_uid("crew")
	profile.slot = key
	profile.role = role
	profile.joined_day = TimeManager.day
	profile.joined_unix = int(Time.get_unix_time_from_system())
	var special := NpcCatalog.special_for(role, index)
	if special.is_empty():
		profile.display_name = _fresh_name()
		profile.dossier = NpcCatalog.background_for(
			NpcCatalog.station_of(role), index + _profiles.size())
	else:
		profile.special_id = StringName(special.id)
		profile.display_name = str(special.name)
		profile.dossier = str(special.dossier)
		profile.trait_line = str(special.get("trait", ""))
		var hat := str(special.get("hat", ""))
		if hat.begins_with("#") and Color.html_is_valid(hat):
			profile.hat_color = Color(hat)
	_used_names[profile.display_name] = true
	return profile


func _fresh_name() -> String:
	## Two people with the same name on one shift is a bug report, not flavour.
	##
	## The first pass also holds out for an unused *first* name: full names were
	## unique from the start, but a crew of three Rejanes still read as a random
	## table rather than as a crew.
	for attempt in 40:
		var given: String = NpcCatalog.FIRST_NAMES[
			randi() % NpcCatalog.FIRST_NAMES.size()]
		var candidate := "%s %s" % [given,
			NpcCatalog.SURNAMES[randi() % NpcCatalog.SURNAMES.size()]]
		if _used_names.has(candidate):
			continue
		if attempt < 24 and _used_first_names.has(given):
			continue
		_used_first_names[given] = true
		return candidate
	# The pools cross to 400 combinations; exhausting them means something is
	# hiring in a loop, and a numbered name is a visible symptom rather than a
	# silent duplicate.
	return "%s %s %d" % [
		NpcCatalog.FIRST_NAMES[randi() % NpcCatalog.FIRST_NAMES.size()],
		NpcCatalog.SURNAMES[randi() % NpcCatalog.SURNAMES.size()],
		_profiles.size() + 1]


# ---------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	var crew: Array = []
	for key in _order:
		var profile: NpcProfile = _profiles.get(key)
		if profile != null:
			crew.append(profile.snapshot())
	return {"version": 1, "crew": crew}


func restore(data: Dictionary) -> void:
	_clear()
	for raw in data.get("crew", []):
		if not raw is Dictionary:
			continue
		var profile := NpcProfile.from_snapshot(raw)
		if profile.slot.is_empty() or not NpcCatalog.has_crew(profile.role):
			continue
		if _profiles.has(profile.slot):
			continue
		_profiles[profile.slot] = profile
		_order.append(profile.slot)
		_used_names[profile.display_name] = true
		_used_first_names[profile.display_name.split(" ")[0]] = true


func seed_new() -> void:
	## A new terminal has nobody yet. The crew is hired as the stations that
	## need them come into existence, which is also how the dates end up
	## meaning something.
	_clear()


func _clear() -> void:
	_profiles.clear()
	_order.clear()
	_used_names.clear()
	_used_first_names.clear()
