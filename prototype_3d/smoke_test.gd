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

	var unit_records: Array = [
		{"pos": Vector2(200.0, 120.0), "team": "player", "kind": "tank", "faction": "american", "hp": 150, "max_hp": 200, "facing": 0.5},
		{"pos": Vector2(500.0, 300.0), "team": "player", "kind": "infantry", "faction": "american", "hp": 60},
		{"pos": Vector2(800.0, 480.0), "team": "enemy", "kind": "fighter", "faction": "chinese", "hp": 120}
	]
	var unit_count := int(battlefield.call("sync_game_units", unit_records, map_rect))
	if unit_count != 3 or battlefield.game_unit_nodes.size() != 3:
		push_error("Gameplay unit synchronization did not create all 3D counterparts")
		quit(1)
		return
	var tank_key := "player|1|tank"
	var tank_3d := battlefield.game_unit_nodes.get(tank_key) as Node3D
	if tank_3d == null or tank_3d.get_meta("gameplay_unit_kind", "") != "tank" or absf(float(tank_3d.get_meta("max_health", 0.0)) - 200.0) > 0.001:
		push_error("Synchronized tank metadata or maximum health is incorrect")
		quit(1)
		return
	if tank_3d.position.distance_to(Vector3(-9.576, 0.0, -9.576)) > 0.02:
		push_error("Gameplay unit map-to-world transform is incorrect")
		quit(1)
		return
	unit_records[0]["pos"] = Vector2(300.0, 180.0)
	unit_records[0]["hp"] = 90
	battlefield.call("sync_game_units", unit_records, map_rect)
	battlefield.call("_update_showcase_health_bars")
	var tank_health_fill := battlefield.showcase_health_bars.get(tank_3d) as MeshInstance3D
	if tank_3d.position.distance_to(Vector3(-6.384, 0.0, -6.384)) > 0.03 or absf(float(tank_3d.get_meta("health")) - 90.0) > 0.001 or tank_health_fill == null or absf(tank_health_fill.scale.x - 0.45) > 0.02:
		push_error("Gameplay unit movement, facing, or proportional health synchronization failed")
		quit(1)
		return
	var infantry_key := "player|2|infantry"
	var infantry_3d := battlefield.game_unit_nodes.get(infantry_key) as Node3D
	unit_records.remove_at(0)
	unit_count = int(battlefield.call("sync_game_units", unit_records, map_rect))
	if unit_count != 2 or battlefield.game_unit_nodes.size() != 2 or battlefield.game_unit_nodes.has(tank_key) or battlefield.game_unit_nodes.get(infantry_key) != infantry_3d:
		push_error("Stable gameplay unit identities or stale unit removal failed")
		quit(1)
		return

	# Verify dedicated artillery and naval silhouettes plus the shared combat-array invariant.
	var archetype_kinds := ["artillery", "destroyer", "carrier", "submarine", "landing_craft"]
	var archetype_records: Array = []
	for archetype_index in range(archetype_kinds.size()):
		archetype_records.append({
			"pos": Vector2(120.0 + float(archetype_index) * 150.0, 420.0),
			"team": "player",
			"kind": archetype_kinds[archetype_index],
			"faction": "american",
			"hp": 180,
			"max_hp": 240
		})
	var archetype_count := int(battlefield.call("sync_game_units", archetype_records, map_rect))
	if archetype_count != archetype_kinds.size():
		push_error("Dedicated artillery and naval unit archetypes did not synchronize")
		quit(1)
		return
	if battlefield.showcase_turrets.size() != battlefield.showcase_tanks.size():
		push_error("Unit aim pivots are not index-aligned with selectable units")
		quit(1)
		return
	for archetype_index in range(archetype_kinds.size()):
		var kind: String = archetype_kinds[archetype_index]
		var key := "player|%s|%s" % [str(archetype_index + 4), kind]
		var archetype := battlefield.game_unit_nodes.get(key) as Node3D
		if archetype == null or archetype.get_meta("gameplay_unit_kind", "") != kind or archetype.get_meta("unit_type", "") != kind:
			push_error("Dedicated 3D unit identity or visual archetype missing for: " + kind)
			quit(1)
			return
		if archetype.get_node_or_null("HealthBar") == null or archetype.get_child_count() < 3:
			push_error("Health bar or model geometry missing for: " + kind)
			quit(1)
			return
		if absf(float(archetype.get_meta("max_health", 0.0)) - 240.0) > 0.001:
			push_error("Maximum health was not preserved for: " + kind)
			quit(1)
			return
	var submarine := battlefield.game_unit_nodes.get("player|7|submarine") as Node3D
	var destroyer := battlefield.game_unit_nodes.get("player|5|destroyer") as Node3D
	if battlefield.get_node_or_null("CoastalWater") == null or battlefield.get_node_or_null("CoastalShore") == null:
		push_error("Coastal water or shoreline is missing from the 3D battlefield")
		quit(1)
		return
	if submarine == null or submarine.position.y > -0.5:
		push_error("Submarine was not placed beneath the coastal waterline")
		quit(1)
		return
	if destroyer == null or destroyer.position.y <= 0.0 or destroyer.get_node_or_null("Hull") == null:
		push_error("Surface ship hull was not positioned at the water surface")
		quit(1)
		return
	if battlefield.naval_propellers.size() < 6 or destroyer.get_node_or_null("PropellerLeft") == null or destroyer.get_node_or_null("PropellerRight") == null:
		push_error("Surface naval vessels are missing animated propeller assemblies")
		quit(1)
		return
	var propeller_before: float = battlefield.naval_propellers[0].rotation.z
	battlefield._update_naval_animation(0.1)
	if battlefield.naval_propellers[0].rotation.z <= propeller_before:
		push_error("Naval propeller animation did not advance")
		quit(1)
		return
	# Verify a carrier launches a visible patrol aircraft and starts its sortie cooldown.
	var test_carrier := battlefield.game_unit_nodes.get("player|6|carrier") as Node3D
	if test_carrier == null:
		push_error("Carrier unit missing before air operations test")
		quit(1)
		return
	battlefield.call("_update_carrier_air_operations", 0.1)
	if battlefield.carrier_aircraft.size() != 1 or float(test_carrier.get_meta("air_ops_cooldown", 0.0)) <= 0.0:
		push_error("Carrier failed to launch a patrol aircraft or set its sortie cooldown")
		quit(1)
		return
	var launched_aircraft := battlefield.carrier_aircraft[0].get("node") as Node3D
	if launched_aircraft == null or launched_aircraft.get_child_count() < 3 or launched_aircraft.global_position.y <= test_carrier.global_position.y:
		push_error("Carrier patrol aircraft geometry or takeoff altitude is invalid")
		quit(1)
		return

	# Verify the patrol aircraft descends onto the carrier deck before despawning.
	battlefield.call("_update_carrier_air_operations", 8.7)
	if not is_instance_valid(launched_aircraft) or not launched_aircraft.is_inside_tree():
		push_error("Carrier patrol aircraft disappeared before completing its deck approach")
		quit(1)
		return
	var landing_offset: Vector3 = launched_aircraft.position - test_carrier.position
	if absf(landing_offset.y - 1.48) > 0.20 or Vector2(landing_offset.x, landing_offset.z).length() > 0.45:
		push_error("Carrier patrol aircraft did not reach the carrier deck approach zone")
		quit(1)
		return
	battlefield.call("_update_carrier_air_operations", 0.3)
	if battlefield.carrier_aircraft.size() != 0 or is_instance_valid(launched_aircraft):
		push_error("Carrier patrol aircraft was not recovered after landing")
		quit(1)
		return

	var stable_artillery := battlefield.game_unit_nodes.get("player|4|artillery") as Node3D
	battlefield.call("sync_game_units", archetype_records, map_rect)
	if battlefield.game_unit_nodes.get("player|4|artillery") != stable_artillery or battlefield.showcase_turrets.size() != battlefield.showcase_tanks.size():
		push_error("Repeated naval/artillery sync created duplicates or broke aim-pivot alignment")
		quit(1)
		return

	# Exercise automatic destroyer target selection and its firing cadence against a hostile contact.
	var naval_combat_records: Array = [
		{"pos": Vector2(42.0, 50.0), "team": "player", "kind": "destroyer", "faction": "american", "hp": 180, "max_hp": 240},
		{"pos": Vector2(55.0, 50.0), "team": "enemy", "kind": "tank", "faction": "chinese", "hp": 150, "max_hp": 150}
	]
	battlefield.call("sync_game_units", naval_combat_records, map_rect)
	var combat_destroyer := battlefield.game_unit_nodes.get("player|9|destroyer") as Node3D
	var hostile_contact := battlefield.game_unit_nodes.get("enemy|10|tank") as Node3D
	if combat_destroyer == null or hostile_contact == null or battlefield.call("_find_naval_target", combat_destroyer, "player", 15.0) != hostile_contact:
		push_error("Destroyer did not acquire the nearest hostile unit in range")
		quit(1)
		return
	var child_count_before_fire := battlefield.get_child_count()
	battlefield.call("_update_naval_combat", 0.1)
	if absf(float(combat_destroyer.get_meta("naval_fire_cooldown", 0.0)) - 2.4) > 0.001 or battlefield.get_child_count() <= child_count_before_fire:
		push_error("Destroyer failed to fire a naval shell or set its firing cooldown")
		quit(1)
		return

	print("3D battlefield, 10 building archetypes, building sync, health sync, artillery, naval combat and carrier flight operations passed")
	battlefield.queue_free()
	await process_frame
	quit(0)
