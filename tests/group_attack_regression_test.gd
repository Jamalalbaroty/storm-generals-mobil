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
	_test_duplicate_heavy_group_attack_selection(game)
	_test_balanced_large_tank_lanes(game)
	_test_large_artillery_support_ring(game)
	_test_selected_group_order_summary(game)
	_test_selected_group_composition_summary(game)
	_test_live_combined_arms_advance(game)
	_test_artillery_standoff(game)
	_test_enemy_artillery_support_role(game)
	_test_enemy_defensive_flank_selection(game)
	_test_enemy_infantry_flank_screen(game)
	_test_enemy_assault_rally_staging(game)
	_test_enemy_assault_distributes_targets(game)
	_test_enemy_critical_fallback(game)
	_test_enemy_counterattack_prioritizes_group_breach(game)
	_test_enemy_counterattack_focuses_artillery_threat(game)
	_test_enemy_counterattack_reserve_closes_deployment_gap(game)

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

	var forward: Vector2 = (focus - Vector2(165.0, 272.5)).normalized()
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


func _test_duplicate_heavy_group_attack_selection(game: Node) -> void:
	game.units.assign([
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(140.0, 220.0)},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(150.0, 240.0)},
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(160.0, 260.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(170.0, 280.0)},
		{"team": "player", "kind": "tank", "hp": 0, "pos": Vector2(180.0, 300.0)},
		{"team": "enemy", "kind": "tank", "hp": 500, "pos": Vector2(520.0, 330.0)}
	])
	var repeated_selection: Array[int] = []
	for repeat_index in range(100):
		for selected_index in [0, 1, 2, 3, 4, 0, 99]:
			repeated_selection.append(selected_index)
	game.selected = repeated_selection
	game._issue_group_attack_order(5)
	var offsets: Dictionary = game._group_attack_formation_offsets(repeated_selection, game.units[5].pos)
	_expect(offsets.size() == 4, "Duplicate-heavy group attack must create offsets only for unique living ground units")
	for unit_index in [0, 1, 2, 3]:
		_expect(int(game.units[unit_index].get("attack_target", -1)) == 5, "Duplicate-heavy attack orders must still assign focus fire to each living unit")
		_expect(offsets.has(unit_index), "Duplicate-heavy formation must preserve each living unit's role slot")
	_expect(not offsets.has(4) and not game.units[4].has("attack_target"), "Destroyed units must not receive attack slots or orders")
	var offset_values: Array = offsets.values()
	for first_index in range(offset_values.size()):
		for second_index in range(first_index + 1, offset_values.size()):
			_expect((offset_values[first_index] as Vector2).distance_to(offset_values[second_index]) > 0.1, "Duplicate-heavy combined-arms attack must retain distinct formation lanes")


