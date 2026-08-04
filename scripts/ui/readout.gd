class_name Readout
extends VBoxContainer
## The TEU tally: a lit counter behind glass, with the rate on a tag beside it.
##
## A clicker's main number is the thing the player looks at most, so it is the
## one piece of interface built as an instrument rather than a caption — amber
## digits behind dark glass set into the gantry, the way a weighbridge totaliser
## reads on a real terminal.
##
## Geometry is fixed by construction, which is the whole point of a counter: the
## glass is a window of a fixed width sized for the widest number the game can
## produce, and the digits are right-aligned inside it. Nothing in the HUD moves
## when the tally rolls over from 999 to 1.00K, and the rate tag beside it never
## gets shoved sideways.
##
## The cells the number has not reached yet are not left blank — they carry unlit
## eights, the way a real totaliser shows the segments it is not driving. That is
## what makes the reserved width read as a window rather than as a gap, and it
## turns the fixed geometry into the progress bar the tally never had: the dark
## digits burn away from the left as the terminal grows.

const REFRESH := 0.05
## How long the glass stays lit after the number goes up, and how hard.
const FLASH_TIME := 0.22
const FLASH_TINT := Color(1.5, 1.32, 1.0)
## The widest string `GameState.fmt` can return: three significant digits, a
## decimal point and the longest suffix. The window is cut for this and never
## resized, so the digits have somewhere to grow into instead of pushing.
const WIDEST := "8.88Qa"
## What an undriven cell shows. The font is monospace — every glyph advances one
## 6px cell — so the unlit run and the lit number tile against each other exactly
## and never overlap by a pixel.
const UNLIT := "8"
## The smallest production lift worth announcing. Below 1% the badge would fire
## on every rounding wobble and stop meaning "you just changed something".
const LIFT_FLOOR := 0.01
const LIFT_HOLD := 1.6

var _glass: PanelContainer
var _lift_label: Label
var _last_cps := -1.0
var _teus_label: Label
var _unlit_label: Label
var _rate_tag: PanelContainer
var _rate_label: Label
var _shares_row: HBoxContainer
var _shares_label: Label
var _boost_row: HBoxContainer
var _boost_label: Label
var _digit_ink := UiTheme.DIGIT
var _pending := "0"
var _shown := ""
var _tick := 0.0
var _flash := 0.0


func setup() -> void:
	## There is exactly one tally in the game now. It used to exist twice — over
	## the port in portrait and again inside the command rail on a wide screen —
	## which was two copies of the same number to keep in step. The gantry spans
	## the world in both profiles, so the rail no longer needs its own.
	add_theme_constant_override(&"separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_glass = UiTheme.panel(UiTheme.glass_style(3))
	row.add_child(_glass)
	var tally := HBoxContainer.new()
	tally.add_theme_constant_override(&"separation", 4)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.add_child(tally)
	var icon := UiTheme.icon(UiTheme.Icon.TEU)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tally.add_child(icon)
	_teus_label = UiTheme.label("0", UiTheme.SIZE_TITLE, _digit_ink)
	# Right-aligned in a fixed window: the number grows leftwards into space that
	# was always reserved for it, so no digit ever moves once it is on screen.
	_teus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_teus_label.custom_minimum_size.x = ceilf(UiTheme.FONT.get_string_size(
		WIDEST, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_TITLE).x)
	tally.add_child(_teus_label)

	# The unlit run is a child of the digits, not a sibling: inside the tally row
	# it would be one more box for the layout to pack, and shortening it as the
	# number grows would shove the number sideways — the one thing this whole
	# control exists to prevent.
	_unlit_label = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.HULL)
	_unlit_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_teus_label.add_child(_unlit_label)

	# The rate is a service tag bolted beside the counter rather than a second
	# line under it: the bar is one instrument high, and this is what keeps it
	# that way.
	_rate_tag = UiTheme.panel(UiTheme.tag_style(3))
	_rate_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_rate_tag)
	var rate := HBoxContainer.new()
	rate.add_theme_constant_override(&"separation", 4)
	rate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rate_tag.add_child(rate)
	_rate_label = UiTheme.label("0 TEU/s", UiTheme.SIZE_SMALL, UiTheme.TEAL_LIGHT)
	rate.add_child(_rate_label)
	# Rides inside the tag rather than beside it, so announcing a lift cannot
	# resize the instrument the rest of the bar is measured from.
	_lift_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_lift_label.visible = false
	rate.add_child(_lift_label)

	_shares_row = HBoxContainer.new()
	_shares_row.add_theme_constant_override(&"separation", 2)
	_shares_row.visible = false
	_shares_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate.add_child(_shares_row)
	_shares_row.add_child(UiTheme.icon(UiTheme.Icon.STAR))
	_shares_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIGIT)
	_shares_row.add_child(_shares_label)

	_boost_row = HBoxContainer.new()
	_boost_row.add_theme_constant_override(&"separation", 2)
	_boost_row.visible = false
	_boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate.add_child(_boost_row)
	_boost_row.add_child(UiTheme.icon(UiTheme.Icon.PAW))
	_boost_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.STEEL_DIM)
	_boost_row.add_child(_boost_label)

	UiTheme.describe(self, "Contêineres movimentados",
		"Total do terminal e a taxa por segundo")
	EventBus.teus_changed.connect(_on_teus)
	EventBus.cps_changed.connect(_on_cps)
	_on_teus(GameState.teus)
	_on_cps(GameState.cps)


