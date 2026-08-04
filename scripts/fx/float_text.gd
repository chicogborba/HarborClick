class_name FloatText
extends Node2D
## Floating "+N" feedback text.
##
## This is the game's only answer to "did my tap pay?", and the first version
## whispered it: ten-pixel near-white text with a hairline outline, over a port
## full of coloured containers. It was there and nobody saw it. It is now a
## stamped amber number that punches in, rises and fades — and a crit is twice
## the size in gold, because a crit is the thing worth looking up for.

var _label: Label
var _life := 0.0
var _duration := 1.05
var _rise := 34.0
var _crit := false
var _punch := true


func setup(text: String, world_pos: Vector2, crit: bool) -> void:
	_crit = crit
	position = world_pos + Vector2(randf_range(-6, 6), 0)
	_label = Label.new()
	_label.text = text + ("!" if crit else "")
	# A thick dark outline is what makes small bright type survive over pixel art
	# of any colour; without it the number disappears into the cargo under it.
	_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_HUGE if crit else UiTheme.SIZE_TITLE,
		UiTheme.AMBER if crit else Color8(255, 236, 190), 3)
	_label.position = Vector2(-20, -14)
	_label.pivot_offset = Vector2(20, 14)
	add_child(_label)
	_punch = UserPreferences.can_animate()
	if crit:
		_duration = 1.45
		_rise = 52.0
	if not _punch:
		_label.scale = Vector2.ONE


func _process(delta: float) -> void:
	_life += delta
	var t := _life / _duration
	if t >= 1.0:
		queue_free()
		return
	var ease_out := 1.0 - (1.0 - t) * (1.0 - t)
	position.y -= _rise * delta * (1.0 - ease_out * 0.7)
	modulate.a = 1.0 - maxf(0.0, (t - 0.55) / 0.45)
	if not _punch:
		return
	# Punch in over the first fifth, then settle: the number arrives rather than
	# fading up out of nothing.
	var grow := clampf(_life / 0.16, 0.0, 1.0)
	var punch := 0.45 + 0.70 * grow if grow < 1.0 else 1.15 - 0.15 * \
		clampf((_life - 0.16) / 0.12, 0.0, 1.0)
	if _crit:
		punch *= 1.0 + sin(t * PI) * 0.18
	_label.scale = Vector2.ONE * punch
