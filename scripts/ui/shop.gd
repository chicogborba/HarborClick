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
## The parcel being paved: its name, a clock, a bar and the key that skips it.
var _works: Dictionary = {}
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
## The upgrades tab: one list — what can be bought, what is next, what is owned.
var _up_summary: Label
## Buys every affordable upgrade, cheapest first. With ~90 nodes on the tree,
## tapping each card in turn was the tab's most repeated chore.
var _up_buy_all: Button
var _up_list: VBoxContainer
var _up_caption_ready: Control
var _up_caption_next: Control
var _up_more: Label
var _up_owned_toggle: Button
var _up_owned_open := false
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
	EventBus.land_works_changed.connect(func() -> void: _dirty = true)
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
	## A list of what can be bought.
	##
	## It answers the three questions in the order a player asks them — what can
	## I buy now, what is next, what have I got — and every card says what it
	## does and what it costs without a tap.
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
	_up_buy_all = UiTheme.button(Loc.t("shop.upgrades.buy_all"), &"go",
		UiTheme.SIZE_SMALL)
	_up_buy_all.name = "BuyAll"
	_up_buy_all.custom_minimum_size = Vector2(0.0, 24.0)
	_up_buy_all.pressed.connect(_on_buy_all_upgrades)
	head.add_child(_up_buy_all)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiTheme.style_scroll(scroll)
	page.add_child(scroll)
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
	_up_buy_all.disabled = ready == 0
	UiTheme.style_button(_up_buy_all, &"go" if ready > 0 else &"off")
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
const CHIP_RAIL := Color8(76, 88, 112)


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
		"rail_stat":
			chips.append({"text": Loc.t("shop.chip.rail"), "color": CHIP_RAIL,
				"icon": UiTheme.Icon.TRAIN})
	return chips


static func _ids(items: Array[Dictionary]) -> String:
	var out := PackedStringArray()
	for item in items:
		out.append(str(item.id))
	return ",".join(out)


func _pointer_down() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _refresh_upgrades() -> void:
	## Runs off the shop's refresh timer while the tab is open. Nothing is
	## rebuilt: the list only moves and restyles the cards it built once.
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
	_build_works_card(list)
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


func _build_works_card(list: VBoxContainer) -> void:
	## Ground is made, not bought: paying for a parcel starts the works, and
	## this is where they are watched — and skipped, for an advertisement.
	var card := UiTheme.panel(UiTheme.card_style(&"ready"), false)
	card.visible = false
	list.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	card.add_child(col)
	var title := UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.AMBER_DEEP)
	title.clip_text = true
	col.add_child(title)
	var bar := ProgressBar.new()
	var styles := UiTheme.bar_styles()
	bar.add_theme_stylebox_override(&"background", styles[0])
	bar.add_theme_stylebox_override(&"fill", styles[1])
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	var left := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	left.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.custom_minimum_size.x = 120.0
	col.add_child(left)
	var skip := UiTheme.button(Loc.t("shop.land.skip"), &"amber", UiTheme.SIZE_SMALL)
	skip.icon = UiTheme.icon16_texture(UiTheme.Icon16.AD)
	skip.custom_minimum_size.y = UiTheme.TOUCH_MIN
	skip.pressed.connect(_on_skip_land_works)
	col.add_child(skip)
	_works = {"card": card, "title": title, "bar": bar, "left": left, "skip": skip}


func _refresh_works_card() -> void:
	if _works.is_empty() or not is_instance_valid(_works.card):
		return
	var works := GameState.land_works
	(_works.card as Control).visible = not works.is_empty()
	if works.is_empty():
		return
	var total := maxf(1.0, float(works.total))
	var left := maxf(0.0, float(works.left))
	(_works.title as Label).text = Loc.t("shop.land.works",
		{"name": str(LandDB.get_item(str(works.id)).get("name", ""))})
	(_works.bar as ProgressBar).value = 1.0 - left / total
	(_works.left as Label).text = Loc.t("shop.land.works.left",
		{"time": "%d:%02d" % [int(left) / 60, int(left) % 60]})
	(_works.skip as Button).visible = AdService.available(&"land_skip")


func _on_skip_land_works() -> void:
	if GameState.land_works.is_empty():
		return
	if not AdService.show_rewarded(&"land_skip", GameState.finish_land_works):
		AudioManager.play_sfx("deny")


## The decor tab: a filter, a collection meter, and one tile per piece.
var _decor_filter: StringName = &"all"
var _decor_tiles: Dictionary = {}
var _decor_filters: Dictionary = {}
var _decor_count: Label
var _decor_bar: ProgressBar
var _decor_grid: GridContainer
const DECOR_ICONS := preload("res://assets/sprites/ui_decor_icons.png")
const DECOR_ICON_SIZE := Vector2(48, 40)


