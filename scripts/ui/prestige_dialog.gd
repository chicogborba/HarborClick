class_name PrestigeDialog
extends CanvasLayer
## All state-changing work remains in the supplied callbacks. This surface only
## asks for a quote, confirms it explicitly, and renders the five career lanes.

signal open_changed(opened: bool)
signal prestige_confirmed(quote: Dictionary)
signal node_purchase_requested(id: StringName)

var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _open := false
var _quoted := false
var _backdrop: ColorRect
var _panel: PanelContainer
var _summary: Label
var _confirm: Button
var _branches_label: Label
var _tree: VBoxContainer
var _focus_return: Control
var _scroll: ScrollContainer
var _viewport_clip: Control
var _rows: Array[Dictionary] = []


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_callbacks = manager_or_callbacks.duplicate() if manager_or_callbacks is Dictionary else callbacks.duplicate()


func _ready() -> void:
	layer = 13
	_backdrop = UiTheme.scrim(0.78)
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed): close())
	add_child(_backdrop)
	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(9))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 5)
	_panel.add_child(col)
	var header := UiTheme.header("RECONSTRUIR O PORTO", close, UiTheme.Icon.STAR)
	col.add_child(header.root)
	(header.close as Button).tooltip_text = Loc.t("common.close_hint")
	_summary = UiTheme.label("Consulte a proposta de reconstrução.", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_summary)
	_confirm = UiTheme.button("VER PROPOSTA", &"amber", UiTheme.SIZE_SMALL)
	_confirm.custom_minimum_size.y = 28.0
	_confirm.pressed.connect(_confirm_or_quote)
	col.add_child(_confirm)
	_branches_label = UiTheme.label("CAPITAL DO PORTO - %d RAMOS"
		% PrestigeDB.purchasable_branches().size(), UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	col.add_child(_branches_label)
	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sheet)
	# A plain Control does not propagate its children's minimum size. Without
	# this the twelve capital nodes made the dialog 778px tall on a 568px
	# phone, and a PanelContainer can never be shorter than its content — the
	# whole board slid off the top of the screen.
	_viewport_clip = Control.new()
	_viewport_clip.clip_contents = true
	_viewport_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(_viewport_clip)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.style_scroll(_scroll)
	_viewport_clip.add_child(_scroll)
	# Gutter for the reserved scrollbar so the buy keys on the right edge of
	# each row are not drawn under the grip.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override(&"margin_right",
		int(UiTheme.SCROLL_WIDTH) + 2)
	_scroll.add_child(gutter)
	_tree = VBoxContainer.new()
	_tree.add_theme_constant_override(&"separation", 4)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(_tree)
	_build_tree()
	_layout()


func open() -> void:
	_open = true
	_quoted = false
	_summary.text = "Consulte a proposta antes de confirmar a reconstrução."
	_confirm.text = "VER PROPOSTA"
	# Shares are earned outside this dialog, so what is affordable changes while
	# it is shut. Branches also unlock with level (C6 opens Routes/Events at 8),
	# so the tree and its header are rebuilt on every open, not just at boot.
	_rebuild_tree()
	_focus_return = get_viewport().gui_get_focus_owner()
	_layout()
	_confirm.grab_focus()
	open_changed.emit(true)
	UiTheme.pop_open(_panel, _backdrop)


func close() -> void:
	if not _open: return
	_open = false
	_layout()
	UiTheme.restore_focus(_focus_return)
	_focus_return = null
	open_changed.emit(false)


func is_open() -> bool: return _open


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()


func _confirm_or_quote() -> void:
	if not _quoted:
		var quote: Dictionary = _call("quote", {})
		# `peak` is a per-structure dictionary, and feeding it to `float()` raised
		# "Nonexistent 'float' constructor" every time the button was pressed —
		# which meant `_quoted` never flipped and the reset could never be
		# confirmed from this dialog at all.
		# D9: the gain is promised, so show the last run next to this one —
		# "run anterior × esta" makes the reset visible instead of promised.
		var compare := ""
		var last: Dictionary = GameState.last_run_summary
		if not last.is_empty():
			compare = "\nRun anterior: %s TEU  -  esta: %s TEU" % [
				GameState.fmt(float(last.get("run_teus", 0.0))),
				GameState.fmt(GameState.run_teus)]
		_summary.text = "Ganho: %s ações  -  Pico: %d máquinas  -  Reconstrução: %s\n%s%s" % [
			str(quote.get("gain", 0)), _peak_units(quote),
			str(quote.get("rebuild_discount", "0%")), _rebuild_line(quote), compare]
		_confirm.text = "CONFIRMAR RECONSTRUÇÃO"
		_quoted = true
		return
	var committed: Variant = _call("commit", {})
	if not (committed is bool and not committed):
		prestige_confirmed.emit(committed if committed is Dictionary else {})
		close()


