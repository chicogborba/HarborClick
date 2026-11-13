class_name PortJournal
extends CanvasLayer
## The career board. The optional callbacks are deliberately tiny adapters:
## get_objectives() -> Array[Dictionary], pin(id) -> bool.
##
## Contracts used to live here as a card at the top of the "next" tab, and they
## were the worst thing on it: a quiet counter you had to remember to come and
## look at, sitting above the goals it had nothing to do with. Charters are events
## now — see `SpecialCallAlert` and `CraneMinigame`. This board is goals only.
##
## The first version printed `245413 / 1000000` and, next to it, the literal
## contents of the reward dictionary — the player read "recompensa: cosmetic".
## Every row now carries a filled bar, formatted numbers and reward text
## written for a person, and a completed goal is marked with a tick instead of
## quietly looking like every other row.

signal open_changed(opened: bool)
signal objective_pinned(id: StringName)
## The Arcade key on the "next" page: one minigame on demand, paid for by a
## rewarded ad (`minigame_play`, 3/day). Never required — the charters still
## come on their own.
signal arcade_requested

const TABS := [["next", "PRÓXIMAS"], ["all", "TODAS"], ["troph", "TROFÉUS"],
	["crew", "EQUIPE"], ["album", "ÁLBUM"]]

## The trophy board's twelve branches, in the order they are shown, with the
## medallion struck for each and the word the player reads.
##
## CONCLUÍDAS is gone and this took its slot: a flat list of everything already
## earned answered "what have I done" in the least interesting way available,
## while the same fact — thirty-eight goals, twelve trades, how far along each —
## is what a board of struck coins says at a glance.
const BRANCHES := [
	["teu", "TEUs MOVIMENTADOS"], ["ships", "NAVIOS ATENDIDOS"],
	["structures", "ESTRUTURAS"], ["cargo", "CONTÊINERES"],
	["critical", "CRÍTICOS"], ["events", "EVENTOS"],
	["routes", "ROTAS"], ["terrain", "TERRENOS"],
	["collection", "COLEÇÃO"], ["contracts", "CONTRATOS"],
	["prestige", "RECONSTRUÇÃO"], ["tutorial", "PRIMEIROS PASSOS"],
]

var _source: Variant
var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _profile := ""
var _open := false
var _active_tab := "next"
var _backdrop: ColorRect
var _sheet: PanelContainer
var _page: Control
var _list: VBoxContainer
var _tab_buttons: Dictionary = {}
var _focus_return: Control
var _rail: CommandRail
## The cup whose card is open on the trophy page.
var _trophy_pick := ""


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_source = manager_or_callbacks
	_callbacks = callbacks.duplicate()
	_refresh()


func _ready() -> void:
	layer = 12
	_backdrop = UiTheme.scrim(0.76)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_sheet = PanelContainer.new()
	# Leather, not a clipboard: this is the port's logbook (`BookFx`).
	UiTheme.apply_panel(_sheet, UiTheme.book_style())
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_sheet.add_child(column)

	var header := UiTheme.header("DIÁRIO DO PORTO", close, UiTheme.Icon.TROPHY,
		UiTheme.book_header_style())
	column.add_child(header.root)
	(header.close as Button).tooltip_text = Loc.t("common.close_hint")

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 2)
	tabs.custom_minimum_size.y = 22.0
	column.add_child(tabs)
	for tab: Array in TABS:
		var button := Button.new()
		button.text = str(tab[1])
		# Without this the three labels set a 314px floor on the board, which is
		# wider than the command rail it now lives in.
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.apply_font(button, UiTheme.SIZE_SMALL)
		UiTheme.style_book_tab(button, tab[0] == _active_tab)
		button.pressed.connect(_select_tab.bind(tab[0]))
		tabs.add_child(button)
		_tab_buttons[tab[0]] = button

	# The cards lie on the page itself: no tray inside a book.
	var page_box := StyleBoxEmpty.new()
	page_box.set_content_margin_all(2)
	var sheet := UiTheme.panel(page_box)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	_page = sheet
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiTheme.style_scroll(scroll)
	sheet.add_child(scroll)
	# The scrollbar is reserved *inside* the scroll container, so anything
	# right-aligned on this board ends up under the grip — the trophy tally read
	# "6/33" with the 8 behind the bar, and the ARCADE stamp sat on the grip.
	# One gutter, once, for every tab: the bar's own width plus a breath.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override(&"margin_right",
		int(UiTheme.SCROLL_WIDTH) + 2)
	scroll.add_child(gutter)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	gutter.add_child(_list)
	_layout()
	_refresh()