static func _decor_texture(id: StringName) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = DECOR_ICONS
	atlas.region = Rect2(Vector2(CosmeticDb.art_of(id) * DECOR_ICON_SIZE.x, 0),
		DECOR_ICON_SIZE)
	return atlas


func _build_cosmetics() -> void:
	## The decor tab is built the way the equipment tab is: a shelf of tiles two
	## abreast, each with the piece standing in its well, its name, one line of
	## what it does, and a key across the foot that does the one thing that
	## piece needs — buy it, or switch it on and off. No showcase to pick into
	## first: the tile *is* the control, like every other tile on this board.
	var list: VBoxContainer = _lists["cosmetics"]
	_decor_tiles.clear()
	_decor_filters.clear()

	# --- the collection meter (the same card the ship album opens with) -------
	var meter := PanelContainer.new()
	meter.name = "DecorMeter"
	UiTheme.apply_panel(meter, UiTheme.card_style(&"normal"))
	list.add_child(meter)
	var meter_col := VBoxContainer.new()
	meter_col.add_theme_constant_override(&"separation", 3)
	meter.add_child(meter_col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 6)
	meter_col.add_child(head)
	var glyph := TextureRect.new()
	glyph.texture = _decor_texture(&"duck")
	glyph.custom_minimum_size = DECOR_ICON_SIZE * 0.75
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", 3)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(texts)
	_decor_count = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.AMBER_DEEP)
	_decor_count.name = "DecorCount"
	texts.add_child(_decor_count)
	_decor_bar = ProgressBar.new()
	var styles := UiTheme.bar_styles()
	_decor_bar.add_theme_stylebox_override(&"background", styles[0])
	_decor_bar.add_theme_stylebox_override(&"fill", styles[1])
	_decor_bar.show_percentage = false
	_decor_bar.custom_minimum_size = Vector2(0, 8)
	_decor_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_decor_bar)

	# --- filters: the same segmented bar as the equipment tab's LOTE ----------
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 3)
	list.add_child(bar)
	for pair: Array in [[&"all", "shop.cosmetics.all"],
			[CosmeticDb.KIND_PORT, "shop.cosmetics.port"],
			[CosmeticDb.KIND_CREW, "shop.cosmetics.crew"]]:
		var chip := UiTheme.segment(Loc.t(pair[1]), pair[0] == _decor_filter)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size.y = 24.0
		var key: StringName = pair[0]
		chip.pressed.connect(func() -> void:
			_decor_filter = key
			AudioManager.play_sfx("ui_tab", 0.05)
			_refresh_cosmetics())
		bar.add_child(chip)
		_decor_filters[key] = chip

	# --- the shelf -------------------------------------------------------------
	_decor_grid = GridContainer.new()
	_decor_grid.name = "DecorGrid"
	_decor_grid.columns = 2
	_decor_grid.add_theme_constant_override(&"h_separation", 4)
	_decor_grid.add_theme_constant_override(&"v_separation", 4)
	_decor_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(_decor_grid)
	for item: Dictionary in _decor_order():
		var tile := _cosmetic_tile(item)
		_decor_grid.add_child(tile)
		_decor_tiles[StringName(item.id)] = tile

	var intro := UiTheme.label(Loc.t("shop.cosmetics.blurb"), UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(intro)


func _decor_order() -> Array[Dictionary]:
	## The port's pieces first: they are what changes the view, and what a
	## player opening the shelf for the first time should see.
	var port: Array[Dictionary] = []
	var crew: Array[Dictionary] = []
	for item: Dictionary in CosmeticDb.all():
		if StringName(item.kind) == CosmeticDb.KIND_PORT:
			port.append(item)
		else:
			crew.append(item)
	return port + crew


func _cosmetic_tile(item: Dictionary) -> Button:
	## One piece, as an equipment-style tile. The whole tile is the key; the
	## coloured bar across its foot only says what pressing it will do.
	var id := StringName(item.id)
	var tile := Button.new()
	tile.name = "Decor_%s" % id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.focus_mode = Control.FOCUS_ALL
	tile.custom_minimum_size.y = 168.0
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_top = 6
	column.offset_right = -6
	column.offset_bottom = -6
	tile.add_child(column)

	var well := UiTheme.panel(UiTheme.well_style(2))
	well.name = "Well"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size.y = DECOR_ICON_SIZE.y * 2.0 + 6.0
	column.add_child(well)
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = _decor_texture(id)
	art.custom_minimum_size = DECOR_ICON_SIZE * 2.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(art)
	# "Ligado" as a stamp in the corner of the well, where the equipment tiles
	# carry their count: the state is read off the picture, not hunted for.
	var stamp := UiTheme.panel(UiTheme.slate_style(true, 2))
	stamp.name = "OnStamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
	stamp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stamp.visible = false
	well.add_child(stamp)
	var stamp_row := HBoxContainer.new()
	stamp_row.add_theme_constant_override(&"separation", 2)
	stamp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_child(stamp_row)
	var check := UiTheme.icon(UiTheme.Icon.CHECK)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_row.add_child(check)

	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override(&"separation", 3)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_row)
	var lock := UiTheme.icon(UiTheme.Icon.LOCK)
	lock.name = "Lock"
	lock.modulate = UiTheme.INK_SOFT
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(lock)
	var label := UiTheme.label(str(item.name), UiTheme.SIZE_BODY, UiTheme.INK)
	label.name = "Name"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(label)

	var desc := UiTheme.label(str(item.desc), UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(desc)

	var key := UiTheme.panel(UiTheme.nine("ui_btn_off", 5, 4))
	key.name = "Key"
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.custom_minimum_size.y = 24.0
	column.add_child(key)
	var key_label := UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK_SOFT)
	key_label.name = "Value"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(key_label)

	tile.pressed.connect(func() -> void: _on_decor_tile(id))
	return tile


