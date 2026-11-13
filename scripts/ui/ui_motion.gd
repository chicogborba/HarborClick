class_name UiMotion
## How the interface moves, in one place.
##
## `UiTheme` says what a thing is made of; this says how it behaves when it is
## touched or brought on screen. Everything here is presentation only and obeys
## two rules the rest of the UI already lives by:
##
## * **Nothing waits on it.** State changes first; the motion is a tween bound
##   to the node, so freeing the node ends it, and "movimento reduzido" (or no
##   display) turns every function here into a no-op that leaves the control
##   exactly where the layout put it.
## * **The layout always wins.** A control inside a container has its position
##   written by that container. A slide therefore remembers where *it* last put
##   the control; if the control is anywhere else, something laid it out again
##   and that becomes the new resting place. Same idea as `UiTheme.pop_open`.
##
## The vocabulary:
##
## * `wire_press`   — a key sinks under the finger and springs back.
## * `cascade`      — rows arrive one after another instead of all at once.
## * `power_on`     — a scanline runs down a board as it lands.
## * `dress_scrim`  — the port behind a board goes out of focus (pixel mosaic).
## * `sheen`        — the gloss that sweeps every amber key together.
## * `punch`        — a number that just changed jumps.
## * `flash`        — a surface lights for a beat.

const SCRIM_SHADER := preload("res://assets/shaders/ui_scrim.gdshader")
const SHEEN_SHADER := preload("res://assets/shaders/ui_sheen.gdshader")
const POWER_SHADER := preload("res://assets/shaders/ui_power.gdshader")

const PRESS_SCALE := 0.94
const STEP := 0.028
const RISE := 10.0

static var _sheen: ShaderMaterial


static func live() -> bool:
	return UserPreferences.can_animate() and DisplayServer.get_name() != "headless"


static func _px(node: CanvasItem) -> float:
	## Physical pixels per logical one, so stepped effects keep the game's own
	## pixel size on a phone and on a desktop.
	if node == null or not node.is_inside_tree():
		return 2.0
	return maxf(1.0, roundf(node.get_viewport().get_stretch_transform().get_scale().x))


# ------------------------------------------------------------------- press

static func wire_press(node: BaseButton) -> void:
	## Idempotent: boards restyle their keys in place many times a second.
	if node.has_meta(&"ui_press"):
		return
	node.set_meta(&"ui_press", true)
	node.button_down.connect(_press_down.bind(node))
	node.button_up.connect(_press_up.bind(node))


