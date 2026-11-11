extends SceneTree

var failure_count: int = 0

func _initialize() -> void:
	call_deferred("_run_transport_airlift_regression")


func _run_transport_airlift_regression() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Remove generated audio players so headless test shutdown is deterministic.
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	game.set("game_started", true)
	game.set("paused", false)
	game.set("faction", "الأمريكي")
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()

	# Loading preserves the selected infantry records and never exceeds eight passengers.
	var loading_transport: Dictionary = {
		"kind": "transport_helicopter",
		"team": "player",
		"pos": Vector2(200.0, 200.0),
		"transport_state": "idle",
		"transport_cargo": []
	}
	game.get("units").append(loading_transport)
	for infantry_index in range(9):
		var infantry_record: Dictionary = {
			"kind": "infantry",
			"team": "player",
			"faction": "الأمريكي",
			"hp": 57 if infantry_index == 0 else 60,
			"pos": Vector2(210.0 + float(infantry_index) * 4.0, 200.0),
			"combat_medals": ["veteran"] if infantry_index == 0 else [],
			"guarding": infantry_index == 0
		}
		if infantry_index == 0:
			infantry_record["attack_target"] = 10
		game.get("units").append(infantry_record)
	game.get("units").append({"kind": "tank", "team": "enemy", "hp": 100, "pos": Vector2(500.0, 200.0)})
	var loading_selection: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	game.set("selected", loading_selection)
	print("LOAD_DEBUG before units=%d selected=%s" % [game.get("units").size(), str(game.get("selected"))])
	game.call("_load_selected_infantry_into_transport")
	print("LOAD_DEBUG after units=%d selected=%s notice=%s units_data=%s" % [game.get("units").size(), str(game.get("selected")), str(game.get("notice")), str(game.get("units"))])
	var loaded_transport: Dictionary = game.get("units")[0]
	var loaded_cargo: Array = loaded_transport.get("transport_cargo", [])
	_expect(loaded_cargo.size() == 8, "Transport should load up to its eight-soldier capacity")
	_expect(game.get("units").size() == 3, "Loading eight of nine selected soldiers should leave one infantry and the enemy on the field")
	_expect(String(loaded_transport.get("transport_state", "")) == "loaded", "A successful load should set the transport state to loaded")
	_expect(game.get("selected").size() == 1 and int(game.get("selected")[0]) == 0, "After loading, the transport should remain selected")
	if not loaded_cargo.is_empty():
		_expect(int(loaded_cargo[0].get("hp", 0)) == 57 and String(loaded_cargo[0].get("faction", "")) == "الأمريكي", "Loading should preserve passenger health and faction")
		_expect(Array(loaded_cargo[0].get("combat_medals", [])).has("veteran") and bool(loaded_cargo[0].get("guarding", false)), "Loading should preserve passenger upgrades and stance")
		_expect(not loaded_cargo[0].has("attack_target") and loaded_cargo[0].get("attack_focus_pos", Vector2.ZERO).distance_to(Vector2(500.0, 200.0)) < 0.1, "Loading should preserve the passenger's intended target position without a stale array index")
	game.set("selected", [0, 1])
	game.call("_load_selected_infantry_into_transport")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).size() == 8, "A full transport must not exceed its eight-soldier capacity")
	_expect(game.get("units").size() == 3, "A full transport must leave excess infantry on the battlefield")

	game.get("units").clear()

	# Player-selected focus must override a closer opportunistic target.
	var transport: Dictionary = {
		"kind": "transport_helicopter",
		"team": "player",
		"pos": Vector2(200.0, 200.0),
		"transport_state": "loaded",
		"transport_cargo": [
			{"kind": "infantry", "faction": "الأمريكي", "hp": 60, "cargo_attack_cd": 0.0},
			{"kind": "infantry", "faction": "الأمريكي", "hp": 60, "cargo_attack_cd": 0.0}
		],
		"attack_focus_pos": Vector2(300.0, 200.0)
	}
	game.get("units").append({"kind": "tank", "team": "enemy", "hp": 100, "pos": Vector2(300.0, 200.0)})
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 100, "pos": Vector2(230.0, 200.0)})
	game.call("_update_transport_passenger_fire", transport, 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 92, "Door gunners should prioritize the player-selected target")
	_expect(int(game.get("units")[1]["hp"]) == 100, "Door gunners must not switch to a closer unselected enemy")
	_expect(bool(transport.get("transport_firing", false)), "Loaded passengers should fire when their selected target is in range")

	# The transport approaches a commanded target outside the 158-unit firing envelope.
	game.get("units").clear()
	transport = {
		"kind": "transport_helicopter",
		"team": "player",
		"pos": Vector2(200.0, 200.0),
		"transport_state": "loaded",
		"transport_cargo": [{"kind": "infantry", "cargo_attack_cd": 0.0}],
		"attack_focus_pos": Vector2(400.0, 200.0),
		"attack_target": 0
	}
	game.get("units").append({"kind": "tank", "team": "enemy", "hp": 100, "pos": Vector2(400.0, 200.0)})
	game.call("_update_transport_passenger_fire", transport, 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 100, "Door gunners must not fire outside their effective range")
	_expect(transport.get("target", Vector2.ZERO).distance_to(Vector2(400.0, 200.0)) < 0.1, "Transport should approach a commanded target outside firing range")
	_expect(not bool(transport.get("transport_firing", false)), "Transport firing animation should remain off while approaching")

	# Destroyed or missing targets clear stale attack orders and never fire.
	game.get("units").clear()
	game.get("units").append({"kind": "tank", "team": "enemy", "hp": 0, "pos": Vector2(300.0, 200.0)})
	transport["pos"] = Vector2(200.0, 200.0)
	transport["transport_state"] = "loaded"
	transport["attack_target"] = 0
	transport["attack_focus_pos"] = Vector2(300.0, 200.0)
	transport.erase("target")
	game.call("_update_transport_passenger_fire", transport, 0.1)
	_expect(not transport.has("attack_target") and not transport.has("attack_focus_pos"), "A destroyed target should clear stale transport attack orders")
	_expect(not bool(transport.get("transport_firing", false)), "Transport must not fire at a destroyed target")

	# Passenger weapons are suppressed during descent and when the cargo is empty.
	game.get("units").clear()
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 100, "pos": Vector2(220.0, 200.0)})
	transport["transport_state"] = "descending"
	transport["transport_cargo"] = [{"kind": "infantry", "cargo_attack_cd": 0.0}]
	game.call("_update_transport_passenger_fire", transport, 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 100 and not bool(transport.get("transport_firing", false)), "Passengers must stop firing while descending")
	transport["transport_state"] = "loaded"
	transport["transport_cargo"] = []
	game.call("_update_transport_passenger_fire", transport, 0.1)
	_expect(not bool(transport.get("transport_firing", false)), "An empty transport must not fire")

	# Rooftop rope descent preserves the selected building context on the landed soldier.
	game.get("units").clear()
	var rooftop_transport: Dictionary = {
		"kind": "transport_helicopter",
		"team": "player",
		"pos": Vector2(420.0, 300.0),
		"transport_state": "inbound",
		"transport_target_pos": Vector2(420.0, 300.0),
		"transport_landing_type": "rooftop",
		"transport_target_building_kind": "barracks",
		"transport_cargo": [{"kind": "infantry", "faction": "الأمريكي", "hp": 60}]
	}
	game.call("_update_transport_helicopter", rooftop_transport, 0.1)
	_expect(String(rooftop_transport.get("transport_state", "")) == "descending", "Transport should enter descending at its selected rooftop")
	game.call("_update_transport_helicopter", rooftop_transport, 0.72)
	_expect(game.get("units").size() == 1, "Rooftop rope descent should deploy its passenger")
	if not game.get("units").is_empty():
		var rooftop_soldier: Dictionary = game.get("units")[0]
		_expect(String(rooftop_soldier.get("transport_rooftop_kind", "")) == "barracks", "Rooftop passenger should retain the selected building type")
		_expect(rooftop_soldier.get("transport_rooftop_center", Vector2.ZERO).distance_to(Vector2(420.0, 300.0)) < 0.1, "Rooftop passenger should retain the selected building center")
		_expect(bool(rooftop_soldier.get("transport_rope_drop", false)), "Rooftop passenger should carry the one-shot rope touchdown hint")

	# Full eight-soldier insertion deploys every passenger, clears cargo, and returns to the nearest airfield.
	game.get("units").clear()
	game.get("buildings").append({"kind": "airfield", "pos": Vector2(650.0, 320.0), "hp": 600, "build_progress": 1.0})
	var full_cargo: Array = []
	for passenger_index in range(8):
		full_cargo.append({
			"kind": "infantry",
			"faction": "الأمريكي",
			"hp": 60,
			"combat_medals": [],
			"facing": 0.0
		})
	var full_transport: Dictionary = {
		"kind": "transport_helicopter",
		"team": "player",
		"pos": Vector2(420.0, 320.0),
		"transport_state": "inbound",
		"transport_target_pos": Vector2(420.0, 320.0),
		"transport_landing_type": "ground",
		"transport_cargo": full_cargo,
		"transport_drop_index": 0
	}
	game.call("_update_transport_helicopter", full_transport, 0.1)
	for drop_index in range(8):
		game.call("_update_transport_helicopter", full_transport, 0.72)
	_expect(game.get("units").size() == 8, "A full transport should deploy all eight soldiers")
	_expect(Array(full_transport.get("transport_cargo", [])).is_empty(), "All eight passengers should leave the transport cargo")
	_expect(String(full_transport.get("transport_state", "")) == "returning", "A completed insertion should send the transport back to its airfield")
	for landed_unit in game.get("units"):
		_expect(String(landed_unit.get("team", "")) == "player" and String(landed_unit.get("kind", "")) == "infantry", "Every dropped passenger should become a friendly infantry unit")
		_expect(bool(landed_unit.get("transport_rope_drop", false)), "Every dropped passenger should receive the rope touchdown presentation hint")
		_expect(String(landed_unit.get("faction", "")) == "الأمريكي" and int(landed_unit.get("hp", 0)) == 60, "Airlift should preserve passenger faction and health")
	for return_frame in range(8):
		game.call("_update_transport_helicopter", full_transport, 0.5)
	_expect(String(full_transport.get("transport_state", "")) == "idle", "Transport should complete its return to the nearest airfield")
	_expect(full_transport.pos.distance_to(Vector2(650.0, 320.0)) < 0.1, "Transport should return to the airfield position")

	game.queue_free()
	await process_frame
	if failure_count > 0:
		push_error("Transport airlift regression failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Transport airlift regression passed: player focus, firing range, descent safety, rooftop rope insertion, eight-soldier deployment, and airfield return.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Transport airlift regression failed: " + message)
