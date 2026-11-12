class_name PortIcon
extends Control
## The picture on a shop card is the machine itself, taken straight from the
## yard sprite — buying a reach stacker should show you the reach stacker that
## will drive in through the gate.
##
## Several yard sprites are spritesheets (`worker_sheet` is twelve 9x12 walk
## frames, `veh_drone` two, `bld_portal` three). Handing the whole strip to a
## TextureRect squashed every frame into an unreadable smear, which is why each
## entry declares its own frame rectangle. Tall vehicles are quarter-turned so
## they fill a landscape socket instead of becoming a sliver.

## sprite, optional frame Rect2, `turn` = draw rotated a quarter turn.
const ART := {
	"estivador": {"sprite": "worker_sheet", "frame": Rect2(0, 0, 9, 12)},
	"empilhadeira": {"sprite": "veh_forklift", "turn": true},
	"tt": {"sprite": "veh_tt", "turn": true},
	"reach_stacker": {"sprite": "veh_reach_stacker", "turn": true},
	"rtg": {"sprite": "rtg"},
	"sts": {"sprite": "sts_base"},
	"armazem": {"sprite": "bld_warehouse"},
	"rebocador": {"sprite": "veh_tug", "turn": true},
	"trem": {"sprite": "veh_loco"},
	"flutuante": {"sprite": "flutuante"},
	"alfandega": {"sprite": "bld_customs"},
	"torre": {"sprite": "bld_tower"},
	"drone": {"sprite": "veh_drone", "frame": Rect2(0, 0, 18, 18)},
	"porto_ia": {"sprite": "bld_ai_hub"},
	"portal": {"sprite": "bld_portal", "frame": Rect2(0, 0, 34, 34)},
	"_land": {"sprite": "gr_dirt_0"},
	"_ship": {"sprite": "ship_cute"},
}

var _sprite: Sprite2D
var _badge: Sprite2D
var _art: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	resized.connect(_fit)


func show_item(key: String) -> void:
	_art = ART.get(key, {})
	if _art.is_empty():
		_sprite.texture = null
		return
	var path := "res://assets/sprites/%s.png" % _art.sprite
	if not ResourceLoader.exists(path):
		_sprite.texture = null
		return
	# The shop shows the machine as this port paints it.
	var base: Texture2D = PortDB.tex(str(_art.sprite))
	if _art.has("frame"):
		var at := AtlasTexture.new()
		at.atlas = base
		at.region = _art.frame
		_sprite.texture = at
	else:
		_sprite.texture = base
	_sprite.rotation = -PI / 2.0 if bool(_art.get("turn", false)) else 0.0
	_fit()


func set_badge(kind: Variant) -> void:
	## A small corner glyph, used to mark an upgrade of an existing machine.
	if kind == null:
		if _badge != null:
			_badge.queue_free()
			_badge = null
		return
	if _badge == null:
		_badge = Sprite2D.new()
		_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_badge.centered = false
		add_child(_badge)
	_badge.texture = UiTheme.icon_texture(kind)
	_fit()


func _fit() -> void:
	if _sprite.texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var art_size := _sprite.texture.get_size()
	if bool(_art.get("turn", false)):
		art_size = Vector2(art_size.y, art_size.x)
	var room := size - Vector2(2, 2)
	var fit := minf(room.x / art_size.x, room.y / art_size.y)
	# Pixel art only stays crisp on whole-number blow-ups; a shrink has to be
	# fractional, so it is at least kept to the exact ratio that fits.
	_sprite.scale = Vector2.ONE * (floorf(fit) if fit >= 1.0 else fit)
	_sprite.position = size * 0.5
	if _badge != null:
		_badge.position = Vector2(size.x - 12.0, size.y - 12.0)