func _test_balanced_large_tank_lanes(game: Node) -> void:
	game.units.assign([
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(120.0, 220.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(140.0, 230.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(160.0, 240.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(180.0, 250.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(200.0, 260.0)},
		{"team": "enemy", "kind": "tank", "hp": 900, "pos": Vector2(620.0, 360.0)}
	])
	game.selected.assign([0, 1, 2, 3, 4])
	game._issue_group_attack_order(5)
	var offsets: Dictionary = {}
	for unit_index in range(5):
		var offset: Vector2 = game.units[unit_index].get("attack_formation_offset", Vector2.ZERO)
		offsets[unit_index] = offset
		_expect(int(game.units[unit_index].get("attack_target", -1)) == 5, "Large armor formations must retain a shared focus-fire target")
	_expect(offsets.size() == 5, "Large tank formations must allocate one lane per selected unit")
	var offset_values: Array = offsets.values()
	for first_index in range(offset_values.size()):
		for second_index in range(first_index + 1, offset_values.size()):
			_expect((offset_values[first_index] as Vector2).distance_to(offset_values[second_index]) > 0.1, "Large armor formations must keep distinct lanes")
	var group_center := Vector2.ZERO
	for unit_index in range(5):
		group_center += game.units[unit_index].pos
	group_center /= 5.0
	var forward: Vector2 = (game.units[5].pos - group_center).normalized()
	var right := Vector2(-forward.y, forward.x)
	var front_lanes: Array[float] = []
	var rear_lanes: Array[float] = []
	for unit_index in [0, 1, 2]:
		front_lanes.append((offsets[unit_index] as Vector2).dot(right))
	for unit_index in [3, 4]:
		rear_lanes.append((offsets[unit_index] as Vector2).dot(right))
	front_lanes.sort()
	rear_lanes.sort()
	_expect(absf(front_lanes[1]) < 0.1 and front_lanes[0] < -40.0 and front_lanes[2] > 40.0, "Three-unit front rows must center the middle tank and spread both flanks")
	_expect(rear_lanes[0] < -10.0 and rear_lanes[1] > 10.0, "Trailing armor rows must remain symmetrically spaced behind the front line")


func _test_large_artillery_support_ring(game: Node) -> void:
	var target_pos := Vector2(850.0, 500.0)
	var artillery_units: Array[Dictionary] = []
	var selected_indices: Array[int] = []
	var group_center := Vector2.ZERO
	for unit_index in range(40):
		var artillery_pos := Vector2(300.0 + float(unit_index) * 1.5, 280.0 + float(unit_index) * 0.6)
		artillery_units.append({"team": "player", "kind": "artillery", "hp": 110, "pos": artillery_pos})
		selected_indices.append(unit_index)
		group_center += artillery_pos
	artillery_units.append({"team": "enemy", "kind": "tank", "hp": 900, "pos": target_pos})
	game.units.assign(artillery_units)
	group_center /= 40.0
	var forward: Vector2 = (target_pos - group_center).normalized()
	var offsets: Dictionary = game._group_attack_formation_offsets(selected_indices, target_pos)
	_expect(offsets.size() == 40, "A forty-unit artillery group must receive a complete support layout")
	var offset_values: Array[Vector2] = []
	for unit_index in range(40):
		var offset: Vector2 = offsets.get(unit_index, Vector2.ZERO)
		var support_distance := offset.length()
		_expect(support_distance >= 250.0 and support_distance <= 315.0, "Large artillery groups must stay inside the reachable support ring")
		_expect(offset.dot(forward) < -35.0, "Large artillery groups must remain behind the advancing armor")
		offset_values.append(offset)
	for first_index in range(offset_values.size()):
		for second_index in range(first_index + 1, offset_values.size()):
			_expect(offset_values[first_index].distance_to(offset_values[second_index]) > 25.0, "Large artillery support slots must not overlap")

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


func _test_selected_group_composition_summary(game: Node) -> void:
	var sample_units: Array[Dictionary] = [
		{"team": "player", "kind": "tank", "hp": 180},
		{"team": "player", "kind": "infantry", "hp": 60},
		{"team": "player", "kind": "tank", "hp": 120},
		{"team": "player", "kind": "artillery", "hp": 110},
		{"team": "player", "kind": "fighter", "hp": 130},
		{"team": "player", "kind": "tank", "hp": 0},
		{"team": "enemy", "kind": "infantry", "hp": 60}
	]
	var summary: String = game._selected_group_composition_summary(sample_units)
	_expect(summary.contains("دبابة ×2"), "Selection dossier must count tanks separately from other ground units")
	_expect(summary.contains("مشاة ×1"), "Selection dossier must report the selected infantry count")
	_expect(summary.contains("مدفعية ×1"), "Selection dossier must report the selected artillery count")
	_expect(summary.contains("مقاتلة ×1"), "Selection dossier must report the selected fighter count")
	_expect(not summary.contains("دبابة ×3"), "Destroyed units must not inflate the selected tank count")
	_expect(not summary.contains("أخرى"), "Known selected unit types must not be collapsed into an unknown bucket")
	var compact_units: Array[Dictionary] = [
		{"team": "player", "kind": "tank", "hp": 180},
		{"team": "player", "kind": "infantry", "hp": 60},
		{"team": "player", "kind": "artillery", "hp": 110},
		{"team": "player", "kind": "builder", "hp": 400},
		{"team": "player", "kind": "fighter", "hp": 130}
	]
	var compact_summary: String = game._selected_group_composition_summary(compact_units)
	_expect(compact_summary.contains("أخرى ×1"), "Long mixed selections must preserve the total while keeping the dossier compact")
	var no_units: Array[Dictionary] = []
	_expect(game._selected_group_composition_summary(no_units) == "لا توجد قوات حية", "An empty force must produce a safe composition label")
	var single_unit: Array[Dictionary] = [{"team": "player", "kind": "artillery", "hp": 110}]
	_expect(game._selected_group_composition_summary(single_unit) == "مدفعية", "A single selected unit must use its clear unit-type label")


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
		{"owner": "player", "kind": "supply", "pos": Vector2(500.0, 330.0), "payout": 0.0, "supply_payout": 0.0}
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


func _test_enemy_defensive_flank_selection(game: Node) -> void:
	var target := Vector2(500.0, 330.0)
	var origin := Vector2(900.0, 330.0)
	var left_flank := Vector2(500.0, 215.0)
	var right_flank := Vector2(500.0, 445.0)

	# Two central defenses make the target fortified; an extra left-side turret
	# should force the assault to route around the weaker right flank.
	game.buildings.assign([
		{"team": "player", "kind": "turret", "hp": 300, "build_progress": 1.0, "pos": target},
		{"team": "player", "kind": "turret", "hp": 300, "build_progress": 1.0, "pos": target},
		{"team": "player", "kind": "turret", "hp": 300, "build_progress": 1.0, "pos": left_flank}
	])
	var selected_flank: Vector2 = game._enemy_ground_assault_flank_anchor(target, origin, 0)
	_expect(selected_flank.distance_to(right_flank) < 0.1, "Enemy ground assault must choose the less defended flank around a fortified target")
	_expect(game._enemy_ground_target_defense_risk(left_flank) > game._enemy_ground_target_defense_risk(right_flank), "Flank routing fixture must expose a clear defensive-risk difference")

	# If both sides are equally defended, units split lanes instead of stacking.
	game.buildings.assign([
		{"team": "player", "kind": "turret", "hp": 300, "build_progress": 1.0, "pos": target},
		{"team": "player", "kind": "turret", "hp": 300, "build_progress": 1.0, "pos": target}
	])
	var even_flank: Vector2 = game._enemy_ground_assault_flank_anchor(target, origin, 0)
	var odd_flank: Vector2 = game._enemy_ground_assault_flank_anchor(target, origin, 1)
	_expect(even_flank.distance_to(right_flank) < 0.1 and odd_flank.distance_to(left_flank) < 0.1, "Enemy assault units must split evenly defended approaches across opposite flanks")
	game.buildings.clear()


func _test_enemy_critical_fallback(game: Node) -> void:
	game.enemy_base = Vector2(900.0, 330.0)
	game.base_pos = Vector2(150.0, 330.0)
	game.buildings.clear()
	game.enemy_buildings.clear()
	game.supply_points.clear()
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 30, "pos": Vector2(500.0, 330.0), "attack_cd": 10.0},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(400.0, 330.0)}
	])
	var damaged_start: Vector2 = game.units[0].pos
	_expect(game._update_enemy_ground_assault(game.units[0], 0, 1.0), "A critically damaged enemy tank must remain controlled while falling back")
	_expect(bool(game.units[0].get("tactical_fallback_active", false)), "A critically damaged enemy unit under nearby ground pressure must enter tactical fallback")
	_expect(game.units[0].pos.x > damaged_start.x, "A damaged enemy tank must retreat toward its own base instead of remaining exposed")
	_expect(not game.units[0].has("attack_target"), "A retreating enemy unit must release its offensive target lock")
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 120, "pos": Vector2(500.0, 330.0), "attack_cd": 10.0},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(400.0, 330.0)}
	])
	var healthy_start: Vector2 = game.units[0].pos
	game._update_enemy_ground_assault(game.units[0], 0, 1.0)
	_expect(not game.units[0].has("tactical_fallback_active"), "Healthy enemy armor must not retreat solely because a player unit is nearby")
	_expect(game.units[0].pos == healthy_start, "Healthy enemy armor must retain its firing position instead of triggering fallback")


