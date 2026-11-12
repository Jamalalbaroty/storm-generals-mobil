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

	game.set("base_pos", Vector2(120.0, 360.0))
	game.set("enemy_base", Vector2(1160.0, 360.0))
	game.set("enemy_strategy", "balanced")
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("supply_points").clear()

	for army in FACTIONS:
		for ground_kind in GROUND_KINDS:
			var attacker := {
				"kind": ground_kind,
				"team": "enemy",
				"faction": army,
				"hp": 1000,
				"pos": Vector2(900.0, 360.0),
				"attack_cd": 0.0,
				"veterancy": 0
			}
			var target := {
				"kind": "tank",
				"team": "player",
				"faction": "الأمريكي",
				"hp": TARGET_HP,
				"pos": Vector2(940.0, 360.0),
				"attack_cd": 999.0
			}
			var fixture: Array[Dictionary] = [attacker, target]
			(game.get("units") as Array[Dictionary]).assign(fixture)
			var attacker_ref: Dictionary = game.get("units")[0]
			var handled: bool = game.call("_update_enemy_ground_assault", attacker_ref, 0, 0.1)
			_expect(handled, "%s %s must be handled by the enemy ground assault director" % [army, ground_kind])
			var actual_units: Array[Dictionary] = game.get("units")
			var actual_attacker: Dictionary = actual_units[0]
			var actual_target: Dictionary = actual_units[1]
			_expect(int(actual_target.get("hp", TARGET_HP)) < TARGET_HP,
				"%s %s enemy AI must deal live damage to a valid player ground target" % [army, ground_kind])
			_expect(float(actual_attacker.get("combat_xp", 0.0)) > 0.0,
				"%s %s enemy AI must earn combat experience" % [army, ground_kind])
			_expect(float(actual_attacker.get("attack_cd", 0.0)) > 0.0,
				"%s %s enemy AI must apply the correct firing cooldown" % [army, ground_kind])
			print("LIVE ENEMY AI: %s | %s | target HP %d | XP %.1f | cooldown %.2fs" % [
				army, ground_kind, int(actual_target.get("hp", 0)),
				float(actual_attacker.get("combat_xp", 0.0)), float(actual_attacker.get("attack_cd", 0.0))
			])

	_cleanup_audio(game)
	game.queue_free()
	await process_frame
	if failures > 0:
		push_error("Live enemy ground AI test failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("PASS: enemy infantry, tanks, and artillery from all four factions executed live ground attacks.")
	quit(0)


func _cleanup_audio(game: Node) -> void:
	for player in game.get("audio_players"):
		player.stop()
		player.stream = null
		game.remove_child(player)
		player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Live enemy AI test failed: " + message)
