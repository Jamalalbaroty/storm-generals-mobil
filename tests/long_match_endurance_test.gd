extends SceneTree

var failure_count: int = 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Audio is irrelevant to deterministic simulation and can keep headless
	# AudioServer handles alive during SceneTree shutdown.
	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		game.remove_child(audio_player)
		audio_player.free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()

	game.set("faction", "الأمريكي")
	game.set("base_pos", Vector2(160.0, 360.0))
	game.set("enemy_base", Vector2(1080.0, 360.0))
	game.set("player_base_hp", 100000)
	game.set("enemy_base_hp", 100000)
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("credits", 5000)
	game.set("supplies", 40)
	game.set("enemy_credits", 6000)
	game.set("enemy_supplies", 40)
	game.set("income_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_timer", 0.0)
	game.set("enemy_missile_timer", 999.0)
	game.set("enemy_strategy", "balanced")
	game.set("map_type", "الساحل الصحراوي")
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("units").clear()
	game.get("production_orders").clear()
	game.get("missiles").clear()
	game.get("visual_effects").clear()
	game.get("environment_particles").clear()
	game.get("supply_points").clear()

	# Both economies receive a powered production backbone before the match begins.
	for kind in ["power_plant", "power_plant", "factory", "barracks"]:
		game.get("buildings").append({
			"kind": kind, "pos": Vector2(180.0 + float(game.get("buildings").size()) * 34.0, 330.0),
			"hp": 500, "build_progress": 1.0
		})
	for kind in ["power_plant", "power_plant", "power_plant", "factory", "barracks", "airfield"]:
		game.get("enemy_buildings").append({
			"kind": kind, "pos": Vector2(1080.0 - float(game.get("enemy_buildings").size()) * 30.0, 330.0),
			"hp": 600, "build_progress": 1.0
		})

	var player_port := Vector2(280.0, 190.0)
	var enemy_port := Vector2(960.0, 530.0)
	game.get("supply_points").append({
		"pos": player_port, "owner": "player", "kind": "port",
		"payout": 0.0, "supply_payout": 0.0
	})
	game.get("supply_points").append({
		"pos": enemy_port, "owner": "enemy", "kind": "port",
		"payout": 0.0, "supply_payout": 0.0
	})

	var units: Array = game.get("units")
	units.append({"kind": "infantry", "team": "player", "faction": "الأمريكي", "hp": 50000, "pos": player_port, "attack_cd": 10.0})
	units.append({"kind": "infantry", "team": "enemy", "faction": "الصيني", "hp": 50000, "pos": enemy_port, "attack_cd": 10.0})
	for tank_index in range(3):
		units.append({
			"kind": "tank", "team": "player", "faction": "الأمريكي",
			"hp": 12000, "pos": Vector2(440.0, 300.0 + float(tank_index) * 34.0),
			"attack_cd": 0.0
		})
	for tank_index in range(3):
		units.append({
			"kind": "tank", "team": "enemy", "faction": "الصيني",
			"hp": 5000, "pos": Vector2(760.0, 300.0 + float(tank_index) * 34.0),
			"attack_cd": 0.0
		})
	game.set("units", units)

	# Queue a real player tank and let the normal frame loop complete it.
	var credits_before_queue: int = int(game.get("credits"))
	game.call("_enqueue_unit", "tank")
	var supplies_after_queue: int = int(game.get("supplies"))
	_expect(game.get("production_orders").size() == 1, "A powered factory should accept a tank order before the endurance run")
	_expect(int(game.get("credits")) < credits_before_queue, "Player production should reserve credits")
	for frame in range(80):
		game.call("_process", 0.1)
	_expect(game.get("production_orders").is_empty(), "The player tank should finish production through the live frame loop")
	_expect(int(game.call("_team_unit_count", "player")) >= 4, "The live production loop should add a fourth player tank")
	# The queued tank already spent one supply; the port restores one after its 6-second payout interval.
	_expect(int(game.get("supplies")) >= 40, "The player-held port should offset the opening tank supply cost during the production phase")
	_expect(int(game.get("enemy_supplies")) > 40, "The enemy-held port should deliver supply income during the opening production phase")

	# Sustain a deterministic 90-second match: income, port payouts, combat,
	# enemy doctrine changes, counter-production, and unit cleanup all run
	# through _process rather than isolated helper calls.
	for frame in range(900):
		game.call("_process", 0.1)

	_expect(String(game.get("battle_result")) == "", "A sustained match with reinforced bases should remain active")
	_expect(String(game.get("enemy_strategy")) == "armor_breaker", "Enemy AI should recognize and retain its response to the player's three-tank force")
	_expect(int(game.get("enemy_credits")) >= 0 and int(game.get("enemy_supplies")) >= 0, "Enemy economy must never become negative during repeated AI decisions")
	_expect(int(game.get("credits")) >= 0 and int(game.get("supplies")) >= 0, "Player economy must never become negative during sustained production and supply payouts")
	_expect(int(game.call("_team_unit_count", "enemy")) >= 4, "Enemy counter-production should reinforce its starting force during the long match")

	var enemy_helicopters := 0
	for unit in game.get("units"):
		if String(unit.get("team", "")) == "enemy" and String(unit.get("kind", "")) == "helicopter":
			enemy_helicopters += 1
		_expect(int(unit.get("hp", 0)) > 0, "Destroyed units must be removed before the next live frame")
	_expect(enemy_helicopters >= 1, "Armor-breaker doctrine should field at least one helicopter counter through the live AI loop")
	_expect(game.get("production_orders").is_empty(), "No completed player production order should remain stuck after the endurance run")

	# Gradually increase live battlefield density after the economy/endurance checks.
	# Keep health high so this phase measures sustained update/identity handling,
	# not which side wins the deliberately crowded engagement.
	for stage_count in [8, 16, 24, 32, 40, 48]:
		for team in ["player", "enemy"]:
			for stage_index in range(8):
				var unit_number: int = int(stage_count) - 8 + stage_index
				var unit_kind := "tank"
				if unit_number % 4 == 2:
					unit_kind = "fighter"
				elif unit_number % 4 == 3:
					unit_kind = "helicopter"
				# Pack each side into an 8-column grid that stays inside the
				# 1280x720 test viewport even at the 48-unit-per-team stage.
				var grid_column: int = unit_number % 8
				var grid_row: int = int(unit_number / 8)
				var side_origin_x := 180.0 if team == "player" else 700.0
				var side_x := side_origin_x + float(grid_column) * 50.0
				var side_y := 140.0 + float(grid_row) * 75.0
				units.append({
					"kind": unit_kind, "team": team,
					"faction": "الأمريكي" if team == "player" else "الصيني",
					"hp": 100000, "pos": Vector2(side_x, side_y),
					"attack_cd": 10.0
				})
		game.set("units", units)
		game.call("_ensure_stable_unit_identities")
		var seen_stress_ids: Dictionary = {}
		for stress_unit in units:
			var stress_id := String(stress_unit.get("unit_id", ""))
			_expect(not stress_id.is_empty(), "Every live unit must receive a stable identity during density ramp")
			_expect(not seen_stress_ids.has(stress_id), "Unit identities must remain unique as battlefield density increases")
			seen_stress_ids[stress_id] = true
		# Record simulation-update cost separately from rendered FPS: this headless
		# benchmark helps compare density growth without pretending to be a device test.
		var density_start_usec := Time.get_ticks_usec()
		for stress_frame in range(100):
			game.call("_process", 0.1)
		var density_elapsed_ms := float(Time.get_ticks_usec() - density_start_usec) / 1000.0
		var density_average_frame_ms := density_elapsed_ms / 100.0
		_expect(is_finite(density_average_frame_ms) and density_average_frame_ms >= 0.0, "Density benchmark must report a valid simulation-update duration")
		print("DENSITY UPDATE BENCH: %d staged units/team | %d live units | %.3f ms/update" % [int(stage_count), units.size(), density_average_frame_ms])
		_expect(String(game.get("battle_result")) == "", "A staged high-density match must remain active during the stress window")
		_expect(int(game.get("credits")) >= 0 and int(game.get("enemy_credits")) >= 0, "Both economies must remain non-negative during density stress")
		_expect(int(game.get("supplies")) >= 0 and int(game.get("enemy_supplies")) >= 0, "Both supply pools must remain non-negative during density stress")

	# Confirm both port economies continue to accrue even after repeated AI turns.
	var player_port_state: Dictionary = game.get("supply_points")[0]
	var enemy_port_state: Dictionary = game.get("supply_points")[1]
	_expect(String(player_port_state.get("owner", "")) == "player", "Player port ownership should remain stable while its garrison holds the site")
	_expect(String(enemy_port_state.get("owner", "")) == "enemy", "Enemy port ownership should remain stable while its garrison holds the site")
	_expect(float(player_port_state.get("payout", 0.0)) >= 0.0 and float(enemy_port_state.get("payout", 0.0)) >= 0.0, "Both port payout clocks should remain valid after sustained simulation")

	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		audio_player.queue_free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()
	game.queue_free()
	for frame in range(4):
		await process_frame

	if failure_count > 0:
		push_error("Long-match endurance test failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Long-match endurance test passed: 158 seconds of live economy, production, AI, combat, supply, and staged battlefield-density simulation.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Long-match endurance test failed: " + message)
