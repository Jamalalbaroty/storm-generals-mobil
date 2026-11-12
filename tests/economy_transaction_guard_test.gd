extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const MAX_UNITS := 40
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_disable_audio(game)
	game.set("faction", "وطن")
	game.get("buildings").clear()
	game.get("buildings").append({
		"kind": "factory",
		"pos": Vector2(420.0, 320.0),
		"hp": 500,
		"build_progress": 1.0,
		"production_id": 41
	})
	game.get("buildings").append({
		"kind": "power_plant",
		"pos": Vector2(300.0, 320.0),
		"hp": 500,
		"build_progress": 1.0
	})
	game.get("units").clear()
	game.get("production_orders").clear()

	# Credit rejection is atomic: neither supplies nor queue may change.
	game.set("credits", 359)
	game.set("supplies", 10)
	game.call("_enqueue_unit", "tank")
	_expect(int(game.get("credits")) == 359, "Insufficient credits must not partially charge a Watan tank")
	_expect(int(game.get("supplies")) == 10, "Credit rejection must not reserve supplies")
	_expect((game.get("production_orders") as Array).is_empty(), "Credit rejection must not create a queue entry")

	# Supply rejection is also atomic, even with ample credits.
	game.set("credits", 1000)
	game.set("supplies", 0)
	game.call("_enqueue_unit", "tank")
	_expect(int(game.get("credits")) == 1000, "Insufficient supplies must not charge credits")
	_expect(int(game.get("supplies")) == 0, "Insufficient supplies must not go negative")
	_expect((game.get("production_orders") as Array).is_empty(), "Supply rejection must not create a queue entry")

	# A successful order reserves the exact faction cost and supply amount once.
	game.set("credits", 1000)
	game.set("supplies", 10)
	game.call("_enqueue_unit", "tank")
	_expect(int(game.get("credits")) == 640, "A Watan tank order must reserve its exact 360-credit cost")
	_expect(int(game.get("supplies")) == 9, "A Watan tank order must reserve exactly one supply")
	_expect((game.get("production_orders") as Array).size() == 1, "A valid tank order must be queued exactly once")

	# Pending orders count against the team cap before any unit has spawned.
	game.get("production_orders").clear()
	game.get("units").clear()
	for index in range(MAX_UNITS - 2):
		game.get("units").append({
			"kind": "tank", "team": "player", "hp": 100,
			"pos": Vector2(100.0 + float(index) * 4.0, 100.0)
		})
	game.set("credits", 2000)
	game.set("supplies", 20)
	game.call("_enqueue_unit", "tank")
	game.call("_enqueue_unit", "tank")
	_expect((game.get("production_orders") as Array).size() == 2,
		"Two remaining team slots must allow two reservations")
	var credits_before_cap := int(game.get("credits"))
	var supplies_before_cap := int(game.get("supplies"))
	game.call("_enqueue_unit", "tank")
	_expect((game.get("production_orders") as Array).size() == 2,
		"A full live-plus-queued force must reject the next production order")
	_expect(int(game.get("credits")) == credits_before_cap and int(game.get("supplies")) == supplies_before_cap,
		"Team-cap rejection must not consume either resource")

	# A full team blocks new orders even when no queue exists.
	game.get("production_orders").clear()
	for index in range(2):
		game.get("units").append({
			"kind": "infantry", "team": "player", "hp": 60,
			"pos": Vector2(900.0 + float(index) * 30.0, 500.0)
		})
	var credits_at_full := int(game.get("credits"))
	var supplies_at_full := int(game.get("supplies"))
	game.call("_enqueue_unit", "tank")
	_expect((game.get("production_orders") as Array).is_empty(),
		"Forty living player units must block further production")
	_expect(int(game.get("credits")) == credits_at_full and int(game.get("supplies")) == supplies_at_full,
		"Full-force rejection must leave the economy unchanged")

	# Legacy shipyard presence must never reopen naval production in this release.
	game.get("production_orders").clear()
	game.get("units").clear()
	game.get("buildings").append({
		"kind": "shipyard", "pos": Vector2(700.0, 320.0),
		"hp": 500, "build_progress": 1.0, "production_id": 42
	})
	var naval_credits := int(game.get("credits"))
	var naval_supplies := int(game.get("supplies"))
	game.call("_enqueue_unit", "destroyer")
	_expect((game.get("production_orders") as Array).is_empty(),
		"A legacy shipyard must not enqueue naval units while the naval release gate is closed")
	_expect(int(game.get("credits")) == naval_credits and int(game.get("supplies")) == naval_supplies,
		"Disabled naval production must not charge resources")

	_disable_audio(game)
	game.queue_free()
	await process_frame
	if failures > 0:
		push_error("Economy transaction regression failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("PASS: production reservations are atomic, faction-priced, capacity-safe, and naval-gated.")
	quit(0)


func _disable_audio(game: Node) -> void:
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
		push_error("Economy transaction regression failed: " + message)