func open(tab := "next") -> void:
	_active_tab = tab if TABS.any(func(entry: Array) -> bool: return entry[0] == tab) else "next"
	_open = true
	_focus_return = get_viewport().gui_get_focus_owner()
	_refresh()
	_layout()
	UiTheme.focus_first(_sheet)
	open_changed.emit(true)
	BookFx.open(_sheet, _backdrop)


func close() -> void:
	if not _open:
		return
	_open = false
	BookFx.close(_sheet, _backdrop, _layout)
	UiTheme.restore_focus(_focus_return)
	_focus_return = null
	open_changed.emit(false)


func is_open() -> bool:
	return _open


func refresh() -> void:
	_refresh()


func set_rail(rail: CommandRail) -> void:
	_rail = rail


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_profile = str(metrics.get("profile", ""))
	_layout()


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		close()


# -------------------------------------------------------------- the trophies

func _build_trophy_page() -> void:
	## The cabinet. Every goal in the game is a cup on a shelf: struck in
	## bronze, silver or gold by how deep into its trade it sits, and a dark
	## outline of itself until it is earned.
	##
	## This page used to be twelve rows with a coin and a line of lamps — a
	## summary of the collection rather than the collection. Somebody who wants
	## everything wants to *see* everything: which cups are there, which gaps
	## are left, and one number at the top for how far the whole lot has got.
	## So the top of the page is that number, as a bar with the quarters marked,
	## and under it are the shelves, one trade at a time.
	var objectives := _objectives()
	var done := 0
	for objective: Dictionary in objectives:
		if bool(objective.get("complete", false)):
			done += 1
	var total := maxi(1, objectives.size())
	var meter := _Completion.new()
	meter.done = done
	meter.total = total
	meter.custom_minimum_size.y = 72.0
	_list.add_child(meter)

	# What the cup under the finger is.
	var picked: Dictionary = {}
	for objective: Dictionary in objectives:
		if str(objective.get("id", "")) == _trophy_pick:
			picked = objective
	var note := UiTheme.panel(UiTheme.card_style(
		&"done" if bool(picked.get("complete", false)) else &"normal"))
	_list.add_child(note)
	var note_col := VBoxContainer.new()
	note_col.add_theme_constant_override(&"separation", 2)
	note_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(note_col)
	if picked.is_empty():
		var hint := UiTheme.label(Loc.t("trophy.hint"), UiTheme.SIZE_SMALL,
			UiTheme.INK_SOFT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_col.add_child(hint)
	else:
		var name_label := UiTheme.label(str(picked.get("title", "")),
			UiTheme.SIZE_BODY, UiTheme.INK)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_col.add_child(name_label)
		var earned := bool(picked.get("complete", false))
		if not earned:
			note_col.add_child(_progress_bar(float(picked.get("progress", 0.0)),
				float(picked.get("target", 1.0))))
		var line := UiTheme.label("%s / %s  -  %s" % [
			GameState.fmt(float(picked.get("progress", 0.0))),
			GameState.fmt(float(picked.get("target", 0.0))),
			_reward_text(picked.get("reward", {}))], UiTheme.SIZE_SMALL,
			UiTheme.TEAL_DEEP if earned else UiTheme.INK_SOFT)
		line.clip_text = true
		note_col.add_child(line)

	var width := maxf(160.0, _sheet.size.x - 44.0 - UiTheme.SCROLL_WIDTH)
	var columns := clampi(int(width / _Cup.CELL.x), 3, 12)
	for branch: Array in BRANCHES:
		var rows: Array[Dictionary] = []
		for objective: Dictionary in objectives:
			if String(objective.get("category", "")) == str(branch[0]):
				rows.append(objective)
		if rows.is_empty():
			continue
		# Cheapest first, so a shelf reads left to right as a ladder.
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("target", 0.0)) < float(b.get("target", 0.0)))
		_list.add_child(_trophy_shelf(str(branch[1]), rows, columns))


