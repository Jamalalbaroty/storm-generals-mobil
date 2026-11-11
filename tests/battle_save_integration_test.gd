extends SceneTree

var failure_count := 0


func _initialize() -> void:
	call_deferred("_run_battle_save_integration_test")


func _run_battle_save_integration_test() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	game.set("faction", "وطن")
	game.set("map_type", "الساحل الجبلي")
	game.set("game_started", true)
	game.set("credits", 1840)
	game.set("supplies", 7)
	game.set("enemy_supplies", 4)
	game.set("enemy_credits", 920)
	game.set("enemy_missile_timer", 6.75)
	game.set("player_base_hp", 760)
	game.set("enemy_base_hp", 510)
	game.set("campaign_mission_index", 2)
	game.get("supply_points").append({"id": "supply_alpha", "owner": "player", "pos": Vector2(430.0, 300.0)})
	game.get("units").append({
		"unit_id": "unit_00000051",
		"kind": "transport_helicopter",
		"team": "player",
		"faction": "وطن",
		"hp": 155,
		"pos": Vector2(420.0, 210.0),
		"transport_state": "loaded",
		"transport_target_pos": Vector2(680.0, 260.0),
		"transport_cargo": [{
			"unit_id": "unit_00000052",
			"kind": "infantry",
			"team": "player",
			"faction": "وطن",
			"hp": 47,
			"pos": Vector2(420.0, 210.0)
		}]
	})
	game.get("buildings").append({"kind": "airfield", "hp": 390, "pos": Vector2(650.0, 320.0), "production_id": 4})
	game.get("enemy_buildings").append({"kind": "factory", "hp": 240, "pos": Vector2(980.0, 320.0), "production_id": 9})
	game.get("production_orders").append({"producer_id": 4, "kind": "fighter", "remaining": 8.5, "duration": 20.0})
	game.get("missiles").append({"team": "player", "pos": Vector2(200.0, 300.0), "target": Vector2(800.0, 300.0), "damage": 180})

	_expect(bool(game.call("_save_battle_snapshot")), "Active battle should save through the gameplay integration")
	game.set("credits", 1)
	game.set("player_base_hp", 1)
	game.set("enemy_missile_timer", 0.0)
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("production_orders").clear()
	game.get("missiles").clear()
	game.get("supply_points").clear()
	_expect(bool(game.call("_load_battle_snapshot")), "A valid saved battle should restore through the gameplay integration")
	_expect(String(game.get("faction")) == "وطن" and String(game.get("map_type")) == "الساحل الجبلي", "Faction and map should be restored")
	_expect(int(game.get("credits")) == 1840 and int(game.get("player_base_hp")) == 760, "Economy and base health should be restored")
	_expect(is_equal_approx(float(game.get("enemy_missile_timer")), 6.75), "Enemy missile attack cadence should be restored")
	_expect(game.get("supply_points").size() == 1 and String(game.get("supply_points")[0].get("owner", "")) == "player", "Supply ownership should be restored")
	_expect(game.get("units").size() == 1, "Field units should be restored")
	if not game.get("units").is_empty():
		var transport: Dictionary = game.get("units")[0]
		_expect(String(transport.get("unit_id", "")) == "unit_00000051", "Transport identity should be restored")
		_expect(String(transport.get("transport_state", "")) == "loaded", "Transport mission state should be restored")
		_expect(Array(transport.get("transport_cargo", [])).size() == 1, "Transport cargo should be restored")
	_expect(game.get("buildings").size() == 1 and game.get("enemy_buildings").size() == 1, "Both armies' building states should be restored")
	_expect(game.get("production_orders").size() == 1 and game.get("missiles").size() == 1, "Production and active missile state should be restored")

	game.set("credits", 1337)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	game.set("credits", 5)
	_expect(bool(game.call("_load_battle_snapshot")), "Android pause notification should persist a resumable battle")
	_expect(int(game.get("credits")) == 1337, "Pause autosave should capture the latest economy state")

	game.get("battle_save_store").call("delete_snapshot")
	game.queue_free()
	await process_frame
	if failure_count > 0:
		push_error("Battle save integration failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Battle save integration passed: full match snapshot restores economy, objectives, armies, transport cargo, production, and missiles.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Battle save integration failed: " + message)
