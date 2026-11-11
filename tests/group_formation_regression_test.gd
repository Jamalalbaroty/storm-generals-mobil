extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	# Formation logic does not require audio. Remove generated players so the
	# headless SceneTree exits deterministically after the assertions.
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	print("Formation regression: scene ready")
	var viewport_size: Vector2 = game.get_viewport_rect().size
	if viewport_size.x < 100.0 or viewport_size.y < 100.0:
		push_error("Formation regression requires a valid gameplay viewport")
		quit(1)
		return

	var origin := viewport_size * 0.28
	var destination := viewport_size * 0.68
	game.units.assign([
		{"team": "player", "kind": "artillery", "hp": 110, "pos": origin + Vector2(-18.0, 0.0)},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": origin + Vector2(0.0, -12.0)},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": origin + Vector2(0.0, 12.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": origin + Vector2(18.0, -12.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": origin + Vector2(18.0, 12.0)},
		{"team": "player", "kind": "fighter", "hp": 130, "pos": origin + Vector2(-8.0, 18.0)},
		{"team": "player", "kind": "transport_helicopter", "hp": 190, "pos": origin + Vector2(-8.0, -18.0)},
		{"team": "player", "kind": "tank", "hp": 0, "pos": origin}
	])
	var selected_indices: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 3]
	var slots: Array[Vector2] = []
	print("Formation regression: validating seven live units")
	for unit_index in range(7):
		var slot: Vector2 = game._group_move_destination(unit_index, selected_indices, destination)
		slots.append(slot)
		if slot.x < 24.0 or slot.y < 24.0 or slot.x > viewport_size.x - 24.0 or slot.y > viewport_size.y - 24.0:
			push_error("Group formation slot escaped the playable viewport")
			quit(1)
			return

	print("Formation regression: slots generated")
	# Every living selected unit gets a distinct slot, even with duplicate/dead indices in the selection.
	for first_index in range(slots.size()):
		for second_index in range(first_index + 1, slots.size()):
			if slots[first_index].distance_to(slots[second_index]) < 12.0:
				push_error("Combined-arms group formation produced overlapping unit destinations")
				quit(1)
				return

	var direction := (destination - origin).normalized()
	var artillery_depth := (slots[0] - destination).dot(direction)
	var armor_depth := (slots[3] - destination).dot(direction)
	var fighter_depth := (slots[5] - destination).dot(direction)
	var transport_depth := (slots[6] - destination).dot(direction)
	if artillery_depth >= armor_depth:
		push_error("Artillery must remain behind the armor line")
		quit(1)
		return
	if fighter_depth <= armor_depth or transport_depth <= fighter_depth:
		push_error("Air and transport support must occupy their designated forward/support lanes")
		quit(1)
		return
	if absf((slots[1] - destination).x * direction.y - (slots[1] - destination).y * direction.x) < 20.0 or absf((slots[2] - destination).x * direction.y - (slots[2] - destination).y * direction.x) < 20.0:
		push_error("Infantry screen must deploy on the two outer flanks")
		quit(1)
		return

	# Dead, unselected, and single-unit commands must not inherit a multi-unit slot.
	if game._group_move_destination(7, selected_indices, destination) != destination:
		push_error("Dead units must not reserve a group formation slot")
		quit(1)
		return
	var single_selection: Array[int] = [3]
	if game._group_move_destination(3, single_selection, destination) != destination:
		push_error("A single selected unit must move directly to the commanded point")
		quit(1)
		return

	print("Formation regression: all assertions passed")
	print("Group formation regression passed: unique slots, viewport bounds, rear artillery, infantry flanks, armor center, air/support lanes, and dead/single-unit handling.")
	quit(0)
