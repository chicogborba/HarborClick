class_name NpcCard
extends CanvasLayer
## Somebody's staff badge: photo, name, station, and what they are on right now.
##
## This used to be a dossier — a clipboard of captioned rows with a name at the
## top and no picture anywhere on it, which is a form about a person rather than
## a person. A terminal issues its people a card with their face on it, so that
## is what tapping somebody hands you: laminate, a teal header with the port's
## name, a mounted photograph, and the record printed beside it.
##
## It is the one overlay that is not paper off the manifest and not steel bolted
## to the port, because it is neither: it is the thing clipped to their vest.

signal open_changed(opened: bool)

## Roles that work outdoors in a hard hat. The despachante sits in the gate
## office and the tug master is on a boat; a hard hat on either is a costume.
const BAREHEADED := ["alfandega", "rebocador"]

var _scrim: ColorRect
var _card: PanelContainer
var _clip: TextureRect
var _scroll: ScrollContainer
var _column: VBoxContainer
var _photo: PanelContainer
var _name: Label
var _role: Label
var _station: Label
var _joined: Label
var _dossier: Label
var _duty: Label
var _objective: Label
var _tally: Label
var _close: Button
var _safe_rect := Rect2()
var _profile: NpcProfile
var _last_focus: Control


func _ready() -> void:
	layer = 11
	visible = false
	_scrim = UiTheme.scrim(0.42)
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_card = UiTheme.panel(UiTheme.badge_style(0), false)
	add_child(_card)
	_clip = UiTheme.badge_clip()
	add_child(_clip)

	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 0)
	_card.add_child(body)

	# --- the header band: whose card this is, and who issued it ---
	var head := UiTheme.panel(UiTheme.badge_head_style(), false)
	body.add_child(head)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override(&"separation", 4)
	head.add_child(head_row)
	head_row.add_child(UiTheme.icon(UiTheme.Icon.GLOVE))
	var issuer := UiTheme.label("CRACHÁ DO TERMINAL", UiTheme.SIZE_SMALL,
		UiTheme.CREAM)
	issuer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	issuer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	issuer.clip_text = true
	head_row.add_child(issuer)
	_close = UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 24.0, "Fechar crachá")
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	head_row.add_child(_close)

	# The dossier is prose, and prose wraps to a height nobody can predict at
	# layout time. The card therefore has a size the safe area decides and the
	# content scrolls inside it — which is also the only way a long dossier can be
	# guaranteed not to hang off a 320px phone.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.style_scroll(_scroll)
	body.add_child(_scroll)
	# The reserved scrollbar sits inside the card, so right-aligned stamps have to
	# be held off it — "30/07/2026" ended with its last digit under the grip.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		gutter.add_theme_constant_override(side, 6)
	gutter.add_theme_constant_override(&"margin_right", 4)
	_scroll.add_child(gutter)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override(&"separation", 5)
	gutter.add_child(_column)

	# --- the photograph, and the identity printed beside it ---
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override(&"separation", 7)
	_column.add_child(identity)
	_photo = UiTheme.panel(UiTheme.photo_style())
	_photo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	identity.add_child(_photo)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override(&"separation", 1)
	identity.add_child(titles)
	_name = UiTheme.label("", UiTheme.SIZE_TITLE)
	_name.clip_text = true
	titles.add_child(_name)
	_role = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_role)
	_station = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_station.clip_text = true
	titles.add_child(_station)
	var joined_stamp := UiTheme.stamp("", UiTheme.AMBER, UiTheme.SIZE_SMALL)
	titles.add_child(joined_stamp)
	_joined = UiTheme.stamp_label(joined_stamp)
	_joined.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_column.add_child(UiTheme.divider())

	# The task comes before the prose. It is the reason the player tapped, it is
	# the only line that changes while the card is open, and on a wide screen a
	# long dossier pushed it below the fold — a card about somebody working that
	# had to be scrolled to find out what they were working on.
	var task_row := HBoxContainer.new()
	task_row.add_theme_constant_override(&"separation", 5)
	_column.add_child(task_row)
	task_row.add_child(UiTheme.icon(UiTheme.Icon.GLOVE))
	_objective = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_row.add_child(_objective)

	var tally_row := HBoxContainer.new()
	tally_row.add_theme_constant_override(&"separation", 5)
	_column.add_child(tally_row)
	# "Tarefas", not "movimentos": for a crane a completed task is a container,
	# but for a conferente it is a stack checked and for a driver it is a round
	# trip. One honest word covers all three.
	var tally_label := UiTheme.label("TAREFAS FEITAS", UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	tally_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tally_row.add_child(tally_label)
	var tally_stamp := UiTheme.stamp("0", UiTheme.AMBER, UiTheme.SIZE_SMALL)
	tally_row.add_child(tally_stamp)
	_tally = UiTheme.stamp_label(tally_stamp)

	_column.add_child(UiTheme.divider())

	# The dossier is the flavour, so it is the part that may scroll.
	_dossier = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_dossier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_dossier)

	_duty = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_duty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_duty)

	_layout()


