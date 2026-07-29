class_name Shop
extends CanvasLayer
## The terminal's order book: a manifest board that slides up from the tabs.

const SHEET_H := 280.0
const TAB_H := 30.0
const W := PortLayout.WORLD_W
const H := PortLayout.VIEW_H

const TABS := [
	["structures", "EQUIPAMENTO", UiTheme.Icon.CRANE],
	["upgrades", "MELHORIAS", UiTheme.Icon.STAR],
	["land", "TERRENO", UiTheme.Icon.LAND],
]

const ICONS := {
	"estivador": "worker_sheet", "empilhadeira": "veh_forklift", "tt": "veh_tt",
	"reach_stacker": "veh_reach_stacker", "rtg": "rtg", "sts": "sts_base",
	"armazem": "bld_warehouse", "rebocador": "veh_tug", "trem": "veh_loco",
	"flutuante": "flutuante", "alfandega": "bld_customs", "torre": "bld_tower",
	"drone": "veh_drone", "porto_ia": "bld_ai_hub", "portal": "bld_portal",
}

var _sheet: PanelContainer
var _tabs: HBoxContainer
var _lists: Dictionary = {}
var _scrolls: Dictionary = {}
var _cards: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _open := false
var _active := "structures"
var _refresh_timer := 0.0
var _dirty := true


func _ready() -> void:
	layer = 5
	_build()
	_populate()
	_sheet.position.y = H - TAB_H
	EventBus.teus_changed.connect(func(_t: float) -> void: _dirty = true)
	EventBus.structure_bought.connect(func(_a: String, _b: int) -> void: _refresh())
	EventBus.upgrade_bought.connect(func(_a: String) -> void: _rebuild_upgrades())
	EventBus.land_bought.connect(func(_a: String) -> void: _refresh())
	_refresh()


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _dirty or _refresh_timer > 0.3:
		_refresh_timer = 0.0
		_dirty = false
		_refresh()
		if _active == "upgrades":
			_rebuild_upgrades()


# ---------- construction ----------

func _build() -> void:
	_sheet = PanelContainer.new()
	UiTheme.apply_panel(_sheet, UiTheme.panel_style())
	_sheet.size = Vector2(W, SHEET_H + TAB_H)
	_sheet.custom_minimum_size = _sheet.size
	add_child(_sheet)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	_sheet.add_child(col)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override(&"separation", 2)
	_tabs.custom_minimum_size.y = TAB_H - 8.0
	col.add_child(_tabs)
	for tab: Array in TABS:
		var button := _make_tab(tab[1], tab[2])
		button.pressed.connect(_on_tab.bind(tab[0]))
		_tabs.add_child(button)
		_tab_buttons[tab[0]] = button

	# One scroll per tab, all stacked in the same slot; hidden ones are skipped
	# by the container so the visible one always fills the sheet.
	for tab: Array in TABS:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.y = SHEET_H - 14.0
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.visible = tab[0] == _active
		col.add_child(scroll)
		_scrolls[tab[0]] = scroll

		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.custom_minimum_size.x = W - 22
		list.add_theme_constant_override(&"separation", 3)
		scroll.add_child(list)
		_lists[tab[0]] = list


func _make_tab(text: String, icon: UiTheme.Icon) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = UiTheme.icon_texture(icon)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override(&"font", UiTheme.FONT)
	button.add_theme_font_size_override(&"font_size", UiTheme.SIZE_SMALL)
	_style_tab(button, false)
	return button


func _style_tab(button: Button, active: bool) -> void:
	var style := UiTheme.nine("ui_tab_on" if active else "ui_tab_off", 4)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		button.add_theme_stylebox_override(state, style)
	var color := UiTheme.INK if active else Color8(76, 66, 60)
	button.add_theme_color_override(&"font_color", color)
	button.add_theme_color_override(&"font_hover_color", color)
	button.add_theme_color_override(&"font_pressed_color", color)


func _populate() -> void:
	for item in StructureDB.ITEMS:
		var card := ShopCard.new()
		card.setup(item.id, "structure",
			"res://assets/sprites/%s.png" % ICONS.get(item.id, "bld_office"),
			item.name, item.desc)
		card.pressed_card.connect(_on_buy_structure)
		_lists["structures"].add_child(card)
		_cards[item.id] = card
	_rebuild_upgrades()
	_rebuild_land()


