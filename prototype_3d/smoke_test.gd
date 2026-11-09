extends SceneTree

func _initialize() -> void:
	var packed := load("res://prototype_3d/battlefield_3d.tscn") as PackedScene
	if packed == null:
		push_error("Could not load the 3D battlefield scene")
		quit(1)
		return

	var battlefield := packed.instantiate()
	root.add_child(battlefield)
	await process_frame

	if not battlefield is Node3D:
		push_error("The 3D battlefield root is not Node3D")
		quit(1)
		return

	var building_kinds := ["command", "barracks", "factory", "airfield", "power_plant", "turret", "anti_air", "missile_silo", "missile_defense", "shipyard"]
	for building_index in range(building_kinds.size()):
		var kind: String = building_kinds[building_index]
		var test_building := battlefield.call("spawn_game_building", kind, Vector3(float(building_index) * 12.0 - 54.0, 0.0, 18.0), "test", Color(0.32, 0.38, 0.30), 0.35) as Node3D
		if test_building == null or not test_building.has_meta("construction_progress"):
			push_error("Runtime 3D building creation failed for: " + kind)
			quit(1)
			return
		if absf(float(test_building.get_meta("construction_progress")) - 0.35) > 0.001:
			push_error("Construction progress was not stored for: " + kind)
			quit(1)
			return
		var progress_fill := test_building.get_node_or_null("ConstructionProgressFill") as MeshInstance3D
		if progress_fill == null or not progress_fill.visible:
			push_error("Construction progress indicator missing for: " + kind)
			quit(1)
			return
		battlefield.call("update_game_building_progress", test_building, 1.0)
		if absf(float(test_building.get_meta("construction_progress")) - 1.0) > 0.001 or progress_fill.visible:
			push_error("Building completion update failed for: " + kind)
			quit(1)
			return

	var player_records: Array = [
		{"pos": Vector2(250.0, 150.0), "kind": "factory", "build_progress": 0.4, "hp": 500}
	]
	var enemy_records: Array = [
		{"pos": Vector2(750.0, 450.0), "kind": "anti_air", "build_progress": 1.0, "hp": 380}
	]
	var map_rect := Rect2(0.0, 0.0, 1000.0, 600.0)
	var synced := int(battlefield.call("sync_game_buildings", player_records, enemy_records, map_rect, "american", "chinese"))
	if synced != 2 or battlefield.game_building_nodes.size() != 2:
		push_error("2D-to-3D building synchronization did not create both counterparts")
		quit(1)
		return
	var player_key := "player|factory|250.00|150.00"
	var player_3d := battlefield.game_building_nodes.get(player_key) as Node3D
	if player_3d == null or player_3d.get_meta("source_team", "") != "player":
		push_error("Player building mapping metadata is incorrect")
		quit(1)
		return
	if player_3d.position.distance_to(Vector3(-7.98, 0.0, -7.98)) > 0.02:
		push_error("2D map coordinates were not transformed into the expected 3D arena position")
		quit(1)
		return
	player_records[0]["build_progress"] = 0.8
	battlefield.call("sync_game_buildings", player_records, enemy_records, map_rect, "american", "chinese")
	if absf(float(player_3d.get_meta("construction_progress")) - 0.8) > 0.001:
		push_error("2D building construction progress did not update in 3D")
		quit(1)
		return
	enemy_records.clear()
	synced = int(battlefield.call("sync_game_buildings", player_records, enemy_records, map_rect, "american", "chinese"))
	if synced != 1 or battlefield.game_building_nodes.size() != 1:
		push_error("Removed gameplay buildings were not reconciled from the 3D scene")
		quit(1)
		return

	print("3D battlefield, 10 building archetypes, and 2D-to-3D building sync smoke tests passed")
	battlefield.queue_free()
	await process_frame
	quit(0)
