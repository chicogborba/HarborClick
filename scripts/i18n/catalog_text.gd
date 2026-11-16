class_name CatalogText
## The catalogues' words, in the player's language.
##
## Every catalogue (`StructureDB`, `UpgradeDB`, `PortDB`, ...) is authored in
## Brazilian Portuguese, inline, next to the numbers it describes — that is the
## right place to *write* a line, and the wrong place to *read* one from on an
## English phone. The translations live in `LocStringsContent` under one key
## shape, `<domain>.<id>.<field>`:
##
##     upgrade.luvas.name      structure.rtg.desc     port.shanghai.tagline
##
## and this class writes them over the live catalogue rows in place. Doing it in
## place rather than at each read site is the point: forty-odd places read
## `item.name` or `item.get("desc")`, and every one of them is right the moment
## the row is, including the ones nobody remembered to grep for. The authored
## text survives where it always did — `RAW_ITEMS`, or the row itself until the
## first pass — and is what a row falls back to if a key is ever missing.
##
## `relocalize()` runs when `Loc` starts, on every language switch, and after
## `PortDB.set_active` rebuilds the paced tables. `tables()` is the one list of
## what is translated; `tests/i18n_test_runner.gd` walks it and fails on any
## catalogue text that has no key, so a new upgrade cannot ship in Portuguese
## only.
##
## Deliberately *not* here: `FleetDB` ship names ("Maré Alta", "Sakura Maru").
## A ship keeps its name in every language — the same rule `LocStringsContent`
## applies to places. A port's local machine and parcel names *are* keyed: most
## of them are half description ("Yangshan Fase I", "Armazém de Lingang"), and a
## pure proper noun ("Pier T") simply reads the same in every column.


## The text fields a row may carry. Only the ones a row actually has get a key.
const ROW_FIELDS: Array[String] = ["name", "short", "desc", "description",
	"title", "brief", "tagline", "perk", "country"]


## key -> the authored Portuguese, taken the first time a row is overwritten.
## The tables that are translated in place (`PortDB.PORTS`, `CosmeticDb.ITEMS`,
## ...) no longer hold their authored line after that, and `authored_rows()`
## must still report it.
static var _authored: Dictionary = {}


static func key(domain: String, id: String, field: String) -> String:
	return "%s.%s.%s" % [domain, id, field]


static func text(domain: String, id: String, field: String, fallback: String) -> String:
	## One lookup, for the few reads that are not a catalogue row (an NPC's
	## background, a fallback title).
	var k := key(domain, id, field)
	return Loc.t(k) if Loc.has(k) else fallback


static func tables() -> Array[Dictionary]:
	## `{domain, rows}` for every translated catalogue. `rows` is the *live*
	## array, so writing into it is what changes the screen.
	return [
		{"domain": "structure", "rows": StructureDB.ITEMS},
		{"domain": "land", "rows": LandDB.ITEMS},
		{"domain": "upgrade", "rows": UpgradeDB.ITEMS},
		{"domain": "upgrade_branch", "rows": _upgrade_branches()},
		{"domain": "port", "rows": PortDB.PORTS},
		{"domain": "cosmetic", "rows": CosmeticDb.ITEMS},
		{"domain": "achievement", "rows": AchievementDB.ITEMS},
		{"domain": "contract", "rows": ContractDB.TEMPLATES},
		{"domain": "prestige_branch", "rows": PrestigeDB.BRANCHES},
		{"domain": "prestige", "rows": _prestige_nodes()},
		{"domain": "special", "rows": SpecialCallDB.OFFERS},
		{"domain": "ship_class", "rows": ShipCatalog.SILHOUETTES},
	]


