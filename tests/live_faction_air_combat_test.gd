extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const TARGET_HP := 1000

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_cleanup_audio(game)

	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("base_pos", Vector2(120.0, 360.0))
	game.set("enemy_base", Vector2(1160.0, 360.0))
	game.set("player_base_hp", 100000)
	game.set("enemy_base_hp", 100000)
	game.set("credits", 5000)
	game.set("supplies", 40)
	game.set("enemy_credits", 5000)
	game.set("enemy_supplies", 40)
	game.set("income_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_timer", 0.0)
	game.set("enemy_missile_timer", 999.0)
	game.set("map_type", "الساحل الصحراوي")
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("production_orders").clear()
	game.get("missiles").clear()
	game.get("visual_effects").clear()
	game.get("environment_particles").clear()
	game.get("supply_points").clear()

	for army in FACTIONS:
		var helicopter := {
			"kind": "helicopter",
			"team": "player",
			"faction": army,
			"hp": 180,
			"pos": Vector2(500.0, 360.0),
			"attack_cd": 0.0,
			"aircraft_ammo": 12,
			"attack_target": 1,
			"attack_focus_pos": Vector2(520.0, 360.0)
		}
		var target := {
			"kind": "infantry",
			"team": "enemy",
			"faction": "الصيني",
			"hp": TARGET_HP,
			"pos": Vector2(520.0, 360.0),
			"attack_cd": 10.0
		}
		var live_units: Array[Dictionary] = [helicopter, target]
		(game.get("units") as Array[Dictionary]).assign(live_units)
		_expect((game.get("units") as Array[Dictionary]).size() == 2,
			"%s test fixture must install both live combat units before simulation" % army)
		if failures > 0:
			_cleanup_audio(game)
			game.queue_free()
			await process_frame
			quit(1)
			return

		var expected_raw_damage: int = int(game.call("_helicopter_damage", helicopter))
		var expected_damage: int = int(game.call("_terrain_adjusted_damage", target, expected_raw_damage))
		var expected_cooldown: float = float(game.call("_helicopter_cooldown", helicopter))
		_expect(expected_raw_damage > 0, "%s helicopter must have positive live weapon damage" % army)
		_expect(expected_cooldown > 0.0, "%s helicopter must have a positive live reload cooldown" % army)

		# Exercise the actual player-aircraft branch in main.gd, not a calculated TTK model.
		game.call("_process", 0.1)

		var actual_units: Array[Dictionary] = game.get("units")
		if actual_units.size() < 2:
			_expect(false, "%s live combat loop unexpectedly removed the test units" % army)
			_cleanup_audio(game)
			game.queue_free()
			await process_frame
			quit(1)
			return
		var actual_helicopter: Dictionary = actual_units[0]
		var actual_target: Dictionary = actual_units[1]
		_expect(int(actual_target.get("hp", TARGET_HP)) == TARGET_HP - expected_damage,
			"%s helicopter must apply its faction damage through the live combat loop" % army)
		_expect(int(actual_helicopter.get("aircraft_ammo", 12)) == 11,
			"%s helicopter must consume exactly one missile on its first live volley" % army)
		_expect(is_equal_approx(float(actual_helicopter.get("attack_cd", 0.0)), expected_cooldown),
			"%s helicopter must receive its faction-specific reload cooldown after firing" % army)
		_expect(float(actual_helicopter.get("combat_xp", 0.0)) > 0.0,
			"%s helicopter must earn combat experience from live damage" % army)
		print("LIVE AIR COMBAT: %s | damage %d | cooldown %.2fs | target HP %d" % [
			army, expected_damage, expected_cooldown, int(actual_target.get("hp", 0))
		])

	_cleanup_audio(game)
	game.queue_free()
	for frame in range(4):
		await process_frame

	if failures > 0:
		push_error("Live faction air combat test failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("PASS: all four factions fired real helicopter volleys through the live _process combat loop.")
	quit()


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
		push_error("Live faction air combat test failed: " + message)
