extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const HELICOPTER_HP := 180
const MATCHUPS := [
	[0, 1], [0, 2], [0, 3],
	[1, 2], [1, 3], [2, 3]
]

var failures := 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_cleanup_audio(game)

	var matchup_rows: Array[String] = []
	for pairing in MATCHUPS:
		var left_faction: String = FACTIONS[pairing[0]]
		var right_faction: String = FACTIONS[pairing[1]]
		var left_unit := {"kind": "helicopter", "faction": left_faction, "hp": HELICOPTER_HP}
		var right_unit := {"kind": "helicopter", "faction": right_faction, "hp": HELICOPTER_HP}
		var left_damage: int = int(game.call("_helicopter_damage", left_unit))
		var right_damage: int = int(game.call("_helicopter_damage", right_unit))
		var left_cooldown: float = float(game.call("_helicopter_cooldown", left_unit))
		var right_cooldown: float = float(game.call("_helicopter_cooldown", right_unit))
		_expect(left_damage > 0 and right_damage > 0, "Both factions in a matchup must have positive helicopter damage")
		_expect(left_cooldown > 0.0 and right_cooldown > 0.0, "Both factions in a matchup must have positive helicopter cooldown")

		# First volleys land at t=0; subsequent volleys follow each faction's actual cooldown.
		var left_shots_to_kill: int = int(ceil(float(HELICOPTER_HP) / float(left_damage)))
		var right_shots_to_kill: int = int(ceil(float(HELICOPTER_HP) / float(right_damage)))
		var left_ttk: float = float(left_shots_to_kill - 1) * left_cooldown
		var right_ttk: float = float(right_shots_to_kill - 1) * right_cooldown
		var left_cost: int = int(game.call("_unit_cost", "helicopter", left_faction))
		var right_cost: int = int(game.call("_unit_cost", "helicopter", right_faction))
		_expect(left_cost > 0 and right_cost > 0, "Both factions must have a valid helicopter reinforcement cost")

		var result := "تعادل"
		if left_ttk < right_ttk:
			result = left_faction
		elif right_ttk < left_ttk:
			result = right_faction
		matchup_rows.append("%s × %s | helicopter TTK %.2fs : %.2fs | cost %d : %d | edge %s" % [
			left_faction, right_faction, left_ttk, right_ttk, left_cost, right_cost, result
		])

		var left_missile_damage: int = int(game.call("_missile_damage", left_faction))
		var right_missile_damage: int = int(game.call("_missile_damage", right_faction))
		var left_missile_cooldown: float = float(game.call("_missile_cooldown", left_faction))
		var right_missile_cooldown: float = float(game.call("_missile_cooldown", right_faction))
		var left_missile_cost: int = int(game.call("_missile_cost", left_faction))
		var right_missile_cost: int = int(game.call("_missile_cost", right_faction))
		_expect(left_missile_damage > 0 and right_missile_damage > 0, "Both factions must have positive missile damage")
		_expect(left_missile_cooldown > 0.0 and right_missile_cooldown > 0.0, "Both factions must have positive missile cooldown")
		_expect(left_missile_cost > 0 and right_missile_cost > 0, "Both factions must have positive missile cost")
		var left_missile_ttk: float = float(int(ceil(1000.0 / float(left_missile_damage))) - 1) * left_missile_cooldown
		var right_missile_ttk: float = float(int(ceil(1000.0 / float(right_missile_damage))) - 1) * right_missile_cooldown
		var missile_edge := "تعادل"
		if left_missile_ttk < right_missile_ttk:
			missile_edge = left_faction
		elif right_missile_ttk < left_missile_ttk:
			missile_edge = right_faction
		matchup_rows.append("  missile TTK %.2fs : %.2fs | cost %d : %d | edge %s" % [
			left_missile_ttk, right_missile_ttk, left_missile_cost, right_missile_cost, missile_edge
		])

	# Compare equal-budget air reinforcement efficiency without changing live balance values.
	var air_budget := 6000
	for army in FACTIONS:
		var fighter_cost: int = int(game.call("_unit_cost", "fighter", army))
		var helicopter_cost: int = int(game.call("_unit_cost", "helicopter", army))
		var missile_cost: int = int(game.call("_missile_cost", army))
		_expect(fighter_cost > 0 and helicopter_cost > 0 and missile_cost > 0, "%s must have valid air and missile costs" % army)
		var fighter_count: int = int(floor(float(air_budget) / float(fighter_cost)))
		var helicopter_count: int = int(floor(float(air_budget) / float(helicopter_cost)))
		var missile_count: int = int(floor(float(air_budget) / float(missile_cost)))
		_expect(fighter_count > 0 and helicopter_count > 0 and missile_count > 0, "%s must be able to field at least one air unit or missile within the test budget" % army)

		for ground_kind in ["infantry", "tank", "builder", "artillery"]:
			var ground_cost: int = int(game.call("_unit_cost", ground_kind, army))
			var ground_supply: int = int(game.call("_unit_supply_cost", ground_kind))
			_expect(ground_cost > 0, "%s must have a positive %s reinforcement cost" % [army, ground_kind])
			_expect(ground_supply >= 0, "%s %s supply demand cannot be negative" % [army, ground_kind])
			var affordable_count: int = int(floor(float(air_budget) / float(ground_cost)))
			_expect(affordable_count > 0, "%s must be able to field %s within the comparison budget" % [army, ground_kind])
			print("ECONOMY: %s %s | cost %d | supply %d | budget count %d" % [army, ground_kind, ground_cost, ground_supply, affordable_count])

		print("AIR ECONOMY: %s | fighter %d | helicopter %d | missile %d | budget %d" % [army, fighter_count, helicopter_count, missile_count, air_budget])

	for row in matchup_rows:
		print("MATCHUP: " + row)
	print("PASS: all six pairwise helicopter and missile duels plus land-and-air reinforcement economy checks completed for four factions.")
	_cleanup_audio(game)
	game.queue_free()
	await process_frame
	if failures > 0:
		push_error("Faction matchup matrix failed with %d assertion(s)." % failures)
		quit(1)
		return
	quit(0)


func _cleanup_audio(game: Node) -> void:
	var players: Array = game.get("audio_players")
	for player in players:
		player.stop()
		player.stream = null
		game.remove_child(player)
		player.free()
	players.clear()
	(game.get("audio_streams") as Dictionary).clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Faction matchup matrix failed: " + message)
