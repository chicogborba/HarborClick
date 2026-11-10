class_name SkillBar
extends CanvasLayer
## The Capataz's skills as three keys above the console.
##
## Each key is the skill's icon, a dark curtain that drains as it recharges with
## the seconds left on it, and — while it is recharging — a small film-frame
## badge when a rewarded ad can skip the wait. A skill the terminal has not
## earned yet has no key. Built once, rewritten in place, ten times a second.

const KEY := 44.0
const GAP := 6.0
const ICONS := {
	&"skill_overtime": UiTheme.Icon16.SKILL_OVERTIME,
	&"skill_mutirao": UiTheme.Icon16.SKILL_MUTIRAO,
	&"skill_pilot": UiTheme.Icon16.SKILL_PILOT,
}

var _service: SkillService
var _row: HBoxContainer
var _keys: Dictionary = {}     # id -> {button, curtain, label, badge}
var _safe_rect := Rect2()
var _tick := 0.0


func _ready() -> void:
	layer = 6
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", int(GAP))
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	for skill in SkillBook.SKILLS:
		_build_key(StringName(skill.id))
	refresh()
	_layout()


func _build_key(id: StringName) -> void:
	var button := UiTheme.button("", &"steel", UiTheme.SIZE_SMALL)
	button.custom_minimum_size = Vector2(KEY, KEY)
	button.clip_contents = true
	UiTheme.describe(button, Loc.t("skill.%s" % String(id)),
		Loc.t("skill.%s.desc" % String(id)))
	button.pressed.connect(_on_pressed.bind(id))
	_row.add_child(button)
	var icon := UiTheme.icon16(ICONS[id], 2)
	icon.position = Vector2((KEY - 32.0) * 0.5, (KEY - 32.0) * 0.5)
	icon.size = Vector2(32.0, 32.0)
	button.add_child(icon)
	var curtain := ColorRect.new()
	curtain.color = Color(0.04, 0.05, 0.1, 0.72)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.size = Vector2(KEY, 0.0)
	button.add_child(curtain)
	var label := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.CREAM)
	label.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL, UiTheme.CREAM, 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(KEY, 12.0)
	label.position = Vector2(0.0, (KEY - 12.0) * 0.5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	var badge := UiTheme.icon16(UiTheme.Icon16.AD)
	badge.position = Vector2(KEY - 17.0, 1.0)
	badge.visible = false
	button.add_child(badge)
	_keys[id] = {"button": button, "curtain": curtain, "label": label, "badge": badge}


func setup(service: SkillService) -> void:
	_service = service
	if _service != null and not _service.state_changed.is_connected(refresh):
		_service.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _service == null or _service.book == null or _keys.is_empty():
		return
	var now := _service.now()
	var shown := 0
	for id: StringName in _keys:
		var key: Dictionary = _keys[id]
		var button: Button = key.button
		var open := _service.unlocked(id)
		button.visible = open
		if not open:
			continue
		shown += 1
		var left := _service.book.seconds_left(id, now)
		var frac := _service.book.fraction_left(id, now)
		(key.curtain as ColorRect).size.y = roundf(KEY * frac)
		(key.curtain as ColorRect).visible = frac > 0.0
		var label: Label = key.label
		label.text = _clock(left) if left > 0.0 else ""
		(key.badge as Control).visible = left > 0.0 and AdService.available(&"skill_reset")
	_row.visible = shown > 0
	_layout()


static func _clock(seconds: float) -> String:
	var s := ceili(seconds)
	return "%ds" % s if s < 60 else "%d:%02d" % [s / 60, s % 60]


func _on_pressed(id: StringName) -> void:
	if _service == null:
		return
	if _service.activate(id):
		return
	if _service.book.is_ready(id, _service.now()) or not _service.unlocked(id):
		return
	# Recharging: a rewarded ad skips the wait, when one is allowed.
	if AdService.available(&"skill_reset"):
		AdService.show_rewarded(&"skill_reset", func() -> void: _service.reset_cooldown(id))
	else:
		AudioManager.play_sfx("deny", 0.02, -4.0)


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.1:
		_tick = 0.0
		refresh()


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _layout() -> void:
	if _row == null or not is_instance_valid(_row):
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	_row.reset_size()
	# Centred, just above the console and the objective line that sits on it.
	_row.position = Vector2(
		safe.position.x + (safe.size.x - _row.size.x) * 0.5,
		safe.end.y - CommandRail.BAR_H - 6.0 - 8.0 - KEY).round()
