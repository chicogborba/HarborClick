class_name Shop
extends CanvasLayer
## The purchase manifest, presented as the foreman's clipboard.
##
## The board is one object: steel clip on top, folder tabs, then the sheet you
## actually read. The order of the chrome follows the order of the questions a
## player asks — *what can I afford* (balance, always in the header), *what kind
## of thing am I buying* (tabs), *how many at a time* (the bulk switch, which
## only appears on the tab where bulk means anything), then the list.
##
## In portrait it is a bottom sheet under the thumb; on a wide screen it becomes
## a side drawer so the port keeps at least two thirds of the window.

signal open_changed(opened: bool)

const TABS := [
	["structures", "EQUIPAMENTO", "EQUIP.", UiTheme.Icon.CRANE],
	["upgrades", "MELHORIAS", "MELH.", UiTheme.Icon.STAR],
	["land", "TERRENO", "TERRA", UiTheme.Icon.LAND],
]
const BUY_MODES: Array[StringName] = [&"x1", &"x10", &"x25", &"max"]
## Min/max width of the desktop drawer. The world keeps
## `ResponsiveShell.WORLD_DESKTOP_FRACTION` regardless, so the upper bound only
## decides how much of the leftover rail the manifest is allowed to use — at
## 300px the longer machine names were still being truncated on a 1080p screen.
const DESKTOP_WIDTH := Vector2(240.0, 360.0)

## Which yard sprite stands for each purchase. Upgrades borrow the sprite of
## the machine they improve, so an upgrade never looks like a generic box.
const UPGRADE_ART := {"click_mult": "estivador", "click_cps_pct": "estivador",
	"global_mult": "torre"}

var _backdrop: ColorRect
var _board: PanelContainer
var _clip: TextureRect
var _launcher: Button
var _balance: Label
var _tabs_row: HBoxContainer
var _bulk_row: HBoxContainer
var _lists: Dictionary = {}
var _scrolls: Dictionary = {}
var _cards: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _buy_buttons: Dictionary = {}
var _teaser: ShopCard
var _open := false
var _active := "structures"
var _refresh_timer := 0.0
var _dirty := true
var _desktop := false
var _safe_rect := Rect2()
var _profile := ""
var _buy_mode: StringName = &"x1"
var _focus_return: Control
var _rail: CommandRail


func _ready() -> void:
	layer = 8
	_build()
	if Progression != null:
		var saved_mode := StringName(Progression.ui.get("buy_mode", "x1"))
		_buy_mode = saved_mode if BUY_MODES.has(saved_mode) else &"x1"
		for mode: StringName in _buy_buttons:
			UiTheme.style_segment(_buy_buttons[mode], mode == _buy_mode)
	_populate()
	get_viewport().size_changed.connect(_layout)
	EventBus.teus_changed.connect(func(_t: float) -> void: _dirty = true)
	EventBus.structure_bought.connect(func(_a: String, _b: int) -> void: _refresh())
	EventBus.upgrade_bought.connect(func(_a: String) -> void: _rebuild_upgrades())
	EventBus.land_bought.connect(func(_a: String) -> void: _refresh())
	_refresh()
	_layout()


func _process(delta: float) -> void:
	if not _open:
		return
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


# ------------------------------------------------------------------ assembly

