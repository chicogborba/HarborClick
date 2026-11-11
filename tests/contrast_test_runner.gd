extends Node
## WCAG contrast proof for the interface palette.
## Run with:
## Godot --headless --path . res://tests/contrast_test_runner.tscn
##
## Colour is chosen by eye and then drifts. This suite keeps the theme honest:
## every colour used for functional text must clear 4.5:1 against every surface
## it can actually land on, computed with the WCAG 2.1 relative-luminance
## formula rather than eyeballed.
##
## Inactive controls are exempt under WCAG 1.4.3 and are checked at a lower
## floor, so a disabled key stays readable without forcing it to look enabled.

const AA_TEXT := 4.5
const DISABLED_FLOOR := 3.0

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var surfaces := UiTheme.SURFACE

	# ink, surface, label
	var pairs := [
		[UiTheme.INK, surfaces.card, "card title on a card"],
		[UiTheme.INK_SOFT, surfaces.card, "card blurb on a card"],
		[UiTheme.INK_SOFT, surfaces.card_ready, "card blurb on an affordable card"],
		[UiTheme.INK_SOFT, surfaces.card_locked, "hint on a locked card"],
		[UiTheme.INK_SOFT, surfaces.sheet, "body text on the sheet"],
		[UiTheme.INK, surfaces.sheet, "heading on the sheet"],
		[UiTheme.TEAL_DEEP, surfaces.sheet, "section caption on the sheet"],
		[UiTheme.TEAL_DEEP, surfaces.card, "output figure on a card"],
		[UiTheme.AMBER_DEEP, surfaces.card_ready, "contract figure on a card"],
		[UiTheme.SLATE_TEXT, surfaces.slate, "readout on slate"],
		[UiTheme.AMBER, surfaces.slate, "price stamped on slate"],
		[UiTheme.TEAL_LIGHT, surfaces.slate, "notice on slate"],
		[UiTheme.SLATE_DIM, surfaces.slate, "unaffordable price on slate"],
		[UiTheme.INK, surfaces.btn_amber, "label on an amber key"],
		[UiTheme.CREAM, surfaces.btn_alt, "label on a teal key"],
		[UiTheme.CREAM, surfaces.btn_danger, "label on the danger key"],
		[UiTheme.INK, surfaces.btn_ghost, "label on a ghost key"],
		[UiTheme.INK, surfaces.btn_off, "label on a muted key"],
		[UiTheme.INK_SOFT, surfaces.seg_off, "label on an inactive segment"],
		[UiTheme.STEEL_TEXT, surfaces.tab_off, "label on an inactive tab"],
		[UiTheme.AMBER, surfaces.header, "a board's title on its nameplate"],
		# The steel half of the interface: the gantry over the port, the glass
		# the tally is lit behind, the berth tag and the console keys.
		[UiTheme.DIGIT, surfaces.glass, "the tally lit behind glass"],
		[UiTheme.DIGIT, surfaces.gantry, "the hour on the gantry"],
		[UiTheme.STEEL_TEXT, surfaces.gantry, "a caption on the gantry"],
		[UiTheme.STEEL_DIM, surfaces.gantry, "the day on the gantry"],
		[UiTheme.STEEL_TEXT, surfaces.tag, "the berth state on its tag"],
		[UiTheme.TEAL_LIGHT, surfaces.tag, "the rate on its tag"],
		[UiTheme.STEEL_DIM, surfaces.tag, "the cat timer on its tag"],
		[UiTheme.STEEL_TEXT, surfaces.btn_steel, "label on a console key"],
	]
	for pair in pairs:
		var ratio := _contrast(pair[0], pair[1])
		_expect(ratio >= AA_TEXT,
			"%s reads at %.2f:1, below the %.1f:1 floor" % [pair[2], ratio, AA_TEXT])

	# Disabled controls: exempt from AA, but still not invisible.
	var disabled := _contrast(Color8(86, 78, 74), surfaces.btn_off)
	_expect(disabled >= DISABLED_FLOOR,
		"a disabled key reads at %.2f:1, below the %.1f:1 legibility floor"
			% [disabled, DISABLED_FLOOR])

	# The focus ring is two-tone precisely because no single colour is visible
	# on both cream paper and near-black slate. It passes when *either* tone
	# separates from the surface it lands on.
	for key: StringName in surfaces:
		var outer := _contrast(UiTheme.FOCUS_OUTER, surfaces[key])
		var inner := _contrast(UiTheme.FOCUS_INNER, surfaces[key])
		_expect(maxf(outer, inner) >= 3.0,
			"neither tone of the focus ring separates from %s (%.2f:1 / %.2f:1)"
				% [key, outer, inner])

	if failures.is_empty():
		print("CONTRAST TESTS PASSED (%d text pairs at AA)" % pairs.size())
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CONTRAST TESTS FAILED: %d pair(s)" % failures.size())
		get_tree().quit(1)


static func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 \
		else pow((value + 0.055) / 1.055, 2.4)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) \
		+ 0.0722 * _channel(color.b)


static func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
