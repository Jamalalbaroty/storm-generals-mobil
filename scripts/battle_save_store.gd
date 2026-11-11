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
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var input := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	for required_key in ["match", "units", "buildings", "enemy_buildings", "production_orders"]:
		if not snapshot.has(required_key):
			return false
	if not snapshot["match"] is Dictionary:
		return false
	if not snapshot["units"] is Array or not snapshot["buildings"] is Array or not snapshot["enemy_buildings"] is Array or not snapshot["production_orders"] is Array:
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
			if not building_variant is Dictionary:
				return false
	for order_variant in snapshot["production_orders"]:
		if not order_variant is Dictionary:
			return false
	return true


func _validate_unit_identity(unit: Dictionary, seen_ids: Dictionary) -> bool:
	var unit_id := String(unit.get("unit_id", ""))
	if unit_id.is_empty() or seen_ids.has(unit_id):
		return false
	if not unit.has("kind") or not unit.has("team") or not unit.has("hp") or not unit.has("pos"):
		return false
	if not unit["pos"] is Vector2:
		return false
	seen_ids[unit_id] = true
	return true