func _build() -> void:
	_backdrop = UiTheme.scrim()
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_launcher = UiTheme.button("LOJA", &"amber", UiTheme.SIZE_BODY)
	_launcher.icon = UiTheme.icon_texture(UiTheme.Icon.CRANE)
	_launcher.tooltip_text = "Abrir a loja do terminal"
	_launcher.pressed.connect(func() -> void: _on_tab(_active))
	add_child(_launcher)

	_board = PanelContainer.new()
	UiTheme.apply_panel(_board, UiTheme.board_style(9))
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_board)

	# the clip is decoration on top of the board, not part of its layout
	_clip = UiTheme.clip_badge()
	add_child(_clip)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	_board.add_child(col)
	col.add_child(_build_header())
	col.add_child(_build_tabs())

	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sheet)
	var sheet_col := VBoxContainer.new()
	sheet_col.add_theme_constant_override(&"separation", 4)
	sheet.add_child(sheet_col)
	sheet_col.add_child(_build_bulk())

	for tab: Array in TABS:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.visible = tab[0] == _active
		UiTheme.style_scroll(scroll)
		sheet_col.add_child(scroll)
		_scrolls[tab[0]] = scroll
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override(&"separation", 4)
		scroll.add_child(list)
		_lists[tab[0]] = list


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 5)
	header.custom_minimum_size.y = 24.0

	var wallet := UiTheme.panel(UiTheme.slate_style(false, 3))
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(wallet)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override(&"separation", 4)
	wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_child(wallet_row)
	wallet_row.add_child(UiTheme.icon(UiTheme.Icon.TEU))
	_balance = UiTheme.label("0", UiTheme.SIZE_BODY, UiTheme.AMBER)
	wallet_row.add_child(_balance)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(gap)

	var close_btn := UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 26.0,
		"Fechar a loja")
	close_btn.custom_minimum_size = Vector2(30, 24)
	close_btn.tooltip_text = "Fechar (Esc)"
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)
	return header


func _build_tabs() -> Control:
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override(&"separation", 2)
	_tabs_row.custom_minimum_size.y = 24.0
	for tab: Array in TABS:
		var button := Button.new()
		button.text = str(tab[1])
		button.icon = UiTheme.icon_texture(tab[3])
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.apply_font(button, UiTheme.SIZE_SMALL)
		UiTheme.style_tab(button, tab[0] == _active)
		button.pressed.connect(_on_tab.bind(tab[0]))
		_tabs_row.add_child(button)
		_tab_buttons[tab[0]] = button
	return _tabs_row


