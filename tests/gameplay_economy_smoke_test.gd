extends SceneTree

var failure_count: int = 0

func _initialize() -> void:
	call_deferred("_run_gameplay_economy_smoke_test")


func _run_gameplay_economy_smoke_test() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Gameplay assertions do not depend on audio output. Disable the generated
	# audio pool in headless CI so AudioServer playback handles cannot outlive
	# the test SceneTree during shutdown.
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	game.set("credits", 0)
	game.set("supplies", 0)
	game.call("_initialize_supply_points", Vector2(1280.0, 720.0))
	# Isolate the port economy from the two default player/enemy supply points.
	game.get("supply_points")[0]["owner"] = "neutral"
	game.get("supply_points")[1]["owner"] = "neutral"
	var port_position: Vector2 = game.get("supply_points")[2]["pos"]
	var live_units: Array = game.get("units")
	live_units.append({"pos": port_position, "team": "player", "kind": "infantry", "hp": 60})
	game.set("units", live_units)

	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[2]["owner"]) == "player", "Player infantry should capture the neutral port")
	_expect(int(game.get("credits")) == 8, "Captured port should generate 8 credits per second")
	_expect(int(game.get("supplies")) == 0, "Port supply payout must not trigger before its 6-second interval")

	game.call("_update_supply_control", 5.0)
	_expect(int(game.get("credits")) == 48, "Port should retain fractional payout time and generate 48 credits over 6 seconds")
	_expect(int(game.get("supplies")) == 1, "Port should grant one supply point after 6 seconds")

	live_units = game.get("units")
	live_units.append({"pos": port_position, "team": "enemy", "kind": "infantry", "hp": 60})
	game.set("units", live_units)
	game.call("_update_supply_control", 4.0)
	_expect(int(game.get("credits")) == 48, "Contested port must stop paying credits")
	_expect(int(game.get("supplies")) == 1, "Contested port must stop paying supplies")

	game.get("units").clear()
	game.get("units").append({"pos": game.get("enemy_base"), "team": "enemy", "kind": "infantry", "hp": 60})
	game.get("enemy_buildings").clear()
	game.get("enemy_buildings").append({"kind": "barracks", "pos": game.get("enemy_base"), "hp": 0, "build_progress": 1.0})
	_expect(not game.call("_enemy_has_building", "barracks"), "Destroyed enemy barracks must not count as an available production structure")
	game.set("enemy_credits", 1200)
	game.call("_enemy_ai_turn")
	var rebuilt: Array = game.get("enemy_buildings")
	_expect(rebuilt.size() >= 2, "Enemy AI should rebuild a destroyed production structure when it has resources")
	var replacement_index := -1
	for building_index in range(rebuilt.size()):
		if String(rebuilt[building_index]["kind"]) == "barracks" and int(rebuilt[building_index].get("hp", 0)) > 0:
			replacement_index = building_index
			break
	_expect(replacement_index >= 0, "Enemy AI should restore its barracks before optional structures")
	_expect(float(rebuilt[replacement_index].get("build_progress", 1.0)) == 0.0, "Enemy replacement barracks should begin under construction")
	_expect(not game.call("_enemy_has_building", "barracks"), "Enemy production must not use a barracks before construction completes")
	game.call("_update_enemy_building_construction", 3.5)
	_expect(is_equal_approx(float(game.get("enemy_buildings")[replacement_index]["build_progress"]), 0.5), "Enemy construction should advance proportionally to elapsed time")
	_expect(not game.call("_enemy_has_building", "barracks"), "Enemy barracks must remain unavailable while construction is incomplete")
	game.call("_update_enemy_building_construction", 3.5)
	_expect(game.call("_enemy_has_building", "barracks"), "Enemy barracks should become available after its construction timer completes")

	# Verify that enemy reserves protect the base and the highest-value completed production asset.
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	var protected_factory_pos: Vector2 = game.get("enemy_base") + Vector2(-300.0, -100.0)
	var secondary_barracks_pos: Vector2 = game.get("enemy_base") + Vector2(-100.0, 20.0)
	game.get("enemy_buildings").append({"kind": "factory", "pos": protected_factory_pos, "hp": 500, "build_progress": 1.0})
	game.get("enemy_buildings").append({"kind": "barracks", "pos": secondary_barracks_pos, "hp": 400, "build_progress": 1.0})
	game.get("units").append({"pos": game.get("enemy_base") + Vector2(-12.0, 0.0), "team": "enemy", "kind": "tank", "hp": 150})
	game.get("units").append({"pos": protected_factory_pos + Vector2(12.0, 0.0), "team": "enemy", "kind": "tank", "hp": 150})
	for reserve_index in range(3):
		game.get("units").append({"pos": game.get("enemy_base") + Vector2(80.0 + float(reserve_index) * 35.0, 45.0), "team": "enemy", "kind": "infantry", "hp": 60})
	game.call("_update_enemy_defense_assignments")
	var guard_count := 0
	var base_guard_assigned := false
	var factory_guard_assigned := false
	for enemy_unit in game.get("units"):
		if not bool(enemy_unit.get("defense_guard", false)):
			continue
		guard_count += 1
		var guard_anchor: Vector2 = enemy_unit.get("defense_anchor", Vector2.ZERO)
		if guard_anchor.distance_to(game.get("enemy_base")) < 90.0:
			base_guard_assigned = true
		if guard_anchor.distance_to(protected_factory_pos) < 90.0:
			factory_guard_assigned = true
	_expect(guard_count == 2, "Enemy AI should assign a compact reserve when five ground units are available")
	_expect(base_guard_assigned, "Enemy AI should keep one ground guard near its main base")
	_expect(factory_guard_assigned, "Enemy AI should assign another guard to its highest-priority completed factory")

	# Critically damaged enemy armor retreats to a completed asset, heals, and then rejoins.
	game.get("enemy_buildings").clear()
	var retreat_factory_pos := Vector2(220.0, 100.0)
	game.get("enemy_buildings").append({"kind": "factory", "pos": retreat_factory_pos, "hp": 500, "build_progress": 1.0})
	game.get("enemy_buildings").append({"kind": "barracks", "pos": Vector2(102.0, 100.0), "hp": 400, "build_progress": 0.5})
	var retreat_origin := Vector2(100.0, 100.0)
	_expect(game.call("_enemy_retreat_destination", retreat_origin) == retreat_factory_pos, "Retreat routing should ignore incomplete buildings and choose the nearest completed asset")
	var wounded_tank: Dictionary = {"kind": "tank", "hp": 20, "pos": retreat_origin}
	var is_retreating: bool = game.call("_update_enemy_retreat", wounded_tank, 1.0)
	_expect(is_retreating and bool(wounded_tank.get("retreating", false)), "A critically damaged tank should enter retreat mode")
	_expect(wounded_tank.pos.distance_to(retreat_origin) > 0.0, "A retreating tank should move toward a safe completed asset")
	wounded_tank.pos = retreat_factory_pos + Vector2(40.0, 0.0)
	wounded_tank.hp = 80
	is_retreating = game.call("_update_enemy_retreat", wounded_tank, 1.0)
	_expect(is_retreating and int(wounded_tank.hp) == 88, "A retreating tank should recover 8 health per second near its safe asset")
	is_retreating = game.call("_update_enemy_retreat", wounded_tank, 1.0)
	_expect(not is_retreating and not wounded_tank.has("retreating") and int(wounded_tank.hp) >= 90, "A recovered tank should leave retreat mode at 60 percent health")

	# Verify that each adaptive strategy can order its intended counter-unit.
	game.get("enemy_buildings").clear()
	game.get("enemy_buildings").append({"kind": "airfield", "pos": game.get("enemy_base"), "hp": 450, "build_progress": 1.0})
	game.get("enemy_buildings").append({"kind": "factory", "pos": game.get("enemy_base") + Vector2(-100, 0), "hp": 500, "build_progress": 1.0})
	game.get("enemy_buildings").append({"kind": "shipyard", "pos": Vector2(game.get("enemy_base").x - 120.0, 590.0), "hp": 500, "build_progress": 1.0})
	game.set("enemy_credits", 10000)
	game.set("enemy_supplies", 100)
	var counter_cases := [
		["air_control", "fighter"],
		["armor_breaker", "helicopter"],
		["area_denial", "artillery"],
		["naval_control", "destroyer"]
	]
	for counter_case in counter_cases:
		var produced_before: int = game.get("units").size()
		var ordered: bool = game.call("_enemy_counter_production", counter_case[0], 0, 0, 0, 0)
		_expect(ordered, "Enemy strategy %s should be able to order %s" % [counter_case[0], counter_case[1]])
		_expect(game.get("units").size() == produced_before + 1, "Counter production should add exactly one unit")
		_expect(String(game.get("units")[-1]["kind"]) == counter_case[1], "Enemy strategy %s should produce %s" % [counter_case[0], counter_case[1]])


	# Exercise the complete adaptive loop: observe player composition, choose a
	# strategy, and immediately order the matching counter-unit.
	var adaptive_cases := [
		["air_control", "fighter", "fighter", 2],
		["naval_control", "destroyer", "destroyer", 2],
		["armor_breaker", "helicopter", "tank", 3],
		["area_denial", "artillery", "infantry", 5]
	]
	for adaptive_case in adaptive_cases:
		game.get("units").clear()
		game.set("enemy_strategy", "balanced")
		game.set("enemy_credits", 10000)
		game.set("enemy_supplies", 100)
		game.get("enemy_buildings").clear()
		var completed_kinds := ["barracks", "factory", "turret", "airfield", "missile_silo", "missile_defense", "shipyard", "anti_air"]
		for structure_index in range(completed_kinds.size()):
			var structure_pos: Vector2 = game.get("enemy_base") + Vector2(-float(structure_index) * 24.0, 110.0)
			if completed_kinds[structure_index] == "shipyard":
				structure_pos = Vector2(game.get("enemy_base").x - 120.0, 590.0)
			game.get("enemy_buildings").append({"kind": completed_kinds[structure_index], "pos": structure_pos, "hp": 500, "build_progress": 1.0})
		for threat_index in range(int(adaptive_case[3])):
			game.get("units").append({
				"pos": Vector2(900.0 + float(threat_index) * 24.0, 360.0),
				"team": "player",
				"kind": adaptive_case[2],
				"hp": 150
			})
		game.call("_enemy_ai_turn")
		_expect(String(game.get("enemy_strategy")) == adaptive_case[0], "Enemy AI should recognize %s player composition" % adaptive_case[0])
		_expect(not game.get("units").is_empty() and String(game.get("units")[-1].get("kind", "")) == adaptive_case[1], "Enemy AI should answer %s with %s" % [adaptive_case[0], adaptive_case[1]])


	# Guard the four faction profiles and the premium cost of the strongest "Watan" units.
	var faction_cases := [
		["الصيني", 30, 1.35, 185, 14.0, 40],
		["الأمريكي", 32, 1.25, 195, 13.0, 44],
		["الجيش العربي", 34, 1.20, 205, 12.0, 42],
		["وطن", 38, 1.10, 230, 11.0, 50]
	]
	_expect(game.get("FACTIONS").size() == 4, "The game should expose exactly four player-facing factions")
	_expect(not game.get("FACTIONS").has("GLA"), "Legacy GLA naming must not appear in player-facing faction selection")
	for faction_case in faction_cases:
		var army_name: String = faction_case[0]
		var helicopter_profile: Dictionary = {"kind": "helicopter", "faction": army_name}
		var naval_profile: Dictionary = {"kind": "destroyer", "faction": army_name}
		_expect(game.call("_helicopter_damage", helicopter_profile) == int(faction_case[1]), "%s helicopter damage should match its balance profile" % army_name)
		_expect(is_equal_approx(float(game.call("_helicopter_cooldown", helicopter_profile)), float(faction_case[2])), "%s helicopter cooldown should match its balance profile" % army_name)
		_expect(game.call("_missile_damage", army_name) == int(faction_case[3]), "%s missile damage should match its balance profile" % army_name)
		_expect(is_equal_approx(float(game.call("_missile_cooldown", army_name)), float(faction_case[4])), "%s missile cooldown should match its balance profile" % army_name)
		_expect(game.call("_naval_damage", naval_profile, -1) == int(faction_case[5]), "%s naval damage should match its balance profile" % army_name)

	# Watan has the strongest raw helicopter/missile output, but its 850-credit
	# premium should keep per-credit output within a deliberate 25% advantage.
	var china_heli_dps := 30.0 / 1.35
	var watan_heli_dps := 38.0 / 1.10
	var china_missile_dps := 185.0 / 14.0
	var watan_missile_dps := 230.0 / 11.0
	_expect(game.call("_helicopter_cost", "وطن") == 850 and game.call("_helicopter_cost", "الصيني") == 650, "Watan helicopters should carry the agreed premium cost")
	_expect(game.call("_missile_cost", "وطن") == 850 and game.call("_missile_cost", "الصيني") == 650, "Watan missiles should carry the agreed premium cost")
	_expect((watan_heli_dps / 850.0) / (china_heli_dps / 650.0) <= 1.25, "Watan helicopter damage efficiency should stay within 25% of the Chinese baseline")
	_expect((watan_missile_dps / 850.0) / (china_missile_dps / 650.0) <= 1.25, "Watan missile damage efficiency should stay within 25% of the Chinese baseline")

	# Preserve specialist naval counters regardless of faction base damage.
	game.get("units").clear()
	game.get("units").append({"kind": "submarine", "team": "enemy", "pos": Vector2.ZERO, "hp": 200})
	_expect(game.call("_naval_damage", {"kind": "destroyer", "faction": "وطن"}, 0) == 78, "Destroyers should retain their 78-damage anti-submarine role")
	_expect(game.call("_naval_damage", {"kind": "submarine", "faction": "وطن"}, -1) == 62, "Submarines should retain their 62-damage role")
	_expect(game.call("_naval_damage", {"kind": "carrier", "faction": "وطن"}, -1) == 24, "Carriers should retain their 24-damage role")

	# Validate terrain cover modifiers for infantry and ensure destroyed-unit cleanup
	# preserves index-based selections and attack orders during long battles.
	game.set("map_type", "ساحل الغابات")
	_expect(game.call("_terrain_adjusted_damage", {"kind": "infantry"}, 100) == 72, "Forest cover should reduce infantry damage by 28%")
	game.set("map_type", "الساحل الجبلي")
	_expect(game.call("_terrain_adjusted_damage", {"kind": "infantry"}, 100) == 80, "Mountain cover should reduce infantry damage by 20%")
	game.set("map_type", "المدينة الساحلية")
	_expect(game.call("_terrain_adjusted_damage", {"kind": "infantry"}, 100) == 76, "Urban cover should reduce infantry damage by 24%")
	game.set("map_type", "الساحل الصحراوي")
	_expect(game.call("_terrain_adjusted_damage", {"kind": "infantry"}, 100) == 100, "Desert terrain should not grant infantry cover")
	_expect(game.call("_terrain_adjusted_damage", {"kind": "tank"}, 100) == 100, "Infantry terrain cover must not reduce tank damage")

	game.set("map_type", "ساحل الغابات")
	# Exercise the real splash-damage path: terrain cover applies to infantry only,
	# damage stays on the intended team/radius, and lethal hits clamp at zero HP.
	game.get("units").clear()
	game.get("units").append({"kind": "infantry", "team": "player", "hp": 100, "pos": Vector2(300.0, 300.0), "attack_cd": 10.0})
	game.get("units").append({"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(310.0, 300.0)})
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 100, "pos": Vector2(305.0, 300.0)})
	game.get("units").append({"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(500.0, 300.0)})
	game.call("_apply_splash_damage", Vector2(300.0, 300.0), 48.0, 100, "player")
	_expect(int(game.get("units")[0]["hp"]) == 28, "Forest cover should reduce real splash damage to player infantry")
	_expect(int(game.get("units")[1]["hp"]) == 50, "Tanks should receive full splash damage in forest terrain")
	_expect(int(game.get("units")[2]["hp"]) == 100, "Splash damage must not hit the opposing team")
	_expect(int(game.get("units")[3]["hp"]) == 150, "Splash damage must not hit units outside its radius")
	game.call("_apply_splash_damage", Vector2(300.0, 300.0), 48.0, 100, "player")
	_expect(int(game.get("units")[0]["hp"]) == 0, "Lethal splash damage should clamp infantry health at zero")

	game.get("units").clear()
	game.get("units").append({"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(100.0, 100.0), "attack_target": 2})
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 0, "pos": Vector2(120.0, 100.0)})
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(140.0, 100.0)})
	game.get("selected").clear()
	game.get("selected").append(0)
	game.get("selected").append(1)
	game.call("_cleanup_destroyed_units")
	_expect(game.get("units").size() == 2, "Destroyed units should be removed from the active unit array")
	_expect(int(game.get("units")[0].get("attack_target", -1)) == 1, "Surviving attack orders should remap to the target's new unit index")
	_expect(game.get("selected").size() == 1 and int(game.get("selected")[0]) == 0, "Selection indices should be remapped and destroyed selections discarded")

	# Exercise real time-stepped combat through the game's _process loop.
	# Enemy artillery should damage nearby player ground units with splash,
	# while respecting team ownership; a player tank should fire its assigned target.
	game.set("map_type", "الساحل الصحراوي")
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_buildings", [])
	game.set("buildings", [])
	game.get("supply_points").clear()
	game.get("units").clear()
	game.get("units").append({"kind": "infantry", "team": "player", "hp": 100, "pos": Vector2(300.0, 300.0)})
	game.get("units").append({"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(320.0, 300.0), "attack_cd": 10.0})
	game.get("units").append({"kind": "artillery", "team": "enemy", "hp": 180, "pos": Vector2(290.0, 300.0), "attack_cd": 0.0})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 76, "Enemy artillery should deal its real 24-point splash damage to player infantry")
	_expect(int(game.get("units")[1]["hp"]) == 126, "Enemy artillery splash should damage nearby player armor")

	game.get("units").clear()
	game.get("units").append({"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(400.0, 300.0), "attack_target": 1, "attack_cd": 0.0})
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 100, "pos": Vector2(420.0, 300.0), "attack_cd": 10.0})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[1]["hp"]) == 80, "Player tank should deal its real 20-point direct hit through the combat loop")

	# Exercise real anti-air combat from both sides using the live _process loop.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_missile_timer", 0.0)
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("units").clear()
	game.get("enemy_buildings").append({
		"kind": "anti_air", "pos": Vector2(500.0, 300.0),
		"hp": 500, "build_progress": 1.0, "attack_cd": 0.0
	})
	game.get("units").append({
		"kind": "fighter", "team": "player", "faction": "الصيني",
		"hp": 120, "pos": Vector2(520.0, 300.0), "attack_cd": 10.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 86, "Completed enemy anti-air should deal its real 34-point hit to a player fighter")
	_expect(is_equal_approx(float(game.get("enemy_buildings")[0]["attack_cd"]), 0.65), "Enemy anti-air should use its 0.65-second firing cycle")

	game.get("buildings").append({
		"kind": "anti_air", "pos": Vector2(500.0, 300.0),
		"hp": 500, "build_progress": 1.0, "attack_cd": 0.0
	})
	game.get("units").clear()
	game.get("units").append({
		"kind": "fighter", "team": "enemy", "faction": "الصيني",
		"hp": 120, "pos": Vector2(520.0, 300.0), "attack_cd": 10.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 86, "Powered player anti-air should deal its real 34-point hit to an enemy fighter")
	_expect(is_equal_approx(float(game.get("buildings")[0]["attack_cd"]), 0.65), "Player anti-air should use its 0.65-second firing cycle")

	# Exercise real fighter-vs-fighter dogfights in both directions.
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("units").clear()
	game.get("units").append({
		"kind": "fighter", "team": "player", "faction": "الأمريكي",
		"hp": 120, "pos": Vector2(500.0, 300.0), "attack_cd": 0.0
	})
	game.get("units").append({
		"kind": "fighter", "team": "enemy", "faction": "الصيني",
		"hp": 120, "pos": Vector2(520.0, 300.0), "attack_cd": 0.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 90, "Enemy fighter should return fire for 30 damage in an air-to-air engagement")
	_expect(int(game.get("units")[1]["hp"]) == 90, "Player fighter should deal its real 30-damage air-to-air hit")
	_expect(is_equal_approx(float(game.get("units")[0]["attack_cd"]), 1.35), "Player fighter should use its 1.35-second firing cycle")

	# Verify faction-specific helicopter damage and cooldown through live combat.
	game.get("units").clear()
	game.get("units").append({
		"kind": "tank", "team": "enemy", "hp": 150,
		"pos": Vector2(420.0, 300.0), "attack_cd": 10.0
	})
	game.get("units").append({
		"kind": "helicopter", "team": "player", "faction": "الصيني",
		"hp": 160, "pos": Vector2(400.0, 300.0), "attack_cd": 0.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 120, "Chinese helicopter should deal its real 30-point hit to enemy armor")
	_expect(is_equal_approx(float(game.get("units")[1]["attack_cd"]), 1.35), "Chinese helicopter should use its 1.35-second firing cycle")

	game.get("units").clear()
	game.get("units").append({
		"kind": "helicopter", "team": "enemy", "faction": "الأمريكي",
		"hp": 160, "pos": Vector2(400.0, 300.0), "attack_cd": 0.0
	})
	game.get("units").append({
		"kind": "tank", "team": "player", "hp": 150,
		"pos": Vector2(420.0, 300.0), "attack_cd": 10.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[1]["hp"]) == 118, "American helicopter should deal its real 32-point hit to player armor")
	_expect(is_equal_approx(float(game.get("units")[0]["attack_cd"]), 1.25), "American helicopter should use its 1.25-second firing cycle")

	# Anti-air must also counter helicopters, not only fixed-wing fighters.
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("enemy_buildings").append({
		"kind": "anti_air", "pos": Vector2(500.0, 300.0),
		"hp": 500, "build_progress": 1.0, "attack_cd": 0.0
	})
	game.get("units").clear()
	game.get("units").append({
		"kind": "helicopter", "team": "player", "faction": "الصيني",
		"hp": 160, "pos": Vector2(520.0, 300.0), "attack_cd": 10.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 126, "Enemy anti-air should deal its 34-point counter hit to a player helicopter")

	# Naval combat: destroyers must expose and punish hostile submarines.
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("units").clear()
	game.get("units").append({
		"kind": "destroyer", "team": "player", "faction": "الأمريكي",
		"hp": 200, "pos": Vector2(500.0, 300.0), "attack_cd": 0.0
	})
	game.get("units").append({
		"kind": "submarine", "team": "enemy", "faction": "الصيني",
		"hp": 200, "pos": Vector2(520.0, 300.0), "attack_cd": 0.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[1]["hp"]) == 122, "Destroyer should deal its specialist 78 damage to a detected enemy submarine")
	_expect(int(game.get("units")[0]["hp"]) == 138, "Submarine should return its 62-damage strike against an enemy destroyer")

	# Mirror the destroyer/submarine duel from the enemy AI side.
	game.get("units").clear()
	game.get("units").append({
		"kind": "destroyer", "team": "enemy", "faction": "الصيني",
		"hp": 200, "pos": Vector2(500.0, 300.0), "attack_cd": 0.0
	})
	game.get("units").append({
		"kind": "submarine", "team": "player", "faction": "وطن",
		"hp": 200, "pos": Vector2(520.0, 300.0), "attack_cd": 0.0
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[1]["hp"]) == 122, "Enemy destroyer should retain its 78-damage anti-submarine counter")
	_expect(int(game.get("units")[0]["hp"]) == 138, "Player submarine should retaliate for its 62-damage specialist strike")

	# Sonar detection must respect destroyer range and remain hidden outside it.
	game.get("units").clear()
	var sonar_submarine: Dictionary = {"kind": "submarine", "team": "enemy", "hp": 200, "pos": Vector2(500.0, 300.0)}
	game.get("units").append(sonar_submarine)
	_expect(not bool(game.call("_is_submarine_detected", sonar_submarine, "player")), "Submarine should remain hidden without a friendly sonar observer")
	game.get("units").append({"kind": "destroyer", "team": "player", "hp": 200, "pos": Vector2(690.0, 300.0)})
	_expect(bool(game.call("_is_submarine_detected", sonar_submarine, "player")), "Destroyer sonar should reveal a submarine inside 190 units")
	game.get("units")[1]["pos"] = Vector2(691.0, 300.0)
	_expect(not bool(game.call("_is_submarine_detected", sonar_submarine, "player")), "Submarine should become hidden again outside destroyer sonar range")

	# Carrier launches a limited fighter sortie when its deck cycle is ready.
	game.get("units").clear()
	game.get("units").append({
		"kind": "carrier", "team": "player", "faction": "الأمريكي",
		"hp": 900, "pos": Vector2(500.0, 300.0), "attack_cd": 0.0, "launch_cd": 0.0
	})
	game.call("_process", 0.1)
	var carrier_fighter_count := 0
	for air_unit in game.get("units"):
		if air_unit.team == "player" and air_unit.kind == "fighter" and bool(air_unit.get("carrier_home", false)):
			carrier_fighter_count += 1
	_expect(carrier_fighter_count == 1, "Ready carrier should launch one recoverable fighter sortie")
	_expect(is_equal_approx(float(game.get("units")[0]["launch_cd"]), 18.0), "Carrier should observe its 18-second launch cycle")

	# Landing craft must unload its three marines at the hostile shore.
	game.get("units").clear()
	var landing_shore: Vector2 = Vector2(game.get("enemy_base").x, game.get_viewport_rect().size.y * 0.82)
	game.get("units").append({
		"kind": "landing_craft", "team": "player", "faction": "الأمريكي",
		"hp": 320, "pos": landing_shore, "home_pos": Vector2(300.0, 600.0),
		"attack_cd": 0.0, "landing_state": "outbound", "passengers": 3
	})
	game.call("_process", 0.1)
	var landed_marines := 0
	for landing_unit in game.get("units"):
		if landing_unit.team == "player" and landing_unit.kind == "infantry" and bool(landing_unit.get("landing_assault", false)):
			landed_marines += 1
	_expect(landed_marines == 3, "Landing craft should deploy its complete three-marine assault squad")
	_expect(String(game.get("units")[0].get("landing_state", "")) == "returning", "Landing craft should return to its home dock after unloading")

	# Verify faction-specific missile launch cost, damage, and reload timing.
	game.set("faction", "وطن")
	game.set("credits", 2000)
	game.set("supplies", 5)
	game.get("buildings").clear()
	game.get("buildings").append({
		"kind": "missile_silo", "pos": Vector2(180.0, 330.0),
		"hp": 500, "build_progress": 1.0, "attack_cd": 0.0
	})
	game.get("missiles").clear()
	game.call("_launch_player_missile")
	_expect(int(game.get("credits")) == 1150, "Watan missile launch should deduct its 850-credit premium")
	_expect(int(game.get("supplies")) == 1, "Missile launch should consume four supply points")
	_expect(game.get("missiles").size() == 1 and int(game.get("missiles")[0]["damage"]) == 230, "Watan missile should launch with its 230-damage warhead")
	_expect(is_equal_approx(float(game.get("buildings")[0]["attack_cd"]), 11.0), "Watan missile silo should reload in 11 seconds")

	# Missile defense must intercept an incoming hostile missile before impact.
	game.get("buildings").clear()
	game.get("buildings").append({
		"kind": "missile_defense", "pos": Vector2(300.0, 300.0),
		"hp": 500, "build_progress": 1.0, "attack_cd": 0.0
	})
	game.get("missiles").clear()
	game.get("missiles").append({
		"pos": Vector2(310.0, 300.0), "target": Vector2(180.0, 330.0),
		"target_kind": "base", "team": "enemy", "damage": 195, "life": 8.0
	})
	var base_health_before_intercept: int = int(game.get("player_base_hp"))
	game.call("_update_missiles", 0.1)
	_expect(game.get("missiles").is_empty(), "Missile defense should remove an incoming missile inside its 190-unit interception radius")
	_expect(int(game.get("player_base_hp")) == base_health_before_intercept, "An intercepted missile must not damage the player base")
	_expect(is_equal_approx(float(game.get("buildings")[0]["attack_cd"]), 0.75), "Missile defense should observe its 0.75-second intercept cooldown")

	# Stop and release generated audio resources before freeing the test scene.
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		audio_player.queue_free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()
	game.queue_free()
	# Allow queued nodes and generated combat effects to leave the tree cleanly.
	for frame in range(4):
		await process_frame
	if failure_count > 0:
		push_error("Gameplay smoke test failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Gameplay smoke test passed: supply economy, enemy recovery, and all four adaptive counter-production strategies.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Gameplay economy smoke test failed: " + message)
