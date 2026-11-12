extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const NAVAL_KINDS := ["destroyer", "carrier", "submarine", "landing_craft"]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_cleanup_audio(game)

	_expect(not bool(game.get("NAVAL_SYSTEM_ENABLED")), "Naval gameplay must remain disabled for the land-and-air release")

	# A legacy or pre-existing shipyard must not let enemy AI resume naval production.
	game.get("enemy_buildings").assign([
		{"kind": "barracks", "hp": 400, "build_progress": 1.0, "pos": Vector2(1000.0, 200.0)},
		{"kind": "factory", "hp": 500, "build_progress": 1.0, "pos": Vector2(1040.0, 200.0)},
		{"kind": "airfield", "hp": 450, "build_progress": 1.0, "pos": Vector2(1080.0, 200.0)},
		{"kind": "shipyard", "hp": 500, "build_progress": 1.0, "pos": Vector2(1120.0, 200.0)},
		{"kind": "anti_air", "hp": 380, "build_progress": 1.0, "pos": Vector2(1000.0, 240.0)},
		{"kind": "missile_silo", "hp": 500, "build_progress": 1.0, "pos": Vector2(1040.0, 240.0)},
		{"kind": "missile_defense", "hp": 450, "build_progress": 1.0, "pos": Vector2(1080.0, 240.0)},
		{"kind": "power_plant", "hp": 400, "build_progress": 1.0, "pos": Vector2(1120.0, 240.0)},
		{"kind": "power_plant", "hp": 400, "build_progress": 1.0}
	])
	game.get("units").assign([
		{"team": "enemy", "kind": "infantry", "hp": 60, "faction": "الصيني", "pos": Vector2(900.0, 250.0)},
		{"team": "enemy", "kind": "infantry", "hp": 60, "faction": "الصيني", "pos": Vector2(920.0, 250.0)},
		{"team": "enemy", "kind": "tank", "hp": 150, "faction": "الصيني", "pos": Vector2(900.0, 300.0)},
		{"team": "enemy", "kind": "tank", "hp": 150, "faction": "الصيني", "pos": Vector2(920.0, 300.0)}
	])
	game.set("enemy_credits", 5000)
	game.set("enemy_supplies", 40)
	game.set("enemy_strategy", "balanced")
	game.call("_enemy_ai_turn")

	for unit in game.get("units"):
		if String(unit.get("team", "")) == "enemy":
			_expect(not NAVAL_KINDS.has(String(unit.get("kind", ""))),
				"Enemy AI must not produce naval units while the naval system is disabled")

	# Player construction must reject shipyards and preserve the resource balance.
	game.get("buildings").clear()
	game.get("units").assign([
		{"team": "player", "kind": "builder", "hp": 100, "pos": Vector2(250.0, 250.0)}
	])
	game.get("selected").assign([0])
	game.set("credits", 5000)
	game.set("build_mode", "shipyard")
	game.call("_place_building", Vector2(300.0, 300.0))
	_expect(game.get("build_mode") == "", "Shipyard placement mode must close when naval gameplay is disabled")
	_expect(int(game.get("credits")) == 5000, "Rejected shipyard placement must not spend credits")
	for building in game.get("buildings"):
		_expect(String(building.get("kind", "")) != "shipyard", "Player must not construct a shipyard in the land-and-air release")

	_cleanup_audio(game)
	game.queue_free()
	await process_frame
	if failures > 0:
		push_error("Naval release gate failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("PASS: naval production and shipyard construction remain disabled; land-and-air AI stays available.")
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
		push_error("Naval release gate failed: " + message)