func _trophy_shelf(title: String, rows: Array[Dictionary], columns: int) -> Control:
	var earned := 0
	for objective: Dictionary in rows:
		if bool(objective.get("complete", false)):
			earned += 1
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	box.add_child(head)
	var name_label := UiTheme.label(title, UiTheme.SIZE_SMALL, UiTheme.BOOK_INK)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var full := earned == rows.size()
	head.add_child(UiTheme.label("%d/%d" % [earned, rows.size()], UiTheme.SIZE_SMALL,
		UiTheme.TEAL_DEEP if full else UiTheme.BOOK_INK_SOFT))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override(&"h_separation", 0)
	grid.add_theme_constant_override(&"v_separation", 2)
	box.add_child(grid)
	var next_found := false
	for index in rows.size():
		var objective: Dictionary = rows[index]
		var cup := _Cup.new()
		cup.tier = clampi(int(float(index) * 3.0 / float(rows.size())), 0, 2)
		cup.crown = index == rows.size() - 1 and rows.size() > 1
		cup.earned = bool(objective.get("complete", false))
		cup.picked = str(objective.get("id", "")) == _trophy_pick
		if not cup.earned and not next_found:
			next_found = true
			cup.fill = clampf(float(objective.get("progress", 0.0))
				/ maxf(1.0, float(objective.get("target", 1.0))), 0.0, 1.0)
		cup.custom_minimum_size = _Cup.CELL
		cup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cup.tooltip_text = str(objective.get("title", ""))
		UiTheme.describe(cup, str(objective.get("title", "")))
		cup.pressed.connect(_pick_trophy.bind(str(objective.get("id", ""))))
		grid.add_child(cup)
	# Empty pegs to the end of the shelf, so the plank runs the full width.
	var spare := (columns - rows.size() % columns) % columns
	for i in spare:
		var blank := _Cup.new()
		blank.blank = true
		blank.custom_minimum_size = _Cup.CELL
		blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(blank)
	return box


func _pick_trophy(id: String) -> void:
	_trophy_pick = "" if id == _trophy_pick else id
	AudioManager.play_sfx("tap")
	_refresh()


class _Completion extends Control:
	## The one number a completionist came for: how much of everything is done.
	## A bar with the quarters marked, the percentage in big type, and the big
	## cup at the end that only turns gold at a hundred.
	var done := 0
	var total := 1
	var _big: Label
	var _small: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var percent := int(floor(100.0 * float(done) / float(maxi(1, total))))
		_big = UiTheme.label("%d%%" % percent, UiTheme.SIZE_TITLE, UiTheme.AMBER)
		add_child(_big)
		_small = UiTheme.label(Loc.t("trophy.count",
			{"n": str(done), "total": str(total)}), UiTheme.SIZE_SMALL, UiTheme.SLATE_TEXT)
		add_child(_small)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var ink := Color8(24, 20, 30)
		var gold := UiTheme.AMBER
		draw_rect(Rect2(Vector2.ZERO, size), ink)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color8(34, 30, 44))
		draw_rect(Rect2(1, size.y - 3, size.x - 2, 2), Color8(128, 78, 18))
		var ratio := float(done) / float(maxi(1, total))
		var cup := Vector2(size.x - 34.0, size.y - 6.0)
		var track := Rect2(10, size.y - 24.0, size.x - 84.0, 10)
		draw_rect(track.grow(1.0), ink)
		draw_rect(track, Color8(70, 62, 78))
		var filled := roundf(track.size.x * ratio)
		if filled > 0.0:
			draw_rect(Rect2(track.position, Vector2(filled, track.size.y)), gold)
			draw_rect(Rect2(track.position, Vector2(filled, 2)), Color8(255, 236, 160))
			draw_rect(Rect2(track.position + Vector2(0, track.size.y - 2),
				Vector2(filled, 2)), Color8(196, 136, 40))
		for quarter in [0.25, 0.5, 0.75]:
			var x := roundf(track.position.x + track.size.x * quarter)
			draw_rect(Rect2(x, track.position.y - 3.0, 2, track.size.y + 6.0),
				gold if ratio >= quarter else Color8(112, 102, 116))
		# The grand cup: a silhouette until every shelf is full.
		_Cup.draw_cup(self, cup, 2, done >= total, true, 2.0)
		if _big != null:
			_big.position = Vector2(10, 8)
			_small.position = Vector2(18.0 + _big.get_minimum_size().x, 17)