func _test_enemy_counterattack_prioritizes_group_breach(game: Node) -> void:
	game.enemy_base = Vector2(900.0, 330.0)
	game.enemy_buildings.assign([
		{"kind": "factory", "hp": 500, "build_progress": 1.0, "pos": Vector2(650.0, 330.0)}
	])
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(700.0, 330.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(900.0, 330.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(650.0, 300.0)},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(670.0, 340.0)},
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(630.0, 350.0)}
	])
	_expect(game._update_enemy_counterattack_reserve(game.units[0], 0, 0.5), "Enemy mobile reserve must respond to a coordinated ground breach")
	_expect(bool(game.units[0].get("counterattack_active", false)), "Enemy reserve must activate when a protected asset is under a ground assault")
	_expect(game.units[0].get("counterattack_anchor", Vector2.ZERO).distance_to(Vector2(650.0, 330.0)) < 0.1, "Enemy reserve must prioritize the factory threatened by a concentrated player group over an isolated base contact")


func _test_enemy_counterattack_focuses_artillery_threat(game: Node) -> void:
	game.enemy_strategy = "balanced"
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(700.0, 330.0)},
		{"team": "player", "kind": "infantry", "hp": 60, "pos": Vector2(655.0, 330.0)},
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(690.0, 330.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(670.0, 360.0)}
	])
	var target_index: int = game._enemy_counterattack_priority_target(Vector2(650.0, 330.0), game.units[0].pos, 205.0)
	_expect(target_index == 2, "Enemy counterattack must prioritize nearby player artillery over closer infantry and armor in a breached perimeter")
	game.units[3].pos = Vector2(651.0, 330.0)
	game.enemy_strategy = "armor_breaker"
	var armor_target_index: int = game._enemy_counterattack_priority_target(Vector2(650.0, 330.0), game.units[0].pos, 205.0)
	_expect(armor_target_index == 3, "Armor-breaker doctrine must reprioritize a nearby tank threat")
	game.enemy_strategy = "area_denial"
	var artillery_target_index: int = game._enemy_counterattack_priority_target(Vector2(650.0, 330.0), game.units[0].pos, 205.0)
	_expect(artillery_target_index == 2, "Area-denial doctrine must prioritize artillery even when armor is closer")


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