func _build_bulk() -> Control:
	_bulk_row = HBoxContainer.new()
	_bulk_row.add_theme_constant_override(&"separation", 2)
	_bulk_row.custom_minimum_size.y = 18.0
	var caption := UiTheme.label("LOTE", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bulk_row.add_child(caption)
	for mode in BUY_MODES:
		var button := UiTheme.segment(_buy_mode_label(mode), mode == _buy_mode)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Comprar %s de uma vez" % _buy_mode_label(mode)
		button.pressed.connect(_set_buy_mode.bind(mode))
		_bulk_row.add_child(button)
		_buy_buttons[mode] = button
	return _bulk_row


func _buy_mode_label(mode: StringName) -> String:
	return "MAX" if mode == &"max" else String(mode).to_upper()


# ------------------------------------------------------------------- content

func _populate() -> void:
	for item in StructureDB.ITEMS:
		var card := ShopCard.new()
		card.setup(item.id, "structure", item.id, item.name, item.desc)
		card.pressed_card.connect(_on_buy_structure)
		_lists["structures"].add_child(card)
		_cards[item.id] = card
	_teaser = ShopCard.new()
	_teaser.setup("", "teaser", "", "", "")
	_teaser.visible = false
	_lists["structures"].add_child(_teaser)
	_rebuild_upgrades()
	_rebuild_land()


func _upgrade_art(item: Dictionary) -> String:
	var target := str(item.get("target", ""))
	if not target.is_empty():
		return target
	return str(UPGRADE_ART.get(str(item.get("kind", "")), "torre"))


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
		card.setup(uid, "upgrade", _upgrade_art(item), item.name, item.desc,
			UiTheme.Icon.STAR)
		card.set_compact(_desktop)
		card.pressed_card.connect(_on_buy_upgrade)
		list.add_child(card)
		_cards[uid] = card
	var hint := list.get_node_or_null(^"EmptyHint")
	if wanted.is_empty() and hint == null:
		var note := UiTheme.label(
			"Nada novo na prancheta.\nMovimente mais carga e volte aqui.",
			UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		note.name = "EmptyHint"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(note)
	elif not wanted.is_empty() and hint != null:
		hint.queue_free()
	_update_tab_badges()


func _rebuild_land() -> void:
	var list: VBoxContainer = _lists["land"]
	for child in list.get_children():
		child.queue_free()
	for item in LandDB.ITEMS:
		var card := ShopCard.new()
		card.setup(item.id, "land", "_land", item.name, item.desc)
		card.pressed_card.connect(_on_buy_land)
		list.add_child(card)
		_cards["land_" + item.id] = card


func _update_tab_badges() -> void:
	## A tab only shouts when something on it is actually buyable right now.
	var ready_upgrades := 0
	for item in UpgradeDB.ITEMS:
		if not GameState.has_upgrade(item.id) and GameState.upgrade_unlocked(item) \
				and GameState.can_afford(item.cost):
			ready_upgrades += 1
	var button: Button = _tab_buttons.get("upgrades")
	if button == null:
		return
	var base: String = TABS[1][2] if _desktop else TABS[1][1]
	button.text = "%s %d" % [base, ready_upgrades] if ready_upgrades > 0 else base


# --------------------------------------------------------------------- state

func _on_tab(tab_name: String) -> void:
	if _open and _active == tab_name:
		_close()
		return
	_active = tab_name
	for key: String in _scrolls:
		_scrolls[key].visible = key == tab_name
	for key: String in _tab_buttons:
		UiTheme.style_tab(_tab_buttons[key], key == tab_name)
	_bulk_row.visible = tab_name == "structures"
	if not _open:
		_open_sheet()
	_refresh()
	AudioManager.play_sfx("tap")


func _set_buy_mode(mode: StringName) -> void:
	if not BUY_MODES.has(mode):
		return
	_buy_mode = mode
	if Progression != null:
		Progression.set_buy_mode(mode)
	for key: StringName in _buy_buttons:
		UiTheme.style_segment(_buy_buttons[key], key == _buy_mode)
	_refresh()
	AudioManager.play_sfx("tap")


func _on_backdrop_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_close()
		get_viewport().set_input_as_handled()


func _open_sheet() -> void:
	_open = true
	# Remember who opened us so the caret can go home on close; a keyboard
	# user dumped at the top of the tree every time cannot navigate.
	_focus_return = get_viewport().gui_get_focus_owner()
	_layout()
	UiTheme.focus_first(_board)
	open_changed.emit(true)
	if not UserPreferences.can_animate():
		_board.modulate.a = 1.0
		return
	_board.modulate.a = 0.0
	create_tween().tween_property(_board, "modulate:a", 1.0, 0.14)


func _close() -> void:
	if not _open:
		return
	_open = false
	_layout()
	UiTheme.restore_focus(_focus_return if _focus_return != null else _launcher)
	_focus_return = null
	open_changed.emit(false)


func is_open() -> bool:
	return _open


func has_affordable() -> bool:
	## Is there anything on any tab the player could buy right now?
	##
	## The console lights a lamp on the LOJA key from this. It deliberately asks
	## the shop rather than the economy, because "affordable" here has to mean
	## the same thing the player will see when the board opens — a machine that
	## has not been revealed yet, or an upgrade still locked behind progression,
	## is not something to send them in for.
	for item in StructureDB.ITEMS:
		var count := GameState.structure_count(item.id)
		if count == 0 and GameState.lifetime_teus < float(item.cost) * 0.25:
			continue
		if bool(GameState.structure_purchase_quote(item.id, _buy_mode)
				.get("ok", false)):
			return true
	for item in UpgradeDB.ITEMS:
		if not GameState.has_upgrade(item.id) and GameState.upgrade_unlocked(item) \
				and GameState.can_afford(item.cost):
			return true
	var parcel := LandDB.next_parcel()
	return not parcel.is_empty() and GameState.can_afford(float(parcel.cost))


# -------------------------------------------------------------------- layout

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	_desktop = _profile == "desktop" if not _profile.is_empty() \
		else view.x >= 700.0 and view.x / maxf(view.y, 1.0) >= 1.25
	if _desktop:
		var slot := _rail.content_rect if _rail != null \
			and _rail.content_rect.size != Vector2.ZERO else Rect2()
		if slot.size == Vector2.ZERO:
			var width := clampf(safe.size.x * 0.30, DESKTOP_WIDTH.x, DESKTOP_WIDTH.y)
			slot = Rect2(Vector2(safe.end.x - width - 8.0, safe.position.y + 8.0),
				Vector2(width, safe.size.y - 16.0))
		_board.size = slot.size
		_board.position = slot.position
	else:
		var height := minf(safe.size.y * 0.70, 430.0)
		_board.size = Vector2(safe.size.x - 12.0, height)
		_board.position = Vector2(safe.position.x + 6.0, safe.end.y - height - 6.0)
	for index in TABS.size():
		var tab: Array = TABS[index]
		var tab_button: Button = _tab_buttons.get(tab[0])
		if tab_button != null:
			tab_button.text = str(tab[2] if _desktop else tab[1])
	_update_tab_badges()
	for card: ShopCard in _cards.values():
		card.set_compact(_desktop)
	if _teaser != null:
		_teaser.set_compact(_desktop)

	_backdrop.visible = _open and not _desktop
	_board.visible = _open
	UiTheme.place_clip(_clip, _board, safe)
	# The rail owns the LOJA key in both profiles; the standalone launcher is
	# only a fallback for a shop hosted without one (previews and tests).
	_launcher.visible = not _open and _rail == null
	if _desktop:
		_launcher.size = Vector2(154.0, 40.0)
		_launcher.position = Vector2(safe.end.x - 162.0, safe.end.y - 48.0)
	else:
		_launcher.size = Vector2(118.0, 38.0)
		_launcher.position = Vector2(
			safe.position.x + (safe.size.x - _launcher.size.x) * 0.5,
			safe.end.y - 46.0)


func set_rail(rail: CommandRail) -> void:
	## On a wide screen the board draws exactly where the rail is, so opening
	## the shop reads as the rail turning a page rather than a drawer arriving
	## from off screen — and the LOJA key belongs to the rail, not to a button
	## floating on the grey.
	_rail = rail


func toggle() -> void:
	if _open:
		_close()
	else:
		_on_tab(_active)


func launcher_rect() -> Rect2:
	if _rail != null and _rail.content_rect.size != Vector2.ZERO:
		return _rail.content_rect
	return _launcher.get_global_rect()


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_profile = str(metrics.get("profile", ""))
	_layout()


func _resolved_safe_rect(view: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return viewport_rect
	var clipped := _safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 \
		else viewport_rect


# ------------------------------------------------------------------ purchase

func _on_buy_structure(id: String) -> void:
	var card: ShopCard = _cards.get(id)
	var result := GameState.buy_structure_bulk(id, _buy_mode)
	if bool(result.get("ok", false)):
		if card != null:
			card.flash_ok()
		AudioManager.play_sfx("buy")
	else:
		if card != null:
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
	if _balance != null:
		_balance.text = GameState.fmt(GameState.teus)
	var next_locked := {}
	for item in StructureDB.ITEMS:
		var card: ShopCard = _cards.get(item.id)
		if card == null:
			continue
		var count := GameState.structure_count(item.id)
		var quote := GameState.structure_purchase_quote(item.id, _buy_mode)
		var revealed: bool = count > 0 \
			or GameState.lifetime_teus >= float(item.cost) * 0.25
		card.visible = revealed
		if not revealed:
			if next_locked.is_empty():
				next_locked = item
			continue
		card.refresh(float(quote.get("total_cost", INF)), count,
			bool(quote.get("ok", false)), false,
			int(quote.get("quantity", 0)),
			float(quote.get("nominal_cps_gain", 0.0)))
	_refresh_teaser(next_locked)

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
		card.refresh(item.cost, 0,
			is_next and GameState.can_afford(item.cost), owned)


func _refresh_teaser(item: Dictionary) -> void:
	## Always show the silhouette of the next machine the terminal could run.
	## An empty list bottom reads as "that's all there is"; a locked slot reads
	## as "keep going".
	if _teaser == null:
		return
	if item.is_empty():
		_teaser.visible = false
		return
	_teaser.visible = true
	_teaser.show_locked("???", "Movimente %s TEU no total para liberar."
		% GameState.fmt(float(item.cost) * 0.25))
