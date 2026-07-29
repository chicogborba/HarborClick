class_name FloatText
extends Node2D
## Floating "+N" feedback text. Crits are bigger, golden and rise higher.

var _label: Label
var _life := 0.0
var _duration := 0.9
var _rise := 26.0
var _crit := false


func setup(text: String, world_pos: Vector2, crit: bool) -> void:
	_crit = crit
	position = world_pos + Vector2(randf_range(-6, 6), 0)
	_label = Label.new()
	_label.text = text + ("!" if crit else "")
	_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_TITLE if crit else UiTheme.SIZE_BODY,
		UiTheme.AMBER if crit else Color8(246, 240, 228), 2)
	_label.position = Vector2(-14, -8)
	add_child(_label)
	if crit:
		_duration = 1.3
		_rise = 40.0


func _process(delta: float) -> void:
	_life += delta
	var t := _life / _duration
	if t >= 1.0:
		queue_free()
		return
	var ease_out := 1.0 - (1.0 - t) * (1.0 - t)
	position.y -= _rise * delta * (1.0 - ease_out * 0.7)
	modulate.a = 1.0 - maxf(0.0, (t - 0.55) / 0.45)
	if _crit:
		_label.scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.2)
