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

const TABS := [
	["structures", "EQUIP.", UiTheme.Icon.CRANE],
	["upgrades", "MELH.", UiTheme.Icon.STAR],
	["land", "TERRA", UiTheme.Icon.LAND],
	["orders", "ORDENS", UiTheme.Icon.SHIP],
]
const BUY_MODES: Array[StringName] = [&"x1", &"x10", &"x25", &"max"]
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
var _safe_rect := Rect2()
var _profile := ""
var _buy_mode: StringName = &"x1"
var _focus_return: Control
var _rail: CommandRail
## The railway, not the console. `_rail` is the bottom bar; this is the branch
## line, and the orders board is the only screen it reports to.
var _branch: RailYard


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
	_build_orders()


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
		card.set_effect(str(GameState.upgrade_preview(item).get("text", "")))
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


func _build_orders() -> void:
	## Standing orders: how the gang is divided between the berths.
	##
	## It lives on the purchase board rather than in the settings because it is
	## not a preference — it changes what the port produces, and it is the answer
	## to a question the player only starts having once they own machines.
	var list: VBoxContainer = _lists["orders"]
	list.add_child(_orders_caption("A GANGUE"))
	var intro := UiTheme.label(
		"A gangue é uma só. Com mais de um berço trabalhando, você decide quem leva as máquinas.",
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
	_build_route_orders(list)
	_build_rail_orders(list)
	_build_foreman(list)
	_refresh_orders()


func _build_route_orders(list: VBoxContainer) -> void:
	## The third standing order, and the one that made the world map mean
	## something: which lane the port books next. See `RoutePolicy`.
	list.add_child(UiTheme.spacer(4.0))
	list.add_child(UiTheme.divider())
	list.add_child(_orders_caption("ROTA DA PRÓXIMA ESCALA"))
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
		UiTheme.describe(button, str(RoutePolicy.LABELS[policy]),
			str(RoutePolicy.BLURBS[policy]))
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
		var title := UiTheme.label(str(RoutePolicy.LABELS[policy]),
			UiTheme.SIZE_SMALL, UiTheme.INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var blurb := UiTheme.label(str(RoutePolicy.BLURBS[policy]),
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
	section.add_child(_orders_caption("O RAMAL FERROVIÁRIO"))

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
		return "Sem ramal próprio: o interior manda um frete curto de vez em quando."
	if bool(report.idle):
		return "Linha livre. Próximo trem em %ds." % int(ceilf(float(report.eta)))
	if bool(report.standing):
		return "No ramal agora: %d para descarregar, %d para embarcar. Sai em %ds."\
			% [int(report.drops), int(report.lifts), int(ceilf(float(report.dwell)))]
	match int(report.stage):
		int(RailYard.Stage.ARRIVING):
			return "Trem entrando no ramal."
		int(RailYard.Stage.RUNAROUND):
			return "A locomotiva está contornando a composição."
		_:
			return "Trem saindo, %d de %d movimentos feitos."\
				% [int(report.moved), int(report.booked)]


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
	section.add_child(_orders_caption("O CAPATAZ"))
	var intro := UiTheme.label(
		"Compra sozinho, uma de cada vez, e nunca encosta na reserva. Terreno é sempre seu.",
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(intro)

	# Above the controls it disables, not below them: the reason has to arrive
	# before the greyed-out row, or the row just reads as broken.
	var locked := UiTheme.label(
		"Ele só assume depois da primeira reconstrução. Abra capital e ele estará esperando.",
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
	var reserve_caption := UiTheme.label("RESERVA", UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	reserve_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reserve_row.add_child(reserve_caption)
	for value: float in Foreman.RESERVES:
		var button := UiTheme.segment(str(Foreman.RESERVE_LABELS[value]),
			is_equal_approx(GameState.foreman_reserve, value))
		button.name = "Reserve_%d" % roundi(value * 100.0)
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.describe(button, "Reserva de %s"
			% str(Foreman.RESERVE_LABELS[value]),
			"O capataz nunca gasta esta parte do caixa.")
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
	tab.visible = PortLayout.berth_count() > 1 or GameState.prestige_count > 0 \
		or RouteDB.owned(GameState.routes).size() > 1
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
		if not GameState.has_upgrade(item.id) and GameState.upgrade_unlocked(item) \
				and GameState.can_afford(item.cost):
			ready_upgrades += 1
	var button: Button = _tab_buttons.get("upgrades")
	if button == null:
		return
	var base: String = TABS[1][1]
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
	if tab_name == "orders":
		_refresh_orders()
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
		if not GameState.has_upgrade(item.id) and GameState.upgrade_unlocked(item):
			cheapest = minf(cheapest, float(item.cost))
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
	var height := minf(safe.size.y * 0.70, 430.0)
	_board.size = Vector2(safe.size.x - 12.0, height)
	_board.position = Vector2(safe.position.x + 6.0, safe.end.y - height - 6.0)
	for index in TABS.size():
		var tab: Array = TABS[index]
		var tab_button: Button = _tab_buttons.get(tab[0])
		if tab_button != null:
			tab_button.text = str(tab[1])
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
	_update_orders_tab()
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
		card.set_effect("Requer: %s" % str(gate.get("name", "")) \
			if not gate.is_empty() else "")
		card.refresh(float(quote.get("total_cost", INF)), count,
			bool(quote.get("ok", false)), false,
			int(quote.get("quantity", 0)),
			float(quote.get("nominal_cps_gain", 0.0)))
	_refresh_teaser(next_locked)

	for item in UpgradeDB.ITEMS:
		var card: ShopCard = _cards.get(item.id)
		if card == null:
			continue
		# Recomputed on every refresh, not cached at setup: the gain a machine
		# upgrade is worth moves every time another of that machine is bought.
		var preview := GameState.upgrade_preview(item)
		card.set_effect(str(preview.get("text", "")))
		card.refresh(item.cost, 0, GameState.can_afford(item.cost), false, 1,
			float(preview.get("cps_gain", 0.0)))

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