func tally_rect() -> Rect2:
	return get_global_rect()


func _process(delta: float) -> void:
	# The economy is exact every frame; the digits only need to be readable, so
	# they are repainted at most twenty times a second.
	_tick += delta
	if _tick >= REFRESH:
		_tick = 0.0
		if _shown != _pending:
			_shown = _pending
			_teus_label.text = _pending
			_unlit_label.text = UNLIT.repeat(
				maxi(0, WIDEST.length() - _pending.length()))
	if GameState.boost_time > 0.0:
		_boost_row.visible = true
		_boost_label.text = "x%d %ds" % [int(GameState.CAT_BOOST_MULT),
			ceili(GameState.boost_time)]
	elif _boost_row.visible:
		_boost_row.visible = false
	_burn_flash(delta)


func _burn_flash(delta: float) -> void:
	## Earning lights the glass for a fifth of a second. It is the cheapest
	## possible "that paid" — no geometry moves, so it can fire on every credited
	## box without the bar ever twitching.
	if _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta / FLASH_TIME)
	var k := _flash * _flash
	_glass.self_modulate = Color.WHITE.lerp(FLASH_TINT, k)
	_teus_label.label_settings.font_color = _digit_ink.lerp(UiTheme.CREAM, k)


func _on_teus(total: float) -> void:
	var next := GameState.fmt(total)
	if next != _pending and total > 0.0 and _flash <= 0.0 \
			and UserPreferences.can_animate():
		_flash = 1.0
	_pending = next


func _on_cps(cps: float) -> void:
	## The rate tag is the one place the game states what a purchase did. Before
	## this it simply held a new number, and a number that changes silently while
	## a shop is covering the screen is a number nobody sees change — which is
	## most of "I buy things and nothing happens".
	var lift := 0.0 if _last_cps <= 0.0 else (cps - _last_cps) / _last_cps
	_rate_label.text = GameState.fmt(cps) + " TEU/s"
	if cps > _last_cps and lift >= LIFT_FLOOR and UserPreferences.can_animate():
		_lift_label.text = "+%d%%" % roundi(lift * 100.0)
		_lift_label.visible = true
		var tween := create_tween()
		tween.tween_property(_lift_label, "modulate:a", 1.0, 0.10) \
			.from(0.0)
		tween.tween_interval(LIFT_HOLD)
		tween.tween_property(_lift_label, "modulate:a", 0.0, 0.35)
		tween.tween_callback(func() -> void: _lift_label.visible = false)
	_last_cps = cps
	_shares_row.visible = GameState.shares > 0
	if _shares_row.visible:
		_shares_label.text = str(GameState.shares)
