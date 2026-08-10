extends Node
## Which language the port speaks, and every string it says.
##
## The game was written in Brazilian Portuguese with the text inlined at the
## point of use, which is fine right up until someone opens it on a phone set to
## English. Strings live in `LocStrings*` tables now, keyed by a dotted id, and
## every screen asks for them through `Loc.t()`.
##
## Two rules the rest of the codebase depends on:
##
## * **The device decides by default.** A fresh install reads `OS.get_locale()`
##   and picks the closest language it has, so nobody has to find a menu before
##   the game is readable. Choosing one explicitly in the settings pins it, and
##   that choice is what gets saved — "follow the device" is itself a saveable
##   state, not the absence of one.
## * **A language switch is live.** `language_changed` fires and every open
##   panel re-reads its own labels. Requiring a restart to see the new language
##   would be a bug the player has no way to understand.
##
## Adding a language is a column in the tables plus, if it needs glyphs the
## pixel font does not have, an entry in `tools/sprites/gen_font.py`. Nothing
## here is loaded from disk: a translation table is code, so a missing key is a
## test failure rather than a silent blank label at runtime.

signal language_changed(code: StringName)

## The saved value that means "whatever the device is set to". Stored rather
## than inferred, because a player who picks Portuguese on an English phone and
## a player who has never opened the menu are not in the same state.
const FOLLOW_DEVICE := &"auto"

## Every language the game is actually translated into. `native` is what the
## picker shows: a language list written in the language you are looking for is
## the one list a person who cannot read the current one can still use.
const LANGUAGES: Array[Dictionary] = [
	{"code": &"pt_BR", "native": "Português", "tag": "PT"},
	{"code": &"en", "native": "English", "tag": "EN"},
	{"code": &"es", "native": "Español", "tag": "ES"},
	{"code": &"fr", "native": "Français", "tag": "FR"},
	{"code": &"de", "native": "Deutsch", "tag": "DE"},
	{"code": &"it", "native": "Italiano", "tag": "IT"},
	{"code": &"ru", "native": "Русский", "tag": "RU"},
	{"code": &"pl", "native": "Polski", "tag": "PL"},
	{"code": &"tr", "native": "Türkçe", "tag": "TR"},
]

## What an untranslated key falls back to. English rather than the original
## Portuguese: a player seeing a stray untranslated line is far more likely to
## read English than Brazilian Portuguese.
const FALLBACK := &"en"

## Device language prefix -> the language we serve it. `OS.get_locale_language()`
## returns the two-letter part only, so every regional Portuguese lands on the
## Brazilian table and every Spanish on the one Spanish table.
const DEVICE_MAP := {
	"pt": &"pt_BR",
	"en": &"en",
	"es": &"es",
	# Galician readers are served far better by Spanish than by English.
	"gl": &"es",
	"fr": &"fr",
	"de": &"de",
	"it": &"it",
	"ru": &"ru",
	"pl": &"pl",
	"tr": &"tr",
}

var language: StringName = FALLBACK
## What is saved: either a real code or `FOLLOW_DEVICE`.
var preference: StringName = FOLLOW_DEVICE

var _table: Dictionary = {}
var _missing: Dictionary = {}


func _ready() -> void:
	_build_table()
	# `Loc` is registered after `UserPreferences`, so the saved choice is already
	# on disk and in memory by now. Read it defensively anyway: a headless runner
	# that instantiates this script on its own has no preferences node at all,
	# and it should get the device language rather than a crash.
	var prefs := get_node_or_null(^"/root/UserPreferences")
	apply(StringName(prefs.language) if prefs != null else FOLLOW_DEVICE, false)


func _build_table() -> void:
	_table.clear()
	for source in [LocStringsUi.STRINGS, LocStringsContent.STRINGS]:
		for key: String in source:
			if _table.has(key):
				push_error("Duplicate translation key: %s" % key)
			_table[key] = source[key]


# ------------------------------------------------------------------- lookup

