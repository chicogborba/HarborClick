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
## It is a bottom sheet under the thumb. It used to also have a side-drawer form
## for a wide screen; the game is portrait-only now, and a second layout nobody
## can open is a second layout that silently goes wrong.

signal open_changed(opened: bool)

## Tab id, translation key, glyph. The word is a key rather than a literal so
## the board can be relabelled without being rebuilt.
const TABS := [
	["structures", "shop.tab.structures", UiTheme.Icon.CRANE],
	["upgrades", "shop.tab.upgrades", UiTheme.Icon.STAR],
	["land", "shop.tab.land", UiTheme.Icon.LAND],
	["orders", "shop.tab.orders", UiTheme.Icon.SHIP],
	["cosmetics", "shop.tab.cosmetics", UiTheme.Icon.PAW],
]
const BUY_MODES: Array[StringName] = [&"x1", &"x10", &"x25", &"max"]
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
var _land_empty: Label
var _open := false
var _active := "structures"
var _refresh_timer := 0.0
var _dirty := true
var _safe_rect := Rect2()
var _profile := ""
var _buy_mode: StringName = &"x1"
var _focus_return: Control
var _rail: CommandRail
## The railway, not the console. `_rail` is the bottom bar; this is the branch
## line, and the orders board is the only screen it reports to.
var _branch: RailYard
## The upgrades tab: a network diagram, and the ticket that answers everything
## about whichever station on it was last touched.
var _map: UpgradeMap
var _map_pick := ""
var _ticket: PanelContainer
var _ticket_name: Label
var _ticket_effect: Label
var _ticket_price: PanelContainer
var _ticket_price_label: Label
var _ticket_buy: Button
## The upgrades tab is a list first and a map on request. The map was the only
## view, and on a phone it was fifty grey dots with half their names cut off:
## nobody could tell what was for sale, what it did or what it cost without
## tapping stations one by one.
var _up_list_view: Control
var _up_map_view: Control
var _up_summary: Label
var _up_view_toggle: Button
var _up_list: VBoxContainer
var _up_caption_ready: Control
var _up_caption_next: Control
var _up_more: Label
var _up_owned_toggle: Button
var _up_owned_open := false
var _up_showing_map := false
## Order and membership the list was last laid out with, so a refresh that
## changes nothing moves nothing.
var _up_layout_key := ""


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
	EventBus.upgrade_bought.connect(func(_a: String) -> void: _refresh_upgrades())
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
			_refresh_upgrades()


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

	_launcher = UiTheme.button(Loc.t("shop.title"), &"amber", UiTheme.SIZE_BODY)
	_launcher.icon = UiTheme.icon_texture(UiTheme.Icon.CRANE)
	_launcher.tooltip_text = Loc.t("rail.shop.name")
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
		if tab[0] == "upgrades":
			# The upgrades tab is a map, not a list, so it gets no scroll
			# container: it pans and zooms itself, and a ScrollContainer wrapped
			# round something that already handles drag would fight it for every
			# gesture and win.
			var page := _build_upgrade_page()
			page.visible = tab[0] == _active
			sheet_col.add_child(page)
			_scrolls[tab[0]] = page
			continue
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.visible = tab[0] == _active
		UiTheme.style_scroll(scroll)
		sheet_col.add_child(scroll)
		_scrolls[tab[0]] = scroll
		var list: Container
		if tab[0] == "structures":
			# The equipment tab is a shelf, not a ledger: two machines abreast,
			# each a tile with its own buy key.
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override(&"h_separation", 4)
			grid.add_theme_constant_override(&"v_separation", 4)
			list = grid
		else:
			list = VBoxContainer.new()
			list.add_theme_constant_override(&"separation", 4)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		_lists[tab[0]] = list


func _build_header() -> Control:
	## The shop's nameplate: its title, the wallet lit into a glass well on the
	## right, then the close key — the one balance that matters while buying is
	## next to the hand that buys.
	var header := UiTheme.header(Loc.t("shop.title"), _close, UiTheme.Icon.CRANE)
	var close_btn: Button = header.close
	close_btn.tooltip_text = Loc.t("common.close_hint")
	UiTheme.describe(close_btn, Loc.t("shop.close_name"))
	var wallet := UiTheme.panel(UiTheme.glass_style(3))
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override(&"separation", 4)
	wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_child(wallet_row)
	wallet_row.add_child(UiTheme.icon(UiTheme.Icon.TEU))
	_balance = UiTheme.label("0", UiTheme.SIZE_BODY, UiTheme.DIGIT)
	wallet_row.add_child(_balance)
	var row := close_btn.get_parent()
	row.add_child(wallet)
	row.move_child(wallet, close_btn.get_index())
	return header.root


