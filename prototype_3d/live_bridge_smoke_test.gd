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
	game.set("units", [])
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
