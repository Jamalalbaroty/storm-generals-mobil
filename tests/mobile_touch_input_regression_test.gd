extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const BATTLEFIELD_SCRIPT = preload("res://prototype_3d/battlefield_3d.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_2d_touch_ownership_and_cancellation()
	await _test_3d_pinch_zoom_and_cancellation()
	await _test_parent_secondary_finger_cancellation()
	if failures > 0:
		push_error("Mobile touch input regression failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("PASS: mobile touch ownership, secondary-finger isolation, synthetic mouse suppression, pinch zoom, and cancellation.")
	quit(0)


func _test_2d_touch_ownership_and_cancellation() -> void:
	var game: Node = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_cleanup_audio(game)
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("use_3d_view", false)

	var first_press := InputEventScreenTouch.new()
	first_press.index = 0
	first_press.position = Vector2(400.0, 300.0)
	first_press.pressed = true
	game.call("_input", first_press)
	_expect(int(game.get("active_touch_index")) == 0, "The first finger must own the 2D command pointer")
	_expect(bool(game.get("dragging")), "The first finger must begin the pointer gesture")

	var second_press := InputEventScreenTouch.new()
	second_press.index = 1
	second_press.position = Vector2(800.0, 500.0)
	second_press.pressed = true
	game.call("_input", second_press)
	_expect(int(game.get("active_touch_index")) == 0, "A secondary finger must not steal the active command pointer")
	_expect(game.get("drag_start") == Vector2(400.0, 300.0), "A secondary finger must not replace the first finger's drag origin")

	var secondary_drag := InputEventScreenDrag.new()
	secondary_drag.index = 1
	secondary_drag.position = Vector2(900.0, 550.0)
	game.call("_input", secondary_drag)
	_expect(game.get("drag_end") == Vector2(400.0, 300.0), "A secondary finger must not move the active 2D selection gesture")

	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	emulated_mouse.position = Vector2(900.0, 600.0)
	game.call("_input", emulated_mouse)
	_expect(game.get("drag_start") == Vector2(400.0, 300.0), "Emulated mouse input must not duplicate an active touch command")

	var primary_drag := InputEventScreenDrag.new()
	primary_drag.index = 0
	primary_drag.position = Vector2(460.0, 340.0)
	game.call("_input", primary_drag)
	_expect(game.get("drag_end") == Vector2(460.0, 340.0), "The owning finger must update the active 2D drag endpoint")

	var cancelled := InputEventScreenTouch.new()
	cancelled.index = 0
	cancelled.position = Vector2(460.0, 340.0)
	cancelled.canceled = true
	game.call("_input", cancelled)
	_expect(int(game.get("active_touch_index")) == -1, "A cancelled primary touch must release pointer ownership")
	_expect(not bool(game.get("dragging")), "A cancelled primary touch must abort the active 2D drag")

	var stale_release := InputEventScreenTouch.new()
	stale_release.index = 0
	stale_release.position = Vector2(460.0, 340.0)
	stale_release.pressed = false
	game.call("_input", stale_release)
	_expect(not bool(game.get("dragging")), "A release after cancellation must not complete the aborted gesture")

	_cleanup_audio(game)
	game.queue_free()
	await process_frame


func _test_3d_pinch_zoom_and_cancellation() -> void:
	var battlefield: Node3D = BATTLEFIELD_SCRIPT.new()
	root.add_child(battlefield)
	await process_frame
	var starting_height := float(battlefield.get("camera_height"))

	var first_press := InputEventScreenTouch.new()
	first_press.index = 0
	first_press.position = Vector2(100.0, 100.0)
	first_press.pressed = true
	battlefield.call("_unhandled_input", first_press)

	var second_press := InputEventScreenTouch.new()
	second_press.index = 1
	second_press.position = Vector2(200.0, 100.0)
	second_press.pressed = true
	battlefield.call("_unhandled_input", second_press)
	_expect((battlefield.get("touch_points") as Dictionary).size() == 2, "The 3D battlefield must track both fingers during a pinch")
	_expect(bool(battlefield.get("touch_multi_gesture")), "Two simultaneous fingers must enter multi-touch mode")

	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(260.0, 100.0)
	pinch_drag.relative = Vector2(60.0, 0.0)
	battlefield.call("_unhandled_input", pinch_drag)
	_expect(float(battlefield.get("camera_height")) < starting_height,
		"Moving pinch fingers apart must zoom the 3D battlefield camera in")

	var cancelled := InputEventScreenTouch.new()
	cancelled.index = 0
	cancelled.position = Vector2(100.0, 100.0)
	cancelled.canceled = true
	battlefield.call("_unhandled_input", cancelled)
	_expect((battlefield.get("touch_points") as Dictionary).is_empty(), "A cancelled 3D touch must clear every tracked finger")
	_expect((battlefield.get("touch_start_positions") as Dictionary).is_empty(), "A cancelled 3D touch must clear every gesture origin")
	_expect(not bool(battlefield.get("touch_multi_gesture")), "A cancelled 3D touch must exit multi-touch mode")
	_expect(is_zero_approx(float(battlefield.get("last_pinch_distance"))), "A cancelled 3D touch must reset pinch distance")

	battlefield.queue_free()
	await process_frame



func _test_parent_secondary_finger_cancellation() -> void:
	var game: Node = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_cleanup_audio(game)
	game.set("game_started", true)
	game.call("_set_3d_view_enabled", true)
	_expect(bool(game.get("use_3d_view")), "The 3D input cancellation test must activate the live battlefield bridge")
	var battlefield: Node = game.get("battlefield_3d")
	_expect(is_instance_valid(battlefield), "The 3D battlefield bridge must exist for parent-child touch routing")
	if not is_instance_valid(battlefield):
		_cleanup_audio(game)
		game.queue_free()
		await process_frame
		return

	var primary := InputEventScreenTouch.new()
	primary.index = 0
	primary.position = Vector2(100.0, 100.0)
	primary.pressed = true
	game.call("_input", primary)
	battlefield.call("_unhandled_input", primary)

	var secondary := InputEventScreenTouch.new()
	secondary.index = 1
	secondary.position = Vector2(200.0, 100.0)
	secondary.pressed = true
	game.call("_input", secondary)
	battlefield.call("_unhandled_input", secondary)
	_expect(int(game.get("active_touch_index")) == 0, "The parent must retain its first-finger owner while 3D pinch starts")
	_expect((battlefield.get("touch_points") as Dictionary).size() == 2, "The 3D child must receive both fingers for pinch handling")

	var secondary_cancel := InputEventScreenTouch.new()
	secondary_cancel.index = 1
	secondary_cancel.position = Vector2(200.0, 100.0)
	secondary_cancel.canceled = true
	game.call("_input", secondary_cancel)
	battlefield.call("_unhandled_input", secondary_cancel)
	_expect(int(game.get("active_touch_index")) == -1,
		"Cancellation of the secondary pinch finger must release the parent's stale primary pointer")
	_expect((battlefield.get("touch_points") as Dictionary).is_empty(),
		"Cancellation of either pinch finger must clear the child's complete gesture state")

	_cleanup_audio(game)
	game.queue_free()
	await process_frame

func _cleanup_audio(game: Node) -> void:
	var players: Array = game.get("audio_players")
	for player in players:
		player.stop()
		player.stream = null
		game.remove_child(player)
		player.free()
	players.clear()
	(game.get("audio_streams") as Dictionary).clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Mobile touch input test failed: " + message)