func _build_tabs() -> Control:
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override(&"separation", 2)
	_tabs_row.custom_minimum_size.y = 24.0
	for tab: Array in TABS:
		var button := Button.new()
		button.text = Loc.t(str(tab[1]))
		button.icon = UiTheme.icon_texture(tab[2])
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
	var caption := UiTheme.label(Loc.t("shop.bulk"), UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bulk_row.add_child(caption)
	for mode in BUY_MODES:
		var button := UiTheme.segment(_buy_mode_label(mode), mode == _buy_mode)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = Loc.t("shop.bulk.name",
			{"mode": _buy_mode_label(mode)})
		button.pressed.connect(_set_buy_mode.bind(mode))
		_bulk_row.add_child(button)
		_buy_buttons[mode] = button
	return _bulk_row


func _buy_mode_label(mode: StringName) -> String:
	return Loc.t("shop.bulk.max") if mode == &"max" else String(mode).to_upper()


# ------------------------------------------------------------------- content

func _populate() -> void:
	for item in StructureDB.ITEMS:
		var card := ShopCard.new()
		card.tile = true
		card.setup(item.id, "structure", item.id, item.name, item.desc)
		card.pressed_card.connect(_on_buy_structure)
		_lists["structures"].add_child(card)
		_cards[item.id] = card
	_teaser = ShopCard.new()
	_teaser.tile = true
	_teaser.setup("", "teaser", "", "", "")
	_teaser.visible = false
	_lists["structures"].add_child(_teaser)
	_build_upgrade_cards()
	_refresh_upgrades()
	_rebuild_land()
	_build_orders()
	_build_cosmetics()


func _build_upgrade_page() -> Control:
	## A list of what can be bought, with the map one key away.
	##
	## The list answers the three questions in the order a player asks them —
	## what can I buy now, what is next, what have I got — and every card says
	## what it does and what it costs without a tap. The transit map is still
	## there for the shape of the tree; it is just no longer the only way in.
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", 3)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	page.add_child(head)
	_up_summary = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_up_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up_summary.clip_text = true
	head.add_child(_up_summary)
	_up_view_toggle = UiTheme.button(Loc.t("shop.upgrades.map"), &"ghost",
		UiTheme.SIZE_SMALL)
	_up_view_toggle.custom_minimum_size = Vector2(64.0, 22.0)
	_up_view_toggle.pressed.connect(_toggle_upgrade_view)
	head.add_child(_up_view_toggle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiTheme.style_scroll(scroll)
	page.add_child(scroll)
	_up_list_view = scroll
	# The scrollbar is drawn over the last few pixels of a full-width child, so
	# the gutter is reserved by hand (see the live-panel note in scripts/ui).
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override(&"margin_right", UiTheme.SCROLL_WIDTH)
	scroll.add_child(gutter)
	_up_list = VBoxContainer.new()
	_up_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up_list.add_theme_constant_override(&"separation", 4)
	gutter.add_child(_up_list)
	_up_caption_ready = _orders_caption(Loc.t("shop.upgrades.available"))
	_up_list.add_child(_up_caption_ready)
	_up_caption_next = _orders_caption(Loc.t("shop.upgrades.next"))
	_up_list.add_child(_up_caption_next)
	_up_more = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_up_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_up_list.add_child(_up_more)
	_up_owned_toggle = UiTheme.button("", &"ghost", UiTheme.SIZE_SMALL)
	_up_owned_toggle.custom_minimum_size.y = 24.0
	_up_owned_toggle.pressed.connect(func() -> void:
		_up_owned_open = not _up_owned_open
		_up_layout_key = ""
		_refresh_upgrade_list())
	_up_list.add_child(_up_owned_toggle)

	var map_page := VBoxContainer.new()
	map_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_page.add_theme_constant_override(&"separation", 3)
	map_page.visible = false
	page.add_child(map_page)
	_up_map_view = map_page

	var well := UiTheme.panel(UiTheme.well_style(2))
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_page.add_child(well)
	_map = UpgradeMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.node_selected.connect(_on_map_node)
	well.add_child(_map)

	_ticket = UiTheme.panel(UiTheme.paper_style(4))
	# A floor, so the map's EXPAND_FILL can never squeeze the answer panel to
	# nothing on a short screen — the map is the part that should give way.
	_ticket.custom_minimum_size.y = 84.0
	map_page.add_child(_ticket)
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	_ticket.add_child(row)

	_ticket_name = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_ticket_name.clip_text = true
	row.add_child(_ticket_name)

	_ticket_effect = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_ticket_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Both of these matter. An autowrap label with no width to wrap *to* reports a
	# minimum height of thousands of pixels, and a PanelContainer can never be
	# smaller than its content — so the board grew past the screen and pushed this
	# very panel off the bottom of it. `_layout` gives it a real width; the line
	# cap stops a long swap warning doing the same thing more slowly.
	_ticket_effect.max_lines_visible = 3
	_ticket_effect.custom_minimum_size = Vector2(120.0, 30.0)
	row.add_child(_ticket_effect)

	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override(&"separation", 4)
	row.add_child(buy_row)
	_ticket_price = UiTheme.stamp("", UiTheme.AMBER, UiTheme.SIZE_SMALL)
	_ticket_price.custom_minimum_size.x = 68.0
	buy_row.add_child(_ticket_price)
	_ticket_price_label = UiTheme.stamp_label(_ticket_price)
	_ticket_buy = UiTheme.button(Loc.t("shop.map.buy"), &"amber", UiTheme.SIZE_SMALL)
	_ticket_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticket_buy.custom_minimum_size.y = 26.0
	_ticket_buy.pressed.connect(func() -> void: _on_buy_upgrade(_map_pick))
	buy_row.add_child(_ticket_buy)
	return page


func _build_upgrade_cards() -> void:
	## One card per upgrade, built once. Refreshing moves and restyles them; it
	## never frees one, because a card freed between press and release is a tap
	## that never lands.
	for item in UpgradeDB.ITEMS:
		var card := ShopCard.new()
		card.setup(str(item.id), "upgrade", _upgrade_art(item), str(item.name),
			str(item.get("desc", "")))
		card.pressed_card.connect(_on_buy_upgrade)
		card.visible = false
		_up_list.add_child(card)
		_cards["up_" + str(item.id)] = card


func _upgrade_art(item: Dictionary) -> String:
	## The machine a node is fitted to is the clearest picture of what it does.
	## A click upgrade is the docker's; a port-wide one wears its trunk's art.
	var targets := UpgradeDB.targets_of(item)
	if not targets.is_empty() and PortIcon.ART.has(targets[0]):
		return targets[0]
	if str(item.get("kind", "")).begins_with("click"):
		return "estivador"
	var branch := UpgradeDB.branch_of(item)
	for entry: Dictionary in UpgradeDB.branches():
		if str(entry.id) == branch:
			return str(entry.get("art", ""))
	return ""


func _toggle_upgrade_view() -> void:
	_up_showing_map = not _up_showing_map
	_up_list_view.visible = not _up_showing_map
	_up_map_view.visible = _up_showing_map
	_up_view_toggle.text = Loc.t("shop.upgrades.list" if _up_showing_map
		else "shop.upgrades.map")
	AudioManager.play_sfx("tap")
	_refresh_upgrades()


func _upgrade_frontier(item: Dictionary) -> bool:
	## A node worth showing before it can be bought: everything it hangs off is
	## owned, so the only thing between the player and it is a number they are
	## already growing. Deeper nodes stay off the list — eight greyed rows about
	## machines you do not run yet is noise, not a plan.
	return UpgradeDB.blocked_by(item, GameState.upgrades).is_empty()


func _refresh_upgrade_list() -> void:
	if _up_list == null:
		return
	var available: Array[Dictionary] = []
	var next: Array[Dictionary] = []
	var owned: Array[Dictionary] = []
	var hidden := 0
	for item in UpgradeDB.ITEMS:
		var id := str(item.id)
		if GameState.has_upgrade(id):
			owned.append(item)
		elif GameState.upgrade_available(item):
			available.append(item)
		elif _upgrade_frontier(item):
			next.append(item)
		else:
			hidden += 1
	var by_price := func(a: Dictionary, b: Dictionary) -> bool:
		return UpgradeDB.price_for(a, GameState.upgrades) \
			< UpgradeDB.price_for(b, GameState.upgrades)
	available.sort_custom(by_price)
	next.sort_custom(by_price)

	var ready := 0
	for item in available:
		if GameState.can_afford(UpgradeDB.price_for(item, GameState.upgrades)):
			ready += 1
	_up_summary.text = Loc.t("shop.upgrades.summary", {
		"owned": str(owned.size()), "total": str(UpgradeDB.ITEMS.size()),
		"ready": str(ready)})
	_up_more.text = Loc.t("shop.upgrades.more", {"n": str(hidden)}) if hidden > 0 else ""
	_up_more.visible = hidden > 0
	_up_owned_toggle.text = Loc.t("shop.upgrades.owned", {"n": str(owned.size())}) \
		+ ("  -" if _up_owned_open else "  +")
	_up_owned_toggle.visible = not owned.is_empty()
	_up_caption_ready.visible = not available.is_empty()
	_up_caption_next.visible = not next.is_empty()

	# Membership and order change on a purchase or an unlock, not on every
	# credited box — so the list is only re-laid when they actually did, and
	# never under a finger that is still down.
	var key := "%s|%s|%s|%s" % [_ids(available), _ids(next), _ids(owned), _up_owned_open]
	if key != _up_layout_key and not _pointer_down():
		_up_layout_key = key
		var at := 0
		_up_list.move_child(_up_caption_ready, at)
		at += 1
		for item in available:
			_up_list.move_child(_cards["up_" + str(item.id)], at)
			at += 1
		_up_list.move_child(_up_caption_next, at)
		at += 1
		for item in next:
			_up_list.move_child(_cards["up_" + str(item.id)], at)
			at += 1
		_up_list.move_child(_up_more, at)
		at += 1
		_up_list.move_child(_up_owned_toggle, at)
		at += 1
		for item in owned:
			_up_list.move_child(_cards["up_" + str(item.id)], at)
			at += 1

	for item in UpgradeDB.ITEMS:
		var id := str(item.id)
		var card: ShopCard = _cards.get("up_" + id)
		if card == null:
			continue
		var price := UpgradeDB.price_for(item, GameState.upgrades)
		card.set_chips(upgrade_chips(item))
		if GameState.has_upgrade(id):
			card.visible = _up_owned_open
			card.set_effect(str(GameState.upgrade_preview(item).get("text", "")))
			card.refresh(price, 0, false, true)
		elif GameState.upgrade_available(item):
			card.visible = true
			var effect := str(GameState.upgrade_preview(item).get("text", ""))
			var refits := UpgradeDB.conflicts_with(item, GameState.upgrades)
			var rivals := UpgradeDB.excludes_of(item)
			if not refits.is_empty():
				effect = "%s\n%s" % [effect, Loc.t("shop.upgrade.swap", {"name": str(
					UpgradeDB.get_item(refits[0]).get("name", refits[0]))})]
			elif not rivals.is_empty():
				# The pair explained before the first buy, not discovered after it.
				effect = "%s\n%s" % [effect, Loc.t("shop.upgrade.or", {"name": str(
					UpgradeDB.get_item(rivals[0]).get("name", rivals[0]))})]
			card.set_effect(effect)
			card.refresh(price, 0, GameState.can_afford(price), false, 1,
				float(GameState.upgrade_preview(item).get("cps_gain", 0.0)))
		elif _upgrade_frontier(item):
			card.visible = true
			card.show_gated(_gate_reason(item), price)
		else:
			card.visible = false


## Chip colours, one per kind of effect, so a glance tells production from taps
## from the whole port without reading a word.
const CHIP_PRODUCTION := Color8(36, 120, 110)
const CHIP_PORT := Color8(52, 128, 58)
const CHIP_TAP := Color8(176, 104, 22)
const CHIP_SYNERGY := Color8(40, 96, 156)
const CHIP_SWAP := Color8(112, 70, 156)
const CHIP_RAIL := Color8(76, 88, 112)
const CHIP_CHOICE := Color8(170, 56, 100)


static func upgrade_chips(item: Dictionary) -> Array:
	## What kind of thing an upgrade card does, as up to two coloured tags.
	var chips: Array = []
	var value := float(item.get("value", 1.0))
	var scale := ("x%s" % String.num(value, 2).trim_suffix(".0")) if value >= 2.0 \
		else "+%d%%" % roundi((value - 1.0) * 100.0)
	match str(item.get("kind", "")):
		"structure_mult":
			chips.append({"text": "%s TEU/s" % scale, "color": CHIP_PRODUCTION,
				"icon": UiTheme.Icon.TEU})
		"global_mult":
			chips.append({"text": Loc.t("shop.chip.port", {"v": scale}),
				"color": CHIP_PORT, "icon": UiTheme.Icon.STAR})
		"click_mult":
			chips.append({"text": Loc.t("shop.chip.tap", {"v": scale}),
				"color": CHIP_TAP, "icon": UiTheme.Icon.GLOVE})
		"click_cps_pct":
			chips.append({"text": Loc.t("shop.chip.tap",
				{"v": "+%d%%" % roundi(value * 100.0)}),
				"color": CHIP_TAP, "icon": UiTheme.Icon.GLOVE})
		"synergy":
			chips.append({"text": Loc.t("shop.chip.synergy",
				{"v": "+%d%%" % roundi(value * 100.0)}),
				"color": CHIP_SYNERGY, "icon": UiTheme.Icon.CREW})
		"transform":
			chips.append({"text": Loc.t("shop.chip.swap"), "color": CHIP_SWAP,
				"icon": UiTheme.Icon.CHEVRON})
		"rail_stat":
			chips.append({"text": Loc.t("shop.chip.rail"), "color": CHIP_RAIL,
				"icon": UiTheme.Icon.TRAIN})
	if not UpgradeDB.excludes_of(item).is_empty():
		chips.append({"text": Loc.t("shop.chip.choice"), "color": CHIP_CHOICE,
			"icon": UiTheme.Icon.LOCK})
	return chips


static func _ids(items: Array[Dictionary]) -> String:
	var out := PackedStringArray()
	for item in items:
		out.append(str(item.id))
	return ",".join(out)


func _pointer_down() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _on_map_node(id: String) -> void:
	_map_pick = id
	_refresh_ticket()
	AudioManager.play_sfx("tap")


func _refresh_ticket() -> void:
	## Everything about one station, in the order a player asks it: what is this,
	## what does it do for me, what does it cost, can I have it.
	if _ticket == null:
		return
	if _map_pick.is_empty():
		_ticket_name.text = Loc.t("shop.map.pick")
		_ticket_effect.text = Loc.t("shop.map.hint")
		_ticket_price.visible = false
		_ticket_buy.disabled = true
		_ticket_buy.text = Loc.t("shop.map.buy")
		return
	var item := UpgradeDB.get_item(_map_pick)
	if item.is_empty():
		return
	_ticket_name.text = str(item.get("name", _map_pick))
	_ticket_price.visible = true
	if GameState.has_upgrade(_map_pick):
		_ticket_effect.text = str(GameState.upgrade_preview(item).get("text", ""))
		_ticket_price_label.text = Loc.t("shop.map.owned")
		_ticket_buy.disabled = true
		_ticket_buy.text = Loc.t("shop.map.owned")
		return
	var reason := _gate_reason(item)
	var price := UpgradeDB.price_for(item, GameState.upgrades)
	_ticket_price_label.text = GameState.fmt(price)
	if not reason.is_empty():
		_ticket_effect.text = "%s\n%s" % [reason, str(item.get("desc", ""))]
		_ticket_buy.disabled = true
		_ticket_buy.text = Loc.t("shop.map.shut")
		return
	var refits := UpgradeDB.conflicts_with(item, GameState.upgrades)
	var effect := str(GameState.upgrade_preview(item).get("text", ""))
	if not refits.is_empty():
		effect = "%s\n%s" % [effect, Loc.t("shop.upgrade.swap", {"name": str(
			UpgradeDB.get_item(refits[0]).get("name", refits[0]))})]
	_ticket_effect.text = effect
	_ticket_buy.disabled = not GameState.can_afford(price)
	_ticket_buy.text = Loc.t("shop.map.buy")


func _refresh_upgrades() -> void:
	## The map redraws itself only when a station actually changed state, and the
	## ticket under it re-reads whichever station is selected. Nothing is rebuilt:
	## this runs off the shop's refresh timer while the tab is open, and the
	## version of this screen that tore down and re-created its rows on that timer
	## ate every tap that landed during a rebuild.
	if _up_showing_map:
		if _map != null:
			_map.refresh()
		_refresh_ticket()
	else:
		_refresh_upgrade_list()
	_update_tab_badges()


func _gate_reason(item: Dictionary) -> String:
	## Why this node is shut, in one line, naming the thing to go and do.
	##
	## A purchase gate is named first because it is the closer of the two and the
	## one the player controls directly. "Faltam 40 estivadores" is a plan; a
	## greyed-out row with no sentence is a bug report.
	var missing := UpgradeDB.blocked_by(item, GameState.upgrades)
	if not missing.is_empty():
		return Loc.t("shop.upgrade.needs", {"name": str(
			UpgradeDB.get_item(missing[0]).get("name", missing[0]))})
	var unlock: Dictionary = item.get("unlock", {})
	for sid: String in unlock.get("owned", {}):
		var need := int(unlock.owned[sid])
		var have := GameState.structure_count(sid)
		if have < need:
			return Loc.t("shop.upgrade.needs_fleet", {
				"count": str(need - have),
				"name": str(StructureDB.get_item(sid).get("name", sid))})
	if unlock.has("teus") and GameState.lifetime_teus < float(unlock.teus):
		return Loc.t("shop.upgrade.needs_teus",
			{"amount": GameState.fmt(float(unlock.teus))})
	return ""


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
	# Shown when every parcel is owned: without it the tab is a bare empty
	# sheet that reads as "nothing here", not "everything bought".
	_land_empty = UiTheme.label(Loc.t("shop.land.done"), UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	_land_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_land_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_land_empty.visible = false
	list.add_child(_land_empty)


func _build_cosmetics() -> void:
	## The shelf. Every other tab on this board sells production; this one sells
	## nothing but the way the terminal looks, which is why each row has to carry
	## two different controls at two different times.
	##
	## Unowned, it is a price and a key. Owned, it is a switch — and the switch
	## is the reason the tab exists at all: a decoration you cannot take back off
	## is a decoration nobody risks buying.
	var list: VBoxContainer = _lists["cosmetics"]
	list.add_child(_orders_caption(Loc.t("shop.cosmetics.port")))
	var intro := UiTheme.label(
		# Hyphens, never em dashes: the bitmap font has no glyph for one and
		# prints a hollow box in its place.
		Loc.t("shop.cosmetics.blurb"),
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(intro)
	var crew_done := false
	for item: Dictionary in CosmeticDb.all():
		if StringName(item.kind) == CosmeticDb.KIND_CREW and not crew_done:
			crew_done = true
			list.add_child(_orders_caption(Loc.t("shop.cosmetics.crew")))
		list.add_child(_cosmetic_card(item))


func _cosmetic_card(item: Dictionary) -> PanelContainer:
	var id := StringName(item.id)
	var card := PanelContainer.new()
	card.name = "Decor_%s" % id
	UiTheme.apply_panel(card, UiTheme.card_style(&"normal"))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", 6)
	card.add_child(row)

	var glyph := UiTheme.icon(UiTheme.Icon[str(item.get("icon", "STAR"))], 2)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 1)
	row.add_child(text)
	text.add_child(UiTheme.label(str(item.name), UiTheme.SIZE_BODY, UiTheme.INK))
	var blurb := UiTheme.label(str(item.desc), UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(blurb)

	var keys := VBoxContainer.new()
	keys.name = "Keys"
	keys.add_theme_constant_override(&"separation", 3)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.custom_minimum_size.x = 74.0
	row.add_child(keys)
	var buy := UiTheme.button("", &"amber", UiTheme.SIZE_SMALL)
	buy.name = "Buy"
	buy.custom_minimum_size.y = 24.0
	buy.pressed.connect(_on_buy_cosmetic.bind(id))
	keys.add_child(buy)
	var toggle := UiTheme.button("", &"steel", UiTheme.SIZE_SMALL)
	toggle.name = "Toggle"
	toggle.custom_minimum_size.y = 24.0
	toggle.pressed.connect(_on_toggle_cosmetic.bind(id))
	keys.add_child(toggle)
	return card


func _on_buy_cosmetic(id: StringName) -> void:
	if not GameState.buy_cosmetic(id):
		AudioManager.play_sfx("deny")
		return
	AudioManager.play_sfx("buy")
	SaveManager.request_save(&"cosmetic")
	_refresh()


func _on_toggle_cosmetic(id: StringName) -> void:
	if not GameState.set_cosmetic(id, not GameState.cosmetic_on(id)):
		return
	AudioManager.play_sfx("tap", 0.1)
	SaveManager.request_save(&"cosmetic")
	_refresh()


func _refresh_cosmetics() -> void:
	var list: VBoxContainer = _lists.get("cosmetics")
	if list == null:
		return
	for item: Dictionary in CosmeticDb.all():
		var id := StringName(item.id)
		var card := list.get_node_or_null(NodePath("Decor_%s" % id)) \
			as PanelContainer
		if card == null:
			continue
		var owned := GameState.owns_cosmetic(id)
		var on := GameState.cosmetic_on(id)
		UiTheme.apply_panel(card, UiTheme.card_style(
			&"ready" if on else (&"done" if owned else &"normal")))
		var buy := card.get_node_or_null(^"Row/Keys/Buy") as Button
		var toggle := card.get_node_or_null(^"Row/Keys/Toggle") as Button
		if buy != null:
			buy.visible = not owned
			buy.text = GameState.fmt(float(item.cost))
			buy.disabled = not GameState.can_afford(float(item.cost))
			if CosmeticDb.level_only(id):
				# Not for sale: the roadmap hands it over at its level.
				buy.text = Loc.t("level.short", {"n": str(CosmeticDb.level_of(id))})
				buy.disabled = true
			UiTheme.describe(buy, Loc.t("shop.buy_name", {"name": str(item.name)}),
				Loc.t("shop.cost", {"amount": GameState.fmt(float(item.cost))}))
		if toggle != null:
			toggle.visible = owned
			toggle.text = Loc.t("shop.cosmetics.on" if on
				else "shop.cosmetics.off")
			UiTheme.style_button(toggle, &"amber" if on else &"steel")
			UiTheme.describe(toggle, Loc.t("shop.cosmetics.toggle_off" if on
				else "shop.cosmetics.toggle_on", {"name": str(item.name)}))


func _build_orders() -> void:
	## Standing orders: how the gang is divided between the berths.
	##
	## It lives on the purchase board rather than in the settings because it is
	## not a preference — it changes what the port produces, and it is the answer
	## to a question the player only starts having once they own machines.
	var list: VBoxContainer = _lists["orders"]
	list.add_child(_orders_caption(Loc.t("shop.orders.gang")))
	var intro := UiTheme.label(
		Loc.t("shop.orders.gang.blurb"),
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	intro.name = "Intro"
	# Wrapped, not hard-broken: a Label without autowrap reports the width of its
	# longest line as a minimum, and a Control cannot be laid out narrower than
	# its minimum — one long caption in here was enough to push the whole board
	# 18px wider than a 320px viewport.
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(intro)
	list.add_child(UiTheme.divider())
	for policy: StringName in CraneAllocation.POLICIES:
		var card := PanelContainer.new()
		card.name = "Order_%s" % policy
		UiTheme.apply_panel(card, UiTheme.card_style(&"normal"))
		list.add_child(card)
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
		UiTheme.describe(button, str(CraneAllocation.LABELS[policy]),
			str(CraneAllocation.BLURBS[policy]))
		button.pressed.connect(_on_pick_policy.bind(policy))
		card.add_child(button)
		var row := VBoxContainer.new()
		# Named, because the lamp is looked up by path on every refresh, and an
		# auto-named node turns that lookup into an error printed every time the
		# board is opened.
		row.name = "Row"
		row.add_theme_constant_override(&"separation", 1)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
			Control.PRESET_MODE_MINSIZE, 4)
		card.add_child(row)
		var head := HBoxContainer.new()
		head.name = "Head"
		head.add_theme_constant_override(&"separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(head)
		var lamp := UiTheme.led(UiTheme.Led.OFF)
		lamp.name = "Lamp"
		head.add_child(lamp)
		var title := UiTheme.label(str(CraneAllocation.LABELS[policy]),
			UiTheme.SIZE_SMALL, UiTheme.INK)
		title.name = "Title"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var blurb := UiTheme.label(str(CraneAllocation.BLURBS[policy]),
			UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(blurb)
	_build_rail_orders(list)
	_build_foreman(list)
	_refresh_orders()


func _build_route_orders(list: VBoxContainer) -> void:
	## The third standing order, and the one that made the world map mean
	## something: which lane the port books next. See `RoutePolicy`.
	list.add_child(UiTheme.spacer(4.0))
	list.add_child(UiTheme.divider())
	list.add_child(_orders_caption(Loc.t("shop.orders.lane")))
	for policy: StringName in RoutePolicy.POLICIES:
		var card := PanelContainer.new()
		card.name = "Lane_%s" % policy
		UiTheme.apply_panel(card, UiTheme.card_style(&"normal"))
		list.add_child(card)
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
		UiTheme.describe(button, RoutePolicy.label(policy),
			RoutePolicy.blurb(policy))
		button.pressed.connect(_on_pick_lane_policy.bind(policy))
		card.add_child(button)
		var row := VBoxContainer.new()
		row.name = "Row"
		row.add_theme_constant_override(&"separation", 1)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
			Control.PRESET_MODE_MINSIZE, 4)
		card.add_child(row)
		var head := HBoxContainer.new()
		head.name = "Head"
		head.add_theme_constant_override(&"separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(head)
		var lamp := UiTheme.led(UiTheme.Led.OFF)
		lamp.name = "Lamp"
		head.add_child(lamp)
		var title := UiTheme.label(RoutePolicy.label(policy),
			UiTheme.SIZE_SMALL, UiTheme.INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var blurb := UiTheme.label(RoutePolicy.blurb(policy),
			UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(blurb)


func _on_pick_lane_policy(policy: StringName) -> void:
	if GameState.route_policy == policy:
		return
	GameState.route_policy = RoutePolicy.coerce(policy)
	_refresh_orders()
	AudioManager.play_sfx("tap")
	SaveManager.request_save(&"orders")


func _build_rail_orders(list: VBoxContainer) -> void:
	## The fourth standing order, and the only instrument the branch line has.
	##
	## Every other subsystem is visible from where the player already is: the
	## berth is under the gantry, the gate is on the apron, the yard is the
	## middle of the screen. The branch runs along the very bottom of the world,
	## below the last row of sheds, and the camera does not go looking for it —
	## so an order board with no readout on it would be four buttons wired to
	## something the player has to take on faith. The live line above the cards
	## is that readout.
	var section := VBoxContainer.new()
	section.name = "Branch"
	section.add_theme_constant_override(&"separation", 3)
	list.add_child(section)
	section.add_child(UiTheme.spacer(4.0))
	section.add_child(UiTheme.divider())
	section.add_child(_orders_caption(Loc.t("shop.orders.rail")))

	var status := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(status)

	for order: StringName in RailCargoPolicy.ORDERS:
		var card := PanelContainer.new()
		card.name = "Rail_%s" % order
		UiTheme.apply_panel(card, UiTheme.card_style(&"normal"))
		section.add_child(card)
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
		UiTheme.describe(button, str(RailCargoPolicy.ORDER_LABELS[order]),
			str(RailCargoPolicy.ORDER_BLURBS[order]))
		button.pressed.connect(_on_pick_rail_order.bind(order))
		card.add_child(button)
		var row := VBoxContainer.new()
		row.name = "Row"
		row.add_theme_constant_override(&"separation", 1)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
			Control.PRESET_MODE_MINSIZE, 4)
		card.add_child(row)
		var head := HBoxContainer.new()
		head.name = "Head"
		head.add_theme_constant_override(&"separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(head)
		var lamp := UiTheme.led(UiTheme.Led.OFF)
		lamp.name = "Lamp"
		head.add_child(lamp)
		var title := UiTheme.label(str(RailCargoPolicy.ORDER_LABELS[order]),
			UiTheme.SIZE_SMALL, UiTheme.INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var blurb := UiTheme.label(str(RailCargoPolicy.ORDER_BLURBS[order]),
			UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(blurb)


func _on_pick_rail_order(order: StringName) -> void:
	if GameState.rail_order == order:
		return
	GameState.rail_order = RailCargoPolicy.coerce_order(order)
	_refresh_orders()
	AudioManager.play_sfx("tap")
	SaveManager.request_save(&"orders")


func set_branch(branch: RailYard) -> void:
	## The board reads the branch; it never drives it. `RailYard` decides what a
	## service does, and the only thing a button here changes is the standing
	## order the *next* one is booked with.
	_branch = branch


func _rail_status_text() -> String:
	if _branch == null:
		return ""
	var report := _branch.report()
	if not bool(report.has_branch):
		# Honest about what it is: without the bought branch the terminal still
		# gets a trip freight, and a player wondering why their train is short
		# deserves the answer on the same board as the order.
		return Loc.t("shop.rail.none")
	if bool(report.idle):
		return Loc.t("shop.rail.idle",
			{"seconds": int(ceilf(float(report.eta)))})
	if bool(report.standing):
		return Loc.t("shop.rail.working", {
			"inbound": int(report.drops), "outbound": int(report.lifts),
			"seconds": int(ceilf(float(report.dwell)))})
	match int(report.stage):
		int(RailYard.Stage.ARRIVING):
			return Loc.t("shop.rail.arriving")
		int(RailYard.Stage.RUNAROUND):
			return Loc.t("shop.rail.runaround")
		_:
			return Loc.t("shop.rail.departing",
				{"done": int(report.moved), "total": int(report.booked)})


func _orders_caption(text: String) -> Control:
	var caption := UiTheme.label(text, UiTheme.SIZE_SMALL, UiTheme.INK)
	caption.name = "Caption_%s" % text
	return caption


func _build_foreman(list: VBoxContainer) -> void:
	## The other half of the standing orders: what gets bought when nobody is
	## looking. Same board as the gang, because they are the same question asked
	## about two different resources.
	var section := VBoxContainer.new()
	section.name = "Foreman"
	section.add_theme_constant_override(&"separation", 3)
	list.add_child(section)
	section.add_child(UiTheme.spacer(4.0))
	section.add_child(UiTheme.divider())
	section.add_child(_orders_caption(Loc.t("shop.orders.foreman")))
	var intro := UiTheme.label(
		Loc.t("shop.orders.foreman.blurb"),
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(intro)

	# Above the controls it disables, not below them: the reason has to arrive
	# before the greyed-out row, or the row just reads as broken.
	var locked := UiTheme.label(
		Loc.t("shop.orders.foreman.locked"),
		UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	locked.name = "Locked"
	locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(locked)

	var modes := HBoxContainer.new()
	modes.name = "Modes"
	modes.add_theme_constant_override(&"separation", 2)
	section.add_child(modes)
	for mode: StringName in Foreman.MODES:
		var button := UiTheme.segment(str(Foreman.LABELS[mode]),
			GameState.foreman_mode == mode)
		button.name = "Mode_%s" % mode
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.describe(button, str(Foreman.LABELS[mode]),
			str(Foreman.BLURBS[mode]))
		button.pressed.connect(_on_pick_foreman.bind(mode))
		modes.add_child(button)
	var blurb := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	blurb.name = "ModeBlurb"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(blurb)

	var reserve_row := HBoxContainer.new()
	reserve_row.name = "Reserve"
	reserve_row.add_theme_constant_override(&"separation", 2)
	section.add_child(reserve_row)
	var reserve_caption := UiTheme.label(Loc.t("shop.orders.reserve"),
		UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	reserve_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reserve_row.add_child(reserve_caption)
	for value: float in Foreman.RESERVES:
		var button := UiTheme.segment(str(Foreman.RESERVE_LABELS[value]),
			is_equal_approx(GameState.foreman_reserve, value))
		button.name = "Reserve_%d" % roundi(value * 100.0)
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.describe(button, Loc.t("shop.orders.reserve.name",
			{"percent": str(Foreman.RESERVE_LABELS[value])}),
			Loc.t("shop.orders.reserve.hint"))
		button.pressed.connect(_on_pick_reserve.bind(value))
		reserve_row.add_child(button)


func _on_pick_foreman(mode: StringName) -> void:
	GameState.foreman_mode = Foreman.coerce(mode)
	_refresh_orders()
	AudioManager.play_sfx("tap")
	SaveManager.request_save(&"orders")


func _on_pick_reserve(value: float) -> void:
	GameState.foreman_reserve = Foreman.coerce_reserve(value)
	_refresh_orders()
	AudioManager.play_sfx("tap")
	SaveManager.request_save(&"orders")


func _on_pick_policy(policy: StringName) -> void:
	if GameState.crane_policy == policy:
		return
	GameState.crane_policy = CraneAllocation.coerce(policy)
	_refresh_orders()
	AudioManager.play_sfx("tap")
	SaveManager.request_save(&"orders")


func _apply_level_gates() -> void:
	## Tabs appear as the terminal grows (docs/plans/plano-release.md, 2.3). A tab
	## the player has not earned is not there to be puzzled over — and if the
	## sheet is open on one that just went away, it falls back to machines.
	var gates := {"upgrades": &"upgrades", "land": &"land", "cosmetics": &"decor"}
	for tab: String in gates:
		var button: Button = _tab_buttons.get(tab)
		if button != null:
			button.visible = FeatureGate.unlocked(gates[tab])
	var open_button: Button = _tab_buttons.get(_active)
	if _open and open_button != null and not open_button.visible:
		_on_tab("structures")


func _update_orders_tab() -> void:
	## Rule 10: depth reveals itself. A port with one berth has no allocation to
	## decide, so the tab that decides it is not there to be puzzled over yet.
	##
	## Driven from `_refresh` rather than only from `_layout`, because the quay
	## grows when a parcel is bought and nothing about that resizes the window —
	## the capture matrix caught the tab staying hidden on a two-berth port right
	## up until something else happened to trigger a layout pass.
	var tab: Button = _tab_buttons.get("orders")
	if tab == null:
		return
	# A second lane is reason enough on its own now: from the moment the port
	# trades on two, which one it books next is a decision.
	tab.visible = (PortLayout.berth_count() > 1 or GameState.prestige_count > 0) \
		and FeatureGate.unlocked(&"orders")
	if not tab.visible and _active == "orders":
		_on_tab("structures")


func _refresh_orders() -> void:
	var list: VBoxContainer = _lists.get("orders")
	if list == null:
		return
	for policy: StringName in CraneAllocation.POLICIES:
		var card := list.get_node_or_null(NodePath("Order_%s" % policy)) \
			as PanelContainer
		if card == null:
			continue
		var chosen := GameState.crane_policy == policy
		UiTheme.apply_panel(card, UiTheme.card_style(
			&"ready" if chosen else &"normal"))
		var lamp := card.get_node_or_null(^"Row/Head/Lamp") as TextureRect
		if lamp != null:
			lamp.texture = UiTheme.led_texture(
				UiTheme.Led.ATTENTION if chosen else UiTheme.Led.OFF)
	for policy: StringName in RoutePolicy.POLICIES:
		var lane_card := list.get_node_or_null(NodePath("Lane_%s" % policy)) \
			as PanelContainer
		if lane_card == null:
			continue
		var picked := GameState.route_policy == policy
		UiTheme.apply_panel(lane_card, UiTheme.card_style(
			&"ready" if picked else &"normal"))
		var lane_lamp := lane_card.get_node_or_null(^"Row/Head/Lamp") as TextureRect
		if lane_lamp != null:
			lane_lamp.texture = UiTheme.led_texture(
				UiTheme.Led.ATTENTION if picked else UiTheme.Led.OFF)
	_refresh_branch(list)
	_refresh_foreman(list)


func _refresh_branch(list: VBoxContainer) -> void:
	var section := list.get_node_or_null(^"Branch") as VBoxContainer
	if section == null:
		return
	var status := section.get_node_or_null(^"Status") as Label
	if status != null:
		status.text = _rail_status_text()
		status.visible = not status.text.is_empty()
	for order: StringName in RailCargoPolicy.ORDERS:
		var card := section.get_node_or_null(NodePath("Rail_%s" % order)) \
			as PanelContainer
		if card == null:
			continue
		var picked := GameState.rail_order == order
		UiTheme.apply_panel(card, UiTheme.card_style(
			&"ready" if picked else &"normal"))
		var lamp := card.get_node_or_null(^"Row/Head/Lamp") as TextureRect
		if lamp != null:
			lamp.texture = UiTheme.led_texture(
				UiTheme.Led.ATTENTION if picked else UiTheme.Led.OFF)


func _refresh_foreman(list: VBoxContainer) -> void:
	var section := list.get_node_or_null(^"Foreman") as VBoxContainer
	if section == null:
		return
	var unlocked := GameState.foreman_unlocked()
	# Shown locked rather than hidden: the point of it is to be a reason to
	# rebuild, and a reason nobody can see is not one.
	for name_path in ["Modes", "Reserve"]:
		var row := section.get_node_or_null(NodePath(name_path)) as Control
		if row != null:
			row.modulate = Color(1, 1, 1, 1) if unlocked else Color(1, 1, 1, 0.45)
	var locked := section.get_node_or_null(^"Locked") as Label
	if locked != null:
		locked.visible = not unlocked
	var modes := section.get_node_or_null(^"Modes") as HBoxContainer
	if modes != null:
		for mode: StringName in Foreman.MODES:
			var button := modes.get_node_or_null(
				NodePath("Mode_%s" % mode)) as Button
			if button != null:
				button.disabled = not unlocked
				UiTheme.style_segment(button, GameState.foreman_mode == mode)
	var reserve := section.get_node_or_null(^"Reserve") as HBoxContainer
	if reserve != null:
		for value: float in Foreman.RESERVES:
			var button := reserve.get_node_or_null(
				NodePath("Reserve_%d" % roundi(value * 100.0))) as Button
			if button != null:
				button.disabled = not unlocked \
					or GameState.foreman_mode == Foreman.OFF
				UiTheme.style_segment(button,
					is_equal_approx(GameState.foreman_reserve, value))
	var blurb := section.get_node_or_null(^"ModeBlurb") as Label
	if blurb != null:
		blurb.text = str(Foreman.BLURBS.get(GameState.foreman_mode, ""))


func _update_tab_badges() -> void:
	## A tab only shouts when something on it is actually buyable right now.
	var ready_upgrades := 0
	for item in UpgradeDB.ITEMS:
		# `upgrade_available` and not `upgrade_unlocked`: with the whole tree on the
		# tab, a node whose parent is unbought is visible and priced but not
		# buyable, and a badge that counted it would send the player to a tab where
		# nothing can be pressed.
		if not GameState.has_upgrade(item.id) and GameState.upgrade_available(item) \
				and GameState.can_afford(UpgradeDB.price_for(item, GameState.upgrades)):
			ready_upgrades += 1
	var button: Button = _tab_buttons.get("upgrades")
	if button == null:
		return
	var base := Loc.t(str(TABS[1][1]))
	button.text = "%s %d" % [base, ready_upgrades] if ready_upgrades > 0 else base


# --------------------------------------------------------------------- state

func _on_tab(tab_name: String) -> void:
	if tab_name != _active:
		AudioManager.play_sfx("ui_tab", 0.02, -3.0)
	if _open and _active == tab_name:
		_close()
		return
	_active = tab_name
	for key: String in _scrolls:
		_scrolls[key].visible = key == tab_name
	for key: String in _tab_buttons:
		UiTheme.style_tab(_tab_buttons[key], key == tab_name)
	_bulk_row.visible = tab_name == "structures"
	if tab_name == "orders":
		_refresh_orders()
	var was_open := _open
	if not _open:
		_open_sheet()
	_refresh()
	if was_open:
		# A tab change deals the new list in, row by row, a frame after the
		# container has placed it.
		_deal_tab.call_deferred(tab_name)
	AudioManager.play_sfx("tap")


func _deal_tab(tab_name: String) -> void:
	# The page was hidden until this frame, so it has no size until the next;
	# it waits that frame unseen, or the list shows whole and then deals in.
	var page: Control = _scrolls.get(tab_name)
	if page == null or not UiMotion.live():
		return
	page.modulate.a = 0.0
	await get_tree().process_frame
	page.modulate.a = 1.0
	if _open and _active == tab_name and _scrolls.has(tab_name):
		UiMotion.cascade(UiMotion.scroll_items(_scrolls[tab_name]), 0.0, 0.03, 12.0)


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
	UiTheme.pop_open(_board, _backdrop)


func _close() -> void:
	if not _open:
		return
	_open = false
	# The board drops out of frame and `_layout` hides it when it has gone;
	# everything the game reads (`_open`, focus, the signal) changes now.
	UiTheme.pop_close(_board, _backdrop, _layout)
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
		if not GameState.has_upgrade(item.id) and GameState.upgrade_available(item) \
				and GameState.can_afford(UpgradeDB.price_for(item, GameState.upgrades)):
			return true
	var parcel := LandDB.next_parcel(GameState.land)
	return not parcel.is_empty() and GameState.can_afford(float(parcel.cost))


func next_purchase_eta() -> float:
	## Seconds until the cheapest thing the player can see becomes affordable, or
	## -1 when there is nothing to wait for.
	##
	## The console shows this so a wait always has a size. It answers with the
	## *cheapest* purchase rather than the best one on purpose: the question it
	## is standing in for is "is it worth staying?", and that is answered by the
	## soonest thing that can happen, not the one with the best payback.
	##
	## Always priced at x1 regardless of the buy mode. The mode is a convenience
	## for spending a full treasury; it must not make the countdown to the next
	## decision look ten times further away than it is.
	var cheapest := INF
	for item in StructureDB.ITEMS:
		var count := GameState.structure_count(item.id)
		if count == 0 and GameState.lifetime_teus < float(item.cost) * 0.25:
			continue
		cheapest = minf(cheapest, GameState.structure_cost(item.id))
	for item in UpgradeDB.ITEMS:
		if not GameState.has_upgrade(item.id) and GameState.upgrade_available(item):
			cheapest = minf(cheapest, UpgradeDB.price_for(item, GameState.upgrades))
	var parcel := LandDB.next_parcel(GameState.land)
	if not parcel.is_empty():
		cheapest = minf(cheapest, float(parcel.cost))
	if is_inf(cheapest):
		return -1.0
	var missing := cheapest - GameState.teus
	if missing <= 0.0:
		return 0.0
	# A port with no passive income never gets there by waiting, and a countdown
	# that only moves when the player taps is a lie about what waiting does.
	return missing / GameState.cps if GameState.cps > 0.0 else -1.0


# -------------------------------------------------------------------- layout

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	var height := minf(safe.size.y * 0.84, 620.0)
	(_lists["structures"] as GridContainer).columns = \
		clampi(int((safe.size.x - 40.0) / 150.0), 2, 5)
	_board.size = Vector2(safe.size.x - 12.0, height)
	_board.position = Vector2(safe.position.x + 6.0, safe.end.y - height - 6.0)
	for index in TABS.size():
		var tab: Array = TABS[index]
		var tab_button: Button = _tab_buttons.get(tab[0])
		if tab_button != null:
			tab_button.text = Loc.t(str(tab[1]))
	_update_tab_badges()
	_update_orders_tab()
	if _ticket_effect != null:
		# Autowrap needs a real width before the column asks it for a height.
		_ticket_effect.custom_minimum_size.x = _board.size.x - 40.0

	_backdrop.visible = _open
	_board.visible = _open
	UiTheme.place_clip(_clip, _board, safe)
	# The console owns the LOJA key; the standalone launcher is only a fallback
	# for a shop hosted without one (previews and tests).
	_launcher.visible = not _open and _rail == null
	_launcher.size = Vector2(118.0, 38.0)
	_launcher.position = Vector2(
		safe.position.x + (safe.size.x - _launcher.size.x) * 0.5,
		safe.end.y - 46.0)


func set_rail(rail: CommandRail) -> void:
	## Only so the shop knows a console is hosting it and can drop its own
	## fallback launcher.
	_rail = rail


func toggle() -> void:
	if _open:
		_close()
	else:
		_on_tab(_active)


func launcher_rect() -> Rect2:
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
	var card: ShopCard = _cards.get("up_" + id)
	if GameState.buy_upgrade(id):
		AudioManager.play_sfx("upgrade")
		if card != null:
			card.flash_ok()
	elif card != null:
		card.shake_deny()
		AudioManager.play_sfx("deny")


func _on_buy_land(id: String) -> void:
	var card: ShopCard = _cards.get("land_" + id)
	var item := LandDB.get_item(id)
	if GameState.land.has(id):
		return
	var next := LandDB.next_parcel(GameState.land)
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
	_apply_level_gates()
	_update_orders_tab()
	_refresh_cosmetics()
	if _active == "orders":
		# The board is live: rebuilding the port while it is open hires the
		# foreman, and the row that was greyed out has to stop being greyed out
		# without the player closing and reopening it.
		_refresh_orders()
	var next_locked := {}
	for item in StructureDB.ITEMS:
		var card: ShopCard = _cards.get(item.id)
		if card == null:
			continue
		var count := GameState.structure_count(item.id)
		var quote := GameState.structure_purchase_quote(item.id, _buy_mode)
		var gate := GameState.structure_gate(str(item.id))
		var revealed: bool = count > 0 \
			or GameState.lifetime_teus >= float(item.cost) * 0.25
		card.visible = revealed
		if not revealed:
			if next_locked.is_empty():
				next_locked = item
			continue
		# A machine waiting on ground says so on its own card, with the name of
		# the parcel. Greying it out and saying nothing is the same as a bug.
		if not gate.is_empty():
			card.set_effect("")
			card.show_gated(Loc.t("shop.needs_land",
				{"name": str(gate.get("name", ""))}),
				float(quote.get("total_cost", INF)))
			continue
		card.set_effect("")
		card.refresh(float(quote.get("total_cost", INF)), count,
			bool(quote.get("ok", false)), false,
			int(quote.get("quantity", 0)),
			float(quote.get("nominal_cps_gain", 0.0)))
	_refresh_teaser(next_locked)

	_refresh_upgrades()

	var next := LandDB.next_parcel(GameState.land)
	for item in LandDB.ITEMS:
		var card: ShopCard = _cards.get("land_" + item.id)
		if card == null:
			continue
		var owned: bool = GameState.land.has(item.id)
		var is_next: bool = not next.is_empty() and next.id == item.id
		card.visible = owned or is_next
		card.refresh(item.cost, 0,
			is_next and GameState.can_afford(item.cost), owned)
	if _land_empty != null:
		_land_empty.visible = next.is_empty()


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
	_teaser.show_locked("???", Loc.t("shop.teaser",
		{"amount": GameState.fmt(float(item.cost) * 0.25)}))
