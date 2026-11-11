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

	# Combat logic is under test here, not audio playback. Disable generated
	# playback streams so headless CI cannot exit with asynchronous WAV handles.
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	var bridge: Node3D = game.get("battlefield_3d") as Node3D
	if bridge != null or game.has_node("Gameplay3DBridge"):
		push_error("The 3D prototype should not be instantiated during a normal 2D match startup")
		quit(1)
		return
	game.call("_set_3d_view_enabled", false)
	if game.get("battlefield_3d") != null:
		push_error("Disabling 3D view must not instantiate the hidden battlefield")
		quit(1)
		return

	game.set("game_started", true)
	game.set("faction", "الأمريكي")
	game.call("_set_3d_view_enabled", true)
	bridge = game.get("battlefield_3d") as Node3D
	if bridge == null or bridge.get_parent() != game:
		push_error("Explicit 3D activation did not lazily create its dedicated gameplay bridge")
		quit(1)
		return
	if not bridge.is_connected("gameplay_order_issued", Callable(game, "_on_3d_gameplay_order_issued")):
		push_error("3D command signal is not connected to the live RTS command layer")
		quit(1)
		return
	if not bridge.visible or not bool(game.get("use_3d_view")):
		push_error("Explicit 3D view activation did not reveal the live battlefield")
		quit(1)
		return
	if bridge.process_mode == Node.PROCESS_MODE_DISABLED:
		push_error("Visible 3D battlefield must resume processing when activated")
		quit(1)
		return
	game.call("_set_3d_view_enabled", false)
	if bridge.visible or bool(game.get("use_3d_view")):
		push_error("Returning to 2D view did not hide the 3D battlefield")
		quit(1)
		return
	if bridge.process_mode != Node.PROCESS_MODE_DISABLED:
		push_error("Returning to 2D view must disable hidden 3D processing again")
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
	# Exercise Android cancellation through the parent input handler. The parent
	# marks the event handled, so the 3D child's unhandled-input callback cannot
	# clear its own pointer state unless the parent explicitly forwards the reset.
	var parent_cancelled_press := InputEventScreenTouch.new()
	parent_cancelled_press.index = 7
	parent_cancelled_press.pressed = true
	parent_cancelled_press.position = Vector2(320.0, 280.0)
	game._input(parent_cancelled_press)
	bridge.call("_unhandled_input", parent_cancelled_press)
	var emulated_mouse_press := InputEventMouseButton.new()
	emulated_mouse_press.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse_press.pressed = true
	emulated_mouse_press.position = Vector2(360.0, 300.0)
	game._input(emulated_mouse_press)
	if not game.get_viewport().is_input_handled() or bool(bridge.get("selection_gesture_active")):
		push_error("A synthetic mouse click escaped the parent while an Android finger owned the pointer")
		quit(1)
		return
	if int(game.get("active_touch_index")) != 7 or not (bridge.get("touch_points") as Dictionary).has(7):
		push_error("The parent/3D bridge did not establish the same active Android touch")
		quit(1)
		return
	var parent_cancelled_release := InputEventScreenTouch.new()
	parent_cancelled_release.index = 7
	parent_cancelled_release.pressed = false
	parent_cancelled_release.canceled = true
	parent_cancelled_release.position = Vector2(320.0, 280.0)
	game._input(parent_cancelled_release)
	if int(game.get("active_touch_index")) != -1 or not (bridge.get("touch_points") as Dictionary).is_empty() or not (bridge.get("touch_start_positions") as Dictionary).is_empty() or not (bridge.get("touch_moved") as Dictionary).is_empty() or bool(bridge.get("touch_multi_gesture")) or float(bridge.get("last_pinch_distance")) != 0.0:
		push_error("A parent-intercepted Android cancellation left stale 3D camera gesture state")
		quit(1)
		return
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
	var enemy_screen: Vector2 = bridge.rts_camera.unproject_position(enemy_fighter.position + Vector3.UP)
	var player_screen: Vector2 = bridge.rts_camera.unproject_position(player_tank.position + Vector3.UP)
	bridge.call("_handle_world_tap", enemy_screen)
	bridge.call("_handle_world_tap", player_screen)
	if bridge.get("selected_tank") != player_tank:
		push_error("Tapping a friendly live unit did not select it after an enemy was selected")
		quit(1)
		return
	# A platform-cancelled touch must clear all pointer state and must never issue an attack tap.
	logical_units = game.get("units")
	logical_units[0].erase("attack_target")
	logical_units[0].erase("attack_focus_pos")
	game.set("units", logical_units)
	var cancelled_press := InputEventScreenTouch.new()
	cancelled_press.index = 2
	cancelled_press.pressed = true
	cancelled_press.position = enemy_screen
	bridge.call("_unhandled_input", cancelled_press)
	var cancelled_release := InputEventScreenTouch.new()
	cancelled_release.index = 2
	cancelled_release.pressed = false
	cancelled_release.canceled = true
	cancelled_release.position = enemy_screen
	bridge.call("_unhandled_input", cancelled_release)
	logical_units = game.get("units")
	if logical_units[0].has("attack_target") or not (bridge.get("touch_points") as Dictionary).is_empty() or not (bridge.get("touch_start_positions") as Dictionary).is_empty() or not (bridge.get("touch_moved") as Dictionary).is_empty() or bool(bridge.get("touch_multi_gesture")) or float(bridge.get("last_pinch_distance")) != 0.0:
		push_error("A cancelled Android touch was treated as a command or left stale gesture state")
		quit(1)
		return
	bridge.call("_handle_world_tap", enemy_screen)
	logical_units = game.get("units")
	if int(logical_units[0].get("attack_target", -1)) != 1:
		push_error("Tapping an enemy live unit did not issue an attack from the selected friendly unit")
		quit(1)
		return
	var player_position_before: Vector3 = player_tank.position
	bridge.set("has_selected_destination", true)
	bridge.set("selected_destination", player_position_before + Vector3(10.0, 0.0, 0.0))
	bridge.call("_update_showcase_orders", 1.0)
	if player_tank.position.distance_to(player_position_before) > 0.001:
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
	var first_screen: Vector2 = bridge.rts_camera.unproject_position(player_tank.position + Vector3.UP)
	var second_screen: Vector2 = bridge.rts_camera.unproject_position(second_player.position + Vector3.UP)
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

	# Group formations must face the movement direction and occupy distinct slots.
	var formation_forward := Vector3(1.0, 0.0, 0.0)
	var formation_slots: Array[Vector3] = []
	for formation_index in range(4):
		formation_slots.append(bridge.call("_group_formation_offset", formation_index, 4, formation_forward, 2.6))
	if formation_slots[0].distance_to(formation_slots[1]) < 1.0 or formation_slots[0].distance_to(formation_slots[2]) < 1.0 or formation_slots[0].x >= formation_slots[2].x:
		push_error("Group formation slots overlap or are not oriented along the movement direction")
		quit(1)
		return
	if absf(formation_slots[0].z + formation_slots[1].z) > 0.01 or absf(formation_slots[2].z + formation_slots[3].z) > 0.01:
		push_error("Group formation lateral rows are not centered around the destination")
		quit(1)
		return

	# Formation spacing must account for the largest footprint in mixed groups.
	var infantry_formation_unit := Node3D.new()
	infantry_formation_unit.set_meta("unit_type", "infantry")
	var tank_formation_unit := Node3D.new()
	tank_formation_unit.set_meta("unit_type", "tank")
	var naval_formation_unit := Node3D.new()
	naval_formation_unit.set_meta("unit_type", "destroyer")
	var infantry_formation_group: Array[Node3D] = [infantry_formation_unit]
	var armour_formation_group: Array[Node3D] = [infantry_formation_unit, tank_formation_unit]
	var naval_formation_group: Array[Node3D] = [tank_formation_unit, naval_formation_unit]
	if absf(float(bridge.call("_group_formation_spacing", infantry_formation_group)) - 2.4) > 0.01:
		push_error("Infantry formation spacing is not compact enough for foot soldiers")
		quit(1)
		return
	if absf(float(bridge.call("_group_formation_spacing", armour_formation_group)) - 3.8) > 0.01:
		push_error("Mixed infantry and armor formation did not use the tank footprint")
		quit(1)
		return
	if absf(float(bridge.call("_group_formation_spacing", naval_formation_group)) - 10.5) > 0.01:
		push_error("Mixed naval formation did not reserve enough room for long vessels")
		quit(1)
		return
	infantry_formation_unit.free()
	tank_formation_unit.free()
	naval_formation_unit.free()

	# If one selected unit disappears, surviving selected units must remain selected.
	# Keep the enemy target in the logical array to verify it is not cleared accidentally.
	bridge.set("attack_target", enemy_fighter)
	bridge.set("has_selected_destination", true)
	bridge.order_marker.visible = true
	var partially_removed_units: Array[Dictionary] = [multi_units[1], multi_units[2]]
	game.set("units", partially_removed_units)
	game.call("_sync_3d_gameplay_bridge")
	var selection_after_partial_removal: Array = bridge.get("selected_live_units")
	if selection_after_partial_removal.size() != 1 or selection_after_partial_removal[0] != second_player or bridge.get("selected_tank") != second_player:
		push_error("Removing one unit from a group discarded the surviving unit's selection")
		quit(1)
		return
	if bridge.get("attack_target") != enemy_fighter or not bool(bridge.get("has_selected_destination")) or not bridge.order_marker.visible:
		push_error("Removing one selected unit incorrectly cleared a still-valid enemy target or group destination")
		quit(1)
		return

	if bool(game.get_script().get_script_constant_map().get("NAVAL_SYSTEM_ENABLED", false)):
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
			{"pos": Vector2(900.0, 540.0), "kind": "anti_air", "hp": 380, "build_progress": 1.0},
			{"pos": Vector2(740.0, 650.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0},
			{"pos": Vector2(760.0, 650.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0}
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
	
		# Friendly armor must temporarily support landed marines, then resume its original base order.
		var support_test_units: Array[Dictionary] = [
			{"pos": Vector2(400.0, 360.0), "team": "player", "kind": "tank", "hp": 150, "attack_base": true, "attack_cd": 0.0},
			{"pos": Vector2(410.0, 360.0), "team": "player", "kind": "infantry", "hp": 100, "landing_assault": true},
			{"pos": Vector2(450.0, 360.0), "team": "enemy", "kind": "tank", "hp": 150}
		]
		game.set("units", support_test_units)
		game.call("_process", 0.1)
		var supported_units: Array[Dictionary] = game.get("units")
		if not bool(supported_units[0].get("landing_support_active", false)) or int(supported_units[0].get("attack_target", -1)) != 2 or supported_units[0].has("attack_base"):
			push_error("Friendly tank did not divert from its base order to protect the landed marine squad")
			quit(1)
			return
		var cleared_support_units: Array[Dictionary] = [supported_units[0], supported_units[1]]
		game.set("units", cleared_support_units)
		game.call("_process", 0.1)
		var restored_support_units: Array[Dictionary] = game.get("units")
		if bool(restored_support_units[0].get("landing_support_active", false)) or not bool(restored_support_units[0].get("attack_base", false)) or restored_support_units[0].has("attack_target"):
			push_error("Friendly tank did not resume its saved base order after landing threats were cleared")
			quit(1)
			return
	
		# Friendly artillery must also protect landed marines and restore its saved building order.
		var artillery_support_units: Array[Dictionary] = [
			{"pos": Vector2(400.0, 360.0), "team": "player", "kind": "artillery", "hp": 110, "attack_building": 0, "attack_cd": 0.0},
			{"pos": Vector2(410.0, 360.0), "team": "player", "kind": "infantry", "hp": 100, "landing_assault": true},
			{"pos": Vector2(450.0, 360.0), "team": "enemy", "kind": "tank", "hp": 150}
		]
		game.set("units", artillery_support_units)
		game.set("enemy_buildings", [{"pos": Vector2(900.0, 360.0), "kind": "factory", "hp": 500}])
		game.call("_process", 0.1)
		var supported_artillery: Array[Dictionary] = game.get("units")
		if not bool(supported_artillery[0].get("landing_support_active", false)) or int(supported_artillery[0].get("attack_target", -1)) != 2 or supported_artillery[0].has("attack_building"):
			push_error("Friendly artillery did not divert from its building order to protect the landed marine squad")
			quit(1)
			return
		var cleared_artillery_support: Array[Dictionary] = [supported_artillery[0], supported_artillery[1]]
		game.set("units", cleared_artillery_support)
		game.call("_process", 0.1)
		var restored_artillery: Array[Dictionary] = game.get("units")
		if bool(restored_artillery[0].get("landing_support_active", false)) or int(restored_artillery[0].get("attack_building", -1)) != 0 or restored_artillery[0].has("attack_target"):
			push_error("Friendly artillery did not resume its saved building order after landing threats were cleared")
			quit(1)
			return
	
		# Enemy armor must also defend its own landed marines against nearby player ground forces.
		var enemy_landing_support_units: Array[Dictionary] = [
			{"pos": Vector2(500.0, 360.0), "team": "enemy", "kind": "tank", "hp": 150, "target": Vector2(200.0, 360.0), "defense_guard": true, "defense_anchor": Vector2(500.0, 360.0)},
			{"pos": Vector2(510.0, 360.0), "team": "enemy", "kind": "infantry", "hp": 60, "landing_assault": true},
			{"pos": Vector2(550.0, 360.0), "team": "player", "kind": "tank", "hp": 150}
		]
		game.set("units", enemy_landing_support_units)
		game.call("_process", 0.1)
		var enemy_supported_units: Array[Dictionary] = game.get("units")
		if not bool(enemy_supported_units[0].get("landing_support_active", false)) or int(enemy_supported_units[0].get("landing_support_target", -1)) != 2 or int(enemy_supported_units[2].get("hp", 150)) >= 150:
			push_error("Enemy tank did not engage the nearby player tank to protect its landed marines")
			quit(1)
			return
		var cleared_enemy_support: Array[Dictionary] = [enemy_supported_units[0], enemy_supported_units[1]]
		game.set("units", cleared_enemy_support)
		game.call("_process", 0.1)
		var released_enemy_units: Array[Dictionary] = game.get("units")
		if bool(released_enemy_units[0].get("landing_support_active", false)) or released_enemy_units[0].has("landing_support_target"):
			push_error("Enemy tank did not release its temporary landing-defense assignment after the threat disappeared")
			quit(1)
			return
	
		var enemy_artillery_support_units: Array[Dictionary] = [
			{"pos": Vector2(500.0, 360.0), "team": "enemy", "kind": "artillery", "hp": 100, "target": Vector2(200.0, 360.0), "defense_guard": true, "defense_anchor": Vector2(500.0, 360.0)},
			{"pos": Vector2(510.0, 360.0), "team": "enemy", "kind": "infantry", "hp": 60, "landing_assault": true},
			{"pos": Vector2(550.0, 360.0), "team": "player", "kind": "tank", "hp": 150}
		]
		game.set("units", enemy_artillery_support_units)
		game.call("_process", 0.1)
		var enemy_supported_artillery: Array[Dictionary] = game.get("units")
		if not bool(enemy_supported_artillery[0].get("landing_support_active", false)) or int(enemy_supported_artillery[0].get("landing_support_target", -1)) != 2 or int(enemy_supported_artillery[2].get("hp", 150)) >= 150:
			push_error("Enemy artillery did not fire on the nearby player tank to protect its landed marines")
			quit(1)
			return
	
	
	# Enemy ground assaults use role-based lanes: armor leads and infantry follows.
	var formation_origin := Vector2(1000.0, 360.0)
	var formation_target := Vector2(400.0, 360.0)
	var formation_direction := (formation_target - formation_origin).normalized()
	var tank_formation_pos: Vector2 = game.call("_enemy_ground_assault_formation_position", "tank", formation_target, formation_origin, 0)
	var infantry_formation_pos: Vector2 = game.call("_enemy_ground_assault_formation_position", "infantry", formation_target, formation_origin, 1)
	var tank_advance_projection: float = (tank_formation_pos - formation_target).dot(formation_direction)
	var infantry_advance_projection: float = (infantry_formation_pos - formation_target).dot(formation_direction)
	if tank_advance_projection <= infantry_advance_projection or absf(tank_formation_pos.distance_to(formation_target) - sqrt(65.0 * 65.0 + 22.0 * 22.0)) > 0.1 or absf(infantry_formation_pos.distance_to(formation_target) - sqrt(100.0 * 100.0 + 22.0 * 22.0)) > 0.1:
		push_error("Enemy assault formation did not place armor ahead of infantry in staggered lanes")
		quit(1)
		return
	var second_tank_lane: Vector2 = game.call("_enemy_ground_assault_formation_position", "tank", formation_target, formation_origin, 2)
	var second_infantry_lane: Vector2 = game.call("_enemy_ground_assault_formation_position", "infantry", formation_target, formation_origin, 3)
	if absf(second_tank_lane.y - tank_formation_pos.y) < 20.0 or absf(second_infantry_lane.y - infantry_formation_pos.y) < 20.0:
		push_error("Larger enemy formations stacked their second pair on the first pair's assault lanes")
		quit(1)
		return

	# Destroyed enemy structures must not attract attackers or trigger obsolete base-defense responses.
	# Reset all simulation timers and transient combat state so this regression test is independent
	# of the long sequence of AI, missile and combat tests that precedes it.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_strategy", "balanced")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_credits", 0)
	game.set("enemy_missile_timer", 0.0)
	var guard_test_missiles: Array[Dictionary] = []
	var guard_test_buildings: Array[Dictionary] = []
	var guard_test_supply_points: Array[Dictionary] = []
	var guard_test_enemy_buildings: Array[Dictionary] = []
	var guard_test_units: Array[Dictionary] = [
		{"pos": Vector2(450.0, 360.0), "team": "player", "kind": "tank", "hp": 150},
		{"pos": Vector2(900.0, 360.0), "team": "player", "kind": "infantry", "hp": 100}
	]
	game.set("missiles", guard_test_missiles)
	game.set("buildings", guard_test_buildings)
	game.set("supply_points", guard_test_supply_points)
	game.set("enemy_base", Vector2(500.0, 360.0))
	game.set("units", guard_test_units)
	game.set("enemy_buildings", guard_test_enemy_buildings)
	game.set("battlefield_sync_timer", 0.0)
	var target_without_destroyed_assets := int(game.call("_select_enemy_ground_assault_target"))
	guard_test_enemy_buildings.append({"pos": Vector2(900.0, 360.0), "kind": "factory", "hp": 0})
	game.set("enemy_buildings", guard_test_enemy_buildings)
	var target_with_destroyed_assets := int(game.call("_select_enemy_ground_assault_target"))
	if target_with_destroyed_assets != target_without_destroyed_assets:
		push_error("Enemy ground assault target changed after adding a destroyed factory: baseline=" + str(target_without_destroyed_assets) + ", with_destroyed_asset=" + str(target_with_destroyed_assets))
		quit(1)
		return
	var guard_combat_units: Array[Dictionary] = [
		{"pos": Vector2(900.0, 360.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 0.0, "defense_guard": true, "defense_anchor": Vector2(900.0, 360.0)},
		{"pos": Vector2(920.0, 360.0), "team": "player", "kind": "tank", "hp": 150}
	]
	game.set("units", guard_combat_units)
	game.call("_process", 0.1)
	var obsolete_asset_guard: Array[Dictionary] = game.get("units")
	if int(obsolete_asset_guard[1].get("hp", 150)) != 150:
		push_error("Enemy base guard engaged a player tank threatening only a destroyed factory")
		quit(1)
		return
	game.set("enemy_buildings", [])

	# Validate the live coordinated ground assault: armor leads, infantry follows, and artillery holds its firing standoff.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("base_pos", Vector2(180.0, 360.0))
	game.set("enemy_base", Vector2(500.0, 360.0))
	game.set("enemy_strategy", "aggressive")
	var coordinated_assault_units: Array[Dictionary] = [
		{"pos": Vector2(560.0, 360.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 0.0},
		{"pos": Vector2(650.0, 360.0), "team": "enemy", "kind": "infantry", "hp": 100, "attack_cd": 0.0},
		{"pos": Vector2(740.0, 360.0), "team": "enemy", "kind": "artillery", "hp": 100, "attack_cd": 0.0},
		{"pos": Vector2(400.0, 360.0), "team": "player", "kind": "tank", "hp": 150, "attack_cd": 0.0}
	]
	var no_buildings: Array[Dictionary] = []
	var no_supply_points: Array[Dictionary] = []
	game.set("units", coordinated_assault_units)
	game.set("buildings", no_buildings)
	game.set("enemy_buildings", no_buildings)
	game.set("supply_points", no_supply_points)
	game.call("_process", 1.0)
	game.call("_process", 0.1)
	var coordinated_result: Array[Dictionary] = game.get("units")
	var assault_direction := Vector2.LEFT
	var tank_lane_projection: float = (coordinated_result[0].pos - Vector2(400.0, 360.0)).dot(assault_direction)
	var infantry_lane_projection: float = (coordinated_result[1].pos - Vector2(400.0, 360.0)).dot(assault_direction)
	var artillery_standoff: float = coordinated_result[2].pos.distance_to(Vector2(400.0, 360.0))
	if tank_lane_projection <= infantry_lane_projection or coordinated_result[0].pos.x >= coordinated_result[1].pos.x or artillery_standoff > 330.0 or coordinated_result[0].pos.distance_to(Vector2(560.0, 360.0)) < 1.0 or coordinated_result[1].pos.distance_to(Vector2(650.0, 360.0)) < 1.0 or int(coordinated_result[3].hp) >= 150:
		push_error("Live enemy ground assault coordination failed: tank=" + str(coordinated_result[0].pos) + ", infantry=" + str(coordinated_result[1].pos) + ", artillery_distance=" + str(artillery_standoff) + ", player_tank_hp=" + str(coordinated_result[3].hp))
		quit(1)
		return

	# Verify that all four armies have distinct, valid faction balance profiles and that وطن pays more for elite performance.
	var faction_names: Array[String] = ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
	var faction_signatures: Array[String] = []
	for army in faction_names:
		var army_profile: Dictionary = game.call("_faction_profile", army)
		var army_unit_costs: Dictionary = army_profile.get("unit_costs", {})
		if army_profile.size() != 8 or army_unit_costs.is_empty():
			push_error("Faction balance profile is missing combat stats or its unit-cost table for " + army)
			quit(1)
			return
		var army_helicopter: Dictionary = {"kind": "helicopter", "faction": army}
		var army_destroyer: Dictionary = {"kind": "destroyer", "faction": army}
		if int(game.call("_helicopter_cost", army)) != int(army_profile["helicopter_cost"]) or int(game.call("_helicopter_damage", army_helicopter)) != int(army_profile["helicopter_damage"]) or not is_equal_approx(float(game.call("_helicopter_cooldown", army_helicopter)), float(army_profile["helicopter_cooldown"])) or int(game.call("_missile_cost", army)) != int(army_profile["missile_cost"]) or int(game.call("_missile_damage", army)) != int(army_profile["missile_damage"]) or not is_equal_approx(float(game.call("_missile_cooldown", army)), float(army_profile["missile_cooldown"])) or int(game.call("_naval_damage", army_destroyer, -1)) != int(army_profile["naval_damage"]):
			push_error("Faction combat helpers do not apply the balance profile consistently for " + army)
			quit(1)
			return
		var army_signature := str(army_profile["helicopter_cost"]) + ":" + str(army_profile["helicopter_damage"]) + ":" + str(army_profile["helicopter_cooldown"]) + ":" + str(army_profile["missile_cost"]) + ":" + str(army_profile["missile_damage"]) + ":" + str(army_profile["missile_cooldown"]) + ":" + str(army_profile["naval_damage"])
		if faction_signatures.has(army_signature):
			push_error("Two armies unexpectedly share the same faction balance profile")
			quit(1)
			return
		faction_signatures.append(army_signature)
	var watan_profile: Dictionary = game.call("_faction_profile", "وطن")
	if int(game.call("_helicopter_cost", "وطن")) <= int(game.call("_helicopter_cost", "الأمريكي")) or int(game.call("_missile_cost", "وطن")) <= int(game.call("_missile_cost", "الجيش العربي")) or int(game.call("_missile_damage", "وطن")) <= int(game.call("_missile_damage", "الجيش العربي")) or int(watan_profile["naval_damage"]) <= int(game.call("_faction_profile", "الأمريكي")["naval_damage"]) or float(watan_profile["helicopter_cooldown"]) >= float(game.call("_faction_profile", "الجيش العربي")["helicopter_cooldown"]) or float(watan_profile["missile_cooldown"]) >= float(game.call("_faction_profile", "الأمريكي")["missile_cooldown"]):
		push_error("وطن must retain elite damage and faster reload alongside higher equipment costs")
		quit(1)
		return

	# Verify the centralized economy tables feed every live building/unit cost and supply helper.
	var expected_building_costs: Dictionary = {
		"barracks": 250, "factory": 450, "turret": 350, "airfield": 600,
		"anti_air": 400, "missile_silo": 800, "missile_defense": 700,
		"shipyard": 700, "power_plant": 450
	}
	for building_kind in expected_building_costs:
		if int(game.call("_building_cost", String(building_kind))) != int(expected_building_costs[building_kind]):
			push_error("Building economy helper returned an incorrect cost for " + String(building_kind))
			quit(1)
			return
	var expected_unit_costs_by_faction: Dictionary = {
		"الصيني": {"infantry": 100, "tank": 270, "builder": 600, "artillery": 480, "fighter": 520, "destroyer": 900, "carrier": 1600, "submarine": 1050, "landing_craft": 800},
		"الأمريكي": {"infantry": 100, "tank": 300, "builder": 600, "artillery": 450, "fighter": 500, "destroyer": 900, "carrier": 1600, "submarine": 1100, "landing_craft": 800},
		"الجيش العربي": {"infantry": 90, "tank": 315, "builder": 600, "artillery": 430, "fighter": 500, "destroyer": 950, "carrier": 1700, "submarine": 1150, "landing_craft": 800},
		"وطن": {"infantry": 110, "tank": 360, "builder": 650, "artillery": 520, "fighter": 575, "destroyer": 1080, "carrier": 1900, "submarine": 1320, "landing_craft": 920}
	}
	for army in faction_names:
		var expected_unit_costs: Dictionary = expected_unit_costs_by_faction[army]
		for unit_kind in expected_unit_costs:
			if int(game.call("_unit_cost", String(unit_kind), army)) != int(expected_unit_costs[unit_kind]):
				push_error("Unit economy helper returned an incorrect cost for " + String(unit_kind) + " in " + army)
				quit(1)
				return
		if int(game.call("_unit_cost", "helicopter", army)) != int(game.call("_helicopter_cost", army)):
			push_error("Faction-specific helicopter production cost was not applied for " + army)
			quit(1)
			return
	var expected_supply_costs: Dictionary = {
		"infantry": 0, "tank": 1, "builder": 0, "artillery": 2, "fighter": 2,
		"helicopter": 3, "destroyer": 4, "landing_craft": 4,
		"submarine": 5, "carrier": 8
	}
	for unit_kind in expected_supply_costs:
		if int(game.call("_unit_supply_cost", String(unit_kind))) != int(expected_supply_costs[unit_kind]):
			push_error("Unit supply helper returned an incorrect requirement for " + String(unit_kind))
			quit(1)
			return

	# Validate real production transactions: affordability, supply reservation and successful queueing.
	var economy_test_buildings: Array[Dictionary] = [
		{"pos": Vector2(260.0, 360.0), "kind": "power_plant", "hp": 450, "build_progress": 1.0},
		{"pos": Vector2(340.0, 360.0), "kind": "factory", "hp": 500, "build_progress": 1.0}
	]
	game.set("buildings", economy_test_buildings)
	var no_economy_units: Array[Dictionary] = []
	var no_economy_orders: Array[Dictionary] = []
	game.set("units", no_economy_units)
	game.set("production_orders", no_economy_orders)
	game.set("faction", "الأمريكي")
	game.set("credits", 1000)
	game.set("supplies", 0)
	game.call("_enqueue_unit", "tank")
	if int(game.get("credits")) != 1000 or int(game.get("supplies")) != 0 or not (game.get("production_orders") as Array).is_empty():
		push_error("Tank production consumed resources or queued without the required supply")
		quit(1)
		return
	game.set("supplies", 1)
	game.set("credits", 299)
	game.call("_enqueue_unit", "tank")
	if int(game.get("credits")) != 299 or int(game.get("supplies")) != 1 or not (game.get("production_orders") as Array).is_empty():
		push_error("Tank production consumed resources or queued without sufficient credits")
		quit(1)
		return
	game.set("credits", 1000)
	game.call("_enqueue_unit", "tank")
	var economy_orders: Array[Dictionary] = game.get("production_orders")
	if int(game.get("credits")) != 700 or int(game.get("supplies")) != 0 or economy_orders.size() != 1 or String(economy_orders[0].get("kind", "")) != "tank":
		push_error("Successful tank production did not reserve exactly 300 credits and one supply")
		quit(1)
		return

	# Verify supply-point capture, contested-point income pause and timed supply income.
	var controlled_point: Array[Dictionary] = [
		{"pos": Vector2(300.0, 300.0), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"}
	]
	var capturing_units: Array[Dictionary] = [
		{"pos": Vector2(310.0, 300.0), "team": "player", "kind": "infantry", "hp": 60}
	]
	game.set("supply_points", controlled_point)
	game.set("units", capturing_units)
	game.set("credits", 0)
	game.set("supplies", 0)
	game.call("_update_supply_control", 1.0)
	var captured_points: Array[Dictionary] = game.get("supply_points")
	if String(captured_points[0].get("owner", "")) != "player" or int(game.get("credits")) != 4 or float(captured_points[0].get("supply_payout", 0.0)) < 0.99:
		push_error("Player capture did not grant control and the expected first income tick")
		quit(1)
		return
	var contested_units: Array[Dictionary] = [
		{"pos": Vector2(310.0, 300.0), "team": "player", "kind": "infantry", "hp": 60},
		{"pos": Vector2(305.0, 300.0), "team": "enemy", "kind": "infantry", "hp": 60}
	]
	game.set("units", contested_units)
	game.call("_update_supply_control", 8.0)
	var contested_points: Array[Dictionary] = game.get("supply_points")
	if int(game.get("credits")) != 4 or int(game.get("supplies")) != 0 or float(contested_points[0].get("supply_payout", 0.0)) < 0.99:
		push_error("Contested supply point incorrectly generated income")
		quit(1)
		return
	game.set("units", capturing_units)
	game.call("_update_supply_control", 7.0)
	if int(game.get("supplies")) != 1 or int(game.get("credits")) != 32:
		push_error("Secured supply point failed to resume timed credit and supply income")
		quit(1)
		return

	# Verify the opposing army receives the same fair economy from points it controls.
	var enemy_controlled_point: Array[Dictionary] = [
		{"pos": Vector2(500.0, 300.0), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"}
	]
	var enemy_capturing_units: Array[Dictionary] = [
		{"pos": Vector2(505.0, 300.0), "team": "enemy", "kind": "infantry", "hp": 60}
	]
	game.set("supply_points", enemy_controlled_point)
	game.set("units", enemy_capturing_units)
	game.set("enemy_credits", 0)
	game.set("enemy_supplies", 0)
	game.call("_update_supply_control", 8.0)
	var enemy_captured_points: Array[Dictionary] = game.get("supply_points")
	if String(enemy_captured_points[0].get("owner", "")) != "enemy" or int(game.get("enemy_credits")) != 32 or int(game.get("enemy_supplies")) != 1:
		push_error("Enemy capture did not receive the same timed credit and supply income as the player")
		quit(1)
		return

	# Ports must provide double credit income and faster supply generation than standard points.
	var controlled_port: Array[Dictionary] = [
		{"pos": Vector2(420.0, 300.0), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "port"}
	]
	var port_guard_units: Array[Dictionary] = [
		{"pos": Vector2(425.0, 300.0), "team": "player", "kind": "infantry", "hp": 60}
	]
	game.set("supply_points", controlled_port)
	game.set("units", port_guard_units)
	game.set("credits", 0)
	game.set("supplies", 0)
	game.call("_update_supply_control", 1.0)
	if int(game.get("credits")) != 8 or int(game.get("supplies")) != 0:
		push_error("Captured port did not provide its expected double credit income")
		quit(1)
		return
	game.call("_update_supply_control", 5.0)
	var port_income_result: Array[Dictionary] = game.get("supply_points")
	if int(game.get("credits")) != 48 or int(game.get("supplies")) != 1 or float(port_income_result[0].get("supply_payout", 0.0)) > 0.001:
		push_error("Strategic port failed to deliver faster six-second supply income")
		quit(1)
		return

	# Verify enemy armor advances toward a neutral supply objective instead of idling at its base.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("base_pos", Vector2(180.0, 360.0))
	game.set("enemy_base", Vector2(800.0, 300.0))
	game.set("enemy_strategy", "balanced")
	var objective_test_units: Array[Dictionary] = [
		{"pos": Vector2(700.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 0.0},
		{"pos": Vector2(710.0, 300.0), "team": "enemy", "kind": "infantry", "hp": 60, "attack_cd": 0.0}
	]
	var objective_test_points: Array[Dictionary] = [
		{"pos": Vector2(500.0, 300.0), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"},
		{"pos": Vector2(480.0, 400.0), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "port"}
	]
	game.set("units", objective_test_units)
	game.set("buildings", no_buildings)
	game.set("enemy_buildings", no_buildings)
	game.set("supply_points", objective_test_points)
	game.call("_process", 0.5)
	var objective_result: Array[Dictionary] = game.get("units")
	if objective_result.size() != 2 or float(objective_result[0].pos.x) >= 700.0 or float(objective_result[1].pos.x) >= 710.0 or float(objective_result[0].pos.y) <= 300.0 or float(objective_result[1].pos.y) <= 300.0:
		push_error("Enemy armor and infantry failed to prioritize the higher-value port and advance in formation")
		quit(1)
		return

	# Enemy forces prioritize recapturing a player-held supply point over a closer neutral point.
	var recapture_units: Array[Dictionary] = [
		{"pos": Vector2(700.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 0.0}
	]
	var recapture_points: Array[Dictionary] = [
		{"pos": Vector2(600.0, 300.0), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"},
		{"pos": Vector2(560.0, 380.0), "owner": "player", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"}
	]
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_strategy", "balanced")
	game.set("units", recapture_units)
	game.set("supply_points", recapture_points)
	game.set("buildings", no_buildings)
	game.set("enemy_buildings", no_buildings)
	game.call("_process", 0.5)
	var recapture_result: Array[Dictionary] = game.get("units")
	if recapture_result.size() != 1 or float(recapture_result[0].pos.y) <= 300.0:
		push_error("Enemy AI failed to prioritize recapturing a player-held supply point")
		quit(1)
		return

	# Sending a mobile unit to reinforce a threatened resource point must not pull the base guard away.
	var guarded_reinforcement_points: Array[Dictionary] = [
		{"pos": Vector2(520.0, 300.0), "owner": "enemy", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"}
	]
	var guarded_reinforcement_units: Array[Dictionary] = [
		{"pos": Vector2(760.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 0.0},
		{"pos": Vector2(1000.0, 330.0), "team": "enemy", "kind": "tank", "hp": 150, "defense_guard": true, "defense_anchor": Vector2(1000.0, 330.0)},
		{"pos": Vector2(560.0, 300.0), "team": "player", "kind": "infantry", "hp": 60}
	]
	game.set("enemy_base", Vector2(1090.0, 330.0))
	game.set("enemy_credits", 0)
	game.set("units", guarded_reinforcement_units)
	game.set("supply_points", guarded_reinforcement_points)
	game.call("_process", 0.5)
	var guarded_reinforcement_result: Array[Dictionary] = game.get("units")
	if float(guarded_reinforcement_result[0].pos.x) >= 760.0 or guarded_reinforcement_result[1].pos.distance_to(Vector2(1000.0, 330.0)) > 0.1:
		push_error("Enemy AI left its base guard post while dispatching mobile armor to reinforce a supply point")
		quit(1)
		return

	# Defense reserves must cover the main base and a valuable forward production asset.
	var defense_assignment_units: Array[Dictionary] = [
		{"pos": Vector2(1360.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150},
		{"pos": Vector2(1320.0, 360.0), "team": "enemy", "kind": "infantry", "hp": 60},
		{"pos": Vector2(520.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150},
		{"pos": Vector2(560.0, 360.0), "team": "enemy", "kind": "artillery", "hp": 100},
		{"pos": Vector2(900.0, 200.0), "team": "enemy", "kind": "tank", "hp": 150},
		{"pos": Vector2(950.0, 400.0), "team": "enemy", "kind": "infantry", "hp": 60},
		{"pos": Vector2(700.0, 200.0), "team": "enemy", "kind": "tank", "hp": 150},
		{"pos": Vector2(750.0, 400.0), "team": "enemy", "kind": "artillery", "hp": 100}
	]
	var defense_assignment_buildings: Array[Dictionary] = [
		{"pos": Vector2(500.0, 330.0), "kind": "factory", "hp": 500, "build_progress": 1.0}
	]
	game.set("enemy_base", Vector2(1400.0, 330.0))
	game.set("units", defense_assignment_units)
	game.set("enemy_buildings", defense_assignment_buildings)
	game.call("_update_enemy_defense_assignments")
	var assigned_guard_units: Array[Dictionary] = game.get("units")
	var base_guard_assigned := false
	var factory_guard_assigned := false
	var assigned_guard_count := 0
	for assigned_guard in assigned_guard_units:
		if not bool(assigned_guard.get("defense_guard", false)):
			continue
		assigned_guard_count += 1
		var anchor: Vector2 = assigned_guard.get("defense_anchor", Vector2.ZERO)
		if anchor.distance_to(Vector2(1400.0, 330.0)) < 100.0:
			base_guard_assigned = true
		if anchor.distance_to(Vector2(500.0, 330.0)) < 100.0:
			factory_guard_assigned = true
	if assigned_guard_count != 2 or not base_guard_assigned or not factory_guard_assigned:
		push_error("Enemy defense assignment failed to distribute its reserve between the main base and forward factory")
		quit(1)
		return

	# A base guard must leave its anchor and engage when player armor actually threatens the base.
	var base_threat_units: Array[Dictionary] = [
		{"pos": Vector2(1000.0, 330.0), "team": "enemy", "kind": "tank", "hp": 150, "defense_guard": true, "defense_anchor": Vector2(1000.0, 330.0), "attack_cd": 0.0},
		{"pos": Vector2(900.0, 330.0), "team": "player", "kind": "tank", "hp": 150}
	]
	game.set("enemy_base", Vector2(1000.0, 330.0))
	game.set("units", base_threat_units)
	var no_enemy_buildings: Array[Dictionary] = []
	game.set("enemy_buildings", no_enemy_buildings)
	game.set("supply_points", no_supply_points)
	game.call("_process", 0.5)
	var base_guard_response: Array[Dictionary] = game.get("units")
	if int(base_guard_response[1].get("hp", 150)) >= 150:
		push_error("Enemy base guard failed to engage player armor threatening the base")
		quit(1)
		return

	# After a base threat is neutralized, the defender must return to its assigned anchor.
	var returning_guard_units: Array[Dictionary] = [
		{"pos": Vector2(1000.0, 330.0), "team": "enemy", "kind": "tank", "hp": 150, "defense_guard": true, "defense_anchor": Vector2(1000.0, 330.0), "attack_cd": 0.0},
		{"pos": Vector2(845.0, 330.0), "team": "player", "kind": "tank", "hp": 150}
	]
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_strategy", "balanced")
	game.set("enemy_base", Vector2(1000.0, 330.0))
	game.set("enemy_buildings", no_enemy_buildings)
	game.set("buildings", no_buildings)
	game.set("supply_points", no_supply_points)
	game.set("units", returning_guard_units)
	game.call("_process", 0.5)
	var engaged_guard_units: Array[Dictionary] = game.get("units")
	var guard_after_engagement: Vector2 = engaged_guard_units[0].pos
	if guard_after_engagement.distance_to(Vector2(1000.0, 330.0)) < 5.0:
		push_error("Base guard failed to leave its anchor and advance toward the approaching armor")
		quit(1)
		return
	game.call("_process", 0.5)
	engaged_guard_units = game.get("units")
	if int(engaged_guard_units[1].get("hp", 150)) >= 150:
		push_error("Base guard advanced into firing range but failed to engage the approaching armor")
		quit(1)
		return
	engaged_guard_units[1]["hp"] = 0
	game.set("units", engaged_guard_units)
	game.call("_process", 0.5)
	var returning_guard_result: Array[Dictionary] = game.get("units")
	var guard_return_distance: float = returning_guard_result[0].pos.distance_to(Vector2(1000.0, 330.0))
	if guard_return_distance >= guard_after_engagement.distance_to(Vector2(1000.0, 330.0)):
		push_error("Base guard failed to return toward its assigned anchor after the threat was neutralized: before=%s after=%s anchor=%s hp=%s target=%s focus=%s" % [guard_after_engagement, returning_guard_result[0].pos, returning_guard_result[0].get("defense_anchor", Vector2.ZERO), returning_guard_result[0].get("hp", -1), returning_guard_result[0].get("attack_target", -1), returning_guard_result[0].get("attack_focus_pos", Vector2.ZERO)])
		quit(1)
		return

	# Critically damaged mobile troops should fall back to the nearest completed friendly asset.
	var retreat_units: Array[Dictionary] = [
		{"pos": Vector2(500.0, 330.0), "team": "enemy", "kind": "tank", "hp": 30, "attack_cd": 0.0},
		{"pos": Vector2(450.0, 330.0), "team": "player", "kind": "tank", "hp": 150}
	]
	var retreat_assets: Array[Dictionary] = [
		{"pos": Vector2(820.0, 330.0), "kind": "factory", "hp": 500, "build_progress": 1.0},
		{"pos": Vector2(600.0, 330.0), "kind": "barracks", "hp": 0, "build_progress": 1.0}
	]
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_base", Vector2(1100.0, 330.0))
	game.set("enemy_base_hp", 1000)
	game.set("player_base_hp", 1000)
	game.set("enemy_buildings", retreat_assets)
	game.set("buildings", no_buildings)
	game.set("supply_points", no_supply_points)
	game.set("units", retreat_units)
	game.call("_process", 1.0)
	var retreated_units: Array[Dictionary] = game.get("units")
	if float(retreated_units[0].pos.x) <= 500.0 or not bool(retreated_units[0].get("retreating", false)) or int(retreated_units[1].get("hp", 150)) != 150:
		push_error("Critically damaged enemy armor did not disengage: units=%s enemy_base=%s enemy_base_hp=%s battle_result=%s" % [str(retreated_units), str(game.get("enemy_base")), str(game.get("enemy_base_hp")), str(game.get("battle_result"))])
		quit(1)
		return
	var nearest_retreat_asset: Vector2 = game.call("_enemy_retreat_destination", Vector2(500.0, 330.0))
	if nearest_retreat_asset.distance_to(Vector2(820.0, 330.0)) > 0.1:
		push_error("Enemy retreat routing selected a destroyed asset instead of the nearest completed factory")
		quit(1)
		return

	# A withdrawn tank recovers beside its safe factory and rejoins once it reaches 60% health.
	var recovering_tank: Dictionary = {"pos": Vector2(820.0, 330.0), "team": "enemy", "kind": "tank", "hp": 30}
	for recovery_tick in range(8):
		game.call("_update_enemy_retreat", recovering_tank, 1.0)
	if int(recovering_tank.get("hp", 0)) < 90 or bool(recovering_tank.get("retreating", false)):
		push_error("Withdrawn enemy armor failed to recover safely and return to combat readiness: hp=%s retreating=%s" % [recovering_tank.get("hp", 0), recovering_tank.get("retreating", false)])
		quit(1)
		return

	# Assault artillery should take a protected support lane behind the armor instead of driving into the frontline.
	var artillery_support_position: Vector2 = game.call("_enemy_artillery_support_position", Vector2(400.0, 330.0), Vector2(1000.0, 330.0), 2)
	var opposite_artillery_support_position: Vector2 = game.call("_enemy_artillery_support_position", Vector2(400.0, 330.0), Vector2(1000.0, 330.0), 3)
	if artillery_support_position.distance_to(Vector2(650.0, 470.0)) > 0.1 or opposite_artillery_support_position.distance_to(Vector2(650.0, 190.0)) > 0.1:
		push_error("Enemy artillery failed to hold its 250-pixel rear standoff with expanded separated support lanes: first=%s second=%s" % [artillery_support_position, opposite_artillery_support_position])
		quit(1)
		return

	# Enemy assault artillery must advance toward its rear support lane, not the frontline.
	var advancing_artillery_units: Array[Dictionary] = [
		{"pos": Vector2(1000.0, 330.0), "team": "enemy", "kind": "artillery", "hp": 110, "attack_cd": 0.0},
		{"pos": Vector2(400.0, 330.0), "team": "player", "kind": "tank", "hp": 150}
	]
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_base", Vector2(1000.0, 330.0))
	game.set("base_pos", Vector2(180.0, 330.0))
	game.set("units", advancing_artillery_units)
	game.set("buildings", no_buildings)
	game.set("enemy_buildings", no_enemy_buildings)
	game.set("supply_points", no_supply_points)
	game.call("_process", 0.5)
	var advancing_artillery_result: Array[Dictionary] = game.get("units")
	var expected_artillery_lane: Vector2 = game.call("_enemy_artillery_support_position", Vector2(400.0, 330.0), Vector2(1000.0, 330.0), 0)
	if advancing_artillery_result[0].pos.distance_to(expected_artillery_lane) >= Vector2(1000.0, 330.0).distance_to(expected_artillery_lane) or advancing_artillery_result[0].pos.distance_to(Vector2(400.0, 330.0)) < 500.0:
		push_error("Enemy assault artillery failed to advance toward its protected rear support lane")
		quit(1)
		return

	# Once the target enters the artillery firing envelope, the support unit must deal splash damage.
	var firing_artillery_units: Array[Dictionary] = [
		{"pos": Vector2(700.0, 330.0), "team": "enemy", "kind": "artillery", "hp": 110, "attack_cd": 0.0},
		{"pos": Vector2(400.0, 330.0), "team": "player", "kind": "tank", "hp": 150}
	]
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("units", firing_artillery_units)
	game.set("buildings", no_buildings)
	game.set("enemy_buildings", no_enemy_buildings)
	game.set("supply_points", no_supply_points)
	game.call("_process", 0.1)
	var firing_artillery_result: Array[Dictionary] = game.get("units")
	if int(firing_artillery_result[1].get("hp", 150)) >= 150:
		push_error("Enemy assault artillery reached firing range but failed to damage the player frontline")
		quit(1)
		return

	# A base guard must also protect a forward structure when the base itself is not threatened.
	var protected_structure_units: Array[Dictionary] = [
		{"pos": Vector2(1000.0, 330.0), "team": "enemy", "kind": "tank", "hp": 150, "defense_guard": true, "defense_anchor": Vector2(1000.0, 330.0), "attack_cd": 0.0},
		{"pos": Vector2(800.0, 330.0), "team": "player", "kind": "tank", "hp": 150}
	]
	var protected_enemy_buildings: Array[Dictionary] = [
		{"pos": Vector2(820.0, 330.0), "kind": "factory", "hp": 500, "build_progress": 1.0}
	]
	game.set("enemy_base", Vector2(1400.0, 330.0))
	game.set("units", protected_structure_units)
	game.set("supply_points", no_supply_points)
	game.set("enemy_buildings", protected_enemy_buildings)
	game.call("_process", 0.5)
	var structure_guard_response: Array[Dictionary] = game.get("units")
	if float(structure_guard_response[0].pos.distance_to(Vector2(800.0, 330.0))) >= 200.0:
		push_error("Enemy base guard failed to move against armor threatening a forward factory outside the base defense radius")
		quit(1)
		return

	# Guard artillery must fire on armor threatening a forward factory, not only reposition near it.
	var artillery_structure_guard_units: Array[Dictionary] = [
		{"pos": Vector2(1000.0, 330.0), "team": "enemy", "kind": "artillery", "hp": 110, "defense_guard": true, "defense_anchor": Vector2(1000.0, 330.0), "attack_cd": 0.0},
		{"pos": Vector2(800.0, 330.0), "team": "player", "kind": "tank", "hp": 150}
	]
	game.set("units", artillery_structure_guard_units)
	game.set("enemy_base", Vector2(1400.0, 330.0))
	game.set("enemy_buildings", protected_enemy_buildings)
	game.set("supply_points", no_supply_points)
	game.call("_process", 0.5)
	var artillery_structure_guard_result: Array[Dictionary] = game.get("units")
	if int(artillery_structure_guard_result[1].get("hp", 150)) >= 150:
		push_error("Enemy guard artillery failed to fire on armor threatening a forward factory")
		quit(1)
		return

	# Enemy armor reinforces an owned supply point when player forces threaten an undefended position.
	var threatened_enemy_point: Array[Dictionary] = [
		{"pos": Vector2(520.0, 300.0), "owner": "enemy", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"}
	]
	var reinforcement_units: Array[Dictionary] = [
		{"pos": Vector2(760.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 0.0},
		{"pos": Vector2(560.0, 300.0), "team": "player", "kind": "infantry", "hp": 60}
	]
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_strategy", "balanced")
	game.set("units", reinforcement_units)
	game.set("supply_points", threatened_enemy_point)
	game.set("buildings", no_buildings)
	game.set("enemy_buildings", no_buildings)
	game.call("_process", 0.5)
	var reinforced_units: Array[Dictionary] = game.get("units")
	if float(reinforced_units[0].pos.x) >= 760.0 or float(reinforced_units[0].pos.x) <= 520.0:
		push_error("Enemy armor failed to reinforce its threatened, undefended supply point")
		quit(1)
		return
	# A point that already has an enemy garrison must not pull a second unit away.
	var held_point_units: Array[Dictionary] = [
		{"pos": Vector2(540.0, 300.0), "team": "enemy", "kind": "infantry", "hp": 60},
		{"pos": Vector2(760.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 0.0},
		{"pos": Vector2(560.0, 300.0), "team": "player", "kind": "infantry", "hp": 60}
	]
	game.set("units", held_point_units)
	var held_point_assignment: int = game.call("_enemy_supply_reinforcement_point", 1)
	if held_point_assignment != -1:
		push_error("Enemy AI dispatched extra armor to a supply point that already had a garrison")
		quit(1)
		return

	# Start this identity-family check from a clean bridge so its stable IDs are deterministic.
	var empty_game_units: Array[Dictionary] = []
	game.set("units", empty_game_units)
	game.call("_sync_3d_gameplay_bridge")
	bridge.set("next_game_unit_sync_id", 1)

	# Every production unit family must receive a stable live 3D proxy, not only tanks.
	var all_unit_families: Array[Dictionary] = [
		{"pos": Vector2(180.0, 180.0), "team": "player", "kind": "infantry", "faction": "الجيش العربي", "hp": 55.0, "max_hp": 60.0},
		{"pos": Vector2(260.0, 180.0), "team": "player", "kind": "artillery", "faction": "وطن", "hp": 95.0, "max_hp": 110.0},
		{"pos": Vector2(340.0, 180.0), "team": "player", "kind": "helicopter", "faction": "الأمريكي", "hp": 170.0, "max_hp": 180.0},
		{"pos": Vector2(660.0, 180.0), "team": "enemy", "kind": "fighter", "faction": "الصيني", "hp": 120.0, "max_hp": 120.0}
	]
	var expected_live_keys: Array[String] = ["player|1|infantry", "player|2|artillery", "player|3|helicopter", "enemy|4|fighter"]
	if bool(bridge.get_script().get_script_constant_map().get("NAVAL_PRESENTATION_ENABLED", false)):
		all_unit_families.append_array([
			{"pos": Vector2(420.0, 180.0), "team": "enemy", "kind": "destroyer", "faction": "الصيني", "hp": 240.0, "max_hp": 260.0},
			{"pos": Vector2(500.0, 180.0), "team": "enemy", "kind": "carrier", "faction": "الصيني", "hp": 500.0, "max_hp": 520.0},
			{"pos": Vector2(580.0, 180.0), "team": "enemy", "kind": "submarine", "faction": "الصيني", "hp": 190.0, "max_hp": 210.0},
			{"pos": Vector2(660.0, 180.0), "team": "enemy", "kind": "landing_craft", "faction": "الأمريكي", "hp": 300.0, "max_hp": 320.0}
		])
		expected_live_keys.append_array(["enemy|4|destroyer", "enemy|5|carrier", "enemy|6|submarine", "enemy|7|landing_craft"])
	game.set("units", all_unit_families)
	game.call("_sync_3d_gameplay_bridge")
	if bridge.game_unit_nodes.size() != all_unit_families.size():
		push_error("Live bridge did not create one stable 3D proxy for every enabled unit family")
		quit(1)
		return
	for family_index in range(expected_live_keys.size()):
		var family_node := bridge.game_unit_nodes.get(expected_live_keys[family_index]) as Node3D
		if family_node == null or absf(float(family_node.get_meta("health", -1.0)) - float(all_unit_families[family_index].hp)) > 0.001 or absf(float(family_node.get_meta("max_health", -1.0)) - float(all_unit_families[family_index].max_hp)) > 0.001:
			push_error("Live bridge lost unit-family identity or health metadata for %s" % expected_live_keys[family_index])
			quit(1)
			return

	# Switching between 2D and 3D is presentation-only: preserve live selection,
	# authoritative simulation state, and stable visual proxies across repeated toggles.
	var preserved_infantry := bridge.game_unit_nodes.get("player|1|infantry") as Node3D
	var preserved_artillery := bridge.game_unit_nodes.get("player|2|artillery") as Node3D
	var preserved_enemy := bridge.game_unit_nodes.get("enemy|4|fighter") as Node3D
	if preserved_infantry == null or preserved_artillery == null or preserved_enemy == null:
		push_error("Could not locate units for 2D/3D view-switch preservation validation")
		quit(1)
		return
	var preserved_selection: Array[Node3D] = [preserved_infantry, preserved_artillery]
	bridge.call("_set_live_selection", preserved_selection)
	bridge.set("attack_target", preserved_enemy)
	bridge.set("has_selected_destination", true)
	bridge.set("selected_destination", preserved_infantry.position + Vector3(4.0, 0.0, 0.0))
	game.set("credits", 875)
	game.set("player_base_hp", 640)
	var preserved_unit_position: Vector2 = (game.get("units") as Array)[0].pos
	var preserved_unit_health: float = float((game.get("units") as Array)[0].hp)
	for toggle_cycle in range(3):
		game.call("_set_3d_view_enabled", false)
		if bridge.visible or bridge.process_mode != Node.PROCESS_MODE_DISABLED:
			push_error("3D presentation must remain hidden and paused during a 2D toggle cycle")
			quit(1)
			return
		game.call("_set_3d_view_enabled", true)
		if not bridge.visible or bridge.process_mode == Node.PROCESS_MODE_DISABLED:
			push_error("3D presentation did not reactivate after a view toggle cycle")
			quit(1)
			return
		var selected_after_toggle: Array = bridge.get("selected_live_units")
		if selected_after_toggle.size() != 2 or not selected_after_toggle.has(preserved_infantry) or not selected_after_toggle.has(preserved_artillery) or bridge.get("selected_tank") != preserved_infantry:
			push_error("2D/3D view switching changed the selected friendly unit roster")
			quit(1)
			return
		if bridge.get("attack_target") != preserved_enemy or not bool(bridge.get("has_selected_destination")):
			push_error("2D/3D view switching discarded the active visual attack target or destination marker state")
			quit(1)
			return
		if bridge.game_unit_nodes.get("player|1|infantry") != preserved_infantry or bridge.game_unit_nodes.get("player|2|artillery") != preserved_artillery:
			push_error("2D/3D view switching recreated stable live unit proxies")
			quit(1)
			return
		var current_units: Array = game.get("units")
		if int(game.get("credits")) != 875 or int(game.get("player_base_hp")) != 640 or current_units[0].pos != preserved_unit_position or absf(float(current_units[0].hp) - preserved_unit_health) > 0.001:
			push_error("Presentation switching mutated authoritative RTS economy, base health, or unit state")
			quit(1)
			return

	# A fresh 3D move order after view switching must still reach the authoritative 2D unit record.
	var post_toggle_order_units: Array = game.get("units")
	var expected_post_toggle_target := game.get_viewport().get_visible_rect().size * 0.5
	game.call("_on_3d_gameplay_order_issued", "player|1|infantry", "move", Vector3.ZERO, "")
	post_toggle_order_units = game.get("units")
	if not post_toggle_order_units[0].has("target") or (post_toggle_order_units[0].target as Vector2).distance_to(expected_post_toggle_target) > 1.0:
		push_error("A 3D move order issued after repeated view switching failed to update the authoritative 2D unit destination")
		quit(1)
		return

	# Attack and guard commands must also survive the same live bridge after view changes.
	game.call("_on_3d_gameplay_order_issued", "player|1|infantry", "attack", Vector3.ZERO, "enemy|4|fighter")
	post_toggle_order_units = game.get("units")
	if int(post_toggle_order_units[0].get("attack_target", -1)) != 3 or post_toggle_order_units[0].has("target"):
		push_error("A 3D attack order after view switching failed to bind the authoritative enemy target")
		quit(1)
		return
	game.call("_on_3d_gameplay_order_issued", "player|1|infantry", "guard", Vector3.ZERO, "")
	post_toggle_order_units = game.get("units")
	if not bool(post_toggle_order_units[0].get("guard_active", false)) or post_toggle_order_units[0].has("attack_target") or post_toggle_order_units[0].has("target"):
		push_error("A 3D guard order after view switching failed to replace the previous combat order")
		quit(1)
		return

	# Removing a selected live unit must also clear selection and stale attack targets.
	var selected_before_cleanup := bridge.game_unit_nodes.get("player|1|infantry") as Node3D
	if selected_before_cleanup == null:
		push_error("Could not locate a friendly live unit for stale-selection cleanup validation")
		quit(1)
		return
	var selected_units_for_cleanup: Array[Node3D] = [selected_before_cleanup]
	bridge.call("_set_live_selection", selected_units_for_cleanup)
	bridge.set("attack_target", selected_before_cleanup)
	bridge.set("has_selected_destination", true)
	bridge.order_marker.visible = true
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
	if not (bridge.get("selected_live_units") as Array).is_empty() or is_instance_valid(bridge.get("selected_tank")) or is_instance_valid(bridge.get("attack_target")) or bool(bridge.get("has_selected_destination")) or bridge.selection_ring.visible or bridge.order_marker.visible:
		push_error("Removing a selected live unit left stale selection, attack target, destination, or UI markers")
		quit(1)
		return

	print("Live 2D-to-3D gameplay bridge: hidden-by-default state, two-team unit/building sync, health/progress updates, stable identity, stale selection cleanup and stale node cleanup passed")
	game.queue_free()
	# Let deferred node destruction and the audio server finish releasing
	# playback instances before checking for ObjectDB leaks at process exit.
	for cleanup_frame in range(4):
		await process_frame
	quit(0)
