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
var _clip: TextureRect
var _list: VBoxContainer
var _tab_buttons: Dictionary = {}
var _focus_return: Control
var _rail: CommandRail


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
	UiTheme.apply_panel(_sheet, UiTheme.board_style(9))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	_clip = UiTheme.clip_badge()
	add_child(_clip)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_sheet.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 5)
	header.custom_minimum_size.y = 24.0
	column.add_child(header)
	var badge := UiTheme.icon(UiTheme.Icon.TROPHY)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge)
	var title := UiTheme.label("DIÁRIO DO PORTO", UiTheme.SIZE_BODY, UiTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close_button := UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 26.0,
		"Fechar o diário")
	close_button.custom_minimum_size = Vector2(30, 24)
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.pressed.connect(close)
	header.add_child(close_button)

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
		UiTheme.style_tab(button, tab[0] == _active_tab)
		button.pressed.connect(_select_tab.bind(tab[0]))
		tabs.add_child(button)
		_tab_buttons[tab[0]] = button

	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiTheme.style_scroll(scroll)
	sheet.add_child(scroll)
	# The scrollbar is reserved *inside* the scroll container, so anything
	# right-aligned on this board ends up under the grip — the trophy tally read
	# "6/33" with the 8 behind the bar. One gutter, once, for every tab.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override(&"margin_right", 6)
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
	UiTheme.pop_open(_sheet, _backdrop)


func close() -> void:
	if not _open:
		return
	_open = false
	_layout()
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
	## Thirty-eight goals as twelve tracks rather than thirty-eight rows.
	##
	## The list tabs answer "what is next" and "what is there", one row at a
	## time, and both are the right shape for picking something to chase. Neither
	## answers "how far into this game am I", because that question is about the
	## *shape* of the whole board — which trades are finished, which are barely
	## started, which have not been touched. Twelve struck coins with a row of
	## lamps beside each one answers it in a glance, and the lamps are the same
	## component the console uses for a berth.
	var objectives := _objectives()
	var done := 0
	for objective: Dictionary in objectives:
		if bool(objective.get("complete", false)):
			done += 1
	var tally := HBoxContainer.new()
	tally.add_theme_constant_override(&"separation", 5)
	_list.add_child(tally)
	var heading := UiTheme.label("QUADRO DE HONRA", UiTheme.SIZE_BODY, UiTheme.INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tally.add_child(heading)
	tally.add_child(UiTheme.stamp("%d/%d" % [done, objectives.size()],
		UiTheme.AMBER, UiTheme.SIZE_SMALL))
	_list.add_child(UiTheme.divider())

	for branch: Array in BRANCHES:
		var rows: Array[Dictionary] = []
		for objective: Dictionary in objectives:
			if String(objective.get("category", "")) == str(branch[0]):
				rows.append(objective)
		if rows.is_empty():
			continue
		# Cheapest first, so the lamps down the track read as a ladder rather
		# than as the order the table happened to be written in.
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("target", 0.0)) < float(b.get("target", 0.0)))
		_list.add_child(_trophy_branch(str(branch[0]), str(branch[1]), rows))


func _trophy_branch(key: String, title: String,
		rows: Array[Dictionary]) -> PanelContainer:
	var earned := 0
	var next: Dictionary = {}
	for objective: Dictionary in rows:
		if bool(objective.get("complete", false)):
			earned += 1
		elif next.is_empty():
			next = objective
	var finished := next.is_empty()

	var card := PanelContainer.new()
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"done" if finished else &"normal"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 7)
	card.add_child(row)

	# The coin, mounted. A struck medallion is mostly a dark navy field inside a
	# gold rim, and dropped straight onto cream manifest paper the field is the
	# part that reads — twelve of them looked like twelve holes punched in the
	# sheet. On a slate mount the gold is the lightest thing in the frame, which
	# is what a medal is supposed to be. The game already mounts a photograph
	# this way on a staff badge; this is the same object.
	var mount := UiTheme.panel(UiTheme.slate_style(earned > 0, 2), false)
	mount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mount)
	var coin := TextureRect.new()
	coin.texture = load("res://assets/sprites/ui_medal_%s.png" % key)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.custom_minimum_size = Vector2(32, 32)
	# Dimmed until the branch is started, so a board of twelve says where the run
	# has actually been — but never so far that the relief disappears.
	coin.modulate = Color(1, 1, 1) if earned > 0 else Color(0.62, 0.64, 0.72, 0.8)
	mount.add_child(coin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override(&"separation", 2)
	row.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	column.add_child(head)
	var name_label := UiTheme.label(title, UiTheme.SIZE_SMALL, UiTheme.INK)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	# Lamps: lit for earned, running for the one in progress, dark for the rest.
	var track := HBoxContainer.new()
	track.add_theme_constant_override(&"separation", 2)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(track)
	for objective: Dictionary in rows:
		var state := UiTheme.Led.OFF
		if bool(objective.get("complete", false)):
			state = UiTheme.Led.ATTENTION
		elif objective == next:
			state = UiTheme.Led.RUNNING
		var lamp := UiTheme.led(state)
		lamp.tooltip_text = str(objective.get("title", ""))
		track.add_child(lamp)

	if finished:
		var closed := UiTheme.label("Tudo conquistado nesta trilha.",
			UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
		closed.clip_text = true
		column.add_child(closed)
		return card

	var next_label := UiTheme.label(str(next.get("title", "")),
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	next_label.clip_text = true
	column.add_child(next_label)
	column.add_child(_progress_bar(float(next.get("progress", 0.0)),
		float(next.get("target", 1.0))))
	var counted := UiTheme.label("%s / %s" % [
		GameState.fmt(float(next.get("progress", 0.0))),
		GameState.fmt(float(next.get("target", 0.0)))],
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	counted.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(counted)
	return card


func _build_album_page() -> void:
	## C7 — the ship album: one card per silhouette, a chip per livery, lit when
	# that hull×paint has actually arrived. A complete page pays a lump once.
	var heading := UiTheme.label("ÁLBUM DE NAVIOS", UiTheme.SIZE_BODY, UiTheme.INK)
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
	_active_tab = tab
	_refresh()


func _refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	for key: String in _tab_buttons:
		UiTheme.style_tab(_tab_buttons[key], key == _active_tab)
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
			UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
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
		&"meta":
			return "+%d carreira" % int(reward.get("amount", 1))
		&"cosmetic":
			return "coleção"
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
	UiTheme.place_clip(_clip, _sheet, safe)