class _Cup extends Control:
	## One goal, as a cup standing on its shelf.
	signal pressed

	const CELL := Vector2(40, 46)
	const METALS := [
		[Color8(200, 124, 72), Color8(238, 176, 120), Color8(132, 74, 44)],
		[Color8(188, 196, 208), Color8(240, 244, 248), Color8(112, 122, 140)],
		[Color8(244, 190, 64), Color8(255, 236, 160), Color8(176, 116, 28)],
	]
	const WOOD := Color8(150, 100, 60)
	const WOOD_D := Color8(96, 60, 38)
	const WOOD_L := Color8(186, 134, 84)

	var tier := 0
	var crown := false
	var earned := false
	var picked := false
	var blank := false
	## 0..1 for the next cup to be won on its shelf; -1 for the rest.
	var fill := -1.0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if blank:
			return
		var click := event as InputEventMouseButton
		var touch := event as InputEventScreenTouch
		if (click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed) \
				or (touch != null and not touch.pressed) \
				or event.is_action_pressed(&"ui_accept"):
			accept_event()
			pressed.emit()

	func _draw() -> void:
		# The plank, continuous from cell to cell.
		var shelf := size.y - 7.0
		draw_rect(Rect2(0, shelf, size.x, 5), WOOD)
		draw_rect(Rect2(0, shelf, size.x, 1), WOOD_L)
		draw_rect(Rect2(0, shelf + 4.0, size.x, 2), WOOD_D)
		if blank:
			return
		var cx := roundf(size.x * 0.5)
		if picked or has_focus():
			draw_rect(Rect2(cx - 17, 1, 34, shelf - 1.0), Color(UiTheme.AMBER, 0.35))
		draw_cup(self, Vector2(cx, shelf), tier, earned, crown, 1.0)
		if not earned and fill >= 0.0:
			# The one being worked on: how close, under the plank.
			draw_rect(Rect2(cx - 13, size.y - 2.0, 26, 2), Color8(96, 84, 78))
			draw_rect(Rect2(cx - 13, size.y - 2.0, roundf(26.0 * fill), 2), UiTheme.TEAL)

	static func draw_cup(on: CanvasItem, foot: Vector2, metal: int, lit: bool,
			star: bool, k: float) -> void:
		## A cup standing on `foot` (bottom centre), `k` pixels to the pixel.
		var ink := Color8(38, 26, 30)
		var body: Color = METALS[metal][0]
		var light: Color = METALS[metal][1]
		var dark: Color = METALS[metal][2]
		if not lit:
			# Not won yet: its own outline, cut out of the dark.
			body = Color8(122, 108, 96)
			light = Color8(140, 126, 112)
			dark = Color8(104, 92, 84)
			ink = Color8(84, 72, 68)
		var parts := [
			# [x, y (up from the foot), w, h, colour]
			[-9, 3, 18, 3, ink], [-8, 3, 16, 2, dark],            # plinth
			[-6, 6, 12, 3, ink], [-5, 6, 10, 2, body],
			[-2, 12, 4, 6, ink], [-1, 12, 2, 6, dark],            # stem
			[-9, 28, 18, 16, ink],                                # bowl
			[-8, 27, 16, 14, body], [-8, 27, 4, 14, light],
			[4, 27, 4, 14, dark], [-6, 14, 12, 2, ink], [-5, 15, 10, 2, dark],
			[-14, 26, 5, 3, ink], [-14, 26, 3, 9, ink], [-14, 19, 6, 3, ink],   # handles
			[9, 26, 5, 3, ink], [11, 26, 3, 9, ink], [8, 19, 6, 3, ink],
			[-10, 30, 20, 3, ink], [-9, 29, 18, 1, light],        # lip
		]
		for part: Array in parts:
			on.draw_rect(Rect2(foot.x + float(part[0]) * k, foot.y - float(part[1]) * k,
				float(part[2]) * k, float(part[3]) * k), part[4])
		if star and lit:
			for dot: Array in [[-1, 24, 2, 6], [-3, 22, 6, 2]]:
				on.draw_rect(Rect2(foot.x + float(dot[0]) * k, foot.y - float(dot[1]) * k,
					float(dot[2]) * k, float(dot[3]) * k), Color8(196, 56, 48))