func _on_decor_tile(id: StringName) -> void:
	## The tile does whatever its key says: buy what is for sale, switch what is
	## owned, and refuse — audibly — what the wallet or the level cannot reach.
	if GameState.owns_cosmetic(id):
		_on_toggle_cosmetic(id)
	elif CosmeticDb.level_only(id):
		AudioManager.play_sfx("deny")
	else:
		_on_buy_cosmetic(id)


func _on_buy_cosmetic(id: StringName) -> void:
	if not GameState.buy_cosmetic(id):
		AudioManager.play_sfx("deny")
		return
	AudioManager.play_sfx("buy")
	SaveManager.request_save(&"cosmetic")
	var tile := _decor_tiles.get(id) as Control
	if tile != null and UserPreferences.can_animate():
		UiMotion.punch(tile)
	_refresh()


func _on_toggle_cosmetic(id: StringName) -> void:
	if not GameState.set_cosmetic(id, not GameState.cosmetic_on(id)):
		return
	AudioManager.play_sfx("tap", 0.1)
	SaveManager.request_save(&"cosmetic")
	_refresh()


func _decor_state(id: StringName) -> Dictionary:
	## What a tile shows: {card, key, text, ink}. `card` is the tile's frame,
	## `key` the sprite of the bar across its foot.
	var item := CosmeticDb.of(id)
	if GameState.cosmetic_on(id):
		return {"card": &"done", "key": "ui_btn", "text": Loc.t("shop.cosmetics.on"),
			"ink": UiTheme.KEY_INK}
	if GameState.owns_cosmetic(id):
		return {"card": &"normal", "key": "ui_btn_steel",
			"text": Loc.t("shop.cosmetics.off"), "ink": UiTheme.STEEL_TEXT}
	if CosmeticDb.level_only(id):
		return {"card": &"locked", "key": "ui_btn_off",
			"text": Loc.t("level.short", {"n": str(CosmeticDb.level_of(id))}),
			"ink": UiTheme.INK_SOFT}
	var price := float(item.get("cost", 0.0))
	if GameState.can_afford(price):
		return {"card": &"ready", "key": "ui_btn_go", "text": GameState.fmt(price),
			"ink": UiTheme.CREAM}
	return {"card": &"normal", "key": "ui_btn_off", "text": GameState.fmt(price),
		"ink": UiTheme.INK_SOFT}


