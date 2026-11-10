extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	game.faction = "الأمريكي"
	if game._unit_cost("tank", "الصيني") != 270:
		push_error("Chinese armor cost profile was not applied")
		quit(1)
		return
	if game._unit_cost("infantry", "الجيش العربي") != 90 or game._unit_cost("artillery", "الجيش العربي") != 430:
		push_error("Arab infantry/artillery cost profile was not applied")
		quit(1)
		return
	if game._unit_cost("tank", "وطن") <= game._unit_cost("tank", "الأمريكي"):
		push_error("Watan elite armor must carry a higher production cost")
		quit(1)
		return
	if game._unit_cost("fighter", "وطن") <= game._unit_cost("fighter", "الأمريكي"):
		push_error("Watan elite aircraft must carry a higher production cost")
		quit(1)
		return

	# Threat assessment must select a predictable doctrine with explicit priority.
	if game._enemy_choose_strategy(2, 0, 2, 0) != "air_control":
		push_error("Enemy should prioritize a matching air threat")
		quit(1)
		return
	if game._enemy_choose_strategy(1, 2, 3, 0) != "naval_control":
		push_error("Enemy should respond to a significant naval threat")
		quit(1)
		return
	if game._enemy_choose_strategy(0, 1, 3, 0) != "armor_breaker":
		push_error("Enemy should counter a heavy ground force")
		quit(1)
		return
	if game._enemy_choose_strategy(0, 0, 0, 5) != "area_denial":
		push_error("Enemy should use area denial against massed infantry")
		quit(1)
		return
	if game._enemy_choose_strategy(1, 1, 2, 4) != "balanced":
		push_error("Enemy should retain balanced doctrine below threat thresholds")
		quit(1)
		return

	# Engagement timing: landing support and active doctrines respond immediately, while balanced forces weigh supply objectives.
	if not game._enemy_should_engage_player(true, 500.0, 100.0, "balanced", true):
		push_error("Landing-assault support should engage despite a distant player target")
		quit(1)
		return
	if game._enemy_should_engage_player(false, INF, 100.0, "armor_breaker", false):
		push_error("Enemy should not engage when no player target exists")
		quit(1)
		return
	if not game._enemy_should_engage_player(true, 400.0, 100.0, "armor_breaker", false):
		push_error("Non-balanced doctrine should respond to a player target immediately")
		quit(1)
		return
	if not game._enemy_should_engage_player(true, 250.0, INF, "balanced", false):
		push_error("Balanced forces should engage when no supply objective is available")
		quit(1)
		return
	if not game._enemy_should_engage_player(true, 170.0, 100.0, "balanced", false):
		push_error("Balanced forces should engage a player threat near their supply route")
		quit(1)
		return
	if game._enemy_should_engage_player(true, 250.0, 100.0, "balanced", false):
		push_error("Balanced forces should keep pursuing a closer strategic supply objective")
		quit(1)
		return

	# Supply objective selection must favor valuable recaptures and neutral ports, never friendly points.
	game.supply_points = [
		{"pos": Vector2(100.0, 0.0), "owner": "neutral", "kind": "supply"},
		{"pos": Vector2(120.0, 0.0), "owner": "player", "kind": "supply"},
		{"pos": Vector2(400.0, 0.0), "owner": "enemy", "kind": "supply"}
	]
	if game._enemy_best_supply_objective(Vector2.ZERO) != 1:
		push_error("Enemy should prioritize a nearby player-held supply point for recapture")
		quit(1)
		return
	game.supply_points = [
		{"pos": Vector2(100.0, 0.0), "owner": "neutral", "kind": "supply"},
		{"pos": Vector2(120.0, 0.0), "owner": "neutral", "kind": "port"}
	]
	if game._enemy_best_supply_objective(Vector2.ZERO) != 1:
		push_error("Enemy should account for the higher income value of a neutral port")
		quit(1)
		return
	game.supply_points = [
		{"pos": Vector2(100.0, 0.0), "owner": "enemy", "kind": "supply"}
	]
	if game._enemy_best_supply_objective(Vector2.ZERO) != -1:
		push_error("Enemy should not select a supply point it already owns")
		quit(1)
		return

	# Formation ranks must ignore player/support units and dead enemy units.
	game.units = [
		{"team": "player", "kind": "tank", "hp": 150},
		{"team": "enemy", "kind": "artillery", "hp": 100},
		{"team": "enemy", "kind": "tank", "hp": 150},
		{"team": "enemy", "kind": "infantry", "hp": 60},
		{"team": "enemy", "kind": "tank", "hp": 0}
	]
	if game._enemy_assault_formation_rank(2) != 0 or game._enemy_assault_formation_rank(4) != 2:
		push_error("Enemy formation rank must count only preceding living enemy tanks and infantry")
		quit(1)
		return

	# Enemy defense assignments should preserve artillery and armor for combined-arms attacks.
	if game._enemy_defense_guard_role_penalty("infantry") != 0 or game._enemy_defense_guard_role_penalty("tank") <= game._enemy_defense_guard_role_penalty("infantry") or game._enemy_defense_guard_role_penalty("artillery") <= game._enemy_defense_guard_role_penalty("tank"):
		push_error("Enemy guard role priority must prefer infantry, then tanks, then artillery")
		quit(1)
		return

	# Artillery uses its own live-unit lanes and maintains a safe 185-330 unit firing band.
	game.units = [
		{"team": "player", "kind": "tank", "hp": 150},
		{"team": "enemy", "kind": "tank", "hp": 150},
		{"team": "enemy", "kind": "artillery", "hp": 100},
		{"team": "enemy", "kind": "artillery", "hp": 100},
		{"team": "enemy", "kind": "artillery", "hp": 0}
	]
	if game._enemy_artillery_formation_rank(2) != 0 or game._enemy_artillery_formation_rank(4) != 2:
		push_error("Artillery formation rank must count only preceding living enemy artillery")
		quit(1)
		return
	if game._enemy_artillery_in_firing_band(184.9) or not game._enemy_artillery_in_firing_band(185.0) or not game._enemy_artillery_in_firing_band(330.0) or game._enemy_artillery_in_firing_band(330.1):
		push_error("Enemy artillery firing band must remain between 185 and 330 units")
		quit(1)
		return
	var artillery_slot_a: Vector2 = game._enemy_artillery_support_position(Vector2(500.0, 0.0), Vector2.ZERO, 0)
	var artillery_slot_b: Vector2 = game._enemy_artillery_support_position(Vector2(500.0, 0.0), Vector2.ZERO, 1)
	if artillery_slot_a.distance_to(artillery_slot_b) < 70.0 or artillery_slot_a.distance_to(Vector2(500.0, 0.0)) < 185.0:
		push_error("Artillery support positions must stay separated and behind the assault target")
		quit(1)
		return

	# Enemy counter-production must respect faction pricing, supplies, and doctrine caps.
	game.units.clear()
	game.enemy_buildings.clear()
	game.enemy_buildings.append({"kind": "airfield", "hp": 450, "build_progress": 1.0, "pos": Vector2(900.0, 300.0)})
	game.enemy_credits = 1000
	game.enemy_supplies = 10
	if not game._enemy_counter_production("air_control", 0, 0, 0, 0):
		push_error("Enemy air-control doctrine failed to produce its available fighter counter")
		quit(1)
		return
	if game.enemy_credits != 480 or game.enemy_supplies != 8:
		push_error("Enemy counter-production did not charge faction cost and supply correctly")
		quit(1)
		return
	if game.units.size() != 1 or game.units[0].kind != "fighter" or game.units[0].faction != "الصيني":
		push_error("Enemy counter-production spawned the wrong counter-unit or faction")
		quit(1)
		return
	if game._enemy_counter_production("air_control", 4, 0, 0, 0):
		push_error("Enemy air-control doctrine exceeded its fighter cap")
		quit(1)
		return
	if game.enemy_credits != 480 or game.enemy_supplies != 8 or game.units.size() != 1:
		push_error("Enemy production cap check spent resources or spawned an extra unit")
		quit(1)
		return

	game.credits = 0
	game.supplies = 0
	game.buildings.clear()
	game.production_orders.clear()
	game.production_orders.append({
		"producer_pos": Vector2(300.0, 300.0),
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	})

	game._update_production_queues(0.1)

	if not game.production_orders.is_empty():
		push_error("Destroyed producer left a stuck production order")
		quit(1)
		return
	if game.credits != 225:
		push_error("Expected 75% tank-cost refund (225 credits), got %d" % game.credits)
		quit(1)
		return
	if game.supplies != 1:
		push_error("Expected tank supply reservation to be refunded")
		quit(1)
		return

	# Replacing a producer with a different building at the same coordinates must cancel the old queue.
	game.credits = 0
	game.supplies = 0
	game.buildings.clear()
	game.buildings.append({
		"pos": Vector2(300.0, 300.0),
		"kind": "barracks",
		"hp": 400,
		"build_progress": 1.0
	})
	game.production_orders = [{
		"producer_pos": Vector2(300.0, 300.0),
		"producer_kind": "factory",
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	}]
	game._update_production_queues(0.1)
	if not game.production_orders.is_empty() or game.credits != 225 or game.supplies != 1:
		push_error("A replacement building at the old producer position must not inherit its production order")
		quit(1)
		return

	# Even a same-kind replacement at the same location is a different producer.
	game.credits = 0
	game.supplies = 0
	game.buildings.clear()
	game.buildings.append({
		"pos": Vector2(300.0, 300.0),
		"kind": "factory",
		"hp": 400,
		"build_progress": 1.0,
		"production_id": 42
	})
	game.production_orders = [{
		"producer_pos": Vector2(300.0, 300.0),
		"producer_kind": "factory",
		"producer_id": 41,
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	}]
	game._update_production_queues(0.1)
	if not game.production_orders.is_empty() or game.credits != 225 or game.supplies != 1:
		push_error("A same-kind replacement must not inherit the destroyed factory's production queue")
		quit(1)
		return

	# An existing but unfinished producer must pause, not cancel, its order.
	game.credits = 0
	game.supplies = 0
	game.buildings.append({
		"pos": Vector2(300.0, 300.0),
		"kind": "factory",
		"hp": 400,
		"build_progress": 0.5,
		"build_duration": 10.0
	})
	game.production_orders.append({
		"producer_pos": Vector2(300.0, 300.0),
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	})
	game._update_production_queues(0.1)
	if game.production_orders.size() != 1:
		push_error("Unfinished producer should keep its production order queued")
		quit(1)
		return
	if game.credits != 0 or game.supplies != 0:
		push_error("Paused production must not issue a refund")
		quit(1)
		return
	if not is_equal_approx(float(game.production_orders[0].remaining), 3.0):
		push_error("Unfinished producer should not advance production time")
		quit(1)
		return

	# Power priority: defensive structures take precedence over production buildings.
	game.buildings.clear()
	game.production_orders.clear()
	game.buildings.append({"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0})
	game.buildings.append({"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0})
	game.buildings.append({"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0})
	game.buildings.append({"pos": Vector2(400.0, 100.0), "kind": "factory", "hp": 400, "build_progress": 1.0, "production_id": 77})
	if game._player_power_capacity() != 8 or game._player_power_demand() != 10:
		push_error("Power capacity and demand totals should include completed buildings only")
		quit(1)
		return
	if game._is_player_building_powered(3):
		push_error("Production factory should lose power when higher-priority defenses consume the grid")
		quit(1)
		return
	game.production_orders = [{
		"producer_pos": Vector2(400.0, 100.0),
		"producer_kind": "factory",
		"producer_id": 77,
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	}]
	game._update_production_queues(1.0)
	if not is_equal_approx(float(game.production_orders[0].remaining), 3.0):
		push_error("Production must pause while its factory is unpowered")
		quit(1)
		return
	# A completed power plant restores production; an unfinished plant must not add capacity.
	game.buildings.append({"pos": Vector2(500.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 0.5})
	if game._player_power_capacity() != 8:
		push_error("An unfinished power plant must not contribute grid capacity")
		quit(1)
		return
	game.buildings[4]["build_progress"] = 1.0
	if game._player_power_capacity() != 22 or not game._is_player_building_powered(3):
		push_error("Completing a power plant should restore power to production")
		quit(1)
		return
	game._update_production_queues(1.0)
	if not is_equal_approx(float(game.production_orders[0].remaining), 2.0):
		push_error("Production should resume after grid power is restored")
		quit(1)
		return

	# Missile silos and interception defenses must obey the same power grid.
	game.buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "missile_silo", "hp": 500, "build_progress": 1.0, "attack_cd": 5.0}
	]
	game.missiles.clear()
	game.credits = 1200
	game.supplies = 10
	game._launch_player_missile()
	if not game.missiles.is_empty() or game.credits != 1200 or game.supplies != 10:
		push_error("An unpowered missile silo must not launch or charge for a missile")
		quit(1)
		return
	if not game.notice.contains("طاقة"):
		push_error("An existing but unpowered silo should report its power/reload state, not claim it is missing")
		quit(1)
		return
	game._update_missiles(1.0)
	if not is_equal_approx(float(game.buildings[3].attack_cd), 5.0):
		push_error("An unpowered missile silo must pause its reload timer")
		quit(1)
		return
	game.buildings.append({"pos": Vector2(500.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0})
	game.buildings[3]["attack_cd"] = 0.0
	game._launch_player_missile()
	if game.missiles.size() != 1 or game.credits >= 1200 or game.supplies != 6:
		push_error("A powered missile silo should resume launching and charge the missile cost")
		quit(1)
		return

	game.buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "missile_defense", "hp": 450, "build_progress": 1.0, "attack_cd": 0.0}
	]
	game.enemy_buildings.clear()
	game.missiles = [{"pos": Vector2(400.0, 100.0), "target": Vector2(800.0, 100.0), "target_kind": "base", "team": "enemy", "damage": 100, "life": 8.0}]
	game._update_missiles(0.1)
	if game.missiles.size() != 1 or game.buildings[3].attack_cd != 0.0:
		push_error("An unpowered missile defense must not intercept incoming missiles")
		quit(1)
		return
	game.buildings.append({"pos": Vector2(500.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0})
	game.missiles[0].pos = Vector2(400.0, 100.0)
	game._update_missiles(0.1)
	if not game.missiles.is_empty() or not is_equal_approx(float(game.buildings[3].attack_cd), 0.75):
		push_error("A powered missile defense must intercept incoming missiles")
		quit(1)
		return

	# Integrated outage: defense keeps priority while factory and missile silo pause.
	game.buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "factory", "hp": 400, "build_progress": 1.0, "production_id": 77},
		{"pos": Vector2(500.0, 100.0), "kind": "missile_silo", "hp": 500, "build_progress": 1.0, "attack_cd": 0.0},
		{"pos": Vector2(600.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0}
	]
	game.production_orders = [{
		"producer_pos": Vector2(400.0, 100.0),
		"producer_kind": "factory",
		"producer_id": 77,
		"kind": "tank",
		"remaining": 3.0,
		"duration": 3.0
	}]
	game.missiles.clear()
	game.credits = 1200
	game.supplies = 10
	game._update_production_queues(1.0)
	if not is_equal_approx(float(game.production_orders[0].remaining), 2.0):
		push_error("A powered factory should advance production while the full grid is available")
		quit(1)
		return
	game.buildings.remove_at(5)
	game._update_production_queues(1.0)
	game._launch_player_missile()
	if not is_equal_approx(float(game.production_orders[0].remaining), 2.0) or not game.missiles.is_empty():
		push_error("After power plant loss, production and missile launch must pause while defenses retain power")
		quit(1)
		return
	if game.credits != 1200 or game.supplies != 10:
		push_error("A missile launch blocked by a power outage must not consume resources")
		quit(1)
		return
	game.buildings.append({"pos": Vector2(600.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0})
	game._update_production_queues(1.0)
	game._launch_player_missile()
	if not is_equal_approx(float(game.production_orders[0].remaining), 1.0) or game.missiles.size() != 1:
		push_error("Restoring power must resume factory production and missile launch together")
		quit(1)
		return
	if game.supplies != 6 or game.credits >= 1200:
		push_error("A successful post-outage missile launch must consume its normal resources")
		quit(1)
		return

	# Destroyed player structures must neither provide nor consume grid power.
	game.buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "factory", "hp": 400, "build_progress": 1.0},
		{"pos": Vector2(500.0, 100.0), "kind": "power_plant", "hp": 0, "build_progress": 1.0}
	]
	if game._player_power_capacity() != 8 or game._player_power_demand() != 10 or game._is_player_building_powered(3):
		push_error("Destroyed player power plants must not supply capacity or power an overloaded factory")
		quit(1)
		return
	game.buildings[2]["hp"] = 0
	if game._player_power_demand() != 8 or not game._is_player_building_powered(3) or game._is_player_building_powered(2):
		push_error("Destroyed player defenses must stop consuming power and must not be reported as powered")
		quit(1)
		return

	# Enemy production and missile systems must obey the same power allocation.
	game.enemy_credits = 2000
	game.enemy_supplies = 10
	game.enemy_buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "factory", "hp": 500, "build_progress": 1.0}
	]
	if game._enemy_power_capacity() != 8 or game._enemy_power_demand() != 10:
		push_error("Enemy power capacity and demand should mirror the player's grid rules")
		quit(1)
		return
	for defense_index in range(3):
		if not game._is_enemy_building_powered(defense_index):
			push_error("Enemy defensive turrets must retain power priority over production")
			quit(1)
			return
	if game._is_enemy_building_powered(3) or game._enemy_has_powered_building("factory"):
		push_error("Enemy factory must lose power when defensive structures consume the grid")
		quit(1)
		return
	var enemy_credits_before_power_test: int = game.enemy_credits
	var enemy_supplies_before_power_test: int = game.enemy_supplies
	if game._enemy_counter_production("area_denial", 0, 0, 0, 0):
		push_error("Enemy counter-production must pause when its factory is unpowered")
		quit(1)
		return
	if game.enemy_credits != enemy_credits_before_power_test or game.enemy_supplies != enemy_supplies_before_power_test:
		push_error("Unpowered enemy production must not consume credits or supplies")
		quit(1)
		return
	game.enemy_buildings.append({"pos": Vector2(500.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 0.5})
	if game._enemy_power_capacity() != 8:
		push_error("An unfinished enemy power plant must not contribute capacity")
		quit(1)
		return
	game.enemy_buildings[4]["build_progress"] = 1.0
	if game._enemy_power_capacity() != 22 or not game._is_enemy_building_powered(3):
		push_error("Completing an enemy power plant should restore factory power")
		quit(1)
		return
	if not game._enemy_counter_production("area_denial", 0, 0, 0, 0):
		push_error("Powered enemy factory should resume counter-production")
		quit(1)
		return

	# Enemy missile launchers and interception defenses also pause without power.
	game.enemy_buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "missile_silo", "hp": 500, "build_progress": 1.0, "attack_cd": 5.0}
	]
	game.missiles.clear()
	game.enemy_credits = 1200
	game.enemy_supplies = 10
	game.enemy_missile_timer = 23.5
	game._launch_enemy_missile()
	if not game.missiles.is_empty() or game.enemy_credits != 1200 or game.enemy_supplies != 10:
		push_error("An unpowered enemy missile silo must not launch or charge resources")
		quit(1)
		return
	game._update_missiles(1.0)
	if not is_equal_approx(float(game.enemy_buildings[3].attack_cd), 5.0) or not is_equal_approx(float(game.enemy_missile_timer), 23.5):
		push_error("An unpowered enemy missile silo must pause both reload and readiness timers")
		quit(1)
		return
	game.enemy_buildings.append({"pos": Vector2(500.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0})
	game.enemy_buildings[3]["attack_cd"] = 0.0
	game._update_missiles(0.5)
	if game.missiles.size() != 1 or game.enemy_missile_timer != 0.0 or game.enemy_supplies != 6:
		push_error("A powered enemy silo should resume its paused readiness timer and launch normally")
		quit(1)
		return
	game.enemy_buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "missile_defense", "hp": 450, "build_progress": 1.0, "attack_cd": 0.0}
	]
	game.missiles = [{"pos": Vector2(400.0, 100.0), "target": Vector2(800.0, 100.0), "target_kind": "base", "team": "player", "damage": 100, "life": 8.0}]
	game._update_missiles(0.1)
	if game.missiles.size() != 1 or game.enemy_buildings[3].attack_cd != 0.0:
		push_error("An unpowered enemy missile defense must not intercept player missiles")
		quit(1)
		return
	game.enemy_buildings.append({"pos": Vector2(500.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0})
	game.missiles[0].pos = Vector2(400.0, 100.0)
	game._update_missiles(0.1)
	if not game.missiles.is_empty() or not is_equal_approx(float(game.enemy_buildings[3].attack_cd), 0.75):
		push_error("A powered enemy missile defense must intercept player missiles")
		quit(1)
		return

	# Enemy AI should invest in power before expanding beyond its available grid.
	game.enemy_buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(200.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(300.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0},
		{"pos": Vector2(400.0, 100.0), "kind": "factory", "hp": 500, "build_progress": 1.0}
	]
	game.enemy_credits = 1200
	game._enemy_ai_turn()
	if not game._enemy_has_any_building("power_plant"):
		push_error("Enemy AI should construct a power plant when current demand exceeds capacity")
		quit(1)
		return
	game.enemy_buildings = []
	for i in range(6):
		game.enemy_buildings.append({"pos": Vector2(100.0 + i * 80.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0})
	for i in range(3):
		game.enemy_buildings.append({"pos": Vector2(100.0 + i * 80.0, 220.0), "kind": "factory", "hp": 500, "build_progress": 1.0})
	game.enemy_buildings.append({"pos": Vector2(500.0, 320.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0})
	game.enemy_credits = 1200
	game._enemy_ai_turn()
	var completed_enemy_power_plants := 0
	for building in game.enemy_buildings:
		if String(building.get("kind", "")) == "power_plant":
			completed_enemy_power_plants += 1
	if completed_enemy_power_plants != 2:
		push_error("Enemy AI should add a second power plant when one plant cannot cover demand")
		quit(1)
		return

	# Enemy defensive fire must stop when the specific turret is outside the allocated grid.
	game.game_started = true
	game.paused = false
	game.battle_result = ""
	game.buildings.clear()
	game.missiles.clear()
	game.supply_points.clear()
	game.enemy_timer = 0.0
	game.enemy_missile_timer = 0.0
	game.enemy_income_timer = 0.0
	game.income_timer = 0.0
	game.units = [{
		"pos": Vector2(1700.0, 100.0),
		"team": "player",
		"kind": "tank",
		"hp": 150,
		"target": Vector2(1700.0, 100.0),
		"attack_cd": 1000.0
	}]
	game.enemy_buildings = [
		{"pos": Vector2(100.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0, "attack_cd": 0.0},
		{"pos": Vector2(500.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0, "attack_cd": 0.0},
		{"pos": Vector2(900.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0, "attack_cd": 0.0},
		{"pos": Vector2(1300.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0, "attack_cd": 0.0},
		{"pos": Vector2(1700.0, 100.0), "kind": "turret", "hp": 350, "build_progress": 1.0, "attack_cd": 0.0}
	]
	game._process(0.1)
	if int(game.units[0].hp) != 150:
		push_error("An unpowered enemy turret must not fire at player units")
		quit(1)
		return
	game.enemy_buildings.append({"pos": Vector2(1900.0, 100.0), "kind": "power_plant", "hp": 400, "build_progress": 1.0})
	game._process(0.1)
	if int(game.units[0].hp) >= 150:
		push_error("Enemy turret fire should resume when power capacity is restored")
		quit(1)
		return

	# A new battle must not inherit queued production from the finished match.
	game.game_started = true
	game.battle_result = "انتصرت! دمرت قاعدة العدو"
	game.production_orders = [{"kind": "tank", "remaining": 2.0, "duration": 3.0}]
	game.dragging = true
	game._handle_pointer(game._restart_rect(game.get_viewport_rect().size).get_center(), false)
	if game.game_started or game.battle_result != "" or not game.production_orders.is_empty():
		push_error("Restart must return to faction selection and clear stale production orders")
		quit(1)
		return
	if game.credits != 1200 or game.player_base_hp != 1000 or game.enemy_base_hp != 1000:
		push_error("Restart must restore the initial economy and both base health values")
		quit(1)
		return

	# The terminal overlay must remain clickable while the 3D battlefield is active.
	game.game_started = true
	game.battle_result = "هُزمت! سقطت قاعدتك"
	game.production_orders = [{"kind": "infantry", "remaining": 1.0, "duration": 2.0}]
	game._set_3d_view_enabled(true)
	var restart_position: Vector2 = game._restart_rect(game.get_viewport_rect().size).get_center()
	var restart_press := InputEventScreenTouch.new()
	restart_press.pressed = true
	restart_press.position = restart_position
	game._input(restart_press)
	var restart_release := InputEventScreenTouch.new()
	restart_release.pressed = false
	restart_release.position = restart_position
	game._input(restart_release)
	if game.game_started or game.battle_result != "" or not game.production_orders.is_empty():
		push_error("3D view must route the result-screen restart tap into the 2D match reset")
		quit(1)
		return
	if game.use_3d_view or game.battlefield_3d.visible:
		push_error("Restart must disable the 3D battlefield before returning to faction selection")
		quit(1)
		return

	# A final attack must show the result in the same simulation frame.
	game.game_started = true
	game.paused = false
	game.battle_result = ""
	game.enemy_base_hp = 10
	game.player_base_hp = 1000
	game.enemy_timer = 0.0
	game.enemy_income_timer = 0.0
	game.income_timer = 0.0
	game.supply_points.clear()
	game.buildings.clear()
	game.enemy_buildings.clear()
	game.production_orders.clear()
	game.units = [{
		"pos": game.enemy_base,
		"team": "player",
		"kind": "tank",
		"hp": 100,
		"attack_base": true,
		"attack_cd": 0.0
	}]
	game._process(0.1)
	if game.battle_result != "انتصرت! دمرت قاعدة العدو":
		push_error("Destroying the enemy base during combat must resolve victory in the same frame")
		quit(1)
		return

	game.battle_result = ""
	game.enemy_base_hp = 1000
	game.player_base_hp = 10
	game.enemy_timer = 0.0
	game.enemy_income_timer = 0.0
	game.income_timer = 0.0
	game.units = [{
		"pos": game.base_pos,
		"team": "enemy",
		"kind": "tank",
		"hp": 100,
		"attack_cd": 0.0
	}]
	game._process(0.1)
	if game.battle_result != "هُزمت! سقطت قاعدتك":
		push_error("Losing the player base during combat must resolve defeat in the same frame")
		quit(1)
		return

	# Base destruction resolves deterministically and immediately.
	game.battle_result = ""
	game.enemy_base_hp = 0
	game.player_base_hp = 0
	if not game._resolve_battle_result() or game.battle_result != "انتصرت! دمرت قاعدة العدو":
		push_error("Simultaneous base destruction must preserve the established player-victory precedence")
		quit(1)
		return
	game.battle_result = ""
	game.enemy_base_hp = 1000
	game.player_base_hp = 0
	if not game._resolve_battle_result() or game.battle_result != "هُزمت! سقطت قاعدتك":
		push_error("Player base destruction must resolve the defeat state")
		quit(1)
		return
	game.battle_result = ""
	game.enemy_base_hp = 1000
	game.player_base_hp = 1000
	if game._resolve_battle_result():
		push_error("Battle result must remain unset while both bases are alive")
		quit(1)
		return

	# A finished match must freeze all economic and AI simulation until restart.
	game.game_started = true
	game.paused = false
	game.battle_result = "انتصرت! دمرت قاعدة العدو"
	game.credits = 700
	game.income_timer = 0.0
	game.enemy_credits = 640
	game.enemy_income_timer = 0.5
	game.enemy_timer = 11.5
	game.production_orders = [{"kind": "tank", "remaining": 1.5, "duration": 3.0}]
	game._process(1.0)
	if game.credits != 700 or game.income_timer != 0.0:
		push_error("A completed match continued granting player passive income")
		quit(1)
		return
	if game.enemy_credits != 640 or not is_equal_approx(float(game.enemy_income_timer), 0.5) or not is_equal_approx(float(game.enemy_timer), 11.5):
		push_error("A completed match continued advancing enemy income or AI timers")
		quit(1)
		return
	if game.production_orders.size() != 1 or not is_equal_approx(float(game.production_orders[0].remaining), 1.5):
		push_error("A completed match continued advancing the production queue")
		quit(1)
		return

	print("PASS: faction costs, enemy strategy, player/enemy power grids, production recovery, and missile defense")
	quit(0)
