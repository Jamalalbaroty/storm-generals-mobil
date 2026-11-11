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

	# Stable IDs must be reserved before assigning IDs to earlier unassigned records.
	game.set("next_unit_identity", 1)
	game.get("units").assign([
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(100.0, 100.0)},
		{"unit_id": "unit_00000001", "kind": "infantry", "team": "player", "hp": 60, "pos": Vector2(130.0, 100.0)}
	])
	game.call("_ensure_stable_unit_identities")
	_expect(String(game.get("units")[0].get("unit_id", "")) == "unit_00000002", "Unassigned earlier spawn must not steal a later unit's reserved stable ID")
	_expect(String(game.get("units")[1].get("unit_id", "")) == "unit_00000001", "Existing stable unit ID must remain unchanged")
	game.get("units").remove_at(0)
	game.call("_ensure_stable_unit_identities")
	_expect(String(game.get("units")[0].get("unit_id", "")) == "unit_00000001", "Stable identity must survive unit-array compaction")
	game.get("units").clear()

	# Strategic supply points remain neutral while contested and change hands when uncontested.
	game.get("supply_points").assign([{
		"pos": Vector2(400.0, 300.0),
		"owner": "neutral",
		"kind": "supply",
		"payout": 0.0,
		"supply_payout": 0.0
	}])
	game.get("units").assign([
		{"kind": "infantry", "team": "player", "hp": 60, "pos": Vector2(405.0, 300.0)},
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(395.0, 300.0)}
	])
	game.set("credits", 0)
	game.set("enemy_credits", 0)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "neutral", "A contested neutral supply point must not change hands")
	game.get("units").remove_at(1)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "player", "An uncontested player unit must capture a neutral supply point")
	_expect(int(game.get("credits")) >= 4, "A player-controlled supply point must generate its income")
	game.get("units").clear()
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(400.0, 300.0)})
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "enemy", "An uncontested enemy unit must recapture a player supply point")
	_expect(int(game.get("enemy_credits")) >= 4, "An enemy-controlled supply point must generate enemy income")
	game.get("units").clear()
	game.get("supply_points").clear()

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
	game.get("production_orders").append({"producer_id": 4, "producer_pos": Vector2(650.0, 320.0), "producer_kind": "airfield", "kind": "fighter", "remaining": 8.5, "duration": 20.0})
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

	# Exercise every meaningful transport lifecycle boundary through the real snapshot path.
	var transport_cases := [
		{"state": "inbound", "cargo_count": 1, "target": Vector2(710.0, 280.0), "route": [Vector2(500.0, 220.0), Vector2(710.0, 280.0)], "drop_index": 0},
		{"state": "descending", "cargo_count": 1, "target": Vector2(720.0, 290.0), "route": [Vector2(540.0, 230.0), Vector2(720.0, 290.0)], "drop_index": 0},
		{"state": "returning", "cargo_count": 1, "target": Vector2(650.0, 320.0), "route": [Vector2(600.0, 280.0), Vector2(650.0, 320.0)], "drop_index": 0},
		{"state": "loaded", "cargo_count": 1, "target": Vector2(680.0, 260.0), "route": [], "drop_index": 0},
		{"state": "idle", "cargo_count": 0, "target": Vector2.ZERO, "route": [], "drop_index": 1}
	]
	for case_index in range(transport_cases.size()):
		var transport_case: Dictionary = transport_cases[case_index]
		var live_transport: Dictionary = game.get("units")[0]
		live_transport["transport_state"] = String(transport_case["state"])
		live_transport["transport_target_pos"] = transport_case["target"]
		live_transport["transport_ai_route_points"] = transport_case["route"].duplicate(true)
		live_transport["transport_ai_route_index"] = 0
		live_transport["transport_drop_index"] = int(transport_case["drop_index"])
		live_transport["transport_drop_timer"] = 0.35
		live_transport["transport_cargo"] = []
		if int(transport_case["cargo_count"]) > 0:
			live_transport["transport_cargo"] = [{
				"unit_id": "unit_00000052",
				"kind": "infantry",
				"team": "player",
				"faction": "وطن",
				"hp": 47,
				"pos": Vector2(420.0, 210.0)
			}]
		elif game.get("units").size() == 1:
			game.get("units").append({
				"unit_id": "unit_00000052",
				"kind": "infantry",
				"team": "player",
				"faction": "وطن",
				"hp": 47,
				"pos": Vector2(720.0, 290.0)
			})
		_expect(bool(game.call("_save_battle_snapshot")), "Transport lifecycle case %s should save" % String(transport_case["state"]))
		live_transport["transport_state"] = "idle"
		live_transport["transport_ai_route_points"] = []
		_expect(bool(game.call("_load_battle_snapshot")), "Transport lifecycle case %s should restore" % String(transport_case["state"]))
		var restored_transport: Dictionary = game.get("units")[0]
		_expect(String(restored_transport.get("transport_state", "")) == String(transport_case["state"]), "Transport lifecycle state should survive save/restore")
		_expect(Array(restored_transport.get("transport_cargo", [])).size() == int(transport_case["cargo_count"]), "Transport cargo manifest should match lifecycle state")
		_expect(restored_transport.get("transport_target_pos", Vector2.ZERO).distance_to(transport_case["target"]) < 0.1, "Transport destination should survive lifecycle save/restore")
		_expect(Array(restored_transport.get("transport_ai_route_points", [])).size() == Array(transport_case["route"]).size(), "Transport tactical route should survive lifecycle save/restore")
		if case_index == transport_cases.size() - 1:
			_expect(game.get("units").size() == 2 and String(game.get("units")[1].get("unit_id", "")) == "unit_00000052", "Dropped passenger should exist as a field unit after leaving the manifest")

	# Battle outcomes must update career and campaign progression exactly once.
	var original_commander_profile: Dictionary = game.get("commander_profile").duplicate(true)
	game.set("commander_profile", {
		"battles_played": 0,
		"victories": 0,
		"defeats": 0,
		"total_kills": 0,
		"air_kills": 0,
		"armor_kills": 0,
		"naval_kills": 0,
		"earned_medals": [],
		"campaign_progress": {"وطن": 0},
		"campaign_funds": 0
	})
	game.set("faction", "وطن")
	game.set("campaign_mission_index", 0)
	game.set("campaign_briefing", false)
	game.set("commander_profile_saved_result", "")
	game.set("battle_result", "")
	game.set("enemy_base_hp", 0)
	game.set("player_base_hp", 700)
	_expect(bool(game.call("_resolve_battle_result")), "Destroying the enemy base must resolve a victory immediately")
	var victory_profile: Dictionary = game.get("commander_profile")
	_expect(int(victory_profile.get("battles_played", 0)) == 1 and int(victory_profile.get("victories", 0)) == 1, "Victory must increment battle and victory totals once")
	_expect(int(victory_profile.get("campaign_progress", {}).get("وطن", 0)) == 1, "Victory must unlock the next campaign mission")
	_expect(int(victory_profile.get("campaign_funds", 0)) == 350, "Meeting the first mission secondary objective must grant base and bonus rewards")
	game.call("_resolve_battle_result")
	_expect(int(victory_profile.get("battles_played", 0)) == 1 and int(victory_profile.get("victories", 0)) == 1, "Repeated victory resolution must not duplicate career totals")
	_expect(int(victory_profile.get("campaign_funds", 0)) == 350, "Repeated victory resolution must not duplicate campaign rewards")

	game.set("faction", "")
	game.set("commander_profile_saved_result", "")
	game.set("battle_result", "")
	game.set("enemy_base_hp", 500)
	game.set("player_base_hp", 0)
	_expect(bool(game.call("_resolve_battle_result")), "Destroying the player base must resolve a defeat immediately")
	var defeat_profile: Dictionary = game.get("commander_profile")
	_expect(int(defeat_profile.get("battles_played", 0)) == 2 and int(defeat_profile.get("defeats", 0)) == 1, "Defeat must increment battle and defeat totals once")
	_expect(int(defeat_profile.get("campaign_progress", {}).get("وطن", 0)) == 1 and int(defeat_profile.get("campaign_funds", 0)) == 350, "Defeat must not unlock missions or award campaign funds")
	game.call("_resolve_battle_result")
	_expect(int(defeat_profile.get("battles_played", 0)) == 2 and int(defeat_profile.get("defeats", 0)) == 1, "Repeated defeat resolution must not duplicate career totals")
	game.set("commander_profile", original_commander_profile)
	game.call("_save_commander_profile")

	game.get("battle_save_store").call("delete_snapshot")
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
