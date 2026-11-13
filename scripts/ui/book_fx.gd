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
## focusable before the cover moves; the cover and the leaf are drawn by a
## `_Flap` on a `Node2D` holder — a container lays out its `Control` children
## and ignores everything else, so the holder rides the board without being
## arranged by it. A flap is drawn in perspective (the free edge grows as it
## lifts, and throws a shadow on the page), which is what separates a book
## from a panel that gets narrower. Shutting plays the cover back first.
## With motion off the book is simply open.

const EMBLEM := preload("res://assets/sprites/ui_book_emblem.png")
## Cut against `book_open.wav`: set down at 0.18 s, the creak from 0.22 s.
const SWING_AT := 0.22
const SWING_TIME := 0.34
const LEAF_TIME := 0.24
const SHUT_TIME := 0.16


static func open(board: Control, scrim: CanvasItem = null) -> void:
	AudioManager.play_sfx("book_open", 0.02, -2.0)
	_clear(board)
	UiTheme.pop_open(board, scrim, true, "")
	if not UserPreferences.can_animate():
		return
	var holder := _holder(board, &"book_cover")
	var cover := _Flap.new()
	cover.kind = &"cover"
	cover.size = board.size
	holder.add_child(cover)
	# A board laid out again while the cover is still over it must not outgrow
	# its own cover.
	var fit := func() -> void:
		if is_instance_valid(cover) and is_instance_valid(board):
			cover.size = board.size
			cover.queue_redraw()
	board.resized.connect(fit)
	holder.tree_exiting.connect(func() -> void:
		if is_instance_valid(board) and board.resized.is_connected(fit):
			board.resized.disconnect(fit))
	var tween := holder.create_tween()
	tween.tween_interval(SWING_AT)
	tween.tween_method(cover.turn, 0.0, 1.0, SWING_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The leaf under the cover lifts with it and falls a beat behind: a book
	# opened in a hurry always drags its first page.
	tween.tween_callback(func() -> void:
		cover.kind = &"leaf"
		cover.turn(0.0))
	tween.tween_method(cover.turn, 0.0, 1.0, LEAF_TIME * 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
	var leaf := _Flap.new()
	leaf.kind = &"leaf"
	leaf.size = page.size
	holder.add_child(leaf)
	var tween := holder.create_tween()
	tween.tween_method(leaf.turn, 0.0, 1.0, LEAF_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(holder.queue_free)


static func close(board: Control, scrim: CanvasItem, done: Callable) -> void:
	## Shut, then dropped. `done` follows `UiTheme.pop_close`'s contract: called
	## at once when there is nothing to animate.
	_clear(board)
	AudioManager.play_sfx("book_close", 0.02, -4.0)
	if not UserPreferences.can_animate() or not board.is_visible_in_tree() \
			or DisplayServer.get_name() == "headless":
		UiTheme.pop_close(board, scrim, done, "")
		return
	var holder := _holder(board, &"book_cover")
	var cover := _Flap.new()
	cover.kind = &"cover"
	cover.size = board.size
	cover.turn(1.0)
	holder.add_child(cover)
	var tween := holder.create_tween()
	tween.tween_method(cover.turn, 1.0, 0.0, SHUT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(board):
			return
		UiTheme.pop_close(board, scrim, func() -> void:
			_clear(board)
			done.call(), ""))


class _Flap extends Node2D:
	## A cover or a leaf hinged on the spine (its left edge) and seen from in
	## front, in perspective: as it lifts, the free edge comes toward the eye —
	## taller than the hinge — while the sheet narrows, and its shadow slides
	## off the page beneath. Drawn in two-pixel columns so the slanted edges
	## step like everything else on the screen instead of being a smooth line
	## over pixel art. No text on it, so nothing here ever squashes a glyph.
	const STEP := 2.0
	const LEATHER := Color8(102, 50, 30)
	const LEATHER_LIT := Color8(138, 72, 40)
	const LEATHER_EDGE := Color8(38, 18, 16)
	const GILT := Color8(206, 160, 104)
	const PAPER := Color8(238, 224, 198)
	const PAPER_SHADE := Color8(196, 178, 140)

	var kind: StringName = &"cover"
	var size := Vector2.ZERO
	var t := 0.0

	func turn(value: float) -> void:
		t = clampf(value, 0.0, 1.0)
		queue_redraw()

	static func _dim(c: Color, k: float) -> Color:
		return Color(c.r * k, c.g * k, c.b * k)

	func _draw() -> void:
		if size.x < 4.0 or t >= 1.0:
			return
		var angle := t * PI * 0.5
		var cover := kind == &"cover"
		var width := maxf(STEP, roundf(size.x * cos(angle) / STEP) * STEP)
		var lift := sin(angle) * (16.0 if cover else 9.0)
		# The shadow it throws on the page: longest when the sheet stands up.
		var reach := minf(size.x, width + sin(angle) * size.x * 0.35)
		draw_rect(Rect2(0.0, 0.0, reach, size.y),
			Color(0.08, 0.04, 0.03, 0.34 * (1.0 - t)))
		var face := LEATHER if cover else PAPER
		var dark := LEATHER_EDGE if cover else PAPER_SHADE
		var shade := lerpf(1.0, 0.62 if cover else 0.8, t)
		var x := 0.0
		while x < width:
			var u := x / width
			var grow := roundf(lift * u)
			var top := -grow
			var height := size.y + grow * 2.0
			# A leaf bows a little in the middle as it goes over.
			var tone := shade * (1.0 if cover else 1.0 - 0.1 * sin(u * PI) * sin(angle))
			draw_rect(Rect2(x, top, STEP, height),
				Color(face.r * tone, face.g * tone, face.b * tone))
			draw_rect(Rect2(x, top, STEP, STEP), dark)
			draw_rect(Rect2(x, top + height - STEP, STEP, STEP), dark)
			if cover:
				# The lit bevel and the gilt rule, in from each long edge.
				draw_rect(Rect2(x, top + STEP, STEP, STEP), _dim(LEATHER_LIT, shade))
				if u > 0.04 and u < 0.96:
					draw_rect(Rect2(x, top + 6.0 + grow * 0.2, STEP, STEP), _dim(GILT, shade))
					draw_rect(Rect2(x, top + height - 8.0 - grow * 0.2, STEP, STEP),
						_dim(GILT, shade))
			x += STEP
		# The free edge: the board's thickness, or the cut of the paper.
		var edge_grow := roundf(lift)
		draw_rect(Rect2(width - STEP, -edge_grow, STEP, size.y + edge_grow * 2.0), dark)
		if cover:
			draw_rect(Rect2(0.0, 0.0, STEP * 2.0, size.y), LEATHER_EDGE)
			var rule := roundf(width * 0.04)
			draw_rect(Rect2(rule + 6.0, 6.0, STEP, size.y - 12.0), _dim(GILT, shade))
			var mark := BookFx.EMBLEM.get_size() * (2.0 if minf(size.x, size.y) >= 200.0 else 1.0)
			var squeeze := maxf(0.0, cos(angle))
			var rect := Rect2(roundf((size.x - mark.x) * 0.5 * squeeze),
				roundf((size.y - mark.y) * 0.5), roundf(mark.x * squeeze), mark.y)
			if rect.size.x >= 4.0:
				draw_texture_rect(BookFx.EMBLEM, rect, false,
					Color(shade, shade, shade))


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
