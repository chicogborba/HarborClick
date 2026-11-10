class_name PlaceholderAdProvider
extends AdProvider
## The test stand-in for a real ad SDK: a scrim with a paper board that says
## what is happening and counts 3-2-1, then reports success. On a headless
## display there is nobody to watch the countdown, so it resolves at once.
##
## The close X reports failure, which is how the "failure pays nothing" rule
## is exercised before any real SDK is wired in.

const CANVAS_LAYER := 20
const COUNTDOWN_STEPS := 3
const STEP_SECONDS := 1.0

var _layer: CanvasLayer
var _count_label: Label
var _timer: Timer
var _placement: StringName = &""
var _remaining: int = 0
var _showing: bool = false


func _ready() -> void:
	_build()


func show_rewarded(placement: StringName) -> void:
	if _showing:
		# A second request while one is on screen refuses and pays nothing.
		finished.emit(placement, false)
		return
	_showing = true
	_placement = placement
	_remaining = COUNTDOWN_STEPS
	_count_label.text = str(_remaining)
	_layer.visible = true
	if DisplayServer.get_name() == "headless":
		_finish(true)
		return
	_timer.start(STEP_SECONDS)


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = &"AdLayer"
	_layer.layer = CANVAS_LAYER
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.name = &"AdRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	root.add_child(UiTheme.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var board := UiTheme.panel(UiTheme.board_style(16), false)
	board.custom_minimum_size = Vector2(240, 0)
	center.add_child(board)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	board.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(UiTheme.label(Loc.t("ad.placeholder.title"), UiTheme.SIZE_TITLE))
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spring)
	var close := UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost",
		UiTheme.TOUCH_MIN, Loc.t("ad.placeholder.close"))
	close.pressed.connect(_on_close_pressed)
	head.add_child(close)
	_count_label = UiTheme.label(str(COUNTDOWN_STEPS), UiTheme.SIZE_HUGE, UiTheme.AMBER_DEEP)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_count_label)
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func _on_timer_timeout() -> void:
	_remaining -= 1
	if _remaining <= 0:
		_finish(true)
		return
	_count_label.text = str(_remaining)


func _on_close_pressed() -> void:
	_finish(false)


func _finish(rewarded: bool) -> void:
	if not _showing:
		return
	_timer.stop()
	_showing = false
	_layer.visible = false
	var placement := _placement
	_placement = &""
	finished.emit(placement, rewarded)
