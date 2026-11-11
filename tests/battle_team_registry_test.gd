extends SceneTree

const TeamRegistry = preload("res://scripts/battle_team_registry.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry = TeamRegistry.new()
	_expect(registry.register_team("team_red", "الأمريكي", "human", Vector2(120.0, 180.0), 900), "A human-controlled team should register")
	_expect(registry.register_team("team_blue", "وطن", "ai", Vector2(1080.0, 180.0), 1100), "An AI team should register")
	_expect(registry.register_team("team_green", "وطن", "ai", Vector2(600.0, 620.0), 1000), "Two teams may select the same faction")
	_expect(not registry.register_team("team_red", "الصيني"), "Stable team IDs must be unique")
	_expect(not registry.register_team("team_invalid", "", "ai"), "A team must have a faction identity")
	_expect(not registry.register_team("team_invalid", "الصيني", "spectator"), "Unsupported controller types must be rejected")

	_expect(registry.team_ids() == ["team_red", "team_blue", "team_green"], "Team registration order should remain stable")
	_expect(registry.are_hostile("team_red", "team_blue"), "New FFA teams should default to hostile")
	_expect(registry.are_hostile("team_blue", "team_green"), "Every new team should be hostile to previously registered teams")
	_expect(not registry.are_hostile("team_red", "team_red"), "A team must never be hostile to itself")
	_expect(not registry.are_hostile("team_red", "unknown"), "Unknown teams must never resolve as hostile")

	_expect(registry.set_hostility("team_red", "team_blue", false), "Diplomacy should allow an alliance")
	_expect(not registry.are_hostile("team_red", "team_blue") and not registry.are_hostile("team_blue", "team_red"), "Diplomacy changes must be symmetric")
	_expect(not registry.set_hostility("team_red", "team_red", true), "Self-hostility must be rejected")

	_expect(registry.set_economy("team_blue", 2400, 35, 60), "A valid independent team economy should be stored")
	_expect(not registry.set_economy("team_blue", -1, 0, 60), "Negative credits must be rejected")
	_expect(not registry.set_economy("team_blue", 100, 61, 60), "Supplies above capacity must be rejected")
	var blue_snapshot: Dictionary = registry.get_team("team_blue")
	_expect(int(blue_snapshot.get("credits", 0)) == 2400, "Team credits should be independently retained")
	blue_snapshot["credits"] = 0
	_expect(int(registry.get_team("team_blue").get("credits", -1)) == 2400, "Team snapshots must not expose mutable internal state")

	_expect(registry.set_base_health("team_green", 0), "A team base should be eliminable")
	_expect(not registry.living_team_ids().has("team_green"), "Eliminated teams must leave the living-team list")
	_expect(registry.living_team_ids().size() == 2, "Other teams should remain alive after one elimination")
	_expect(not registry.set_base_health("unknown", 500), "Unknown team base state must not be mutable")

	if failures > 0:
		push_error("Battle team registry test failed with %d assertion(s)." % failures)
		quit(1)
		return
	print("Battle team registry test passed: stable IDs, faction/team separation, symmetric diplomacy, independent economy, and elimination state.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Battle team registry test failed: " + message)