func t(key: String, params: Dictionary = {}) -> String:
	## The one call the rest of the game makes. `params` fills `{name}` slots, so
	## a language is free to put the number after the noun, or before it, or
	## nowhere — which `%s` ordering cannot express.
	var row: Dictionary = _table.get(key, {})
	if row.is_empty():
		_report_missing(key)
		return key
	var text := str(row.get(language, ""))
	if text.is_empty():
		text = str(row.get(FALLBACK, ""))
		if text.is_empty():
			_report_missing(key)
			return key
	if params.is_empty():
		return text
	return text.format(params, "{_}")


func tn(key: String, count: int, params: Dictionary = {}) -> String:
	## Plural forms. `key.one` for exactly one, `key.other` for everything else —
	## which is the rule all three languages here share. A language with a richer
	## plural system would need its own branch, and would say so by failing the
	## parity test rather than by quietly picking the wrong form.
	var merged := params.duplicate()
	merged["n"] = count
	return t("%s.%s" % [key, "one" if absi(count) == 1 else "other"], merged)


func has(key: String) -> bool:
	return _table.has(key)


func keys() -> Array:
	return _table.keys()


func _report_missing(key: String) -> void:
	## Loud once, silent after. A label that refreshes every frame would
	## otherwise turn one missing key into an unreadable console.
	if _missing.has(key):
		return
	_missing[key] = true
	push_warning("Missing translation for key: %s" % key)


# -------------------------------------------------------------------- choice

func apply(wanted: StringName, notify: bool = true) -> void:
	## `wanted` is either a language code or `FOLLOW_DEVICE`.
	preference = wanted if wanted == FOLLOW_DEVICE or is_supported(wanted) \
		else FOLLOW_DEVICE
	var resolved := device_language() if preference == FOLLOW_DEVICE \
		else preference
	if resolved == language and not notify:
		return
	language = resolved
	# Keeps engine-side locale-dependent behaviour in step with ours. Nothing in
	# the game reads it today; a mismatch would be a trap for whatever does next.
	TranslationServer.set_locale(String(language))
	if notify:
		language_changed.emit(language)


func set_preference(wanted: StringName) -> void:
	if preference == wanted:
		return
	apply(wanted)
	var prefs := get_node_or_null(^"/root/UserPreferences")
	if prefs != null:
		prefs.set_language(preference)


func cycle() -> void:
	## Follow-the-device, then each language in turn. The picker is a single key
	## on a 320px board; a dropdown there would be a menu inside a menu.
	var order: Array[StringName] = [FOLLOW_DEVICE]
	for entry in LANGUAGES:
		order.append(StringName(entry.code))
	var index := order.find(preference)
	set_preference(order[(index + 1) % order.size()])


func is_supported(code: StringName) -> bool:
	for entry in LANGUAGES:
		if StringName(entry.code) == code:
			return true
	return false


func device_language() -> StringName:
	## What the phone is set to, mapped onto something we can actually show.
	var prefix := OS.get_locale_language().to_lower()
	if DEVICE_MAP.has(prefix):
		return StringName(DEVICE_MAP[prefix])
	# `get_locale_language` is normally the bare language, but a device that
	# hands back a full tag should still be understood rather than dropped.
	var full := OS.get_locale().to_lower()
	for key: String in DEVICE_MAP:
		if full.begins_with(key):
			return StringName(DEVICE_MAP[key])
	return FALLBACK


func entry(code: StringName) -> Dictionary:
	for item in LANGUAGES:
		if StringName(item.code) == code:
			return item.duplicate()
	return {}


func native_name(code: StringName) -> String:
	var found := entry(code)
	return str(found.get("native", String(code)))


func preference_label() -> String:
	## What the settings key reads. Following the device names the language it
	## resolved to as well, because "Automatic" alone never tells you whether the
	## game agreed with your phone.
	if preference == FOLLOW_DEVICE:
		return "%s (%s)" % [t("settings.language.auto"), native_name(language)]
	return native_name(language)


func set_language_for_tests(code: StringName) -> void:
	apply(code)
