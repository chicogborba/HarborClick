class_name OfflinePopup
extends CanvasLayer
## "While you were away" board, shown once when idle income piled up.

var _dim: ColorRect
var _panel: PanelContainer
## Every line here is short on purpose. Autowrap inside a `PanelContainer` asks
## for a height against a width the panel does not have yet, and Godot defers the
## recalculation, so the board measured 1719 px tall against a 692 px viewport
## and then drew as an empty sheet. Short single lines have a stable minimum from
## the first frame.
const MAX_LINE := 38

func _ready() -> void:
	layer = 10
	if SaveManager.offline_earnings <= 0.0:
		queue_free()
		return
	_build(SaveManager.offline_earnings, SaveManager.offline_report)
	SaveManager.offline_earnings = 0.0
	SaveManager.offline_report = {}
	get_viewport().size_changed.connect(_layout)


static func format_duration(seconds: float) -> String:
	## Whole hours and minutes. "29100 s" is a log line, not an answer to "how
	## long was I gone".
	var total := int(roundf(maxf(0.0, seconds)))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%dh%02d" % [hours, minutes] if minutes > 0 else "%dh" % hours
	if minutes > 0:
		return "%dmin" % minutes
	return "%ds" % total


static func greeting(report: Dictionary) -> String:
	var away := float(report.get("away_seconds", 0.0))
	if away <= 0.0:
		return Loc.t("offline.greeting.short")
	return Loc.t("offline.greeting.away", {"time": format_duration(away)})


static func breakdown_lines(report: Dictionary) -> Array[String]:
	## Built as data so the board and its regression test read the same strings.
	var lines: Array[String] = []
	if report.is_empty():
		return lines
	lines.append(Loc.t("offline.counted", {
		"time": format_duration(float(report.get("credited_seconds", 0.0))),
		"rate": GameState.fmt(float(report.get("rate", 0.0))),
		"pct": str(roundi(float(report.get("efficiency", 0.0)) * 100.0))}))
	if float(report.get("capped_seconds", 0.0)) > 0.0:
		lines.append(Loc.t("offline.capped", {
			"time": format_duration(float(report.get("cap_seconds", 0.0))),
			"amount": GameState.fmt(float(report.get("lost_to_cap", 0.0)))}))
	return lines


func _build(amount: float, report: Dictionary) -> void:
	_dim = UiTheme.scrim(0.62)
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	_panel.add_child(col)

	var title := UiTheme.label(Loc.t("offline.title"), UiTheme.SIZE_BODY, UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	col.add_child(_line(greeting(report), UiTheme.INK_SOFT))

	var readout := UiTheme.panel(UiTheme.slate_style(true, 6))
	col.add_child(readout)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.TEU, 2))
	row.add_child(UiTheme.label(GameState.fmt(amount) + " TEU",
		UiTheme.SIZE_TITLE, UiTheme.AMBER))

	_add_breakdown(col, report)

	var button := UiTheme.button(Loc.t("offline.ok"))
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		queue_free())
	col.add_child(button)

	_layout()
	UiTheme.pop_open(_panel, _dim)


func _add_breakdown(col: VBoxContainer, report: Dictionary) -> void:
	## Total without an account reads as an arbitrary gift, and a cap that is
	## never named reads as production that disappeared. The player gets the same
	## two lines the code used: how long counted, at what rate and share, and
	## what the cap refused to pay.
	var lines := breakdown_lines(report)
	for index in lines.size():
		col.add_child(_line(lines[index],
			UiTheme.DANGER if index > 0 else UiTheme.INK_SOFT))


func _line(text: String, color: Color) -> Label:
	var label := UiTheme.label(text, UiTheme.SIZE_SMALL, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func apply_view_metrics(metrics: Dictionary) -> void:
	_layout(metrics.get("safe_rect", Rect2(Vector2.ZERO,
		get_viewport().get_visible_rect().size)))


func _layout(safe_rect: Rect2 = Rect2()) -> void:
	if _panel == null:
		return
	if safe_rect.size == Vector2.ZERO:
		safe_rect = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var width := minf(safe_rect.size.x - 32.0, 360.0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.size = Vector2(width, _panel.get_combined_minimum_size().y)
	_panel.position = safe_rect.position + (safe_rect.size - _panel.size) * 0.5
	_panel.pivot_offset = _panel.size / 2.0
