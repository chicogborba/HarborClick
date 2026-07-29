extends Node
## Core economy state: TEUs (currency), structures, upgrades, CPS.

var teus: float = 0.0
var lifetime_teus: float = 0.0
var owned: Dictionary = {}      # structure id -> count
var upgrades: Dictionary = {}   # upgrade id -> true
var land: Dictionary = {}       # parcel id -> true
var cps: float = 0.0
var click_power: float = 1.0
var shares: int = 0              # prestige currency
var boost_time: float = 0.0      # remaining seconds of the cat boost
var flags: Dictionary = {}       # tutorial_done, seen milestones, ...

const MILESTONES := [
	{"teus": 100.0, "text": "100 TEUs! O porto saiu do papel."},
	{"teus": 1e4, "text": "10 mil TEUs. A alfândega já sabe teu nome."},
	{"teus": 1e6, "text": "1 milhão de TEUs. Isso vira notícia local."},
	{"teus": 1e9, "text": "1 bilhão de TEUs. O oceano pediu pausa."},
	{"teus": 1e12, "text": "1 trilhão. Contadores do mundo inteiro choram."},
	{"teus": 1e15, "text": "1 quatrilhão. Ninguém sabe mais o que é um container."},
]

const CRIT_CHANCE := 0.03
const CRIT_MULT := 7.0
const CAT_BOOST_MULT := 7.0
const CAT_BOOST_TIME := 25.0
const PRESTIGE_DIVISOR := 1e12   # lifetime TEUs per golden share
const SHARE_BONUS := 0.02        # +2% to everything per share

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


func _ready() -> void:
	recompute()


func _process(delta: float) -> void:
	if boost_time > 0.0:
		boost_time = maxf(0.0, boost_time - delta)
		if boost_time == 0.0:
			recompute()
	if cps > 0.0:
		_earn(cps * delta)


func grant_cat_boost() -> void:
	boost_time = CAT_BOOST_TIME
	recompute()


func prestige_gain() -> int:
	## Shares the player would earn by resetting right now.
	return int(sqrt(maxf(0.0, lifetime_teus) / PRESTIGE_DIVISOR))


func can_prestige() -> bool:
	return prestige_gain() > shares


func do_prestige() -> bool:
	var gain := prestige_gain()
	if gain <= shares:
		return false
	shares = gain
	teus = 0.0
	lifetime_teus = 0.0
	owned.clear()
	upgrades.clear()
	boost_time = 0.0
	recompute()
	EventBus.teus_changed.emit(teus)
	EventBus.prestiged.emit(shares)
	return true


func do_click(world_pos: Vector2) -> void:
	var crit := randf() < CRIT_CHANCE
	var value := click_power * (CRIT_MULT if crit else 1.0)
	_earn(value)
	EventBus.container_unloaded.emit(world_pos, value, crit)


func _earn(amount: float) -> void:
	teus += amount
	lifetime_teus += amount
	EventBus.teus_changed.emit(teus)
	_check_milestones()


func _check_milestones() -> void:
	var seen: Array = flags.get("milestones", [])
	for i in MILESTONES.size():
		if lifetime_teus >= MILESTONES[i].teus and not seen.has(i):
			seen.append(i)
			flags["milestones"] = seen
			EventBus.toast.emit(MILESTONES[i].text)
			AudioManager.play_sfx("milestone")
			return


func can_afford(cost: float) -> bool:
	return teus >= cost


func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	teus -= cost
	EventBus.teus_changed.emit(teus)
	return true


func structure_count(id: String) -> int:
	return owned.get(id, 0)


func structure_cost(id: String) -> float:
	return StructureDB.cost_for(id, structure_count(id))


func buy_structure(id: String) -> bool:
	if not spend(structure_cost(id)):
		return false
	owned[id] = structure_count(id) + 1
	recompute()
	EventBus.structure_bought.emit(id, owned[id])
	return true


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


func buy_upgrade(id: String) -> bool:
	var item := UpgradeDB.get_item(id)
	if item.is_empty() or has_upgrade(id):
		return false
	if not spend(item.cost):
		return false
	upgrades[id] = true
	recompute()
	EventBus.upgrade_bought.emit(id)
	return true


func upgrade_unlocked(item: Dictionary) -> bool:
	var unlock: Dictionary = item.get("unlock", {})
	if unlock.has("teus") and lifetime_teus < unlock.teus:
		return false
	if unlock.has("owned"):
		for sid: String in unlock.owned:
			if structure_count(sid) < unlock.owned[sid]:
				return false
	return true


func structure_cps(id: String) -> float:
	## Effective CPS of one unit of the structure, upgrades applied.
	var item := StructureDB.get_item(id)
	if item.is_empty():
		return 0.0
	var value: float = item.cps
	for uid: String in upgrades:
		var up := UpgradeDB.get_item(uid)
		if up.get("kind") == "structure_mult" and up.get("target") == id:
			value *= up.value
	return value


func recompute() -> void:
	var total := 0.0
	for id: String in owned:
		total += structure_cps(id) * owned[id]
	var global_mult := 1.0
	var click_mult := 1.0
	var click_cps_pct := 0.0
	for uid: String in upgrades:
		var up := UpgradeDB.get_item(uid)
		match up.get("kind"):
			"global_mult":
				global_mult *= up.value
			"click_mult":
				click_mult *= up.value
			"click_cps_pct":
				click_cps_pct += up.value
	var share_mult := 1.0 + shares * SHARE_BONUS
	cps = total * global_mult * share_mult * TimeManager.weather_cps_mult()
	click_power = ((1.0 * click_mult) + cps * click_cps_pct) * share_mult
	if boost_time > 0.0:
		click_power *= CAT_BOOST_MULT
	EventBus.cps_changed.emit(cps)


func fmt(n: float) -> String:
	## 1234 -> "1.23K"; integers below 1000 stay plain.
	if n < 1000.0:
		return str(int(n)) if absf(n - roundf(n)) < 0.05 or n >= 100.0 else "%.1f" % n
	var tier := 0
	while n >= 1000.0 and tier < SUFFIXES.size() - 1:
		n /= 1000.0
		tier += 1
	if n >= 100.0:
		return "%.0f%s" % [n, SUFFIXES[tier]]
	elif n >= 10.0:
		return "%.1f%s" % [n, SUFFIXES[tier]]
	return "%.2f%s" % [n, SUFFIXES[tier]]


func to_save() -> Dictionary:
	return {
		"teus": teus, "lifetime": lifetime_teus, "shares": shares,
		"owned": owned, "upgrades": upgrades.keys(), "land": land.keys(),
		"flags": flags,
	}


func from_save(data: Dictionary) -> void:
	teus = data.get("teus", 0.0)
	lifetime_teus = data.get("lifetime", 0.0)
	shares = int(data.get("shares", 0))
	flags = data.get("flags", {})
	owned = data.get("owned", {})
	upgrades.clear()
	for uid in data.get("upgrades", []):
		upgrades[uid] = true
	land.clear()
	for lid in data.get("land", []):
		land[lid] = true
	recompute()
	EventBus.teus_changed.emit(teus)
