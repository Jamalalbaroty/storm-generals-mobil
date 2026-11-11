extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	# The test validates command logic only; remove generated audio resources
	# to keep headless shutdown deterministic.
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	var focus := Vector2(520.0, 310.0)
	game.units.assign([
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(160.0, 240.0), "target": Vector2(90.0, 90.0), "attack_move_active": true, "guard_active": true},
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(150.0, 270.0), "air_patrol_points": [Vector2.ZERO, Vector2.ONE]},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(170.0, 280.0), "escort_active": true},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(200.0, 290.0), "attack_target": 4},
		{"team": "enemy", "kind": "tank", "hp": 120, "pos": focus},
		{"team": "enemy", "kind": "infantry", "hp": 70, "pos": focus + Vector2(28.0, 8.0)},
		{"team": "enemy", "kind": "fighter", "hp": 130, "pos": focus + Vector2(18.0, -18.0)}
	])
	var commanded_selection: Array[int] = [0, 1, 2, 0, 99]
	game.selected = commanded_selection
	game._issue_group_attack_order(4)

	for unit_index in [0, 1, 2]:
		var attacker: Dictionary = game.units[unit_index]
		if int(attacker.get("attack_target", -1)) != 4:
			push_error("Every living selected unit must receive the same focus-fire target")
			quit(1)
			return
		if attacker.get("attack_focus_pos", Vector2.ZERO) != focus:
			push_error("Group attackers must share one initial focus position")
			quit(1)
			return
		for stale_order in ["target", "attack_move_active", "guard_active", "air_patrol_points", "escort_active"]:
			if attacker.has(stale_order):
				push_error("A focused group attack must clear stale order: " + stale_order)
				quit(1)
				return

	# Unselected units must retain their previous orders.
	if int(game.units[3].get("attack_target", -1)) != 4:
		push_error("Group attack must not alter unselected friendly units")
		quit(1)
		return

	# After the original target is destroyed, the whole group can reacquire the
	# nearest living threat around the shared last-known focus point.
	game.units[4]["hp"] = 0
	var reacquired: int = game._nearest_enemy_to_focus(focus, 300.0)
	if reacquired != 5:
		push_error("Group focus-fire must reacquire a nearby living ground target")
		quit(1)
		return
	var reacquired_again: int = game._nearest_enemy_to_focus(focus, 300.0)
	if reacquired_again != reacquired:
		push_error("All members must resolve the same replacement target from the shared focus")
		quit(1)
		return

	# Invalid and destroyed targets must never overwrite current valid orders.
	game._issue_group_attack_order(99)
	game._issue_group_attack_order(4)
	if int(game.units[0].get("attack_target", -1)) != 4:
		push_error("Invalid target orders must not mutate an existing attack assignment")
		quit(1)
		return

	print("Group attack regression passed: shared focus fire, stale-order cancellation, selection isolation, and target reacquisition.")
	quit(0)
