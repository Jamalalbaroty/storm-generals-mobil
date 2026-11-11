extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_cleanup_audio(game)

	# Capture orders are restricted to living player infantry and supersede stale orders.
	game.get("enemy_buildings").assign([
		{"kind": "barracks", "team": "enemy", "hp": 400, "build_progress": 1.0, "pos": Vector2(220.0, 220.0)}
	])
	game.get("units").assign([
		{"team": "player", "kind": "infantry", "hp": 80, "pos": Vector2(100.0, 100.0), "attack_target": 4, "attack_move_active": true},
		{"team": "enemy", "kind": "infantry", "hp": 80, "pos": Vector2(110.0, 100.0)},
		{"team": "player", "kind": "infantry", "hp": 0, "pos": Vector2(120.0, 100.0)},
		{"team": "player", "kind": "tank", "hp": 150, "pos": Vector2(130.0, 100.0)}
	])
	game.set("selected_enemy_building", 0)
	game.get("selected").assign([0, 1, 2, 3])
	game.call("_capture_selected_building")
	_expect(game.get("units")[0].get("target", Vector2.ZERO) == Vector2(220.0, 220.0), "A living selected player infantry unit should receive the capture destination")
	_expect(not game.get("units")[0].has("attack_target") and not game.get("units")[0].has("attack_move_active"), "A fresh capture order should clear stale combat and attack-move orders")
	_expect(not game.get("units")[1].has("target"), "Enemy infantry must not receive a player capture order")
	_expect(not game.get("units")[2].has("target"), "Destroyed player infantry must not receive a capture order")
	_expect(not game.get("units")[3].has("target"), "Player armor must not receive an infantry-only capture order")

	# A nearby enemy guard blocks capture progress; without a guard, progress
	# accumulates to the existing three-second completion threshold.
	game.get("units").assign([
		{"team": "player", "kind": "infantry", "hp": 80, "pos": Vector2(220.0, 220.0)},
		{"team": "enemy", "kind": "tank", "hp": 150, "pos": Vector2(240.0, 220.0)}
	])
	game.get("enemy_buildings")[0]["capture_progress"] = 1.5
	game.call("_update_building_capture", 1.0)
	_expect(is_equal_approx(float(game.get("enemy_buildings")[0].get("capture_progress", -1.0)), 0.0), "A living enemy guard near the building should reset capture progress")

	game.get("units").assign([
		{"team": "player", "kind": "infantry", "hp": 80, "pos": Vector2(220.0, 220.0)}
	])
	var owned_building_count: int = (game.get("buildings") as Array).size()
	game.call("_update_building_capture", 1.5)
	_expect(game.get("enemy_buildings").size() == 1, "Capture should not complete before the three-second threshold")
	game.call("_update_building_capture", 1.5)
	_expect(game.get("enemy_buildings").is_empty(), "A completed capture should remove the building from enemy ownership")
	_expect(game.get("buildings").size() == owned_building_count + 1, "A captured building should be transferred into player building ownership")
	_expect(bool(game.get("buildings")[-1].get("captured", false)), "Transferred building should retain its captured-state marker")
	_expect(int(game.get("buildings")[-1].get("hp", 0)) == 400, "Capture should preserve the building's health")

	_cleanup_audio(game)
	game.queue_free()
	await process_frame
	if failures > 0:
		push_error("Two-side capture characterization failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("Two-side capture characterization passed: player infantry authorization, stale-order clearing, guard interruption, completion threshold, and ownership transfer.")
	quit(0)


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
		push_error("Two-side capture characterization failed: " + message)
