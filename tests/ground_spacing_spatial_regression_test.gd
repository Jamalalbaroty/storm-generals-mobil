extends SceneTree

var failure_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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

	for seed_value in [101, 2026, 7331, 99173]:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed_value)
		var fixture: Array[Dictionary] = []
		var kinds := ["infantry", "tank", "artillery", "builder", "fighter", "helicopter", "transport_helicopter"]
		for unit_index in range(180):
			var x := rng.randf_range(-64.0, 520.0)
			var y := rng.randf_range(-48.0, 360.0)
			if unit_index % 19 == 0:
				x = 31.8 if unit_index % 2 == 0 else 32.2
				y = 63.9 if unit_index % 3 == 0 else 64.1
			fixture.append({
				"kind": kinds[rng.randi_range(0, kinds.size() - 1)],
				"team": "player" if rng.randi_range(0, 1) == 0 else "enemy",
				"hp": 0 if unit_index % 23 == 0 else 100,
				"pos": Vector2(x, y)
			})

		var expected := _reference_spacing(fixture)
		game.set("units", fixture.duplicate(true))
		game.call("_resolve_ground_unit_spacing")
		var actual: Array = game.get("units")
		_expect(actual.size() == expected.size(), "Spatial spacing must preserve every unit for fixture seed %d" % int(seed_value))
		for unit_index in range(mini(actual.size(), expected.size())):
			var actual_pos: Vector2 = actual[unit_index].get("pos", Vector2.ZERO)
			var expected_pos: Vector2 = expected[unit_index].get("pos", Vector2.ZERO)
			_expect(actual_pos.distance_to(expected_pos) <= 0.001, "Spatial spacing must match the original pairwise result at seed %d, unit %d" % [int(seed_value), unit_index])

	for audio_player in game.get("audio_players"):
		audio_player.stop()
		audio_player.stream = null
		audio_player.queue_free()
	(game.get("audio_players") as Array).clear()
	(game.get("audio_streams") as Dictionary).clear()
	game.queue_free()
	await process_frame
	if failure_count > 0:
		push_error("Ground spacing spatial regression failed with %d assertion(s)." % failure_count)
		quit(1)
		return
	print("Ground spacing spatial regression passed: optimized collision buckets match the original two-pass pairwise solver across four deterministic 180-unit fixtures.")
	quit()


func _reference_spacing(source: Array) -> Array:
	var result: Array = source.duplicate(true)
	var excluded_kinds := ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine", "landing_craft"]
	for pass_index in range(2):
		for first_index in range(result.size()):
			var first: Dictionary = result[first_index]
			if int(first.get("hp", 0)) <= 0 or String(first.get("kind", "")) in excluded_kinds:
				continue
			for second_index in range(first_index + 1, result.size()):
				var second: Dictionary = result[second_index]
				if String(first.get("team", "")) != String(second.get("team", "")):
					continue
				if int(second.get("hp", 0)) <= 0 or String(second.get("kind", "")) in excluded_kinds:
					continue
				var offset: Vector2 = second.pos - first.pos
				var distance := offset.length()
				var first_kind := String(first.get("kind", ""))
				var second_kind := String(second.get("kind", ""))
				var first_radius := 13.0 if first_kind in ["tank", "artillery"] else 9.0
				var second_radius := 13.0 if second_kind in ["tank", "artillery"] else 9.0
				var minimum_distance := first_radius + second_radius
				if distance >= minimum_distance:
					continue
				var fallback_angle := float(first_index * 37 + second_index * 17) * 2.39996323
				var direction := offset / distance if distance > 0.001 else Vector2(cos(fallback_angle), sin(fallback_angle))
				var correction := (minimum_distance - distance) * 0.5
				first.pos -= direction * correction
				second.pos += direction * correction
				result[first_index] = first
				result[second_index] = second
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error("Ground spacing spatial regression failed: " + message)