func show_profile(profile: NpcProfile, dossier: Dictionary = {}) -> void:
	if profile == null:
		return
	_profile = profile
	_last_focus = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	_set_photo(profile)
	_name.text = profile.display_name
	_role.text = profile.title().to_upper()
	_station.text = "POSTO: %s" % _station_words(profile.station())
	_joined.text = profile.joined_text()
	var story := profile.dossier
	if not profile.trait_line.is_empty():
		story += " " + profile.trait_line
	_dossier.text = story
	_duty.text = "Função no porto: %s" % profile.duty()
	set_objective(str(dossier.get("objective", "")), str(dossier.get("stage", "")))
	_tally.text = str(profile.moves)
	UiTheme.describe(_card, "Crachá de %s" % profile.display_name,
		"%s. %s" % [profile.title(), story])
	visible = true
	_layout()
	open_changed.emit(true)
	_close.grab_focus()
	_fit_to_content()


func _set_photo(profile: NpcProfile) -> void:
	for child in _photo.get_children():
		child.queue_free()
	# Drawn bare-headed rather than in a hat they would never wear. The portrait
	# carries hair under the overlay, so dropping it leaves a face rather than a
	# hole.
	_photo.add_child(UiTheme.portrait(UiTheme.portrait_index(profile),
		profile.hat_color, not BAREHEADED.has(profile.role)))


func _station_words(station: StringName) -> String:
	match station:
		NpcCatalog.STATION_BERTH: return "Berço"
		NpcCatalog.STATION_YARD: return "Pátio"
		NpcCatalog.STATION_STACK: return "Pilha"
		NpcCatalog.STATION_ROAD: return "Estrada"
		NpcCatalog.STATION_GATE: return "Portão"
		NpcCatalog.STATION_CITY: return "Cidade"
		NpcCatalog.STATION_MANOEUVRE: return "Manobra"
		_: return "Terminal"


func set_objective(objective: String, stage: String) -> void:
	## Recomputed live by whoever owns the actor, so a card left open while the
	## berth works counts up instead of freezing on the moment it was tapped.
	if objective.is_empty():
		_objective.text = "Sem tarefa agora, aguardando serviço."
		return
	# Hyphen and bullet, never an em dash: the bitmap font has no glyph for one and
	# prints a hollow box instead.
	_objective.text = objective if stage.is_empty() \
		else "%s - %s" % [objective, stage]


func profile() -> NpcProfile:
	return _profile


func close() -> void:
	if not visible:
		return
	visible = false
	_profile = null
	open_changed.emit(false)
	UiTheme.restore_focus(_last_focus)
	_last_focus = null


func is_open() -> bool:
	return visible


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _on_scrim_input(event: InputEvent) -> void:
	## Tapping the port around the card puts it away, which is what a card you
	## opened by tapping the port should do.
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed:
		close()
		return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT \
			and not click.pressed:
		close()


func _layout() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var safe := _safe()
	# Narrow enough for a 320px phone with its margins, and a little over half the
	# safe area tall: this is a card over a live port, not a full sheet, and the
	# port has to stay visible behind it.
	_card.size = Vector2(minf(288.0, safe.size.x - 20.0), _cap_height(safe))
	_place(safe)


func _place(safe: Rect2) -> void:
	_card.position = Vector2(
		safe.position.x + (safe.size.x - _card.size.x) * 0.5,
		safe.position.y + safe.size.y - _card.size.y - 10.0)
	# The clip straddles the top edge, and stands down when the card is tall
	# enough to reach the top of the safe area rather than being drawn over the
	# gantry.
	var top := _card.position.y - _clip.size.y + 3.0
	_clip.visible = visible and top >= safe.position.y + 6.0
	_clip.position = Vector2(
		_card.position.x + (_card.size.x - _clip.size.x) * 0.5, top)


func _cap_height(safe: Rect2) -> float:
	return minf(maxf(190.0, safe.size.y * 0.56), safe.size.y - 24.0)


func _fit_to_content() -> void:
	## Shrink to the prose once it has actually wrapped. A dossier is one to six
	## lines depending on the person, and a card padded out to a fixed height for
	## the short ones is dead space over the port. Measuring before the layout pass
	## is what produced a card several thousand pixels tall, so this deliberately
	## waits a frame and stays clamped to the cap either way.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not visible or _card == null or not is_instance_valid(_card):
		return
	var safe := _safe()
	var wanted := _card.get_combined_minimum_size().y
	_card.size.y = clampf(wanted, 170.0, _cap_height(safe))
	_place(safe)


func _safe() -> Rect2:
	if _safe_rect.size != Vector2.ZERO:
		return _safe_rect
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
