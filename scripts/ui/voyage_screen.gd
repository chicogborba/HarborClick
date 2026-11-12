extends Control
## The crossing between two ports.
##
## It exists for a mechanical reason and earns its keep as a moment. The
## mechanical reason: a port is a save file, and a save must never be applied
## while the last port's world is still alive — its sections would be restored
## with somebody else's cargo on their way out. This scene is the gap: by the
## time `_ready` runs the old world is gone and the new one does not exist yet,
## so `SaveManager.use_port` is exactly the profile switch the title performs.
##
## The moment: a card that says where you are going, a hull steaming across it,
## the horn. `PortDB.destination` is the only input.

const FLAGS := preload("res://assets/sprites/ui_flags.png")
const FLAG_SIZE := Vector2(16, 11)
const SHIP := preload("res://assets/sprites/ship_cute.png")
const HOLD := 1.7

var _ship: TextureRect
var _t := 0.0
var _leaving := false


func _ready() -> void:
	UiTheme.install_window_theme(get_window())
	get_tree().paused = false
	var port := PortDB.get_port(PortDB.destination)
	var ok := not port.is_empty() and SaveManager.use_port(PortDB.destination)
	if not ok:
		# Nowhere valid to go: back to wherever the profile already was.
		port = PortDB.current()
	PortDB.destination = &""

	var sea := ColorRect.new()
	sea.color = UiTheme.HULL_DEEP
	sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sea)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := UiTheme.panel(UiTheme.gantry_style())
	card.custom_minimum_size = Vector2(240, 0)
	centre.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)

	var flag := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = FLAGS
	atlas.region = Rect2(Vector2(int(port.get("flag", 0)) * FLAG_SIZE.x, 0), FLAG_SIZE)
	flag.texture = atlas
	flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flag.custom_minimum_size = FLAG_SIZE * 3.0
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(flag)

	var bound := UiTheme.label(Loc.t("ports.voyage.bound"), UiTheme.SIZE_SMALL,
		UiTheme.STEEL_DIM)
	bound.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(bound)
	var where := UiTheme.label(str(port.get("name", "")).to_upper(),
		UiTheme.SIZE_TITLE, UiTheme.AMBER)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(where)
	var country := UiTheme.label(str(port.get("country", "")).to_upper(),
		UiTheme.SIZE_SMALL, UiTheme.STEEL_TEXT)
	country.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(country)
	var tagline := UiTheme.label(str(port.get("tagline", "")), UiTheme.SIZE_SMALL,
		UiTheme.STEEL_DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size.x = 220.0
	column.add_child(tagline)

	_ship = TextureRect.new()
	_ship.texture = SHIP
	_ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship.scale = Vector2(2, 2)
	add_child(_ship)
	_place_ship(0.0)
	AudioManager.play_sfx("horn", 0.03, -5.0)


func _place_ship(progress: float) -> void:
	var view := get_viewport_rect().size
	var width := SHIP.get_width() * 2.0
	_ship.position = Vector2(
		roundf(lerpf(-width, view.x, progress)),
		roundf(view.y * 0.72))


func _process(delta: float) -> void:
	_t += delta
	var hold := HOLD if UserPreferences.can_animate() else 0.4
	_place_ship(clampf(_t / hold, 0.0, 1.0))
	if _t >= hold and not _leaving:
		_leaving = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# A tap is "yes, yes, take me there".
	if _t > 0.25 and ((event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)):
		_t = HOLD
