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
	game.production_orders = [{
		"producer_pos": Vector2(300.0, 300.0),
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	}]

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

	print("PASS: destroyed producer cancels the order and refunds 75% credits plus supplies")
	quit(0)
