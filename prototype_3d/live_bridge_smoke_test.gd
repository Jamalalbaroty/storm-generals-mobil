extends SceneTree

func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load the active game scene for live bridge validation")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame

	var bridge := game.get("battlefield_3d") as Node3D
	if bridge == null or bridge.get_parent() != game:
		push_error("Active match did not create its dedicated 3D gameplay bridge")
		quit(1)
		return
	if not bridge.is_connected("gameplay_order_issued", Callable(game, "_on_3d_gameplay_order_issued")):
		push_error("3D command signal is not connected to the live RTS command layer")
		quit(1)
		return
	if bridge.visible:
		push_error("3D gameplay bridge must remain hidden until the 3D view is explicitly enabled")
		quit(1)
		return

	game.set("game_started", true)
	game.set("faction", "الأمريكي")
	game.call("_set_3d_view_enabled", true)
	if not bridge.visible or not bool(game.get("use_3d_view")):
		push_error("Explicit 3D view activation did not reveal the live battlefield")
		quit(1)
		return
	game.call("_set_3d_view_enabled", false)
	if bridge.visible or bool(game.get("use_3d_view")):
		push_error("Returning to 2D view did not hide the 3D battlefield")
		quit(1)
		return
	var test_units: Array[Dictionary] = [
		{"pos": Vector2(200.0, 160.0), "team": "player", "kind": "tank", "faction": "الأمريكي", "hp": 75.0, "max_hp": 150.0},
		{"pos": Vector2(800.0, 420.0), "team": "enemy", "kind": "fighter", "faction": "الصيني", "hp": 120.0, "max_hp": 120.0}
	]
	var test_buildings: Array[Dictionary] = [
		{"pos": Vector2(260.0, 220.0), "kind": "factory", "build_progress": 0.65, "hp": 500}
	]
	var test_enemy_buildings: Array[Dictionary] = [
		{"pos": Vector2(820.0, 430.0), "kind": "turret", "build_progress": 1.0, "hp": 400}
	]
	game.set("units", test_units)
	game.set("buildings", test_buildings)
	game.set("enemy_buildings", test_enemy_buildings)
	game.call("_sync_3d_gameplay_bridge")

	if bridge.game_unit_nodes.size() != 2 or bridge.game_building_nodes.size() != 2:
		push_error("Live gameplay bridge did not synchronize both teams' units and buildings")
		quit(1)
		return
	var player_tank := bridge.game_unit_nodes.get("player|1|tank") as Node3D
	var enemy_fighter := bridge.game_unit_nodes.get("enemy|2|fighter") as Node3D
	if player_tank == null or enemy_fighter == null:
		push_error("Live bridge lost stable unit identity or team ownership")
		quit(1)
		return
	game.call("_on_3d_gameplay_order_issued", "player|1|tank", "move", Vector3(0.0, 0.0, 0.0), "")
	var logical_units: Array[Dictionary] = game.get("units")
	if not logical_units[0].has("target") or logical_units[0].target.distance_to(Vector2(640.0, 360.0)) > 0.1:
		push_error("3D move command did not convert battlefield coordinates into the live RTS map")
		quit(1)
		return
	game.call("_on_3d_gameplay_order_issued", "player|1|tank", "attack", Vector3.ZERO, "enemy|2|fighter")
	logical_units = game.get("units")
	if int(logical_units[0].get("attack_target", -1)) != 1 or not logical_units[0].has("attack_focus_pos"):
		push_error("3D attack command did not resolve the enemy unit into a live RTS attack order")
		quit(1)
		return
	game.call("_set_3d_view_enabled", true)
	# Two-finger gestures must enter pinch mode and must not become a unit-selection tap.
	var touch_one := InputEventScreenTouch.new()
	touch_one.index = 0
	touch_one.pressed = true
	touch_one.position = Vector2(240.0, 260.0)
	bridge.call("_unhandled_input", touch_one)
	var touch_two := InputEventScreenTouch.new()
	touch_two.index = 1
	touch_two.pressed = true
	touch_two.position = Vector2(440.0, 260.0)
	bridge.call("_unhandled_input", touch_two)
	if not bool(bridge.get("touch_multi_gesture")) or float(bridge.get("last_pinch_distance")) < 199.0:
		push_error("Two-finger touch did not enter mobile pinch gesture mode")
		quit(1)
		return
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 1
	touch_drag.position = Vector2(480.0, 280.0)
	touch_drag.relative = Vector2(40.0, 20.0)
	bridge.call("_unhandled_input", touch_drag)
	var pinch_center: Vector2 = bridge.get("last_pinch_center")
	if pinch_center.distance_to(Vector2(360.0, 270.0)) > 0.1:
		push_error("Two-finger camera gesture did not track the pinch center for camera panning")
		quit(1)
		return
	var release_one := InputEventScreenTouch.new()
	release_one.index = 0
	release_one.pressed = false
	release_one.position = Vector2(240.0, 260.0)
	bridge.call("_unhandled_input", release_one)
	var release_two := InputEventScreenTouch.new()
	release_two.index = 1
	release_two.pressed = false
	release_two.position = Vector2(480.0, 280.0)
	bridge.call("_unhandled_input", release_two)
	if bool(bridge.get("touch_multi_gesture")) or not (bridge.get("selected_live_units") as Array).is_empty():
		push_error("Ending a pinch gesture left gesture state active or triggered unintended unit selection")
		quit(1)
		return
	var enemy_screen: Vector2 = bridge.rts_camera.unproject_position(enemy_fighter.global_position + Vector3.UP)
	var player_screen: Vector2 = bridge.rts_camera.unproject_position(player_tank.global_position + Vector3.UP)
	bridge.call("_handle_world_tap", enemy_screen)
	bridge.call("_handle_world_tap", player_screen)
	if bridge.get("selected_tank") != player_tank:
		push_error("Tapping a friendly live unit did not select it after an enemy was selected")
		quit(1)
		return
	bridge.call("_handle_world_tap", enemy_screen)
	logical_units = game.get("units")
	if int(logical_units[0].get("attack_target", -1)) != 1:
		push_error("Tapping an enemy live unit did not issue an attack from the selected friendly unit")
		quit(1)
		return
	var player_position_before: Vector3 = player_tank.global_position
	bridge.set("has_selected_destination", true)
	bridge.set("selected_destination", player_position_before + Vector3(10.0, 0.0, 0.0))
	bridge.call("_update_showcase_orders", 1.0)
	if player_tank.global_position.distance_to(player_position_before) > 0.001:
		push_error("A live 3D proxy moved locally instead of following the authoritative RTS simulation")
		quit(1)
		return
	game.call("_set_3d_view_enabled", false)
	if absf(float(player_tank.get_meta("health", 0.0)) - 75.0) > 0.001 or absf(float(player_tank.get_meta("max_health", 0.0)) - 150.0) > 0.001:
		push_error("Live bridge did not preserve unit health values")
		quit(1)
		return
	var factory_key := "player|factory|260.00|220.00"
	var factory := bridge.game_building_nodes.get(factory_key) as Node3D
	if factory == null or absf(float(factory.get_meta("construction_progress", 0.0)) - 0.65) > 0.001:
		push_error("Live bridge did not preserve building construction progress")
		quit(1)
		return

	var original_tank := player_tank
	var updated_units: Array[Dictionary] = game.get("units")
	updated_units[0]["pos"] = Vector2(300.0, 240.0)
	updated_units[0]["hp"] = 45.0
	game.set("units", updated_units)
	game.call("_sync_3d_gameplay_bridge")
	if bridge.game_unit_nodes.get("player|1|tank") != original_tank or absf(float(player_tank.get_meta("health", 0.0)) - 45.0) > 0.001:
		push_error("Live bridge recreated a unit instead of updating its stable 3D counterpart")
		quit(1)
		return

	# Multi-unit selection must select only live friendly units inside the drag rectangle.
	var multi_units: Array[Dictionary] = game.get("units")
	multi_units.append({"pos": Vector2(260.0, 220.0), "team": "player", "kind": "tank", "faction": "الأمريكي", "hp": 130.0, "max_hp": 150.0})
	game.set("units", multi_units)
	game.call("_sync_3d_gameplay_bridge")
	var second_player := bridge.game_unit_nodes.get("player|3|tank") as Node3D
	if second_player == null:
		push_error("Live bridge did not create the second friendly unit for multi-selection")
		quit(1)
		return
	var first_screen: Vector2 = bridge.rts_camera.unproject_position(player_tank.global_position + Vector3.UP)
	var second_screen: Vector2 = bridge.rts_camera.unproject_position(second_player.global_position + Vector3.UP)
	var drag_start := Vector2(minf(first_screen.x, second_screen.x) - 42.0, minf(first_screen.y, second_screen.y) - 42.0)
	var drag_finish := Vector2(maxf(first_screen.x, second_screen.x) + 42.0, maxf(first_screen.y, second_screen.y) + 42.0)
	bridge.call("_select_live_units_in_screen_rect", drag_start, drag_finish)
	var selected_live: Array = bridge.get("selected_live_units")
	if selected_live.size() != 2 or not selected_live.has(player_tank) or not selected_live.has(second_player):
		push_error("Drag rectangle did not select both friendly live units")
		quit(1)
		return
	bridge.call("_handle_world_tap", enemy_screen)
	multi_units = game.get("units")
	if int(multi_units[0].get("attack_target", -1)) != 1 or int(multi_units[2].get("attack_target", -1)) != 1:
		push_error("Group attack did not issue an attack order to every selected friendly unit")
		quit(1)
		return
	var open_ground_screen := Vector2.ZERO
	var found_open_ground := false
	var visible_rect: Rect2 = bridge.get_viewport().get_visible_rect()
	for world_x in [-15.0, -10.0, 0.0, 10.0, 15.0]:
		for world_z in [-15.0, -10.0, 0.0, 10.0, 15.0]:
			var candidate: Vector2 = bridge.rts_camera.unproject_position(Vector3(world_x, 0.0, world_z))
			var candidate_ground: Variant = bridge.call("_screen_to_ground", candidate)
			if visible_rect.has_point(candidate) and candidate_ground != null and bridge.call("_tank_at_screen_position", candidate) == null:
				open_ground_screen = candidate
				found_open_ground = true
				break
		if found_open_ground:
			break
	if not found_open_ground:
		push_error("Could not find visible empty ground for group movement validation")
		quit(1)
		return
	bridge.call("_handle_world_tap", open_ground_screen)
	multi_units = game.get("units")
	if not multi_units[0].has("target") or not multi_units[2].has("target") or multi_units[0].target.distance_to(multi_units[2].target) < 1.0:
		push_error("Group movement did not assign distinct formation destinations to all selected units")
		quit(1)
		return

	# Naval counter-production must launch destroyers from the coastal shipyard.
	var naval_test_units: Array[Dictionary] = []
	game.set("units", naval_test_units)
	var ai_shipyards: Array[Dictionary] = [{"pos": Vector2(900.0, 320.0), "kind": "shipyard", "hp": 500, "build_progress": 1.0}]
	game.set("enemy_buildings", ai_shipyards)
	game.set("enemy_base", Vector2(900.0, 320.0))
	game.set("enemy_credits", 100000)
	game.set("enemy_supplies", 1000)
	if not bool(game.call("_enemy_has_building", "shipyard")):
		push_error("Naval-control AI test setup did not register a completed enemy shipyard")
		quit(1)
		return
	var produced_naval_counter := bool(game.call("_enemy_counter_production", "naval_control", 0, 0, 0, 0))
	var produced_units: Array = game.get("units")
	if not produced_naval_counter or produced_units.size() != 1 or String(produced_units[0].get("kind", "")) != "destroyer":
		push_error("Naval-control AI failed: produced=%s units=%s shipyard=%s credits=%s supplies=%s destroyer_cost=%s supply_cost=%s" % [produced_naval_counter, produced_units.size(), game.call("_enemy_has_building", "shipyard"), game.get("enemy_credits"), game.get("enemy_supplies"), game.call("_unit_cost", "destroyer", game.call("_enemy_faction")), game.call("_unit_supply_cost", "destroyer")])
		quit(1)
		return
	var expected_dock := Vector2(780.0, game.get_viewport_rect().size.y * 0.82)
	var produced_position: Vector2 = produced_units[0].get("pos", Vector2.ZERO)
	if produced_position.distance_to(expected_dock) > 0.1:
		push_error("Naval counter destroyer did not spawn at the coastal shipyard")
		quit(1)
		return

	# Once naval superiority is established, the enemy AI should deploy an amphibious assault craft.
	var ai_naval_units: Array[Dictionary] = [
		{"pos": Vector2(780.0, 650.0), "team": "enemy", "kind": "destroyer", "hp": 260},
		{"pos": Vector2(790.0, 650.0), "team": "enemy", "kind": "destroyer", "hp": 260},
		{"pos": Vector2(800.0, 650.0), "team": "enemy", "kind": "destroyer", "hp": 260},
		{"pos": Vector2(780.0, 660.0), "team": "enemy", "kind": "carrier", "hp": 520},
		{"pos": Vector2(780.0, 670.0), "team": "enemy", "kind": "submarine", "hp": 210},
		{"pos": Vector2(220.0, 650.0), "team": "player", "kind": "destroyer", "hp": 260},
		{"pos": Vector2(240.0, 650.0), "team": "player", "kind": "submarine", "hp": 210}
	]
	game.set("units", ai_naval_units)
	var complete_ai_buildings: Array[Dictionary] = [
		{"pos": Vector2(900.0, 240.0), "kind": "barracks", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(900.0, 300.0), "kind": "factory", "hp": 500, "build_progress": 1.0},
		{"pos": Vector2(900.0, 360.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(900.0, 420.0), "kind": "airfield", "hp": 450, "build_progress": 1.0},
		{"pos": Vector2(900.0, 480.0), "kind": "missile_silo", "hp": 500, "build_progress": 1.0},
		{"pos": Vector2(780.0, 650.0), "kind": "shipyard", "hp": 500, "build_progress": 1.0},
		{"pos": Vector2(900.0, 540.0), "kind": "anti_air", "hp": 380, "build_progress": 1.0}
	]
	game.set("enemy_buildings", complete_ai_buildings)
	game.set("enemy_credits", 100000)
	game.set("enemy_supplies", 1000)
	game.set("enemy_strategy", "balanced")
	game.call("_enemy_ai_turn")
	var amphibious_units: Array[Dictionary] = game.get("units")
	var ai_landing_craft_count := 0
	var ai_landing_craft: Dictionary = {}
	for ai_unit in amphibious_units:
		if ai_unit.get("team") == "enemy" and ai_unit.get("kind") == "landing_craft":
			ai_landing_craft_count += 1
			ai_landing_craft = ai_unit
	var expected_ai_dock := Vector2(780.0, game.get_viewport_rect().size.y * 0.82)
	if ai_landing_craft_count != 1 or String(ai_landing_craft.get("landing_state", "")) != "outbound" or int(ai_landing_craft.get("passengers", 0)) != 3 or Vector2(ai_landing_craft.get("home_pos", Vector2.ZERO)).distance_to(expected_ai_dock) > 0.1:
		push_error("Enemy naval AI did not deploy one fully loaded amphibious landing craft from its coastal dock")
		quit(1)
		return


	# Enemy amphibious units must unload a complete assault squad and direct it at the player base.
	var enemy_craft_test: Dictionary = ai_landing_craft
	enemy_craft_test["pos"] = Vector2(700.0, 520.0)
	var enemy_assault_units: Array[Dictionary] = [enemy_craft_test]
	game.set("units", enemy_assault_units)
	game.call("_update_landing_craft", enemy_assault_units[0], 0.1, Vector2(700.0, 520.0))
	var enemy_landed_units: Array[Dictionary] = game.get("units")
	var enemy_marines := 0
	var player_base_target: Vector2 = game.get("base_pos")
	for enemy_landed_unit in enemy_landed_units:
		if enemy_landed_unit.get("team") == "enemy" and enemy_landed_unit.get("kind") == "infantry" and bool(enemy_landed_unit.get("landing_assault", false)):
			enemy_marines += 1
			if not enemy_landed_unit.has("target") or Vector2(enemy_landed_unit["target"]).distance_to(player_base_target) > 0.1:
				push_error("Enemy amphibious infantry did not receive an attack route to the player base")
				quit(1)
				return
	if enemy_marines != 3 or enemy_landed_units.size() != 4 or String(enemy_landed_units[0].get("landing_state", "")) != "returning":
		push_error("Enemy amphibious craft failed to unload a complete three-marine squad and return")
		quit(1)
		return


	# Enemy craft must complete the same return-and-reload cycle after its assault.
	var enemy_home: Vector2 = Vector2(enemy_craft_test.get("home_pos", Vector2.ZERO))
	enemy_landed_units[0]["pos"] = enemy_home
	game.set("units", enemy_landed_units)
	game.call("_update_landing_craft", enemy_landed_units[0], 0.1, Vector2(700.0, 520.0))
	var enemy_loading_units: Array[Dictionary] = game.get("units")
	if String(enemy_loading_units[0].get("landing_state", "")) != "loading" or absf(float(enemy_loading_units[0].get("landing_timer", 0.0)) - 5.0) > 0.01:
		push_error("Enemy landing craft did not return to dock for its five-second reload")
		quit(1)
		return
	game.call("_update_landing_craft", enemy_loading_units[0], 5.1, Vector2(700.0, 520.0))
	var enemy_reloaded_units: Array[Dictionary] = game.get("units")
	if String(enemy_reloaded_units[0].get("landing_state", "")) != "outbound" or int(enemy_reloaded_units[0].get("passengers", 0)) != 3 or enemy_reloaded_units.size() != 4:
		push_error("Enemy landing craft failed to reload and prepare a second amphibious sortie")
		quit(1)
		return

	# Landing craft must unload exactly three marines, return, reload and prepare another sortie.
	var shore := Vector2(700.0, 520.0)
	var home_dock := Vector2(180.0, 520.0)
	var landing_craft: Dictionary = {
		"pos": shore, "home_pos": home_dock, "team": "player", "kind": "landing_craft",
		"faction": "الأمريكي", "hp": 180, "passengers": 3, "landing_state": "outbound"
	}
	var landing_units: Array[Dictionary] = [landing_craft]
	game.set("units", landing_units)
	game.call("_update_landing_craft", landing_units[0], 0.1, shore)
	var unloaded_units: Array[Dictionary] = game.get("units")
	var unloaded_marines := 0
	for landed_unit in unloaded_units:
		if landed_unit.get("team") == "player" and landed_unit.get("kind") == "infantry" and bool(landed_unit.get("landing_assault", false)):
			unloaded_marines += 1
	if unloaded_units.size() != 4 or unloaded_marines != 3 or String(unloaded_units[0].get("landing_state", "")) != "returning" or int(unloaded_units[0].get("passengers", -1)) != 0:
		push_error("Landing craft did not unload exactly three marines and enter returning state")
		quit(1)
		return

	unloaded_units[0]["pos"] = home_dock
	game.set("units", unloaded_units)
	game.call("_update_landing_craft", unloaded_units[0], 0.1, shore)
	var returning_units: Array[Dictionary] = game.get("units")
	if String(returning_units[0].get("landing_state", "")) != "loading" or absf(float(returning_units[0].get("landing_timer", 0.0)) - 5.0) > 0.01:
		push_error("Landing craft did not enter its five-second dock loading phase")
		quit(1)
		return
	game.call("_update_landing_craft", returning_units[0], 5.1, shore)
	var reloaded_units: Array[Dictionary] = game.get("units")
	if String(reloaded_units[0].get("landing_state", "")) != "outbound" or int(reloaded_units[0].get("passengers", 0)) != 3 or reloaded_units.size() != 4:
		push_error("Landing craft failed to reload three passengers for its next sortie")
		quit(1)
		return

	# A full team must make the craft wait at shore without duplicate or partial unloading.
	var capacity_units: Array[Dictionary] = [{
		"pos": shore, "home_pos": home_dock, "team": "player", "kind": "landing_craft",
		"faction": "الأمريكي", "hp": 180, "passengers": 3, "landing_state": "outbound"
	}]
	for marine_index in range(39):
		capacity_units.append({"pos": home_dock, "team": "player", "kind": "infantry", "hp": 100})
	game.set("units", capacity_units)
	game.call("_update_landing_craft", capacity_units[0], 0.1, shore)
	var capacity_result: Array[Dictionary] = game.get("units")
	if capacity_result.size() != 40 or String(capacity_result[0].get("landing_state", "")) != "outbound" or int(capacity_result[0].get("passengers", 0)) != 3:
		push_error("Landing craft did not wait safely when its team reached unit capacity")
		quit(1)
		return

	# A destroyer assigned to amphibious escort must hold station instead of firing at the distant base.
	game.set("base_pos", Vector2(200.0, 360.0))
	game.set("player_base_hp", 1000)
	var escort_craft_pos := Vector2(700.0, 360.0)
	var escort_slot := escort_craft_pos + Vector2(-58.0, -66.0)
	var escort_test_units: Array[Dictionary] = [
		{"pos": Vector2(400.0, 360.0), "team": "enemy", "kind": "destroyer", "hp": 260, "attack_cd": 0.0},
		{"pos": escort_craft_pos, "home_pos": Vector2(780.0, 590.0), "team": "enemy", "kind": "landing_craft", "hp": 180, "passengers": 3, "landing_state": "outbound"}
	]
	game.set("units", escort_test_units)
	var base_hp_before_escort: int = int(game.get("player_base_hp"))
	game.call("_process", 0.5)
	var escorted_units: Array[Dictionary] = game.get("units")
	var destroyer_after_escort: Vector2 = escorted_units[0].pos
	if int(game.get("player_base_hp")) != base_hp_before_escort or destroyer_after_escort.distance_to(escort_slot) >= Vector2(400.0, 360.0).distance_to(escort_slot):
		push_error("Destroyer did not hold escort station around its amphibious landing craft")
		quit(1)
		return

	var empty_units: Array[Dictionary] = []
	var empty_buildings: Array[Dictionary] = []
	var empty_enemy_buildings: Array[Dictionary] = []
	game.set("units", empty_units)
	game.set("buildings", empty_buildings)
	game.set("enemy_buildings", empty_enemy_buildings)
	game.call("_sync_3d_gameplay_bridge")
	if not bridge.game_unit_nodes.is_empty() or not bridge.game_building_nodes.is_empty():
		push_error("Live bridge stale cleanup counts: units=%d buildings=%d" % [bridge.game_unit_nodes.size(), bridge.game_building_nodes.size()])
		quit(1)
		return

	print("Live 2D-to-3D gameplay bridge: hidden-by-default state, two-team unit/building sync, health/progress updates, stable identity and stale cleanup passed")
	game.queue_free()
	await process_frame
	quit(0)
