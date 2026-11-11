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

	# Characterize the existing two-side targeting contract before any team-ID
	# migration: side filters, life-state filters, role filters, and range bounds.
	game.get("units").assign([
		{"team": "player", "kind": "tank", "hp": 150, "pos": Vector2(100.0, 100.0)},
		{"team": "enemy", "kind": "infantry", "hp": 80, "pos": Vector2(160.0, 100.0)},
		{"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(125.0, 100.0)},
		{"team": "enemy", "kind": "tank", "hp": 0, "pos": Vector2(105.0, 100.0)},
		{"team": "enemy", "kind": "tank", "hp": 140, "retreating": true, "pos": Vector2(110.0, 100.0)},
		{"team": "player", "kind": "helicopter", "hp": 120, "pos": Vector2(300.0, 100.0)}
	])

	_expect(int(game.call("_nearest_player_unit", Vector2(0.0, 100.0))) == 0, "Enemy target search must select the nearest living player unit")
	_expect(int(game.call("_nearest_enemy_unit", Vector2(0.0, 100.0), 200.0)) == 2, "Player target search must select the nearest living enemy, including air units")
	_expect(int(game.call("_nearest_enemy_unit", Vector2(0.0, 100.0), 200.0, true)) == 2, "Air-only target search must retain fighter targets")
	_expect(int(game.call("_nearest_enemy_ground_unit", Vector2(0.0, 100.0), 200.0)) == 1, "Ground target search must ignore aircraft, dead units, and retreating units")
	_expect(int(game.call("_nearest_enemy_unit", Vector2(0.0, 100.0), 100.0)) == 2, "Target range should include candidates strictly inside the maximum distance")
	_expect(int(game.call("_nearest_enemy_unit", Vector2(0.0, 100.0), 120.0)) == 2, "Nearest target should win when multiple candidates are in range")
	_expect(int(game.call("_nearest_enemy_unit", Vector2(0.0, 100.0), 124.9)) == -1, "Target search must return no target when all living enemies are outside range")
	_expect(int(game.call("_nearest_enemy_ground_unit", Vector2(0.0, 100.0), 100.0)) == 1, "Ground target search should preserve its inclusive maximum-range boundary")

	# Unknown or neutral side labels must not be mistaken for either legacy side.
	game.get("units").append({"team": "neutral", "kind": "tank", "hp": 500, "pos": Vector2(1.0, 100.0)})
	_expect(int(game.call("_nearest_enemy_unit", Vector2(0.0, 100.0), 200.0)) == 2, "Neutral units must not enter the legacy enemy target set")
	_expect(int(game.call("_nearest_player_unit", Vector2(0.0, 100.0))) == 0, "Neutral units must not enter the legacy player target set")

	_cleanup_audio(game)
	game.queue_free()
	await process_frame
	if failures > 0:
		push_error("Two-side targeting characterization failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("Two-side targeting characterization passed: side ownership, life state, ground/air filters, range, and neutral exclusion.")
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
		push_error("Two-side targeting characterization failed: " + message)
