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
	game.get("units").append({"team": "enemy", "kind": "tank", "hp": 150, "pos": Vector2(600.0, 250.0)})
	var mobile_threat_candidates: Array[Dictionary] = [
		{"id": "near_hostiles", "pos": Vector2(500.0, 250.0), "landing_type": "ground"},
		{"id": "outside_hostile_range", "pos": Vector2(900.0, 250.0), "landing_type": "ground"}
	]
	var mobile_threat_choice: Dictionary = game.call("_transport_ai_choose_landing_site", mobile_threat_candidates, Vector2(700.0, 250.0))
	_expect(String(mobile_threat_choice.get("site_id", "")) == "outside_hostile_range", "Prefer landing sites outside nearby mobile enemy threat range")
	game.get("units").clear()

	var tied_candidates: Array[Dictionary] = [
		{"id": "bravo", "pos": Vector2(400.0, 250.0), "landing_type": "ground"},
		{"id": "alpha", "pos": Vector2(800.0, 250.0), "landing_type": "ground"}
	]
	var first_choice: Dictionary = game.call("_transport_ai_choose_landing_site", tied_candidates, Vector2(600.0, 250.0))
	var second_choice: Dictionary = game.call("_transport_ai_choose_landing_site", tied_candidates, Vector2(600.0, 250.0))
	_expect(String(first_choice.get("site_id", "")) == "alpha", "Equal-score and equal-distance sites must use stable lexical ID tie-break")
	_expect(String(first_choice.get("site_id", "")) == String(second_choice.get("site_id", "")), "Identical inputs must produce identical landing decisions")

	# The tactical director must be able to derive candidates from the live map.
	var generated_candidates: Array = game.call("_transport_ai_build_landing_candidates", objective)
	_expect(not generated_candidates.is_empty(), "Candidate generation should produce ground landing options on a normal map")
	var planned_landing: Dictionary = game.call("_transport_ai_plan_landing", objective)
	_expect(bool(planned_landing.get("valid", false)), "The planner should return a valid landing site when the map has safe ground")
	_expect(planned_landing.has("pos") and planned_landing.has("landing_type"), "The planner should return the complete landing destination contract")

	var transport_manual := {"transport_cargo": [{"kind": "infantry"}]}
	var manual_decision: Dictionary = game.call("_transport_ai_landing_decision", transport_manual, objective)
	_expect(String(manual_decision.get("mode", "")) == "MANUAL", "Transport AI must default to manual control")
	_expect(String(manual_decision.get("action", "")) == "manual_control" and not bool(manual_decision.get("can_execute", true)), "MANUAL mode must never authorize autonomous movement")

	var transport_assisted := {"transport_cargo": [{"kind": "infantry"}], "transport_ai_mode": "ASSISTED"}
	var assisted_decision: Dictionary = game.call("_transport_ai_landing_decision", transport_assisted, objective)
	_expect(String(assisted_decision.get("action", "")) == "recommend" and not bool(assisted_decision.get("can_execute", true)), "ASSISTED mode may recommend but must not execute")

	var transport_autonomous := {"transport_cargo": [{"kind": "infantry"}], "transport_ai_mode": "AUTONOMOUS"}
	var autonomous_decision: Dictionary = game.call("_transport_ai_landing_decision", transport_autonomous, objective)
	_expect(String(autonomous_decision.get("action", "")) == "authorize_autonomous" and bool(autonomous_decision.get("can_execute", false)), "AUTONOMOUS mode may authorize a planned landing")
	transport_autonomous["transport_ai_player_override"] = true
	var override_decision: Dictionary = game.call("_transport_ai_landing_decision", transport_autonomous, objective)
	_expect(String(override_decision.get("action", "")) == "manual_control" and not bool(override_decision.get("can_execute", true)), "An explicit player override must block autonomous execution")

	var empty_transport := {"transport_cargo": [], "transport_ai_mode": "AUTONOMOUS"}
	var empty_decision: Dictionary = game.call("_transport_ai_landing_decision", empty_transport, objective)
	_expect(not bool(empty_decision.get("valid", true)) and String(empty_decision.get("reason", "")) == "empty_cargo", "The tactical director must reject empty transports")

	var manual_request := {"transport_cargo": [{"kind": "infantry"}], "transport_ai_mode": "MANUAL", "transport_state": "loaded", "pos": Vector2(300.0, 300.0)}
	var manual_request_result: Dictionary = game.call("_transport_ai_request_landing", manual_request, objective)
	_expect(not bool(manual_request_result.get("accepted", true)) and String(manual_request.get("transport_state", "")) == "loaded", "MANUAL requests must not change the transport state")

	var assisted_request := {"transport_cargo": [{"kind": "infantry"}], "transport_ai_mode": "ASSISTED", "transport_state": "loaded", "pos": Vector2(300.0, 300.0)}
	var assisted_request_result: Dictionary = game.call("_transport_ai_request_landing", assisted_request, objective)
	_expect(bool(assisted_request_result.get("accepted", false)) and String(assisted_request_result.get("reason", "")) == "recommendation_ready", "ASSISTED requests should return a landing recommendation")
	_expect(String(assisted_request.get("transport_state", "")) == "loaded" and assisted_request.has("transport_ai_recommendation"), "ASSISTED recommendations must not move the aircraft")

	var autonomous_request := {"transport_cargo": [{"kind": "infantry"}], "transport_ai_mode": "AUTONOMOUS", "transport_state": "loaded", "pos": Vector2(300.0, 300.0)}
	var autonomous_request_result: Dictionary = game.call("_transport_ai_request_landing", autonomous_request, objective)
	_expect(bool(autonomous_request_result.get("accepted", false)) and String(autonomous_request.get("transport_state", "")) == "ai_assessing", "AUTONOMOUS requests should queue a landing assessment")
	game.call("_update_transport_helicopter", autonomous_request, 0.016)
	_expect(String(autonomous_request.get("transport_state", "")) == "inbound", "The transport update loop should turn an authorized AI request into inbound flight")
	_expect(autonomous_request.has("transport_target_pos") and autonomous_request.has("transport_ai_last_site_id"), "Autonomous execution should store the selected landing destination")

	var overridden_request := {"transport_cargo": [{"kind": "infantry"}], "transport_ai_mode": "AUTONOMOUS", "transport_ai_player_override": true, "transport_state": "loaded", "pos": Vector2(300.0, 300.0)}
	var overridden_result: Dictionary = game.call("_transport_ai_request_landing", overridden_request, objective)
	_expect(not bool(overridden_result.get("accepted", true)) and String(overridden_request.get("transport_state", "")) == "loaded", "Player override must reject autonomous task requests")

	print("Transport AI landing-site regression passed")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