static func _press_down(node: BaseButton) -> void:
	if not live() or not is_instance_valid(node):
		return
	node.pivot_offset = (node.size * 0.5).round()
	var tween := _fresh(node, &"ui_press_tween")
	tween.tween_property(node, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _press_up(node: BaseButton) -> void:
	if not is_instance_valid(node):
		return
	if not live():
		node.scale = Vector2.ONE
		return
	node.pivot_offset = (node.size * 0.5).round()
	var tween := _fresh(node, &"ui_press_tween")
	tween.tween_property(node, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func punch(node: Control, amount: float = 1.16, time: float = 0.26) -> void:
	## A value that just changed jumps and settles.
	if not live() or not is_instance_valid(node) or not node.is_visible_in_tree():
		return
	node.pivot_offset = (node.size * 0.5).round()
	var tween := _fresh(node, &"ui_press_tween")
	tween.tween_property(node, "scale", Vector2.ONE, time) \
		.from(Vector2(amount, amount)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _fresh(node: Node, key: StringName) -> Tween:
	if node.has_meta(key):
		var previous := node.get_meta(key) as Tween
		if previous != null and previous.is_valid():
			previous.kill()
	var tween := node.create_tween()
	node.set_meta(key, tween)
	return tween


# ----------------------------------------------------------------- cascade

static func cascade(items: Array, start: float = 0.05, step: float = STEP,
		rise: float = RISE) -> void:
	## Rows arrive in order, each a beat after the one above it.
	var index := 0
	for item: Variant in items:
		var control := item as Control
		if control == null or not is_instance_valid(control):
			continue
		slide_in(control, Vector2(0.0, rise), start + index * step)
		index += 1


static func slide_in(node: Control, from: Vector2, delay: float = 0.0,
		time: float = 0.26) -> void:
	settle(node)
	if not live() or not node.is_visible_in_tree():
		return
	var state := {"final": node.position, "last": node.position + from,
		"alpha": node.modulate.a, "alpha_last": 0.0, "own_alpha": true}
	node.position = state.last
	node.modulate.a = 0.0
	node.set_meta(&"ui_slide", state)
	var tween := node.create_tween()
	node.set_meta(&"ui_slide_tween", tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(node):
			return
		if node.position != state.last:
			state.final = node.position
		# Back-out: a few pixels past the mark, then home.
		var u := t - 1.0
		var eased := 1.0 + 2.2 * u * u * u + 1.2 * u * u
		state.last = state.final + (from * (1.0 - eased)).round()
		node.position = state.last
		if state.own_alpha:
			if is_equal_approx(node.modulate.a, state.alpha_last):
				state.alpha_last = float(state.alpha) * clampf(t * 2.4, 0.0, 1.0)
				node.modulate.a = state.alpha_last
			else:
				# Somebody else set it since: it is theirs now.
				state.own_alpha = false, 0.0, 1.0, time)
	tween.tween_callback(settle.bind(node))


static func settle(node: Control) -> void:
	## Lands a slide right now. Safe to call on a node that never slid.
	if not is_instance_valid(node):
		return
	if node.has_meta(&"ui_slide_tween"):
		var tween := node.get_meta(&"ui_slide_tween") as Tween
		if tween != null and tween.is_valid():
			tween.kill()
		node.remove_meta(&"ui_slide_tween")
	if node.has_meta(&"ui_slide"):
		var state: Dictionary = node.get_meta(&"ui_slide")
		if node.position == state.last:
			node.position = state.final
		if state.own_alpha and is_equal_approx(node.modulate.a, state.alpha_last):
			node.modulate.a = float(state.alpha)
		node.remove_meta(&"ui_slide")


static func board_items(board: Control, limit: int = 12) -> Array[Control]:
	## What a board is made of, top to bottom, as the pieces a player would
	## name: the nameplate, the tab row, then the rows of whatever list is
	## showing — not the scroll box that holds them.
	var out: Array[Control] = []
	var column := _first_box(board, 2)
	if column == null:
		return out
	for child in column.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var scroll := _find_scroll(control, 3)
		if scroll == null:
			out.append(control)
			continue
		var rows := _scroll_rows(scroll)
		if rows.is_empty():
			out.append(control)
			continue
		var window := Rect2(Vector2.ZERO, scroll.size).grow(8.0)
		var origin := scroll.global_position
		for row in rows:
			if out.size() >= limit:
				break
			if window.intersects(Rect2(row.global_position - origin, row.size)):
				out.append(row)
	return out


static func scroll_items(page: Control, limit: int = 10) -> Array[Control]:
	## The rows of a list that are actually in view — what a tab change brings
	## in. `page` is the scroll box or anything that holds one.
	var out: Array[Control] = []
	if page == null or not page.is_visible_in_tree():
		return out
	var scroll := _find_scroll(page, 3)
	if scroll == null:
		return out
	var window := Rect2(Vector2.ZERO, scroll.size).grow(8.0)
	var origin := scroll.global_position
	for row in _scroll_rows(scroll):
		if out.size() >= limit:
			break
		if window.intersects(Rect2(row.global_position - origin, row.size)):
			out.append(row)
	return out


static func _first_box(node: Node, depth: int) -> BoxContainer:
	for child in node.get_children():
		if child is BoxContainer and (child as Control).visible:
			return child
	if depth > 0:
		for child in node.get_children():
			if child is Control and (child as Control).visible:
				var found := _first_box(child, depth - 1)
				if found != null:
					return found
	return null


static func _find_scroll(node: Control, depth: int) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	if depth <= 0:
		return null
	for child in node.get_children():
		var control := child as Control
		if control != null and control.visible:
			var found := _find_scroll(control, depth - 1)
			if found != null:
				return found
	return null


static func _scroll_rows(scroll: ScrollContainer) -> Array[Control]:
	var content: Control = null
	for child in scroll.get_children():
		if child is Control and not child is ScrollBar and (child as Control).visible:
			content = child
			break
	# Through the gutter margin and any single wrapper, down to the list itself.
	var guard := 0
	while content != null and guard < 4:
		guard += 1
		var visible_kids: Array[Control] = []
		for child in content.get_children():
			if child is Control and (child as Control).visible:
				visible_kids.append(child)
		if visible_kids.size() == 1 and visible_kids[0] is Container:
			content = visible_kids[0]
			continue
		return visible_kids
	return []


# ------------------------------------------------------------------ boards

static func power_on(board: Control) -> void:
	## One scanline down the board as it lands.
	if not live() or not board.is_inside_tree():
		return
	var host := board.get_parent()
	if host == null:
		return
	if board.has_meta(&"ui_power"):
		var old := board.get_meta(&"ui_power") as Node
		if old != null and is_instance_valid(old):
			old.queue_free()
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = POWER_SHADER
	glow.material = material
	host.add_child(glow)
	host.move_child(glow, board.get_index() + 1)
	board.set_meta(&"ui_power", glow)
	var follow := func(p: float) -> void:
		if not is_instance_valid(board) or not is_instance_valid(glow):
			return
		glow.position = board.position + Vector2(2, 2)
		glow.size = board.size - Vector2(4, 4)
		material.set_shader_parameter(&"height", glow.size.y)
		material.set_shader_parameter(&"progress", p)
	follow.call(0.0)
	var tween := glow.create_tween()
	tween.tween_interval(0.12)
	tween.tween_method(follow, 0.0, 1.0, 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(glow.queue_free)


static func dress_scrim(node: ColorRect) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var material := ShaderMaterial.new()
	material.shader = SCRIM_SHADER
	node.material = material
	node.tree_entered.connect(func() -> void:
		material.set_shader_parameter(&"px", _px(node)))
	node.visibility_changed.connect(func() -> void:
		if node.is_visible_in_tree():
			material.set_shader_parameter(&"px", _px(node)))


static func sheen() -> ShaderMaterial:
	## Shared on purpose: one material, one clock, one sweep.
	if _sheen == null:
		_sheen = ShaderMaterial.new()
		_sheen.shader = SHEEN_SHADER
	return _sheen


static func set_sheen(node: CanvasItem, on: bool) -> void:
	if on and live():
		var material := sheen()
		material.set_shader_parameter(&"px", _px(node))
		node.material = material
	elif node.material == _sheen and _sheen != null:
		node.material = null


static func flash(node: Control, color: Color = Color(1.5, 1.4, 1.2),
		time: float = 0.28) -> void:
	## A surface lights for a beat. `self_modulate`, so its text keeps its ink.
	if not live() or not is_instance_valid(node):
		return
	var tween := _fresh(node, &"ui_flash_tween")
	node.self_modulate = color
	tween.tween_property(node, "self_modulate", Color.WHITE, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
