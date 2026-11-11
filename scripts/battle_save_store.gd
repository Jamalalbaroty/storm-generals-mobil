extends RefCounted
class_name BattleSaveStore

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://storm_generals_battle.save"
const TEMP_PATH := "user://storm_generals_battle.save.tmp"
const BACKUP_PATH := "user://storm_generals_battle.save.bak"


func save_snapshot(snapshot: Dictionary) -> bool:
	if not _validate_snapshot(snapshot):
		return false
	var output := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if output == null:
		return false
	output.store_var(snapshot, true)
	output.flush()
	var write_error := output.get_error()
	output.close()
	if write_error != OK:
		_remove_if_exists(TEMP_PATH)
		return false
	# Verify the complete temporary payload before touching the previous valid save.
	var verification := FileAccess.open(TEMP_PATH, FileAccess.READ)
	if verification == null:
		_remove_if_exists(TEMP_PATH)
		return false
	var decoded: Variant = verification.get_var(true)
	var read_error := verification.get_error()
	verification.close()
	if read_error != OK or not decoded is Dictionary or not _validate_snapshot(decoded):
		_remove_if_exists(TEMP_PATH)
		return false
	var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var temp_absolute := ProjectSettings.globalize_path(TEMP_PATH)
	var backup_absolute := ProjectSettings.globalize_path(BACKUP_PATH)
	var had_previous_save := FileAccess.file_exists(SAVE_PATH)
	if had_previous_save:
		_remove_if_exists(BACKUP_PATH)
		var backup_error := DirAccess.rename_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			_remove_if_exists(TEMP_PATH)
			return false
	var promote_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if promote_error != OK:
		if had_previous_save:
			DirAccess.rename_absolute(backup_absolute, save_absolute)
		_remove_if_exists(TEMP_PATH)
		return false
	if had_previous_save:
		_remove_if_exists(BACKUP_PATH)
	return true


func load_snapshot() -> Dictionary:
	var primary := _read_snapshot(SAVE_PATH)
	if not primary.is_empty():
		return primary
	# Recover the last verified snapshot if the app stopped during atomic promotion.
	var backup := _read_snapshot(BACKUP_PATH)
	if backup.is_empty():
		return {}
	_remove_if_exists(SAVE_PATH)
	var recovery_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if recovery_error != OK:
		return backup
	return backup


func _read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var input := FileAccess.open(path, FileAccess.READ)
	if input == null:
		return {}
	var decoded: Variant = input.get_var(true)
	var read_error := input.get_error()
	input.close()
	if read_error != OK or not decoded is Dictionary or not _validate_snapshot(decoded):
		return {}
	return decoded


func delete_snapshot() -> bool:
	var had_save := FileAccess.file_exists(SAVE_PATH)
	var had_temp := FileAccess.file_exists(TEMP_PATH)
	var had_backup := FileAccess.file_exists(BACKUP_PATH)
	_remove_if_exists(SAVE_PATH)
	_remove_if_exists(TEMP_PATH)
	_remove_if_exists(BACKUP_PATH)
	return (not had_save or not FileAccess.file_exists(SAVE_PATH)) and (not had_temp or not FileAccess.file_exists(TEMP_PATH)) and (not had_backup or not FileAccess.file_exists(BACKUP_PATH))


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _validate_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	for required_key in ["match", "units", "buildings", "enemy_buildings", "production_orders", "missiles"]:
		if not snapshot.has(required_key):
			return false
	if not snapshot["match"] is Dictionary:
		return false
	if not snapshot["units"] is Array or not snapshot["buildings"] is Array or not snapshot["enemy_buildings"] is Array or not snapshot["production_orders"] is Array or not snapshot["missiles"] is Array:
		return false
	var match_state: Dictionary = snapshot["match"]
	if match_state.has("supply_points"):
		if not match_state["supply_points"] is Array:
			return false
		for point_variant in match_state["supply_points"]:
			if not point_variant is Dictionary or not _validate_supply_point(point_variant):
				return false
	for numeric_key in ["credits", "supplies", "enemy_supplies", "income_timer", "enemy_credits", "enemy_income_timer", "enemy_timer", "enemy_missile_timer", "player_base_hp", "enemy_base_hp", "next_unit_identity", "next_building_production_id"]:
		if match_state.has(numeric_key) and not _is_finite_number(match_state[numeric_key]):
			return false
	for position_key in ["base_pos", "enemy_base"]:
		if match_state.has(position_key) and not _is_valid_position(match_state[position_key]):
			return false
	if int(match_state.get("credits", 0)) < 0 or int(match_state.get("enemy_credits", 0)) < 0 or int(match_state.get("supplies", 0)) < 0 or int(match_state.get("enemy_supplies", 0)) < 0:
		return false
	if int(match_state.get("player_base_hp", 0)) < 0 or int(match_state.get("enemy_base_hp", 0)) < 0:
		return false
	var seen_ids: Dictionary = {}
	for unit_variant in snapshot["units"]:
		if not unit_variant is Dictionary:
			return false
		var unit: Dictionary = unit_variant
		if not _validate_unit_identity(unit, seen_ids):
			return false
		var cargo: Variant = unit.get("transport_cargo", [])
		if not cargo is Array or cargo.size() > 8:
			return false
		for passenger_variant in cargo:
			if not passenger_variant is Dictionary:
				return false
			if not _validate_unit_identity(passenger_variant, seen_ids):
				return false
	for building_array_key in ["buildings", "enemy_buildings"]:
		for building_variant in snapshot[building_array_key]:
			if not building_variant is Dictionary or not _validate_building(building_variant):
				return false
	for order_variant in snapshot["production_orders"]:
		if not order_variant is Dictionary or not _validate_production_order(order_variant):
			return false
	for missile_variant in snapshot["missiles"]:
		if not missile_variant is Dictionary or not _validate_missile(missile_variant):
			return false
	return true


