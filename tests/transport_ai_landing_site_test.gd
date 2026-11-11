extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Keep headless teardown deterministic and independent of audio devices.
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	var objective := Vector2(1100.0, 250.0)

	var outside := game.call("_transport_ai_evaluate_landing_site", {"id": "outside", "pos": Vector2(5.0, 5.0), "landing_type": "ground"}, objective)
	_expect(not bool(outside.get("valid", true)) and String(outside.get("reason", "")) == "outside_map", "Reject landing points outside safe map bounds")

	var invalid_roof := game.call("_transport_ai_evaluate_landing_site", {"id": "roof", "pos": Vector2(450.0, 250.0), "landing_type": "rooftop", "building_kind": "barracks"}, objective)
	_expect(not bool(invalid_roof.get("valid", true)) and String(invalid_roof.get("reason", "")) == "invalid_rooftop", "Reject rooftops that do not resolve to a completed building")

	game.get("enemy_buildings").append({"kind": "anti_air", "hp": 500, "pos": Vector2(500.0, 250.0)})
	var candidates: Array[Dictionary] = [
		{"id": "exposed", "pos": Vector2(600.0, 250.0), "landing_type": "ground"},
		{"id": "safe", "pos": Vector2(900.0, 250.0), "landing_type": "ground"}
	]
	var chosen: Dictionary = game.call("_transport_ai_choose_landing_site", candidates, objective)
	_expect(String(chosen.get("site_id", "")) == "safe", "Prefer the site with lower known anti-air exposure")

	game.get("enemy_buildings").clear()
	var tied_candidates: Array[Dictionary] = [
		{"id": "bravo", "pos": Vector2(400.0, 250.0), "landing_type": "ground"},
		{"id": "alpha", "pos": Vector2(800.0, 250.0), "landing_type": "ground"}
	]
	var first_choice: Dictionary = game.call("_transport_ai_choose_landing_site", tied_candidates, Vector2(600.0, 250.0))
	var second_choice: Dictionary = game.call("_transport_ai_choose_landing_site", tied_candidates, Vector2(600.0, 250.0))
	_expect(String(first_choice.get("site_id", "")) == "alpha", "Equal-score and equal-distance sites must use stable lexical ID tie-break")
	_expect(String(first_choice.get("site_id", "")) == String(second_choice.get("site_id", "")), "Identical inputs must produce identical landing decisions")

	print("Transport AI landing-site regression passed")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
