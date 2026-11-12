class_name ClickOutline
extends Node2D
## A soft white border round anything in the yard the player can tap.
##
## A tappable thing that looks like scenery is a feature nobody finds. Every
## clickable object — the hulls, the parked lorries, the Receita's post, the
## people on foot, the cat, the golden gull — carries one of these, so "can I
## touch that?" is answered by looking. It breathes slowly rather than sitting
## still, because a still outline is just a thicker line in the drawing.
##
## Mechanics. Eight solid silhouettes one pixel out in each direction, behind
## the source, the same trick `Ship` uses: a neighbour-sampling shader cannot
## draw outside a tightly cropped atlas region, eight copies can. The copies
## mirror the source every frame (texture, atlas region, animation frame, flip,
## offset, transform), so an animated walker is outlined frame by frame.
## Add it as a sibling *before* the source so it draws underneath.

const SHADER := preload("res://assets/shaders/interaction_outline.gdshader")
const SOFT := Color(1.0, 1.0, 1.0, 0.55)
const LIT := Color(1.0, 1.0, 1.0, 0.95)
const DIRECTIONS := [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
	Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]

## Shown at all only while true: an empty berth or a lorry nobody can work is
## not tappable, and an outline that lies is worse than none.
var active := true
var hovered := false
var source: CanvasItem

var _copies: Array[Sprite2D] = []
var _materials: Array[ShaderMaterial] = []
var _t := 0.0
var _last_color := Color(0, 0, 0, 0)


static func attach(target: CanvasItem) -> ClickOutline:
	## Builds an outline for `target` and parks it right behind it.
	var outline := ClickOutline.new()
	outline.source = target
	outline.name = "%sOutline" % target.name
	var parent := target.get_parent()
	if parent != null:
		parent.add_child(outline)
		parent.move_child(outline, target.get_index())
	return outline


func _ready() -> void:
	_t = randf() * TAU
	for direction: Vector2 in DIRECTIONS:
		var copy := Sprite2D.new()
		copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var material := ShaderMaterial.new()
		material.shader = SHADER
		copy.material = material
		copy.set_meta("dir", direction)
		add_child(copy)
		_copies.append(copy)
		_materials.append(material)
	_sync()


func _process(delta: float) -> void:
	_t += delta
	_sync()


func _sync() -> void:
	if source == null or not is_instance_valid(source):
		visible = false
		return
	visible = active and source.visible and source.is_visible_in_tree()
	if not visible:
		return
	var texture: Texture2D = null
	var centered := true
	var offset := Vector2.ZERO
	var flip_h := false
	var region := Rect2()
	var use_region := false
	if source is AnimatedSprite2D:
		var anim := source as AnimatedSprite2D
		if anim.sprite_frames != null:
			texture = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		centered = anim.centered
		offset = anim.offset
		flip_h = anim.flip_h
	elif source is Sprite2D:
		var sprite := source as Sprite2D
		texture = sprite.texture
		centered = sprite.centered
		offset = sprite.offset
		flip_h = sprite.flip_h
		use_region = sprite.region_enabled
		region = sprite.region_rect
	var node := source as Node2D
	position = node.position
	rotation = node.rotation
	scale = node.scale
	z_index = node.z_index
	var breathe := 0.5 + 0.5 * sin(_t * 2.6) if UserPreferences.can_animate() else 0.6
	var color := LIT if hovered else Color(SOFT.r, SOFT.g, SOFT.b,
		lerpf(0.35, 0.75, breathe))
	var width := 1.0
	for copy in _copies:
		copy.texture = texture
		copy.centered = centered
		copy.offset = offset
		copy.flip_h = flip_h
		copy.region_enabled = use_region
		copy.region_rect = region
		copy.position = (copy.get_meta("dir") as Vector2) * width
	if not color.is_equal_approx(_last_color):
		_last_color = color
		for material in _materials:
			material.set_shader_parameter("outline_color", color)