func _refresh_cosmetics() -> void:
	if _decor_grid == null or not is_instance_valid(_decor_grid):
		return
	_decor_grid.columns = 2 if _board == null else \
		clampi(int((_board.size.x - 28.0) / 150.0), 2, 4)
	var owned := 0
	for item: Dictionary in CosmeticDb.all():
		var id := StringName(item.id)
		var mine := GameState.owns_cosmetic(id)
		if mine:
			owned += 1
		var tile := _decor_tiles.get(id) as Button
		if tile == null or not is_instance_valid(tile):
			continue
		tile.visible = _decor_filter == &"all" or StringName(item.kind) == _decor_filter
		var look := _decor_state(id)
		var card: StringName = look.card
		if tile.get_meta(&"look", "") == str(look):
			continue
		tile.set_meta(&"look", str(look))
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			tile.add_theme_stylebox_override(state, UiTheme.card_style(card))
		var art := tile.get_node(^"Column/Well/Art") as TextureRect
		# Pieces you cannot have yet are shown dimmed, never hidden: the shelf
		# is also the list of what there is to want.
		art.modulate = Color.WHITE if mine or card == &"ready" else Color(0.62, 0.64, 0.68)
		(tile.get_node(^"Column/Well/OnStamp") as Control).visible = \
			GameState.cosmetic_on(id)
		(tile.get_node(^"Column/NameRow/Lock") as Control).visible = \
			CosmeticDb.level_only(id) and not mine
		var name_label := tile.get_node(^"Column/NameRow/Name") as Label
		name_label.label_settings = UiTheme.settings(UiTheme.SIZE_BODY,
			UiTheme.INK if mine or card == &"ready" else UiTheme.INK_SOFT)
		var key := tile.get_node(^"Column/Key") as PanelContainer
		UiTheme.apply_panel(key, UiTheme.nine(str(look.key), 5, 4))
		var value := tile.get_node(^"Column/Key/Value") as Label
		value.text = str(look.text)
		value.label_settings = UiTheme.settings(UiTheme.SIZE_BODY, look.ink)
		if mine:
			UiTheme.describe(tile, str(item.name), Loc.t(
				"shop.cosmetics.toggle_off" if GameState.cosmetic_on(id)
				else "shop.cosmetics.toggle_on", {"name": str(item.name)}))
		else:
			UiTheme.describe(tile, str(item.name), "%s • %s" % [str(item.desc),
				str(look.text)])
	for key: StringName in _decor_filters:
		UiTheme.style_segment(_decor_filters[key], key == _decor_filter)
	var total := CosmeticDb.all().size()
	_decor_count.text = Loc.t("shop.cosmetics.count", {"n": str(owned), "total": str(total)})
	_decor_bar.max_value = float(total)
	_decor_bar.value = float(owned)


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
	# The tab is retired: booking orders and the foreman's switches were a page
	# nobody opened. The rules behind it keep their defaults.
	tab.visible = false
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
	# Ground shouts the same way: a parcel that can be paid for right now.
	var land_tab: Button = _tab_buttons.get("land")
	if land_tab != null:
		var parcel := GameState.next_land()
		var ready_land := not parcel.is_empty() and GameState.can_afford(float(parcel.cost))
		var land_base := Loc.t(str(TABS[2][1]))
		land_tab.text = "%s 1" % land_base if ready_land else land_base


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
	var parcel := GameState.next_land()
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
	var parcel := GameState.next_land()
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


func buy_all_upgrades() -> int:
	## Cheapest first, and again after each pass: a purchase can open the next
	## node down its trunk, which may itself be affordable now.
	var bought := 0
	var guard := 0
	while guard < 32:
		guard += 1
		var candidates: Array[Dictionary] = []
		for item in UpgradeDB.ITEMS:
			if not GameState.has_upgrade(str(item.id)) and GameState.upgrade_available(item) \
					and GameState.can_afford(float(item.cost)):
				candidates.append(item)
		if candidates.is_empty():
			break
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.cost) < float(b.cost))
		var progressed := false
		for item in candidates:
			if GameState.buy_upgrade(str(item.id)):
				bought += 1
				progressed = true
		if not progressed:
			break
	return bought


func _on_buy_all_upgrades() -> void:
	var bought := buy_all_upgrades()
	if bought <= 0:
		AudioManager.play_sfx("deny")
		return
	AudioManager.play_sfx("upgrade")
	EventBus.notification_requested.emit({
		"id": "upgrades_bought", "kind": &"unlock", "priority": 1,
		"text": Loc.t("shop.upgrades.bought_all", {"n": str(bought)}),
	})
	_refresh_upgrades()


func _on_buy_land(id: String) -> void:
	var card: ShopCard = _cards.get("land_" + id)
	if GameState.land.has(id):
		return
	if not GameState.start_land_works(id):
		if card != null:
			card.shake_deny()
		AudioManager.play_sfx("deny")
		return
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

	var next := GameState.next_land()
	for item in LandDB.ITEMS:
		var card: ShopCard = _cards.get("land_" + item.id)
		if card == null:
			continue
		var owned: bool = GameState.land.has(item.id)
		var is_next: bool = not next.is_empty() and next.id == item.id
		card.visible = owned or is_next
		card.refresh(item.cost, 0,
			is_next and GameState.can_afford(item.cost), owned)
	_refresh_works_card()
	if _land_empty != null:
		_land_empty.visible = next.is_empty() and GameState.land_works.is_empty()


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
