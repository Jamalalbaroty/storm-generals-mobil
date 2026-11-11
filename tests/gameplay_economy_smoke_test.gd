extends SceneTree

var failure_count: int = 0

func _initialize() -> void:
	call_deferred("_run_gameplay_economy_smoke_test")


func _run_gameplay_economy_smoke_test() -> void:
	_expect(int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) == 0, "Mobile game should use landscape orientation")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) > int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)), "Mobile viewport should remain wider than it is tall")

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

	# Mobile command deck exposes all 29 unique actions across five tabs.
	var expected_command_tabs: Array = [
		[0, 1, 2, 3, 4, 5],
		[6, 7, 8, 9, 21, 22],
		[10, 11, 12, 13, 14, 15],
		[23, 24, 25, 26, 27],
		[28, 29, 30, 31, 32, 33]
	]
	var covered_actions: Dictionary = {}
	for tab_index in range(expected_command_tabs.size()):
		game.set("command_tab", tab_index)
		var visible_actions: Array = game.call("_command_action_ids")
		_expect(visible_actions == expected_command_tabs[tab_index], "Each command tab should expose its intended gameplay actions")
		for action_id in visible_actions:
			covered_actions[int(action_id)] = true
	_expect(covered_actions.size() == 29, "The five compact command tabs should retain access to all 29 gameplay actions")
	# The four army choices must remain visible and independently tappable on common phone aspect ratios.
	var picker_viewports: Array[Vector2] = [
		Vector2(1280.0, 720.0),
		Vector2(800.0, 480.0),
		Vector2(720.0, 1280.0),
		Vector2(360.0, 800.0),
		Vector2(320.0, 568.0)
	]
	for picker_viewport in picker_viewports:
		var faction_rects: Array[Rect2] = []
		for faction_index in range(4):
			var faction_rect: Rect2 = game.call("_faction_rect", faction_index, picker_viewport)
			_expect(faction_rect.position.x >= 0.0 and faction_rect.position.y >= 0.0 and faction_rect.end.x <= picker_viewport.x and faction_rect.end.y <= picker_viewport.y, "Every army choice must fit inside viewport %s" % picker_viewport)
			for previous_rect in faction_rects:
				_expect(not faction_rect.intersects(previous_rect), "Army choice touch targets must not overlap on viewport %s" % picker_viewport)
			faction_rects.append(faction_rect)
		_expect(faction_rects[0].position.x < faction_rects[1].position.x, "First army row should use two columns")
		_expect(faction_rects[2].position.y > faction_rects[0].position.y, "Second army row should be reachable below the first")
	# Exercise the real press/release path, including the campaign briefing between faction selection and battle start.
	var active_viewport: Vector2 = game.get_viewport_rect().size
	var expected_factions: Array[String] = ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
	for faction_index in range(expected_factions.size()):
		game.set("game_started", false)
		game.set("campaign_briefing", false)
		game.set("faction", "")
		game.get("units").clear()
		var touch_target: Rect2 = game.call("_faction_rect", faction_index, active_viewport)
		game.call("_handle_pointer", touch_target.get_center(), true)
		game.call("_handle_pointer", touch_target.get_center(), false)
		_expect(bool(game.get("campaign_briefing")) and not bool(game.get("game_started")), "Tapping army card %d should open its campaign briefing" % faction_index)
		_expect(String(game.get("faction")) == expected_factions[faction_index], "Tapping army card %d should select the matching faction" % faction_index)
		var campaign_start: Vector2 = game.call("_campaign_start_rect", active_viewport).get_center()
		game.call("_handle_pointer", campaign_start, true)
		game.call("_handle_pointer", campaign_start, false)
		_expect(bool(game.get("game_started")), "Starting the selected campaign should launch the match for army %d" % faction_index)
		var starting_units: Array = game.get("units")
		_expect(not starting_units.is_empty() and String(starting_units[0].get("kind", "")) == "builder", "Each faction should receive its starting builder")
		if not starting_units.is_empty():
			_expect(String(starting_units[0].get("faction", "")) == expected_factions[faction_index], "Starting builder should inherit the selected faction")
	game.set("game_started", false)
	game.set("campaign_briefing", false)
	game.get("units").clear()

	# A second finger must not take ownership of an active touch or change its
	# drag/release target. This protects command taps from accidental multitouch.
	var multitouch_first_target: Vector2 = game.call("_faction_rect", 0, active_viewport).get_center()
	var multitouch_second_target: Vector2 = game.call("_faction_rect", 3, active_viewport).get_center()
	var primary_touch := InputEventScreenTouch.new()
	primary_touch.index = 0
	primary_touch.pressed = true
	primary_touch.position = multitouch_first_target
	game._input(primary_touch)
	_expect(int(game.get("active_touch_index")) == 0 and bool(game.get("dragging")), "The first finger should own the active pointer")
	var secondary_touch := InputEventScreenTouch.new()
	secondary_touch.index = 1
	secondary_touch.pressed = true
	secondary_touch.position = multitouch_second_target
	game._input(secondary_touch)
	var secondary_drag := InputEventScreenDrag.new()
	secondary_drag.index = 1
	secondary_drag.position = multitouch_second_target
	game._input(secondary_drag)
	_expect(int(game.get("active_touch_index")) == 0, "A second finger must not replace the primary touch")
	_expect(game.get("drag_end") == multitouch_first_target, "A second-finger drag must not move the primary selection pointer")
	secondary_touch.pressed = false
	game._input(secondary_touch)
	_expect(int(game.get("active_touch_index")) == 0 and not bool(game.get("game_started")), "A second-finger release must not complete the primary tap")
	primary_touch.pressed = false
	game._input(primary_touch)
	_expect(int(game.get("active_touch_index")) == -1, "The primary touch should release pointer ownership")
	_expect(bool(game.get("campaign_briefing")) and not bool(game.get("game_started")) and String(game.get("faction")) == "الأمريكي", "The original finger should complete its intended army-card selection without a secondary finger stealing the tap")
	var multitouch_campaign_start: Vector2 = game.call("_campaign_start_rect", active_viewport).get_center()
	game.call("_handle_pointer", multitouch_campaign_start, true)
	game.call("_handle_pointer", multitouch_campaign_start, false)
	_expect(bool(game.get("game_started")), "The selected army should start after the briefing confirmation")
	game.set("game_started", false)
	game.set("campaign_briefing", false)
	game.get("units").clear()

	# Verify touch selection, move orders, and direct attack orders through the
	# same pointer handler used by mobile input.
	var battle_viewport: Vector2 = game.get_viewport_rect().size
	var army_start_rect: Rect2 = game.call("_faction_rect", 0, battle_viewport)
	var army_start: Vector2 = army_start_rect.get_center()
	game.call("_handle_pointer", army_start, true)
	game.call("_handle_pointer", army_start, false)
	var battle_campaign_start: Vector2 = game.call("_campaign_start_rect", battle_viewport).get_center()
	game.call("_handle_pointer", battle_campaign_start, true)
	game.call("_handle_pointer", battle_campaign_start, false)
	var builder_position: Vector2 = game.get("base_pos") + Vector2(58.0, 0.0)
	game.call("_handle_pointer", builder_position, true)
	game.call("_handle_pointer", builder_position, false)
	_expect(game.get("selected").size() == 1 and int(game.get("selected")[0]) == 0, "Touching the starting builder should select it")
	var move_target := Vector2(450.0, 430.0)
	game.call("_handle_pointer", move_target, true)
	game.call("_handle_pointer", move_target, false)
	_expect(game.get("units").size() > 0 and game.get("units")[0].get("target", Vector2.ZERO).distance_to(move_target) < 0.1, "Tapping open battlefield after selecting a unit should issue a move order")
	game.get("units").append({"pos": Vector2(650.0, 330.0), "team": "enemy", "kind": "infantry", "hp": 60, "attack_cd": 0.0})
	var enemy_target: Vector2 = game.get("units")[1]["pos"]
	game.call("_handle_pointer", enemy_target, true)
	game.call("_handle_pointer", enemy_target, false)
	_expect(int(game.get("units")[0].get("attack_target", -1)) == 1, "Tapping a visible enemy while a friendly unit is selected should issue an attack order")
	game.get("units").clear()
	game.get("selected").clear()
	game.set("game_started", false)

	# End-to-end player loop: tap build commands, place/finish structures, then produce infantry and armor.
	var build_loop_viewport: Vector2 = game.get_viewport_rect().size
	game.set("command_tab", 0)
	game.set("campaign_briefing", false)
	var build_loop_army: Vector2 = game.call("_faction_rect", 0, build_loop_viewport).get_center()
	game.call("_handle_pointer", build_loop_army, true)
	game.call("_handle_pointer", build_loop_army, false)
	var build_loop_campaign_start: Vector2 = game.call("_campaign_start_rect", build_loop_viewport).get_center()
	game.call("_handle_pointer", build_loop_campaign_start, true)
	game.call("_handle_pointer", build_loop_campaign_start, false)
	var build_loop_builder: Vector2 = game.get("base_pos") + Vector2(58.0, 0.0)
	game.call("_handle_pointer", build_loop_builder, true)
	game.call("_handle_pointer", build_loop_builder, false)
	game.set("credits", 5000)
	game.set("supplies", 20)

	var barracks_command: Vector2 = game.call("_button_rect", 2, build_loop_viewport).get_center()
	game.call("_handle_pointer", barracks_command, true)
	game.call("_handle_pointer", barracks_command, false)
	var barracks_site: Vector2 = game.get("base_pos") + Vector2(120.0, 80.0)
	game.call("_handle_pointer", barracks_site, true)
	game.call("_handle_pointer", barracks_site, false)
	_expect(game.get("buildings").size() == 1 and String(game.get("buildings")[0].get("kind", "")) == "barracks", "Build command should place a barracks at a valid tapped site")
	if not game.get("buildings").is_empty():
		# A nearby second structure must not progress unless the builder is assigned to it.
		game.get("buildings").append({"pos": barracks_site + Vector2(20.0, 0.0), "kind": "turret", "hp": 400, "build_progress": 0.0, "build_duration": 8.0})
		# Construction must pause unless a living builder remains within 48 units.
		game.get("units")[0]["pos"] = barracks_site + Vector2(60.0, 0.0)
		game.call("_update_building_construction", 2.0)
		_expect(is_equal_approx(float(game.get("buildings")[0].get("build_progress", 0.0)), 0.0), "Construction should not advance while the builder is outside its work radius")
		_expect(is_equal_approx(float(game.get("buildings")[1].get("build_progress", 0.0)), 0.0), "An unassigned nearby structure must not progress")
		game.get("units")[0]["pos"] = barracks_site + Vector2(30.0, 0.0)
		game.call("_update_building_construction", 2.0)
		_expect(is_equal_approx(float(game.get("buildings")[0].get("build_progress", 0.0)), 0.25), "A nearby living builder should advance its assigned construction proportionally")
		_expect(is_equal_approx(float(game.get("buildings")[1].get("build_progress", 0.0)), 0.0), "A builder must not advance a second structure it was not assigned to")
		game.get("units")[0]["pos"] = barracks_site + Vector2(80.0, 0.0)
		game.call("_update_building_construction", 2.0)
		_expect(is_equal_approx(float(game.get("buildings")[0].get("build_progress", 0.0)), 0.25), "Construction should pause when the builder leaves the work radius")
		game.get("units")[0]["pos"] = barracks_site
		game.get("units")[0]["hp"] = 0
		game.call("_update_building_construction", 2.0)
		_expect(is_equal_approx(float(game.get("buildings")[0].get("build_progress", 0.0)), 0.25), "A destroyed builder must not advance construction")
		game.get("units")[0]["hp"] = 220
		game.call("_update_building_construction", 6.0)
		_expect(float(game.get("buildings")[0].get("build_progress", 0.0)) >= 1.0, "A living builder returning to the site should finish the remaining construction")
		_expect(not game.get("units")[0].has("build_target"), "The builder should be released from its completed construction assignment")
		_expect(is_equal_approx(float(game.get("buildings")[1].get("build_progress", 0.0)), 0.0), "The unassigned structure should remain untouched after the assigned building completes")
		game.get("buildings").remove_at(1)
		var infantry_credits_before: int = int(game.get("credits"))
		var infantry_supplies_before: int = int(game.get("supplies"))
		game.call("_enqueue_unit", "infantry")
		_expect(game.get("production_orders").size() == 1, "Completed barracks should accept an infantry production order")
		_expect(int(game.get("credits")) < infantry_credits_before, "Infantry queue should reserve credits")
		_expect(int(game.get("supplies")) == infantry_supplies_before and int(game.call("_unit_supply_cost", "infantry")) == 0, "Infantry should not consume supplies under the faction economy rules")
		game.call("_update_production_queues", 3.0)
		var produced_infantry := 0
		for loop_unit in game.get("units"):
			if String(loop_unit.get("kind", "")) == "infantry" and String(loop_unit.get("team", "")) == "player":
				produced_infantry += 1
		_expect(produced_infantry == 1 and game.get("production_orders").is_empty(), "Completed infantry production should spawn exactly one friendly soldier")

		var factory_command: Vector2 = game.call("_button_rect", 3, build_loop_viewport).get_center()
		game.call("_handle_pointer", factory_command, true)
		game.call("_handle_pointer", factory_command, false)
		var factory_site: Vector2 = game.get("base_pos") + Vector2(145.0, -90.0)
		game.call("_handle_pointer", factory_site, true)
		game.call("_handle_pointer", factory_site, false)
		_expect(game.get("buildings").size() == 2 and String(game.get("buildings")[1].get("kind", "")) == "factory", "Build command should place a factory separately from the barracks")
		if game.get("buildings").size() == 2:
			game.get("units")[0]["pos"] = factory_site
			game.call("_update_building_construction", 10.0)
			_expect(float(game.get("buildings")[1].get("build_progress", 0.0)) >= 1.0, "Builder should complete the placed factory")
			var tank_credits_before: int = int(game.get("credits"))
			var tank_supplies_before: int = int(game.get("supplies"))
			game.call("_enqueue_unit", "tank")
			_expect(game.get("production_orders").size() == 1, "Completed factory should accept a tank production order")
			_expect(int(game.get("credits")) < tank_credits_before and int(game.get("supplies")) < tank_supplies_before, "Tank queue should reserve credits and supplies")
			game.call("_update_production_queues", 7.0)
			var produced_tanks := 0
			for loop_unit in game.get("units"):
				if String(loop_unit.get("kind", "")) == "tank" and String(loop_unit.get("team", "")) == "player":
					produced_tanks += 1
			_expect(produced_tanks == 1 and game.get("production_orders").is_empty(), "Completed tank production should spawn exactly one friendly tank")

			# Repair is a paid, proportional restoration; the selected-building command is reachable by touch.
			game.get("buildings")[0]["hp"] = 200
			game.set("selected_player_building", -1)
			var barracks_touch: Vector2 = game.get("buildings")[0]["pos"]
			game.call("_handle_pointer", barracks_touch, true)
			game.call("_handle_pointer", barracks_touch, false)
			_expect(int(game.get("selected_player_building")) == 0, "Tapping a friendly structure should select it for management")
			game.set("command_tab", 2)
			var repair_credits_before := int(game.get("credits"))
			var repair_button: Vector2 = game.call("_button_rect", 0, build_loop_viewport).get_center()
			game.call("_handle_pointer", repair_button, true)
			game.call("_handle_pointer", repair_button, false)
			_expect(int(game.get("buildings")[0].get("hp", 0)) == 400, "Repair command should restore a damaged completed structure to full health")
			_expect(int(game.get("credits")) == repair_credits_before - 63, "Repair should charge half the proportional barracks replacement value, rounded up")
	
			# Insufficient funds and unfinished structures must never grant a free repair.
			game.get("buildings")[0]["hp"] = 200
			game.set("credits", 0)
			game.set("selected_player_building", 0)
			game.call("_repair_selected_building")
			_expect(int(game.get("buildings")[0].get("hp", 0)) == 200, "Repair should not proceed without enough credits")
			game.get("buildings")[0]["build_progress"] = 0.5
			game.set("credits", 5000)
			game.call("_repair_selected_building")
			_expect(int(game.get("buildings")[0].get("hp", 0)) == 200, "An unfinished structure must not be repairable")
			game.get("buildings")[0]["build_progress"] = 1.0
			game.get("buildings")[0]["hp"] = 400
	
			# Selling refunds 50% of the original building cost and removes the structure.
			var factory_sell_touch: Vector2 = game.get("buildings")[1]["pos"]
			game.call("_handle_pointer", factory_sell_touch, true)
			game.call("_handle_pointer", factory_sell_touch, false)
			_expect(int(game.get("selected_player_building")) == 1, "Tapping the factory should select it for sale")
			game.set("credits", 1000)
			var sale_credits_before := int(game.get("credits"))
			var sell_button: Vector2 = game.call("_button_rect", 1, build_loop_viewport).get_center()
			game.call("_handle_pointer", sell_button, true)
			game.call("_handle_pointer", sell_button, false)
			_expect(game.get("buildings").size() == 1, "Selling a completed factory should remove it from the base")
			_expect(int(game.get("credits")) == sale_credits_before + 225, "Selling a factory should refund exactly half of its 450-credit cost")
			_expect(int(game.get("selected_player_building")) == -1, "Selling a structure should clear the stale building selection")
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("production_orders").clear()
	game.get("selected").clear()
	game.set("game_started", false)

	var mobile_viewport := Vector2(1280.0, 720.0)
	var first_command_button: Rect2 = game.call("_button_rect", 0, mobile_viewport)
	var last_command_button: Rect2 = game.call("_button_rect", 5, mobile_viewport)
	var first_command_tab: Rect2 = game.call("_command_tab_rect", 0, mobile_viewport)
	_expect(first_command_button.size.y >= 44.0 and first_command_button.size.x >= 300.0, "Command buttons should remain comfortable touch targets")
	_expect(last_command_button.end.y <= mobile_viewport.y, "The final command row should remain inside the mobile viewport")
	_expect(first_command_tab.position.y - 197.0 >= 340.0, "The compact command deck should preserve a useful central battlefield area")
	game.set("command_tab", 0)

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

	# Capture, contest, and recapture lifecycle: ownership changes must reset fractional income and transfer payouts to the new owner.
	live_units = game.get("units")
	live_units[0]["hp"] = 0
	game.set("units", live_units)
	game.set("enemy_credits", 0)
	game.set("enemy_supplies", 0)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[2]["owner"]) == "enemy", "Enemy infantry should capture the port after player forces are eliminated")
	_expect(int(game.get("enemy_credits")) == 8, "Captured port income should transfer to the enemy immediately")
	_expect(int(game.get("credits")) == 48, "Former owner must stop receiving port income after capture")
	_expect(is_equal_approx(float(game.get("supply_points")[2]["payout"]), 0.0), "Ownership transfer should reset the previous owner's fractional credit timer")
	_expect(is_equal_approx(float(game.get("supply_points")[2]["supply_payout"]), 1.0), "Ownership transfer should reset the previous owner's fractional supply timer before accruing the new owner's one-second payout")
	live_units = game.get("units")
	live_units[1]["hp"] = 0
	live_units.append({"pos": port_position, "team": "player", "kind": "tank", "hp": 150})
	game.set("units", live_units)
	game.call("_update_supply_control", 1.0)
	_expect(String(game.get("supply_points")[2]["owner"]) == "player", "Player armor should recapture the port after removing enemy control")
	_expect(int(game.get("credits")) == 56, "Recaptured port should resume income for the player")
	_expect(int(game.get("enemy_credits")) == 8, "Enemy income should stop after losing the port")

	# Enemy strategic logistics should favor valuable player-held objectives and dispatch only one guard per threatened point.
	game.get("supply_points").clear()
	game.get("supply_points").append({"pos": Vector2(200.0, 300.0), "owner": "neutral", "kind": "supply", "payout": 0.0, "supply_payout": 0.0})
	game.get("supply_points").append({"pos": Vector2(600.0, 300.0), "owner": "player", "kind": "supply", "payout": 0.0, "supply_payout": 0.0})
	game.get("supply_points").append({"pos": Vector2(500.0, 300.0), "owner": "player", "kind": "port", "payout": 0.0, "supply_payout": 0.0})
	_expect(int(game.call("_enemy_best_supply_objective", Vector2(550.0, 300.0))) == 2, "Enemy strategy should prioritize the nearby player-held port over a regular supply point")
	_expect(not bool(game.call("_enemy_should_engage_player", true, 260.0, 120.0, "balanced", false)), "Balanced enemy forces should prioritize a much closer strategic supply objective over a distant player target")
	_expect(bool(game.call("_enemy_should_engage_player", true, 150.0, 120.0, "balanced", false)), "Balanced enemy forces should engage when the player threat is close to the supply objective distance")
	_expect(bool(game.call("_enemy_should_engage_player", true, 260.0, 120.0, "armor_breaker", false)), "Threat-focused enemy doctrines should engage player armor instead of detouring to supplies")
	_expect(bool(game.call("_enemy_should_engage_player", true, 500.0, 20.0, "balanced", true)), "Active landing support must override supply detours and engage its assigned target")
	game.get("supply_points").clear()
	game.get("supply_points").append({"pos": Vector2(500.0, 300.0), "owner": "enemy", "kind": "supply", "payout": 0.0, "supply_payout": 0.0})
	game.get("units").clear()
	game.get("units").append({"pos": Vector2(400.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150})
	game.get("units").append({"pos": Vector2(650.0, 300.0), "team": "enemy", "kind": "infantry", "hp": 60})
	game.get("units").append({"pos": Vector2(540.0, 300.0), "team": "player", "kind": "tank", "hp": 150})
	_expect(int(game.call("_enemy_supply_reinforcement_point", 0)) == 0, "Nearest enemy guard should be assigned to reinforce a threatened owned supply point")
	_expect(int(game.call("_enemy_supply_reinforcement_point", 1)) == -1, "A second enemy unit should not duplicate the same supply reinforcement assignment")
	game.get("units").append({"pos": Vector2(500.0, 300.0), "team": "enemy", "kind": "infantry", "hp": 60})
	_expect(int(game.call("_enemy_supply_reinforcement_point", 0)) == -1, "An already garrisoned supply point should not request another reinforcement")

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
	# A second AI decision while the replacement is still under construction
	# must not purchase and place another copy of the same structure.
	game.call("_enemy_ai_turn")
	var barracks_in_progress_count := 0
	for structure in game.get("enemy_buildings"):
		if String(structure.get("kind", "")) == "barracks" and int(structure.get("hp", 0)) > 0:
			barracks_in_progress_count += 1
	_expect(barracks_in_progress_count == 1, "Enemy AI must not queue duplicate barracks while one is under construction")
	_expect(not game.call("_enemy_has_building", "barracks"), "Enemy barracks must remain unavailable until the single replacement finishes")
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
	game.get("enemy_buildings").append({"kind": "barracks", "pos": Vector2(100.0, 360.0), "hp": 400, "build_progress": 1.0})
	game.get("units").clear()
	game.get("units").append({"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(120.0, 100.0)})
	_expect(game.call("_enemy_retreat_destination", retreat_origin) == Vector2(100.0, 360.0), "Retreat routing should prefer a farther completed asset when the nearest one is exposed to player fire")
	game.get("units").clear()
	var wounded_tank: Dictionary = {"kind": "tank", "hp": 20, "pos": retreat_origin}
	var is_retreating: bool = game.call("_update_enemy_retreat", wounded_tank, 1.0)
	_expect(is_retreating and bool(wounded_tank.get("retreating", false)), "A critically damaged tank should enter retreat mode")
	_expect(wounded_tank.pos.distance_to(retreat_origin) > 0.0, "A retreating tank should move toward a safe completed asset")
	wounded_tank.pos = retreat_factory_pos + Vector2(40.0, 0.0)
	wounded_tank.hp = 80
	is_retreating = game.call("_update_enemy_retreat", wounded_tank, 1.0)
	_expect(not is_retreating and int(wounded_tank.hp) == 90, "A tank should recover ten health and exit retreat mode at 60 percent")
	is_retreating = game.call("_update_enemy_retreat", wounded_tank, 1.0)
	_expect(not is_retreating and not wounded_tank.has("retreating") and int(wounded_tank.hp) >= 90, "A recovered tank should leave retreat mode at 60 percent health")

	# Defensive assignments should hold their post while healthy, then make an emergency withdrawal before destruction.
	var guarded_wounded_tank: Dictionary = {"kind": "tank", "hp": 30, "pos": retreat_origin, "defense_guard": true}
	var guard_retreating: bool = game.call("_update_enemy_retreat", guarded_wounded_tank, 1.0)
	_expect(not guard_retreating and not guarded_wounded_tank.has("retreating"), "A healthy base guard should retain its defensive post")
	guarded_wounded_tank["hp"] = 17
	guard_retreating = game.call("_update_enemy_retreat", guarded_wounded_tank, 1.0)
	_expect(guard_retreating and bool(guarded_wounded_tank.get("retreating", false)), "A critically wounded base guard should retreat instead of fighting to destruction")
	var landing_support_artillery: Dictionary = {"kind": "artillery", "hp": 11, "pos": retreat_origin, "landing_support_active": true, "landing_support_target": 0}
	var support_retreating: bool = game.call("_update_enemy_retreat", landing_support_artillery, 1.0)
	_expect(support_retreating and bool(landing_support_artillery.get("retreating", false)), "Critically wounded landing-support artillery should make an emergency retreat")
	_expect(not landing_support_artillery.has("landing_support_target"), "Emergency retreat should clear the stale landing-support target")

	# Verify that each adaptive strategy can order its intended counter-unit.
	game.get("enemy_buildings").clear()
	game.get("enemy_buildings").append({"kind": "airfield", "pos": game.get("enemy_base"), "hp": 450, "build_progress": 1.0})
	game.get("enemy_buildings").append({"kind": "factory", "pos": game.get("enemy_base") + Vector2(-100, 0), "hp": 500, "build_progress": 1.0})
	game.get("enemy_buildings").append({"kind": "shipyard", "pos": Vector2(game.get("enemy_base").x - 120.0, 590.0), "hp": 500, "build_progress": 1.0})
	game.get("enemy_buildings").append({"kind": "power_plant", "pos": game.get("enemy_base") + Vector2(-220.0, 160.0), "hp": 400, "build_progress": 1.0})
	game.set("enemy_credits", 10000)
	game.set("enemy_supplies", 100)
	var counter_cases := [
		["air_control", "fighter"],
		["armor_breaker", "helicopter"],
		["area_denial", "artillery"],
		
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
		
		["armor_breaker", "helicopter", "tank", 3],
		["area_denial", "artillery", "infantry", 5]
	]
	for adaptive_case in adaptive_cases:
		game.get("units").clear()
		game.set("enemy_strategy", "balanced")
		game.set("enemy_credits", 10000)
		game.set("enemy_supplies", 100)
		game.get("enemy_buildings").clear()
		var completed_kinds := ["barracks", "factory", "turret", "airfield", "missile_silo", "missile_defense", "shipyard", "anti_air", "power_plant", "power_plant"]
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



	# Enemy repairs only substantial damage, only on completed living structures,
	# and preserves a small reserve for unit production.
	game.get("enemy_buildings").clear()
	game.set("enemy_credits", 1000)
	game.get("enemy_buildings").append({
		"kind": "factory",
		"pos": game.get("enemy_base") + Vector2(-100.0, 40.0),
		"hp": 300,
		"build_progress": 1.0
	})
	var repair_before := int(game.get("enemy_credits"))
	_expect(bool(game.call("_enemy_repair_damaged_building")), "Enemy AI should repair a completed factory after substantial damage")
	_expect(int(game.get("enemy_buildings")[0].get("hp", 0)) == 500, "Enemy repair should restore the factory to its maximum health")
	_expect(int(game.get("enemy_credits")) < repair_before, "Enemy repair should deduct its proportional resource cost")
	var repaired_credits := int(game.get("enemy_credits"))
	_expect(not bool(game.call("_enemy_repair_damaged_building")), "Enemy AI should not pay to repair a healthy factory")
	_expect(int(game.get("enemy_credits")) == repaired_credits, "A healthy structure should not consume enemy resources")
	game.get("enemy_buildings")[0]["hp"] = 390
	game.get("enemy_buildings")[0]["build_progress"] = 0.5
	_expect(not bool(game.call("_enemy_repair_damaged_building")), "Enemy AI must not repair a structure still under construction")
	game.get("enemy_buildings")[0]["build_progress"] = 1.0
	game.get("enemy_buildings")[0]["hp"] = 100
	game.set("enemy_credits", 1)
	_expect(not bool(game.call("_enemy_repair_damaged_building")), "Enemy AI must not spend resources it cannot afford or drain its production reserve")
	_expect(int(game.get("enemy_buildings")[0].get("hp", 0)) == 100, "Unaffordable repairs must leave structure health unchanged")

	# A major air threat should trigger urgent anti-air construction before
	# optional base expansion, and an unfinished defense must count toward the cap.
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	game.set("enemy_strategy", "balanced")
	game.set("enemy_credits", 10000)
	game.set("enemy_supplies", 100)
	game.get("enemy_buildings").append({
		"kind": "anti_air",
		"pos": game.get("enemy_base") + Vector2(-120.0, 0.0),
		"hp": 380,
		"build_progress": 1.0
	})
	for air_index in range(3):
		game.get("units").append({
			"pos": Vector2(900.0 + float(air_index) * 24.0, 260.0),
			"team": "player",
			"kind": "fighter",
			"hp": 120
		})
	game.call("_enemy_ai_turn")
	_expect(String(game.get("enemy_strategy")) == "air_control", "Enemy AI should switch to air-control doctrine as soon as a major air threat appears")
	var urgent_anti_air_count := 0
	for defense in game.get("enemy_buildings"):
		if String(defense.get("kind", "")) == "anti_air" and int(defense.get("hp", 1)) > 0:
			urgent_anti_air_count += 1
	_expect(urgent_anti_air_count == 2, "Enemy AI should build its second anti-air defense immediately against a major air threat")
	_expect(float(game.get("enemy_buildings")[-1].get("build_progress", 1.0)) == 0.0, "Urgent anti-air defense should enter normal construction")
	game.call("_enemy_ai_turn")
	urgent_anti_air_count = 0
	for defense in game.get("enemy_buildings"):
		if String(defense.get("kind", "")) == "anti_air" and int(defense.get("hp", 1)) > 0:
			urgent_anti_air_count += 1
	_expect(urgent_anti_air_count == 2, "Enemy AI must count unfinished anti-air defenses and avoid building a third duplicate")

	# Verify that the enemy changes doctrine as the player's battlefield composition evolves.
	game.get("units").clear()
	game.set("enemy_strategy", "balanced")
	game.set("enemy_credits", 10000)
	game.set("enemy_supplies", 100)
	game.get("enemy_buildings").clear()
	for structure_kind in ["barracks", "factory", "turret", "airfield", "missile_silo", "missile_defense", "shipyard", "anti_air", "power_plant", "power_plant"]:
		var doctrine_building_pos: Vector2 = game.get("enemy_base") + Vector2(-140.0, 120.0 + float(game.get("enemy_buildings").size()) * 28.0)
		if structure_kind == "shipyard":
			doctrine_building_pos = Vector2(game.get("enemy_base").x - 120.0, 590.0)
		game.get("enemy_buildings").append({"kind": structure_kind, "pos": doctrine_building_pos, "hp": 500, "build_progress": 1.0})
	for threat_index in range(3):
		game.get("units").append({"pos": Vector2(900.0 + float(threat_index) * 20.0, 360.0), "team": "player", "kind": "tank", "hp": 150})
	game.call("_enemy_ai_turn")
	_expect(String(game.get("enemy_strategy")) == "armor_breaker", "Enemy AI should switch to armor breaker when heavy armor dominates the battlefield")
	game.get("units").append({"pos": Vector2(900.0, 260.0), "team": "player", "kind": "fighter", "hp": 120})
	game.get("units").append({"pos": Vector2(920.0, 260.0), "team": "player", "kind": "fighter", "hp": 120})
	game.get("units").append({"pos": Vector2(940.0, 260.0), "team": "player", "kind": "fighter", "hp": 120})
	game.call("_enemy_ai_turn")
	_expect(String(game.get("enemy_strategy")) == "air_control", "Enemy AI should reprioritize air control when the player's air threat overtakes heavy armor")
	if bool(game.get_script().get_script_constant_map().get("NAVAL_SYSTEM_ENABLED", false)):
		game.get("units").clear()
		game.get("units").append({"pos": Vector2(900.0, 360.0), "team": "player", "kind": "destroyer", "hp": 260})
		game.get("units").append({"pos": Vector2(920.0, 360.0), "team": "player", "kind": "submarine", "hp": 210})
		game.call("_enemy_ai_turn")
		_expect(String(game.get("enemy_strategy")) == "naval_control", "Enemy AI should switch to naval control when the player fields a naval force")
	game.get("units").clear()
	for threat_index in range(5):
		game.get("units").append({"pos": Vector2(900.0 + float(threat_index) * 18.0, 360.0), "team": "player", "kind": "infantry", "hp": 60})
	game.call("_enemy_ai_turn")
	_expect(String(game.get("enemy_strategy")) == "area_denial", "Enemy AI should use area denial against massed infantry")
	game.get("units").clear()
	game.call("_enemy_ai_turn")
	_expect(String(game.get("enemy_strategy")) == "balanced", "Enemy AI should return to a balanced doctrine after the specialist threat disappears")

	# Counter production must never spend credits or supplies the enemy does not have.
	game.get("units").clear()
	game.set("enemy_credits", 10)
	game.set("enemy_supplies", 0)
	var units_before_unaffordable_order: int = game.get("units").size()
	var credits_before_unaffordable_order: int = int(game.get("enemy_credits"))
	var supplies_before_unaffordable_order: int = int(game.get("enemy_supplies"))
	var unaffordable_order: bool = game.call("_enemy_counter_production", "air_control", 0, 0, 0, 0)
	_expect(not unaffordable_order, "Enemy AI should reject a counter-unit order when resources are insufficient")
	_expect(game.get("units").size() == units_before_unaffordable_order, "Rejected counter production must not create a free unit")
	_expect(int(game.get("enemy_credits")) == credits_before_unaffordable_order and int(game.get("enemy_supplies")) == supplies_before_unaffordable_order, "Rejected counter production must preserve the enemy's remaining resources")

	# Stress the enemy's production budget across repeated AI turns with scarce supplies.
	game.get("units").clear()
	game.set("enemy_strategy", "balanced")
	game.set("enemy_credits", 2000)
	game.set("enemy_supplies", 4)
	for threat_index in range(5):
		game.get("units").append({
			"pos": Vector2(900.0 + float(threat_index) * 18.0, 360.0),
			"team": "player", "kind": "infantry", "hp": 60
		})
	for ai_turn_index in range(20):
		game.call("_enemy_ai_turn")
	_expect(int(game.get("enemy_credits")) >= 0, "Repeated enemy AI turns must never drive credits below zero")
	_expect(int(game.get("enemy_supplies")) >= 0, "Repeated enemy AI turns must never drive supplies below zero")
	var stress_artillery_count := 0
	var stress_infantry_count := 0
	for stress_unit in game.get("units"):
		if String(stress_unit.get("team", "")) != "enemy":
			continue
		if String(stress_unit.get("kind", "")) == "artillery":
			stress_artillery_count += 1
		elif String(stress_unit.get("kind", "")) == "infantry":
			stress_infantry_count += 1
	_expect(stress_artillery_count <= 3, "Repeated area-denial turns must respect the artillery counter-unit cap")
	_expect(stress_infantry_count <= 8, "Repeated enemy production must respect the infantry force cap")

	# Run the live match loop long enough for three scheduled enemy AI turns.
	game.set("faction", "الصيني")
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_credits", 5000)
	game.set("enemy_supplies", 100)
	game.set("enemy_strategy", "balanced")
	game.set("enemy_base_hp", 1000)
	game.set("player_base_hp", 1000)
	game.get("enemy_buildings").clear()
	for ai_structure_kind in ["barracks", "factory", "turret", "airfield", "missile_silo", "missile_defense", "shipyard", "anti_air", "power_plant", "power_plant"]:
		game.get("enemy_buildings").append({
			"kind": ai_structure_kind,
			"pos": game.get("enemy_base") + Vector2(-100.0, float(game.get("enemy_buildings").size()) * 65.0 - 220.0),
			"hp": 500, "build_progress": 1.0
		})
	game.get("units").clear()
	for live_threat_index in range(3):
		game.get("units").append({
			"kind": "tank", "team": "player", "faction": "الصيني",
			"hp": 150, "pos": Vector2(70.0 + float(live_threat_index) * 35.0, 650.0),
			"attack_cd": 10.0
		})
	# Observe the first scheduled strategic decision before enemy counters can destroy the test threat.
	for live_ai_frame in range(121):
		game.call("_process", 0.1)
	_expect(String(game.get("enemy_strategy")) == "armor_breaker", "The first live enemy AI turn should choose armor-breaker against three active player tanks")
	for later_ai_frame in range(259):
		game.call("_process", 0.1)
	var live_counter_helicopters := 0
	for live_ai_unit in game.get("units"):
		if String(live_ai_unit.get("team", "")) == "enemy" and String(live_ai_unit.get("kind", "")) == "helicopter":
			live_counter_helicopters += 1
	_expect(live_counter_helicopters >= 1, "Live enemy AI should field helicopter counters during a sustained tank-threat match")
	_expect(int(game.get("enemy_credits")) >= 0 and int(game.get("enemy_supplies")) >= 0, "Live enemy AI turns must preserve non-negative resource balances")

	# Guard the four faction profiles and the premium cost of the strongest "Watan" units.
	var faction_cases := [
		["الصيني", 30, 1.35, 185, 14.0, 40],
		["الأمريكي", 32, 1.25, 195, 13.0, 44],
		["الجيش العربي", 34, 1.20, 205, 12.0, 42],
		["وطن", 38, 1.10, 230, 11.0, 50]
	]
	_expect(expected_factions.size() == 4, "The game should expose exactly four player-facing factions")
	_expect(not expected_factions.has("GLA"), "Legacy GLA naming must not appear in player-facing faction selection")
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
	game.get("units").append({"kind": "artillery", "team": "enemy", "hp": 180, "pos": Vector2(510.0, 300.0), "attack_cd": 0.0})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 62, "Enemy artillery infantry splash damage mismatch: hp=%d" % int(game.get("units")[0]["hp"]))
	_expect(int(game.get("units")[1]["hp"]) == 102, "Enemy artillery tank splash damage mismatch: hp=%d" % int(game.get("units")[1]["hp"]))

	game.get("units").clear()
	game.get("units").append({"kind": "tank", "team": "player", "hp": 150, "pos": Vector2(400.0, 300.0), "attack_target": 1, "attack_cd": 0.0})
	game.get("units").append({"kind": "infantry", "team": "enemy", "hp": 100, "pos": Vector2(420.0, 300.0), "attack_cd": 10.0})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[1]["hp"]) == 76, "Player tank should apply the 24-point rear-aspect penetration hit to infantry")

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
		"hp": 120, "pos": Vector2(500.0, 300.0), "attack_cd": 0.0, "attack_target": 1, "attack_focus_pos": Vector2(520.0, 300.0)
	})
	game.get("units").append({
		"kind": "fighter", "team": "enemy", "faction": "الصيني",
		"hp": 120, "pos": Vector2(520.0, 300.0), "attack_cd": 0.0, "attack_target": 0, "attack_focus_pos": Vector2(500.0, 300.0)
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 90, "Enemy fighter should return fire for 30 damage in an air-to-air engagement")
	_expect(int(game.get("units")[1]["hp"]) == 90, "Player fighter damage mismatch: units=%s" % str(game.get("units")))
	_expect(is_equal_approx(float(game.get("units")[0]["attack_cd"]), 1.35), "Player fighter cooldown mismatch: units=%s" % str(game.get("units")))

	# Verify faction-specific helicopter damage and cooldown through live combat.
	game.get("units").clear()
	game.get("units").append({
		"kind": "tank", "team": "enemy", "hp": 150,
		"pos": Vector2(420.0, 300.0), "attack_cd": 10.0
	})
	game.get("units").append({
		"kind": "helicopter", "team": "player", "faction": "الصيني",
		"hp": 160, "pos": Vector2(400.0, 300.0), "attack_cd": 0.0, "attack_target": 0, "attack_focus_pos": Vector2(420.0, 300.0)
	})
	game.call("_process", 0.1)
	_expect(int(game.get("units")[0]["hp"]) == 120, "Chinese helicopter damage mismatch: units=%s" % str(game.get("units")))
	_expect(is_equal_approx(float(game.get("units")[1]["attack_cd"]), 1.35), "Chinese helicopter cooldown mismatch: units=%s" % str(game.get("units")))

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

	# Naval gameplay is feature-gated off for the land-and-air release.
	if bool(game.get_script().get_script_constant_map().get("NAVAL_SYSTEM_ENABLED", false)):
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
	
		# Enemy naval base damage must use the ship owner's faction, not the player's faction.
		game.set("faction", "وطن")
		game.get("units").clear()
		game.get("units").append({
			"kind": "destroyer", "team": "enemy", "faction": "الصيني",
			"hp": 260, "pos": Vector2(500.0, 300.0), "attack_cd": 0.0
		})
		game.get("units").append({
			"kind": "carrier", "team": "player", "faction": "وطن",
			"hp": 520, "pos": Vector2(520.0, 300.0), "attack_cd": 0.0
		})
		game.call("_process", 0.1)
		_expect(int(game.get("units")[1]["hp"]) == 480, "Chinese enemy destroyer should use its own 40-point naval profile, not the player's Watan 50")
		_expect(int(game.get("units")[0]["hp"]) == 236, "Player carrier should retain its 24-point role-specific naval strike")
	
	
	# Run a sustained live battle to verify destroyed-unit cleanup and target/selection remapping.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_credits", 0)
	game.set("enemy_income_timer", 0.0)
	game.set("credits", 0)
	game.set("income_timer", 0.0)
	game.set("player_base_hp", 1000)
	game.set("enemy_base_hp", 1000)
	game.get("supply_points").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("missiles").clear()
	game.get("production_orders").clear()
	game.get("visual_effects").clear()
	game.get("environment_particles").clear()
	game.get("units").clear()
	game.get("units").append({
		"kind": "tank", "team": "player", "hp": 150,
		"pos": Vector2(500.0, 300.0), "attack_target": 1, "attack_cd": 0.0
	})
	game.get("units").append({
		"kind": "infantry", "team": "enemy", "hp": 60,
		"pos": Vector2(520.0, 300.0), "attack_cd": 0.0
	})
	game.get("selected").clear()
	game.get("selected").append(0)
	game.get("selected").append(1)
	for battle_frame in range(180):
		game.call("_process", 0.1)
	_expect(game.get("units").size() == 1, "A sustained 18-second battle should remove the destroyed enemy unit without retaining stale entries")
	_expect(String(game.get("units")[0].get("team", "")) == "player" and int(game.get("units")[0].get("hp", 0)) > 0, "The surviving player tank should remain valid after the long battle")
	_expect(not game.get("units")[0].has("attack_target"), "The surviving tank must not retain an attack index for a destroyed enemy")
	_expect(game.get("selected").size() == 1 and int(game.get("selected")[0]) == 0, "Long-battle cleanup should preserve the surviving selection and discard destroyed selections")
	for active_unit in game.get("units"):
		_expect(int(active_unit.get("hp", 0)) > 0, "No destroyed unit may remain in the active array after a long battle")

	# Verify the real enemy unit update path retreats, heals, and rejoins after recovery.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	# Keep the AI turn from reassigning this wounded test tank as a base guard before retreat is exercised.
	game.set("enemy_timer", 0.0)
	game.set("enemy_missile_timer", 999.0)
	game.set("enemy_income_timer", 999.0)
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	var live_retreat_factory := Vector2(260.0, 180.0)
	game.get("enemy_buildings").append({"kind": "factory", "pos": live_retreat_factory, "hp": 500, "build_progress": 1.0})
	game.get("units").append({
		"kind": "tank", "team": "enemy", "faction": "الصيني",
		"hp": 20, "pos": live_retreat_factory + Vector2(40.0, 0.0), "attack_cd": 10.0
	})
	game.call("_process", 1.0)
	_expect(bool(game.get("units")[0].get("retreating", false)), "Live enemy tank update should enter retreat mode when critically damaged")
	_expect(int(game.get("units")[0]["hp"]) == 30, "Live retreat should heal the tank by ten health per second beside a completed factory")
	for recovery_frame in range(8):
		game.call("_process", 1.0)
	_expect(int(game.get("units")[0]["hp"]) >= 90, "Live retreat should recover the tank to at least 60 percent health")
	_expect(not game.get("units")[0].has("retreating"), "Recovered enemy tank should leave retreat mode and rejoin normal unit updates")

	if bool(game.get_script().get_script_constant_map().get("NAVAL_SYSTEM_ENABLED", false)):
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
	
	
	# Ground assault target selection should distribute attackers by local threat and distance.
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	game.set("enemy_base", Vector2(900.0, 400.0))
	game.get("units").append({"pos": Vector2(180.0, 260.0), "team": "player", "kind": "tank", "hp": 150})
	game.get("units").append({"pos": Vector2(820.0, 260.0), "team": "player", "kind": "artillery", "hp": 100})
	_expect(int(game.call("_select_enemy_ground_assault_target", Vector2(200.0, 260.0))) == 0, "Left assault group should select its nearby ground threat")
	_expect(int(game.call("_select_enemy_ground_assault_target", Vector2(800.0, 260.0))) == 1, "Right assault group should select its own nearby ground threat")
	_expect(int(game.call("_select_enemy_ground_assault_target", Vector2(500.0, 260.0))) >= 0, "Ground assault target selection should remain valid for units between threats")

	# Infantry should follow an active assault tank as a screening/support element.
	game.get("units").clear()
	game.get("units").append({"pos": Vector2(700.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150})
	game.get("units").append({"pos": Vector2(650.0, 330.0), "team": "enemy", "kind": "infantry", "hp": 60})
	var infantry_support_pos: Vector2 = game.call("_enemy_infantry_support_position", Vector2(650.0, 330.0), Vector2(900.0, 300.0), Vector2(100.0, 300.0), 1)
	_expect(infantry_support_pos.x < 700.0 and absf(infantry_support_pos.y - 326.0) < 1.0, "Infantry should take a staggered support position behind its advancing tank")
	game.get("units")[0]["defense_guard"] = true
	var fallback_support_pos: Vector2 = game.call("_enemy_infantry_support_position", Vector2(650.0, 330.0), Vector2(900.0, 300.0), Vector2(100.0, 300.0), 1)
	_expect(fallback_support_pos != infantry_support_pos, "Infantry should ignore defensive tanks when selecting an assault escort")

	# Offensive artillery support lanes must remain distinct as the battery grows.
	var artillery_lane_a: Vector2 = game.call("_enemy_artillery_support_position", Vector2(500.0, 300.0), Vector2(900.0, 300.0), 0)
	var artillery_lane_b: Vector2 = game.call("_enemy_artillery_support_position", Vector2(500.0, 300.0), Vector2(900.0, 300.0), 1)
	var artillery_lane_c: Vector2 = game.call("_enemy_artillery_support_position", Vector2(500.0, 300.0), Vector2(900.0, 300.0), 2)
	_expect(artillery_lane_a.distance_to(artillery_lane_b) >= 70.0, "First and second artillery units should occupy separate support lanes")
	_expect(artillery_lane_a.distance_to(artillery_lane_c) >= 70.0, "Third artillery unit must not overlap the first support lane")
	_expect(bool(game.call("_enemy_artillery_in_firing_band", artillery_lane_c.distance_to(Vector2(500.0, 300.0)))), "Expanded artillery support lanes should remain inside the firing envelope")

	# Ground assault target hysteresis should prevent minor score changes from switching a squad's focus.
	game.get("units").clear()
	game.get("enemy_buildings").clear()
	game.set("enemy_base", Vector2(900.0, 400.0))
	game.get("units").append({"pos": Vector2(500.0, 400.0), "team": "player", "kind": "tank", "hp": 150})
	game.get("units").append({"pos": Vector2(500.0, 400.0), "team": "player", "kind": "artillery", "hp": 100})
	_expect(int(game.call("_select_enemy_ground_assault_target", Vector2(500.0, 400.0), Vector2(500.0, 400.0))) == 0, "Ground assault should retain its current target when a new threat is only marginally better")
	_expect(int(game.call("_select_enemy_ground_assault_target", Vector2(500.0, 400.0), Vector2(-1000000.0, -1000000.0))) == 1, "Ground assault should select the higher-priority artillery threat when no valid target lock exists")

	# Formation slots must be isolated from defensive guards and landing-support attachments.
	game.get("units").clear()
	game.get("units").append({"pos": Vector2(760.0, 320.0), "team": "enemy", "kind": "tank", "hp": 150})
	game.get("units").append({"pos": Vector2(780.0, 340.0), "team": "enemy", "kind": "infantry", "hp": 60, "defense_guard": true})
	game.get("units").append({"pos": Vector2(800.0, 360.0), "team": "enemy", "kind": "artillery", "hp": 100, "landing_support_active": true})
	game.get("units").append({"pos": Vector2(820.0, 380.0), "team": "enemy", "kind": "tank", "hp": 150})
	_expect(int(game.call("_enemy_assault_formation_rank", 3)) == 1, "Defensive guards and landing-support units must not consume assault formation slots")
	game.get("units").append({"pos": Vector2(840.0, 400.0), "team": "enemy", "kind": "artillery", "hp": 100})
	_expect(int(game.call("_enemy_artillery_formation_rank", 4)) == 0, "Landing-support artillery must not consume offensive fire-support slots")
	game.get("units").append({"pos": Vector2(860.0, 420.0), "team": "enemy", "kind": "artillery", "hp": 100, "defense_guard": true})
	game.get("units").append({"pos": Vector2(880.0, 440.0), "team": "enemy", "kind": "artillery", "hp": 100})
	_expect(int(game.call("_enemy_artillery_formation_rank", 6)) == 1, "Defensive artillery must not distort offensive artillery spacing")

	# Run a coordinated ground assault through the real frame update, not only helper calls.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 999.0)
	game.set("enemy_missile_timer", 999.0)
	game.set("enemy_income_timer", 999.0)
	game.set("enemy_base", Vector2(100.0, 300.0))
	game.get("enemy_buildings").clear()
	game.get("supply_points").clear()
	game.get("units").clear()
	game.get("units").append({"pos": Vector2(360.0, 300.0), "team": "enemy", "kind": "tank", "hp": 150, "attack_cd": 10.0})
	game.get("units").append({"pos": Vector2(350.0, 330.0), "team": "enemy", "kind": "infantry", "hp": 60, "attack_cd": 10.0})
	game.get("units").append({"pos": Vector2(280.0, 260.0), "team": "enemy", "kind": "artillery", "hp": 100, "attack_cd": 10.0})
	game.get("units").append({"pos": Vector2(520.0, 300.0), "team": "player", "kind": "tank", "hp": 150, "attack_cd": 10.0})
	var artillery_initial_position: Vector2 = game.get("units")[2].pos
	game.call("_process", 1.0)
	var coordinated_tank: Dictionary = game.get("units")[0]
	var coordinated_infantry: Dictionary = game.get("units")[1]
	var coordinated_artillery: Dictionary = game.get("units")[2]
	var coordinated_target: Vector2 = game.get("units")[3].pos
	_expect(coordinated_tank.pos.x > 360.0, "Live ground assault should advance its tank toward the selected frontline threat")
	_expect(coordinated_infantry.pos.x < coordinated_tank.pos.x, "Live infantry should remain behind its advancing armor as a support screen")
	_expect(coordinated_artillery.pos.distance_to(coordinated_target) >= 185.0 and coordinated_artillery.pos.distance_to(coordinated_target) <= 330.0, "Live assault artillery should preserve its protected firing envelope")
	_expect(coordinated_artillery.pos.distance_to(artillery_initial_position) < 0.1, "Artillery already inside its firing envelope should not rush into the frontline")
	for assault_index in range(3):
		game.call("_update_enemy_ground_assault", game.get("units")[assault_index], assault_index, 0.0)
		var assault_focus: Vector2 = game.get("units")[assault_index].get("attack_focus_pos", Vector2(-1000000.0, -1000000.0))
		_expect(assault_focus.distance_to(coordinated_target) < 0.1, "Assault role %d focus mismatch: focus=%s target=%s" % [assault_index, str(assault_focus), str(coordinated_target)])

	# Faction balance contract: preserve each army's intended economic and combat identity.
	var faction_names: Array[String] = ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
	for army_name in faction_names:
		var profile: Dictionary = game.call("_faction_profile", army_name)
		_expect(profile.has("unit_costs") and profile.has("helicopter_damage") and profile.has("missile_damage") and profile.has("naval_damage"), "%s must define a complete faction balance profile" % army_name)
		_expect(int(game.call("_unit_cost", "tank", army_name)) > 0 and int(game.call("_unit_cost", "infantry", army_name)) > 0, "%s must have valid ground unit costs" % army_name)
		_expect(float(profile.get("helicopter_cooldown", 0.0)) > 0.0, "%s helicopter cooldown must be positive" % army_name)
	_expect(int(game.call("_unit_cost", "tank", "الصيني")) < int(game.call("_unit_cost", "tank", "الأمريكي")), "Chinese armor should retain its economy advantage")
	_expect(int(game.call("_unit_cost", "infantry", "الجيش العربي")) < int(game.call("_unit_cost", "infantry", "الأمريكي")), "Arab infantry should retain its affordability advantage")
	_expect(int(game.call("_unit_cost", "artillery", "الجيش العربي")) < int(game.call("_unit_cost", "artillery", "الأمريكي")), "Arab artillery should retain its affordability advantage")
	_expect(int(game.call("_unit_cost", "tank", "وطن")) > int(game.call("_unit_cost", "tank", "الأمريكي")), "Watan elite armor should carry a resource premium")
	_expect(int(game.call("_unit_cost", "fighter", "وطن")) > int(game.call("_unit_cost", "fighter", "الأمريكي")), "Watan elite air units should carry a resource premium")
	var watan_helicopter: Dictionary = {"faction": "وطن"}
	var american_helicopter: Dictionary = {"faction": "الأمريكي"}
	_expect(int(game.call("_helicopter_damage", watan_helicopter)) > int(game.call("_helicopter_damage", american_helicopter)), "Watan helicopter should retain elite damage")
	_expect(float(game.call("_helicopter_cooldown", watan_helicopter)) < float(game.call("_helicopter_cooldown", american_helicopter)), "Watan helicopter should retain its faster firing cycle")
	_expect(int(game.call("_naval_damage", {"kind": "destroyer", "faction": "وطن"}, -1)) > int(game.call("_naval_damage", {"kind": "destroyer", "faction": "الأمريكي"}, -1)), "Watan naval forces should retain their damage advantage")

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

	# Full match lifecycle: resolve a player victory through live helicopter combat.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("supply_points").clear()
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_timer", 0.0)
	game.set("enemy_income_timer", 0.0)
	game.set("income_timer", 0.0)
	game.set("enemy_base_hp", 1)
	game.set("player_base_hp", 500)
	game.get("units").append({"pos": game.get("enemy_base") + Vector2(120.0, 0.0), "team": "player", "kind": "helicopter", "faction": game.get("faction"), "hp": 180, "attack_cd": 0.0, "attack_base": true})
	game.call("_process", 0.1)
	_expect(String(game.get("battle_result")).contains("انتصرت"), "A live player helicopter strike that destroys the enemy base should resolve a victory")

	# Reset the same match state and verify the enemy can win through artillery fire.
	game.set("battle_result", "")
	game.set("enemy_base_hp", 500)
	game.set("player_base_hp", 1)
	game.get("units").clear()
	game.get("units").append({"pos": game.get("base_pos") + Vector2(250.0, 0.0), "team": "enemy", "kind": "artillery", "hp": 100, "attack_cd": 0.0})
	game.call("_process", 0.1)
	_expect(String(game.get("battle_result")).contains("هُزمت"), "Enemy artillery destroying the player base should resolve a defeat")

	# Run supply capture and ownership changes through the real frame loop, not direct helper calls.
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("player_base_hp", 1000)
	game.set("enemy_base_hp", 1000)
	game.set("faction", "الأمريكي")
	game.set("credits", 100)
	game.set("supplies", 0)
	game.set("income_timer", 0.0)
	game.set("enemy_credits", 100)
	game.set("enemy_supplies", 0)
	game.set("enemy_income_timer", 0.0)
	game.set("enemy_timer", 0.0)
	game.set("enemy_missile_timer", 999.0)
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("production_orders").clear()
	game.get("units").clear()
	game.get("supply_points").clear()
	var live_supply_position := Vector2(640.0, 360.0)
	game.get("supply_points").append({"pos": live_supply_position, "owner": "neutral", "kind": "port", "payout": 0.0, "supply_payout": 0.0})
	game.get("units").append({"kind": "infantry", "team": "player", "faction": "الأمريكي", "hp": 60, "pos": live_supply_position, "attack_cd": 10.0})
	for supply_frame in range(80):
		game.call("_process", 0.1)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "player", "Live match loop should capture a neutral port for uncontested player infantry")
	_expect(int(game.get("credits")) >= 190, "Live match loop should combine passive income and repeated port payouts after the capture frame")
	_expect(int(game.get("supplies")) >= 1, "Live match loop should deliver the port's six-second supply payout")
	var player_income_before_contest := int(game.get("credits"))
	game.get("units").append({"kind": "infantry", "team": "enemy", "faction": "الصيني", "hp": 60, "pos": live_supply_position, "attack_cd": 10.0})
	for contest_frame in range(10):
		game.call("_process", 0.1)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "player", "A contested point should retain its last owner while stopping its payout")
	_expect(int(game.get("credits")) - player_income_before_contest <= 7, "Contested port must stop paying its owner while passive income continues")
	game.get("units")[0]["hp"] = 0
	var enemy_income_before_capture := int(game.get("enemy_credits"))
	for capture_frame in range(11):
		game.call("_process", 0.1)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "enemy", "Live match loop should transfer the port after enemy forces become uncontested")
	_expect(int(game.get("enemy_credits")) >= enemy_income_before_capture + 13, "Enemy should receive passive income and the captured port payout through the live loop")
	var enemy_income_before_recapture := int(game.get("enemy_credits"))
	game.get("units")[0]["hp"] = 0
	game.get("units").append({"kind": "tank", "team": "player", "faction": "الأمريكي", "hp": 150, "pos": live_supply_position, "attack_cd": 10.0})
	for recapture_frame in range(11):
		game.call("_process", 0.1)
	_expect(String(game.get("supply_points")[0].get("owner", "")) == "player", "Player armor should recapture the port through the live match loop")
	_expect(int(game.get("enemy_credits")) - enemy_income_before_recapture <= 7, "Enemy should stop receiving port income after player recapture")

	# Live enemy behavior: balanced forces should move toward valuable supply when combat is distant, then engage an immediate nearby threat.
	game.get("units").clear()
	game.get("supply_points").clear()
	game.get("supply_points").append({"pos": Vector2(500.0, 360.0), "owner": "player", "kind": "port", "payout": 0.0, "supply_payout": 0.0})
	game.get("units").append({"kind": "tank", "team": "enemy", "faction": "الصيني", "hp": 150, "pos": Vector2(800.0, 360.0), "attack_cd": 0.0})
	game.get("units").append({"kind": "infantry", "team": "player", "faction": "الأمريكي", "hp": 60, "pos": Vector2(100.0, 360.0), "attack_cd": 10.0})
	game.set("enemy_strategy", "balanced")
	game.set("enemy_timer", 999.0)
	var enemy_start_x: float = game.get("units")[0]["pos"].x
	for objective_frame in range(20):
		game.call("_update_enemy_ground_assault", game.get("units")[0], 0, 0.1)
	_expect(float(game.get("units")[0]["pos"].x) < enemy_start_x - 10.0, "Balanced enemy armor should advance toward a nearby player-held port when the player threat is distant")
	# Remove the distant infantry and use the aggressive doctrine to verify the live combat damage path independently of the balanced-priority helper tests.
	game.get("units").remove_at(1)
	# The earlier AI turn may assign the surviving tank to base defense; convert it back to an assault unit for this independent doctrine test.
	game.get("units")[0]["defense_guard"] = false
	game.get("units")[0].erase("defense_anchor")
	game.set("enemy_strategy", "armor_breaker")
	game.set("enemy_timer", 0.0)
	game.set("enemy_landing_support_target", -1)
	var nearby_player_index: int = game.get("units").size()
	game.get("units").append({"kind": "tank", "team": "player", "faction": "الأمريكي", "hp": 150, "pos": game.get("units")[0]["pos"] + Vector2(35.0, 0.0), "attack_cd": 10.0})
	var nearby_player_hp: int = int(game.get("units")[nearby_player_index]["hp"])
	var enemy_before_combat: Vector2 = game.get("units")[0]["pos"]
	var enemy_distance_before_combat: float = enemy_before_combat.distance_to(game.get("units")[nearby_player_index]["pos"])
	for combat_frame in range(12):
		game.call("_process", 0.1)
	var enemy_after_combat: Vector2 = game.get("units")[0]["pos"]
	var enemy_distance_after_combat: float = enemy_after_combat.distance_to(game.get("units")[nearby_player_index]["pos"])
	var enemy_damaged_nearby_tank := int(game.get("units")[nearby_player_index]["hp"]) < nearby_player_hp
	var enemy_closed_on_nearby_tank := enemy_distance_after_combat < enemy_distance_before_combat - 1.0
	_expect(enemy_damaged_nearby_tank or enemy_closed_on_nearby_tank, "Enemy armor should engage nearby threat; strategy=%s enemy_before=%s enemy_after=%s player_pos=%s distance_before=%.2f distance_after=%.2f player_hp=%d" % [String(game.get("enemy_strategy")), str(enemy_before_combat), str(enemy_after_combat), str(game.get("units")[nearby_player_index]["pos"]), enemy_distance_before_combat, enemy_distance_after_combat, int(game.get("units")[nearby_player_index]["hp"])])

	# Player group movement should create distinct mixed-unit formation slots.
	game.get("units").clear()
	game.get("buildings").clear()
	game.get("enemy_buildings").clear()
	game.get("supply_points").clear()
	game.set("game_started", true)
	game.set("paused", false)
	game.set("battle_result", "")
	game.set("enemy_base_hp", 1000)
	game.set("player_base_hp", 1000)
	# The preceding UI/campaign scenarios may leave a construction command active.
	# Clear transient input state so this section exercises a ground-move order,
	# not the building-placement early return in _handle_pointer().
	game.set("build_mode", "")
	game.set("dragging", false)
	game.set("selected_enemy_building", -1)
	game.set("selected_player_building", -1)
	var group_records: Array[Dictionary] = [
		{"kind": "artillery", "team": "player", "faction": "الأمريكي", "hp": 100, "pos": Vector2(180.0, 180.0)},
		{"kind": "infantry", "team": "player", "faction": "الأمريكي", "hp": 60, "pos": Vector2(190.0, 190.0)},
		{"kind": "infantry", "team": "player", "faction": "الأمريكي", "hp": 60, "pos": Vector2(200.0, 200.0)},
		{"kind": "tank", "team": "player", "faction": "الأمريكي", "hp": 150, "pos": Vector2(210.0, 210.0)},
		{"kind": "tank", "team": "player", "faction": "الأمريكي", "hp": 150, "pos": Vector2(220.0, 220.0)},
		{"kind": "helicopter", "team": "player", "faction": "الأمريكي", "hp": 160, "pos": Vector2(230.0, 230.0)},
		{"kind": "transport_helicopter", "team": "player", "faction": "الأمريكي", "hp": 220, "pos": Vector2(240.0, 240.0)},
		{"kind": "fighter", "team": "player", "faction": "الأمريكي", "hp": 120, "pos": Vector2(250.0, 250.0)}
	]
	for group_record in group_records:
		game.get("units").append(group_record)
	var group_selection: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	game.set("selected", group_selection)
	var group_destination := Vector2(active_viewport.x * 0.58, clampf(active_viewport.y * 0.72, 240.0, 285.0))
	print("GROUP_MOVE_DIAGNOSTIC viewport=", active_viewport, " destination=", group_destination, " tab_rect=", game.call("_command_tab_rect", 2, active_viewport), " button_rect=", game.call("_button_rect", 0, active_viewport), " mode_rect=", game.call("_transport_ai_mode_rect", active_viewport))
	game.call("_handle_pointer", group_destination, true)
	game.call("_handle_pointer", group_destination, false)
	print("GROUP_MOVE_AFTER selected=", game.get("selected"), " build_mode=", game.get("build_mode"), " dragging=", game.get("dragging"), " notice=", game.get("notice"), " unit_targets=", game.get("units").map(func(unit): return {"kind": unit.get("kind", ""), "target": unit.get("target", null), "pos": unit.get("pos", Vector2.ZERO), "transport_pending": unit.get("transport_order_pending", false)}))
	var group_origin := Vector2.ZERO
	for group_index in group_selection:
		group_origin += game.get("units")[group_index].pos
	group_origin /= float(group_selection.size())
	var group_forward := (group_destination - group_origin).normalized()
	var group_right := Vector2(-group_forward.y, group_forward.x)
	var formation_targets: Array[Vector2] = []
	for group_index in group_selection:
		var group_unit: Dictionary = game.get("units")[group_index]
		var has_group_target := group_unit.has("target")
		_expect(has_group_target, "Every selected unit should receive a formation destination on a ground move")
		var group_target: Vector2 = group_unit.get("target", group_destination)
		if has_group_target:
			_expect(group_target.x >= 24.0 and group_target.x <= 1128.0 and group_target.y >= 24.0 and group_target.y <= 624.0, "Formation destinations should remain inside the battlefield")
		for prior_target in formation_targets:
			_expect(group_target.distance_to(prior_target) > 10.0, "Mixed-unit group movement should not stack selected units on one destination")
		formation_targets.append(group_target)
	var artillery_projection: float = (Vector2(game.get("units")[0].get("target", group_destination)) - group_destination).dot(group_forward)
	var tank_projection: float = (Vector2(game.get("units")[3].get("target", group_destination)) - group_destination).dot(group_forward)
	var helicopter_projection: float = (Vector2(game.get("units")[5].get("target", group_destination)) - group_destination).dot(group_forward)
	var transport_projection: float = (Vector2(game.get("units")[6].get("target", group_destination)) - group_destination).dot(group_forward)
	var infantry_left_lateral: float = (Vector2(game.get("units")[1].get("target", group_destination)) - group_destination).dot(group_right)
	var infantry_right_lateral: float = (Vector2(game.get("units")[2].get("target", group_destination)) - group_destination).dot(group_right)
	_expect(tank_projection > artillery_projection + 20.0, "Tanks should form ahead of artillery in a mixed group move")
	_expect(infantry_left_lateral * infantry_right_lateral < 0.0, "Infantry should spread across opposite flanks of the armor")
	_expect(helicopter_projection > tank_projection and transport_projection > helicopter_projection, "Aircraft and transport should occupy separate forward support lanes")

	# A direct attack click should synchronize the selected group on one enemy target.
	game.get("units").append({"kind": "tank", "team": "enemy", "faction": "الصيني", "hp": 180, "pos": group_destination + Vector2(42.0, 0.0)})
	var group_enemy_index: int = game.get("units").size() - 1
	var group_enemy_position: Vector2 = game.get("units")[group_enemy_index].pos
	game.call("_handle_pointer", group_enemy_position, true)
	game.call("_handle_pointer", group_enemy_position, false)
	for group_index in group_selection:
		var attacking_unit: Dictionary = game.get("units")[group_index]
		_expect(int(attacking_unit.get("attack_target", -1)) == group_enemy_index, "All selected units should receive the same direct attack target")
		_expect(attacking_unit.get("attack_focus_pos", Vector2.ZERO).distance_to(group_enemy_position) < 0.1, "All selected units should preserve the player's chosen attack focus")

	# A fresh move order should clear the old attack and re-form the group at its new destination.
	var second_group_destination := Vector2(active_viewport.x * 0.36, clampf(active_viewport.y * 0.55, 232.0, 278.0))
	game.call("_handle_pointer", second_group_destination, true)
	game.call("_handle_pointer", second_group_destination, false)
	var second_formation_targets: Array[Vector2] = []
	for group_index in group_selection:
		var moving_unit: Dictionary = game.get("units")[group_index]
		_expect(not moving_unit.has("attack_target") and not moving_unit.has("attack_focus_pos"), "A new group move should clear stale attack orders")
		var moving_target: Vector2 = moving_unit.get("target", second_group_destination)
		_expect(moving_unit.has("target"), "Each unit should retain a movement target after a second group move")
		_expect(moving_target.distance_to(second_group_destination) < 180.0, "Each unit should reform around the new group destination")
		for prior_target in second_formation_targets:
			_expect(moving_target.distance_to(prior_target) > 10.0, "A second group move should preserve distinct formation slots")
		second_formation_targets.append(moving_target)

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
