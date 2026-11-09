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
	if bridge.visible:
		push_error("3D gameplay bridge must remain hidden until the 3D view is explicitly enabled")
		quit(1)
		return

	game.set("game_started", true)
	game.set("faction", "الأمريكي")
	game.set("units", [
		{"pos": Vector2(200.0, 160.0), "team": "player", "kind": "tank", "faction": "american", "hp": 75.0, "max_hp": 150.0},
		{"pos": Vector2(800.0, 420.0), "team": "enemy", "kind": "fighter", "faction": "chinese", "hp": 120.0, "max_hp": 120.0}
	])
	game.set("buildings", [
		{"pos": Vector2(260.0, 220.0), "kind": "factory", "build_progress": 0.65, "hp": 500}
	])
	game.set("enemy_buildings", [
		{"pos": Vector2(820.0, 430.0), "kind": "turret", "build_progress": 1.0, "hp": 400}
	])
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
	var updated_units: Array = game.get("units")
	updated_units[0]["pos"] = Vector2(300.0, 240.0)
	updated_units[0]["hp"] = 45.0
	game.set("units", updated_units)
	game.call("_sync_3d_gameplay_bridge")
	if bridge.game_unit_nodes.get("player|1|tank") != original_tank or absf(float(player_tank.get_meta("health", 0.0)) - 45.0) > 0.001:
		push_error("Live bridge recreated a unit instead of updating its stable 3D counterpart")
		quit(1)
		return

	game.set("units", [])
	game.set("buildings", [])
	game.set("enemy_buildings", [])
	game.call("_sync_3d_gameplay_bridge")
	if not bridge.game_unit_nodes.is_empty() or not bridge.game_building_nodes.is_empty():
		push_error("Live bridge did not remove stale 3D counterparts after gameplay records were cleared")
		quit(1)
		return

	print("Live 2D-to-3D gameplay bridge: hidden-by-default state, two-team unit/building sync, health/progress updates, stable identity and stale cleanup passed")
	game.queue_free()
	await process_frame
	quit(0)