static func authored_rows() -> Array[Dictionary]:
	## `{key, text}` for every catalogue string the game can show, read from the
	## *authored* tables — the port's upgrades and local names included — so the
	## list does not depend on which port is active or which language the rows
	## currently hold. This is what the test checks keys against.
	var out: Array[Dictionary] = []
	var sources: Array[Dictionary] = [
		{"domain": "structure", "rows": StructureDB.RAW_ITEMS},
		{"domain": "land", "rows": LandDB.RAW_ITEMS},
		{"domain": "upgrade", "rows": _authored_upgrades()},
		{"domain": "upgrade_branch", "rows": _upgrade_branches()},
		{"domain": "port", "rows": PortDB.PORTS},
		{"domain": "cosmetic", "rows": CosmeticDb.ITEMS},
		{"domain": "achievement", "rows": AchievementDB.ITEMS},
		{"domain": "contract", "rows": ContractDB.TEMPLATES},
		{"domain": "prestige_branch", "rows": PrestigeDB.BRANCHES},
		{"domain": "prestige", "rows": _prestige_nodes()},
		{"domain": "special", "rows": SpecialCallDB.OFFERS},
		{"domain": "ship_class", "rows": ShipCatalog.SILHOUETTES},
	]
	for source in sources:
		for row: Dictionary in source.rows:
			for field in ROW_FIELDS:
				if not str(row.get(field, "")).is_empty():
					var k := key(source.domain, str(row.id), field)
					out.append({"key": k, "text": str(_authored.get(k, row[field]))})
	for port: Dictionary in PortDB.PORTS:
		var names: Dictionary = port.get("names", {})
		for id: String in names:
			var k := key("port", str(port.id), "names." + id)
			out.append({"key": k, "text": str(_authored.get(k, names[id]))})
	for alias: String in ShipCatalog.COMPATIBILITY_ALIASES:
		out.append({"key": key("ship_class", alias, "title"),
			"text": str(ShipCatalog.COMPATIBILITY_ALIASES[alias].title)})
	for role: String in NpcCatalog.ROLES:
		for field in ["title", "duty"]:
			out.append({"key": key("npc_role", role, field),
				"text": str(NpcCatalog.ROLES[role][field])})
	for special: Dictionary in NpcCatalog.SPECIALS:
		for field in ["dossier", "trait"]:
			if not str(special.get(field, "")).is_empty():
				out.append({"key": key("npc_special", String(special.id), field),
					"text": str(special[field])})
	for station: StringName in NpcCatalog.BACKGROUNDS:
		var pool: Array = NpcCatalog.BACKGROUNDS[station]
		for index in pool.size():
			out.append({"key": key("npc_background", String(station), str(index)),
				"text": str(pool[index])})
	out.append({"key": "npc_role.default.title", "text": NpcCatalog.DEFAULT_TITLE})
	out.append({"key": "npc_background.default.0", "text": NpcCatalog.DEFAULT_BACKGROUND})
	return out


static func relocalize() -> void:
	## Writes the current language over every live row. Cheap — a few hundred
	## dictionary writes — and idempotent, so callers never need to know whether
	## it already ran.
	for port: Dictionary in PortDB.PORTS:
		var names: Dictionary = port.get("names", {})
		for id: String in names.keys():
			var k := key("port", str(port.id), "names." + id)
			_write(names, id, k)
	for table in tables():
		var domain: String = table.domain
		for row: Dictionary in table.rows:
			var id := str(row.get("id", ""))
			for field in ROW_FIELDS:
				if not row.has(field):
					continue
				_write(row, field, key(domain, id, field))
	# A port renames some machines and parcels ("Longshoreman", "Pier T"); the
	# local name wins over the catalogue's, as it does in `apply_port`.
	for rows: Array[Dictionary] in [StructureDB.ITEMS, LandDB.ITEMS]:
		for row: Dictionary in rows:
			var local := PortDB.name_for(str(row.id), "")
			if not local.is_empty():
				row["name"] = local


static func _write(row: Dictionary, field: String, k: String) -> void:
	if not _authored.has(k):
		_authored[k] = row[field]
	if Loc.has(k):
		row[field] = Loc.t(k)


static func _prestige_nodes() -> Array[Dictionary]:
	## The live node rows (not copies), so a write reaches `PrestigeDB`.
	var out: Array[Dictionary] = []
	for branch: Dictionary in PrestigeDB.BRANCHES:
		for node: Dictionary in branch.get("nodes", []):
			out.append(node)
	return out


static func _upgrade_branches() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(UpgradeDB.BRANCHES)
	out.append(PortDB.BRANCH)
	return out


static func _authored_upgrades() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(UpgradeDB.RAW_ITEMS)
	for port: Dictionary in PortDB.PORTS:
		for item: Dictionary in port.get("upgrades", []):
			out.append(item)
	return out