static func rebuild_line(seconds: float) -> String:
	## The question that decides the first reset: what does this cost me in time.
	## Without it the dialog asks the player to give up a number they can see for
	## a bonus they cannot, which is how a first prestige gets abandoned.
	if seconds < 0.0:
		return "Este pico leva mais de 4h para voltar."
	if seconds <= 0.0:
		return "Não há produção a recuperar."
	return "Você recupera este ritmo em cerca de %s jogando." \
		% OfflinePopup.format_duration(seconds)


static func peak_units(peak: Variant) -> int:
	## The discount applies per machine up to the historic peak, so the number
	## that means something to the player is how many machines it covers.
	if not (peak is Dictionary):
		return 0
	var total := 0
	for amount in (peak as Dictionary).values():
		total += maxi(0, int(amount))
	return total


func _peak_units(quote: Dictionary) -> int:
	return peak_units(quote.get("peak", {}))


func _rebuild_line(quote: Dictionary) -> String:
	return rebuild_line(float(quote.get("rebuild_seconds", -1.0)))


func _rebuild_tree() -> void:
	## Tear the tree down and build it again. Needed on every open because the
	## branch set itself depends on level (C6 unlocks Routes/Events at 8), and a
	## tree built at boot went stale the first time a branch appeared.
	if _tree == null:
		return
	for child in _tree.get_children():
		# remove_child first: queue_free alone leaves the node counted as a
		# child until the end of the frame, and anything reading the tree in
		# that window (tests, layout) sees double.
		_tree.remove_child(child)
		child.queue_free()
	_rows.clear()
	_build_tree()
	if _branches_label != null:
		_branches_label.text = "CAPITAL DO PORTO - %d RAMOS" \
			% PrestigeDB.purchasable_branches().size()


func _build_tree() -> void:
	## Built once, refreshed thereafter.
	##
	## It used to be built once and *never* refreshed, which meant a node you had
	## just paid three golden shares for went on looking exactly like a node for
	## sale — same button, same price, same everything — until the dialog was
	## closed and the game restarted. The tree is the only thing a reset buys, and
	## it was the one screen in the game that could not show you what you owned.
	if _tree == null:
		return
	_rows.clear()
	for branch: Dictionary in PrestigeDB.purchasable_branches():
		var caption := UiTheme.label(str(branch.get("title", "Ramo")).to_upper(),
			UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
		_tree.add_child(caption)
		# One node per full-width row. Laying a branch out horizontally made the
		# four-node offline branch wider than the dialog, which pushed the whole
		# panel off screen because a PanelContainer can never be smaller than
		# its content.
		for node: Dictionary in branch.get("nodes", []):
			var id := str(node.get("id", ""))
			var card := UiTheme.panel(UiTheme.card_style(&"normal"))
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			_tree.add_child(card)
			var row := HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 5)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(row)

			var text_col := VBoxContainer.new()
			text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			text_col.add_theme_constant_override(&"separation", 0)
			text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(text_col)
			var title := UiTheme.label(str(node.get("title", id)),
				UiTheme.SIZE_BODY, UiTheme.INK)
			title.clip_text = true
			text_col.add_child(title)
			var effect := UiTheme.label(_node_label(node), UiTheme.SIZE_SMALL,
				UiTheme.INK_SOFT)
			effect.clip_text = true
			text_col.add_child(effect)

			var buy := UiTheme.button("", &"alt", UiTheme.SIZE_SMALL)
			buy.custom_minimum_size = Vector2(58, 26)
			buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			buy.pressed.connect(_purchase.bind(StringName(id)))
			row.add_child(buy)
			_rows.append({"id": id, "node": node, "card": card, "buy": buy,
				"title": title, "effect": effect})
	_refresh_tree()


