extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	game.faction = "الأمريكي"
	game.credits = 0
	game.supplies = 0
	game.buildings.clear()
	game.production_orders.clear()
	game.production_orders.append({
		"producer_pos": Vector2(300.0, 300.0),
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	})

	game._update_production_queues(0.1)

	if not game.production_orders.is_empty():
		push_error("Destroyed producer left a stuck production order")
		quit(1)
		return
	if game.credits != 225:
		push_error("Expected 75% tank-cost refund (225 credits), got %d" % game.credits)
		quit(1)
		return
	if game.supplies != 1:
		push_error("Expected tank supply reservation to be refunded")
		quit(1)
		return

	# An existing but unfinished producer must pause, not cancel, its order.
	game.credits = 0
	game.supplies = 0
	game.buildings.append({
		"pos": Vector2(300.0, 300.0),
		"kind": "factory",
		"hp": 400,
		"build_progress": 0.5,
		"build_duration": 10.0
	})
	game.production_orders.append({
		"producer_pos": Vector2(300.0, 300.0),
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	})
	game._update_production_queues(0.1)
	if game.production_orders.size() != 1:
		push_error("Unfinished producer should keep its production order queued")
		quit(1)
		return
	if game.credits != 0 or game.supplies != 0:
		push_error("Paused production must not issue a refund")
		quit(1)
		return
	if not is_equal_approx(float(game.production_orders[0].remaining), 3.0):
		push_error("Unfinished producer should not advance production time")
		quit(1)
		return

	print("PASS: destroyed producers refund cancelled orders; unfinished producers pause without refund")
	quit(0)
