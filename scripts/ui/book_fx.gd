class_name BookFx
extends RefCounted
## How the logbook opens, turns a page and shuts.
##
## The two diaries (`PortJournal`, `NoticeBell`) are bound in leather
## (`UiTheme.book_style`), and a book that slid up like a clipboard would be a
## clipboard painted brown. So: the book comes up *shut*, lands, and its cover
## swings over on the spine to show the page that was laid out underneath the
## whole time. Changing tab turns a leaf the same way.
##
## Nothing here owns state the game reads. The page is built, laid out and
## focusable before the cover moves; the cover and the leaf are textures on a
## `Node2D` holder — a container lays out its `Control` children and ignores
## everything else, so the holder rides the board without being arranged by
## it. They carry no text, because the one thing this does scale is `scale.x`,
## and a squashed pixel font is the thing `pop_open` exists to avoid.
## With motion off the book is simply open.

const COVER := preload("res://assets/sprites/ui_book_cover.png")
const EMBLEM := preload("res://assets/sprites/ui_book_emblem.png")
const LEAF := preload("res://assets/sprites/ui_book_leaf.png")
## Cut against `book_open.wav`: set down at 0.18 s, the creak from 0.22 s.
const SWING_AT := 0.22
const SWING_TIME := 0.24
const LEAF_TIME := 0.20


static func open(board: Control, scrim: CanvasItem = null) -> void:
	AudioManager.play_sfx("book_open", 0.02, -2.0)
	_clear(board)
	UiTheme.pop_open(board, scrim, true, "")
	if not UserPreferences.can_animate():
		return
	var holder := _holder(board, &"book_cover")
	var cover := _sheet(COVER, 14, board.size)
	holder.add_child(cover)
	var mark := TextureRect.new()
	mark.texture = EMBLEM
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Integer scale only: 2x on anything wider than a small phone's board.
	var mark_scale := 2.0 if minf(board.size.x, board.size.y) >= 200.0 else 1.0
	mark.scale = Vector2.ONE * mark_scale
	mark.position = ((board.size - EMBLEM.get_size() * mark_scale) * 0.5).round()
	cover.add_child(mark)
	# A board that fits itself to its content a frame after opening (the
	# gantry diary does) must not outgrow its own cover.
	var fit := func() -> void:
		if is_instance_valid(cover) and is_instance_valid(board):
			cover.size = board.size
			mark.position = ((board.size - EMBLEM.get_size() * mark_scale) \
				* 0.5).round()
	board.resized.connect(fit)
	holder.tree_exiting.connect(func() -> void:
		if is_instance_valid(board) and board.resized.is_connected(fit):
			board.resized.disconnect(fit))
	var tween := holder.create_tween()
	tween.tween_interval(SWING_AT)
	tween.tween_method(_swing.bind(cover), 0.0, 1.0, SWING_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(holder.queue_free)


static func flip(page: Control) -> void:
	## One leaf across `page` (the scrolling sheet), uncovering whatever the
	## tab change just put there.
	AudioManager.play_sfx("page_flip", 0.05, -4.0)
	_clear(page)
	if not UserPreferences.can_animate() or not page.is_visible_in_tree() \
			or page.size.x < 8.0:
		return
	var holder := _holder(page, &"book_leaf")
	var leaf := _sheet(LEAF, 5, page.size)
	holder.add_child(leaf)
	var tween := holder.create_tween()
	tween.tween_method(_swing.bind(leaf), 0.0, 1.0, LEAF_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(holder.queue_free)


static func close(board: Control, scrim: CanvasItem, done: Callable) -> void:
	## Shut and dropped. `done` follows `UiTheme.pop_close`'s contract: called
	## at once when there is nothing to animate.
	_clear(board)
	AudioManager.play_sfx("book_close", 0.02, -4.0)
	UiTheme.pop_close(board, scrim, done, "")


static func _swing(t: float, sheet: Control) -> void:
	## A sheet hinged on its left edge, seen from in front: it narrows to
	## nothing, and darkens as it turns away from the light.
	if not is_instance_valid(sheet):
		return
	sheet.scale.x = maxf(0.0, 1.0 - t)
	var shade := lerpf(1.0, 0.55, t)
	sheet.modulate = Color(shade, shade, shade, 1.0)


static func _sheet(texture: Texture2D, margin: int, size: Vector2) -> NinePatchRect:
	var sheet := NinePatchRect.new()
	sheet.texture = texture
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.patch_margin_left = margin
	sheet.patch_margin_top = margin
	sheet.patch_margin_right = margin
	sheet.patch_margin_bottom = margin
	sheet.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	sheet.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	sheet.size = size
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sheet


static func _holder(owner: Control, key: StringName) -> Node2D:
	var holder := Node2D.new()
	holder.name = String(key)
	holder.z_index = 1
	owner.add_child(holder)
	owner.set_meta(&"book_fx", holder)
	# Gone means gone: nothing is left pointing at a freed node.
	holder.tree_exited.connect(func() -> void:
		if is_instance_valid(owner) and owner.has_meta(&"book_fx") \
				and owner.get_meta(&"book_fx") == holder:
			owner.remove_meta(&"book_fx"))
	return holder


static func _clear(owner: Control) -> void:
	if not owner.has_meta(&"book_fx"):
		return
	# Untyped on purpose: the holder frees itself when its sheet has turned,
	# and casting a freed object is an error where testing one is not.
	var old: Variant = owner.get_meta(&"book_fx")
	if is_instance_valid(old):
		(old as Node).queue_free()
	owner.remove_meta(&"book_fx")