func _refresh_tree() -> void:
	## Four states, told apart the way the shop tells them apart: owned, buyable,
	## priced-but-unaffordable, and shut behind the node above it.
	var shares := int(_call("shares", 0))
	var owned: Dictionary = _call("owned_nodes", {})
	for row: Dictionary in _rows:
		var id := str(row.id)
		var node: Dictionary = row.node
		var cost := int(node.get("cost", 0))
		var buy: Button = row.buy
		var card: PanelContainer = row.card
		var title: Label = row.title
		var effect: Label = row.effect
		if owned.has(StringName(id)):
			buy.text = Loc.t("shop.map.owned")
			buy.disabled = true
			title.label_settings.font_color = UiTheme.TEAL_DEEP
			effect.label_settings.font_color = UiTheme.TEAL_DEEP
			UiTheme.apply_panel(card, UiTheme.card_style(&"done"))
			continue
		var missing := _missing_parent(node, owned)
		if not missing.is_empty():
			buy.text = "-"
			buy.disabled = true
			title.label_settings.font_color = UiTheme.INK_SOFT
			effect.label_settings.font_color = UiTheme.INK_SOFT
			effect.text = Loc.t("shop.upgrade.needs", {"name": missing})
			UiTheme.apply_panel(card, UiTheme.card_style(&"locked"))
			continue
		effect.text = _node_label(node)
		buy.text = "%d" % cost
		buy.disabled = shares < cost
		title.label_settings.font_color = \
			UiTheme.INK if shares >= cost else UiTheme.INK_SOFT
		effect.label_settings.font_color = UiTheme.INK_SOFT
		UiTheme.apply_panel(card,
			UiTheme.card_style(&"ready" if shares >= cost else &"normal"))


func _node_label(node: Dictionary) -> String:
	## What the node does, in the units the player reads. Derived from the effect
	## rather than authored beside it, so it cannot drift from the data — the
	## *name* is authored, because "+20%" is not a name.
	var effect: Dictionary = node.get("effect", {})
	var value := float(effect.get("value", 0.0))
	match StringName(effect.get("stat", "")):
		&"cps_multiplier": return "+%d%% em tudo" % roundi(value * 100.0)
		&"cps_per_kind": return "+%d%% por tipo de máquina" % roundi(value * 100.0)
		&"click_multiplier": return "+%d%% por toque" % roundi(value * 100.0)
		&"cps_per_tap": return "toque ganha %d%% da produção" % roundi(value * 100.0)
		&"offline_efficiency": return "offline rende %d%%" % roundi(value * 100.0)
		&"offline_cap_seconds": return "offline até %dh" % roundi(value / 3600.0)
		&"route_reward_multiplier": return "rota paga +%d%%" % roundi(value * 100.0)
		&"route_slots": return "+%d rota simultânea" % roundi(value)
		&"event_reward_multiplier": return "evento paga +%d%%" % roundi(value * 100.0)
		&"event_duration_multiplier": return "evento dura +%d%%" % roundi(value * 100.0)
	return str(node.get("id", "no"))


func _missing_parent(node: Dictionary, owned: Dictionary) -> String:
	## The name of the first unbought prerequisite, or empty. Named rather than
	## merely greyed: a locked row with no sentence is indistinguishable from a
	## broken one, which is the lesson the shop already learned.
	for required in node.get("requires", []):
		if not owned.has(StringName(required)):
			var parent := PrestigeDB.get_node(StringName(required))
			return str(parent.get("title", required))
	return ""


func _purchase(id: StringName) -> void:
	if id.is_empty(): return
	var callback: Callable = _callbacks.get("purchase_node", Callable())
	if callback.is_valid():
		callback.call(id)
	node_purchase_requested.emit(id)
	# The purchase has already been committed by whoever owns the economy, so the
	# tree can simply re-read it. Without this the row you just bought went on
	# advertising itself for sale until the game was restarted.
	_refresh_tree()


func _call(callback_name: String, fallback: Variant) -> Variant:
	var callback: Callable = _callbacks.get(callback_name, Callable())
	return callback.call() if callback.is_valid() else fallback


func _layout() -> void:
	if _panel == null or not is_instance_valid(_panel): return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var wanted := Vector2(minf(400.0, safe.size.x - 16.0),
		minf(480.0, safe.size.y - 20.0))
	_panel.custom_minimum_size = wanted
	_panel.size = wanted
	if _summary != null:
		# Autowrap needs a real width before the column asks for its height.
		_summary.custom_minimum_size.x = wanted.x - 24.0
	if _tree != null:
		_tree.custom_minimum_size.x = wanted.x - 44.0
	_panel.position = safe.position + (safe.size - _panel.size) * 0.5
	_backdrop.visible = _open
	_panel.visible = _open
