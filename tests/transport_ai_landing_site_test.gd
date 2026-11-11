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

	var outside: Dictionary = game.call("_transport_ai_evaluate_landing_site", {"id": "outside", "pos": Vector2(5.0, 5.0), "landing_type": "ground"}, objective)
	_expect(not bool(outside.get("valid", true)) and String(outside.get("reason", "")) == "outside_map", "Reject landing points outside safe map bounds")

	var invalid_roof: Dictionary = game.call("_transport_ai_evaluate_landing_site", {"id": "roof", "pos": Vector2(450.0, 250.0), "landing_type": "rooftop", "building_kind": "barracks"}, objective)
	_expect(not bool(invalid_roof.get("valid", true)) and String(invalid_roof.get("reason", "")) == "invalid_rooftop", "Reject rooftops that do not resolve to a completed building")

	game.get("enemy_buildings").append({"kind": "anti_air", "hp": 500, "pos": Vector2(500.0, 250.0)})
	var candidates: Array[Dictionary] = [
		{"id": "exposed", "pos": Vector2(600.0, 250.0), "landing_type": "ground"},
		{"id": "safe", "pos": Vector2(900.0, 250.0), "landing_type": "ground"}
	]
	var chosen: Dictionary = game.call("_transport_ai_choose_landing_site", candidates, objective)
	_expect(String(chosen.get("site_id", "")) == "safe", "Prefer the site with lower known anti-air exposure")

	game.get("enemy_buildings").clear()
	game.get("units").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(200.0, 250.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 100}]})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(250.0, 250.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 90}]})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 250.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 80}]})
	for transport_index in range(3):
		game.get("units")[transport_index]["transport_order_pending"] = true
	game.get("selected").append_array([0, 1, 2])
	var group_landing_ordered: bool = game.call("_issue_transport_rooftop_order", Vector2(600.0, 250.0))
	_expect(group_landing_ordered, "A transport group should accept a complete set of safe ground insertion sites")
	var group_site_a: Vector2 = game.get("units")[0].get("transport_target_pos", Vector2.ZERO)
	var group_site_b: Vector2 = game.get("units")[1].get("transport_target_pos", Vector2.ZERO)
	var group_site_c: Vector2 = game.get("units")[2].get("transport_target_pos", Vector2.ZERO)
	_expect(group_site_a.distance_to(group_site_b) >= 96.0 and group_site_a.distance_to(group_site_c) >= 96.0 and group_site_b.distance_to(group_site_c) >= 96.0, "Group insertion sites must remain spatially separated")
	_expect(String(game.get("units")[0].get("transport_state", "")) == "inbound" and String(game.get("units")[1].get("transport_state", "")) == "inbound" and String(game.get("units")[2].get("transport_state", "")) == "inbound", "Every selected transport should receive an inbound order")

	# Multi-transport rescue dispatch is atomic, triages casualties, caps each load, and assigns air cover.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "3d_sync_id": 71, "hp": 200, "pos": Vector2(540.0, 250.0), "transport_state": "idle", "transport_cargo": []})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "3d_sync_id": 72, "hp": 200, "pos": Vector2(860.0, 250.0), "transport_state": "idle", "transport_cargo": []})
	for infantry_index in range(18):
		var casualty_hp := 20 if infantry_index == 0 else 65
		game.get("units").append({"team": "player", "kind": "infantry", "hp": casualty_hp, "pos": Vector2(650.0 + float(infantry_index % 6) * 18.0, 235.0 + float(infantry_index / 6) * 18.0)})
	game.get("units").append({"team": "player", "kind": "fighter", "3d_sync_id": 73, "hp": 120, "pos": Vector2(530.0, 220.0)})
	game.get("selected").append_array(range(game.get("units").size()))
	var rescue_indices: Array[int] = []
	for infantry_index in range(2, 20):
		rescue_indices.append(infantry_index)
	var rescue_transports: Array[int] = [0, 1]
	var rescue_result: Dictionary = game.call("_transport_ai_order_group_pickups", rescue_indices, rescue_transports)
	_expect(int(rescue_result.get("transport_count", 0)) == 2 and int(rescue_result.get("passenger_count", 0)) == 16 and int(rescue_result.get("overflow_count", 0)) == 2, "Group rescue should dispatch two aircraft, load at most sixteen casualties, and leave overflow on the ground")
	_expect(String(game.get("units")[0].get("transport_state", "")) == "inbound" and String(game.get("units")[1].get("transport_state", "")) == "inbound", "Every assigned rescue transport should receive an inbound pickup order")
	var rescue_site_a: Vector2 = game.get("units")[0].get("transport_target_pos", Vector2.ZERO)
	var rescue_site_b: Vector2 = game.get("units")[1].get("transport_target_pos", Vector2.ZERO)
	_expect(rescue_site_a.distance_to(rescue_site_b) >= 96.0, "Group rescue landing sites must be separated to prevent aircraft stacking")
	_expect(bool(game.get("units")[20].get("escort_active", false)) and int(game.get("units")[20].get("escort_target_id", -1)) in [71, 72], "Selected fighter should be assigned to protect a dispatched rescue transport")
	game.get("units").clear()
	game.get("selected").clear()

	# Selected fighters and gunships are distributed as air escorts across the transport group.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "3d_sync_id": 41, "hp": 200, "pos": Vector2(200.0, 250.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 100}], "transport_order_pending": true})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "3d_sync_id": 52, "hp": 200, "pos": Vector2(900.0, 250.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 90}], "transport_order_pending": true})
	game.get("units").append({"team": "player", "kind": "fighter", "3d_sync_id": 61, "hp": 120, "pos": Vector2(220.0, 210.0)})
	game.get("units").append({"team": "player", "kind": "helicopter", "3d_sync_id": 62, "hp": 120, "pos": Vector2(880.0, 210.0)})
	game.get("units").append({"team": "player", "kind": "fighter", "3d_sync_id": 63, "hp": 120, "pos": Vector2(210.0, 220.0)})
	game.get("selected").append_array([0, 1, 2, 3, 4])
	var escorted_group_ordered: bool = game.call("_issue_transport_rooftop_order", Vector2(600.0, 250.0))
	_expect(escorted_group_ordered, "A transport group with selected air escorts should still receive its insertion order")
	_expect(bool(game.get("units")[2].get("escort_active", false)) and int(game.get("units")[2].get("escort_target_id", -1)) == 41, "The fighter should escort the nearest first transport")
	_expect(bool(game.get("units")[3].get("escort_active", false)) and int(game.get("units")[3].get("escort_target_id", -1)) == 52, "The gunship should escort the nearest second transport")
	_expect(not game.get("units")[2].has("target") and not game.get("units")[3].has("target"), "Assigning air escort duty should clear stale movement orders")
	_expect(int(game.get("units")[2].get("escort_formation_slot", -1)) == 0 and int(game.get("units")[3].get("escort_formation_slot", -1)) == 0, "Each transport should begin its own escort formation at slot zero")
	_expect(Vector2(game.get("units")[2].get("escort_offset", Vector2.ZERO)).length() > 0.0 and Vector2(game.get("units")[3].get("escort_offset", Vector2.ZERO)).length() > 0.0, "Every escort should receive a non-zero protective offset")
	_expect(int(game.get("units")[2].get("escort_formation_size", 0)) == 2 and int(game.get("units")[4].get("escort_formation_size", 0)) == 2, "The first transport formation should track both assigned aircraft")
	_expect(int(game.get("units")[4].get("escort_target_id", -1)) == 41 and int(game.get("units")[4].get("escort_formation_slot", -1)) == 1, "A second escort assigned to one transport should occupy the next formation slot")
	_expect(Vector2(game.get("units")[2].get("escort_offset", Vector2.ZERO)) != Vector2(game.get("units")[4].get("escort_offset", Vector2.ZERO)), "Escorts protecting the same transport should not stack in one formation position")
	game.get("units").clear()
	game.get("selected").clear()
	game.get("enemy_buildings").clear()
	game.get("units").append({"team": "enemy", "kind": "tank", "hp": 150, "pos": Vector2(600.0, 250.0)})
	var mobile_threat_candidates: Array[Dictionary] = [
		{"id": "near_hostiles", "pos": Vector2(500.0, 250.0), "landing_type": "ground"},
		{"id": "outside_hostile_range", "pos": Vector2(900.0, 250.0), "landing_type": "ground"}
	]
	var mobile_threat_choice: Dictionary = game.call("_transport_ai_choose_landing_site", mobile_threat_candidates, Vector2(700.0, 250.0))
	_expect(String(mobile_threat_choice.get("site_id", "")) == "outside_hostile_range", "Prefer landing sites outside nearby mobile enemy threat range")
	game.get("units").clear()

	# A known anti-air battery should make the direct corridor more expensive than a lateral detour.
	game.get("enemy_buildings").append({"kind": "anti_air", "hp": 500, "pos": Vector2(600.0, 300.0)})
	var route_start := Vector2(300.0, 300.0)
	var route_end := Vector2(900.0, 300.0)
	var direct_route: Array[Vector2] = [route_start, route_end]
	var detour_route: Array[Vector2] = [route_start, Vector2(600.0, 680.0), route_end]
	var direct_exposure: float = game.call("_transport_ai_route_exposure", direct_route)
	var detour_exposure: float = game.call("_transport_ai_route_exposure", detour_route)
	_expect(detour_exposure < direct_exposure, "A lateral waypoint should reduce exposure to a known anti-air battery")
	var selected_route: Array = game.call("_transport_ai_build_route", route_start, route_end)
	_expect(selected_route.size() == 2 and Vector2(selected_route[1]).distance_to(route_end) < 1.0 and Vector2(selected_route[0]).distance_to(route_end) >= 80.0, "Autonomous routing should select a waypoint before the final landing point when it lowers route cost")
	game.get("enemy_buildings").clear()
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 120, "pos": Vector2(600.0, 300.0)})
	var fighter_direct_exposure: float = game.call("_transport_ai_route_exposure", direct_route)
	var fighter_detour_exposure: float = game.call("_transport_ai_route_exposure", detour_route)
	_expect(fighter_direct_exposure > 0.0, "Enemy fighters should contribute interception risk to transport routes")
	_expect(fighter_detour_exposure < fighter_direct_exposure, "Transport route scoring should prefer a detour around an enemy fighter patrol")
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	var clear_route: Array = game.call("_transport_ai_build_route", route_start, route_end)
	_expect(clear_route.size() == 1 and Vector2(clear_route[0]).distance_to(route_end) < 1.0, "With no known anti-air threat, the shortest direct route should remain preferred")

	var tied_candidates: Array[Dictionary] = [
		{"id": "bravo", "pos": Vector2(400.0, 250.0), "landing_type": "ground"},
		{"id": "alpha", "pos": Vector2(800.0, 250.0), "landing_type": "ground"}
	]
	var first_choice: Dictionary = game.call("_transport_ai_choose_landing_site", tied_candidates, Vector2(600.0, 250.0))
	var second_choice: Dictionary = game.call("_transport_ai_choose_landing_site", tied_candidates, Vector2(600.0, 250.0))
	_expect(String(first_choice.get("site_id", "")) == "alpha", "Equal-score and equal-distance sites must use stable lexical ID tie-break")
	_expect(String(first_choice.get("site_id", "")) == String(second_choice.get("site_id", "")), "Identical inputs must produce identical landing decisions")

	var hovering_transport := {"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(600.0, 250.0)}
	game.get("units").append(hovering_transport)
	var transport_clearance: Dictionary = game.call("_transport_ai_evaluate_landing_site", {"id": "under_own_transport", "pos": Vector2(600.0, 250.0), "landing_type": "ground"}, objective)
	_expect(bool(transport_clearance.get("valid", false)), "A friendly transport helicopter must not block its own landing-site evaluation")
	game.get("units").clear()

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

	game.get("units").append({"team": "enemy", "kind": "tank", "hp": 150, "pos": Vector2(600.0, 250.0)})
	var reassessment_transport: Dictionary = {
		"team": "player",
		"kind": "transport_helicopter",
		"hp": 200,
		"pos": Vector2(400.0, 250.0),
		"transport_cargo": [{"kind": "infantry"}],
		"transport_ai_mode": "AUTONOMOUS",
		"transport_ai_autonomous_active": true,
		"transport_ai_objective_pos": objective,
		"transport_ai_reassess_timer": 0.0,
		"transport_state": "inbound",
		"transport_target_pos": Vector2(600.0, 250.0),
		"transport_landing_type": "ground"
	}
	game.call("_transport_ai_reassess_inbound", reassessment_transport, 1.3)
	_expect(int(reassessment_transport.get("transport_ai_replanned", 0)) == 1, "Autonomous transport should replan when its landing footprint becomes occupied by an enemy")
	_expect(Vector2(reassessment_transport.get("transport_target_pos", Vector2.ZERO)).distance_to(Vector2(600.0, 250.0)) >= 80.0, "Replanned destination should move away from the newly occupied landing site")
	game.get("units").clear()

	# If every replacement site becomes unsafe, the director must abort insertion and recover.
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	var blocked_objective := Vector2(720.0, 300.0)
	var blocked_candidates: Array = game.call("_transport_ai_build_landing_candidates", blocked_objective)
	for blocked_candidate in blocked_candidates:
		game.get("units").append({"team": "enemy", "kind": "tank", "hp": 150, "pos": blocked_candidate.pos})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(1040.0, 540.0)})
	var unsafe_inbound: Dictionary = {
		"team": "player", "kind": "transport_helicopter", "hp": 180,
		"pos": Vector2(500.0, 300.0), "transport_state": "inbound",
		"transport_target_pos": blocked_candidates[0].pos,
		"transport_landing_type": "ground",
		"transport_cargo": [{"kind": "infantry", "hp": 75}],
		"transport_ai_mode": "AUTONOMOUS",
		"transport_ai_autonomous_active": true,
		"transport_ai_objective_pos": blocked_objective,
		"transport_ai_reassess_timer": 0.0
	}
	game.call("_transport_ai_reassess_inbound", unsafe_inbound, 1.3)
	_expect(String(unsafe_inbound.get("transport_state", "")) == "returning", "When all landing sites are unsafe, an autonomous transport should abort insertion and return to a friendly airfield")
	_expect(Vector2(unsafe_inbound.get("transport_return_pos", Vector2.ZERO)).distance_to(Vector2(1040.0, 540.0)) < 1.0, "Emergency recovery should select the nearest valid friendly airfield")
	_expect(Array(unsafe_inbound.get("transport_cargo", [])).size() == 1, "Aborting an unsafe insertion must preserve every passenger")

	# Without a friendly airfield, hold safely with cargo instead of continuing toward a rejected site.
	game.get("buildings").clear()
	unsafe_inbound["transport_state"] = "inbound"
	unsafe_inbound["transport_target_pos"] = blocked_candidates[0].pos
	unsafe_inbound["transport_ai_reassess_timer"] = 0.0
	game.call("_transport_ai_reassess_inbound", unsafe_inbound, 1.3)
	_expect(String(unsafe_inbound.get("transport_state", "")) == "loaded", "With no safe landing or recovery airfield, the transport should hold rather than force insertion")
	_expect(not bool(unsafe_inbound.get("transport_ai_autonomous_active", true)), "A no-site hold should stop the autonomous flight loop")
	_expect(Array(unsafe_inbound.get("transport_cargo", [])).size() == 1, "A no-site hold must retain the complete passenger manifest")
	game.get("units").clear()

	# Autonomous passengers with no prior orders establish a defensive perimeter after touchdown.
	var fresh_passenger: Dictionary = {"kind": "infantry", "team": "player", "pos": Vector2(700.0, 400.0)}
	var autonomous_transport: Dictionary = {"transport_ai_mode": "AUTONOMOUS", "transport_ai_post_drop_doctrine": "DEFEND"}
	var doctrine_applied: bool = game.call("_transport_ai_apply_post_drop_doctrine", fresh_passenger, autonomous_transport, Vector2(720.0, 420.0))
	_expect(doctrine_applied and bool(fresh_passenger.get("guard_active", false)), "Unassigned autonomous passengers should receive the defensive landing doctrine")
	_expect(Vector2(fresh_passenger.get("guard_position", Vector2.ZERO)).distance_to(Vector2(720.0, 420.0)) < 1.0, "Defensive doctrine should anchor to the landing zone")
	_expect(is_equal_approx(float(fresh_passenger.get("guard_radius", 0.0)), 155.0), "Defensive doctrine should use the infantry guard radius")

	var ordered_passenger: Dictionary = {"kind": "infantry", "team": "player", "target": Vector2(950.0, 420.0)}
	var preserved_order: bool = game.call("_transport_ai_apply_post_drop_doctrine", ordered_passenger, autonomous_transport, Vector2(720.0, 420.0))
	_expect(not preserved_order and ordered_passenger.has("target") and not ordered_passenger.has("guard_active"), "A pre-existing player movement order must never be replaced by post-drop doctrine")

	var attack_move_passenger: Dictionary = {"kind": "infantry", "team": "player"}
	var attack_move_transport: Dictionary = {
		"transport_ai_mode": "AUTONOMOUS",
		"transport_ai_post_drop_doctrine": "ATTACK_MOVE",
		"transport_ai_objective_pos": Vector2(980.0, 360.0)
	}
	var attack_move_applied: bool = game.call("_transport_ai_apply_post_drop_doctrine", attack_move_passenger, attack_move_transport, Vector2(720.0, 420.0))
	_expect(attack_move_applied and bool(attack_move_passenger.get("attack_move_active", false)), "ATTACK_MOVE doctrine should activate the existing attack-move combat behavior")
	_expect(Vector2(attack_move_passenger.get("target", Vector2.ZERO)).distance_to(Vector2(980.0, 360.0)) < 1.0, "ATTACK_MOVE doctrine should direct infantry toward the saved sortie objective")

	var no_objective_passenger: Dictionary = {"kind": "infantry", "team": "player"}
	var no_objective_transport: Dictionary = {"transport_ai_mode": "AUTONOMOUS", "transport_ai_post_drop_doctrine": "ATTACK_MOVE"}
	var no_objective_result: bool = game.call("_transport_ai_apply_post_drop_doctrine", no_objective_passenger, no_objective_transport, Vector2(720.0, 420.0))
	_expect(not no_objective_result and not no_objective_passenger.has("attack_move_active"), "ATTACK_MOVE must safely decline when no mission objective was saved")

	var manual_passenger: Dictionary = {"kind": "infantry", "team": "player"}
	var manual_transport: Dictionary = {"transport_ai_mode": "MANUAL"}
	var manual_doctrine: bool = game.call("_transport_ai_apply_post_drop_doctrine", manual_passenger, manual_transport, Vector2(720.0, 420.0))
	_expect(not manual_doctrine and not manual_passenger.has("guard_active"), "Manual transport mode must not apply autonomous post-drop doctrine")

	# The selected-transport panel must configure only safe, player-owned transports.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "transport_state": "loaded", "transport_cargo": [{"kind": "infantry"}]})
	game.get("selected").append(0)
	_expect(bool(game.call("_has_selected_transport")), "Selecting a transport should expose its tactical control panel")
	_expect(int(game.call("_set_selected_transport_mode", "AUTONOMOUS")) == 1, "A loaded selected transport should accept AUTONOMOUS mode")
	_expect(String(game.get("units")[0].get("transport_ai_mode", "")) == "AUTONOMOUS", "Transport mode selection should persist on the aircraft")
	_expect(int(game.call("_set_selected_transport_doctrine", "ATTACK_MOVE")) == 1, "A loaded selected transport should accept ATTACK_MOVE doctrine")
	_expect(String(game.get("units")[0].get("transport_ai_post_drop_doctrine", "")) == "ATTACK_MOVE", "Post-drop doctrine selection should persist on the aircraft")
	game.get("units")[0]["transport_state"] = "inbound"
	_expect(int(game.call("_set_selected_transport_mode", "MANUAL")) == 0, "Control mode changes must be locked while the transport is inbound")
	_expect(int(game.call("_set_selected_transport_doctrine", "DEFEND")) == 0, "Doctrine changes must be locked while the transport is inbound")
	_expect(game.call("_transport_ai_mode_rect", Vector2(400.0, 800.0)) is Rect2, "The transport mode control should provide a valid touch target")
	_expect(game.call("_transport_ai_doctrine_rect", Vector2(400.0, 800.0)) is Rect2, "The post-drop doctrine control should provide a valid touch target")
	game.get("selected").clear()
	game.get("units").clear()

	# A selected transport can be recalled to a selected field squad using the tactical landing planner.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(220.0, 220.0), "transport_state": "idle", "transport_cargo": []})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(620.0, 420.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 55, "pos": Vector2(650.0, 440.0)})
	game.get("selected").append_array([0, 1, 2])
	game.call("_order_transport_pickup")
	_expect(String(game.get("units")[0].get("transport_state", "")) == "inbound", "A valid pickup request should dispatch the transport toward the squad")
	_expect(game.get("units")[0].has("transport_target_pos"), "A pickup request should store a safe planned landing point")
	_expect(game.get("units")[0].has("transport_ai_route_points"), "A pickup request should assign an AI flight route")
	game.get("units").clear()
	game.get("selected").clear()

	# A recalled empty transport must remain at the pickup site instead of becoming idle.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(400.0, 300.0), "transport_state": "descending", "transport_cargo": [], "transport_pickup_waiting": true})
	game.call("_update_transport_helicopter", game.get("units")[0], 0.1)
	_expect(String(game.get("units")[0].get("transport_state", "")) == "pickup_waiting", "An empty recalled transport should hold at the squad pickup site")

	# Infantry can board a transport that is waiting at its pickup rendezvous.
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 65, "pos": Vector2(430.0, 300.0), "target": Vector2(430.0, 300.0), "transport_pickup_rendezvous": true})
	game.get("selected").append_array([0, 1])
	game.call("_load_selected_infantry_into_transport")
	_expect(String(game.get("units")[0].get("transport_state", "")) == "loaded", "Boarding a waiting pickup transport should transition it to loaded")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).size() == 1, "The field squad should board the waiting pickup transport")
	var waiting_cargo: Array = game.get("units")[0].get("transport_cargo", [])
	_expect(not waiting_cargo[0].has("target") and not waiting_cargo[0].has("transport_pickup_rendezvous"), "Temporary pickup movement must not be replayed after redeployment")
	_expect(not game.get("units")[0].has("transport_pickup_waiting"), "Successful boarding should clear the pickup wait marker")
	game.get("units").clear()
	game.get("selected").clear()

	# Boarding requires a landed aircraft and infantry within the physical pickup radius.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 300.0), "transport_state": "loaded", "transport_cargo": []})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(340.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(520.0, 300.0)})
	game.get("selected").append_array([0, 1, 2])
	game.call("_load_selected_infantry_into_transport")
	var boarded_transport: Dictionary = game.get("units")[0]
	_expect(Array(boarded_transport.get("transport_cargo", [])).size() == 1, "Only nearby selected infantry should board the landed transport")
	_expect(game.get("units").size() == 2, "Infantry outside the pickup radius must remain on the battlefield")
	_expect(String(game.get("units")[1].get("kind", "")) == "infantry", "The distant infantry should remain a live field unit")

	# Distant selected infantry receive rendezvous movement orders and remain on the field.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 300.0), "transport_state": "loaded", "transport_cargo": []})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(520.0, 300.0)})
	game.get("selected").append_array([0, 1])
	game.call("_load_selected_infantry_into_transport")
	_expect(game.get("units").size() == 2, "Rendezvous orders must not remove infantry before they reach the transport")
	_expect(game.get("units")[1].has("target"), "Distant infantry should receive a movement target near the transport")
	_expect(Vector2(game.get("units")[1].get("target", Vector2.ZERO)).distance_to(Vector2(300.0, 300.0)) <= 76.0, "The rendezvous target should lie inside the boarding radius")

	# Rescue triage orders casualties by health, then pickup distance for equal-health soldiers.
	game.get("units").clear()
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(390.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(315.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 25, "pos": Vector2(500.0, 300.0)})
	var triage_indices: Array[int] = [0, 1, 2]
	var triage_order: Array[int] = game.call("_transport_ai_sort_rescue_infantry", triage_indices, Vector2(300.0, 300.0))
	_expect(triage_order == [2, 1, 0], "Rescue triage should prioritize the most wounded first, then the nearest casualty at equal health")
	game.get("units").clear()

	# Wounded infantry board first when capacity is limited.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 300.0), "transport_state": "loaded", "transport_cargo": []})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(320.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 25, "pos": Vector2(340.0, 300.0)})
	game.get("selected").append_array([0, 1, 2])
	game.call("_load_selected_infantry_into_transport")
	var rescue_cargo: Array = game.get("units")[0].get("transport_cargo", [])
	_expect(rescue_cargo.size() == 2 and int(rescue_cargo[0].get("hp", 100)) == 25, "The most wounded selected infantry should board first")

	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 300.0), "transport_state": "inbound", "transport_cargo": []})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(320.0, 300.0)})
	game.get("selected").append_array([0, 1])
	game.call("_load_selected_infantry_into_transport")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).is_empty(), "An airborne transport must not accept new passengers")
	_expect(game.get("units").size() == 2, "Rejected boarding must not remove infantry from the battlefield")
	game.get("units").clear()
	game.get("selected").clear()

	# Returning with a loaded transport must target a completed friendly airfield and retain its passengers.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 300.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 80}]})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(700.0, 300.0)})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 0.5, "pos": Vector2(310.0, 300.0)})
	game.get("buildings").append({"kind": "airfield", "hp": 0, "build_progress": 1.0, "pos": Vector2(340.0, 300.0)})
	game.get("enemy_buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(320.0, 300.0)})
	game.get("selected").append(0)
	game.call("_order_transport_return_to_base")
	var returning_transport: Dictionary = game.get("units")[0]
	_expect(String(returning_transport.get("transport_state", "")) == "returning", "A loaded transport should accept a return-to-base order")
	_expect(Vector2(returning_transport.get("transport_return_pos", Vector2.ZERO)).distance_to(Vector2(700.0, 300.0)) < 1.0, "Return-to-base must select a friendly completed airfield, never an enemy airfield")
	_expect(Array(returning_transport.get("transport_cargo", [])).size() == 1, "Return-to-base must preserve all passengers")
	_expect(returning_transport.has("transport_ai_route_points"), "Return-to-base should assign the existing threat-aware flight route")

	# A group return assigns every selected loaded transport its own nearest friendly airfield.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(200.0, 300.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 80}]})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(900.0, 300.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 75}]})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(100.0, 300.0)})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(1000.0, 300.0)})
	game.get("selected").append_array([0, 1])
	game.call("_order_transport_return_to_base")
	_expect(String(game.get("units")[0].get("transport_state", "")) == "returning" and String(game.get("units")[1].get("transport_state", "")) == "returning", "A group return order should dispatch every selected transport")
	_expect(Vector2(game.get("units")[0].get("transport_return_pos", Vector2.ZERO)).distance_to(Vector2(100.0, 300.0)) < 1.0, "The first transport should choose its nearest friendly airfield")
	_expect(Vector2(game.get("units")[1].get("transport_return_pos", Vector2.ZERO)).distance_to(Vector2(1000.0, 300.0)) < 1.0, "The second transport should choose its own nearest friendly airfield")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).size() == 1 and Array(game.get("units")[1].get("transport_cargo", [])).size() == 1, "Group return must preserve every transport cargo manifest")
	_expect(game.get("units")[0].has("transport_ai_route_points") and game.get("units")[1].has("transport_ai_route_points"), "Every aircraft in the group should receive a threat-aware route")

	# Group validation is atomic: an empty aircraft must not dispatch the other selected transport.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(200.0, 300.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 80}]})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(900.0, 300.0), "transport_state": "idle", "transport_cargo": []})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(100.0, 300.0)})
	game.get("selected").append_array([0, 1])
	game.call("_order_transport_return_to_base")
	_expect(String(game.get("units")[0].get("transport_state", "")) == "loaded", "A failed group validation must not partially dispatch the first aircraft")
	_expect(String(game.get("units")[1].get("transport_state", "")) == "idle", "A failed group validation must leave the invalid aircraft unchanged")
	game.get("units").clear()

	# If the selected recovery airfield is destroyed or loses power in flight, replan to another valid friendly field.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 300.0), "transport_state": "returning", "transport_return_pos": Vector2(700.0, 300.0), "transport_cargo": [{"kind": "infantry", "hp": 80}], "transport_ai_autonomous_active": true})
	game.get("buildings").append({"kind": "airfield", "hp": 0, "build_progress": 1.0, "pos": Vector2(700.0, 300.0)})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(900.0, 300.0)})
	game.call("_update_transport_helicopter", game.get("units")[0], 0.01)
	var replanned_transport: Dictionary = game.get("units")[0]
	_expect(String(replanned_transport.get("transport_state", "")) == "returning", "A returning transport should remain in recovery after its destination is lost")
	_expect(Vector2(replanned_transport.get("transport_return_pos", Vector2.ZERO)).distance_to(Vector2(900.0, 300.0)) < 1.0, "A returning transport should replan to the next powered friendly airfield")
	_expect(Array(replanned_transport.get("transport_cargo", [])).size() == 1, "Airfield loss must never discard the transport's passengers")

	# Arrival at a valid airfield enters a short service cycle before the transport can be reused.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 80, "pos": Vector2(700.0, 300.0), "transport_state": "returning", "transport_return_pos": Vector2(700.0, 300.0), "transport_cargo": [{"kind": "infantry", "hp": 80}], "transport_ai_autonomous_active": true})
	game.get("buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(700.0, 300.0)})
	game.call("_update_transport_helicopter", game.get("units")[0], 0.1)
	_expect(String(game.get("units")[0].get("transport_state", "")) == "rearming", "A returning transport should enter airfield servicing on arrival")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).size() == 1, "Airfield servicing must preserve the passenger manifest")
	game.call("_update_transport_helicopter", game.get("units")[0], 5.1)
	_expect(String(game.get("units")[0].get("transport_state", "")) == "loaded", "A serviced transport with cargo should become ready for its next mission")
	_expect(int(game.get("units")[0].get("hp", 0)) == int(game.call("_unit_repair_max_hp", game.get("units")[0])), "Airfield servicing should restore transport health")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).size() == 1, "Rearming must not unload passengers automatically")

	# Losing the airfield during service must abort safely and retain cargo.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 80, "pos": Vector2(700.0, 300.0), "transport_state": "rearming", "transport_return_pos": Vector2(700.0, 300.0), "transport_cargo": [{"kind": "infantry", "hp": 80}]})
	game.call("_update_transport_helicopter", game.get("units")[0], 0.1)
	_expect(String(game.get("units")[0].get("transport_state", "")) == "loaded", "A transport must leave service safely if its airfield becomes unavailable")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).size() == 1, "Aborted airfield service must preserve all passengers")

	# Equal-health casualties in a more dangerous local pocket are evacuated before safer casualties.
	game.get("units").clear()
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(500.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(650.0, 300.0)})
	game.get("units").append({"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(520.0, 300.0)})
	var threat_priority_indices: Array[int] = [0, 1]
	var threat_sorted: Array = game.call("_transport_ai_sort_rescue_infantry", threat_priority_indices, Vector2(500.0, 300.0))
	_expect(int(threat_sorted[0]) == 0, "Equal-health casualties under heavier local threat should board before safer casualties")
	_expect(float(game.call("_transport_ai_rescue_threat_pressure", Vector2(500.0, 300.0))) > float(game.call("_transport_ai_rescue_threat_pressure", Vector2(900.0, 300.0))), "Rescue threat pressure should decrease outside hostile proximity")
	game.get("units").clear()

	# When health and hostile pressure are equal, isolated casualties outrank soldiers with nearby friendly support.
	game.get("units").clear()
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(500.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(700.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(720.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "infantry", "hp": 100, "pos": Vector2(740.0, 300.0)})
	var isolation_priority_indices: Array[int] = [0, 1]
	var isolation_sorted: Array = game.call("_transport_ai_sort_rescue_infantry", isolation_priority_indices, Vector2(600.0, 300.0))
	_expect(int(isolation_sorted[0]) == 0, "An isolated casualty should be prioritized over an equally wounded soldier with nearby friendly support")
	_expect(float(game.call("_transport_ai_rescue_isolation_score", Vector2(500.0, 300.0))) > float(game.call("_transport_ai_rescue_isolation_score", Vector2(720.0, 300.0))), "Isolation score should be higher when no friendly infantry are nearby")
	game.get("units").clear()

	# Air units can be explicitly assigned to escort a friendly transport via the 3D command bridge.
	game.get("units").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "fighter", "hp": 120, "pos": Vector2(360.0, 280.0), "3d_sync_id": 41, "aircraft_ammo": 8})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(500.0, 300.0), "3d_sync_id": 52, "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 80}]})
	game.call("_on_3d_gameplay_order_issued", "player|41|fighter", "escort", Vector3.ZERO, "player|52|transport_helicopter")
	var assigned_air_escort: Dictionary = game.get("units")[0]
	_expect(bool(assigned_air_escort.get("escort_active", false)), "A fighter should accept an explicit transport escort order")
	_expect(int(assigned_air_escort.get("escort_target_id", -1)) == 52, "An air escort should track the transport by its stable 3D sync ID")
	_expect(not assigned_air_escort.has("target") and not assigned_air_escort.has("attack_target"), "Assigning escort duty should replace stale movement and attack orders")
	game.get("units").append({"team": "player", "kind": "helicopter", "hp": 120, "pos": Vector2(390.0, 260.0), "3d_sync_id": 42, "aircraft_ammo": 12})
	game.call("_on_3d_gameplay_order_issued", "player|42|helicopter", "escort", Vector3.ZERO, "player|52|transport_helicopter")
	_expect(int(game.get("units")[0].get("escort_formation_slot", -1)) == 0 and int(game.get("units")[2].get("escort_formation_slot", -1)) == 1, "Manual escort orders should allocate distinct formation slots around one transport")
	_expect(Vector2(game.get("units")[0].get("escort_offset", Vector2.ZERO)) != Vector2(game.get("units")[2].get("escort_offset", Vector2.ZERO)), "Manually assigned escorts should not overlap formation positions")
	_expect(int(game.get("units")[0].get("escort_formation_size", 0)) == 2 and int(game.get("units")[2].get("escort_formation_size", 0)) == 2, "Manual escort assignment should update formation size for every escort")
	# An invalid or destroyed escort target must not be accepted.
	game.get("units")[0].erase("escort_active")
	game.get("units")[1]["hp"] = 0
	game.call("_on_3d_gameplay_order_issued", "player|41|fighter", "escort", Vector3.ZERO, "player|52|transport_helicopter")
	_expect(not game.get("units")[0].has("escort_active"), "An air escort must reject a destroyed transport")
	# If a protected transport is destroyed, its surviving escorts transfer to the nearest available transport and take a free slot.
	game.get("units").clear()
	game.get("units").append({"team": "player", "kind": "fighter", "hp": 120, "pos": Vector2(480.0, 300.0), "3d_sync_id": 71, "escort_active": true, "escort_target_id": 52, "escort_target_kind": "transport_helicopter", "escort_auto_target": true, "attack_target": 8})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 0, "pos": Vector2(500.0, 300.0), "3d_sync_id": 52})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(540.0, 300.0), "3d_sync_id": 64, "transport_state": "loaded"})
	game.get("units").append({"team": "player", "kind": "helicopter", "hp": 120, "pos": Vector2(530.0, 280.0), "3d_sync_id": 72, "escort_active": true, "escort_target_id": 64, "escort_target_kind": "transport_helicopter", "escort_formation_slot": 0, "escort_formation_size": 1})
	var reassigned_escort: bool = game.call("_transport_ai_reassign_air_escort", 0)
	_expect(reassigned_escort, "A surviving escort should transfer to another living friendly transport")
	_expect(int(game.get("units")[0].get("escort_target_id", -1)) == 64 and int(game.get("units")[0].get("escort_formation_slot", -1)) == 1, "A reassigned escort should join the nearest transport in its next free formation slot")
	_expect(not game.get("units")[0].has("attack_target") and not game.get("units")[0].has("escort_auto_target"), "Reassignment should clear stale automatic combat targets from the lost transport")
	_expect(int(game.get("units")[0].get("escort_formation_size", 0)) == 2 and int(game.get("units")[3].get("escort_formation_size", 0)) == 2, "The replacement transport formation should update all escort members")
	# Dead or detached escorts must not leave holes in a surviving transport's formation.
	game.get("units").clear()
	game.get("units").append({"team": "player", "kind": "fighter", "hp": 0, "escort_active": true, "escort_target_id": 88, "escort_formation_slot": 0})
	game.get("units").append({"team": "player", "kind": "helicopter", "hp": 120, "escort_active": true, "escort_target_id": 88, "escort_formation_slot": 2, "escort_formation_size": 3, "escort_offset": Vector2(999.0, 999.0)})
	game.call("_transport_ai_sync_escort_formation", 88)
	_expect(int(game.get("units")[1].get("escort_formation_slot", -1)) == 0, "Surviving escorts should compact into the first available formation slot")
	_expect(int(game.get("units")[1].get("escort_formation_size", 0)) == 1, "Compacted formation size should exclude destroyed escorts")
	_expect(Vector2(game.get("units")[1].get("escort_offset", Vector2.ZERO)) == game.call("_transport_ai_escort_formation_offset", 0), "Compaction should restore the deterministic slot offset")
	var staging_transport := {"pos": Vector2(500.0, 300.0), "transport_state": "inbound", "transport_target_pos": Vector2(760.0, 300.0)}
	_expect(Vector2(game.call("_transport_ai_escort_anchor_position", staging_transport)) == Vector2(760.0, 300.0), "Escorts should stage at the assigned drop zone during the final approach")
	staging_transport["pos"] = Vector2(300.0, 300.0)
	_expect(Vector2(game.call("_transport_ai_escort_anchor_position", staging_transport)) == Vector2(300.0, 300.0), "Escorts should stay with the transport before the final approach staging window")
	staging_transport["transport_state"] = "loaded"
	staging_transport["pos"] = Vector2(500.0, 300.0)
	_expect(Vector2(game.call("_transport_ai_escort_anchor_position", staging_transport)) == Vector2(500.0, 300.0), "Escorts should return to the transport after landing or when it is not inbound")
	staging_transport["transport_state"] = "returning"
	staging_transport["pos"] = Vector2(620.0, 300.0)
	staging_transport["transport_post_drop_guard_pos"] = Vector2(500.0, 300.0)
	_expect(Vector2(game.call("_transport_ai_escort_anchor_position", staging_transport)) == Vector2(500.0, 300.0), "Escorts should hold the insertion zone while the transport starts extracting")
	staging_transport["pos"] = Vector2(900.0, 300.0)
	_expect(Vector2(game.call("_transport_ai_escort_anchor_position", staging_transport)) == Vector2(900.0, 300.0), "Escorts should rejoin the transport after it clears the insertion zone")
	_expect(not staging_transport.has("transport_post_drop_guard_pos"), "The temporary insertion-zone guard anchor should clear after extraction")
	var escort_base_speed: float = game.call("_transport_ai_escort_catchup_speed", "fighter", 18.0)
	var escort_far_speed: float = game.call("_transport_ai_escort_catchup_speed", "fighter", 420.0)
	var escort_helicopter_speed: float = game.call("_transport_ai_escort_catchup_speed", "helicopter", 420.0)
	_expect(escort_far_speed > escort_base_speed, "An escort far from its moving formation slot should accelerate to catch up")
	_expect(escort_far_speed <= escort_base_speed * 1.4, "Escort catch-up acceleration must remain capped for balance")
	_expect(escort_helicopter_speed > 78.0 and escort_helicopter_speed <= 78.0 * 1.4, "Gunship catch-up speed should scale independently within the same cap")
	_expect(not bool(game.call("_transport_ai_escort_should_release_target", Vector2(650.0, 300.0), Vector2(500.0, 300.0), Vector2(620.0, 300.0))), "Escorts should retain targets while both remain inside the transport defense bubble")
	_expect(bool(game.call("_transport_ai_escort_should_release_target", Vector2(770.0, 300.0), Vector2(500.0, 300.0), Vector2(620.0, 300.0))), "Escorts should abandon automatic pursuit when they drift beyond 260 units from their transport")
	_expect(bool(game.call("_transport_ai_escort_should_release_target", Vector2(600.0, 300.0), Vector2(500.0, 300.0), Vector2(730.0, 300.0))), "Escorts should release enemies that leave the 220-unit protected radius")
	# Escorts assigned to one transport should distribute automatic targets instead of dogpiling.
	game.get("units").clear()
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(510.0, 300.0)})
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(550.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "fighter", "hp": 120, "pos": Vector2(505.0, 300.0), "escort_active": true, "escort_target_id": 77, "escort_auto_target": true, "attack_target": 0})
	_expect(int(game.call("_transport_ai_select_group_escort_threat", 77, Vector2(500.0, 300.0), "fighter", 220.0)) == 1, "A second escort should choose an unclaimed enemy near the same transport")
	_expect(int(game.call("_transport_ai_select_group_escort_threat", 88, Vector2(500.0, 300.0), "fighter", 220.0)) == 0, "Escorts protecting another transport should not reserve this group's target")
	_expect(int(game.call("_transport_ai_select_emergency_escort_threat", 77, 2, Vector2(500.0, 300.0), 150.0)) == 1, "Emergency defense should select the nearest unclaimed attacker near the transport")
	_expect(int(game.call("_transport_ai_select_emergency_escort_threat", 88, 2, Vector2(500.0, 300.0), 150.0)) == 0, "Emergency target reservations should remain isolated between transports")
	game.get("units").clear()
	# Escort target priorities are role-specific, not simply nearest-enemy selection.
	game.get("units").clear()
	game.get("units").append({"team": "enemy", "kind": "helicopter", "hp": 100, "pos": Vector2(510.0, 300.0)})
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(650.0, 300.0)})
	game.get("units").append({"team": "enemy", "kind": "infantry", "hp": 100, "pos": Vector2(505.0, 300.0)})
	game.get("units").append({"team": "enemy", "kind": "tank", "hp": 100, "pos": Vector2(620.0, 300.0)})
	_expect(int(game.call("_transport_ai_select_escort_threat", Vector2(500.0, 300.0), "fighter", 220.0)) == 1, "Fighters should prioritize enemy fighters over closer helicopters")
	_expect(int(game.call("_transport_ai_select_escort_threat", Vector2(500.0, 300.0), "helicopter", 220.0)) == 3, "Gunships should prioritize enemy tanks over closer infantry")
	game.get("units").clear()

	# With no valid friendly airfield, reject the order without changing aircraft state or cargo.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("selected").clear()
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(300.0, 300.0), "transport_state": "loaded", "transport_cargo": [{"kind": "infantry", "hp": 80}]})
	game.get("enemy_buildings").append({"kind": "airfield", "hp": 500, "build_progress": 1.0, "pos": Vector2(320.0, 300.0)})
	game.get("selected").append(0)
	game.call("_order_transport_return_to_base")
	_expect(String(game.get("units")[0].get("transport_state", "")) == "loaded", "No friendly airfield should leave the loaded transport safely in place")
	_expect(Array(game.get("units")[0].get("transport_cargo", [])).size() == 1, "A rejected return order must not lose passengers")
	game.get("units").clear()
	game.get("selected").clear()

	# Escort distribution should favor a transport under nearby air threat before distance/load balancing ties.
	game.get("units").clear()
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(500.0, 300.0)})
	var threatened_transport: Dictionary = {"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(500.0, 300.0), "transport_state": "inbound", "transport_target_pos": Vector2(500.0, 300.0)}
	var safe_transport: Dictionary = {"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(800.0, 300.0), "transport_state": "inbound", "transport_target_pos": Vector2(800.0, 300.0)}
	_expect(float(game.call("_transport_ai_transport_threat_score", threatened_transport)) > float(game.call("_transport_ai_transport_threat_score", safe_transport)), "A transport inside an enemy fighter threat envelope should receive a higher escort priority")
	var damaged_loaded_transport: Dictionary = {"team": "player", "kind": "transport_helicopter", "hp": 80, "pos": Vector2(900.0, 500.0), "transport_state": "inbound", "transport_cargo": [{}, {}, {}, {}]}
	var healthy_empty_transport: Dictionary = {"team": "player", "kind": "transport_helicopter", "hp": 250, "pos": Vector2(900.0, 500.0), "transport_state": "idle", "transport_cargo": []}
	_expect(float(game.call("_transport_ai_transport_threat_score", damaged_loaded_transport)) > float(game.call("_transport_ai_transport_threat_score", healthy_empty_transport)), "Escort priority should favor a damaged transport carrying passengers on an active mission")
	game.get("units").clear()
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(500.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(500.0, 300.0), "3d_sync_id": 81, "transport_state": "inbound"})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(800.0, 300.0), "3d_sync_id": 82, "transport_state": "inbound"})
	game.get("units").append({"team": "player", "kind": "fighter", "hp": 120, "pos": Vector2(650.0, 300.0), "3d_sync_id": 83})
	game.get("selected").clear()
	game.get("selected").append(2)
	var priority_transport_indices: Array[int] = [0, 1]
	var priority_assigned := int(game.call("_transport_ai_assign_selected_air_escorts", priority_transport_indices))
	_expect(priority_assigned == 1 and int(game.get("units")[2].get("escort_target_id", -1)) == 81, "The selected escort should protect the more threatened transport when travel distance is comparable")
	# A live escort should transfer only when another transport is materially more threatened.
	game.get("units").clear()
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(500.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(500.0, 300.0), "3d_sync_id": 91, "transport_state": "inbound"})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(850.0, 300.0), "3d_sync_id": 92, "transport_state": "inbound"})
	game.get("units").append({"team": "player", "kind": "fighter", "hp": 120, "pos": Vector2(510.0, 300.0), "3d_sync_id": 93, "escort_active": true, "escort_target_id": 92, "escort_target_kind": "transport_helicopter"})
	_expect(bool(game.call("_transport_ai_reassign_air_escort", 3)), "An escort should dynamically transfer to a nearby transport under materially greater threat")
	_expect(int(game.get("units")[3].get("escort_target_id", -1)) == 91, "Dynamic rebalancing should select the threatened transport")
	game.get("units").clear()
	game.get("units").append({"team": "enemy", "kind": "fighter", "hp": 100, "pos": Vector2(500.0, 300.0)})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(500.0, 300.0), "3d_sync_id": 94, "transport_state": "inbound"})
	game.get("units").append({"team": "player", "kind": "transport_helicopter", "hp": 200, "pos": Vector2(850.0, 300.0), "3d_sync_id": 95, "transport_state": "inbound"})
	game.get("units").append({"team": "player", "kind": "fighter", "hp": 120, "pos": Vector2(510.0, 300.0), "3d_sync_id": 96, "escort_active": true, "escort_target_id": 95, "escort_target_kind": "transport_helicopter", "attack_target": 0})
	_expect(not bool(game.call("_transport_ai_reassign_air_escort", 3)), "Automatic rebalancing must not override a player-issued attack target")
	_expect(int(game.get("units")[3].get("escort_target_id", -1)) == 95, "A player-issued order must retain its existing escort assignment")
	game.get("units").clear()
	game.get("selected").clear()

	game.get("units").clear()
	game.get("selected").clear()

	print("Transport AI landing-site regression passed")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
