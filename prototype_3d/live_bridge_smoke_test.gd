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
	var enemy_screen := bridge.rts_camera.unproject_position(enemy_fighter.global_position + Vector3.UP)
	var player_screen := bridge.rts_camera.unproject_position(player_tank.global_position + Vector3.UP)
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
