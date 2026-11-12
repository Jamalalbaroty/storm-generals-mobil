extends RefCounted
class_name BattleLegacyTeamAdapter

const TeamRegistry = preload("res://scripts/battle_team_registry.gd")
const PLAYER_TEAM_ID := "legacy.player"
const ENEMY_TEAM_ID := "legacy.enemy"

var registry = TeamRegistry.new()


func configure_legacy_match(
	player_faction: String,
	enemy_faction: String,
	player_base: Vector2,
	enemy_base: Vector2,
	player_base_hp: int = 1000,
	enemy_base_hp: int = 1000,
	player_credits: int = 0,
	enemy_credits: int = 0,
	player_supplies: int = 0,
	enemy_supplies: int = 0,
	supply_capacity: int = 999
) -> bool:
	registry = TeamRegistry.new()
	if not registry.register_team(PLAYER_TEAM_ID, player_faction, "human", player_base, player_base_hp):
		return false
	if not registry.register_team(ENEMY_TEAM_ID, enemy_faction, "ai", enemy_base, enemy_base_hp):
		return false
	if not registry.set_economy(PLAYER_TEAM_ID, player_credits, player_supplies, supply_capacity):
		return false
	if not registry.set_economy(ENEMY_TEAM_ID, enemy_credits, enemy_supplies, supply_capacity):
		return false
	return registry.are_hostile(PLAYER_TEAM_ID, ENEMY_TEAM_ID)


func team_id_for_legacy(team: String) -> String:
	match team:
		"player":
			return PLAYER_TEAM_ID
		"enemy":
			return ENEMY_TEAM_ID
	return ""


func team_id_for_unit(unit: Dictionary) -> String:
	var explicit_id := String(unit.get("team_id", ""))
	if not explicit_id.is_empty():
		return explicit_id
	return team_id_for_legacy(String(unit.get("team", "")))


func are_units_hostile(left: Dictionary, right: Dictionary) -> bool:
	var left_id := team_id_for_unit(left)
	var right_id := team_id_for_unit(right)
	if left_id.is_empty() or right_id.is_empty():
		return false
	return registry.are_hostile(left_id, right_id)


func faction_for_unit(unit: Dictionary) -> String:
	var explicit_faction := String(unit.get("faction", ""))
	if not explicit_faction.is_empty():
		return explicit_faction
	var team_id := team_id_for_unit(unit)
	if team_id.is_empty():
		return ""
	return String(registry.get_team(team_id).get("faction_id", ""))
