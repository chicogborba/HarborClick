extends Control
## The crossing between two ports, on the globe.
##
## It exists for a mechanical reason and earns its keep as a moment. The
## mechanical reason: a port is a save file, and a save must never be applied
## while the last port's world is still alive — its sections would be restored
## with somebody else's cargo on their way out. This scene is the gap: by the
## time `_ready` runs the old world is gone and the new one does not exist yet,
## so `SaveManager.use_port` is exactly the profile switch the title performs.
##
## The moment: the planet turns from where you were to where you are going,
## a little hull runs the great circle between them, and the destination's
## name and flag sit above it. A tap skips. `PortDB.destination` is the input.

const FLAGS := preload("res://assets/sprites/ui_flags.png")
const FLAG_SIZE := Vector2(16, 11)
const HOLD := 2.8

var _globe: Globe
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _leaving := false


func _ready() -> void:
	UiTheme.install_window_theme(get_window())
	get_tree().paused = false
	var origin := PortDB.get_port(PortDB.active)
	var port := PortDB.get_port(PortDB.destination)
	var ok := not port.is_empty() and SaveManager.use_port(PortDB.destination)
	if not ok:
		# Nowhere valid to go: back to wherever the profile already was.
		port = PortDB.current()
	PortDB.destination = &""
	_from = Globe.lonlat(origin if not origin.is_empty() else port)
	_to = Globe.lonlat(port)

	var space := ColorRect.new()
	space.color = UiTheme.HULL_EDGE
	space.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(space)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 8)
	add_child(column)

	var card := UiTheme.panel(UiTheme.gantry_style())
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	card.add_child(row)
	var flag := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = FLAGS
	atlas.region = Rect2(Vector2(int(port.get("flag", 0)) * FLAG_SIZE.x, 0), FLAG_SIZE)
	flag.texture = atlas
	flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flag.custom_minimum_size = FLAG_SIZE * 2.0
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", 1)
	row.add_child(words)
	words.add_child(UiTheme.label(Loc.t("ports.voyage.bound"), UiTheme.SIZE_SMALL,
		UiTheme.STEEL_DIM))
	words.add_child(UiTheme.label(str(port.get("name", "")).to_upper(),
		UiTheme.SIZE_TITLE, UiTheme.AMBER))
	words.add_child(UiTheme.label(str(port.get("country", "")).to_upper(),
		UiTheme.SIZE_SMALL, UiTheme.STEEL_TEXT))

	_globe = Globe.new()
	_globe.spin_when_idle = false
	_globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_globe.custom_minimum_size = Vector2(Globe.PIXELS * 2, Globe.PIXELS * 2)
	_globe.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_globe.arc_from = _from
	_globe.arc_to = _to
	_globe.arc_t = 0.0
	_globe.selected = StringName(port.get("id", &""))
	column.add_child(_globe)
	_globe.look_at_lonlat(_from, 0.0)

	var tagline := UiTheme.label(str(port.get("tagline", "")), UiTheme.SIZE_SMALL,
		UiTheme.STEEL_DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	AudioManager.play_sfx("horn", 0.03, -5.0)


func _process(delta: float) -> void:
	_t += delta
	var hold := HOLD if UserPreferences.can_animate() else 0.4
	var k := clampf(_t / hold, 0.0, 1.0)
	var eased := k * k * (3.0 - 2.0 * k)
	_globe.arc_t = eased
	# The camera rides with the hull along the great circle.
	var a := Globe._unit(_from)
	var b := Globe._unit(_to)
	var p := Globe._slerp(a, b, a.angle_to(b), eased)
	_globe.look_at_lonlat(Vector2(rad_to_deg(atan2(p.x, p.z)),
		rad_to_deg(asin(clampf(p.y, -1.0, 1.0)))), 0.0)
	if _t >= hold + 0.5 and not _leaving:
		_leaving = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# A tap is "yes, yes, take me there".
	if _t > 0.25 and ((event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)):
		_t = HOLD
