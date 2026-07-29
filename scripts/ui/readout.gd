class_name Readout
extends VBoxContainer
## The TEU tally, the rate, the golden shares and the cat timer.
##
## It exists in two places and must never be two implementations: floating over
## the port in portrait, and set into the command rail on a wide screen. The
## only difference is the ink — outlined cream over the world, plain ink on
## paper — so `style` picks the palette and everything else is shared.
##
## Geometry is fixed by construction: the icon sits at a constant offset and
## the digits are left-aligned, so only the number's unused right edge moves
## when the value changes.

enum Style { WORLD, PAPER }

const REFRESH := 0.05

var _teus_label: Label
var _rate_label: Label
var _shares_row: HBoxContainer
var _shares_label: Label
var _boost_row: HBoxContainer
var _boost_label: Label
var _pending := "0"
var _tick := 0.0


func setup(style: Style = Style.WORLD) -> void:
	add_theme_constant_override(&"separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := UiTheme.CREAM if style == Style.WORLD else UiTheme.INK
	var small := UiTheme.AMBER if style == Style.WORLD else UiTheme.AMBER_DEEP
	var accent := UiTheme.TEAL_LIGHT if style == Style.WORLD else UiTheme.TEAL_DEEP
	# Over the port the text has no panel behind it, so it carries its own
	# outline; on paper an outline would just look muddy.
	var outline := 3 if style == Style.WORLD else 0

	var tally := HBoxContainer.new()
	tally.add_theme_constant_override(&"separation", 5)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tally)
	var icon := UiTheme.icon(UiTheme.Icon.TEU, 2)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tally.add_child(icon)
	_teus_label = UiTheme.label("0", UiTheme.SIZE_TITLE, big)
	_teus_label.label_settings = UiTheme.settings(UiTheme.SIZE_TITLE, big, outline)
	tally.add_child(_teus_label)

	var rate := HBoxContainer.new()
	rate.add_theme_constant_override(&"separation", 6)
	rate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rate)
	_rate_label = UiTheme.label("0 TEU/s", UiTheme.SIZE_SMALL, small)
	_rate_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_SMALL, small, maxi(outline - 1, 0))
	rate.add_child(_rate_label)

	_shares_row = HBoxContainer.new()
	_shares_row.add_theme_constant_override(&"separation", 2)
	_shares_row.visible = false
	_shares_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate.add_child(_shares_row)
	_shares_row.add_child(UiTheme.icon(UiTheme.Icon.STAR))
	_shares_label = UiTheme.label("", UiTheme.SIZE_SMALL, small)
	_shares_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_SMALL, small, maxi(outline - 1, 0))
	_shares_row.add_child(_shares_label)

	_boost_row = HBoxContainer.new()
	_boost_row.add_theme_constant_override(&"separation", 2)
	_boost_row.visible = false
	_boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate.add_child(_boost_row)
	_boost_row.add_child(UiTheme.icon(UiTheme.Icon.PAW))
	_boost_label = UiTheme.label("", UiTheme.SIZE_SMALL, accent)
	_boost_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_SMALL, accent, maxi(outline - 1, 0))
	_boost_row.add_child(_boost_label)

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
		if _teus_label.text != _pending:
			_teus_label.text = _pending
	if GameState.boost_time > 0.0:
		_boost_row.visible = true
		_boost_label.text = "x%d %ds" % [int(GameState.CAT_BOOST_MULT),
			ceili(GameState.boost_time)]
	elif _boost_row.visible:
		_boost_row.visible = false


func _on_teus(total: float) -> void:
	_pending = GameState.fmt(total)


func _on_cps(cps: float) -> void:
	_rate_label.text = GameState.fmt(cps) + " TEU/s"
	_shares_row.visible = GameState.shares > 0
	if _shares_row.visible:
		_shares_label.text = str(GameState.shares)
