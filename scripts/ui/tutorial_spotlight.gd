class_name TutorialSpotlight
extends CanvasLayer
## Seven data-driven harbour orientation steps. Target callbacks can return a
## Rect2, allowing the real control to remain interactive beneath the overlay.

signal step_changed(index: int, step: Dictionary)
signal finished(skipped: bool)

const STEPS := [
	{"id":"navio", "title":"NAVIO ATRACADO", "text":"Toque no navio para mover carga.", "target":"ship"},
	{"id":"teu", "title":"CONTADOR TEU", "text":"Aqui chega a receita do cais.", "target":"teu"},
	{"id":"meta", "title":"META DO TURNO", "text":"Acompanhe a próxima operação.", "target":"objective"},
	{"id":"diario", "title":"DIÁRIO DO PORTO", "text":"Fixe uma meta para o próximo turno.", "target":"journal"},
	{"id":"loja", "title":"PRANCHETA", "text":"Contrate equipe e equipamento.", "target":"shop"},
	{"id":"capital", "title":"CAPITAL", "text":"Reconstrua o porto quando o botão de ações aparecer.", "target":"prestige"},
	{"id":"rotas", "title":"ROTAS DE CARGA", "text":"Novas rotas aparecerão no Diário conforme o porto cresce.", "target":"routes"},
]

var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _index := 0
var _active := false
var _veil: Control
var _panel: PanelContainer
var _title: Label
var _body: Label


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_callbacks = manager_or_callbacks.duplicate() if manager_or_callbacks is Dictionary else callbacks.duplicate()


func _ready() -> void:
	layer = 20
	_veil = _SpotlightVeil.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.dark_panel(8, UiTheme.TEAL))
	add_child(_panel)
	var col := VBoxContainer.new()
	_panel.add_child(col)
	_title = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.CREAM)
	col.add_child(_title)
	_body = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.PLATE_TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_body)
	var actions := HBoxContainer.new()
	col.add_child(actions)
	var skip := UiTheme.button("PULAR", "off", UiTheme.SIZE_SMALL)
	skip.pressed.connect(func() -> void: _finish(true))
	actions.add_child(skip)
	var next_button := UiTheme.button("PRÓXIMO", "amber", UiTheme.SIZE_SMALL)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(next)
	actions.add_child(next_button)
	visible = false


func start() -> void:
	_active = true
	_index = 0
	visible = true
	_show_step()


func replay() -> void: start()


func is_active() -> bool: return _active


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func next() -> void:
	if not _active: return
	_index += 1
	if _index >= STEPS.size(): _finish(false)
	else: _show_step()


func _unhandled_input(event: InputEvent) -> void:
	if not _active: return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		_finish(true)
	elif ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)) and not _target_rect().has_point(event.position):
		next()


func _show_step() -> void:
	var step: Dictionary = STEPS[_index]
	_title.text = str(step.title)
	_body.text = str(step.text)
	_veil.cutout = _target_rect().grow(5.0)
	_veil.reduced_motion = _reduced_motion()
	_veil.queue_redraw()
	_layout()
	step_changed.emit(_index, step.duplicate(true))


func _target_rect() -> Rect2:
	var callback: Callable = _callbacks.get("get_target_rect", Callable())
	if callback.is_valid():
		var result: Variant = callback.call(str(STEPS[_index].get("target", "")))
		if result is Rect2: return result
	return Rect2()


func _reduced_motion() -> bool:
	var callback: Callable = _callbacks.get("reduced_motion", Callable())
	return bool(callback.call()) if callback.is_valid() else false


func _layout() -> void:
	if _panel == null or not is_instance_valid(_panel): return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_panel.size = Vector2(minf(340.0, safe.size.x - 16.0), 96.0)
	_panel.position = Vector2(safe.get_center().x - _panel.size.x * 0.5, safe.end.y - _panel.size.y - 10.0)


func _finish(skipped: bool) -> void:
	_active = false
	visible = false
	finished.emit(skipped)


class _SpotlightVeil extends Control:
	var cutout := Rect2()
	var reduced_motion := false
	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		var shade := Color(0.02, 0.02, 0.06, 0.72)
		if cutout.size == Vector2.ZERO:
			draw_rect(full, shade)
			return
		draw_rect(Rect2(full.position, Vector2(full.size.x, cutout.position.y)), shade)
		draw_rect(Rect2(Vector2(0, cutout.end.y), Vector2(full.size.x, maxf(0, full.end.y - cutout.end.y))), shade)
		draw_rect(Rect2(Vector2(0, cutout.position.y), Vector2(cutout.position.x, cutout.size.y)), shade)
		draw_rect(Rect2(Vector2(cutout.end.x, cutout.position.y), Vector2(maxf(0, full.end.x - cutout.end.x), cutout.size.y)), shade)
		draw_rect(cutout, UiTheme.TEAL, false, 2.0)
