class_name PixelSlider
extends Control
## A level you can actually set: drag it, tap it, or arrow it.
##
## Godot's own `HSlider` is a fine control and the wrong one here — its grabber
## is a theme texture the game does not have, and every part of this interface is
## drawn from the same nine-patch sprites. So this is a `Control` that draws the
## same well and fill the progress bars already use, in fixed steps.
##
## Three ways in, because a settings screen is used on all of them:
##
## * **Touch/mouse** — press anywhere on the track and it jumps there, then
##   tracks the finger. Jumping to the press point rather than requiring a grab
##   is what makes a 12px-tall control usable with a thumb.
## * **Keyboard** — left/right by one step, home/end for the ends. The control
##   is focusable, so it is reachable in the same tab order as everything else.
## * **Screen reader** — `accessibility_name` carries the row it belongs to and
##   the value, and is re-stated on every change.
##
## The value is always a multiple of `step`, so a player can land on the same
## level twice. It is *not* continuous, deliberately.

signal value_changed(value: float)
## Emitted when the drag ends, for callers that want to be told once rather than
## sixty times a second — playing a preview sound per pixel of drag is noise.
signal drag_finished(value: float)

const TRACK_HEIGHT := 12.0
## Bigger than the track it draws, so the finger target obeys the same 44px rule
## the rest of the interface does while the drawing stays 12px of pixel art.
const HIT_HEIGHT := 28.0
## Where the tick marks go, as fractions of the track.
const TICKS := [0.25, 0.5, 0.75]

var value := 0.0
var step := 0.05
var accessible_label := ""

var _dragging := false
var _bg: StyleBoxTexture
var _fill: StyleBoxTexture


func _init(initial: float = 0.0, value_step: float = 0.05) -> void:
	step = maxf(0.01, value_step)
	value = _snap(initial)
	var styles := UiTheme.bar_styles()
	_bg = styles[0]
	_fill = styles[1]
	custom_minimum_size = Vector2(64.0, HIT_HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_value_silently(new_value: float) -> void:
	## For a refresh that is restating what the model already says. Emitting here
	## would let a refresh drive the very setter that caused it.
	var wanted := _snap(new_value)
	if is_equal_approx(value, wanted):
		return
	value = wanted
	queue_redraw()
	_publish()


func percent() -> int:
	return roundi(value * 100.0)


# --------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			grab_focus()
			_dragging = true
			_set_from_position(button.position.x)
		elif _dragging:
			_dragging = false
			drag_finished.emit(value)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_position((event as InputEventMouseMotion).position.x)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			grab_focus()
			_dragging = true
			_set_from_position(touch.position.x)
		elif _dragging:
			_dragging = false
			drag_finished.emit(value)
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_set_from_position((event as InputEventScreenDrag).position.x)
		accept_event()
	elif event is InputEventKey and event.is_pressed():
		_key_input(event as InputEventKey)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT \
			or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _key_input(key: InputEventKey) -> void:
	## Left/right adjust rather than move focus. That costs arrow navigation off
	## this one control, which is the trade every slider makes — Tab still leaves,
	## and a slider that cannot be nudged from a keyboard is unusable without a
	## pointer.
	var moved := false
	match key.keycode:
		KEY_LEFT, KEY_DOWN:
			_apply(value - step)
			moved = true
		KEY_RIGHT, KEY_UP:
			_apply(value + step)
			moved = true
		KEY_HOME:
			_apply(0.0)
			moved = true
		KEY_END:
			_apply(1.0)
			moved = true
	if moved:
		drag_finished.emit(value)
		accept_event()


func _set_from_position(x: float) -> void:
	var track := _track_rect()
	if track.size.x <= 0.0:
		return
	_apply((x - track.position.x) / track.size.x)


func _apply(raw: float) -> void:
	var wanted := _snap(raw)
	if is_equal_approx(value, wanted):
		return
	value = wanted
	queue_redraw()
	_publish()
	value_changed.emit(value)


func _snap(raw: float) -> float:
	if not is_finite(raw):
		return 0.0
	return clampf(snappedf(clampf(raw, 0.0, 1.0), step), 0.0, 1.0)


func _publish() -> void:
	## Restated on every change: a screen reader announces the accessible name,
	## and a name that still says the old percentage is worse than none.
	accessibility_name = "%s: %d%%" % [accessible_label, percent()] \
		if not accessible_label.is_empty() else "%d%%" % percent()


# ---------------------------------------------------------------------- draw

func _track_rect() -> Rect2:
	return Rect2(Vector2(0.0, (size.y - TRACK_HEIGHT) * 0.5),
		Vector2(size.x, TRACK_HEIGHT))


func _draw() -> void:
	var track := _track_rect()
	draw_style_box(_bg, track)
	# Whole pixels. A fill that lands on a half pixel makes the nine-patch's own
	# border blur, which is the one thing the art cannot survive.
	var filled := roundf(track.size.x * value)
	if filled >= 2.0:
		draw_style_box(_fill, Rect2(track.position, Vector2(filled, track.size.y)))
	for fraction: float in TICKS:
		var x := roundf(track.position.x + track.size.x * fraction)
		# Ticks sit under the fill, not over it: a mark drawn on top of the amber
		# reads as a notch cut out of the level.
		if x <= track.position.x + filled:
			continue
		draw_rect(Rect2(Vector2(x, track.position.y + 3.0), Vector2(1.0,
			track.size.y - 6.0)), UiTheme.PAPER_DEEP)
	# The grabber is drawn last and is the only part that says "this is a thing
	# you move", which a bare progress bar never does.
	var handle_x := clampf(roundf(track.position.x + filled) - 2.0,
		track.position.x, track.end.x - 4.0)
	var handle := Rect2(Vector2(handle_x, track.position.y - 2.0),
		Vector2(4.0, track.size.y + 4.0))
	draw_rect(handle, UiTheme.INK)
	draw_rect(handle.grow(-1.0), UiTheme.CREAM if has_focus() else UiTheme.AMBER)
	if has_focus():
		draw_rect(track.grow(1.0), UiTheme.FOCUS_INNER, false, 1.0)
		draw_rect(track.grow(2.0), UiTheme.FOCUS_OUTER, false, 1.0)
