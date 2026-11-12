extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_cleanup_audio(game)

	_test_group_order_and_reacquisition(game)
	_test_selected_group_order_summary(game)
	_test_live_combined_arms_advance(game)
	_test_artillery_standoff(game)
	_test_enemy_artillery_support_role(game)

	game.queue_free()
	await process_frame
	if failures > 0:
		push_error("Coordinated group attack regression failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("PASS: shared focus fire, target reacquisition, armor-forward and infantry-flank formation, rear artillery support, and artillery standoff.")
	quit(0)


func _test_group_order_and_reacquisition(game: Node) -> void:
	var focus := Vector2(520.0, 310.0)
	game.units.assign([
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(160.0, 240.0), "target": Vector2(90.0, 90.0), "attack_move_active": true, "guard_active": true},
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(150.0, 270.0), "air_patrol_points": [Vector2.ZERO, Vector2.ONE]},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(170.0, 280.0), "escort_active": true},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(180.0, 300.0)},
		{"team": "enemy", "kind": "tank", "hp": 120, "pos": focus},
		{"team": "enemy", "kind": "infantry", "hp": 70, "pos": focus + Vector2(28.0, 8.0)},
		{"team": "enemy", "kind": "fighter", "hp": 130, "pos": focus + Vector2(120.0, -110.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(200.0, 290.0), "attack_target": 4}
	])
	var commanded_selection: Array[int] = [0, 1, 2, 3, 0, 99]
	game.selected = commanded_selection
	game._issue_group_attack_order(4)

	for unit_index in [0, 1, 2, 3]:
		var attacker: Dictionary = game.units[unit_index]
		_expect(int(attacker.get("attack_target", -1)) == 4, "Every living selected ground unit must receive the same focus-fire target")
		_expect(attacker.get("attack_focus_pos", Vector2.ZERO) == focus, "Group attackers must share one initial focus position")
		_expect(attacker.has("attack_formation_offset"), "Selected tanks, infantry, and artillery must receive a role-based formation offset")
		for stale_order in ["target", "attack_move_active", "guard_active", "air_patrol_points", "escort_active"]:
			_expect(not attacker.has(stale_order), "A focused group attack must clear stale order: " + stale_order)

	var forward := (focus - Vector2(165.0, 272.5)).normalized()
	var right := Vector2(-forward.y, forward.x)
	var tank_offset: Vector2 = game.units[0].get("attack_formation_offset", Vector2.ZERO)
	var artillery_offset: Vector2 = game.units[1].get("attack_formation_offset", Vector2.ZERO)
	var infantry_left_offset: Vector2 = game.units[2].get("attack_formation_offset", Vector2.ZERO)
	var infantry_right_offset: Vector2 = game.units[3].get("attack_formation_offset", Vector2.ZERO)
	var tank_depth := tank_offset.dot(forward)
	var infantry_depth := infantry_left_offset.dot(forward)
	var artillery_depth := artillery_offset.dot(forward)
	_expect(tank_depth > infantry_depth and infantry_depth > artillery_depth, "Armor must lead, infantry must screen behind it, and artillery must hold the rear")
	_expect(infantry_left_offset.dot(right) * infantry_right_offset.dot(right) < 0.0, "The infantry screen must split across opposite flanks")
	_expect(absf(infantry_left_offset.dot(right)) >= 60.0 and absf(infantry_right_offset.dot(right)) >= 60.0, "Infantry flank spacing must remain wide enough to avoid stacking")
	_expect(artillery_offset.length() >= 245.0, "Artillery must keep a long-range support position")

	# Unselected units must retain their previous orders and must not inherit a new group lane.
	_expect(int(game.units[7].get("attack_target", -1)) == 4, "Group attack must not alter unselected friendly units")
	_expect(not game.units[7].has("attack_formation_offset"), "Unselected units must not receive group attack formation state")

	# After the original target is destroyed, all members resolve the same nearby replacement from the shared focus.
	game.units[4]["hp"] = 0
	# A closer aircraft must not steal a ground formation's reacquisition focus.
	game.units[6]["pos"] = focus + Vector2(2.0, 1.0)
	var reacquired: int = game._nearest_enemy_to_focus(focus, 300.0)
	_expect(reacquired == 5, "Ground group focus-fire must ignore closer air contacts and reacquire a living ground target")
	var reacquired_again: int = game._nearest_enemy_to_focus(focus, 300.0)
	_expect(reacquired_again == reacquired, "All members must resolve the same replacement target from the shared focus")
	game.units[6]["pos"] = focus + Vector2(120.0, -110.0)

	# Invalid and destroyed targets must never overwrite current valid orders.
	game._issue_group_attack_order(99)
	game._issue_group_attack_order(4)
	_expect(int(game.units[0].get("attack_target", -1)) == 4, "Invalid target orders must not mutate an existing attack assignment")


