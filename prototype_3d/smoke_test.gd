extends SceneTree

func _has_faction_insignia_color(unit: Node, badge_path: NodePath, expected: Color) -> bool:
	if unit == null:
		return false
	var badge := unit.get_node_or_null(badge_path) as MeshInstance3D
	if badge == null:
		return false
	var material := badge.material_override as StandardMaterial3D
	if material == null:
		return false
	var actual := material.albedo_color
	return absf(actual.r - expected.r) <= 0.001 and absf(actual.g - expected.g) <= 0.001 and absf(actual.b - expected.b) <= 0.001


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

	# Verify individual tactical paths for a selected group and clear them when its order ends.
	var path_test_unit := Node3D.new()
	path_test_unit.set_meta("unit_type", "tank")
	path_test_unit.set_meta("source_team", "player")
	path_test_unit.set_meta("source_unit_key", "player|path-test|tank")
	var path_test_infantry := Node3D.new()
	path_test_infantry.set_meta("unit_type", "infantry")
	path_test_infantry.set_meta("source_team", "player")
	path_test_infantry.set_meta("source_unit_key", "player|path-test|infantry")
	battlefield.add_child(path_test_unit)
	battlefield.add_child(path_test_infantry)
	var path_test_group: Array[Node3D] = [path_test_unit, path_test_infantry]
	battlefield.call("_set_live_selection", path_test_group)
	battlefield.set("selected_destination", Vector3(4.0, 0.0, 2.0))
	battlefield.set("has_selected_destination", true)
	battlefield.call("_update_order_path_visual")
	var path_visual := battlefield.get("order_path_instance") as MeshInstance3D
	var path_mesh := battlefield.get("order_path_mesh") as ImmediateMesh
	if path_visual == null or path_mesh == null or not path_visual.visible or path_mesh.get_surface_count() != 1:
		push_error("Tactical group paths did not render a visible line surface")
		quit(1)
		return
	if path_mesh.surface_get_array_len(0) != 4:
		push_error("Tactical group path did not render one separate segment per selected unit")
		quit(1)
		return
	battlefield.set("has_selected_destination", false)
	battlefield.call("_update_order_path_visual")
	if path_visual.visible or path_mesh.get_surface_count() != 0:
		push_error("Tactical group paths remained visible after the movement order was cleared")
		quit(1)
		return
	var empty_path_group: Array[Node3D] = []
	battlefield.call("_set_live_selection", empty_path_group)
	path_test_unit.queue_free()
	path_test_infantry.queue_free()

	var sun_light := battlefield.get("sun_light") as DirectionalLight3D
	if sun_light == null:
		push_error("3D battlefield mobile quality profile did not expose its directional light")
		quit(1)
		return
	if sun_light.shadow_enabled == OS.has_feature("mobile"):
		push_error("3D battlefield did not select the expected default shadow profile for this platform")
		quit(1)
		return
	battlefield.call("_apply_mobile_quality_profile", true)
	if sun_light.shadow_enabled:
		push_error("Mobile quality profile must disable expensive real-time directional shadows")
		quit(1)
		return
	battlefield.call("_apply_mobile_quality_profile", false)
	if not sun_light.shadow_enabled:
		push_error("Desktop quality profile should retain directional shadows")
		quit(1)
		return
	battlefield.call("_apply_mobile_quality_profile", OS.has_feature("mobile"))

	# Verify the movement destination marker has four readable tactical reticle ticks.
	var destination_marker := battlefield.get("order_marker") as MeshInstance3D
	if destination_marker == null or destination_marker.get_child_count() != 4:
		push_error("Movement destination marker is missing its four-point tactical reticle")
		quit(1)
		return
	for reticle_index in range(4):
		var reticle_tick := destination_marker.get_node_or_null("DestinationReticle%d" % reticle_index) as MeshInstance3D
		if reticle_tick == null or not reticle_tick.mesh is BoxMesh:
			push_error("Movement destination reticle tick is missing or has invalid geometry")
			quit(1)
			return

	# Verify camera zoom limits, arena pan bounds, and the two-finger mobile gesture.
	var camera_height_before: float = float(battlefield.get("camera_height"))
	battlefield.call("_zoom_camera", 0.01)
	if absf(float(battlefield.get("camera_height")) - 14.0) > 0.001:
		push_error("RTS camera zoomed below its minimum safe height")
		quit(1)
		return
	battlefield.call("_zoom_camera", 1000.0)
	if absf(float(battlefield.get("camera_height")) - 48.0) > 0.001:
		push_error("RTS camera zoomed above its maximum safe height")
		quit(1)
		return
	battlefield.set("camera_focus", Vector3.ZERO)
	battlefield.call("_update_camera_pose")
	battlefield.call("_pan_camera", Vector2(50000.0, -50000.0))
	var bounded_focus: Vector3 = battlefield.get("camera_focus")
	if absf(bounded_focus.x) > 17.641 or absf(bounded_focus.z) > 17.641:
		push_error("RTS camera pan escaped the playable arena bounds")
		quit(1)
		return
	battlefield.set("camera_focus", Vector3.ZERO)
	battlefield.set("camera_height", camera_height_before)
	battlefield.call("_update_camera_pose")
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 0
	first_touch.position = Vector2(100.0, 100.0)
	first_touch.pressed = true
	battlefield.call("_unhandled_input", first_touch)
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.position = Vector2(200.0, 100.0)
	second_touch.pressed = true
	battlefield.call("_unhandled_input", second_touch)
	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(260.0, 120.0)
	battlefield.call("_unhandled_input", pinch_drag)
	var pinch_focus: Vector3 = battlefield.get("camera_focus")
	if float(battlefield.get("camera_height")) >= camera_height_before or pinch_focus.length() <= 0.01:
		push_error("Two-finger mobile gesture did not apply pinch zoom and camera pan")
		quit(1)
		return
	var release_second := InputEventScreenTouch.new()
	release_second.index = 1
	release_second.position = pinch_drag.position
	release_second.pressed = false
	battlefield.call("_unhandled_input", release_second)
	var release_first := InputEventScreenTouch.new()
	release_first.index = 0
	release_first.position = first_touch.position
	release_first.pressed = false
	battlefield.call("_unhandled_input", release_first)
	if battlefield.get("selected_tank") != null:
		push_error("Ending a pinch gesture incorrectly selected a battlefield unit")
		quit(1)
		return
	battlefield.set("camera_focus", Vector3.ZERO)
	battlefield.set("camera_height", camera_height_before)
	battlefield.call("_update_camera_pose")

	# Regression: queued-for-deletion nodes are excluded before projection.
	# A unit queued for deletion must never remain a tap target during the
	# frame before Godot actually frees its node.
	var stale_pick_target := Node3D.new()
	stale_pick_target.set_meta("source_team", "player")
	stale_pick_target.set_meta("source_unit_key", "player|stale|tank")
	battlefield.add_child(stale_pick_target)
	if not battlefield.call("_is_live_player_unit", stale_pick_target):
		push_error("A valid live player unit was rejected before deletion")
		quit(1)
		return
	var camera_for_pick := battlefield.get("rts_camera") as Camera3D
	var offscreen_pick := Vector2(-1000.0, -1000.0)
	stale_pick_target.global_position = camera_for_pick.project_ray_origin(offscreen_pick) + camera_for_pick.project_ray_normal(offscreen_pick) * 10.0
	# Keep the live showcase arrays aligned; place the stale node well outside
	# the visible arena so no other unit can satisfy this pick coordinate.
	battlefield.showcase_tanks.append(stale_pick_target)
	stale_pick_target.queue_free()
	if battlefield.call("_is_live_player_unit", stale_pick_target):
		push_error("Queued-for-deletion player unit was still considered selectable")
		quit(1)
		return
	var stale_selection: Array[Node3D] = [stale_pick_target]
	battlefield.call("_set_live_selection", stale_selection)
	if not battlefield.get("selected_live_units").is_empty() or battlefield.get("selected_tank") != null:
		push_error("Group selection retained a unit queued for deletion")
		quit(1)
		return
	if battlefield.call("_tank_at_screen_position", offscreen_pick) != null:
		push_error("Touch selection returned a unit already queued for deletion")
		quit(1)
		return
	battlefield.showcase_tanks.erase(stale_pick_target)

	# Exercise real mobile tap targets and the gameplay-order bridge for a mixed group.
	var group_tank := battlefield.call("spawn_game_unit", "tank", Vector3(-12.0, 0.0, -2.0), "american", Color(0.28, 0.34, 0.22)) as Node3D
	var group_infantry := battlefield.call("spawn_game_unit", "infantry", Vector3(-9.0, 0.0, -2.0), "american", Color(0.28, 0.34, 0.22)) as Node3D
	var group_enemy := battlefield.call("spawn_game_unit", "tank", Vector3(12.0, 0.0, 9.0), "chinese", Color(0.34, 0.37, 0.40)) as Node3D
	if group_tank == null or group_infantry == null or group_enemy == null:
		push_error("Could not create mobile group-command interaction fixtures")
		quit(1)
		return
	group_tank.set_meta("source_team", "player")
	group_tank.set_meta("source_unit_key", "player|mobile-test|tank")
	group_tank.set_meta("unit_type", "tank")
	group_infantry.set_meta("source_team", "player")
	group_infantry.set_meta("source_unit_key", "player|mobile-test|infantry")
	group_infantry.set_meta("unit_type", "infantry")
	group_enemy.set_meta("source_team", "enemy")
	group_enemy.set_meta("source_unit_key", "enemy|mobile-test|tank")
	var issued_orders: Array[Dictionary] = []
	battlefield.gameplay_order_issued.connect(func(source_key: String, order_type: String, world_position: Vector3, target_key: String) -> void:
		issued_orders.append({"source": source_key, "type": order_type, "position": world_position, "target": target_key})
	)
	var group_selection: Array[Node3D] = [group_tank, group_infantry]
	battlefield.call("_set_live_selection", group_selection)
	if battlefield.get("selected_live_units").size() != 2:
		push_error("Mobile group selection did not retain both live player units")
		quit(1)
		return
	var selection_count_label := battlefield.get_node_or_null("TacticalSelectionHud/SelectionCountLabel") as Label
	if selection_count_label == null or not selection_count_label.visible or selection_count_label.text != "UNITS: 2":
		push_error("Mobile tactical HUD did not show the correct live group selection count")
		quit(1)
		return
	if battlefield.get("group_selection_rings").size() != 1:
		push_error("Group selection did not create a visible marker for every additional selected unit")
		quit(1)
		return
	var extra_selection_ring = battlefield.get("group_selection_rings")[0]
	if not is_instance_valid(extra_selection_ring) or not extra_selection_ring.visible:
		push_error("Additional group selection marker was not visible")
		quit(1)
		return
	var move_screen := camera_for_pick.unproject_position(Vector3(0.0, 0.0, 15.0))
	if battlefield.call("_screen_to_ground", move_screen) == null:
		push_error("Mobile move-command test point did not intersect the battlefield")
		quit(1)
		return
	battlefield.call("_handle_world_tap", move_screen)
	if issued_orders.size() != 2:
		push_error("A ground tap did not issue move orders to every selected group member")
		quit(1)
		return
	var move_positions: Array[Vector3] = []
	for order in issued_orders:
		if str(order.get("type", "")) != "move" or str(order.get("target", "")) != "":
			push_error("Ground tap emitted an invalid group movement order")
			quit(1)
			return
		move_positions.append(order.get("position", Vector3.ZERO))
	if move_positions[0].distance_to(move_positions[1]) < 0.5:
		push_error("Mixed group movement orders overlapped instead of using formation offsets")
		quit(1)
		return


	# Mixed formations must place artillery behind infantry and armor ahead of both.
	var role_artillery := Node3D.new()
	var role_infantry := Node3D.new()
	var role_tank := Node3D.new()
	var role_aircraft := Node3D.new()
	role_artillery.set_meta("unit_type", "artillery")
	role_infantry.set_meta("unit_type", "infantry")
	role_tank.set_meta("unit_type", "tank")
	role_aircraft.set_meta("unit_type", "helicopter")
	var role_units: Array[Node3D] = [role_artillery, role_infantry, role_tank, role_aircraft]
	var role_positions: Array[Vector3] = []
	for role_unit in role_units:
		role_positions.append(battlefield.call("_group_formation_offset_for_unit", role_unit, role_units, Vector3.FORWARD, 4.0))
	if not (role_positions[0].dot(Vector3.FORWARD) < role_positions[1].dot(Vector3.FORWARD) and role_positions[1].dot(Vector3.FORWARD) < role_positions[2].dot(Vector3.FORWARD) and role_positions[2].dot(Vector3.FORWARD) < role_positions[3].dot(Vector3.FORWARD)):
		push_error("Mixed formation did not arrange artillery, infantry, armor, and aircraft by tactical role")
		quit(1)
		return
	for role_unit in role_units:
		role_unit.free()

	# Multiple rows per role must remain in distinct, ordered tactical lanes.
	var dense_role_units: Array[Node3D] = []
	var dense_role_types := ["artillery", "infantry", "tank", "helicopter"]
	var dense_role_positions: Array[Vector3] = []
	for dense_type in dense_role_types:
		for dense_index in range(4):
			var dense_unit := Node3D.new()
			dense_unit.set_meta("unit_type", dense_type)
			dense_role_units.append(dense_unit)
	for dense_unit in dense_role_units:
		dense_role_positions.append(battlefield.call("_group_formation_offset_for_unit", dense_unit, dense_role_units, Vector3.FORWARD, 4.0))
	for role_index in range(3):
		var current_min := INF
		var current_max := -INF
		var next_min := INF
		for unit_index in range(dense_role_units.size()):
			var depth_value: float = dense_role_positions[unit_index].dot(Vector3.FORWARD)
			if unit_index / 4 == role_index:
				current_min = minf(current_min, depth_value)
				current_max = maxf(current_max, depth_value)
			elif unit_index / 4 == role_index + 1:
				next_min = minf(next_min, depth_value)
		if current_max >= next_min:
			push_error("Dense mixed formation role lanes overlapped")
			quit(1)
			return
	for dense_unit in dense_role_units:
		dense_unit.free()

	# Keep the entire formation inside arena bounds without distorting its spacing.
	var edge_offsets: Array[Vector3] = []
	for index in range(6):
		edge_offsets.append(battlefield.call("_group_formation_offset", index, 6, Vector3.FORWARD, 5.0))
	var edge_center := Vector3(17.64, 0.0, 17.64)
	var fitted_center: Vector3 = battlefield.call("_fit_group_formation_to_arena", edge_center, edge_offsets)
	for offset in edge_offsets:
		var fitted_position: Vector3 = fitted_center + offset
		if absf(fitted_position.x) > 17.641 or absf(fitted_position.z) > 17.641:
			push_error("Group formation extended beyond arena bounds near the map edge")
			quit(1)
			return
	for offset_index in range(edge_offsets.size()):
		for other_index in range(offset_index + 1, edge_offsets.size()):
			var before_distance := edge_offsets[offset_index].distance_to(edge_offsets[other_index])
			var after_distance := (fitted_center + edge_offsets[offset_index]).distance_to(fitted_center + edge_offsets[other_index])
			if absf(before_distance - after_distance) > 0.001:
				push_error("Edge fitting distorted the group's formation spacing")
				quit(1)
				return
	var enemy_screen := camera_for_pick.unproject_position(group_enemy.global_position + Vector3.UP)
	if battlefield.call("_tank_at_screen_position", enemy_screen) != group_enemy:
		push_error("Enemy tap target was not resolved to the intended hostile unit")
		quit(1)
		return
	battlefield.call("_handle_world_tap", enemy_screen)
	if issued_orders.size() != 4:
		push_error("Hostile tap did not issue attack orders to every selected group member")
		quit(1)
		return
	for order_index in range(2, 4):
		var attack_order: Dictionary = issued_orders[order_index]
		if str(attack_order.get("type", "")) != "attack" or str(attack_order.get("target", "")) != "enemy|mobile-test|tank":
			push_error("Hostile tap emitted an invalid group attack order")
			quit(1)
			return

	# The HUD must immediately reflect units queued for deletion, not retain a stale count.
	group_infantry.queue_free()
	battlefield.call("_update_showcase_orders", 0.0)
	if selection_count_label.text != "UNITS: 1" or not selection_count_label.visible:
		push_error("Selection HUD count did not update after a selected unit was removed")
		quit(1)
		return
	if battlefield.get("selected_live_units").size() != 1:
		push_error("Deleted group member remained in the live selection")
		quit(1)
		return

	var rock_scatter := battlefield.get_node_or_null("TerrainRockScatter") as MultiMeshInstance3D
	var scrub_scatter := battlefield.get_node_or_null("TerrainScrubScatter") as MultiMeshInstance3D
	if rock_scatter == null or scrub_scatter == null:
		push_error("Low-poly terrain detail scatter nodes are missing")
		quit(1)
		return
	if rock_scatter.multimesh == null or scrub_scatter.multimesh == null or rock_scatter.multimesh.instance_count != 14 or scrub_scatter.multimesh.instance_count != 14:
		push_error("Terrain detail scatter instance counts are incorrect")
		quit(1)
		return
	for scatter_node in [rock_scatter, scrub_scatter]:
		for instance_index in range(scatter_node.multimesh.instance_count):
			var instance_transform: Transform3D = scatter_node.multimesh.get_instance_transform(instance_index)
			if instance_transform.origin.y < 0.0 or absf(instance_transform.origin.x) > 19.0 or absf(instance_transform.origin.z) > 19.0:
				push_error("Terrain scatter instance is outside the safe ground bounds")
				quit(1)
				return

	var faction_ids: Array[String] = ["american", "chinese", "arab", "watan"]
	var faction_colors: Array[Color] = [
		Color(0.20, 0.48, 0.82),
		Color(0.82, 0.20, 0.16),
		Color(0.20, 0.58, 0.32),
		Color(0.88, 0.68, 0.22)
	]
	for faction_index in range(faction_ids.size()):
		var unit_expected_color: Color = faction_colors[faction_index]
		var faction_tank := battlefield.call("spawn_game_unit", "tank", Vector3(-72.0 + float(faction_index) * 12.0, 0.0, 38.0), faction_ids[faction_index], Color(0.32, 0.38, 0.30)) as Node3D
		var tank_insignia := faction_tank.get_node_or_null("TurretPivot/FactionInsignia") as MeshInstance3D if faction_tank != null else null
		var tank_badge_material := tank_insignia.material_override as StandardMaterial3D if tank_insignia != null else null
		var tank_badge_color := tank_badge_material.albedo_color if tank_badge_material != null else Color.BLACK
		var tank_color_mismatch := absf(tank_badge_color.r - unit_expected_color.r) > 0.001 or absf(tank_badge_color.g - unit_expected_color.g) > 0.001 or absf(tank_badge_color.b - unit_expected_color.b) > 0.001
		if tank_badge_material == null or tank_color_mismatch:
			push_error("Faction tank insignia is incorrect for: " + faction_ids[faction_index])
			quit(1)
			return
		var faction_infantry := battlefield.call("spawn_game_unit", "infantry", Vector3(-72.0 + float(faction_index) * 12.0, 0.0, 46.0), faction_ids[faction_index], Color(0.32, 0.38, 0.30)) as Node3D
		var infantry_insignia := faction_infantry.get_node_or_null("Soldier_0/FactionInsignia") as MeshInstance3D if faction_infantry != null else null
		var infantry_badge_material := infantry_insignia.material_override as StandardMaterial3D if infantry_insignia != null else null
		var infantry_badge_color := infantry_badge_material.albedo_color if infantry_badge_material != null else Color.BLACK
		var infantry_color_mismatch := absf(infantry_badge_color.r - unit_expected_color.r) > 0.001 or absf(infantry_badge_color.g - unit_expected_color.g) > 0.001 or absf(infantry_badge_color.b - unit_expected_color.b) > 0.001
		if infantry_badge_material == null or infantry_color_mismatch:
			push_error("Faction infantry insignia is incorrect for: " + faction_ids[faction_index])
			quit(1)
			return
		var faction_fighter := battlefield.call("spawn_game_unit", "fighter", Vector3(-72.0 + float(faction_index) * 12.0, 0.0, 54.0), faction_ids[faction_index], Color(0.32, 0.38, 0.30)) as Node3D
		if not _has_faction_insignia_color(faction_fighter, NodePath("FactionInsignia_Left"), unit_expected_color) or not _has_faction_insignia_color(faction_fighter, NodePath("FactionInsignia_Right"), unit_expected_color):
			push_error("Faction fighter wing insignia is incorrect for: " + faction_ids[faction_index])
			quit(1)
			return
		var faction_helicopter := battlefield.call("spawn_game_unit", "helicopter", Vector3(-72.0 + float(faction_index) * 12.0, 0.0, 62.0), faction_ids[faction_index], Color(0.32, 0.38, 0.30)) as Node3D
		if not _has_faction_insignia_color(faction_helicopter, NodePath("FactionInsignia"), unit_expected_color):
			push_error("Faction helicopter insignia is incorrect for: " + faction_ids[faction_index])
			quit(1)
			return
		var faction_destroyer := battlefield.call("spawn_game_unit", "destroyer", Vector3(-72.0 + float(faction_index) * 12.0, 0.0, 70.0), faction_ids[faction_index], Color(0.32, 0.38, 0.30)) as Node3D
		if not _has_faction_insignia_color(faction_destroyer, NodePath("FactionInsignia"), unit_expected_color):
			push_error("Faction destroyer insignia is incorrect for: " + faction_ids[faction_index])
			quit(1)
			return
		var faction_building := battlefield.call("spawn_game_building", "command", Vector3(-72.0 + float(faction_index) * 12.0, 0.0, 28.0), faction_ids[faction_index], Color(0.32, 0.38, 0.30)) as Node3D
		var faction_stripe: MeshInstance3D = faction_building.get_node_or_null("FactionStripe") as MeshInstance3D if faction_building != null else null
		var stripe_material: StandardMaterial3D = faction_stripe.material_override as StandardMaterial3D if faction_stripe != null else null
		var actual_color := stripe_material.albedo_color if stripe_material != null else Color.BLACK
		var expected_color: Color = faction_colors[faction_index]
		var color_mismatch := absf(actual_color.r - expected_color.r) > 0.001 or absf(actual_color.g - expected_color.g) > 0.001 or absf(actual_color.b - expected_color.b) > 0.001
		if stripe_material == null or color_mismatch:
			push_error("Faction building identity color is incorrect for: " + faction_ids[faction_index])
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
	if launched_aircraft == null or launched_aircraft.get_child_count() < 3 or launched_aircraft.position.y <= test_carrier.position.y:
		push_error("Carrier patrol aircraft geometry or takeoff altitude is invalid")
		quit(1)
		return

	# Verify the patrol aircraft descends onto the carrier deck before despawning.
	battlefield.call("_update_carrier_air_operations", 8.8)
	if not is_instance_valid(launched_aircraft) or not launched_aircraft.is_inside_tree():
		push_error("Carrier patrol aircraft disappeared before completing its deck approach")
		quit(1)
		return
	var landing_offset: Vector3 = launched_aircraft.position - test_carrier.position
	if absf(landing_offset.y - 1.48) > 0.25 or Vector2(landing_offset.x, landing_offset.z).length() > 0.45:
		push_error("Carrier patrol aircraft did not reach the carrier deck approach zone")
		quit(1)
		return
	battlefield.call("_update_carrier_air_operations", 0.3)
	if battlefield.carrier_aircraft.size() != 0 or (is_instance_valid(launched_aircraft) and not launched_aircraft.is_queued_for_deletion()):
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