func _build_album_page() -> void:
	## C7 — the ship album: one card per silhouette, a chip per livery, lit when
	# that hull×paint has actually arrived. A complete page pays a lump once.
	var heading := UiTheme.label("ÁLBUM DE NAVIOS", UiTheme.SIZE_BODY, UiTheme.BOOK_INK)
	_list.add_child(heading)
	_list.add_child(UiTheme.divider())
	for silhouette in ShipCatalog.SILHOUETTES:
		var sid := String(silhouette.id)
		var page: Dictionary = Progression.album_page(sid, ShipCatalog.PALETTES.size())
		var card := PanelContainer.new()
		UiTheme.apply_panel(card, UiTheme.card_style(
			&"done" if page.complete and page.claimed else &"normal"))
		_list.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 3)
		card.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 6)
		col.add_child(head)
		var title := UiTheme.label(str(silhouette.title), UiTheme.SIZE_BODY, UiTheme.INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		head.add_child(title)
		head.add_child(UiTheme.stamp("%d/%d" % [int(page.seen), int(page.total)],
			UiTheme.AMBER if page.complete else UiTheme.STEEL_DIM, UiTheme.SIZE_SMALL))
		if page.complete and not page.claimed:
			var claim := UiTheme.button("RESGATAR", &"amber", UiTheme.SIZE_SMALL)
			claim.custom_minimum_size.y = UiTheme.TOUCH_MIN
			claim.pressed.connect(func() -> void:
				if Progression.claim_album_page(sid, ShipCatalog.PALETTES.size()):
					var amount := GameState.cps * Progression.ALBUM_PAGE_SECONDS
					GameState.grant_nonproductive_reward(amount)
					EventBus.notification_requested.emit({
						"id": "album_%s" % sid, "kind": &"unlock", "priority": 2,
						"text": "%s completo: +%s TEU" % [str(silhouette.title),
							GameState.fmt(amount)],
					})
					AudioManager.play_sfx("coins")
				_refresh())
			head.add_child(claim)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override(&"separation", 4)
		col.add_child(chips)
		for palette in ShipCatalog.PALETTES:
			var chip := ColorRect.new()
			chip.custom_minimum_size = Vector2(26.0, 18.0)
			chip.color = Color(str(palette.hull))
			if not Progression.album_seen(sid, String(palette.id)):
				chip.modulate = Color(1, 1, 1, 0.25)
			chips.add_child(chip)


func _build_crew_page() -> void:
	## Who works here, what each of them is on right now, and the charter record.
	## The whole crew in one place was the thing the individual dossiers could not
	## give: you can tap one person in the yard, but not compare the shift.
	var record := _charter_record()
	if not record.is_empty():
		_list.add_child(_make_record_card(record))
	for member: Dictionary in _crew():
		_list.add_child(_make_crew_card(member))


func _make_record_card(record: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	UiTheme.apply_panel(card, UiTheme.card_style(&"ready"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.STAR))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 1)
	row.add_child(text)
	text.add_child(UiTheme.label("ESCALAS ESPECIAIS", UiTheme.SIZE_SMALL,
		UiTheme.INK))
	var played := int(record.get("played", 0))
	var won := int(record.get("won", 0))
	var detail := "nenhuma ainda" if played == 0 \
		else "%d de %d concluídas" % [won, played]
	text.add_child(UiTheme.label(detail, UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP))
	return card


func _make_crew_card(member: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"ready" if bool(member.get("special", false)) else &"normal"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.GLOVE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 1)
	row.add_child(text)
	# Three lines, not two.
	#
	# Name and role used to share one clipped line, and on a phone that produced a
	# whole shift of "Fabiane Silveira  -  Conferente de ..." — every row cut at
	# the same place, so the column read as one repeated word. A person's name is
	# the thing this list is *for*; it gets a line of its own, the role gets the
	# next, and the task is allowed to wrap rather than be truncated to a verb.
	var name_label := UiTheme.label(str(member.get("name", "")),
		UiTheme.SIZE_SMALL, UiTheme.INK)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_label)
	var role := str(member.get("title", ""))
	if not role.is_empty():
		var role_label := UiTheme.label(role, UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
		role_label.clip_text = true
		role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(role_label)
	var task := str(member.get("objective", ""))
	var task_label := UiTheme.label(task if not task.is_empty() \
		else "Sem tarefa agora.", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.max_lines_visible = 2
	task_label.custom_minimum_size.x = 0.0
	text.add_child(task_label)
	var tally := UiTheme.stamp(str(int(member.get("moves", 0))), UiTheme.AMBER,
		UiTheme.SIZE_SMALL)
	tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tally)
	return card


func _crew() -> Array:
	var getter: Callable = _callbacks.get("get_crew", Callable())
	if getter.is_valid():
		var value: Variant = getter.call()
		return value if value is Array else []
	return []


func _charter_record() -> Dictionary:
	var getter: Callable = _callbacks.get("get_charters", Callable())
	if getter.is_valid():
		var value: Variant = getter.call()
		return value if value is Dictionary else {}
	return {}


func _select_tab(tab: String) -> void:
	var turned := tab != _active_tab
	_active_tab = tab
	_refresh()
	if turned and _open:
		BookFx.flip(_page)


func _refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	for key: String in _tab_buttons:
		UiTheme.style_book_tab(_tab_buttons[key], key == _active_tab)
	if _active_tab == "crew":
		_build_crew_page()
	elif _active_tab == "troph":
		_build_trophy_page()
	elif _active_tab == "album":
		_build_album_page()
	else:
		if _active_tab == "next" and FeatureGate.unlocked(&"charters"):
			_list.add_child(_arcade_row())
		for objective: Dictionary in _objectives():
			# PRÓXIMAS hides what is finished; TODAS hides nothing. What used to
			# be CONCLUÍDAS is the trophy board now.
			if _active_tab == "next" and bool(objective.get("complete", false)):
				continue
			_list.add_child(_make_card(objective))
	if _list.get_child_count() == 0:
		var empty := UiTheme.label("Nenhuma meta nesta página."
			if _active_tab != "crew" else "Ninguém contratado ainda.",
			UiTheme.SIZE_SMALL, UiTheme.BOOK_INK_SOFT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)


func _arcade_row() -> Control:
	## One wide key at the top of PRÓXIMAS: a minigame on demand for a rewarded
	# ad. The label carries the remaining plays today, and the key hides when the
	# daily cap is spent — an ad is never a wall.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var left := AdService.remaining_today(&"minigame_play")
	var key := UiTheme.button(Loc.t("journal.arcade"), &"steel", UiTheme.SIZE_SMALL)
	key.icon = UiTheme.icon16_texture(UiTheme.Icon16.AD)
	key.custom_minimum_size.y = UiTheme.TOUCH_MIN
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.disabled = left <= 0 or not AdService.available(&"minigame_play")
	UiTheme.describe(key, Loc.t("journal.arcade"), Loc.t("journal.arcade.hint"))
	key.pressed.connect(func() -> void: arcade_requested.emit())
	row.add_child(key)
	var count := UiTheme.stamp("%d" % maxi(0, left), UiTheme.AMBER, UiTheme.SIZE_SMALL)
	row.add_child(count)
	return row


func _objectives() -> Array:
	var getter: Callable = _callbacks.get("get_objectives", Callable())
	if getter.is_valid():
		var supplied: Variant = getter.call()
		return supplied if supplied is Array else []
	if _source != null and _source.has_method("get_pinned_objective"):
		var pinned: Dictionary = _source.get_pinned_objective()
		return [pinned] if not pinned.is_empty() else []
	return []


# --------------------------------------------------------------------- cards

func _progress_bar(progress: float, target: float) -> ProgressBar:
	var bar := ProgressBar.new()
	var styles := UiTheme.bar_styles()
	bar.add_theme_stylebox_override(&"background", styles[0])
	bar.add_theme_stylebox_override(&"fill", styles[1])
	bar.show_percentage = false
	# Tall enough to read as a bar. At 5px it looked like an underline under
	# the title rather than a measure of anything.
	bar.custom_minimum_size.y = 9.0
	bar.max_value = maxf(target, 1.0)
	bar.value = clampf(progress, 0.0, bar.max_value)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _make_card(objective: Dictionary) -> PanelContainer:
	var done := bool(objective.get("complete", false))
	var pinned := bool(objective.get("pinned", false))
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 44.0
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"done" if done else (&"ready" if pinned else &"normal")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)

	var mark := UiTheme.icon(UiTheme.Icon.CHECK if done else UiTheme.Icon.TROPHY)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := UiTheme.label(str(objective.get("title", "Meta de operação")),
		UiTheme.SIZE_SMALL, UiTheme.INK)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)

	var progress := float(objective.get("progress", 0.0))
	var target := float(objective.get("target", 0.0))
	if not done:
		text.add_child(_progress_bar(progress, target))
	var detail := UiTheme.label("%s / %s  -  %s" % [GameState.fmt(progress),
		GameState.fmt(target), _reward_text(objective.get("reward", {}))],
		UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP if done else UiTheme.INK_SOFT)
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(detail)

	if not done:
		var pin := UiTheme.icon_button(UiTheme.Icon.STAR,
			&"amber" if pinned else &"ghost", 28.0)
		pin.custom_minimum_size = Vector2(30, 28)
		pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiTheme.describe(pin, "Fixar \"%s\" no HUD"
			% str(objective.get("title", "meta")))
		pin.tooltip_text = "Fixada no HUD" if pinned else "Fixar no HUD"
		pin.disabled = pinned
		pin.pressed.connect(_pin.bind(StringName(objective.get("id", ""))))
		row.add_child(pin)
	return card


