extends SceneTree

const SaveStore = preload("res://scripts/battle_save_store.gd")
var failure_count := 0


func _initialize() -> void:
	call_deferred("_run_battle_save_store_test")


func _run_battle_save_store_test() -> void:
	var store = SaveStore.new()
	store.delete_snapshot()
	var snapshot := {
		"schema_version": 1,
		"match": {
			"faction": "وطن",
			"map_type": "الساحل الصحراوي",
			"campaign_mission_index": 2,
			"credits": 1840,
			"enemy_credits": 920,
			"player_base_hp": 760,
			"enemy_base_hp": 510,
			"next_unit_identity": 42
		},
		"units": [{
			"unit_id": "unit_00000041",
			"kind": "transport_helicopter",
			"team": "player",
			"hp": 155,
			"pos": Vector2(420.0, 210.0),
			"transport_state": "loaded",
			"transport_target_pos": Vector2(680.0, 260.0),
			"transport_cargo": [{
				"unit_id": "unit_00000042",
				"kind": "infantry",
				"team": "player",
				"hp": 47,
				"pos": Vector2(420.0, 210.0),
				"combat_medals": ["مخضرم"]
			}]
		}],
		"buildings": [{"kind": "airfield", "hp": 390, "pos": Vector2(650.0, 320.0), "production_id": 4}],
		"enemy_buildings": [{"kind": "factory", "hp": 240, "pos": Vector2(980.0, 320.0), "production_id": 9}],
		"production_orders": [{"producer_id": 4, "kind": "fighter", "remaining": 8.5, "duration": 20.0}],
		"missiles": [{"team": "player", "pos": Vector2(200.0, 300.0), "target": Vector2(800.0, 300.0), "damage": 180}]
	}
	_expect(store.save_snapshot(snapshot), "A valid versioned battle snapshot should save atomically")
	var restored: Dictionary = store.load_snapshot()
	_expect(not restored.is_empty(), "A saved battle snapshot should load and validate")
	if not restored.is_empty():
		_expect(String(restored["match"].get("faction", "")) == "وطن", "Battle metadata should survive a save/load round trip")
		_expect(int(restored["match"].get("credits", 0)) == 1840, "Player economy should survive a save/load round trip")
		_expect(restored["units"].size() == 1, "Field unit count should survive a save/load round trip")
		var restored_transport: Dictionary = restored["units"][0]
		_expect(String(restored_transport.get("unit_id", "")) == "unit_00000041", "Stable transport identity should survive a save/load round trip")
		_expect(String(restored_transport.get("transport_state", "")) == "loaded", "Transport state should survive a save/load round trip")
		var restored_cargo: Array = restored_transport.get("transport_cargo", [])
		_expect(restored_cargo.size() == 1, "Transport passenger manifest should survive a save/load round trip")
		if not restored_cargo.is_empty():
			_expect(int(restored_cargo[0].get("hp", 0)) == 47, "Passenger health should survive a save/load round trip")
			_expect(String(restored_cargo[0].get("unit_id", "")) == "unit_00000042", "Passenger identity should survive a save/load round trip")
		_expect(restored_transport.get("transport_target_pos", Vector2.ZERO).distance_to(Vector2(680.0, 260.0)) < 0.1, "Transport mission destination should survive a save/load round trip")
		_expect(restored["production_orders"].size() == 1, "Active production queues should survive a save/load round trip")

	var invalid_snapshot: Dictionary = snapshot.duplicate(true)
	invalid_snapshot["units"][0]["transport_cargo"][0]["unit_id"] = "unit_00000041"
	_expect(not store.save_snapshot(invalid_snapshot), "Duplicate field-unit/passenger IDs must be rejected")
	var preserved: Dictionary = store.load_snapshot()
	_expect(not preserved.is_empty() and int(preserved["match"].get("credits", 0)) == 1840, "A rejected snapshot must not overwrite the previous valid save")

	var unsupported_snapshot: Dictionary = snapshot.duplicate(true)
	unsupported_snapshot["schema_version"] = 999
	_expect(not store.save_snapshot(unsupported_snapshot), "Unsupported save schema versions must be rejected")
	_expect(store.delete_snapshot(), "Test save, temporary file, and backup should be cleaned up")

	if failure_count > 0:
		push_error("Battle save store test failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Battle save store test passed: atomic versioned snapshot round trip, transport cargo integrity, and invalid-save protection.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Battle save store test failed: " + message)