func _rebuild_upgrades() -> void:
	var list: VBoxContainer = _lists["upgrades"]
	var wanted: Array[String] = []
	for item in UpgradeDB.ITEMS:
		if not GameState.has_upgrade(item.id) and GameState.upgrade_unlocked(item):
			wanted.append(item.id)
	for child in list.get_children():
		var card := child as ShopCard
		if card != null and not wanted.has(card.id):
			_cards.erase(card.id)
			card.queue_free()
	for uid in wanted:
		if _cards.has(uid):
			continue
		var item := UpgradeDB.get_item(uid)
		var icon: String = ICONS.get(item.get("target", ""), "bld_ai_hub")
		var card := ShopCard.new()
		card.setup(uid, "upgrade", "res://assets/sprites/%s.png" % icon,
			item.name, item.desc)
		card.pressed_card.connect(_on_buy_upgrade)
		list.add_child(card)
		_cards[uid] = card
	var hint := list.get_node_or_null(^"EmptyHint")
	if wanted.is_empty() and hint == null:
		var note := UiTheme.label(
			"Nada novo na prancheta.\nMovimente mais carga.",
			UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		note.name = "EmptyHint"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(note)
	elif not wanted.is_empty() and hint != null:
		hint.queue_free()


func _rebuild_land() -> void:
	var list: VBoxContainer = _lists["land"]
	for child in list.get_children():
		child.queue_free()
	for item in LandDB.ITEMS:
		var card := ShopCard.new()
		card.setup(item.id, "land", "res://assets/sprites/gr_dirt_0.png",
			item.name, item.desc)
		card.pressed_card.connect(_on_buy_land)
		list.add_child(card)
		_cards["land_" + item.id] = card


# ---------- interaction ----------

func _on_tab(tab_name: String) -> void:
	if _open and _active == tab_name:
		_close()
		return
	_active = tab_name
	for key: String in _scrolls:
		_scrolls[key].visible = key == tab_name
	for key: String in _tab_buttons:
		_style_tab(_tab_buttons[key], key == tab_name)
	if not _open:
		_open_sheet()
	_refresh()
	AudioManager.play_sfx("tap")


func _open_sheet() -> void:
	_open = true
	var tween := create_tween()
	tween.tween_property(_sheet, "position:y", H - SHEET_H - TAB_H, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	_open = false
	for key: String in _tab_buttons:
		_style_tab(_tab_buttons[key], false)
	var tween := create_tween()
	tween.tween_property(_sheet, "position:y", H - TAB_H, 0.24) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func is_open() -> bool:
	return _open


func _on_buy_structure(id: String) -> void:
	var card: ShopCard = _cards.get(id)
	if GameState.buy_structure(id):
		card.flash_ok()
		AudioManager.play_sfx("buy")
	else:
		card.shake_deny()
		AudioManager.play_sfx("deny")
	_refresh()


func _on_buy_upgrade(id: String) -> void:
	var card: ShopCard = _cards.get(id)
	if GameState.buy_upgrade(id):
		AudioManager.play_sfx("upgrade")
	elif card != null:
		card.shake_deny()
		AudioManager.play_sfx("deny")


func _on_buy_land(id: String) -> void:
	var card: ShopCard = _cards.get("land_" + id)
	var item := LandDB.get_item(id)
	if GameState.land.has(id):
		return
	var next := LandDB.next_parcel()
	if next.is_empty() or next.id != id or not GameState.spend(item.cost):
		if card != null:
			card.shake_deny()
		AudioManager.play_sfx("deny")
		return
	GameState.land[id] = true
	EventBus.land_bought.emit(id)
	if card != null:
		card.flash_ok()
	AudioManager.play_sfx("build")
	_refresh()


func _refresh() -> void:
	for item in StructureDB.ITEMS:
		var card: ShopCard = _cards.get(item.id)
		if card == null:
			continue
		var count := GameState.structure_count(item.id)
		var cost := GameState.structure_cost(item.id)
		var reachable: bool = count > 0 \
			or GameState.lifetime_teus >= float(item.cost) * 0.35
		card.visible = reachable
		card.refresh(cost, count, GameState.can_afford(cost))
	for item in UpgradeDB.ITEMS:
		var card: ShopCard = _cards.get(item.id)
		if card != null:
			card.refresh(item.cost, 0, GameState.can_afford(item.cost))
	var next := LandDB.next_parcel()
	for item in LandDB.ITEMS:
		var card: ShopCard = _cards.get("land_" + item.id)
		if card == null:
			continue
		var owned: bool = GameState.land.has(item.id)
		var is_next: bool = not next.is_empty() and next.id == item.id
		card.visible = owned or is_next
		card.refresh(item.cost, 0, is_next and GameState.can_afford(item.cost), owned)
