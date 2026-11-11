extends RefCounted
class_name BattleTeamRegistry

# Isolated team-state foundation. The live two-side match remains on its legacy
# adapter until save migration, combat targeting, economy, and AI are migrated.
var _teams: Dictionary = {}
var _team_order: Array[String] = []
var _hostility: Dictionary = {}


func register_team(
	team_id: String,
	faction_id: String,
	controller_type: String = "ai",
	base_position: Vector2 = Vector2.ZERO,
	base_hp: int = 1000
) -> bool:
	if team_id.strip_edges().is_empty() or faction_id.strip_edges().is_empty():
		return false
	if _teams.has(team_id) or controller_type not in ["human", "ai"] or base_hp < 0:
		return false

	_teams[team_id] = {
		"team_id": team_id,
		"faction_id": faction_id,
		"controller_type": controller_type,
		"base_position": base_position,
		"base_hp": base_hp,
		"alive": base_hp > 0,
		"credits": 0,
		"supplies": 0,
		"supply_capacity": 0,
		"building_ids": [],
		"production_orders": [],
		"ai_state": {}
	}
	_team_order.append(team_id)

	# Free-for-all defaults to hostile relationships; explicit diplomacy can
	# turn any pair into allies later. Team identity is independent of faction.
	for existing_id in _team_order:
		if existing_id == team_id:
			continue
		set_hostility(existing_id, team_id, true)
	return true


func has_team(team_id: String) -> bool:
	return _teams.has(team_id)


func team_ids() -> Array[String]:
	return _team_order.duplicate()


func living_team_ids() -> Array[String]:
	var result: Array[String] = []
	for team_id in _team_order:
		if bool(_teams[team_id].get("alive", false)):
			result.append(team_id)
	return result


func get_team(team_id: String) -> Dictionary:
	if not _teams.has(team_id):
		return {}
	return (_teams[team_id] as Dictionary).duplicate(true)


func set_base_health(team_id: String, health: int) -> bool:
	if not _teams.has(team_id) or health < 0:
		return false
	var team: Dictionary = _teams[team_id]
	team["base_hp"] = health
	team["alive"] = health > 0
	_teams[team_id] = team
	return true


func set_economy(team_id: String, credits: int, supplies: int, supply_capacity: int) -> bool:
	if not _teams.has(team_id) or credits < 0 or supplies < 0 or supply_capacity < 0:
		return false
	if supplies > supply_capacity:
		return false
	var team: Dictionary = _teams[team_id]
	team["credits"] = credits
	team["supplies"] = supplies
	team["supply_capacity"] = supply_capacity
	_teams[team_id] = team
	return true


func set_hostility(source_team_id: String, target_team_id: String, hostile: bool) -> bool:
	if source_team_id == target_team_id:
		return false
	if not _teams.has(source_team_id) or not _teams.has(target_team_id):
		return false
	var source_relations: Dictionary = _hostility.get(source_team_id, {})
	var target_relations: Dictionary = _hostility.get(target_team_id, {})
	source_relations[target_team_id] = hostile
	target_relations[source_team_id] = hostile
	_hostility[source_team_id] = source_relations
	_hostility[target_team_id] = target_relations
	return true


func are_hostile(source_team_id: String, target_team_id: String) -> bool:
	if source_team_id == target_team_id:
		return false
	if not _teams.has(source_team_id) or not _teams.has(target_team_id):
		return false
	var relations: Dictionary = _hostility.get(source_team_id, {})
	return bool(relations.get(target_team_id, false))
