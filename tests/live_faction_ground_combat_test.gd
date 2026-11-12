extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const GROUND_KINDS := ["infantry", "tank", "artillery"]
const TARGET_HP := 5000

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
	game.set("unit_identity_scan_timer", 1.0)
	game.set("map_type", "الساحل الصحراوي")
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("production_orders").clear()
	game.get("missiles").clear()
	game.get("visual_effects").clear()
	game.get("environment_particles").clear()
	game.get("supply_points").clear()

	for army in FACTIONS:
		game.set("faction", army)
		for ground_kind in GROUND_KINDS:
			var attacker := {
				"kind": ground_kind,
				"team": "player",
				"faction": army,
				"hp": 1000,
				"pos": Vector2(500.0, 360.0),
				"attack_cd": 0.0,
				"attack_target": 1,
				"attack_focus_pos": Vector2(540.0, 360.0)
			}
			var target := {
				"kind": "builder",
				"team": "enemy",
				"faction": "الصيني",
				"hp": TARGET_HP,
				"pos": Vector2(540.0, 360.0),
				"attack_cd": 999.0
			}
			var fixture: Array[Dictionary] = [attacker, target]
			(game.get("units") as Array[Dictionary]).assign(fixture)
			_expect((game.get("units") as Array[Dictionary]).size() == 2,
				"%s %s fixture must contain both live units" % [army, ground_kind])
			if failures > 0:
				_cleanup_audio(game)
				game.queue_free()
				await process_frame
				quit(1)
				return

			# Exercise the real player ground-unit branch in main.gd.
			game.call("_process", 0.1)
			var actual_units: Array[Dictionary] = game.get("units")
			if actual_units.size() < 2:
				_expect(false, "%s %s combat unexpectedly removed its live test units" % [army, ground_kind])
				_cleanup_audio(game)
				game.queue_free()
				await process_frame
				quit(1)
				return

			var actual_attacker: Dictionary = actual_units[0]
			var actual_target: Dictionary = actual_units[1]
			_expect(int(actual_target.get("hp", TARGET_HP)) < TARGET_HP,
				"%s %s must deal real damage through the live ground combat loop" % [army, ground_kind])
			_expect(float(actual_attacker.get("combat_xp", 0.0)) > 0.0,
				"%s %s must earn experience from live ground damage" % [army, ground_kind])
			_expect(float(actual_attacker.get("attack_cd", 0.0)) > 0.0,
				"%s %s must receive a firing cooldown after its live attack" % [army, ground_kind])
			print("LIVE GROUND COMBAT: %s | %s | target HP %d | XP %.1f | cooldown %.2fs" % [
				army, ground_kind, int(actual_target.get("hp", 0)),
				float(actual_attacker.get("combat_xp", 0.0)), float(actual_attacker.get("attack_cd", 0.0))
			])

	_cleanup_audio(game)
	game.queue_free()
	for frame in range(4):
		await process_frame

	if failures > 0:
		push_error("Live four-faction ground combat test failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("PASS: infantry, tanks, and artillery from all four factions dealt live damage and earned combat XP.")
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
		push_error("Live ground combat test failed: " + message)
