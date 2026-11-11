extends SceneTree

var failure_count := 0


func _initialize() -> void:
	call_deferred("_run_battle_save_integration_test")


func _run_battle_save_integration_test() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	# Stable IDs must be reserved before assigning IDs to earlier unassigned records.
	game.set("next_unit_identity", 1)
	game.get("units").assign([
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(100.0, 100.0)},
		{"unit_id": "unit_00000001", "kind": "infantry", "team": "player", "hp": 60, "pos": Vector2(130.0, 100.0)}
	])
	game.call("_ensure_stable_unit_identities")
	_expect(String(game.get("units")[0].get("unit_id", "")) == "unit_00000002", "Unassigned earlier spawn must not steal a later unit's reserved stable ID")
	_expect(String(game.get("units")[1].get("unit_id", "")) == "unit_00000001", "Existing stable unit ID must remain unchanged")
	game.get("units").remove_at(0)
	game.call("_ensure_stable_unit_identities")
	_expect(String(game.get("units")[0].get("unit_id", "")) == "unit_00000001", "Stable identity must survive unit-array compaction")
	game.get("units").clear()

	# Strategic supply points remain neutral while contested and change hands when uncontested.
	game.get("supply_points").assign([{
		"pos": Vector2(400.0, 300.0),
		"owner": "neutral",
		"kind": "supply",
		"payout": 0.0,
		"supply_payout": 0.0
	}])
	game.get("units").assign([
		{"kind": "infantry", "team": "player", "hp": 60, "pos": Vector2(405.0, 300.0)},
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(395.0, 300.0)}
	])
	game.set("credits", 0)
	game.set("enemy_credits", 0)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "neutral", "A contested neutral supply point must not change hands")
	game.get("units").remove_at(1)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "player", "An uncontested player unit must capture a neutral supply point")
	_expect(int(game.get("credits")) >= 4, "A player-controlled supply point must generate its income")
	game.get("units").clear()
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(400.0, 300.0)})
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "enemy", "An uncontested enemy unit must recapture a player supply point")
	_expect(int(game.get("enemy_credits")) >= 4, "An enemy-controlled supply point must generate enemy income")
	# The nearest enemy defender must be able to reinforce a threatened friendly supply point.
	game.get("units").assign([
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(375.0, 300.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(430.0, 300.0)}
	])
	var reinforcement_handled: bool = game.call("_update_enemy_supply_reinforcement", game.get("units")[0], 0, 0.1)
	_expect(reinforcement_handled, "An eligible enemy defender must respond to a threatened enemy-held supply point")
	_expect(bool(game.get("units")[0].get("supply_reinforcement_active", false)), "The dispatched defender must retain its supply reinforcement assignment")
	# Nearby mobile defenders must not mutually suppress the nearest reinforcement.
	game.get("units").assign([
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(350.0, 300.0)},
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(380.0, 300.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(430.0, 300.0)}
	])
	var farther_guard_handled: bool = game.call("_update_enemy_supply_reinforcement", game.get("units")[0], 0, 0.1)
	var nearest_guard_handled: bool = game.call("_update_enemy_supply_reinforcement", game.get("units")[1], 1, 0.1)
	_expect(not farther_guard_handled, "A farther defender must not duplicate the nearest defender's reinforcement assignment")
	_expect(nearest_guard_handled, "The nearest defender must reinforce even when another mobile defender is nearby")
	game.get("units").clear()
	game.get("supply_points").clear()
	# Defense director keeps a compact base reserve and protects a high-value forward installation.
	game.set("enemy_base", Vector2(700.0, 300.0))
	game.get("enemy_buildings").assign([
		{"kind": "missile_silo", "hp": 500, "build_progress": 1.0, "pos": Vector2(500.0, 300.0)},
		{"kind": "factory", "hp": 400, "build_progress": 1.0, "pos": Vector2(600.0, 300.0)}
	])
	var defense_units: Array = []
	for guard_index in range(8):
		defense_units.append({"kind": "infantry" if guard_index < 5 else "tank", "team": "enemy", "hp": 60 if guard_index < 5 else 150, "pos": Vector2(660.0 + float(guard_index % 3) * 12.0, 280.0 + float(guard_index) * 5.0)})
	game.get("units").assign(defense_units)
	game.call("_update_enemy_defense_assignments")
	var assigned_guard_count := 0
	var protects_base := false
	var protects_silo := false
	for defense_unit in game.get("units"):
		if not bool(defense_unit.get("defense_guard", false)):
			continue
		assigned_guard_count += 1
		var guard_anchor: Vector2 = defense_unit.get("defense_anchor", Vector2.ZERO)
		protects_base = protects_base or guard_anchor.distance_to(game.get("enemy_base")) < 100.0
		protects_silo = protects_silo or guard_anchor.distance_to(Vector2(500.0, 300.0)) < 100.0
	_expect(assigned_guard_count == 2, "Eight enemy ground units must retain a compact two-unit defensive reserve")
	_expect(protects_base, "Enemy defense director must preserve a guard around the main base")
	_expect(protects_silo, "Enemy defense director must assign a guard to the high-value missile silo")
	# A forward guard must fall back to the main base when its assigned asset is destroyed.
	game.get("units").assign([{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(480.0, 300.0), "defense_guard": true, "defense_anchor": Vector2(500.0, 300.0)}])
	game.get("enemy_buildings").assign([{"kind": "missile_silo", "hp": 0, "build_progress": 1.0, "pos": Vector2(500.0, 300.0)}])
	game.call("_update_enemy_defense_guard", game.get("units")[0], 0, 0.1)
	_expect((game.get("units")[0].get("defense_anchor", Vector2.ZERO) as Vector2).distance_to(game.get("enemy_base")) < 1.0, "A guard must abandon a destroyed forward asset and return to base defense")
	# Base guards must not chase attackers beyond their local defensive perimeter.
	game.get("units").assign([
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(700.0, 300.0), "defense_guard": true, "defense_anchor": Vector2(700.0, 300.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(925.0, 300.0)}
	])
	game.get("enemy_buildings").clear()
	var outside_perimeter_hp := int(game.get("units")[1].get("hp", 0))
	game.call("_update_enemy_defense_guard", game.get("units")[0], 0, 1.0)
	_expect((game.get("units")[0].pos as Vector2).distance_to(Vector2(700.0, 300.0)) < 1.0, "A base guard must hold position when the attacker is outside its 210-unit perimeter")
	_expect(int(game.get("units")[1].get("hp", 0)) == outside_perimeter_hp, "A base guard must not attack an enemy outside its defensive perimeter")
	game.get("units")[1].pos = Vector2(890.0, 300.0)
	game.call("_update_enemy_defense_guard", game.get("units")[0], 0, 1.0)
	_expect(game.get("units")[0].pos.x > 700.0 and game.get("units")[0].pos.x <= 736.1, "A base guard must approach a threat inside its perimeter without abandoning its post")
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	# Counterattack reserve mobilization is capped at two units around a breached critical asset.
	game.set("enemy_base", Vector2(700.0, 300.0))
	game.get("enemy_buildings").assign([{"kind": "factory", "hp": 400, "build_progress": 1.0, "pos": Vector2(700.0, 300.0)}])
	game.get("units").assign([
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(650.0, 280.0)},
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(660.0, 320.0)},
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(680.0, 340.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(710.0, 300.0)}
	])
	var first_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[0], 0, 0.1)
	var second_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[1], 1, 0.1)
	var third_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[2], 2, 0.1)
	_expect(first_reserve_handled and second_reserve_handled, "The enemy must mobilize up to two counterattack reserves against a breach")
	_expect(not third_reserve_handled, "The enemy must not commit more than two counterattack reserves at once")
	_expect(bool(game.get("units")[0].get("counterattack_active", false)) and bool(game.get("units")[1].get("counterattack_active", false)), "Both committed counterattack units must retain their active assignments")
	# A reserve at its anchor must be released once the local breach is cleared.
	game.get("units").assign([{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(700.0, 300.0), "counterattack_active": true, "counterattack_anchor": Vector2(700.0, 300.0)}])
	var released_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[0], 0, 0.1)
	_expect(released_reserve_handled, "An active reserve must complete its local counterattack update")
	_expect(not bool(game.get("units")[0].get("counterattack_active", false)), "A reserve must be released after the breach is cleared and it returns to its anchor")
	game.get("units").clear()
	game.get("enemy_buildings").clear()

	game.set("faction", "وطن")
	game.set("map_type", "الساحل الجبلي")
	game.set("game_started", true)
	game.set("credits", 1840)
	game.set("supplies", 7)
	game.set("enemy_supplies", 4)
	game.set("enemy_credits", 920)
	game.set("enemy_missile_timer", 6.75)
	game.set("player_base_hp", 760)
	game.set("enemy_base_hp", 510)
	game.set("campaign_mission_index", 2)
	game.get("supply_points").append({"id": "supply_alpha", "owner": "player", "pos": Vector2(430.0, 300.0)})
	game.get("units").append({
		"unit_id": "unit_00000051",
		"kind": "transport_helicopter",
		"team": "player",
		"faction": "وطن",
		"hp": 155,
		"pos": Vector2(420.0, 210.0),
		"transport_state": "loaded",
		"transport_target_pos": Vector2(680.0, 260.0),
		"transport_landing_type": "rooftop",
		"transport_target_building_kind": "factory",
		"transport_drop_index": 1,
		"transport_drop_timer": 0.35,
		"transport_ai_last_site_id": "roof_factory_01",
		"transport_ai_route_points": [Vector2(520.0, 220.0), Vector2(610.0, 245.0), Vector2(680.0, 260.0)],
		"transport_ai_route_index": 1,
		"transport_ai_autonomous_active": true,
		"transport_ai_player_override": false,
		"transport_firing": true,
		"attack_focus_pos": Vector2(735.0, 270.0),
		"attack_target_pos": Vector2(742.0, 275.0),
		"transport_cargo": [{
			"unit_id": "unit_00000052",
			"kind": "infantry",
			"team": "player",
			"faction": "وطن",
			"hp": 47,
			"pos": Vector2(420.0, 210.0)
		}]
	})
	game.get("units").append({
		"unit_id": "unit_00000053", "kind": "infantry", "team": "player", "faction": "وطن",
		"hp": 60, "pos": Vector2(450.0, 220.0), "target": Vector2(720.0, 240.0)
	})
	game.get("units").append({
		"unit_id": "unit_00000054", "kind": "tank", "team": "player", "faction": "وطن",
		"hp": 150, "pos": Vector2(470.0, 230.0), "attack_target": 4
	})
	game.get("units").append({
		"unit_id": "unit_00000055", "kind": "artillery", "team": "player", "faction": "وطن",
		"hp": 120, "pos": Vector2(490.0, 240.0), "guard_active": true
	})
	game.get("units").append({
		"unit_id": "unit_00000056", "kind": "fighter", "team": "enemy",
		"hp": 180, "pos": Vector2(760.0, 250.0)
	})
	game.get("buildings").append({"kind": "airfield", "hp": 390, "pos": Vector2(650.0, 320.0), "production_id": 4})
	game.get("enemy_buildings").append({"kind": "factory", "hp": 240, "pos": Vector2(980.0, 320.0), "production_id": 9})
	game.get("production_orders").append({"producer_id": 4, "producer_pos": Vector2(650.0, 320.0), "producer_kind": "airfield", "kind": "fighter", "remaining": 8.5, "duration": 20.0})
	game.get("missiles").append({"team": "player", "pos": Vector2(200.0, 300.0), "target": Vector2(800.0, 300.0), "damage": 180})

	_expect(bool(game.call("_save_battle_snapshot")), "Active battle should save through the gameplay integration")
	game.set("credits", 1)
	game.set("player_base_hp", 1)
	game.set("enemy_missile_timer", 0.0)
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("production_orders").clear()
	game.get("missiles").clear()
	game.get("supply_points").clear()
	_expect(bool(game.call("_load_battle_snapshot")), "A valid saved battle should restore through the gameplay integration")
	_expect(String(game.get("faction")) == "وطن" and String(game.get("map_type")) == "الساحل الجبلي", "Faction and map should be restored")
	_expect(int(game.get("campaign_mission_index")) == 2 and bool(game.get("game_started")), "Active campaign mission identity and match state should survive save/restore")
	_expect(int(game.get("credits")) == 1840 and int(game.get("player_base_hp")) == 760, "Economy and base health should be restored")
	_expect(is_equal_approx(float(game.get("enemy_missile_timer")), 6.75), "Enemy missile attack cadence should be restored")
	_expect(game.get("supply_points").size() == 1 and String(game.get("supply_points")[0].get("owner", "")) == "player", "Supply ownership should be restored")
	_expect(game.get("units").size() == 5, "All field units must be restored with their original order indexes")
	if game.get("units").size() == 5:
		var transport: Dictionary = game.get("units")[0]
		var mover: Dictionary = game.get("units")[1]
		var attacker: Dictionary = game.get("units")[2]
		var guard: Dictionary = game.get("units")[3]
		_expect(String(transport.get("unit_id", "")) == "unit_00000051", "Transport identity should be restored")
		_expect(String(transport.get("transport_state", "")) == "loaded", "Transport mission state should be restored")
		_expect(Array(transport.get("transport_cargo", [])).size() == 1, "Transport cargo should be restored")
		_expect(String(transport.get("transport_landing_type", "")) == "rooftop" and String(transport.get("transport_target_building_kind", "")) == "factory", "Transport rooftop insertion target must survive restore")
		_expect(int(transport.get("transport_drop_index", -1)) == 1 and is_equal_approx(float(transport.get("transport_drop_timer", -1.0)), 0.35), "Rope deployment progress must survive restore")
		_expect(String(transport.get("transport_ai_last_site_id", "")) == "roof_factory_01", "Transport AI landing-site identity must survive restore")
		_expect(Array(transport.get("transport_ai_route_points", [])).size() == 3 and int(transport.get("transport_ai_route_index", -1)) == 1, "Transport flight route and current waypoint must survive restore")
		_expect(bool(transport.get("transport_ai_autonomous_active", false)) and not bool(transport.get("transport_ai_player_override", true)), "Transport AI execution policy must survive restore")
		_expect(bool(transport.get("transport_firing", false)) and transport.get("attack_focus_pos", Vector2.ZERO) == Vector2(735.0, 270.0) and transport.get("attack_target_pos", Vector2.ZERO) == Vector2(742.0, 275.0), "Loaded passenger firing focus must survive restore")
		_expect(String(mover.get("unit_id", "")) == "unit_00000053" and mover.get("target", Vector2.ZERO) == Vector2(720.0, 240.0), "Movement destination order must survive save/restore")
		_expect(String(attacker.get("unit_id", "")) == "unit_00000054" and int(attacker.get("attack_target", -1)) == 4, "Attack order must retain its target unit index after restore")
		_expect(String(game.get("units")[4].get("unit_id", "")) == "unit_00000056" and String(game.get("units")[4].get("team", "")) == "enemy", "The restored attack target must still identify the same enemy unit")
		_expect(String(guard.get("unit_id", "")) == "unit_00000055" and bool(guard.get("guard_active", false)), "Guard stance must survive save/restore")
	_expect(game.get("buildings").size() == 1 and game.get("enemy_buildings").size() == 1, "Both armies' building states should be restored")
	_expect(game.get("production_orders").size() == 1 and game.get("missiles").size() == 1, "Production and active missile state should be restored")

	game.set("credits", 1337)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	game.set("credits", 5)
	_expect(bool(game.call("_load_battle_snapshot")), "Android pause notification should persist a resumable battle")
	_expect(int(game.get("credits")) == 1337, "Pause autosave should capture the latest economy state")

	game.set("credits", 1444)
	game.call("_notification", Node.NOTIFICATION_WM_CLOSE_REQUEST)
	game.set("credits", 6)
	_expect(bool(game.call("_load_battle_snapshot")), "Desktop close notification should persist the active battle before teardown")
	_expect(int(game.get("credits")) == 1444, "Close-request autosave should capture the latest economy state")
	game.set("game_started", false)
	game.set("campaign_briefing", false)
	game.set("has_resumable_battle", game.call("_has_resumable_battle"))
	game.set("credits", 2222)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	game.set("credits", 7)
	var resume_menu_size: Vector2 = game.get_viewport_rect().size
	var resume_button: Rect2 = game.call("_resume_battle_rect", resume_menu_size)
	_expect(bool(game.get("has_resumable_battle")) and resume_button.size.y >= 42.0, "Main menu must expose a usable resume action when a valid active battle save exists")
	game.call("_handle_pointer", resume_button.get_center(), true)
	game.call("_handle_pointer", resume_button.get_center(), false)
	_expect(bool(game.get("game_started")), "Touching the main-menu resume action must return directly to the saved battle")
	_expect(int(game.get("credits")) == 1444, "Main-menu resume must restore the latest autosaved economy state")
	# Isolate the transport lifecycle fixture after validating independent combat orders above.
	game.get("units").resize(1)

	# Exercise every meaningful transport lifecycle boundary through the real snapshot path.
	var transport_cases := [
		{"state": "inbound", "cargo_count": 1, "target": Vector2(710.0, 280.0), "route": [Vector2(500.0, 220.0), Vector2(710.0, 280.0)], "drop_index": 0},
		{"state": "descending", "cargo_count": 1, "target": Vector2(720.0, 290.0), "route": [Vector2(540.0, 230.0), Vector2(720.0, 290.0)], "drop_index": 0},
		{"state": "returning", "cargo_count": 1, "target": Vector2(650.0, 320.0), "route": [Vector2(600.0, 280.0), Vector2(650.0, 320.0)], "drop_index": 0},
		{"state": "loaded", "cargo_count": 1, "target": Vector2(680.0, 260.0), "route": [], "drop_index": 0},
		{"state": "idle", "cargo_count": 0, "target": Vector2.ZERO, "route": [], "drop_index": 1}
	]
	for case_index in range(transport_cases.size()):
		var transport_case: Dictionary = transport_cases[case_index]
		var live_transport: Dictionary = game.get("units")[0]
		live_transport["transport_state"] = String(transport_case["state"])
		live_transport["transport_target_pos"] = transport_case["target"]
		live_transport["transport_ai_route_points"] = transport_case["route"].duplicate(true)
		live_transport["transport_ai_route_index"] = 0
		live_transport["transport_drop_index"] = int(transport_case["drop_index"])
		live_transport["transport_drop_timer"] = 0.35
		live_transport["transport_cargo"] = []
		if int(transport_case["cargo_count"]) > 0:
			live_transport["transport_cargo"] = [{
				"unit_id": "unit_00000052",
				"kind": "infantry",
				"team": "player",
				"faction": "وطن",
				"hp": 47,
				"pos": Vector2(420.0, 210.0)
			}]
		elif game.get("units").size() == 1:
			game.get("units").append({
				"unit_id": "unit_00000052",
				"kind": "infantry",
				"team": "player",
				"faction": "وطن",
				"hp": 47,
				"pos": Vector2(720.0, 290.0)
			})
		_expect(bool(game.call("_save_battle_snapshot")), "Transport lifecycle case %s should save" % String(transport_case["state"]))
		live_transport["transport_state"] = "idle"
		live_transport["transport_ai_route_points"] = []
		_expect(bool(game.call("_load_battle_snapshot")), "Transport lifecycle case %s should restore" % String(transport_case["state"]))
		var restored_transport: Dictionary = game.get("units")[0]
		_expect(String(restored_transport.get("transport_state", "")) == String(transport_case["state"]), "Transport lifecycle state should survive save/restore")
		_expect(Array(restored_transport.get("transport_cargo", [])).size() == int(transport_case["cargo_count"]), "Transport cargo manifest should match lifecycle state")
		_expect(restored_transport.get("transport_target_pos", Vector2.ZERO).distance_to(transport_case["target"]) < 0.1, "Transport destination should survive lifecycle save/restore")
		_expect(Array(restored_transport.get("transport_ai_route_points", [])).size() == Array(transport_case["route"]).size(), "Transport tactical route should survive lifecycle save/restore")
		if case_index == transport_cases.size() - 1:
			_expect(game.get("units").size() == 2 and String(game.get("units")[1].get("unit_id", "")) == "unit_00000052", "Dropped passenger should exist as a field unit after leaving the manifest")

	# Preserve live collections: the remainder of this integration test exercises
	# transport and battle-result code that expects complete positional records.
	var saved_objective_supply_points: Array = game.get("supply_points").duplicate(true)
	var saved_objective_buildings: Array = game.get("buildings").duplicate(true)
	var saved_objective_units: Array = game.get("units").duplicate(true)

	# Campaign secondary objectives expose live, deterministic progress for every mission.
	game.set("campaign_mission_index", 0)
	game.set("player_base_hp", 499)
	game.set("game_started", true)
	game.get("selected").clear()
	var objective_hud: Dictionary = game.call("_campaign_objective_hud_state", Vector2(800.0, 480.0))
	_expect(bool(objective_hud.get("visible", false)), "Campaign objective HUD must be visible during an active campaign match")
	_expect((objective_hud.get("rect", Rect2()) as Rect2).position == Vector2(10.0, 203.0), "Objective HUD must use its upper slot when no units are selected")
	_expect(float(objective_hud.get("progress", -1.0)) == 0.998, "Objective HUD progress must match the live mission status")
	_expect(String(objective_hud.get("state", "")) == "499 / 500", "Objective HUD must expose the current and required counts")
	game.get("selected").append(0)
	objective_hud = game.call("_campaign_objective_hud_state", Vector2(800.0, 480.0))
	_expect((objective_hud.get("rect", Rect2()) as Rect2).position == Vector2(10.0, 255.0), "Objective HUD must move below the unit dossier when units are selected")
	game.get("selected").clear()
	game.set("game_started", false)
	objective_hud = game.call("_campaign_objective_hud_state", Vector2(800.0, 480.0))
	_expect(not bool(objective_hud.get("visible", true)), "Objective HUD must be hidden outside an active match")
	game.set("game_started", true)
	var objective_status: Dictionary = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 499 and int(objective_status.get("required", -1)) == 500 and not bool(objective_status.get("met", true)), "Mission 1 objective progress must reflect base health below threshold")
	game.set("player_base_hp", 500)
	_expect(bool(game.call("_campaign_secondary_objective_met")), "Mission 1 secondary objective must complete at 50 percent base health")
	objective_hud = game.call("_campaign_objective_hud_state", Vector2(320.0, 480.0))
	_expect(bool(objective_hud.get("met", false)) and String(objective_hud.get("state", "")) == "مكتمل", "Objective HUD must switch to its completed state when the live threshold is reached")
	_expect(float(objective_hud.get("progress", 0.0)) == 1.0, "Completed objective HUD progress must clamp to exactly 100 percent")
	_expect((objective_hud.get("rect", Rect2()) as Rect2).size == Vector2(300.0, 39.0), "Objective HUD must preserve safe horizontal margins on a narrow phone viewport")

	game.get("supply_points").clear()
	game.get("supply_points").append_array([
		{"id": "objective_supply_1", "pos": Vector2(300.0, 250.0), "owner": "player"},
		{"id": "objective_supply_2", "pos": Vector2(500.0, 250.0), "owner": "player"},
		{"id": "objective_supply_3", "pos": Vector2(700.0, 250.0), "owner": "enemy"},
		{"id": "objective_supply_4", "pos": Vector2(900.0, 250.0), "owner": "neutral"}
	])
	game.set("campaign_mission_index", 1)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 2 and bool(objective_status.get("met", false)), "Mission 2 objective must count two player-controlled supply points")

	game.get("buildings").clear()
	game.get("buildings").append_array([
		{"pos": Vector2(300.0, 300.0), "hp": 100, "build_progress": 1.0},
		{"pos": Vector2(400.0, 300.0), "hp": 100, "build_progress": 1.0},
		{"pos": Vector2(500.0, 300.0), "hp": 100, "build_progress": 1.0},
		{"pos": Vector2(600.0, 300.0), "hp": 100, "build_progress": 0.75},
		{"pos": Vector2(700.0, 300.0), "hp": 0, "build_progress": 1.0}
	])
	game.set("campaign_mission_index", 2)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 3 and not bool(objective_status.get("met", true)), "Mission 3 objective must exclude incomplete and destroyed buildings")
	game.get("buildings").append({"pos": Vector2(800.0, 300.0), "hp": 100, "build_progress": 1.0})
	_expect(bool(game.call("_campaign_secondary_objective_met")), "Mission 3 secondary objective must complete with four finished living buildings")

	game.get("units").clear()
	game.get("units").append_array([
		{"pos": Vector2(300.0, 400.0), "team": "player", "kind": "fighter", "hp": 100},
		{"pos": Vector2(400.0, 400.0), "team": "player", "kind": "tank", "hp": 100},
		{"pos": Vector2(500.0, 400.0), "team": "player", "kind": "artillery", "hp": 0},
		{"pos": Vector2(600.0, 400.0), "team": "enemy", "kind": "tank", "hp": 100}
	])
	game.set("campaign_mission_index", 3)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 2 and bool(objective_status.get("met", false)), "Mission 4 objective must require living player air and armor units")
	game.get("units").clear()
	game.get("units").append_array([
		{"pos": Vector2(300.0, 400.0), "team": "player", "kind": "fighter", "hp": 100},
		{"pos": Vector2(400.0, 400.0), "team": "player", "kind": "tank", "hp": 0}
	])
	_expect(not bool(game.call("_campaign_secondary_objective_met")), "Mission 4 objective must fail when the only armor unit is destroyed")

	game.set("campaign_mission_index", 4)
	game.set("player_base_hp", 599)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 599 and not bool(objective_status.get("met", true)), "Mission 5 objective progress must reflect base health below 60 percent")
	game.set("player_base_hp", 600)
	_expect(bool(game.call("_campaign_secondary_objective_met")), "Mission 5 secondary objective must complete at 60 percent base health")

	game.get("supply_points").clear()
	game.get("supply_points").append_array(saved_objective_supply_points)
	game.get("buildings").clear()
	game.get("buildings").append_array(saved_objective_buildings)
	game.get("units").clear()
	game.get("units").append_array(saved_objective_units)

	# Battle outcomes must update career and campaign progression exactly once.
	var original_commander_profile: Dictionary = game.get("commander_profile").duplicate(true)
	game.set("commander_profile", {
		"battles_played": 0,
		"victories": 0,
		"defeats": 0,
		"total_kills": 0,
		"air_kills": 0,
		"armor_kills": 0,
		"naval_kills": 0,
		"earned_medals": [],
		"campaign_progress": {"وطن": 0},
		"campaign_funds": 0
	})
	game.set("faction", "وطن")
	game.set("campaign_mission_index", 0)
	game.set("campaign_briefing", false)
	game.set("commander_profile_saved_result", "")
	game.set("battle_result", "")
	game.set("enemy_base_hp", 0)
	game.set("player_base_hp", 700)
	_expect(bool(game.call("_resolve_battle_result")), "Destroying the enemy base must resolve a victory immediately")
	var victory_profile: Dictionary = game.get("commander_profile")
	_expect(int(victory_profile.get("battles_played", 0)) == 1 and int(victory_profile.get("victories", 0)) == 1, "Victory must increment battle and victory totals once")
	_expect(int(victory_profile.get("campaign_progress", {}).get("وطن", 0)) == 1, "Victory must unlock the next campaign mission")
	_expect(int(victory_profile.get("campaign_funds", 0)) == 350, "Meeting the first mission secondary objective must grant base and bonus rewards")
	game.call("_resolve_battle_result")
	_expect(int(victory_profile.get("battles_played", 0)) == 1 and int(victory_profile.get("victories", 0)) == 1, "Repeated victory resolution must not duplicate career totals")
	_expect(int(victory_profile.get("campaign_funds", 0)) == 350, "Repeated victory resolution must not duplicate campaign rewards")

	game.set("faction", "")
	game.set("commander_profile_saved_result", "")
	game.set("battle_result", "")
	game.set("enemy_base_hp", 500)
	game.set("player_base_hp", 0)
	_expect(bool(game.call("_resolve_battle_result")), "Destroying the player base must resolve a defeat immediately")
	var defeat_profile: Dictionary = game.get("commander_profile")
	_expect(int(defeat_profile.get("battles_played", 0)) == 2 and int(defeat_profile.get("defeats", 0)) == 1, "Defeat must increment battle and defeat totals once")
	_expect(int(defeat_profile.get("campaign_progress", {}).get("وطن", 0)) == 1 and int(defeat_profile.get("campaign_funds", 0)) == 350, "Defeat must not unlock missions or award campaign funds")
	game.call("_resolve_battle_result")
	_expect(int(defeat_profile.get("battles_played", 0)) == 2 and int(defeat_profile.get("defeats", 0)) == 1, "Repeated defeat resolution must not duplicate career totals")

	# Every campaign mission must award its own base reward and secondary bonus exactly once.
	var expected_campaign_rewards := [350, 500, 625, 750, 1050]
	for mission_index in range(expected_campaign_rewards.size()):
		game.set("campaign_mission_index", mission_index)
		game.set("faction", "وطن")
		game.set("campaign_briefing", false)
		game.set("battle_result", "victory")
		game.set("commander_profile_saved_result", "")
		game.set("enemy_base_hp", 0)
		game.set("player_base_hp", 1000)
		game.get("supply_points").clear()
		game.get("buildings").clear()
		game.get("units").clear()
		if mission_index == 0:
			game.set("player_base_hp", 500)
		elif mission_index == 1:
			game.get("supply_points").append_array([
				{"pos": Vector2(300.0, 250.0), "owner": "player"},
				{"pos": Vector2(500.0, 250.0), "owner": "player"}
			])
		elif mission_index == 2:
			for building_index in range(4):
				game.get("buildings").append({"pos": Vector2(300.0 + building_index * 100.0, 300.0), "hp": 100, "build_progress": 1.0})
		elif mission_index == 3:
			game.get("units").append_array([
				{"pos": Vector2(300.0, 400.0), "team": "player", "kind": "fighter", "hp": 100},
				{"pos": Vector2(400.0, 400.0), "team": "player", "kind": "tank", "hp": 100}
			])
		elif mission_index == 4:
			game.set("player_base_hp", 600)
		game.set("commander_profile", {
			"battles_played": 0,
			"victories": 0,
			"defeats": 0,
			"campaign_progress": {"وطن": mission_index},
			"campaign_funds": 0
		})
		game.call("_record_battle_result")
		var mission_profile: Dictionary = game.get("commander_profile")
		_expect(int(mission_profile.get("campaign_funds", 0)) == expected_campaign_rewards[mission_index], "Campaign mission %d must award its base reward plus its secondary bonus" % (mission_index + 1))
		_expect(int(mission_profile.get("campaign_progress", {}).get("وطن", -1)) == mission_index + 1, "Campaign mission %d victory must unlock exactly the next mission" % (mission_index + 1))
		game.call("_record_battle_result")
		_expect(int(mission_profile.get("campaign_funds", 0)) == expected_campaign_rewards[mission_index], "Campaign mission %d repeated result must not duplicate rewards" % (mission_index + 1))

	# Exercise the real faction-picker and campaign-start pointer path.
	game.set("commander_profile", {
		"battles_played": 0,
		"victories": 0,
		"defeats": 0,
		"campaign_progress": {"وطن": 2},
		"campaign_funds": 0
	})
	game.set("game_started", false)
	game.set("campaign_briefing", false)
	game.set("battle_result", "")
	game.set("faction", "")
	var menu_size: Vector2 = game.get_viewport_rect().size
	var watan_button: Rect2 = game.call("_faction_rect", 3, menu_size)
	game.call("_handle_pointer", watan_button.get_center(), true)
	game.call("_handle_pointer", watan_button.get_center(), false)
	_expect(String(game.get("faction")) == "وطن" and bool(game.get("campaign_briefing")), "Selecting Watan from the live faction picker must open its campaign briefing")
	var campaign_start_button: Rect2 = game.call("_campaign_start_rect", menu_size)
	game.call("_handle_pointer", campaign_start_button.get_center(), true)
	game.call("_handle_pointer", campaign_start_button.get_center(), false)
	_expect(bool(game.get("game_started")) and not bool(game.get("campaign_briefing")), "Campaign start button must enter the live match")
	_expect(int(game.get("campaign_mission_index")) == 2 and String(game.get("map_type")) == "الساحل الجبلي", "Campaign start must resume the correct unlocked mission and map")
	_expect(game.get("units").size() == 1 and String(game.get("units")[0].get("kind", "")) == "builder" and String(game.get("units")[0].get("faction", "")) == "وطن", "Campaign start must deploy the selected army's builder")
	_expect(int(game.get("credits")) == 1200 and int(game.get("supplies")) == 5 and int(game.get("enemy_supplies")) == 5, "Campaign start must initialize both economies and opening supplies")

	# Complete a full campaign battle through the actual frame loop and verify one-time resolution.
	for building_index in range(4):
		game.get("buildings").append({
			"kind": "barracks" if building_index == 0 else "factory",
			"pos": Vector2(300.0 + building_index * 80.0, 300.0),
			"hp": 400,
			"build_progress": 1.0
		})
	game.set("enemy_base_hp", 0)
	game.call("_process", 0.1)
	_expect(String(game.get("battle_result")) != "" and String(game.get("battle_result")).contains("انتصرت"), "Destroying the enemy base during the live campaign loop must resolve a victory")
	var live_victory_profile: Dictionary = game.get("commander_profile")
	_expect(int(live_victory_profile.get("battles_played", 0)) == 1 and int(live_victory_profile.get("victories", 0)) == 1, "Live campaign victory must record career totals exactly once")
	_expect(int(live_victory_profile.get("campaign_progress", {}).get("وطن", 0)) == 3, "Live campaign victory must unlock the next Watan mission")
	_expect(int(live_victory_profile.get("campaign_funds", 0)) == 625, "Live mountain campaign victory must grant its 450 base reward and 175 secondary bonus")
	game.call("_process", 0.1)
	_expect(int(live_victory_profile.get("battles_played", 0)) == 1 and int(live_victory_profile.get("campaign_funds", 0)) == 625, "Additional frames after victory must not duplicate campaign rewards or career totals")

	# Resolve defeat through the same live frame loop; it must not advance or reward the campaign.
	game.set("battle_result", "")
	game.set("commander_profile_saved_result", "")
	game.set("player_base_hp", 0)
	game.set("enemy_base_hp", 500)
	game.call("_process", 0.1)
	var live_defeat_result := String(game.get("battle_result"))
	_expect(live_defeat_result.contains("هُزمت"), "Destroying the player base in the live campaign loop must resolve defeat")
	_expect(int(live_victory_profile.get("battles_played", 0)) == 2 and int(live_victory_profile.get("defeats", 0)) == 1, "Live defeat must record exactly one additional battle and defeat")
	_expect(int(live_victory_profile.get("campaign_progress", {}).get("وطن", 0)) == 3 and int(live_victory_profile.get("campaign_funds", 0)) == 625, "Live defeat must preserve campaign progress and grant no additional funds")
	_expect(bool(game.call("_save_battle_snapshot")), "A completed defeat state must be saveable for result continuity")
	game.set("battle_result", "")
	game.set("player_base_hp", 900)
	_expect(bool(game.call("_load_battle_snapshot")), "Saved defeat state must restore through the battle save integration")
	_expect(String(game.get("battle_result")) == live_defeat_result and int(game.get("player_base_hp")) == 0, "Restoring a defeated battle must preserve its result and destroyed base state")
	game.call("_process", 0.1)
	_expect(int(live_victory_profile.get("battles_played", 0)) == 2 and int(live_victory_profile.get("defeats", 0)) == 1, "Frames after restoring defeat must not record the same loss twice")

	game.set("commander_profile", original_commander_profile)
	game.call("_save_commander_profile")

	game.get("battle_save_store").call("delete_snapshot")
	game.get("battle_save_store").call("delete_snapshot")
	game.queue_free()
	await process_frame
	if failure_count > 0:
		push_error("Battle save integration failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Battle save integration passed: full match snapshot restores economy, objectives, armies, transport cargo, production, and missiles.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Battle save integration failed: " + message)
