extends SceneTree

const LegacyAdapter = preload("res://scripts/battle_legacy_team_adapter.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter = LegacyAdapter.new()
	_expect(adapter.configure_legacy_match(
		"وطن", "الصيني",
		Vector2(180.0, 330.0), Vector2(1090.0, 330.0),
		880, 760, 2100, 1450, 24, 18, 60
	), "A valid legacy two-side match should configure")

	_expect(adapter.team_id_for_legacy("player") == LegacyAdapter.PLAYER_TEAM_ID, "Legacy player should map to a stable team ID")
	_expect(adapter.team_id_for_legacy("enemy") == LegacyAdapter.ENEMY_TEAM_ID, "Legacy enemy should map to a stable team ID")
	_expect(adapter.team_id_for_legacy("neutral") == "", "Unknown legacy sides must not be silently mapped")

	var player_unit := {"team": "player", "faction": "وطن", "kind": "tank"}
	var enemy_unit := {"team": "enemy", "faction": "الصيني", "kind": "fighter"}
	_expect(adapter.team_id_for_unit(player_unit) == LegacyAdapter.PLAYER_TEAM_ID, "Existing player unit dictionaries should resolve through the compatibility adapter")
	_expect(adapter.team_id_for_unit(enemy_unit) == LegacyAdapter.ENEMY_TEAM_ID, "Existing enemy unit dictionaries should resolve through the compatibility adapter")
	_expect(adapter.are_units_hostile(player_unit, enemy_unit), "Legacy player and enemy must remain hostile")
	_expect(not adapter.are_units_hostile(player_unit, player_unit), "Legacy units on the same side must not be hostile")

	var explicitly_migrated := {"team": "player", "team_id": LegacyAdapter.ENEMY_TEAM_ID, "faction": "الصيني"}
	_expect(adapter.team_id_for_unit(explicitly_migrated) == LegacyAdapter.ENEMY_TEAM_ID, "An explicit stable team ID should take precedence over the legacy side field")
	_expect(adapter.faction_for_unit(enemy_unit) == "الصيني", "Faction identity must remain separate from team identity")

	var player_team: Dictionary = adapter.registry.get_team(LegacyAdapter.PLAYER_TEAM_ID)
	var enemy_team: Dictionary = adapter.registry.get_team(LegacyAdapter.ENEMY_TEAM_ID)
	_expect(int(player_team.get("base_hp", -1)) == 880 and int(enemy_team.get("base_hp", -1)) == 760, "Legacy base health should be represented independently")
	_expect(int(player_team.get("credits", -1)) == 2100 and int(enemy_team.get("credits", -1)) == 1450, "Legacy credits should remain independent")
	_expect(int(player_team.get("supplies", -1)) == 24 and int(enemy_team.get("supplies", -1)) == 18, "Legacy supply stores should remain independent")

	_expect(not adapter.configure_legacy_match("", "الصيني", Vector2.ZERO, Vector2.ONE), "Invalid legacy match configuration must fail safely")
	if failures > 0:
		push_error("Battle legacy team adapter test failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("Battle legacy team adapter test passed: legacy side mapping, stable IDs, hostility parity, faction separation, and independent match state.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Battle legacy team adapter test failed: " + message)
