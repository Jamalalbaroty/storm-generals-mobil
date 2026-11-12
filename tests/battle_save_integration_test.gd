extends SceneTree

var failure_count := 0


func _initialize() -> void:
	call_deferred("_run_battle_save_integration_test")


func _run_battle_save_integration_test() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	# Stable IDs must be reserved before assigning IDs to earlier unassigned records.
	game.set("next_unit_identity", 1)
	game.get("units").assign([
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(100.0, 100.0)},
		{"unit_id": "unit_00000001", "kind": "infantry", "team": "player", "hp": 60, "pos": Vector2(130.0, 100.0)}
	])
	game.call("_ensure_stable_unit_identities")
	_expect(String(game.get("units")[0].get("unit_id", "")) == "unit_00000002", "Unassigned earlier spawn must not steal a later unit's reserved stable ID")
	_expect(String(game.get("units")[1].get("unit_id", "")) == "unit_00000001", "Existing stable unit ID must remain unchanged")
	game.get("units").remove_at(0)
	game.call("_ensure_stable_unit_identities")
	_expect(String(game.get("units")[0].get("unit_id", "")) == "unit_00000001", "Stable identity must survive unit-array compaction")
	game.get("units").clear()

	# Android single-finger drag selection: secondary touches must not steal the active gesture.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("use_3d_view", false)
	game.get("units").assign([
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(110.0, 110.0)},
		{"kind": "infantry", "team": "player", "hp": 100, "pos": Vector2(135.0, 125.0)}
	])
	var primary_touch := InputEventScreenTouch.new()
	primary_touch.index = 1
	primary_touch.position = Vector2(75.0, 75.0)
	primary_touch.pressed = true
	game.call("_input", primary_touch)
	var secondary_touch := InputEventScreenTouch.new()
	secondary_touch.index = 2
	secondary_touch.position = Vector2(350.0, 350.0)
	secondary_touch.pressed = true
	game.call("_input", secondary_touch)
	var primary_drag := InputEventScreenDrag.new()
	primary_drag.index = 1
	primary_drag.position = Vector2(165.0, 155.0)
	game.call("_input", primary_drag)
	var primary_release := InputEventScreenTouch.new()
	primary_release.index = 1
	primary_release.position = Vector2(165.0, 155.0)
	primary_release.pressed = false
	game.call("_input", primary_release)
	_expect(game.get("selected").size() == 2 and game.get("selected").has(0) and game.get("selected").has(1), "Android drag selection must retain its primary finger when a secondary finger touches the screen")
	_expect(int(game.get("active_touch_index")) == -1 and not bool(game.get("dragging")), "Android touch release must clear pointer ownership and finish the selection gesture")
	var canceled_touch := InputEventScreenTouch.new()
	canceled_touch.index = 3
	canceled_touch.position = Vector2(90.0, 90.0)
	canceled_touch.pressed = true
	game.call("_input", canceled_touch)
	canceled_touch.canceled = true
	canceled_touch.pressed = false
	game.call("_input", canceled_touch)
	_expect(int(game.get("active_touch_index")) == -1 and not bool(game.get("dragging")), "Android system-canceled touch must safely abort the active gesture")
	game.get("units").clear()
	game.set("game_started", false)

	# Zero Hour-style combat veterancy: promotion thresholds, damage bonuses, and faction ownership.
	var veteran_test_unit: Dictionary = {"unit_id": "veterancy_test", "kind": "tank", "team": "player", "hp": 150, "pos": Vector2.ZERO, "combat_xp": 0.0, "veterancy": 0}
	game.call("_award_unit_experience", veteran_test_unit, 199)
	_expect(is_equal_approx(float(veteran_test_unit.get("combat_xp", 0.0)), 99.5) and int(veteran_test_unit.get("veterancy", 0)) == 0, "A unit must not promote before reaching 100 combat XP")
	game.call("_award_unit_experience", veteran_test_unit, 1)
	_expect(int(veteran_test_unit.get("veterancy", 0)) == 1, "A unit must become veteran at 100 combat XP")
	_expect(int(game.call("_unit_damage_with_veterancy", veteran_test_unit, 100)) == 108, "Veteran units must receive the established 8 percent damage bonus")
	game.call("_award_unit_experience", veteran_test_unit, 300)
	_expect(int(veteran_test_unit.get("veterancy", 0)) == 2, "A unit must become elite at 250 combat XP")
	_expect(int(game.call("_unit_damage_with_veterancy", veteran_test_unit, 100)) == 115, "Elite units must receive the established 15 percent damage bonus")
	game.call("_award_unit_experience", veteran_test_unit, 500)
	_expect(int(veteran_test_unit.get("veterancy", 0)) == 3, "A unit must become heroic at 500 combat XP")
	_expect(int(game.call("_unit_damage_with_veterancy", veteran_test_unit, 100)) == 125, "Heroic units must receive the established 25 percent damage bonus")
	_expect(int(game.call("_unit_damage_taken_with_veterancy", {"veterancy": 0}, 100)) == 100, "Unranked units must not receive a veterancy defense bonus")
	_expect(int(game.call("_unit_damage_taken_with_veterancy", {"veterancy": 1}, 100)) == 97, "Veteran units must take 3 percent less damage")
	_expect(int(game.call("_unit_damage_taken_with_veterancy", {"veterancy": 2}, 100)) == 94, "Elite units must take 6 percent less damage")
	_expect(int(game.call("_unit_damage_taken_with_veterancy", {"veterancy": 3}, 100)) == 91, "Heroic units must take 9 percent less damage")
	_expect(is_equal_approx(float(game.call("_artillery_blast_radius_with_veterancy", {"veterancy": 0}, 76.0)), 76.0), "Unranked artillery must retain its base blast radius")
	_expect(is_equal_approx(float(game.call("_artillery_blast_radius_with_veterancy", {"veterancy": 1}, 76.0)), 78.28), "Veteran artillery must gain 3 percent blast radius")
	_expect(is_equal_approx(float(game.call("_artillery_blast_radius_with_veterancy", {"veterancy": 2}, 76.0)), 80.56), "Elite artillery must gain 6 percent blast radius")
	_expect(is_equal_approx(float(game.call("_artillery_blast_radius_with_veterancy", {"veterancy": 3}, 76.0)), 83.6), "Heroic artillery must gain 10 percent blast radius")
	_expect(is_equal_approx(float(game.call("_tank_reload_cooldown_with_veterancy", {"veterancy": 0}, 0.75)), 0.75), "Unranked tanks must retain base reload time")
	_expect(is_equal_approx(float(game.call("_tank_reload_cooldown_with_veterancy", {"veterancy": 1}, 0.75)), 0.7275), "Veteran tanks must reload 3 percent faster")
	_expect(is_equal_approx(float(game.call("_tank_reload_cooldown_with_veterancy", {"veterancy": 2}, 0.75)), 0.705), "Elite tanks must reload 6 percent faster")
	_expect(is_equal_approx(float(game.call("_tank_reload_cooldown_with_veterancy", {"veterancy": 3}, 0.75)), 0.675), "Heroic tanks must reload 10 percent faster")
	_expect(is_equal_approx(float(game.call("_tank_reload_cooldown_with_veterancy", {"veterancy": 3}, 2.4)), 2.16), "Tank reload specialization must scale proportionally across cooldown values")
	var enemy_veterancy_test: Dictionary = {"unit_id": "enemy_veterancy_test", "kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2.ZERO, "combat_xp": 0.0, "veterancy": 0}
	game.call("_award_unit_experience", enemy_veterancy_test, 500)
	_expect(float(enemy_veterancy_test.get("combat_xp", 0.0)) == 250.0 and int(enemy_veterancy_test.get("veterancy", 0)) == 2, "Enemy units must earn elite veterancy just like player units")
	_expect(float(veteran_test_unit.get("combat_xp", 0.0)) == 500.0, "Veterancy XP must accumulate exactly across combat awards")
	# Veterancy is part of the persisted unit record and must survive snapshot creation.
	game.get("units").assign([veteran_test_unit.duplicate(true), enemy_veterancy_test.duplicate(true)])
	var veterancy_snapshot: Dictionary = game.call("_build_battle_snapshot")
	_expect(float(veterancy_snapshot["units"][0].get("combat_xp", -1.0)) == 500.0 and int(veterancy_snapshot["units"][0].get("veterancy", -1)) == 3, "Battle snapshots must preserve player combat XP and heroic rank")
	_expect(float(veterancy_snapshot["units"][1].get("combat_xp", -1.0)) == 250.0 and int(veterancy_snapshot["units"][1].get("veterancy", -1)) == 2, "Battle snapshots must preserve enemy combat XP and elite rank")
	var save_store: Object = game.get("battle_save_store")
	_expect(bool(save_store.call("_validate_unit_identity", veteran_test_unit.duplicate(true), {})), "Valid veterancy data must pass save validation")
	var invalid_xp_unit: Dictionary = veteran_test_unit.duplicate(true)
	invalid_xp_unit["combat_xp"] = -1.0
	_expect(not bool(save_store.call("_validate_unit_identity", invalid_xp_unit, {})), "Negative combat XP must be rejected by save validation")
	var invalid_rank_unit: Dictionary = veteran_test_unit.duplicate(true)
	invalid_rank_unit["veterancy"] = 4
	_expect(not bool(save_store.call("_validate_unit_identity", invalid_rank_unit, {})), "Out-of-range veterancy rank must be rejected by save validation")
	game.get("units").clear()

	# Four-army balance contract: each army keeps its intended economic and combat identity.
	_expect(int(game.call("_unit_cost", "tank", "الصيني")) == 270, "Chinese armor must retain the lowest tank cost")
	_expect(int(game.call("_unit_cost", "tank", "الأمريكي")) == 300, "American tank cost must remain the combined-arms baseline")
	_expect(int(game.call("_unit_cost", "infantry", "الجيش العربي")) == 90, "Arab infantry must retain its affordability advantage")
	_expect(int(game.call("_unit_cost", "artillery", "الجيش العربي")) == 430, "Arab artillery must retain its field-support cost advantage")
	_expect(int(game.call("_unit_cost", "tank", "وطن")) == 360, "Watan elite tanks must retain a deliberate production premium")
	_expect(int(game.call("_unit_cost", "fighter", "وطن")) == 575, "Watan air power must retain its reinforcement premium")
	_expect(int(game.call("_missile_damage", "وطن")) == 230 and int(game.call("_missile_cost", "وطن")) == 850, "Watan's stronger strategic missile must retain its higher resource cost")
	_expect(int(game.call("_missile_damage", "الصيني")) == 185 and int(game.call("_missile_cost", "الصيني")) == 650, "Chinese strategic missiles must retain the lower-cost, lower-damage profile")
	_expect(int(game.call("_unit_cost", "tank", "وطن")) > int(game.call("_unit_cost", "tank", "الأمريكي")) and int(game.call("_unit_cost", "tank", "الصيني")) < int(game.call("_unit_cost", "tank", "الأمريكي")), "Elite Watan and efficient Chinese armor must remain distinct from the American baseline")

	# Land/air focus: verify each faction's helicopter and strategic missile combat profile.
	var air_profile_contract := {
		"الصيني": {"helicopter_damage": 30, "helicopter_cooldown": 1.35, "missile_damage": 185, "missile_cooldown": 14.0},
		"الأمريكي": {"helicopter_damage": 32, "helicopter_cooldown": 1.25, "missile_damage": 195, "missile_cooldown": 13.0},
		"الجيش العربي": {"helicopter_damage": 34, "helicopter_cooldown": 1.20, "missile_damage": 205, "missile_cooldown": 12.0},
		"وطن": {"helicopter_damage": 38, "helicopter_cooldown": 1.10, "missile_damage": 230, "missile_cooldown": 11.0}
	}
	for army_name in air_profile_contract:
		var expected_air_profile: Dictionary = air_profile_contract[army_name]
		var helicopter_fixture: Dictionary = {"kind": "helicopter", "faction": String(army_name)}
		_expect(int(game.call("_helicopter_damage", helicopter_fixture)) == int(expected_air_profile["helicopter_damage"]), "Helicopter damage must match the approved faction profile for " + String(army_name))
		_expect(is_equal_approx(float(game.call("_helicopter_cooldown", helicopter_fixture)), float(expected_air_profile["helicopter_cooldown"])), "Helicopter reload must match the approved faction profile for " + String(army_name))
		_expect(int(game.call("_missile_damage", String(army_name))) == int(expected_air_profile["missile_damage"]), "Strategic missile damage must match the approved faction profile for " + String(army_name))
		_expect(is_equal_approx(float(game.call("_missile_cooldown", String(army_name))), float(expected_air_profile["missile_cooldown"])), "Strategic missile cooldown must match the approved faction profile for " + String(army_name))

	var aircraft_cost_contract := {
		"الصيني": {"helicopter": 650, "fighter": 520},
		"الأمريكي": {"helicopter": 650, "fighter": 500},
		"الجيش العربي": {"helicopter": 650, "fighter": 500},
		"وطن": {"helicopter": 850, "fighter": 575}
	}
	for army_name in aircraft_cost_contract:
		var expected_aircraft_costs: Dictionary = aircraft_cost_contract[army_name]
		_expect(int(game.call("_unit_cost", "helicopter", String(army_name))) == int(expected_aircraft_costs["helicopter"]), "Helicopter production cost must match the approved faction economy for " + String(army_name))
		_expect(int(game.call("_unit_cost", "fighter", String(army_name))) == int(expected_aircraft_costs["fighter"]), "Fighter production cost must match the approved faction economy for " + String(army_name))

	# Shared construction economy remains consistent across all four factions.
	var building_cost_contract := {
		"barracks": 250, "factory": 450, "turret": 350, "airfield": 600,
		"anti_air": 400, "missile_silo": 800, "missile_defense": 700,
		"power_plant": 450, "bunker": 520, "supply_depot": 550,
		"wall": 90, "wall_corner": 120, "wall_gate": 150
	}
	for building_kind in building_cost_contract:
		var expected_building_cost := int(building_cost_contract[building_kind])
		_expect(int(game.call("_building_cost", String(building_kind))) == expected_building_cost, "All armies must use the approved shared construction cost for " + String(building_kind))
	for army_name in ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]:
		_expect(int(game.call("_unit_cost", "transport_helicopter", String(army_name))) == (1200 if army_name == "وطن" else 950), "Transport helicopter cost must preserve the Watan premium and shared baseline for " + String(army_name))
		_expect(int(game.call("_unit_supply_cost", "tank")) == 1, "Unit supply requirements must remain consistent across factions")

	# Land and air defensive structures must retain predictable durability and upgrade scaling.
	_expect(int(game.call("_building_max_hp", {"kind": "turret", "level": 1})) == 400, "Ground turret must retain its baseline durability")
	_expect(int(game.call("_building_max_hp", {"kind": "anti_air", "level": 1})) == 400, "Anti-air defense must retain its baseline durability")
	_expect(int(game.call("_building_max_hp", {"kind": "bunker", "level": 1})) == 650, "Bunker must retain its stronger defensive durability")
	_expect(int(game.call("_building_max_hp", {"kind": "missile_defense", "level": 1})) == 450, "Missile defense must retain its dedicated durability")
	_expect(int(game.call("_building_max_hp", {"kind": "turret", "level": 2})) == 480, "Level-two ground defenses must gain the established 20 percent durability")
	_expect(int(game.call("_building_max_hp", {"kind": "anti_air", "level": 3})) == 560, "Level-three anti-air defenses must scale consistently with upgrades")

	# Zero Hour-style enemy doctrine: react to the strongest land/air threat and avoid strategy flicker.
	game.set("enemy_strategy", "balanced")
	_expect(String(game.call("_enemy_choose_strategy", 2, 0, 0, 0)) == "air_control", "Enemy AI must choose air control when hostile aircraft create the strongest threat")
	game.set("enemy_strategy", "balanced")
	_expect(String(game.call("_enemy_choose_strategy", 0, 0, 3, 0)) == "armor_breaker", "Enemy AI must choose armor breaker against a concentrated tank/artillery threat")
	game.set("enemy_strategy", "balanced")
	_expect(String(game.call("_enemy_choose_strategy", 0, 0, 0, 5)) == "area_denial", "Enemy AI must choose area denial against a large infantry force")
	game.set("enemy_strategy", "balanced")
	_expect(String(game.call("_enemy_choose_strategy", 0, 0, 0, 0)) == "balanced", "Enemy AI must retain balanced doctrine when no battlefield threat is present")
	game.set("enemy_strategy", "air_control")
	_expect(String(game.call("_enemy_choose_strategy", 2, 0, 2, 0)) == "air_control", "Enemy doctrine must use hysteresis to avoid flickering between nearly equal threats")
	game.set("enemy_strategy", "air_control")
	_expect(String(game.call("_enemy_choose_strategy", 1, 0, 5, 0)) == "armor_breaker", "Enemy AI must switch doctrine when a clearly stronger armor threat emerges")
	game.set("enemy_strategy", "balanced")

	# Counter-production doctrine must answer land and air threats with the correct units.
	game.set("enemy_strategy", "air_control")
	game.set("enemy_credits", 5000)
	game.set("enemy_supplies", 20)
	game.get("enemy_buildings").assign([{"kind": "airfield", "hp": 450, "build_progress": 1.0, "pos": Vector2(700.0, 300.0)}])
	game.get("units").clear()
	_expect(bool(game.call("_enemy_counter_production", "air_control", 0, 0, 0, 0)), "Enemy AI must produce a fighter when air control is needed and a powered airfield is available")
	_expect(String(game.get("units")[-1].get("kind", "")) == "fighter", "Air-control counter production must deploy a fighter")
	game.get("units").clear()
	game.set("enemy_strategy", "armor_breaker")
	_expect(bool(game.call("_enemy_counter_production", "armor_breaker", 0, 0, 0, 0)), "Enemy AI must produce an attack helicopter against armor when an airfield is available")
	_expect(String(game.get("units")[-1].get("kind", "")) == "helicopter", "Armor-breaker counter production must deploy a helicopter")
	game.get("units").clear()
	game.set("enemy_strategy", "area_denial")
	game.get("enemy_buildings").assign([{"kind": "factory", "hp": 500, "build_progress": 1.0, "pos": Vector2(700.0, 300.0)}])
	_expect(bool(game.call("_enemy_counter_production", "area_denial", 0, 0, 0, 0)), "Enemy AI must produce artillery against infantry concentrations when a factory is available")
	_expect(String(game.get("units")[-1].get("kind", "")) == "artillery", "Area-denial counter production must deploy artillery")
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	game.set("enemy_strategy", "balanced")
	game.set("enemy_credits", 0)
	game.set("enemy_supplies", 0)

	# Enemy base management: repair the most damaged completed asset without starving unit production.
	game.set("faction", "وطن")
	game.set("enemy_credits", 1000)
	game.get("enemy_buildings").assign([
		{"kind": "turret", "hp": 200, "build_progress": 1.0, "pos": Vector2(800.0, 260.0)},
		{"kind": "factory", "hp": 200, "build_progress": 1.0, "pos": Vector2(900.0, 300.0)},
		{"kind": "barracks", "hp": 100, "build_progress": 0.4, "pos": Vector2(950.0, 360.0)}
	])
	_expect(bool(game.call("_enemy_repair_damaged_building")), "Enemy AI must repair a critically damaged completed building when it can afford repairs and preserve an infantry reserve")
	_expect(int(game.get("enemy_buildings")[1].get("hp", 0)) == int(game.call("_enemy_building_max_hp", game.get("enemy_buildings")[1])), "Enemy AI must prioritize the most damaged completed building for repair")
	_expect(int(game.get("enemy_buildings")[0].get("hp", 0)) == 200, "Enemy repair must not waste resources repairing a less damaged asset first")
	game.set("enemy_credits", 200)
	game.get("enemy_buildings")[1]["hp"] = 200
	_expect(not bool(game.call("_enemy_repair_damaged_building")), "Enemy AI must preserve enough credits for a minimum infantry reserve instead of overspending on repairs")
	_expect(int(game.get("enemy_buildings")[1].get("hp", 0)) == 200, "Unaffordable enemy repairs must leave building durability unchanged")
	_expect(bool(game.call("_enemy_has_building_under_construction", "barracks")), "Enemy AI must recognize an existing barracks under construction and avoid duplicate construction")
	_expect(not bool(game.call("_enemy_has_building_under_construction", "airfield")), "Enemy AI must not report absent production buildings as under construction")
	game.get("enemy_buildings").clear()
	game.set("enemy_credits", 1200)
	game.set("faction", "")

	# Enemy bunkers must acquire ground attackers only, never nearby aircraft or transports.
	game.get("units").assign([
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2(20.0, 0.0)},
		{"kind": "transport_helicopter", "team": "player", "hp": 220, "pos": Vector2(35.0, 0.0)},
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(90.0, 0.0)},
		{"kind": "infantry", "team": "player", "hp": 0, "pos": Vector2(10.0, 0.0)}
	])
	_expect(int(game.call("_nearest_player_ground_unit", Vector2.ZERO, 185.0)) == 2, "Enemy bunker targeting must ignore aircraft, transports, and destroyed ground units")
	game.get("units").clear()
	# Enemy anti-air batteries must prioritize fighters over helicopters and ground units.
	game.get("enemy_buildings").assign([
		{"kind": "airfield", "hp": 600, "pos": Vector2(0.0, 0.0)}
	])
	game.get("units").assign([
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(15.0, 0.0)},
		{"kind": "helicopter", "team": "player", "hp": 160, "pos": Vector2(40.0, 0.0)},
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2(75.0, 0.0)}
	])
	_expect(int(game.call("_priority_air_target", Vector2.ZERO, "player", 320.0)) == 2, "Anti-air target selection must prioritize fighters threatening strategic installations over helicopters and ground units")
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	# Enemy ground assault target selection must exclude aircraft and retain only living ground forces.
	game.get("units").assign([
		{"kind": "fighter", "team": "enemy", "hp": 180, "pos": Vector2(5.0, 0.0)},
		{"kind": "helicopter", "team": "enemy", "hp": 160, "pos": Vector2(15.0, 0.0)},
		{"kind": "artillery", "team": "enemy", "hp": 220, "pos": Vector2(60.0, 0.0)},
		{"kind": "tank", "team": "enemy", "hp": 0, "pos": Vector2(10.0, 0.0)}
	])
	_expect(int(game.call("_nearest_enemy_ground_unit", Vector2.ZERO, 185.0)) == 2, "Player bunker targeting must ignore enemy aircraft and destroyed units while selecting artillery")
	game.get("units").clear()
	# Zero Hour-style role targeting: attack helicopters seek armor/ground support, fighters seek hostile aircraft.
	game.get("units").assign([
		{"kind": "fighter", "team": "enemy", "hp": 180, "pos": Vector2(20.0, 0.0)},
		{"kind": "helicopter", "team": "enemy", "hp": 160, "pos": Vector2(35.0, 0.0)},
		{"kind": "tank", "team": "enemy", "hp": 300, "pos": Vector2(90.0, 0.0)},
		{"kind": "artillery", "team": "enemy", "hp": 220, "pos": Vector2(130.0, 0.0)}
	])
	_expect(int(game.call("_nearest_unit_by_priority", Vector2.ZERO, 760.0, "enemy", ["tank", "artillery", "infantry"])) == 2, "Attack helicopters must prioritize ground armor over closer air contacts")
	_expect(int(game.call("_nearest_unit_by_priority", Vector2.ZERO, 320.0, "enemy", ["fighter", "helicopter", "transport_helicopter"])) == 0, "Fighters must prioritize hostile aircraft over closer ground targets")
	_expect(int(game.call("_nearest_unit_by_priority", Vector2.ZERO, 19.0, "enemy", ["fighter", "helicopter", "transport_helicopter"])) == -1, "Role-based target selection must never acquire targets outside its engagement radius")
	# Enemy fighters must protect the helicopter under hostile air pressure, not blindly follow the nearest one.
	game.get("units").assign([
		{"kind": "helicopter", "team": "enemy", "hp": 160, "pos": Vector2(100.0, 0.0)},
		{"kind": "helicopter", "team": "enemy", "hp": 160, "pos": Vector2(50.0, 0.0)},
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2(125.0, 0.0)}
	])
	_expect(int(game.call("_enemy_fighter_escort_helicopter_index", Vector2.ZERO)) == 0, "Enemy fighter must escort the helicopter threatened by hostile aircraft even when another helicopter is closer")
	game.get("units")[2]["hp"] = 0
	_expect(int(game.call("_enemy_fighter_escort_helicopter_index", Vector2.ZERO)) == 1, "Enemy fighter must fall back to the nearest living helicopter when no hostile air threat remains")
	# Interceptors distribute across distinct hostile aircraft instead of concentrating on one target.
	game.get("units").assign([
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2(100.0, 0.0)},
		{"kind": "helicopter", "team": "player", "hp": 160, "pos": Vector2(240.0, 0.0)},
		{"kind": "fighter", "team": "enemy", "hp": 180, "pos": Vector2(105.0, 0.0)},
		{"kind": "fighter", "team": "enemy", "hp": 180, "pos": Vector2.ZERO}
	])
	_expect(int(game.call("_enemy_fighter_select_air_target", Vector2.ZERO, 3)) == 1, "Enemy fighters must distribute interceptions when another fighter is already engaging the nearest hostile aircraft")
	game.get("units")[2]["hp"] = 0
	_expect(int(game.call("_enemy_fighter_select_air_target", Vector2.ZERO, 3)) == 0, "Enemy fighters must select the nearest available hostile aircraft when no friendly interceptor is engaging it")
	# Attack helicopters support the command-selected ground threat, then fall back when that focus is invalid.
	game.get("units").assign([
		{"kind": "infantry", "team": "player", "hp": 100, "pos": Vector2(35.0, 0.0)},
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(260.0, 0.0)}
	])
	_expect(int(game.call("_enemy_helicopter_assault_target", Vector2.ZERO, 1)) == 1, "Enemy attack helicopters must reinforce the ground assault command focus instead of independently chasing a closer low-priority unit")
	# Air assault may override the command focus when it is covered by a concentrated air-defense screen.
	var saved_air_defense_test_buildings: Array = game.get("buildings").duplicate(true)
	game.get("units").assign([
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(220.0, 0.0)},
		{"kind": "infantry", "team": "player", "hp": 100, "pos": Vector2(140.0, 0.0)}
	])
	game.get("buildings").assign([{"kind": "anti_air", "hp": 450, "build_progress": 1.0, "pos": Vector2(220.0, 0.0)}])
	_expect(int(game.call("_enemy_helicopter_assault_target", Vector2.ZERO, 0)) == 1, "Enemy attack helicopters must prefer an exposed ground target over a command focus protected by anti-air defenses")
	game.get("buildings").assign(saved_air_defense_test_buildings)
	game.get("units")[1]["hp"] = 0
	_expect(int(game.call("_enemy_helicopter_assault_target", Vector2.ZERO, 1)) == 0, "Enemy attack helicopters must reacquire a living ground target when the coordinated focus is destroyed")
	# Enemy combined-arms assault formations must keep armor forward, infantry in support, and artillery at standoff range.
	var assault_target_pos := Vector2(500.0, 300.0)
	var assault_origin_pos := Vector2(100.0, 300.0)
	var tank_slot: Vector2 = game.call("_enemy_ground_assault_formation_position", "tank", assault_target_pos, assault_origin_pos, 0)
	var infantry_slot: Vector2 = game.call("_enemy_ground_assault_formation_position", "infantry", assault_target_pos, assault_origin_pos, 0)
	var artillery_slot: Vector2 = game.call("_enemy_artillery_support_position", assault_target_pos, assault_origin_pos, 0)
	_expect(tank_slot.distance_to(Vector2(435.0, 278.0)) < 0.1, "Enemy tanks must occupy the forward assault line")
	_expect(infantry_slot.distance_to(Vector2(400.0, 278.0)) < 0.1, "Enemy infantry must trail the armor instead of crowding the front line")
	_expect(artillery_slot.distance_to(Vector2(250.0, 230.0)) < 0.1, "Enemy artillery must hold a rear standoff firing position")
	game.get("units").assign([
		{"kind": "tank", "team": "enemy", "hp": 300, "pos": Vector2(420.0, 300.0)},
		{"kind": "infantry", "team": "enemy", "hp": 100, "pos": Vector2(430.0, 300.0)},
		{"kind": "tank", "team": "enemy", "hp": 300, "defense_guard": true, "pos": Vector2(440.0, 300.0)},
		{"kind": "artillery", "team": "enemy", "hp": 220, "pos": Vector2(350.0, 300.0)},
		{"kind": "artillery", "team": "enemy", "hp": 220, "pos": Vector2(330.0, 300.0)}
	])
	_expect(int(game.call("_enemy_assault_formation_rank", 3)) == 2, "Assault formation ranks must count active armor and infantry but exclude defensive guards")
	_expect(int(game.call("_enemy_artillery_formation_rank", 4)) == 1, "Artillery support ranks must separate batteries into independent firing lanes")
	game.get("units").assign([
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(200.0, 0.0)},
		{"kind": "infantry", "team": "player", "hp": 100, "pos": Vector2(100.0, 0.0)},
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2(20.0, 0.0)}
	])
	game.set("enemy_strategy", "armor_breaker")
	_expect(int(game.call("_select_enemy_ground_assault_target", Vector2.ZERO)) == 0, "Armor-breaker doctrine must prioritize a threatening tank over nearer infantry and ignore aircraft")
	game.set("enemy_strategy", "area_denial")
	game.get("units")[0]["kind"] = "artillery"
	_expect(int(game.call("_select_enemy_ground_assault_target", Vector2.ZERO)) == 0, "Area-denial doctrine must prioritize hostile artillery concentrations")
	# Flank selection must avoid defended approach corridors, not merely compare endpoint safety.
	var saved_flank_test_buildings: Array = game.get("buildings").duplicate(true)
	game.get("buildings").clear()
	game.get("buildings").append_array([
		{"kind": "turret", "hp": 400, "build_progress": 1.0, "pos": assault_target_pos},
		{"kind": "turret", "hp": 400, "build_progress": 1.0, "pos": assault_target_pos},
		{"kind": "turret", "hp": 400, "build_progress": 1.0, "pos": Vector2(300.0, 185.0)}
	])
	var safer_flank: Vector2 = game.call("_enemy_ground_assault_flank_anchor", assault_target_pos, assault_origin_pos, 0)
	_expect(safer_flank.distance_to(Vector2(500.0, 415.0)) < 0.1, "Enemy armor must choose the flank with the safer approach corridor even when both endpoints are similarly exposed")
	game.get("buildings").clear()
	game.get("buildings").append_array(saved_flank_test_buildings)
	game.set("enemy_strategy", "balanced")
	game.get("units").clear()

	game.get("units").clear()

	# Enemy retreat must use a safe rally point, pause recovery under pressure, and rejoin only after rebuilding combat strength.
	game.set("enemy_base", Vector2.ZERO)
	game.get("enemy_buildings").clear()
	game.get("units").assign([
		{"kind": "tank", "team": "enemy", "hp": 30, "pos": Vector2(300.0, 0.0)},
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(1000.0, 0.0)}
	])
	var retreating_tank: Dictionary = game.get("units")[0]
	_expect(bool(game.call("_update_enemy_retreat", retreating_tank, 1.0)), "Critically damaged enemy armor must enter retreat instead of continuing its assault")
	_expect(bool(retreating_tank.get("retreating", false)) and retreating_tank["pos"].x < 300.0, "Retreating armor must move toward its safe rally point")
	retreating_tank["pos"] = Vector2.ZERO
	retreating_tank["hp"] = 30
	_expect(bool(game.call("_update_enemy_retreat", retreating_tank, 1.0)) and int(retreating_tank["hp"]) == 40, "Enemy armor must recover at a safe rally point before returning to combat")
	game.get("units")[1]["pos"] = Vector2(40.0, 0.0)
	var hp_under_pressure := int(retreating_tank["hp"])
	_expect(bool(game.call("_update_enemy_retreat", retreating_tank, 1.0)) and int(retreating_tank["hp"]) == hp_under_pressure, "Enemy troops must not regenerate while hostile forces threaten the rally point")
	game.get("units")[1]["pos"] = Vector2(1000.0, 0.0)
	retreating_tank["hp"] = 90
	_expect(not bool(game.call("_update_enemy_retreat", retreating_tank, 1.0)) and not bool(retreating_tank.get("retreating", false)), "Recovered enemy armor must leave retreat state and rejoin the battle at the established recovery threshold")
	game.get("units").clear()

	# Zero Hour-style armor facing: rear/side exposure takes more damage than a frontal hit.
	var armored_target: Dictionary = {"kind": "tank", "team": "enemy", "hp": 300, "pos": Vector2.ZERO, "facing": 0.0}
	var frontal_hit := int(game.call("_player_armor_penetration_damage", armored_target, 100, Vector2(100.0, 0.0)))
	var rear_hit := int(game.call("_player_armor_penetration_damage", armored_target, 100, Vector2(-100.0, 0.0)))
	_expect(frontal_hit == 105, "Tank frontal armor must reduce incoming penetration damage")
	_expect(rear_hit == 162 and rear_hit > frontal_hit, "Tank rear exposure must take stronger armor-penetrating damage")
	# Artillery shells damage ground units by distance, never friendly forces or aircraft.
	var artillery_attacker: Dictionary = {"team": "player", "kind": "artillery", "combat_xp": 0.0}
	game.get("units").assign([
		{"kind": "tank", "team": "enemy", "hp": 300, "pos": Vector2.ZERO},
		{"kind": "artillery", "team": "enemy", "hp": 220, "pos": Vector2(100.0, 0.0)},
		{"kind": "infantry", "team": "enemy", "hp": 100, "pos": Vector2(101.0, 0.0)},
		{"kind": "fighter", "team": "enemy", "hp": 180, "pos": Vector2.ZERO},
		{"kind": "tank", "team": "player", "hp": 300, "pos": Vector2.ZERO}
	])
	game.call("_apply_artillery_blast", Vector2.ZERO, 100.0, 100, "enemy", artillery_attacker)
	_expect(int(game.get("units")[0]["hp"]) == 200, "Artillery blast must apply full damage at the impact center")
	_expect(int(game.get("units")[1]["hp"]) == 185, "Artillery blast must apply reduced damage at the edge of its radius")
	_expect(int(game.get("units")[2]["hp"]) == 100, "Artillery blast must not damage ground units outside its radius")
	_expect(int(game.get("units")[3]["hp"]) == 180, "Ground artillery blast must not damage aircraft")
	_expect(int(game.get("units")[4]["hp"]) == 300, "Artillery blast must never damage friendly units")
	game.get("units").clear()

	# Bunker cover must protect nearby friendly ground units without granting map-wide armor.
	game.get("buildings").assign([
		{"kind": "bunker", "hp": 650, "level": 1, "build_progress": 1.0, "pos": Vector2.ZERO}
	])
	game.get("supply_points").clear()
	var covered_tank: Dictionary = {"kind": "tank", "team": "player", "hp": 300, "pos": Vector2.ZERO}
	var exposed_tank: Dictionary = {"kind": "tank", "team": "player", "hp": 300, "pos": Vector2(100.0, 0.0)}
	_expect(int(game.call("_terrain_adjusted_damage", covered_tank, 100)) == 78, "Friendly ground units inside bunker cover must receive the approved defensive bonus")
	_expect(int(game.call("_terrain_adjusted_damage", exposed_tank, 100)) == 100, "Bunker cover must not protect friendly units outside its radius")
	game.get("buildings").clear()

	# Ground units use distinct, Zero Hour-style ranges and damage against structures.
	_expect(is_equal_approx(float(game.call("_ground_building_attack_range", "artillery")), 350.0), "Artillery must attack structures from long standoff range")
	_expect(is_equal_approx(float(game.call("_ground_building_attack_range", "tank")), 75.0), "Tanks must close to direct-fire structure range")
	_expect(int(game.call("_ground_building_attack_damage", {"kind": "artillery", "veterancy": 0})) == 48, "Artillery structure damage must preserve its heavy-shell baseline")
	_expect(int(game.call("_ground_building_attack_damage", {"kind": "tank", "veterancy": 0})) == 32, "Tank structure damage must preserve its direct-fire baseline")
	_expect(int(game.call("_ground_building_attack_damage", {"kind": "infantry", "veterancy": 0})) == 8, "Infantry structure damage must remain deliberately limited")
	_expect(int(game.call("_ground_building_attack_damage", {"kind": "tank", "veterancy": 1})) == 35, "Veteran tank crews must gain the established structure-damage bonus")

	# Aircraft retain distinct structure engagement envelopes and faction-specific attack strength.
	_expect(is_equal_approx(float(game.call("_air_building_attack_range", "fighter")), 245.0), "Fighters must retain their approved structure attack radius")
	_expect(is_equal_approx(float(game.call("_air_building_attack_range", "helicopter")), 225.0), "Attack helicopters must retain their closer structure attack radius")
	_expect(int(game.call("_air_building_attack_damage", {"kind": "fighter"})) == 26, "Fighter structure damage must preserve its baseline")
	for army_name in ["الصيني", "الأمريكي", "الجيش العربي", "وطن"]:
		var aircraft_fixture: Dictionary = {"kind": "helicopter", "faction": String(army_name)}
		_expect(int(game.call("_air_building_attack_damage", aircraft_fixture)) == int(air_profile_contract[army_name]["helicopter_damage"]), "Helicopter structure damage must match its faction profile for " + String(army_name))
	_expect(int(game.call("_air_building_attack_damage", {"kind": "transport_helicopter"})) == 0, "Transport helicopters must not gain an attack role against structures")

	# Airfield recovery slots must reuse gaps rather than collide after an earlier aircraft launches.
	game.get("units").assign([
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2.ZERO, "airfield_returning": true, "airfield_recovery_id": 4, "airfield_recovery_slot": 1},
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2.ZERO, "airfield_returning": true, "airfield_recovery_id": 4, "airfield_recovery_slot": 2},
		{"kind": "fighter", "team": "enemy", "hp": 180, "pos": Vector2.ZERO, "airfield_returning": true, "airfield_recovery_id": 4, "airfield_recovery_slot": 0},
		{"kind": "fighter", "team": "player", "hp": 180, "pos": Vector2.ZERO, "airfield_returning": true, "airfield_recovery_id": 9, "airfield_recovery_slot": 0}
	])
	_expect(int(game.call("_next_airfield_recovery_slot", 4)) == 0, "Recovery slot allocator must reuse the lowest free slot and ignore other teams and airfields")
	game.get("units")[0]["airfield_recovery_slot"] = 0
	game.get("units")[1]["airfield_recovery_slot"] = 2
	game.get("units")[2]["airfield_returning"] = false
	_expect(int(game.call("_next_airfield_recovery_slot", 4)) == 1, "A gap between occupied recovery slots must be reused instead of duplicating a later slot")
	game.get("units")[1]["airfield_recovery_slot"] = 1
	_expect(int(game.call("_next_airfield_recovery_slot", 4)) == 2, "Recovery slot allocator must choose the next free slot when lower slots are occupied")
	game.get("units").clear()

	# Returning aircraft choose the nearest surviving, completed and powered friendly airfield.
	game.get("buildings").assign([
		{"kind": "airfield", "team": "player", "hp": 0, "build_progress": 1.0, "production_id": 4, "pos": Vector2(10.0, 0.0)},
		{"kind": "airfield", "team": "player", "hp": 500, "build_progress": 1.0, "production_id": 9, "pos": Vector2(100.0, 0.0)},
		{"kind": "airfield", "team": "player", "hp": 500, "build_progress": 0.5, "production_id": 10, "pos": Vector2(5.0, 0.0)}
	])
	_expect(int(game.call("_nearest_powered_player_airfield_index", Vector2.ZERO)) == 1, "Aircraft must bypass a destroyed nearest airfield and select the nearest surviving completed powered field")
	var cached_aircraft: Dictionary = {"airfield_cached_index": 1}
	_expect(int(game.call("_valid_player_airfield_index", cached_aircraft, 9)) == 1, "Aircraft must reuse a cached index while its assigned powered airfield remains valid")
	game.get("buildings").insert(0, {"kind": "turret", "team": "player", "hp": 300, "build_progress": 1.0, "production_id": 90, "pos": Vector2.ZERO})
	_expect(int(game.call("_valid_player_airfield_index", cached_aircraft, 9)) == 2 and int(cached_aircraft.get("airfield_cached_index", -1)) == 2, "Aircraft airfield cache must recover safely when building indices shift")
	game.get("buildings").remove_at(0)
	_expect(int(game.call("_valid_player_airfield_index", cached_aircraft, 9)) == 1, "Aircraft airfield cache must recover when the building list shifts back")
	var rerouted_aircraft: Dictionary = {
		"unit_id": "reroute_1", "kind": "fighter", "team": "player", "hp": 120, "pos": Vector2.ZERO,
		"airfield_returning": true, "airfield_recovery_id": 4, "airfield_recovery_slot": 2,
		"airfield_rearm_progress": 2.25, "airfield_resume_order": {"air_patrol_points": [Vector2(80.0, 90.0)], "air_patrol_index": 0, "air_patrol_resume": true},
		"airfield_sortie_launch": true, "airfield_sortie_airfield_id": 4, "airfield_sortie_launch_wait": 1.5
	}
	var rerouted_aircraft_2: Dictionary = {"unit_id": "reroute_2", "kind": "fighter", "team": "player", "hp": 120, "pos": Vector2(2.0, 0.0), "airfield_returning": true, "airfield_recovery_id": 4, "airfield_recovery_slot": 1}
	var rerouted_aircraft_3: Dictionary = {"unit_id": "reroute_3", "kind": "helicopter", "team": "player", "hp": 120, "pos": Vector2(4.0, 0.0), "airfield_returning": true, "airfield_recovery_id": 4, "airfield_recovery_slot": 0}
	game.get("units").assign([rerouted_aircraft, rerouted_aircraft_2, rerouted_aircraft_3])
	_expect(bool(game.call("_redirect_aircraft_recovery", rerouted_aircraft, 4)), "Aircraft must be redirected when its assigned airfield is lost and an alternate is available")
	_expect(bool(game.call("_redirect_aircraft_recovery", rerouted_aircraft_2, 4)), "Second aircraft must also be redirected to the alternate field")
	_expect(bool(game.call("_redirect_aircraft_recovery", rerouted_aircraft_3, 4)), "Third aircraft must also be redirected to the alternate field")
	_expect(int(rerouted_aircraft.get("airfield_recovery_id", -1)) == 9 and int(rerouted_aircraft.get("airfield_recovery_slot", -1)) == 0, "First rerouted aircraft must reserve the first free slot at the alternate field")
	_expect(int(rerouted_aircraft_2.get("airfield_recovery_id", -1)) == 9 and int(rerouted_aircraft_2.get("airfield_recovery_slot", -1)) == 1, "Second rerouted aircraft must reserve a distinct second slot")
	_expect(int(rerouted_aircraft_3.get("airfield_recovery_id", -1)) == 9 and int(rerouted_aircraft_3.get("airfield_recovery_slot", -1)) == 2, "Third rerouted aircraft must reserve a distinct third slot")
	_expect(bool(rerouted_aircraft.get("airfield_returning", false)) and not bool(rerouted_aircraft.get("airfield_sortie_launch", false)), "Rerouting must resume the recovery flight and clear the stale takeoff queue")
	_expect(is_equal_approx(float(rerouted_aircraft.get("airfield_rearm_progress", 0.0)), 2.25) and rerouted_aircraft.has("airfield_resume_order"), "Rerouting must preserve rearm progress and the original flight order")
	game.get("buildings").append_array([
		{"kind": "airfield", "team": "player", "hp": 500, "build_progress": 1.0, "production_id": 11, "pos": Vector2(30.0, 0.0)},
		{"kind": "airfield", "team": "player", "hp": 500, "build_progress": 1.0, "production_id": 12, "pos": Vector2(1.0, 0.0)}
	])
	_expect(int(game.call("_nearest_powered_player_airfield_index", Vector2.ZERO)) == 3, "Aircraft must skip a closer completed airfield that has lost power after earlier fields consume capacity")
	game.get("units").clear()
	game.get("buildings").clear()
	var reroute_without_alternate: Dictionary = {
		"unit_id": "reroute_no_field", "kind": "fighter", "team": "player", "hp": 120, "pos": Vector2.ZERO,
		"airfield_returning": true, "airfield_recovery_id": 4, "airfield_recovery_slot": 2,
		"airfield_resume_order": {"air_patrol_points": [Vector2(120.0, 140.0)], "air_patrol_index": 0, "air_patrol_resume": true}
	}
	game.get("units").assign([reroute_without_alternate])
	_expect(not bool(game.call("_redirect_aircraft_recovery", reroute_without_alternate, 4)), "Aircraft must abandon recovery when no powered alternate airfield exists")
	_expect(not reroute_without_alternate.has("airfield_returning") and not reroute_without_alternate.has("airfield_recovery_slot"), "Failed rerouting must release all stale recovery state")
	_expect(reroute_without_alternate.has("air_patrol_points") and bool(reroute_without_alternate.get("air_patrol_resume", false)), "Failed rerouting must restore the aircraft original patrol order")
	game.get("units").clear()

	# Takeoff queue staggers aircraft assigned to the same airfield and ignores other fields.
	game.get("units").assign([
		{"unit_id": "queue_enemy", "kind": "fighter", "team": "enemy", "hp": 180, "pos": Vector2.ZERO, "airfield_sortie_launch": true, "airfield_sortie_airfield_id": 4},
		{"unit_id": "queue_1", "kind": "fighter", "team": "player", "hp": 180, "pos": Vector2.ZERO, "airfield_sortie_launch": true, "airfield_sortie_airfield_id": 4},
		{"unit_id": "queue_2", "kind": "helicopter", "team": "player", "hp": 180, "pos": Vector2.ZERO, "airfield_sortie_launch": false, "airfield_sortie_airfield_id": 4},
		{"unit_id": "queue_3", "kind": "fighter", "team": "player", "hp": 180, "pos": Vector2.ZERO, "airfield_sortie_launch": false, "airfield_sortie_airfield_id": 4},
		{"unit_id": "queue_other", "kind": "fighter", "team": "player", "hp": 180, "pos": Vector2.ZERO, "airfield_sortie_launch": true, "airfield_sortie_airfield_id": 9}
	])
	_expect(is_equal_approx(float(game.call("_airfield_sortie_launch_delay", 4)), 1.5), "Second aircraft at one airfield must receive a 1.5-second staggered launch delay")
	game.get("units")[2]["airfield_sortie_launch"] = true
	game.get("units")[3]["airfield_sortie_launch"] = true
	_expect(is_equal_approx(float(game.call("_airfield_sortie_launch_delay", 9)), 1.5), "Takeoff queue must be isolated per airfield")
	_expect(not bool(game.call("_airfield_sortie_has_launch_predecessor", "queue_1", 4)), "First aircraft in an airfield queue must be allowed to taxi immediately")
	_expect(bool(game.call("_airfield_sortie_has_launch_predecessor", "queue_2", 4)), "A following aircraft must wait until its same-airfield predecessor clears the launch lane")
	_expect(bool(game.call("_airfield_sortie_has_launch_predecessor", "queue_3", 4)), "A third aircraft must remain behind the second aircraft in the same queue")
	_expect(not bool(game.call("_airfield_sortie_has_launch_predecessor", "queue_other", 9)), "An aircraft at another airfield must not block this runway")
	_expect(not bool(game.call("_airfield_sortie_has_launch_predecessor", "queue_enemy", 4)), "Enemy aircraft must not block the player's airfield queue")
	# Losing or depowering the assigned airfield must release recovery and launch queue state.
	var stranded_aircraft: Dictionary = {
		"unit_id": "stranded_fighter", "kind": "fighter", "team": "player", "hp": 150,
		"airfield_returning": true, "airfield_landed": true, "airfield_recovery_id": 4,
		"airfield_recovery_slot": 2, "airfield_rearm_progress": 3.25,
		"airfield_sortie_ready": true, "airfield_sortie_launch": true,
		"airfield_sortie_airfield_id": 4, "airfield_sortie_launch_wait": 1.5,
		"airfield_resume_order": {"air_patrol_points": [Vector2(210.0, 180.0), Vector2(480.0, 210.0)], "air_patrol_index": 1, "air_patrol_resume": true}
	}
	game.call("_abandon_airfield_recovery", stranded_aircraft)
	var lost_airfield_leader: Dictionary = game.get("units")[1]
	lost_airfield_leader["airfield_resume_order"] = {"air_patrol_points": [Vector2(100.0, 100.0)], "air_patrol_index": 0, "air_patrol_resume": true}
	game.call("_abandon_airfield_recovery", lost_airfield_leader)
	_expect(not bool(game.call("_airfield_sortie_has_launch_predecessor", "queue_2", 4)), "When the lead aircraft loses its airfield, the second aircraft must become the next queue leader")
	_expect(bool(game.call("_airfield_sortie_has_launch_predecessor", "queue_3", 4)), "After promotion, the third aircraft must still wait behind the new queue leader")
	_expect(not stranded_aircraft.has("airfield_returning") and not stranded_aircraft.has("airfield_landed") and not stranded_aircraft.has("airfield_recovery_id") and not stranded_aircraft.has("airfield_recovery_slot") and not stranded_aircraft.has("airfield_rearm_progress"), "Abandoned recovery must release landing state and its reserved slot")
	_expect(not stranded_aircraft.has("airfield_sortie_launch") and not stranded_aircraft.has("airfield_sortie_ready") and not stranded_aircraft.has("airfield_sortie_airfield_id") and not stranded_aircraft.has("airfield_sortie_launch_wait"), "Abandoned recovery must release all stale takeoff queue state")
	_expect(not stranded_aircraft.has("airfield_resume_order") and Array(stranded_aircraft.get("air_patrol_points", [])).size() == 2 and int(stranded_aircraft.get("air_patrol_index", -1)) == 1 and bool(stranded_aircraft.get("air_patrol_resume", false)), "Aircraft must resume its saved patrol mission when the assigned airfield is lost")
	game.get("units").clear()

	# Strategic supply points remain neutral while contested and change hands when uncontested.
	game.get("supply_points").assign([{
		"pos": Vector2(400.0, 300.0),
		"owner": "neutral",
		"kind": "supply",
		"payout": 0.0,
		"supply_payout": 0.0
	}])
	game.get("units").assign([
		{"kind": "infantry", "team": "player", "hp": 60, "pos": Vector2(405.0, 300.0)},
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(395.0, 300.0)}
	])
	game.set("credits", 0)
	game.set("enemy_credits", 0)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "neutral", "A contested neutral supply point must not change hands")
	game.get("units").remove_at(1)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "player", "An uncontested player unit must capture a neutral supply point")
	_expect(int(game.get("credits")) >= 4, "A player-controlled supply point must generate its income")
	game.get("units").clear()
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(400.0, 300.0)})
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "enemy", "An uncontested enemy unit must recapture a player supply point")
	_expect(int(game.get("enemy_credits")) >= 4, "An enemy-controlled supply point must generate enemy income")
	# The nearest enemy defender must be able to reinforce a threatened friendly supply point.
	game.get("units").assign([
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(375.0, 300.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(430.0, 300.0)}
	])
	var reinforcement_handled: bool = game.call("_update_enemy_supply_reinforcement", game.get("units")[0], 0, 0.1)
	_expect(reinforcement_handled, "An eligible enemy defender must respond to a threatened enemy-held supply point")
	_expect(bool(game.get("units")[0].get("supply_reinforcement_active", false)), "The dispatched defender must retain its supply reinforcement assignment")
	# Nearby mobile defenders must not mutually suppress the nearest reinforcement.
	game.get("units").assign([
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(350.0, 300.0)},
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(380.0, 300.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(430.0, 300.0)}
	])
	var farther_guard_handled: bool = game.call("_update_enemy_supply_reinforcement", game.get("units")[0], 0, 0.1)
	var nearest_guard_handled: bool = game.call("_update_enemy_supply_reinforcement", game.get("units")[1], 1, 0.1)
	_expect(not farther_guard_handled, "A farther defender must not duplicate the nearest defender's reinforcement assignment")
	_expect(nearest_guard_handled, "The nearest defender must reinforce even when another mobile defender is nearby")
	game.get("units").clear()
	game.get("supply_points").clear()
	# Defense director keeps a compact base reserve and protects a high-value forward installation.
	game.set("enemy_base", Vector2(700.0, 300.0))
	game.get("enemy_buildings").assign([
		{"kind": "missile_silo", "hp": 500, "build_progress": 1.0, "pos": Vector2(500.0, 300.0)},
		{"kind": "factory", "hp": 400, "build_progress": 1.0, "pos": Vector2(600.0, 300.0)}
	])
	var defense_units: Array = []
	for guard_index in range(8):
		defense_units.append({"kind": "infantry" if guard_index < 5 else "tank", "team": "enemy", "hp": 60 if guard_index < 5 else 150, "pos": Vector2(660.0 + float(guard_index % 3) * 12.0, 280.0 + float(guard_index) * 5.0)})
	game.get("units").assign(defense_units)
	game.call("_update_enemy_defense_assignments")
	var assigned_guard_count := 0
	var protects_base := false
	var protects_silo := false
	for defense_unit in game.get("units"):
		if not bool(defense_unit.get("defense_guard", false)):
			continue
		assigned_guard_count += 1
		var guard_anchor: Vector2 = defense_unit.get("defense_anchor", Vector2.ZERO)
		protects_base = protects_base or guard_anchor.distance_to(game.get("enemy_base")) < 100.0
		protects_silo = protects_silo or guard_anchor.distance_to(Vector2(500.0, 300.0)) < 100.0
	_expect(assigned_guard_count == 2, "Eight enemy ground units must retain a compact two-unit defensive reserve")
	_expect(protects_base, "Enemy defense director must preserve a guard around the main base")
	_expect(protects_silo, "Enemy defense director must assign a guard to the high-value missile silo")
	# A forward guard must fall back to the main base when its assigned asset is destroyed.
	game.get("units").assign([{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(480.0, 300.0), "defense_guard": true, "defense_anchor": Vector2(500.0, 300.0)}])
	game.get("enemy_buildings").assign([{"kind": "missile_silo", "hp": 0, "build_progress": 1.0, "pos": Vector2(500.0, 300.0)}])
	game.call("_update_enemy_defense_guard", game.get("units")[0], 0, 0.1)
	_expect((game.get("units")[0].get("defense_anchor", Vector2.ZERO) as Vector2).distance_to(game.get("enemy_base")) < 1.0, "A guard must abandon a destroyed forward asset and return to base defense")
	# Base guards must not chase attackers beyond their local defensive perimeter.
	game.get("units").assign([
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(700.0, 300.0), "defense_guard": true, "defense_anchor": Vector2(700.0, 300.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(925.0, 300.0)}
	])
	game.get("enemy_buildings").clear()
	var outside_perimeter_hp := int(game.get("units")[1].get("hp", 0))
	game.call("_update_enemy_defense_guard", game.get("units")[0], 0, 1.0)
	_expect((game.get("units")[0].pos as Vector2).distance_to(Vector2(700.0, 300.0)) < 1.0, "A base guard must hold position when the attacker is outside its 210-unit perimeter")
	_expect(int(game.get("units")[1].get("hp", 0)) == outside_perimeter_hp, "A base guard must not attack an enemy outside its defensive perimeter")
	game.get("units")[1].pos = Vector2(890.0, 300.0)
	game.call("_update_enemy_defense_guard", game.get("units")[0], 0, 1.0)
	_expect(game.get("units")[0].pos.x > 700.0 and game.get("units")[0].pos.x <= 736.1, "A base guard must approach a threat inside its perimeter without abandoning its post")
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	# Counterattack reserve mobilization is capped at two units around a breached critical asset.
	game.set("enemy_base", Vector2(700.0, 300.0))
	game.get("enemy_buildings").assign([{"kind": "factory", "hp": 400, "build_progress": 1.0, "pos": Vector2(700.0, 300.0)}])
	game.get("units").assign([
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(650.0, 280.0)},
		{"kind": "infantry", "team": "enemy", "hp": 60, "pos": Vector2(660.0, 320.0)},
		{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(680.0, 340.0)},
		{"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(710.0, 300.0)}
	])
	var first_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[0], 0, 0.1)
	var second_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[1], 1, 0.1)
	var third_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[2], 2, 0.1)
	_expect(first_reserve_handled and second_reserve_handled, "The enemy must mobilize up to two counterattack reserves against a breach")
	_expect(not third_reserve_handled, "The enemy must not commit more than two counterattack reserves at once")
	_expect(bool(game.get("units")[0].get("counterattack_active", false)) and bool(game.get("units")[1].get("counterattack_active", false)), "Both committed counterattack units must retain their active assignments")
	# A reserve at its anchor must be released once the local breach is cleared.
	game.get("units").assign([{"kind": "tank", "team": "enemy", "hp": 150, "pos": Vector2(700.0, 300.0), "counterattack_active": true, "counterattack_anchor": Vector2(700.0, 300.0)}])
	var released_reserve_handled: bool = game.call("_update_enemy_counterattack_reserve", game.get("units")[0], 0, 0.1)
	_expect(released_reserve_handled, "An active reserve must complete its local counterattack update")
	_expect(not bool(game.get("units")[0].get("counterattack_active", false)), "A reserve must be released after the breach is cleared and it returns to its anchor")
	game.get("units").clear()
	game.get("enemy_buildings").clear()

	game.set("faction", "وطن")
	game.set("map_type", "الساحل الجبلي")
	game.set("game_started", true)
	game.set("credits", 1840)
	game.set("supplies", 7)
	game.set("enemy_supplies", 4)
	game.set("enemy_credits", 920)
	game.set("enemy_missile_timer", 6.75)
	game.set("player_base_hp", 760)
	game.set("enemy_base_hp", 510)
	game.set("campaign_mission_index", 2)
	game.get("supply_points").append({"id": "supply_alpha", "owner": "player", "pos": Vector2(430.0, 300.0)})
	game.get("units").append({
		"unit_id": "unit_00000051",
		"kind": "transport_helicopter",
		"team": "player",
		"faction": "وطن",
		"hp": 155,
		"pos": Vector2(420.0, 210.0),
		"transport_state": "loaded",
		"transport_target_pos": Vector2(680.0, 260.0),
		"transport_landing_type": "rooftop",
		"transport_target_building_kind": "factory",
		"transport_drop_index": 1,
		"transport_drop_timer": 0.35,
		"transport_ai_last_site_id": "roof_factory_01",
		"transport_ai_route_points": [Vector2(520.0, 220.0), Vector2(610.0, 245.0), Vector2(680.0, 260.0)],
		"transport_ai_route_index": 1,
		"transport_ai_autonomous_active": true,
		"transport_ai_player_override": false,
		"transport_firing": true,
		"attack_focus_pos": Vector2(735.0, 270.0),
		"attack_target_pos": Vector2(742.0, 275.0),
		"transport_cargo": [{
			"unit_id": "unit_00000052",
			"kind": "infantry",
			"team": "player",
			"faction": "وطن",
			"hp": 47,
			"pos": Vector2(420.0, 210.0)
		}]
	})
	game.get("units").append({
		"unit_id": "unit_00000053", "kind": "infantry", "team": "player", "faction": "وطن",
		"hp": 60, "pos": Vector2(450.0, 220.0), "target": Vector2(720.0, 240.0)
	})
	game.get("units").append({
		"unit_id": "unit_00000054", "kind": "tank", "team": "player", "faction": "وطن",
		"hp": 150, "pos": Vector2(470.0, 230.0), "attack_target": 4
	})
	game.get("units").append({
		"unit_id": "unit_00000055", "kind": "artillery", "team": "player", "faction": "وطن",
		"hp": 120, "pos": Vector2(490.0, 240.0), "guard_active": true
	})
	game.get("units").append({
		"unit_id": "unit_00000056", "kind": "fighter", "team": "enemy",
		"hp": 180, "pos": Vector2(760.0, 250.0)
	})
	game.get("units").append({
		"unit_id": "unit_00000057", "kind": "fighter", "team": "player", "faction": "وطن",
		"hp": 142, "pos": Vector2(650.0, 350.0), "aircraft_ammo": 0,
		"airfield_returning": true, "airfield_landed": true, "airfield_rearm_progress": 2.25,
		"airfield_recovery_id": 4, "airfield_recovery_slot": 1,
		"airfield_resume_order": {
			"air_patrol_points": [Vector2(300.0, 180.0), Vector2(520.0, 210.0), Vector2(700.0, 190.0)],
			"air_patrol_index": 1, "air_patrol_resume": true,
			"attack_building_kind": "factory", "attack_building_id": 9,
			"attack_building_pos": Vector2(980.0, 320.0)
		}
	})
	game.get("units").append({
		"unit_id": "unit_00000058", "kind": "fighter", "team": "player", "faction": "وطن",
		"hp": 180, "pos": Vector2(660.0, 350.0), "airfield_sortie_ready": true,
		"airfield_sortie_launch": true, "airfield_sortie_airfield_id": 4, "airfield_sortie_launch_wait": 0.0
	})
	game.get("units").append({
		"unit_id": "unit_00000059", "kind": "fighter", "team": "player", "faction": "وطن",
		"hp": 180, "pos": Vector2(670.0, 350.0), "airfield_sortie_ready": true,
		"airfield_sortie_launch": true, "airfield_sortie_airfield_id": 4, "airfield_sortie_launch_wait": 1.5
	})
	game.get("buildings").append({"kind": "airfield", "hp": 390, "pos": Vector2(650.0, 320.0), "production_id": 4})
	game.get("enemy_buildings").append({"kind": "factory", "hp": 240, "pos": Vector2(980.0, 320.0), "production_id": 9})
	game.get("production_orders").append({"producer_id": 4, "producer_pos": Vector2(650.0, 320.0), "producer_kind": "airfield", "kind": "fighter", "remaining": 8.5, "duration": 20.0})
	game.get("missiles").append({"team": "player", "pos": Vector2(200.0, 300.0), "target": Vector2(800.0, 300.0), "damage": 180})

	_expect(bool(game.call("_save_battle_snapshot")), "Active battle should save through the gameplay integration")
	game.set("credits", 1)
	game.set("player_base_hp", 1)
	game.set("enemy_missile_timer", 0.0)
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("production_orders").clear()
	game.get("missiles").clear()
	game.get("supply_points").clear()
	_expect(bool(game.call("_load_battle_snapshot")), "A valid saved battle should restore through the gameplay integration")
	_expect(String(game.get("faction")) == "وطن" and String(game.get("map_type")) == "الساحل الجبلي", "Faction and map should be restored")
	_expect(int(game.get("campaign_mission_index")) == 2 and bool(game.get("game_started")), "Active campaign mission identity and match state should survive save/restore")
	_expect(int(game.get("credits")) == 1840 and int(game.get("player_base_hp")) == 760, "Economy and base health should be restored")
	_expect(is_equal_approx(float(game.get("enemy_missile_timer")), 6.75), "Enemy missile attack cadence should be restored")
	_expect(game.get("supply_points").size() == 1 and String(game.get("supply_points")[0].get("owner", "")) == "player", "Supply ownership should be restored")
	_expect(game.get("units").size() == 8, "All field units must be restored with their original order indexes")
	if game.get("units").size() == 8:
		var transport: Dictionary = game.get("units")[0]
		var mover: Dictionary = game.get("units")[1]
		var attacker: Dictionary = game.get("units")[2]
		var guard: Dictionary = game.get("units")[3]
		_expect(String(transport.get("unit_id", "")) == "unit_00000051", "Transport identity should be restored")
		_expect(String(transport.get("transport_state", "")) == "loaded", "Transport mission state should be restored")
		_expect(Array(transport.get("transport_cargo", [])).size() == 1, "Transport cargo should be restored")
		_expect(String(transport.get("transport_landing_type", "")) == "rooftop" and String(transport.get("transport_target_building_kind", "")) == "factory", "Transport rooftop insertion target must survive restore")
		_expect(int(transport.get("transport_drop_index", -1)) == 1 and is_equal_approx(float(transport.get("transport_drop_timer", -1.0)), 0.35), "Rope deployment progress must survive restore")
		_expect(String(transport.get("transport_ai_last_site_id", "")) == "roof_factory_01", "Transport AI landing-site identity must survive restore")
		_expect(Array(transport.get("transport_ai_route_points", [])).size() == 3 and int(transport.get("transport_ai_route_index", -1)) == 1, "Transport flight route and current waypoint must survive restore")
		_expect(bool(transport.get("transport_ai_autonomous_active", false)) and not bool(transport.get("transport_ai_player_override", true)), "Transport AI execution policy must survive restore")
		_expect(bool(transport.get("transport_firing", false)) and transport.get("attack_focus_pos", Vector2.ZERO) == Vector2(735.0, 270.0) and transport.get("attack_target_pos", Vector2.ZERO) == Vector2(742.0, 275.0), "Loaded passenger firing focus must survive restore")
		_expect(String(mover.get("unit_id", "")) == "unit_00000053" and mover.get("target", Vector2.ZERO) == Vector2(720.0, 240.0), "Movement destination order must survive save/restore")
		_expect(String(attacker.get("unit_id", "")) == "unit_00000054" and int(attacker.get("attack_target", -1)) == 4, "Attack order must retain its target unit index after restore")
		_expect(String(game.get("units")[4].get("unit_id", "")) == "unit_00000056" and String(game.get("units")[4].get("team", "")) == "enemy", "The restored attack target must still identify the same enemy unit")
		_expect(String(guard.get("unit_id", "")) == "unit_00000055" and bool(guard.get("guard_active", false)), "Guard stance must survive save/restore")
		var rearming_fighter: Dictionary = game.get("units")[5]
		_expect(String(rearming_fighter.get("unit_id", "")) == "unit_00000057" and bool(rearming_fighter.get("airfield_returning", false)) and bool(rearming_fighter.get("airfield_landed", false)), "Aircraft landing and recovery lifecycle must survive save/restore")
		_expect(int(rearming_fighter.get("airfield_recovery_id", -1)) == 4 and int(rearming_fighter.get("airfield_recovery_slot", -1)) == 1 and is_equal_approx(float(rearming_fighter.get("airfield_rearm_progress", -1.0)), 2.25), "Airfield identity, queue slot, and partial rearm progress must survive restore")
		var restored_resume_order: Dictionary = rearming_fighter.get("airfield_resume_order", {})
		_expect(Array(restored_resume_order.get("air_patrol_points", [])).size() == 3 and int(restored_resume_order.get("air_patrol_index", -1)) == 1 and bool(restored_resume_order.get("air_patrol_resume", false)), "Air patrol route and current waypoint must remain queued while the aircraft rearms")
		var sortie_probe: Dictionary = rearming_fighter.duplicate(true)
		game.call("_restore_aircraft_resume_order", sortie_probe)
		_expect(not sortie_probe.has("airfield_resume_order") and Array(sortie_probe.get("air_patrol_points", [])).size() == 3 and int(sortie_probe.get("air_patrol_index", -1)) == 1, "Launching after rearm must restore the saved patrol mission and waypoint")
		_expect(int(sortie_probe.get("attack_building", -1)) == 0 and not sortie_probe.has("attack_target"), "Airfield sortie must reacquire the intended factory by stable production ID, not stale array index")
		var first_queued_sortie: Dictionary = game.get("units")[6]
		var second_queued_sortie: Dictionary = game.get("units")[7]
		_expect(String(first_queued_sortie.get("unit_id", "")) == "unit_00000058" and bool(first_queued_sortie.get("airfield_sortie_launch", false)) and is_equal_approx(float(first_queued_sortie.get("airfield_sortie_launch_wait", -1.0)), 0.0), "First ready aircraft must retain its immediate takeoff slot after save/restore")
		_expect(String(second_queued_sortie.get("unit_id", "")) == "unit_00000059" and bool(second_queued_sortie.get("airfield_sortie_launch", false)) and int(second_queued_sortie.get("airfield_sortie_airfield_id", -1)) == 4 and is_equal_approx(float(second_queued_sortie.get("airfield_sortie_launch_wait", -1.0)), 1.5), "Second aircraft must retain its airfield identity and staggered takeoff delay after save/restore")
	_expect(game.get("buildings").size() == 1 and game.get("enemy_buildings").size() == 1, "Both armies' building states should be restored")
	_expect(game.get("production_orders").size() == 1 and game.get("missiles").size() == 1, "Production and active missile state should be restored")

	game.set("credits", 1337)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	game.set("credits", 5)
	_expect(bool(game.call("_load_battle_snapshot")), "Android pause notification should persist a resumable battle")
	_expect(int(game.get("credits")) == 1337, "Pause autosave should capture the latest economy state")

	game.set("credits", 1444)
	game.call("_notification", Node.NOTIFICATION_WM_CLOSE_REQUEST)
	game.set("credits", 6)
	_expect(bool(game.call("_load_battle_snapshot")), "Desktop close notification should persist the active battle before teardown")
	_expect(int(game.get("credits")) == 1444, "Close-request autosave should capture the latest economy state")
	game.set("battle_result", "انتصرت")
	game.set("credits", 999)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	game.set("battle_result", "")
	_expect(bool(game.call("_load_battle_snapshot")) and int(game.get("credits")) == 1444, "Pausing after a completed result must not overwrite the last active resumable battle")
	game.set("game_started", false)
	game.set("campaign_briefing", false)
	game.set("has_resumable_battle", game.call("_has_resumable_battle"))
	game.set("credits", 2222)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	game.set("credits", 7)
	var resume_menu_size: Vector2 = game.get_viewport_rect().size
	var resume_button: Rect2 = game.call("_resume_battle_rect", resume_menu_size)
	_expect(bool(game.get("has_resumable_battle")) and resume_button.size.y >= 42.0, "Main menu must expose a usable resume action when a valid active battle save exists")
	game.call("_handle_pointer", resume_button.get_center(), true)
	game.call("_handle_pointer", resume_button.get_center(), false)
	_expect(bool(game.get("game_started")), "Touching the main-menu resume action must return directly to the saved battle")
	_expect(int(game.get("credits")) == 1444, "Main-menu resume must restore the latest autosaved economy state")
	# Isolate the transport lifecycle fixture after validating independent combat orders above.
	game.get("units").resize(1)

	# Exercise every meaningful transport lifecycle boundary through the real snapshot path.
	var transport_cases := [
		{"state": "inbound", "cargo_count": 1, "target": Vector2(710.0, 280.0), "route": [Vector2(500.0, 220.0), Vector2(710.0, 280.0)], "drop_index": 0},
		{"state": "descending", "cargo_count": 1, "target": Vector2(720.0, 290.0), "route": [Vector2(540.0, 230.0), Vector2(720.0, 290.0)], "drop_index": 0},
		{"state": "returning", "cargo_count": 1, "target": Vector2(650.0, 320.0), "route": [Vector2(600.0, 280.0), Vector2(650.0, 320.0)], "drop_index": 0},
		{"state": "loaded", "cargo_count": 1, "target": Vector2(680.0, 260.0), "route": [], "drop_index": 0},
		{"state": "idle", "cargo_count": 0, "target": Vector2.ZERO, "route": [], "drop_index": 1}
	]
	for case_index in range(transport_cases.size()):
		var transport_case: Dictionary = transport_cases[case_index]
		var live_transport: Dictionary = game.get("units")[0]
		live_transport["transport_state"] = String(transport_case["state"])
		live_transport["transport_target_pos"] = transport_case["target"]
		live_transport["transport_ai_route_points"] = transport_case["route"].duplicate(true)
		live_transport["transport_ai_route_index"] = 0
		live_transport["transport_drop_index"] = int(transport_case["drop_index"])
		live_transport["transport_drop_timer"] = 0.35
		live_transport["transport_cargo"] = []
		if int(transport_case["cargo_count"]) > 0:
			live_transport["transport_cargo"] = [{
				"unit_id": "unit_00000052",
				"kind": "infantry",
				"team": "player",
				"faction": "وطن",
				"hp": 47,
				"pos": Vector2(420.0, 210.0)
			}]
		elif game.get("units").size() == 1:
			game.get("units").append({
				"unit_id": "unit_00000052",
				"kind": "infantry",
				"team": "player",
				"faction": "وطن",
				"hp": 47,
				"pos": Vector2(720.0, 290.0)
			})
		_expect(bool(game.call("_save_battle_snapshot")), "Transport lifecycle case %s should save" % String(transport_case["state"]))
		live_transport["transport_state"] = "idle"
		live_transport["transport_ai_route_points"] = []
		_expect(bool(game.call("_load_battle_snapshot")), "Transport lifecycle case %s should restore" % String(transport_case["state"]))
		var restored_transport: Dictionary = game.get("units")[0]
		_expect(String(restored_transport.get("transport_state", "")) == String(transport_case["state"]), "Transport lifecycle state should survive save/restore")
		_expect(Array(restored_transport.get("transport_cargo", [])).size() == int(transport_case["cargo_count"]), "Transport cargo manifest should match lifecycle state")
		_expect(restored_transport.get("transport_target_pos", Vector2.ZERO).distance_to(transport_case["target"]) < 0.1, "Transport destination should survive lifecycle save/restore")
		_expect(Array(restored_transport.get("transport_ai_route_points", [])).size() == Array(transport_case["route"]).size(), "Transport tactical route should survive lifecycle save/restore")
		if case_index == transport_cases.size() - 1:
			_expect(game.get("units").size() == 2 and String(game.get("units")[1].get("unit_id", "")) == "unit_00000052", "Dropped passenger should exist as a field unit after leaving the manifest")

	# Preserve live collections: the remainder of this integration test exercises
	# transport and battle-result code that expects complete positional records.
	var saved_objective_supply_points: Array = game.get("supply_points").duplicate(true)
	var saved_objective_buildings: Array = game.get("buildings").duplicate(true)
	var saved_objective_units: Array = game.get("units").duplicate(true)

	# Corrupt or stale commander-profile fields must be sanitized before campaign UI reads them.
	var profile_fixture := ConfigFile.new()
	var profile_fixture_data := {
		"battles_played": "many",
		"victories": -4,
		"defeats": 3,
		"total_kills": 12.0,
		"campaign_funds": -900,
		"campaign_progress": {"وطن": 999, "الصيني": -2, "الأمريكي": "unknown", "جهة مجهولة": 4},
		"earned_medals": ["وسام الصمود", 42, "", "وسام الصمود", "قاهر الميدان"]
	}
	profile_fixture.set_value("commander", "profile", profile_fixture_data)
	_expect(profile_fixture.save("user://storm_generals_profile_regression.cfg") == OK, "Test should write an isolated malformed commander profile")
	game.call("_load_commander_profile", "user://storm_generals_profile_regression.cfg")
	var sanitized_profile: Dictionary = game.get("commander_profile")
	_expect(int(sanitized_profile.get("battles_played", -1)) == 0 and int(sanitized_profile.get("victories", -1)) == 0, "Malformed or negative career counters must retain safe defaults")
	_expect(int(sanitized_profile.get("defeats", -1)) == 3 and int(sanitized_profile.get("total_kills", -1)) == 12, "Valid numeric career counters must survive profile loading")
	_expect(int(sanitized_profile.get("campaign_funds", -1)) == 0, "Negative campaign funds must be rejected")
	_expect(int(sanitized_profile.get("campaign_progress", {}).get("وطن", -1)) == 5, "Campaign progress beyond the final mission must clamp to the completed state")
	_expect(not sanitized_profile.get("campaign_progress", {}).has("الصيني") and not sanitized_profile.get("campaign_progress", {}).has("الأمريكي"), "Negative and non-integer mission progress must be ignored")
	_expect(sanitized_profile.get("earned_medals", []) == ["وسام الصمود", "قاهر الميدان"], "Profile medal loading must filter invalid entries and duplicates")
	var profile_test_absolute := ProjectSettings.globalize_path("user://storm_generals_profile_regression.cfg")
	if FileAccess.file_exists("user://storm_generals_profile_regression.cfg"):
		DirAccess.remove_absolute(profile_test_absolute)

	# Commander career writes must be verified and promoted without sacrificing the previous profile.
	var profile_test_path := "user://storm_generals_profile_regression.cfg"
	game.set("commander_profile", {"battles_played": 7, "victories": 4, "defeats": 3, "campaign_progress": {"وطن": 2}, "campaign_funds": 125})
	_expect(bool(game.call("_save_commander_profile", profile_test_path)), "A valid commander profile should save through the atomic profile writer")
	var profile_temp_absolute := ProjectSettings.globalize_path(profile_test_path + ".tmp")
	_expect(DirAccess.make_dir_absolute(profile_temp_absolute) == OK, "Test should create a blocking temporary-path directory")
	game.set("commander_profile", {"battles_played": 99, "victories": 99, "defeats": 0, "campaign_progress": {}, "campaign_funds": 0})
	_expect(not bool(game.call("_save_commander_profile", profile_test_path)), "A failed temporary write must be reported instead of replacing the profile")
	var preserved_profile_config := ConfigFile.new()
	_expect(preserved_profile_config.load(profile_test_path) == OK, "The previous commander profile must remain readable after a failed write")
	var preserved_profile_data: Dictionary = preserved_profile_config.get_value("commander", "profile", {})
	_expect(int(preserved_profile_data.get("battles_played", -1)) == 7 and int(preserved_profile_data.get("campaign_funds", -1)) == 125, "A failed profile write must preserve the last complete career and campaign funds")
	DirAccess.remove_absolute(profile_temp_absolute)

	# Simulate a process interruption after moving the old profile to its backup.
	var profile_absolute := ProjectSettings.globalize_path(profile_test_path)
	var profile_backup_absolute := ProjectSettings.globalize_path(profile_test_path + ".bak")
	_expect(DirAccess.rename_absolute(profile_absolute, profile_backup_absolute) == OK, "Test should stage a verified backup before corrupting the primary profile")
	var corrupt_profile_file := FileAccess.open(profile_test_path, FileAccess.WRITE)
	_expect(corrupt_profile_file != null, "Test should create a corrupted primary commander profile")
	if corrupt_profile_file != null:
		corrupt_profile_file.store_string("not a valid commander profile")
		corrupt_profile_file.close()
	game.call("_load_commander_profile", profile_test_path)
	var recovered_profile: Dictionary = game.get("commander_profile")
	_expect(int(recovered_profile.get("battles_played", -1)) == 7 and int(recovered_profile.get("campaign_funds", -1)) == 125, "A corrupted primary profile must recover the verified backup")
	for cleanup_path in [profile_test_path, profile_test_path + ".tmp", profile_test_path + ".bak"]:
		game.call("_remove_commander_profile_file", cleanup_path)

	# Campaign secondary objectives expose live, deterministic progress for every mission.
	game.set("campaign_mission_index", 0)
	game.set("player_base_hp", 499)
	game.set("game_started", true)
	game.get("selected").clear()
	var objective_hud: Dictionary = game.call("_campaign_objective_hud_state", Vector2(800.0, 480.0))
	_expect(bool(objective_hud.get("visible", false)), "Campaign objective HUD must be visible during an active campaign match")
	_expect((objective_hud.get("rect", Rect2()) as Rect2).position == Vector2(10.0, 203.0), "Objective HUD must use its upper slot when no units are selected")
	_expect(float(objective_hud.get("progress", -1.0)) == 0.998, "Objective HUD progress must match the live mission status")
	_expect(String(objective_hud.get("state", "")) == "499 / 500", "Objective HUD must expose the current and required counts")
	game.get("selected").append(0)
	objective_hud = game.call("_campaign_objective_hud_state", Vector2(800.0, 480.0))
	_expect((objective_hud.get("rect", Rect2()) as Rect2).position == Vector2(10.0, 255.0), "Objective HUD must move below the unit dossier when units are selected")
	game.get("selected").clear()
	game.set("game_started", false)
	objective_hud = game.call("_campaign_objective_hud_state", Vector2(800.0, 480.0))
	_expect(not bool(objective_hud.get("visible", true)), "Objective HUD must be hidden outside an active match")
	game.set("game_started", true)
	var objective_status: Dictionary = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 499 and int(objective_status.get("required", -1)) == 500 and not bool(objective_status.get("met", true)), "Mission 1 objective progress must reflect base health below threshold")
	game.set("player_base_hp", 500)
	_expect(bool(game.call("_campaign_secondary_objective_met")), "Mission 1 secondary objective must complete at 50 percent base health")
	objective_hud = game.call("_campaign_objective_hud_state", Vector2(320.0, 480.0))
	_expect(bool(objective_hud.get("met", false)) and String(objective_hud.get("state", "")) == "مكتمل", "Objective HUD must switch to its completed state when the live threshold is reached")
	_expect(float(objective_hud.get("progress", 0.0)) == 1.0, "Completed objective HUD progress must clamp to exactly 100 percent")
	_expect((objective_hud.get("rect", Rect2()) as Rect2).size == Vector2(300.0, 39.0), "Objective HUD must preserve safe horizontal margins on a narrow phone viewport")

	game.get("supply_points").clear()
	game.get("supply_points").append_array([
		{"id": "objective_supply_1", "pos": Vector2(300.0, 250.0), "owner": "player"},
		{"id": "objective_supply_2", "pos": Vector2(500.0, 250.0), "owner": "player"},
		{"id": "objective_supply_3", "pos": Vector2(700.0, 250.0), "owner": "enemy"},
		{"id": "objective_supply_4", "pos": Vector2(900.0, 250.0), "owner": "neutral"}
	])
	game.set("campaign_mission_index", 1)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 2 and bool(objective_status.get("met", false)), "Mission 2 objective must count two player-controlled supply points")

	game.get("buildings").clear()
	game.get("buildings").append_array([
		{"pos": Vector2(300.0, 300.0), "hp": 100, "build_progress": 1.0},
		{"pos": Vector2(400.0, 300.0), "hp": 100, "build_progress": 1.0},
		{"pos": Vector2(500.0, 300.0), "hp": 100, "build_progress": 1.0},
		{"pos": Vector2(600.0, 300.0), "hp": 100, "build_progress": 0.75},
		{"pos": Vector2(700.0, 300.0), "hp": 0, "build_progress": 1.0}
	])
	game.set("campaign_mission_index", 2)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 3 and not bool(objective_status.get("met", true)), "Mission 3 objective must exclude incomplete and destroyed buildings")
	game.get("buildings").append({"pos": Vector2(800.0, 300.0), "hp": 100, "build_progress": 1.0})
	_expect(bool(game.call("_campaign_secondary_objective_met")), "Mission 3 secondary objective must complete with four finished living buildings")

	game.get("units").clear()
	game.get("units").append_array([
		{"pos": Vector2(300.0, 400.0), "team": "player", "kind": "fighter", "hp": 100},
		{"pos": Vector2(400.0, 400.0), "team": "player", "kind": "tank", "hp": 100},
		{"pos": Vector2(500.0, 400.0), "team": "player", "kind": "artillery", "hp": 0},
		{"pos": Vector2(600.0, 400.0), "team": "enemy", "kind": "tank", "hp": 100}
	])
	game.set("campaign_mission_index", 3)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 2 and bool(objective_status.get("met", false)), "Mission 4 objective must require living player air and armor units")
	game.get("units").clear()
	game.get("units").append_array([
		{"pos": Vector2(300.0, 400.0), "team": "player", "kind": "fighter", "hp": 100},
		{"pos": Vector2(400.0, 400.0), "team": "player", "kind": "tank", "hp": 0}
	])
	_expect(not bool(game.call("_campaign_secondary_objective_met")), "Mission 4 objective must fail when the only armor unit is destroyed")

	game.set("campaign_mission_index", 4)
	game.set("player_base_hp", 599)
	objective_status = game.call("_campaign_secondary_objective_status")
	_expect(int(objective_status.get("current", -1)) == 599 and not bool(objective_status.get("met", true)), "Mission 5 objective progress must reflect base health below 60 percent")
	game.set("player_base_hp", 600)
	_expect(bool(game.call("_campaign_secondary_objective_met")), "Mission 5 secondary objective must complete at 60 percent base health")

	game.get("supply_points").clear()
	game.get("supply_points").append_array(saved_objective_supply_points)
	game.get("buildings").clear()
	game.get("buildings").append_array(saved_objective_buildings)
	game.get("units").clear()
	game.get("units").append_array(saved_objective_units)

	# Battle outcomes must update career and campaign progression exactly once.
	var original_commander_profile: Dictionary = game.get("commander_profile").duplicate(true)
	game.set("commander_profile", {
		"battles_played": 0,
		"victories": 0,
		"defeats": 0,
		"total_kills": 0,
		"air_kills": 0,
		"armor_kills": 0,
		"naval_kills": 0,
		"earned_medals": [],
		"campaign_progress": {"وطن": 0},
		"campaign_funds": 0
	})
	game.set("faction", "وطن")
	game.set("campaign_mission_index", 0)
	game.set("campaign_briefing", false)
	game.set("commander_profile_saved_result", "")
	game.set("battle_result", "")
	game.set("enemy_base_hp", 0)
	game.set("player_base_hp", 700)
	_expect(bool(game.call("_resolve_battle_result")), "Destroying the enemy base must resolve a victory immediately")
	var victory_profile: Dictionary = game.get("commander_profile")
	_expect(int(victory_profile.get("battles_played", 0)) == 1 and int(victory_profile.get("victories", 0)) == 1, "Victory must increment battle and victory totals once")
	_expect(int(victory_profile.get("campaign_progress", {}).get("وطن", 0)) == 1, "Victory must unlock the next campaign mission")
	_expect(int(victory_profile.get("campaign_funds", 0)) == 350, "Meeting the first mission secondary objective must grant base and bonus rewards")
	game.call("_resolve_battle_result")
	_expect(int(victory_profile.get("battles_played", 0)) == 1 and int(victory_profile.get("victories", 0)) == 1, "Repeated victory resolution must not duplicate career totals")
	_expect(int(victory_profile.get("campaign_funds", 0)) == 350, "Repeated victory resolution must not duplicate campaign rewards")

	game.set("faction", "")
	game.set("commander_profile_saved_result", "")
	game.set("battle_result", "")
	game.set("enemy_base_hp", 500)
	game.set("player_base_hp", 0)
	_expect(bool(game.call("_resolve_battle_result")), "Destroying the player base must resolve a defeat immediately")
	var defeat_profile: Dictionary = game.get("commander_profile")
	_expect(int(defeat_profile.get("battles_played", 0)) == 2 and int(defeat_profile.get("defeats", 0)) == 1, "Defeat must increment battle and defeat totals once")
	_expect(int(defeat_profile.get("campaign_progress", {}).get("وطن", 0)) == 1 and int(defeat_profile.get("campaign_funds", 0)) == 350, "Defeat must not unlock missions or award campaign funds")
	game.call("_resolve_battle_result")
	_expect(int(defeat_profile.get("battles_played", 0)) == 2 and int(defeat_profile.get("defeats", 0)) == 1, "Repeated defeat resolution must not duplicate career totals")

	# Every campaign mission must award its own base reward and secondary bonus exactly once.
	var expected_campaign_rewards := [350, 500, 625, 750, 1050]
	for mission_index in range(expected_campaign_rewards.size()):
		game.set("campaign_mission_index", mission_index)
		game.set("faction", "وطن")
		game.set("campaign_briefing", false)
		game.set("battle_result", "victory")
		game.set("commander_profile_saved_result", "")
		game.set("enemy_base_hp", 0)
		game.set("player_base_hp", 1000)
		game.get("supply_points").clear()
		game.get("buildings").clear()
		game.get("units").clear()
		if mission_index == 0:
			game.set("player_base_hp", 500)
		elif mission_index == 1:
			game.get("supply_points").append_array([
				{"pos": Vector2(300.0, 250.0), "owner": "player"},
				{"pos": Vector2(500.0, 250.0), "owner": "player"}
			])
		elif mission_index == 2:
			for building_index in range(4):
				game.get("buildings").append({"pos": Vector2(300.0 + building_index * 100.0, 300.0), "hp": 100, "build_progress": 1.0})
		elif mission_index == 3:
			game.get("units").append_array([
				{"pos": Vector2(300.0, 400.0), "team": "player", "kind": "fighter", "hp": 100},
				{"pos": Vector2(400.0, 400.0), "team": "player", "kind": "tank", "hp": 100}
			])
		elif mission_index == 4:
			game.set("player_base_hp", 600)
		game.set("commander_profile", {
			"battles_played": 0,
			"victories": 0,
			"defeats": 0,
			"campaign_progress": {"وطن": mission_index},
			"campaign_funds": 0
		})
		game.call("_record_battle_result")
		var mission_profile: Dictionary = game.get("commander_profile")
		_expect(int(mission_profile.get("campaign_funds", 0)) == expected_campaign_rewards[mission_index], "Campaign mission %d must award its base reward plus its secondary bonus" % (mission_index + 1))
		_expect(int(mission_profile.get("campaign_progress", {}).get("وطن", -1)) == mission_index + 1, "Campaign mission %d victory must unlock exactly the next mission" % (mission_index + 1))
		game.call("_record_battle_result")
		_expect(int(mission_profile.get("campaign_funds", 0)) == expected_campaign_rewards[mission_index], "Campaign mission %d repeated result must not duplicate rewards" % (mission_index + 1))

	# Exercise the real faction-picker and campaign-start pointer path.
	game.set("commander_profile", {
		"battles_played": 0,
		"victories": 0,
		"defeats": 0,
		"campaign_progress": {"وطن": 2},
		"campaign_funds": 0
	})
	game.set("game_started", false)
	game.set("campaign_briefing", false)
	game.set("battle_result", "")
	game.set("faction", "")
	var menu_size: Vector2 = game.get_viewport_rect().size
	var watan_button: Rect2 = game.call("_faction_rect", 3, menu_size)
	game.call("_handle_pointer", watan_button.get_center(), true)
	game.call("_handle_pointer", watan_button.get_center(), false)
	_expect(String(game.get("faction")) == "وطن" and bool(game.get("campaign_briefing")), "Selecting Watan from the live faction picker must open its campaign briefing")
	var campaign_start_button: Rect2 = game.call("_campaign_start_rect", menu_size)
	game.call("_handle_pointer", campaign_start_button.get_center(), true)
	game.call("_handle_pointer", campaign_start_button.get_center(), false)
	_expect(bool(game.get("game_started")) and not bool(game.get("campaign_briefing")), "Campaign start button must enter the live match")
	_expect(int(game.get("campaign_mission_index")) == 2 and String(game.get("map_type")) == "الساحل الجبلي", "Campaign start must resume the correct unlocked mission and map")
	_expect(game.get("units").size() == 1 and String(game.get("units")[0].get("kind", "")) == "builder" and String(game.get("units")[0].get("faction", "")) == "وطن", "Campaign start must deploy the selected army's builder")
	_expect(int(game.get("credits")) == 1200 and int(game.get("supplies")) == 5 and int(game.get("enemy_supplies")) == 5, "Campaign start must initialize both economies and opening supplies")

	# Complete a full campaign battle through the actual frame loop and verify one-time resolution.
	for building_index in range(4):
		game.get("buildings").append({
			"kind": "barracks" if building_index == 0 else "factory",
			"pos": Vector2(300.0 + building_index * 80.0, 300.0),
			"hp": 400,
			"build_progress": 1.0
		})
	game.set("enemy_base_hp", 0)
	game.call("_process", 0.1)
	_expect(String(game.get("battle_result")) != "" and String(game.get("battle_result")).contains("انتصرت"), "Destroying the enemy base during the live campaign loop must resolve a victory")
	var live_victory_profile: Dictionary = game.get("commander_profile")
	_expect(int(live_victory_profile.get("battles_played", 0)) == 1 and int(live_victory_profile.get("victories", 0)) == 1, "Live campaign victory must record career totals exactly once")
	_expect(int(live_victory_profile.get("campaign_progress", {}).get("وطن", 0)) == 3, "Live campaign victory must unlock the next Watan mission")
	_expect(int(live_victory_profile.get("campaign_funds", 0)) == 625, "Live mountain campaign victory must grant its 450 base reward and 175 secondary bonus")
	game.call("_process", 0.1)
	_expect(int(live_victory_profile.get("battles_played", 0)) == 1 and int(live_victory_profile.get("campaign_funds", 0)) == 625, "Additional frames after victory must not duplicate campaign rewards or career totals")

	# Resolve defeat through the same live frame loop; it must not advance or reward the campaign.
	game.set("battle_result", "")
	game.set("commander_profile_saved_result", "")
	game.set("player_base_hp", 0)
	game.set("enemy_base_hp", 500)
	game.call("_process", 0.1)
	var live_defeat_result := String(game.get("battle_result"))
	_expect(live_defeat_result.contains("هُزمت"), "Destroying the player base in the live campaign loop must resolve defeat")
	_expect(int(live_victory_profile.get("battles_played", 0)) == 2 and int(live_victory_profile.get("defeats", 0)) == 1, "Live defeat must record exactly one additional battle and defeat")
	_expect(int(live_victory_profile.get("campaign_progress", {}).get("وطن", 0)) == 3 and int(live_victory_profile.get("campaign_funds", 0)) == 625, "Live defeat must preserve campaign progress and grant no additional funds")
	_expect(bool(game.call("_save_battle_snapshot")), "A completed defeat state must be saveable for result continuity")
	game.set("battle_result", "")
	game.set("player_base_hp", 900)
	_expect(bool(game.call("_load_battle_snapshot")), "Saved defeat state must restore through the battle save integration")
	_expect(String(game.get("battle_result")) == live_defeat_result and int(game.get("player_base_hp")) == 0, "Restoring a defeated battle must preserve its result and destroyed base state")
	game.call("_process", 0.1)
	_expect(int(live_victory_profile.get("battles_played", 0)) == 2 and int(live_victory_profile.get("defeats", 0)) == 1, "Frames after restoring defeat must not record the same loss twice")

	game.set("commander_profile", original_commander_profile)
	game.call("_save_commander_profile")

	game.get("battle_save_store").call("delete_snapshot")
	game.get("battle_save_store").call("delete_snapshot")
	game.queue_free()
	await process_frame
	if failure_count > 0:
		push_error("Battle save integration failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Battle save integration passed: full match snapshot restores economy, objectives, armies, transport cargo, production, and missiles.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Battle save integration failed: " + message)