func _test_enemy_counterattack_reserve_closes_deployment_gap(game: Node) -> void:
	game.enemy_base = Vector2(900.0, 330.0)
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(400.0, 330.0), "counterattack_active": true, "counterattack_anchor": Vector2(700.0, 330.0)},
		{"team": "player", "kind": "artillery", "hp": 110, "pos": Vector2(680.0, 330.0)}
	])
	var reserve_start: Vector2 = game.units[0].pos
	_expect(game._update_enemy_counterattack_reserve(game.units[0], 0, 1.0), "A distant active reserve must remain under counterattack control while deploying")
	_expect(game.units[0].pos.distance_to(Vector2(700.0, 330.0)) < reserve_start.distance_to(Vector2(700.0, 330.0)), "A reserve assigned to a distant breached asset must advance toward its anchor instead of remaining idle")


func _test_enemy_infantry_flank_screen(game: Node) -> void:
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(700.0, 330.0)},
		{"team": "enemy", "kind": "infantry", "hp": 60, "pos": Vector2(720.0, 330.0)}
	])
	var target := Vector2(500.0, 330.0)
	var origin := Vector2(900.0, 330.0)
	var infantry_slot: Vector2 = game._enemy_infantry_support_position(game.units[1].pos, target, origin, 1)
	_expect(infantry_slot.x > game.units[0].pos.x, "Enemy infantry must remain slightly behind its armor screen")
	_expect(absf(infantry_slot.y - game.units[0].pos.y) >= 60.0, "Enemy infantry must occupy a wide lateral escort lane to screen the armor's flank")


func _test_enemy_assault_rally_staging(game: Node) -> void:
	game.enemy_base = Vector2(1000.0, 330.0)
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(550.0, 330.0)},
		{"team": "enemy", "kind": "infantry", "hp": 60, "pos": Vector2(760.0, 330.0)},
		{"team": "enemy", "kind": "artillery", "hp": 110, "pos": Vector2(840.0, 360.0)},
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(540.0, 330.0), "retreating": true},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(450.0, 330.0)}
	])
	var target_pos: Vector2 = game.units[4].pos
	var formation_goal := Vector2(600.0, 330.0)
	var staged_goal: Vector2 = game._enemy_assault_rally_movement_goal(0, target_pos, formation_goal)
	_expect(not game._enemy_assault_rally_ready(0, target_pos), "A dispersed three-unit assault group must wait for its nearby support to close before advancing")
	_expect(staged_goal == game.units[0].pos, "An advanced tank must hold its position rather than push alone beyond the rally line")
	game.units[1].pos = Vector2(700.0, 330.0)
	_expect(not game._enemy_assault_rally_ready(0, target_pos), "The assault must not launch while only one of two supporting elements has joined")
	game.units[2].pos = Vector2(700.0, 360.0)
	var released_goal: Vector2 = game._enemy_assault_rally_movement_goal(0, target_pos, formation_goal)
	_expect(game._enemy_assault_rally_ready(0, target_pos), "The assault must become ready once a supporting unit closes within rally distance")
	_expect(released_goal == formation_goal, "A gathered assault group must resume its assigned formation advance")
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(550.0, 330.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(350.0, 330.0)}
	])
	_expect(game._enemy_assault_rally_ready(0, game.units[1].pos), "A small enemy force must never be stalled waiting for units that do not exist")


func _test_enemy_assault_distributes_targets(game: Node) -> void:
	game.enemy_base = Vector2(1000.0, 330.0)
	game.buildings.clear()
	game.enemy_buildings.clear()
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(620.0, 300.0), "attack_focus_pos": Vector2(600.0, 300.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(600.0, 300.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(630.0, 360.0)}
	])
	var selected_index: int = game._select_enemy_ground_assault_target(Vector2(615.0, 330.0))
	_expect(selected_index == 2, "Enemy assault target selection should spread a new attacker to a nearby unassigned threat instead of stacking onto an already focused tank")
	game.units.assign([
		{"team": "enemy", "kind": "tank", "hp": 180, "pos": Vector2(180.0, 300.0), "attack_focus_pos": Vector2(600.0, 280.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(600.0, 280.0)},
		{"team": "player", "kind": "tank", "hp": 180, "pos": Vector2(600.0, 400.0)}
	])
	selected_index = game._select_enemy_ground_assault_target(Vector2(600.0, 340.0))
	_expect(selected_index == 2, "Enemy assault should count a committed attacker traveling toward its focus so distant reinforcements do not duplicate the same target")
