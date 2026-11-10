extends SceneTree

func _initialize() -> void:
	call_deferred("_run_gameplay_economy_smoke_test")


func _run_gameplay_economy_smoke_test() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	game.set("credits", 0)
	game.set("supplies", 0)
	game.call("_initialize_supply_points", Vector2(1280.0, 720.0))
	var port_position: Vector2 = game.get("supply_points")[2]["pos"]
	var live_units: Array = game.get("units")
	live_units.append({"pos": port_position, "team": "player", "kind": "infantry", "hp": 60})
	game.set("units", live_units)

	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[2]["owner"]) == "player", "Player infantry should capture the neutral port")
	_expect(int(game.get("credits")) == 8, "Captured port should generate 8 credits per second")
	_expect(int(game.get("supplies")) == 0, "Port supply payout must not trigger before its 6-second interval")

	game.call("_update_supply_control", 5.0)
	_expect(int(game.get("credits")) == 48, "Port should retain fractional payout time and generate 48 credits over 6 seconds")
	_expect(int(game.get("supplies")) == 1, "Port should grant one supply point after 6 seconds")

	live_units = game.get("units")
	live_units.append({"pos": port_position, "team": "enemy", "kind": "infantry", "hp": 60})
	game.set("units", live_units)
	game.call("_update_supply_control", 4.0)
	_expect(int(game.get("credits")) == 48, "Contested port must stop paying credits")
	_expect(int(game.get("supplies")) == 1, "Contested port must stop paying supplies")

	game.get("units").clear()
	game.get("units").append({"pos": game.get("enemy_base"), "team": "enemy", "kind": "infantry", "hp": 60})
	game.get("enemy_buildings").clear()
	game.set("enemy_credits", 1200)
	game.call("_enemy_ai_turn")
	var rebuilt: Array = game.get("enemy_buildings")
	_expect(not rebuilt.is_empty(), "Enemy AI should rebuild a missing production structure when it has resources")
	_expect(String(rebuilt[0]["kind"]) == "barracks", "Enemy AI should restore its barracks before optional structures")

	print("Gameplay economy smoke test passed: port capture, income, contest lockout, and enemy barracks recovery.")
	game.queue_free()
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("Gameplay economy smoke test failed: " + message)
		quit(1)