func _pin(id: StringName) -> void:
	if id.is_empty():
		return
	var pin_callback: Callable = _callbacks.get("pin", Callable())
	if pin_callback.is_valid():
		pin_callback.call(id)
	elif _source != null and _source.has_method("pin_objective"):
		_source.pin_objective(id)
	objective_pinned.emit(id)
	_refresh()


func _reward_text(reward: Variant) -> String:
	## Reward payloads are engine data; a player reads a sentence, never a key.
	if not reward is Dictionary or reward.is_empty():
		return "sem recompensa"
	var kind := StringName(reward.get("kind", ""))
	# Short on purpose: this line shares a 256px rail with the progress figures,
	# and a truncated reward tells the player nothing at all.
	match kind:
		&"teu":
			return "+%s TEU" % GameState.fmt(float(reward.get("amount", 0.0)))
		&"xp":
			return "+%d XP" % int(reward.get("amount", 0))
	return "especial"


func _layout() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var top := safe.position.y + 20.0
	_sheet.size = Vector2(safe.size.x - 12.0,
		maxf(220.0, safe.end.y - top - 6.0))
	_sheet.position = Vector2(safe.position.x + 6.0,
		safe.end.y - _sheet.size.y - 6.0)
	_backdrop.visible = _open
	_sheet.visible = _open
