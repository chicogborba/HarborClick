class_name NpcCard
extends CanvasLayer
## Somebody's staff badge: their face, their name, their trade, and the one job
## they are on right now.
##
## It has been cut twice. First from a dossier — a clipboard of captioned rows
## with a name at the top and no picture anywhere on it, which is a form about a
## person rather than a person. Then from the card that replaced it, which still
## carried a station line, a joining date, a tally row, a paragraph of dossier
## prose and a gloss on the trade: six blocks of text under a thumbnail, in an
## overlay opened by tapping somebody in passing.
##
## What is left is a badge. Photograph at 3x, name, trade and post on one line,
## a stamp for the tally, and the live task. The whole shift in detail is what
## the journal's EQUIPE tab is for, and the prose still reaches a screen reader
## through the card's description — nobody has to *read* a card to use it.
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
var _column: VBoxContainer
var _photo: PanelContainer
var _name: Label
var _role: Label
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

	# One margin, one column, four things in it. There is no scroll container any
	# more: nothing on this card is long enough to need one, which is the point.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		gutter.add_theme_constant_override(side, 8)
	body.add_child(gutter)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override(&"separation", 7)
	gutter.add_child(_column)

	# --- the photograph, and the identity printed beside it ---
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override(&"separation", 9)
	_column.add_child(identity)
	# Mounted at 3x rather than 2x. A staff card is a picture of somebody with
	# their name next to it, so the picture is the biggest thing on it.
	_photo = UiTheme.panel(UiTheme.photo_style())
	_photo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(_photo)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override(&"separation", 3)
	identity.add_child(titles)
	_name = UiTheme.label("", UiTheme.SIZE_TITLE)
	_name.clip_text = true
	titles.add_child(_name)
	_role = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_role.clip_text = true
	titles.add_child(_role)
	# The tally as a stamp on the card rather than as a labelled row of its own.
	# "Tarefas" covers all three trades: a crane's completed task is a container,
	# a conferente's is a stack checked, a driver's is a round trip.
	var tally_row := HBoxContainer.new()
	tally_row.add_theme_constant_override(&"separation", 4)
	titles.add_child(tally_row)
	var tally_stamp := UiTheme.stamp("0", UiTheme.AMBER, UiTheme.SIZE_SMALL)
	tally_row.add_child(tally_stamp)
	_tally = UiTheme.stamp_label(tally_stamp)
	var tally_word := UiTheme.label("tarefas", UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	tally_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tally_row.add_child(tally_word)

	# The one line that changes while the card is open: what they are on now.
	# Everything else the card used to carry — station, joining date, dossier
	# prose, the duty gloss — was a form about a person rather than a person, and
	# the shift as a whole is what the journal's EQUIPE tab is for.
	var task_row := HBoxContainer.new()
	task_row.add_theme_constant_override(&"separation", 5)
	_column.add_child(task_row)
	var glove := UiTheme.icon(UiTheme.Icon.GLOVE)
	glove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	task_row.add_child(glove)
	_objective = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_row.add_child(_objective)

	_layout()


func show_profile(profile: NpcProfile, dossier: Dictionary = {}) -> void:
	if profile == null:
		return
	_profile = profile
	_last_focus = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	_set_photo(profile)
	_name.text = profile.display_name
	_role.text = "%s  •  %s" % [profile.title().to_upper(),
		_station_words(profile.station())]
	set_objective(str(dossier.get("objective", "")), str(dossier.get("stage", "")))
	_tally.text = str(profile.moves)
	# The card shows four things; a screen reader still gets the whole person,
	# because there is no cost to a long description and every cost to a long
	# card.
	var story := profile.dossier
	if not profile.trait_line.is_empty():
		story += " " + profile.trait_line
	UiTheme.describe(_card, "Crachá de %s" % profile.display_name,
		"%s. %s. %s" % [profile.title(), profile.duty(), story])
	visible = true
	_layout()
	open_changed.emit(true)
	_close.grab_focus()
	# The wrapped task line only reports its true height after a layout pass,
	# so the fit comes first and the rise waits for the fit: the badge now
	# comes up like every other board — from below, at its final size — where
	# it used to fade in and resize a frame later.
	if is_inside_tree():
		await get_tree().process_frame
		if not visible:
			return
	_fit_now()
	UiTheme.pop_open(_card, _scrim, true)


func _set_photo(profile: NpcProfile) -> void:
	for child in _photo.get_children():
		child.queue_free()
	# Drawn bare-headed rather than in a hat they would never wear. The portrait
	# carries hair under the overlay, so dropping it leaves a face rather than a
	# hole.
	_photo.add_child(UiTheme.portrait(UiTheme.portrait_index(profile),
		profile.hat_color, not BAREHEADED.has(profile.role), 3))


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
	## Four rows of card, not half a screen. The cap came down with the content:
	## a badge padded out to the old height would be laminate with nothing on it.
	return minf(maxf(132.0, safe.size.y * 0.28), safe.size.y - 24.0)


func _fit_now() -> void:
	## Shrink to the task line once it has actually wrapped — one line for most
	## people, two for a relay leg — but in the same frame the caller answers
	## for it, so nothing resizes while the card is in flight.
	if _card == null or not is_instance_valid(_card):
		return
	var safe := _safe()
	var wanted := _card.get_combined_minimum_size().y
	_card.size.y = clampf(wanted, 120.0, _cap_height(safe))
	_place(safe)


func _safe() -> Rect2:
	if _safe_rect.size != Vector2.ZERO:
		return _safe_rect
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
