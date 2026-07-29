class_name Shop
extends CanvasLayer
## Responsive order book: bottom sheet in portrait, compact drawer on desktop.

signal open_changed(opened: bool)

const TABS := [
	["structures", "EQUIPAMENTO", UiTheme.Icon.CRANE],
	["upgrades", "MELHORIAS", UiTheme.Icon.STAR],
	["land", "TERRENO", UiTheme.Icon.LAND],
]
const DESKTOP_TAB_LABELS := {
	"structures": "EQUIP.",
	"upgrades": "MELH.",
	"land": "TERRA",
}

const ICONS := {
	"estivador": "worker_sheet", "empilhadeira": "veh_forklift", "tt": "veh_tt",
	"reach_stacker": "veh_reach_stacker", "rtg": "rtg", "sts": "sts_base",
	"armazem": "bld_warehouse", "rebocador": "veh_tug", "trem": "veh_loco",
	"flutuante": "flutuante", "alfandega": "bld_customs", "torre": "bld_tower",
	"drone": "veh_drone", "porto_ia": "bld_ai_hub", "portal": "bld_portal",
}

var _backdrop: ColorRect
var _sheet: PanelContainer
var _launcher: Button
var _tabs: HBoxContainer
var _lists: Dictionary = {}
var _scrolls: Dictionary = {}
var _cards: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _open := false
var _active := "structures"
var _refresh_timer := 0.0
var _dirty := true
var _desktop := false
var _safe_rect := Rect2()
var _profile := ""


func _ready() -> void:
	layer = 8
	_build()
	_populate()
	get_viewport().size_changed.connect(_layout)
	EventBus.teus_changed.connect(func(_t: float) -> void: _dirty = true)
	EventBus.structure_bought.connect(func(_a: String, _b: int) -> void: _refresh())
	EventBus.upgrade_bought.connect(func(_a: String) -> void: _rebuild_upgrades())
	EventBus.land_bought.connect(func(_a: String) -> void: _refresh())
	_refresh()
	_layout()


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _dirty or _refresh_timer > 0.3:
		_refresh_timer = 0.0
		_dirty = false
		_refresh()
		if _active == "upgrades":
			_rebuild_upgrades()


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		_close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.03, 0.025, 0.07, 0.68)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_launcher = UiTheme.button("LOJA", "amber", UiTheme.SIZE_BODY)
	_launcher.icon = UiTheme.icon_texture(UiTheme.Icon.CRANE)
	_launcher.focus_mode = Control.FOCUS_ALL
	_launcher.tooltip_text = "Abrir loja"
	_launcher.pressed.connect(func() -> void: _on_tab("structures"))
	add_child(_launcher)

	_sheet = PanelContainer.new()
	UiTheme.apply_panel(_sheet, UiTheme.dark_panel(10))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 5)
	_sheet.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 5)
	col.add_child(header)
	var handle := UiTheme.label("LOJA", UiTheme.SIZE_SMALL, UiTheme.TEAL)
	handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(handle)
	var close_btn := UiTheme.button("X", "off", UiTheme.SIZE_TITLE)
	close_btn.tooltip_text = "Fechar loja"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override(&"separation", 3)
	col.add_child(_tabs)
	for tab: Array in TABS:
		var button := _make_tab(tab[1], tab[2])
		button.pressed.connect(_on_tab.bind(tab[0]))
		_tabs.add_child(button)
		_tab_buttons[tab[0]] = button

	for tab: Array in TABS:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.visible = tab[0] == _active
		col.add_child(scroll)
		_scrolls[tab[0]] = scroll
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override(&"separation", 4)
		scroll.add_child(list)
		_lists[tab[0]] = list


func _make_tab(text: String, icon: UiTheme.Icon) -> Button:
	var button := UiTheme.button(text, "alt", UiTheme.SIZE_SMALL)
	button.icon = UiTheme.icon_texture(icon)
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_tab(button, false)
	return button


func _style_tab(button: Button, active: bool) -> void:
	button.modulate = Color.WHITE if active else Color(0.7, 0.67, 0.78)
	button.add_theme_color_override(&"font_color", UiTheme.CREAM if active else UiTheme.PLATE_TEXT)


func _on_backdrop_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_close()
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	_desktop = _profile == "desktop" if not _profile.is_empty() \
		else view.x >= 700.0 and view.x / maxf(view.y, 1.0) >= 1.25
	if _desktop:
		var width := clampf(safe.size.x * 0.29, 200.0, 224.0)
		_sheet.size = Vector2(width, safe.size.y - 16.0)
		_sheet.position = Vector2(
			safe.end.x - width - 8.0, safe.position.y + 8.0)
	else:
		var height := minf(safe.size.y * 0.68, 390.0)
		_sheet.size = Vector2(safe.size.x - 12.0, height)
		_sheet.position = Vector2(
			safe.position.x + 6.0, safe.end.y - height - 6.0)
	for index in TABS.size():
		var tab: Array = TABS[index]
		var tab_button: Button = _tab_buttons.get(tab[0])
		if tab_button != null:
			tab_button.text = str(DESKTOP_TAB_LABELS.get(tab[0], tab[1])) \
				if _desktop else str(tab[1])
	_backdrop.visible = _open
	_sheet.visible = _open
	_launcher.visible = not _open
	if _desktop:
		_launcher.size = Vector2(154.0, 40.0)
		_launcher.position = Vector2(
			safe.end.x - 162.0, safe.end.y - 48.0)
	else:
		_launcher.size = Vector2(118.0, 36.0)
		_launcher.position = Vector2(
			safe.position.x + (safe.size.x - _launcher.size.x) * 0.5,
			safe.end.y - 44.0)


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get(
		"safe_rect", Rect2(Vector2.ZERO, view))
	_profile = str(metrics.get("profile", ""))
	_layout()


func _resolved_safe_rect(view: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return viewport_rect
	var clipped := _safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 \
		else viewport_rect


func _populate() -> void:
	for item in StructureDB.ITEMS:
		var card := ShopCard.new()
		card.setup(item.id, "structure", "res://assets/sprites/%s.png" % ICONS.get(item.id, "bld_office"), item.name, item.desc)
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
		var card := ShopCard.new()
		var icon_path := "res://assets/sprites/%s.png" % ICONS.get(
			item.get("target", ""), "bld_ai_hub")
		card.setup(uid, "upgrade", icon_path, item.name, item.desc)
		card.pressed_card.connect(_on_buy_upgrade)
		list.add_child(card)
		_cards[uid] = card
	var hint := list.get_node_or_null(^"EmptyHint")
	if wanted.is_empty() and hint == null:
		var note := UiTheme.label(
			"Nada novo na prancheta.\nMovimente mais carga.",
			UiTheme.SIZE_SMALL, UiTheme.PLATE_TEXT)
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
	_layout()
	if not UserPreferences.can_animate():
		_sheet.modulate.a = 1.0
		open_changed.emit(true)
		return
	_sheet.modulate.a = 0.0
	create_tween().tween_property(_sheet, "modulate:a", 1.0, 0.16)
	open_changed.emit(true)


func _close() -> void:
	if not _open:
		return
	_open = false
	for key: String in _tab_buttons:
		_style_tab(_tab_buttons[key], false)
	_layout()
	open_changed.emit(false)


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
		card.visible = count > 0 or GameState.lifetime_teus >= float(item.cost) * 0.35
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