func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value))


func _is_valid_position(value: Variant) -> bool:
	if not value is Vector2:
		return false
	var position: Vector2 = value
	return is_finite(position.x) and is_finite(position.y)


func _validate_unit_identity(unit: Dictionary, seen_ids: Dictionary) -> bool:
	var unit_id := String(unit.get("unit_id", ""))
	var kind := String(unit.get("kind", ""))
	var team := String(unit.get("team", ""))
	if unit_id.is_empty() or seen_ids.has(unit_id) or kind.is_empty() or team not in ["player", "enemy"]:
		return false
	if not unit.has("hp") or not _is_finite_number(unit["hp"]) or float(unit["hp"]) < 0.0:
		return false
	if not unit.has("pos") or not _is_valid_position(unit["pos"]):
		return false
	seen_ids[unit_id] = true
	return true


func _validate_supply_point(point: Dictionary) -> bool:
	if not _is_valid_position(point.get("pos", null)):
		return false
	if String(point.get("owner", "")) not in ["player", "enemy", "neutral"]:
		return false
	if String(point.get("kind", "supply")) not in ["supply", "port", "bridge"]:
		return false
	for payout_key in ["payout", "supply_payout"]:
		if point.has(payout_key) and (not _is_finite_number(point[payout_key]) or float(point[payout_key]) < 0.0):
			return false
	return true


func _validate_building(building: Dictionary) -> bool:
	if String(building.get("kind", "")).is_empty():
		return false
	if not building.has("hp") or not _is_finite_number(building["hp"]) or float(building["hp"]) < 0.0:
		return false
	if not building.has("pos") or not _is_valid_position(building["pos"]):
		return false
	if building.has("build_progress"):
		if not _is_finite_number(building["build_progress"]) or float(building["build_progress"]) < 0.0 or float(building["build_progress"]) > 1.0:
			return false
	return true


func _validate_production_order(order: Dictionary) -> bool:
	if String(order.get("kind", "")).is_empty() or not _is_valid_position(order.get("producer_pos", null)):
		return false
	for numeric_key in ["remaining", "duration"]:
		if not order.has(numeric_key) or not _is_finite_number(order[numeric_key]) or float(order[numeric_key]) < 0.0:
			return false
	if float(order["duration"]) <= 0.0 or float(order["remaining"]) > float(order["duration"]):
		return false
	if order.has("producer_id") and not (order["producer_id"] is int):
		return false
	return true


func _validate_missile(missile: Dictionary) -> bool:
	if not _is_valid_position(missile.get("pos", null)) or not _is_valid_position(missile.get("target", null)):
		return false
	if String(missile.get("team", "")) not in ["player", "enemy"]:
		return false
	if not missile.has("damage") or not _is_finite_number(missile["damage"]) or float(missile["damage"]) <= 0.0:
		return false
	if missile.has("life") and (not _is_finite_number(missile["life"]) or float(missile["life"]) < 0.0):
		return false
	return true
