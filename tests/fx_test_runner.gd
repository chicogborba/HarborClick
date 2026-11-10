extends Node
## The Fx pool and the camera shake.
## Run with:
## Godot --headless --path . res://tests/fx_test_runner.tscn
##
## The roll call, and the reason there is one.
##
## A GDScript runtime error does not raise: it prints, aborts the function it
## happened in, and hands control back to the caller as if that function had
## returned. A suite that only counts *assertions it was given* therefore
## reports a test that died on its first line as a pass. Every test below names
## itself as its *last* statement; a test that aborts never gets there, and the
## roll call at the end turns its absence into a failure with the test's own
## name on it.

const EXPECTED := [
	"pool_fixed", "particles_hide", "reduce_motion_noop", "whole_pixels",
	"camera_shake_returns_to_zero",
]

var failures: Array[String] = []
var _finished: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(31337)
	UserPreferences.reduce_motion = false

	_test_pool_stays_fixed_after_500_bursts()
	_test_particles_hide_after_their_life()
	_test_burst_is_a_noop_under_reduce_motion()
	_test_positions_are_whole_pixels()
	_test_camera_shake_returns_offset_to_zero()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)

	UserPreferences.reduce_motion = false
	if failures.is_empty():
		print("FX TESTS PASSED (%d tests: pool fixed at 96, particles hide "
			% EXPECTED.size()
			+ "after their life, reduce-motion no-op, whole-pixel positions, "
			+ "camera shake returns to zero)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FX TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	## The last statement of every test. See `EXPECTED`.
	_finished[label] = true


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _new_fx() -> Fx:
	var fx := Fx.new()
	add_child(fx) # _ready builds the pool
	return fx


func _any_visible(fx: Fx) -> bool:
	for s in fx._sprites:
		if s.visible:
			return true
	return false


func _test_pool_stays_fixed_after_500_bursts() -> void:
	UserPreferences.reduce_motion = false
	var fx := _new_fx()
	_expect(fx._sprites.size() == 96,
		"the pool is built with 96 sprites once (%d)" % fx._sprites.size())
	var kinds := [&"dust", &"spark", &"splash", &"coin", &"confetti"]
	for n in 500:
		fx.burst(kinds[n % 5], Vector2(40.0 + n % 17, 40.0 + n % 13), 6, 14.0)
	_expect(fx._sprites.size() == 96,
		"500 bursts (3000 particles) do not grow the pool (%d)" % fx._sprites.size())
	_expect(fx.get_child_count() == 96,
		"no node is ever added per burst (%d children)" % fx.get_child_count())
	_expect(fx.active_count() == 96,
		"a full pool recycles the oldest slots and ends all-live (%d)"
		% fx.active_count())
	fx.queue_free()
	_done("pool_fixed")


func _test_particles_hide_after_their_life() -> void:
	UserPreferences.reduce_motion = false
	var fx := _new_fx()
	fx.burst(&"confetti", Vector2(100, 100), 12, 20.0) # the longest life: 0.9 s
	_expect(fx.active_count() == 12, "12 particles are live after the burst")
	var guard := 0
	while _any_visible(fx) and guard < 200:
		fx._process(0.05) # driven manually, outside the tree's own tick
		guard += 1
	_expect(not _any_visible(fx),
		"every particle hides once its life is over (guard %d)" % guard)
	_expect(fx.active_count() == 0, "and every slot is inactive again")
	fx.queue_free()
	_done("particles_hide")


func _test_burst_is_a_noop_under_reduce_motion() -> void:
	UserPreferences.reduce_motion = false
	var fx := _new_fx()
	UserPreferences.reduce_motion = true
	fx.burst(&"spark", Vector2(50, 50), 24, 30.0)
	_expect(fx.active_count() == 0, "a burst under reduce motion emits nothing")
	_expect(not _any_visible(fx), "and nothing is visible")
	fx._process(0.1)
	_expect(not _any_visible(fx), "and _process keeps it silent")
	UserPreferences.reduce_motion = false
	fx.burst(&"spark", Vector2(50, 50), 6, 14.0)
	_expect(fx.active_count() == 6, "the same burst fires again once motion is back")
	fx.queue_free()
	_done("reduce_motion_noop")


func _test_positions_are_whole_pixels() -> void:
	UserPreferences.reduce_motion = false
	var fx := _new_fx()
	fx.burst(&"dust", Vector2(33.4, 77.6), 20, 25.0) # a fractional origin
	var whole := true
	var still := true
	for step in 12:
		fx._process(0.03)
		for s in fx._sprites:
			if not s.visible:
				continue
			if s.position != s.position.round():
				whole = false
			if s.rotation != 0.0 or s.scale != Vector2.ONE:
				still = false
	_expect(whole, "every live particle sits on a whole pixel")
	_expect(still, "and no particle is ever rotated or scaled")
	fx.queue_free()
	_done("whole_pixels")


func _test_camera_shake_returns_offset_to_zero() -> void:
	UserPreferences.reduce_motion = false
	var cam := PortCamera.new()
	add_child(cam)
	_expect(cam.offset == Vector2.ZERO, "the offset starts at zero")
	cam.shake(6.0, 0.3)
	var saw_jitter := false
	var whole := true
	for step in 10:
		cam._process(0.05) # driven manually
		if cam.offset != Vector2.ZERO:
			saw_jitter = true
			if cam.offset != cam.offset.round():
				whole = false
	_expect(saw_jitter, "the shake actually moved the offset")
	_expect(whole, "every shake step is a whole-pixel offset")
	_expect(cam.offset == Vector2.ZERO,
		"the offset returns to zero when the shake ends (%s)" % str(cam.offset))
	# And the whole thing is ignored under reduce motion.
	UserPreferences.reduce_motion = true
	cam.shake(5.0, 0.5)
	cam._process(0.05)
	_expect(cam.offset == Vector2.ZERO, "shake is ignored under reduce motion")
	UserPreferences.reduce_motion = false
	cam.queue_free()
	_done("camera_shake_returns_to_zero")