func _test_selected_group_order_summary(game: Node) -> void:
	var sample_units: Array[Dictionary] = [
		{"team": "player", "kind": "tank", "hp": 180, "attack_target": 3},
		{"team": "player", "kind": "infantry", "hp": 60, "guard_active": true},
		{"team": "player", "kind": "fighter", "hp": 130, "air_patrol_points": [Vector2.ZERO, Vector2.ONE]},
		{"team": "player", "kind": "artillery", "hp": 110, "target": Vector2(300.0, 300.0)},
		{"team": "player", "kind": "tank", "hp": 0, "attack_target": 3},
		{"team": "enemy", "kind": "tank", "hp": 180, "attack_target": 3}
	]
	var summary: String = game._selected_group_order_summary(sample_units)
	_expect(summary.contains("هجوم 1"), "Dossier must count the selected group's active attack orders")
	_expect(summary.contains("حراسة 1"), "Dossier must count guard orders separately")
	_expect(summary.contains("دورية 1"), "Dossier must report air patrol orders")
	_expect(summary.contains("تحرك 1"), "Dossier must report ordinary movement orders")
	_expect(not summary.contains("خامل"), "Destroyed and enemy units must not inflate the selected force's order summary")
	var no_units: Array[Dictionary] = []
	_expect(game._selected_group_order_summary(no_units) == "لا توجد قوات حية", "An empty selection must produce a safe empty-state label")
	var destroyed: Array[Dictionary] = [{"team": "player", "kind": "tank", "hp": 0}]
	_expect(game._selected_group_order_summary(destroyed) == "لا توجد قوات حية", "Destroyed selected units must not be reported as active forces")
	var attack_move: Array[Dictionary] = [{"team": "player", "kind": "tank", "hp": 180, "attack_move_active": true}]
	_expect(game._selected_group_order_summary(attack_move) == "الأمر: تقدم قتالي", "A single unit's attack-move order must be clearly distinguished from a direct attack")


func _test_live_combined_arms_advance(game: Node) -> void:
	game.units.assign([
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(180.0, 240.0)},
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(180.0, 330.0)},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(180.0, 390.0)},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(180.0, 450.0)},
		{"team": "enemy", "kind": "tank", "hp": 1000, "pos": Vector2(760.0, 330.0)}
	])
	var selected_group: Array[int] = [0, 1, 2, 3]
	game.selected = selected_group
	game.game_started = true
	game.paused = false
	game.battle_result = ""
	game.enemy_timer = 0.0
	game.enemy_income_timer = 0.0
	game.income_timer = 0.0
	game.credits = 0
	game.enemy_credits = 0
	game.supply_points.clear()
	game.buildings.clear()
	game.enemy_buildings.clear()
	game._issue_group_attack_order(4)

	var starting_distances: Dictionary = {}
	for unit_index in [0, 1, 2, 3]:
		var offset: Vector2 = game.units[unit_index].get("attack_formation_offset", Vector2.ZERO)
		starting_distances[unit_index] = game.units[unit_index].pos.distance_to(game.units[4].pos + offset)
	game._process(0.1)
	var moved_target_pos: Vector2 = game.units[4].pos
	for unit_index in [0, 1, 2, 3]:
		var offset: Vector2 = game.units[unit_index].get("attack_formation_offset", Vector2.ZERO)
		var distance_after: float = game.units[unit_index].pos.distance_to(moved_target_pos + offset)
		_expect(distance_after < float(starting_distances[unit_index]), "Every selected ground unit must advance toward its assigned combined-arms slot")


func _test_artillery_standoff(game: Node) -> void:
	game.units.assign([
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(300.0, 330.0)},
		{"team": "enemy", "kind": "tank", "hp": 500, "pos": Vector2(390.0, 330.0)}
	])
	var selected_artillery: Array[int] = [0]
	game.selected = selected_artillery
	game.enemy_timer = 0.0
	var target_hp_before := int(game.units[1].hp)
	game._issue_group_attack_order(1)
	game._process(0.1)
	_expect(game.units[0].pos.x < 300.0, "Group-ordered artillery must reposition backward when a target is inside its minimum support range")
	_expect(int(game.units[1].hp) == target_hp_before, "Artillery must not fire while forced inside the minimum standoff band")


func _test_enemy_artillery_support_role(game: Node) -> void:
	game.units.assign([
		{"team": "enemy", "kind": "artillery", "hp": 110, "pos": Vector2(800.0, 400.0)}
	])
	game.supply_points.assign([
		{"owner": "player", "kind": "supply", "pos": Vector2(500.0, 330.0)}
	])
	game.enemy_base = Vector2(900.0, 330.0)
	game.base_pos = Vector2(150.0, 330.0)
	var artillery_start: Vector2 = game.units[0].pos
	_expect(game._update_enemy_ground_assault(game.units[0], 0, 0.5), "Enemy artillery without a frontline anchor must remain under AI control")
	_expect(game.units[0].pos == artillery_start, "Enemy artillery must not abandon its support role to capture a supply point alone")

	game.units.append({"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(700.0, 300.0)})
	var anchor_index: int = game._enemy_nearest_ground_assault_anchor(artillery_start)
	_expect(anchor_index == 1, "Enemy artillery must identify nearby friendly armor as its support anchor")
	game._update_enemy_ground_assault(game.units[0], 0, 0.5)
	_expect(game.units[0].pos.distance_to(artillery_start) > 0.1, "Enemy artillery must reposition behind its advancing armor when an assault anchor exists")


func _cleanup_audio(game: Node) -> void:
	for player in game.get("audio_players"):
		player.stop()
		player.stream = null
		game.remove_child(player)
		player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Coordinated group attack regression failed: " + message)
