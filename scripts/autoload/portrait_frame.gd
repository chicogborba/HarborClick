extends Node
## Keeps the game in portrait at any window size.
##
## HarborClick is designed one-handed, so a window wider than the design frame
## must not turn into a landscape game — it gets **pillarboxed**, the way a phone
## game does when it is cast to a wide screen. A window that is *taller* than the
## frame is the opposite case and gets the extra height: a modern phone is far
## narrower than 2:3, and letterboxing it would waste a third of the screen to
## honour a rule that only exists to stop the layout going wide.
##
## Godot's stretch aspect is one setting for both cases, so neither value alone
## does this: `expand` goes landscape on a desktop, `keep` puts bars on the top
## and bottom of every phone. The rule is really "clamp the aspect at portrait",
## which is the two modes switched at the crossover — and that is all this is.
##
## It lives in an autoload because the title screen and the terminal both need
## it, and because the crossover has to be re-evaluated on every resize, not once
## per scene.

## The widest the game is ever allowed to be, as width ÷ height. Above this the
## frame is held and the leftover width becomes bars.
const MAX_ASPECT := 320.0 / 480.0

var _pillarboxed := false
## -1 until the first evaluation, so the opening state is always written rather
## than assumed to match whatever the project settings shipped.
var _applied := -1


func _ready() -> void:
	# Runs before the first frame is drawn, so the game never appears at the
	# wrong aspect and then snaps.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var window := get_window()
	if window == null:
		return
	window.size_changed.connect(_apply)
	_apply()


func is_pillarboxed() -> bool:
	## Whether bars are currently showing. The title screen paints its backdrop
	## to the window rather than to the frame when they are.
	return _pillarboxed


func _apply() -> void:
	var window := get_window()
	if window == null:
		return
	var size := Vector2(window.size)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var too_wide := 1 if size.x / size.y > MAX_ASPECT else 0
	if too_wide == _applied:
		return
	_applied = too_wide
	_pillarboxed = too_wide == 1
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP \
		if _pillarboxed else Window.CONTENT_SCALE_ASPECT_EXPAND
