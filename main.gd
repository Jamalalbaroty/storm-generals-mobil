extends Node2D

const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const MAP_TYPES := ["الساحل الصحراوي", "ساحل الغابات", "الساحل الجبلي", "المدينة الساحلية"]
const CAMPAIGN_MISSIONS := [
	{"name": "شرارة العاصفة", "map": "الساحل الصحراوي", "brief": "أنشئ قاعدة متينة ودمر مركز قيادة العدو", "reward": 250, "secondary": "حافظ على سلامة قاعدتك بأكثر من 50٪", "bonus": 100},
	{"name": "خطوط الإمداد", "map": "ساحل الغابات", "brief": "سيطر على الموارد وامنع العدو من تثبيت مواقعه", "reward": 350, "secondary": "سيطر على نقطتي إمداد على الأقل", "bonus": 150},
	{"name": "قبضة الجبال", "map": "الساحل الجبلي", "brief": "استخدم الدروع والمدفعية لفتح الطريق نحو القاعدة", "reward": 450, "secondary": "أنشئ أربع منشآت مكتملة على الأقل", "bonus": 175},
	{"name": "حصار المدينة", "map": "المدينة الساحلية", "brief": "نسق القوات البرية والجوية لاختراق دفاعات العدو وتدمير مركز قيادته", "reward": 550, "secondary": "امتلك وحدة جوية ووحدة مدرعة حية على الأقل", "bonus": 200},
	{"name": "العاصفة الكبرى", "map": "الساحل الصحراوي", "brief": "المواجهة الحاسمة: دمر قاعدة العدو وأثبت سيادتك", "reward": 750, "secondary": "أنه المعركة مع بقاء 60٪ من صحة قاعدتك", "bonus": 300}
]
const COMMAND_TAB_LABELS := ["البرية", "الجوية", "الاستراتيجية", "التحصينات", "الإنزال الجوي"]
const COMMAND_ACTIONS := [
	[0, 1, 2, 3, 4, 5],
	[6, 7, 8, 9, 21, 22],
	[10, 11, 12, 13, 14, 15],
	[23, 24, 25, 26, 27],
	[28, 29, 30, 31]
]
const INFANTRY_COST := 100
const TANK_COST := 300
const STARTING_CREDITS := 1200
const MAX_TEAM_UNITS := 40
const NAVAL_SYSTEM_ENABLED := false
const NAVAL_UNIT_KINDS := ["destroyer", "carrier", "submarine", "landing_craft"]
const PASSIVE_INCOME := 6.0
const MAX_CREDITS := 5000
const BARRACKS_COST := 250
const FACTORY_COST := 450
const TURRET_COST := 350
const ARTILLERY_COST := 450
const AIRFIELD_COST := 600
const FIGHTER_COST := 500
const FIGHTER_DAMAGE := 30
const FIGHTER_TARGET_RANGE := 300.0
const FIGHTER_ATTACK_RANGE := 270.0
const FIGHTER_ATTACK_COOLDOWN := 1.35
const FIGHTER_SPEED := 95.0
const FIGHTER_PATROL_SPEED := 65.0
const AA_COST := 400
const HELICOPTER_COST := 650
const MISSILE_SILO_COST := 800
const MISSILE_DEFENSE_COST := 700
const MISSILE_COST := 650
const MISSILE_DEFENSE_INTERCEPT_COOLDOWN := 0.75
const FACTION_BALANCE := {
	# China fields efficient armor and submarines, trading some air/artillery cost.
	"الصيني": {"helicopter_cost": 650, "helicopter_damage": 30, "helicopter_cooldown": 1.35, "missile_cost": 650, "missile_damage": 185, "missile_cooldown": 14.0, "naval_damage": 40, "unit_costs": {"infantry": 100, "tank": 270, "builder": 600, "artillery": 480, "fighter": 520, "destroyer": 900, "carrier": 1600, "submarine": 1050, "landing_craft": 800}},
	# American forces retain the baseline combined-arms economy.
	"الأمريكي": {"helicopter_cost": 650, "helicopter_damage": 32, "helicopter_cooldown": 1.25, "missile_cost": 650, "missile_damage": 195, "missile_cooldown": 13.0, "naval_damage": 44, "unit_costs": {"infantry": 100, "tank": 300, "builder": 600, "artillery": 450, "fighter": 500, "destroyer": 900, "carrier": 1600, "submarine": 1100, "landing_craft": 800}},
	# Arab forces emphasize affordable infantry and field artillery.
	"الجيش العربي": {"helicopter_cost": 650, "helicopter_damage": 34, "helicopter_cooldown": 1.20, "missile_cost": 650, "missile_damage": 205, "missile_cooldown": 12.0, "naval_damage": 42, "unit_costs": {"infantry": 90, "tank": 315, "builder": 600, "artillery": 430, "fighter": 500, "destroyer": 950, "carrier": 1700, "submarine": 1150, "landing_craft": 800}},
	# Watan fields elite equipment with a deliberate economy and reinforcement premium.
	"وطن": {"helicopter_cost": 850, "helicopter_damage": 38, "helicopter_cooldown": 1.10, "missile_cost": 850, "missile_damage": 230, "missile_cooldown": 11.0, "naval_damage": 50, "unit_costs": {"infantry": 110, "tank": 360, "builder": 650, "artillery": 520, "fighter": 575, "destroyer": 1080, "carrier": 1900, "submarine": 1320, "landing_craft": 920}}
}
const ECONOMY_BALANCE := {
	"building_costs": {
		"barracks": BARRACKS_COST, "factory": FACTORY_COST, "turret": TURRET_COST,
		"airfield": AIRFIELD_COST, "anti_air": AA_COST, "missile_silo": MISSILE_SILO_COST,
		"missile_defense": MISSILE_DEFENSE_COST, "shipyard": 700, "power_plant": 450, "bunker": 520, "supply_depot": 550,
		"wall": 90, "wall_corner": 120, "wall_gate": 150
	},
	"unit_costs": {
		"infantry": INFANTRY_COST, "tank": TANK_COST, "builder": 600, "artillery": ARTILLERY_COST,
		"fighter": FIGHTER_COST, "transport_helicopter": 950, "destroyer": 900, "carrier": 1600,
		"submarine": 1100, "landing_craft": 800
	},
	"unit_supplies": {
		"infantry": 0, "tank": 1, "builder": 0, "artillery": 2, "fighter": 2,
		"helicopter": 3, "transport_helicopter": 4, "destroyer": 4, "landing_craft": 4,
		"submarine": 5, "carrier": 8
	}
}

var faction := ""
var map_type := "الساحل الصحراوي"
var credits := STARTING_CREDITS
var supplies := 5
var enemy_supplies := 5
var income_timer := 0.0
var supply_points: Array[Dictionary] = []
var units: Array[Dictionary] = []
var selected: Array[int] = []
var buildings: Array[Dictionary] = []
var production_orders: Array[Dictionary] = []
var build_mode := ""
var selected_enemy_building := -1
var selected_player_building := -1
var notice := "اختر جيشك لبدء المعركة"
var notice_time := 4.0
var enemy_timer := 0.0
var enemy_credits := 1200
var enemy_income_timer := 0.0
var enemy_buildings: Array[Dictionary] = []
var game_started := false
var campaign_briefing := false
var campaign_mission_index := 0
var paused := false
var dragging := false
var active_touch_index := -1
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var pointer_start_target := ""
var base_pos := Vector2(180, 330)
var enemy_base := Vector2(1090, 330)
var player_base_hp := 1000
var enemy_base_hp := 1000
var battle_result := ""
var visual_effects: Array[Dictionary] = []
var next_visual_effect_id := 1
var environment_particles: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var enemy_missile_timer := 0.0
var audio_players: Array[AudioStreamPlayer] = []
var audio_streams: Dictionary = {}
var audio_player_cursor := 0
var sound_cooldowns: Dictionary = {"weapon": 0.0, "explosion": 0.0}
var air_alert_active := false
var ground_alert_active := false
var missile_alert_active := false
var enemy_strategy := "balanced"
var next_building_production_id := 1
var command_tab := 0
var commander_profile: Dictionary = {
	"battles_played": 0,
	"victories": 0,
	"defeats": 0,
	"total_kills": 0,
	"air_kills": 0,
	"armor_kills": 0,
	"naval_kills": 0,
	"earned_medals": [],
	"campaign_progress": {},
	"campaign_funds": 0
}
var commander_profile_saved_result := ""

func _ready() -> void:
	randomize()
	_load_commander_profile()
	_setup_battle_audio()
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


const BATTLEFIELD_3D_SCENE: PackedScene = preload("res://prototype_3d/battlefield_3d.tscn")
var battlefield_3d: Node3D
var battlefield_sync_timer := 0.0
var air_formation_last_center := Vector2(INF, INF)
var air_formation_order_index := 0
var air_formation_order_clock := 0.0
var use_3d_view := false
const BATTLEFIELD_SYNC_INTERVAL := 0.12


func _ensure_3d_gameplay_bridge() -> bool:
	# The 3D prototype builds a large visual scene and audio graph. Defer that
	# cost until the player explicitly opens 3D view; normal 2D matches stay lean.
	if is_instance_valid(battlefield_3d):
		return true
	battlefield_3d = BATTLEFIELD_3D_SCENE.instantiate() as Node3D
	if battlefield_3d == null:
		push_warning("3D battlefield bridge could not instantiate")
		return false
	battlefield_3d.name = "Gameplay3DBridge"
	battlefield_3d.visible = false
	battlefield_3d.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(battlefield_3d)
	if battlefield_3d.has_signal("gameplay_order_issued"):
		battlefield_3d.connect("gameplay_order_issued", Callable(self, "_on_3d_gameplay_order_issued"))
	return true


func _save_aircraft_resume_order(unit: Dictionary) -> void:
	# Preserve the player's current air mission while an aircraft automatically rearms.
	var resume_order: Dictionary = {}
	for order_key in ["target", "attack_base", "attack_focus_pos", "air_patrol_points", "air_patrol_index", "air_patrol_resume"]:
		if unit.has(order_key):
			resume_order[order_key] = unit[order_key]
	if unit.has("attack_target"):
		var target_index := int(unit.get("attack_target", -1))
		if target_index >= 0 and target_index < units.size():
			var target_unit: Dictionary = units[target_index]
			if String(target_unit.get("team", "")) == "enemy" and int(target_unit.get("hp", 0)) > 0:
				resume_order["attack_focus_pos"] = target_unit.pos
	if unit.has("attack_building"):
		var building_index := int(unit.get("attack_building", -1))
		if building_index >= 0 and building_index < enemy_buildings.size():
			var target_building: Dictionary = enemy_buildings[building_index]
			if int(target_building.get("hp", 0)) > 0:
				resume_order["attack_building_kind"] = String(target_building.get("kind", ""))
				resume_order["attack_building_id"] = int(target_building.get("production_id", -1))
				resume_order["attack_building_pos"] = target_building.pos
	unit["airfield_resume_order"] = resume_order


func _restore_aircraft_resume_order(unit: Dictionary) -> void:
	var resume_order: Dictionary = unit.get("airfield_resume_order", {})
	unit.erase("airfield_resume_order")
	if resume_order.is_empty():
		return
	for order_key in ["target", "attack_base", "attack_focus_pos", "air_patrol_points", "air_patrol_index", "air_patrol_resume"]:
		if resume_order.has(order_key):
			unit[order_key] = resume_order[order_key]
	# Reacquire a living hostile near the saved focus instead of trusting a stale array index.
	if resume_order.has("attack_focus_pos"):
		unit.erase("attack_target")
	if resume_order.has("attack_building_kind") and resume_order.has("attack_building_pos"):
		var saved_kind := String(resume_order["attack_building_kind"])
		var saved_id := int(resume_order.get("attack_building_id", -1))
		var saved_pos: Vector2 = resume_order["attack_building_pos"]
		var restored_building := -1
		for building_index in range(enemy_buildings.size()):
			var candidate: Dictionary = enemy_buildings[building_index]
			if int(candidate.get("hp", 0)) <= 0 or String(candidate.get("kind", "")) != saved_kind:
				continue
			if saved_id >= 0 and int(candidate.get("production_id", -2)) == saved_id:
				restored_building = building_index
				break
			if saved_id < 0 and candidate.pos.distance_to(saved_pos) <= 2.0:
				restored_building = building_index
				break
		if restored_building >= 0:
			unit.erase("attack_target")
			unit.erase("attack_focus_pos")
			unit["attack_building"] = restored_building


func _cancel_airfield_recovery(unit: Dictionary) -> void:
	# A fresh player command always takes priority over automatic recovery.
	# It also invalidates any old combined-arms lane before a new order is applied.
	unit.erase("attack_formation_offset")
	unit.erase("airfield_returning")
	unit.erase("airfield_landed")
	unit.erase("airfield_recovery_id")
	unit.erase("airfield_recovery_slot")
	unit.erase("airfield_sortie_ready")
	unit.erase("airfield_sortie_launch")
	unit.erase("airfield_sortie_airfield_id")
	unit.erase("airfield_resume_order")


func _on_3d_gameplay_order_issued(source_key: String, order_type: String, world_position: Vector3, target_key: String) -> void:
	var source_parts := source_key.split("|")
	if source_parts.size() < 3 or source_parts[0] != "player":
		return
	var source_id := int(source_parts[1])
	var source_index := -1
	for index in range(units.size()):
		if units[index].team == "player" and int(units[index].get("3d_sync_id", -1)) == source_id:
			source_index = index
			break
	if source_index < 0:
		return
	var source_unit: Dictionary = units[source_index]
	if order_type in ["move", "formation_move", "attack_move"]:
		if order_type == "attack_move" and not (String(source_unit.get("kind", "")) in ["tank", "artillery", "infantry"]):
			return
		var map_size := get_viewport_rect().size
		var world_limit := 42.0 * 0.38
		var nx := clampf((world_position.x + world_limit) / (world_limit * 2.0), 0.0, 1.0)
		var ny := clampf((world_position.z + world_limit) / (world_limit * 2.0), 0.0, 1.0)
		_cancel_airfield_recovery(source_unit)
		var move_destination := Vector2(nx * map_size.x, ny * map_size.y)
		if order_type == "move" and String(source_unit.get("kind", "")) in ["fighter", "helicopter", "transport_helicopter"]:
			# Legacy 2D move orders allocate air slots here; 3D formation_move
			# orders already contain their final per-unit destinations.
			if air_formation_order_clock <= 0.0 or air_formation_last_center.distance_to(move_destination) > 8.0:
				air_formation_order_index = 0
				air_formation_last_center = move_destination
			var formation_slot := air_formation_order_index
			air_formation_order_index += 1
			air_formation_order_clock = 0.35
			var slot_column := 0
			var slot_row := 0
			if formation_slot > 0:
				slot_row = int(ceil(float(formation_slot) / 2.0))
				slot_column = -1 if formation_slot % 2 == 1 else 1
			move_destination += Vector2(float(slot_column) * 28.0 * float(slot_row), float(slot_row) * 34.0)
			move_destination.x = clampf(move_destination.x, 24.0, map_size.x - 24.0)
			move_destination.y = clampf(move_destination.y, 24.0, map_size.y - 24.0)
			source_unit["air_formation_slot"] = formation_slot
			source_unit["air_formation_center"] = air_formation_last_center
		source_unit["target"] = move_destination
		source_unit.erase("guard_active")
		source_unit.erase("guard_position")
		source_unit.erase("guard_radius")
		source_unit.erase("escort_active")
		source_unit.erase("escort_target_id")
		source_unit.erase("escort_offset")
		if order_type == "attack_move":
			source_unit["attack_move_active"] = true
		else:
			source_unit.erase("attack_move_active")
		source_unit.erase("air_patrol_points")
		source_unit.erase("air_patrol_index")
		source_unit.erase("air_patrol_resume")
		source_unit.erase("attack_target")
		source_unit.erase("attack_focus_pos")
		source_unit.erase("attack_base")
		source_unit.erase("attack_building")
		notice = "أمر حركة صادر من القيادة ثلاثية الأبعاد"
		notice_time = 1.6
	elif order_type == "guard":
		if String(source_unit.get("kind", "")) not in ["tank", "artillery", "infantry"]:
			return
		var guard_map_size := get_viewport_rect().size
		var guard_world_limit := 42.0 * 0.38
		var guard_nx := clampf((world_position.x + guard_world_limit) / (guard_world_limit * 2.0), 0.0, 1.0)
		var guard_ny := clampf((world_position.z + guard_world_limit) / (guard_world_limit * 2.0), 0.0, 1.0)
		_cancel_airfield_recovery(source_unit)
		source_unit["guard_position"] = Vector2(guard_nx * guard_map_size.x, guard_ny * guard_map_size.y)
		source_unit["guard_radius"] = 300.0 if source_unit.kind == "artillery" else (190.0 if source_unit.kind == "tank" else 155.0)
		source_unit["guard_active"] = true
		source_unit.erase("escort_active")
		source_unit.erase("escort_target_id")
		source_unit.erase("escort_offset")
		source_unit.erase("target")
		source_unit.erase("attack_move_active")
		source_unit.erase("attack_target")
		source_unit.erase("attack_focus_pos")
		source_unit.erase("attack_building")
		source_unit.erase("attack_base")
		notice = "القوات اتخذت مواقع الحراسة والدفاع"
		notice_time = 1.8
	elif order_type == "escort":
		if String(source_unit.get("kind", "")) != "tank":
			return
		var escort_parts := target_key.split("|")
		if escort_parts.size() < 3 or escort_parts[0] != "player" or not escort_parts[1].is_valid_int():
			return
		var escort_target_id := int(escort_parts[1])
		var escort_target_index := -1
		for candidate_index in range(units.size()):
			var candidate: Dictionary = units[candidate_index]
			if candidate.team == "player" and int(candidate.get("3d_sync_id", -1)) == escort_target_id and String(candidate.get("kind", "")) == "artillery" and int(candidate.get("hp", 0)) > 0:
				escort_target_index = candidate_index
				break
		if escort_target_index < 0:
			return
		_cancel_airfield_recovery(source_unit)
		var escort_target: Dictionary = units[escort_target_index]
		source_unit["escort_target_id"] = escort_target_id
		source_unit["escort_offset"] = source_unit.pos - escort_target.pos
		source_unit["escort_active"] = true
		source_unit.erase("target")
		source_unit.erase("guard_active")
		source_unit.erase("guard_position")
		source_unit.erase("guard_radius")
		source_unit.erase("attack_move_active")
		source_unit.erase("attack_target")
		source_unit.erase("attack_focus_pos")
		source_unit.erase("attack_building")
		source_unit.erase("attack_base")
		notice = "الدبابة بدأت مرافقة المدفعية وحمايتها"
		notice_time = 1.8
	elif order_type == "patrol":
		if String(source_unit.get("kind", "")) not in ["fighter", "helicopter"]:
			return
		var patrol_map_size := get_viewport_rect().size
		var patrol_world_limit := 42.0 * 0.38
		var patrol_nx := clampf((world_position.x + patrol_world_limit) / (patrol_world_limit * 2.0), 0.0, 1.0)
		var patrol_ny := clampf((world_position.z + patrol_world_limit) / (patrol_world_limit * 2.0), 0.0, 1.0)
		var patrol_destination := Vector2(patrol_nx * patrol_map_size.x, patrol_ny * patrol_map_size.y)
		_cancel_airfield_recovery(source_unit)
		source_unit.erase("escort_active")
		source_unit.erase("escort_target_id")
		source_unit.erase("escort_offset")
		source_unit["air_patrol_points"] = [source_unit.pos, patrol_destination]
		source_unit["air_patrol_index"] = 1
		source_unit.erase("target")
		source_unit.erase("attack_target")
		source_unit.erase("attack_focus_pos")
		source_unit.erase("attack_building")
		source_unit.erase("attack_base")
		notice = "دورية جوية مفعّلة بين نقطتين"
		notice_time = 1.8
	elif order_type == "attack":
		var target_parts := target_key.split("|")
		if target_parts.size() < 3 or target_parts[0] != "enemy":
			return
		var target_index := -1
		if target_parts[1].is_valid_int():
			var target_id := int(target_parts[1])
			for index in range(units.size()):
				if units[index].team == "enemy" and int(units[index].get("3d_sync_id", -1)) == target_id and int(units[index].get("hp", 0)) > 0:
					target_index = index
					break
			if target_index < 0:
				return
			source_unit["attack_target"] = target_index
			source_unit["attack_focus_pos"] = units[target_index].pos
			source_unit.erase("attack_building")
		else:
			var target_kind := String(target_parts[1])
			var target_identity := "|".join(target_parts.slice(2))
			var target_building_index := -1
			for index in range(enemy_buildings.size()):
				var candidate: Dictionary = enemy_buildings[index]
				if String(candidate.get("kind", "")) != target_kind or int(candidate.get("hp", 0)) <= 0:
					continue
				var candidate_identity := str(candidate.get("production_id", "%.2f|%.2f" % [candidate.pos.x, candidate.pos.y]))
				if candidate_identity == target_identity:
					target_building_index = index
					break
			if target_building_index < 0:
				return
			source_unit["attack_building"] = target_building_index
			source_unit.erase("attack_target")
			source_unit.erase("attack_focus_pos")
		source_unit.erase("target")
		source_unit.erase("air_patrol_points")
		source_unit.erase("air_patrol_index")
		source_unit.erase("air_patrol_resume")
		source_unit.erase("attack_base")
		# Commit the new attack only after its enemy target has been validated.
		_cancel_airfield_recovery(source_unit)
		source_unit.erase("guard_active")
		source_unit.erase("guard_position")
		source_unit.erase("guard_radius")
		source_unit.erase("escort_active")
		source_unit.erase("escort_target_id")
		source_unit.erase("escort_offset")
		source_unit.erase("attack_move_active")
		notice = "أمر اشتباك صادر من القيادة ثلاثية الأبعاد"
		notice_time = 1.6
	queue_redraw()


func _sync_3d_gameplay_bridge() -> void:
	if not is_instance_valid(battlefield_3d) or not game_started:
		return
	var map_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	battlefield_3d.call("sync_game_units", units, map_rect)
	# Supply authoritative maximum HP so player upgrades and faction-specific enemy structures render accurately.
	for building in buildings:
		if building is Dictionary:
			building["max_hp"] = _building_max_hp(building)
	for building in enemy_buildings:
		if building is Dictionary:
			building["max_hp"] = _enemy_building_max_hp(building)
	var enemy_faction_id := _enemy_faction()
	battlefield_3d.call("sync_game_buildings", buildings, enemy_buildings, map_rect, faction, enemy_faction_id)
	battlefield_3d.call("sync_game_production_orders", production_orders)
	battlefield_3d.call("sync_gameplay_effects", visual_effects, map_rect)


func _set_3d_view_enabled(enabled: bool) -> void:
	if enabled and not game_started:
		return
	if enabled and not _ensure_3d_gameplay_bridge():
		use_3d_view = false
		return
	use_3d_view = enabled
	if is_instance_valid(battlefield_3d):
		battlefield_3d.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		battlefield_3d.visible = enabled
		# CanvasLayer HUDs do not reliably inherit a hidden Node3D parent's visibility.
		# Toggle the tactical radar explicitly so it never covers the 2D command deck.
		if battlefield_3d.has_method("set_tactical_radar_visible"):
			battlefield_3d.call("set_tactical_radar_visible", enabled)
	if enabled:
		# Rebuild the visual snapshot on activation; hidden 3D proxies do not need per-frame sync.
		_sync_3d_gameplay_bridge()
	dragging = false
	queue_redraw()


func _three_d_view_toggle_rect(size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x - 224.0, 5.0), Vector2(104.0, 48.0))


func _setup_battle_audio() -> void:
	audio_streams["weapon"] = _build_battle_sound("weapon")
	audio_streams["explosion"] = _build_battle_sound("explosion")
	for player_index in range(4):
		var player = AudioStreamPlayer.new()
		player.name = "BattleAudio" + str(player_index)
		player.volume_db = -7.0
		add_child(player)
		audio_players.append(player)


func _build_battle_sound(sound_name: String) -> AudioStreamWAV:
	var sample_rate = 22050
	var duration := 0.34 if sound_name == "explosion" else 0.12
	var sample_count := int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count)
	for sample_index in range(sample_count):
		var t = float(sample_index) / float(sample_rate)
		var sample := 0.0
		if sound_name == "explosion":
			var envelope = exp(-t * 8.5)
			var sweep_frequency: float = 82.0 - 42.0 * (t / duration)
			var low_boom := sin(TAU * sweep_frequency * t) * 0.62
			var debris_noise := randf_range(-1.0, 1.0) * 0.38
			sample = (low_boom + debris_noise) * envelope
		else:
			var envelope = exp(-t * 38.0)
			var snap := sin(TAU * (155.0 - 85.0 * t / duration) * t) * 0.58
			var crack := randf_range(-1.0, 1.0) * 0.42
			sample = (snap + crack) * envelope
		pcm[sample_index] = int(clampf(sample * 112.0 + 128.0, 0.0, 255.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm
	return stream


func _play_battle_sound(sound_name: String) -> void:
	if not audio_streams.has(sound_name) or audio_players.is_empty():
		return
	if float(sound_cooldowns.get(sound_name, 0.0)) > 0.0:
		return
	sound_cooldowns[sound_name] = 0.11 if sound_name == "weapon" else 0.18
	for attempt in range(audio_players.size()):
		var player_index = (audio_player_cursor + attempt) % audio_players.size()
		var player: AudioStreamPlayer = audio_players[player_index]
		if not player.playing:
			player.stream = audio_streams[sound_name]
			player.play()
			audio_player_cursor = (player_index + 1) % audio_players.size()
			return

func _process(delta: float) -> void:
	air_formation_order_clock = maxf(0.0, air_formation_order_clock - delta)
	if use_3d_view and is_instance_valid(battlefield_3d):
		battlefield_sync_timer += delta
		if battlefield_sync_timer >= BATTLEFIELD_SYNC_INTERVAL:
			battlefield_sync_timer = fmod(battlefield_sync_timer, BATTLEFIELD_SYNC_INTERVAL)
			_sync_3d_gameplay_bridge()
	if paused:
		return
	for sound_name in sound_cooldowns.keys():
		sound_cooldowns[sound_name] = maxf(0.0, float(sound_cooldowns[sound_name]) - delta)
	if notice_time > 0.0:
		notice_time -= delta
	for effect_index in range(visual_effects.size() - 1, -1, -1):
		visual_effects[effect_index].life = float(visual_effects[effect_index].life) - delta
		if visual_effects[effect_index].life <= 0.0:
			var expired_effect: Dictionary = visual_effects[effect_index]
			if String(expired_effect.get("kind", "")) == "shell":
				_add_visual_effect("explosion", expired_effect.finish, expired_effect.finish, Color("#ffb45e"), 0.72, float(expired_effect.get("radius", 66.0)))
			visual_effects.remove_at(effect_index)
	_update_environment_particles(delta)
	if game_started:
		if battle_result != "":
			return
		income_timer += delta
		if income_timer >= 0.9999:
			var completed_income_seconds := int(floor(income_timer + 0.0001))
			credits = mini(MAX_CREDITS, credits + int(PASSIVE_INCOME * float(completed_income_seconds)))
			income_timer = maxf(0.0, income_timer - float(completed_income_seconds))
		_update_supply_control(delta)
		_update_supply_depots(delta)
		_update_building_construction(delta)
		_update_field_repairs(delta)
		_update_production_queues(delta)
		_update_enemy_building_construction(delta)
		_update_building_capture(delta)
		# Naval systems are out of scope for the land-and-air release.
		_update_missiles(delta)
		_update_combat_alerts()
		if _resolve_battle_result():
			return
		enemy_income_timer += delta
		if enemy_income_timer >= 0.9999:
			var completed_enemy_income_seconds := int(floor(enemy_income_timer + 0.0001))
			enemy_credits = mini(MAX_CREDITS, enemy_credits + int(PASSIVE_INCOME * float(completed_enemy_income_seconds)))
			enemy_income_timer = maxf(0.0, enemy_income_timer - float(completed_enemy_income_seconds))
		enemy_timer += delta
		if enemy_timer >= 12.0:
			enemy_timer = 0.0
			_enemy_ai_turn()
			_update_enemy_defense_assignments()
		for defense_index in range(buildings.size()):
			var building: Dictionary = buildings[defense_index]
			if (building.kind == "turret" or building.kind == "anti_air" or building.kind == "bunker") and _is_player_building_powered(defense_index):
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var is_bunker: bool = String(building.get("kind", "")) == "bunker"
				var bunker_level := maxi(1, int(building.get("level", 1))) if is_bunker else 1
				var bunker_range := 185.0 + float(bunker_level - 1) * 30.0
				var target := _nearest_enemy_ground_unit(building.pos, bunker_range) if is_bunker else (_priority_air_target(building.pos, "enemy", 320.0) if building.kind == "anti_air" else _nearest_enemy_unit(building.pos, 230.0))
				if target >= 0 and building.attack_cd <= 0.0:
					building["defense_target_pos"] = units[target].pos
					var defense_damage := 22 + (bunker_level - 1) * 5 if is_bunker else (34 if building.kind == "anti_air" else 18)
					units[target].hp = maxi(0, int(units[target].hp) - _terrain_adjusted_damage(units[target], defense_damage))
					var defense_color := Color("#c8b58a") if is_bunker else (Color("#8ee8ff") if building.kind == "anti_air" else Color("#ffd27a"))
					var defense_effect_kind := "air_missile" if building.kind == "anti_air" else "tracer"
					_add_visual_effect(defense_effect_kind, building.pos, units[target].pos, defense_color, 0.22 if building.kind == "anti_air" else 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, defense_color, 0.22, 13.0)
					building.attack_cd = maxf(0.85, 1.15 - float(bunker_level - 1) * 0.10) if is_bunker else (0.65 if building.kind == "anti_air" else 0.8)
		for defense_index in range(enemy_buildings.size()):
			var building: Dictionary = enemy_buildings[defense_index]
			if not _is_enemy_building_powered(defense_index):
				continue
			if building.kind == "turret" or building.kind == "anti_air":
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var target := _priority_air_target(building.pos, "player", 320.0) if building.kind == "anti_air" else _nearest_player_unit(building.pos)
				var max_range := 320.0 if building.kind == "anti_air" else 230.0
				if target >= 0 and building.pos.distance_to(units[target].pos) <= max_range and building.attack_cd <= 0.0:
					building["defense_target_pos"] = units[target].pos
					units[target].hp = maxi(0, int(units[target].hp) - _terrain_adjusted_damage(units[target], 34 if building.kind == "anti_air" else 16))
					var enemy_defense_effect_kind := "air_missile" if building.kind == "anti_air" else "tracer"
					_add_visual_effect(enemy_defense_effect_kind, building.pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ff8b72"), 0.22 if building.kind == "anti_air" else 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ff704d"), 0.22, 12.0)
					building.attack_cd = 0.65 if building.kind == "anti_air" else 0.9
		var enemy_ground_focus := _select_enemy_ground_assault_target()
		var wall_collision_origins: Array[Vector2] = []
		for movement_snapshot in units:
			wall_collision_origins.append(movement_snapshot.pos)
		for i in units.size():
			var unit = units[i]
			if unit.get("hp", 0) <= 0:
				continue
			if unit.kind == "fighter" and _update_carrier_fighter(unit, delta):
				continue
			if unit.team == "enemy":
				var enemy_landing_support_target := -1
				if _is_naval_kind(String(unit.kind)):
					var naval_target = _best_naval_target(unit.pos, "player", String(unit.kind))
					var naval_destination := Vector2(base_pos.x, get_viewport_rect().size.y * 0.82)
					var target_shipyard := -1
					for bi in buildings.size():
						if buildings[bi].kind == "shipyard":
							target_shipyard = bi
							break
					if naval_target >= 0:
						naval_destination = units[naval_target].pos
					elif target_shipyard >= 0:
						naval_destination = buildings[target_shipyard].pos
					var naval_attack_destination: Vector2 = naval_destination
					var escorting_destroyer := false
					var escort_transport := _nearest_friendly_landing_craft(unit.pos, unit.team)
					var escort_carrier := _nearest_friendly_carrier(unit.pos, unit.team)
					if unit.kind == "destroyer" and escort_transport >= 0 and String(units[escort_transport].get("landing_state", "outbound")) in ["outbound", "returning"] and naval_attack_destination.distance_to(units[escort_transport].pos) > 240.0:
						var escort_side = -1.0 if unit.pos.y <= units[escort_transport].pos.y else 1.0
						naval_destination = units[escort_transport].pos + Vector2(-58.0, escort_side * 66.0)
						escorting_destroyer = true
					elif unit.kind == "destroyer" and escort_carrier >= 0 and naval_attack_destination.distance_to(units[escort_carrier].pos) > 240.0:
						var escort_side = -1.0 if unit.pos.y <= units[escort_carrier].pos.y else 1.0
						naval_destination = units[escort_carrier].pos + Vector2(-52.0, escort_side * 54.0)
						escorting_destroyer = true
					if unit.kind == "carrier":
						unit.launch_cd = float(unit.get("launch_cd", 16.0)) - delta
						var enemy_air := 0
						for air_unit in units:
							if air_unit.team == "enemy" and air_unit.kind == "fighter" and air_unit.get("hp", 0) > 0:
								enemy_air += 1
						if unit.launch_cd <= 0.0 and enemy_air < 3 and _team_unit_count("enemy") < MAX_TEAM_UNITS:
							units.append({"pos": unit.pos + Vector2(0, -18), "team": "enemy", "kind": "fighter", "faction": _enemy_faction(), "hp": 120, "attack_cd": 0.0, "target": base_pos, "carrier_home": true, "sortie_timer": 24.0, "carrier_returning": false})
							unit.launch_cd = 18.0
					if unit.kind == "landing_craft":
						var landing_destination = Vector2(base_pos.x, get_viewport_rect().size.y * 0.82)
						_update_landing_craft(unit, delta, landing_destination)
						continue
					if unit.kind == "destroyer" and escorting_destroyer:
						var escort_distance: float = unit.pos.distance_to(naval_destination)
						if escort_distance > 18.0:
							unit.pos += (naval_destination - unit.pos).normalized() * delta * 28.0
						continue
					if unit.pos.distance_to(naval_attack_destination) <= 290.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0 and unit.kind != "landing_craft":
							var naval_damage = _naval_damage(unit, naval_target)
							_add_visual_effect("tracer", unit.pos, naval_attack_destination, Color("#ffb66f"), 0.2, 0.0)
							_add_visual_effect("explosion", naval_attack_destination, naval_attack_destination, Color("#ff995c"), 0.5, 38.0)
							if naval_target >= 0:
								_apply_splash_damage(naval_attack_destination, 48.0, naval_damage, "player")
							elif target_shipyard >= 0:
								buildings[target_shipyard].hp = maxi(0, int(buildings[target_shipyard].get("hp", 500)) - naval_damage)
							else:
								player_base_hp = maxi(0, player_base_hp - naval_damage)
							unit.attack_cd = 2.0
					else:
						unit.pos += (naval_destination - unit.pos).normalized() * delta * (24.0 if unit.kind == "submarine" else 28.0)
					continue
				if unit.kind == "helicopter":
					var heli_target = _nearest_unit_by_priority(unit.pos, 760.0, "player", ["tank", "artillery", "infantry"])
					var heli_destination: Vector2 = base_pos if heli_target < 0 else units[heli_target].pos
					if unit.pos.distance_to(heli_destination) <= 235.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							_add_visual_effect("air_missile", unit.pos, heli_destination, Color("#ffb56e"), 0.24, 0.0)
							_add_visual_effect("explosion", heli_destination, heli_destination, Color("#ff9b55"), 0.55, 46.0)
							if heli_target >= 0:
								var heli_damage = 58 if units[heli_target].kind == "submarine" else _helicopter_damage(unit)
								_apply_splash_damage(heli_destination, 42.0, heli_damage, "player")
								if units[heli_target].kind == "submarine":
									_add_visual_effect("flash", heli_destination, heli_destination, Color("#7fe8ef"), 0.35, 28.0)
							else:
								player_base_hp = maxi(0, player_base_hp - 26)
							unit.attack_cd = _helicopter_cooldown(unit)
					else:
						unit.pos += (heli_destination - unit.pos).normalized() * delta * 78.0
					continue
				if unit.kind == "builder":
					if unit.has("target"):
						var enemy_builder_target: Vector2 = unit.target
						if unit.pos.distance_to(enemy_builder_target) > 8.0:
							unit.pos += (enemy_builder_target - unit.pos).normalized() * delta * 32.0
						else:
							unit.erase("target")
					continue
				if unit.kind == "tank" or unit.kind == "artillery":
					enemy_landing_support_target = _landing_assault_support_target(unit.pos, "enemy")
					if enemy_landing_support_target >= 0:
						unit["landing_support_active"] = true
						unit["landing_support_target"] = enemy_landing_support_target
					else:
						unit.erase("landing_support_active")
						unit.erase("landing_support_target")
				if unit.kind in ["tank", "infantry", "artillery"]:
					if _update_enemy_retreat(unit, delta):
						continue
					if bool(unit.get("defense_guard", false)) and _update_enemy_defense_guard(unit, i, delta):
						continue
					if unit.kind in ["tank", "infantry"] and _update_enemy_counterattack_reserve(unit, i, delta):
						continue
				if unit.kind == "fighter":
					var air_target = _landing_craft_air_threat_target(unit.pos, "enemy")
					if air_target < 0:
						air_target = _nearest_unit_by_priority(unit.pos, FIGHTER_TARGET_RANGE, "player", ["fighter", "helicopter", "transport_helicopter"])
					if air_target >= 0:
						var air_enemy: Dictionary = units[air_target]
						if unit.pos.distance_to(air_enemy.pos) <= FIGHTER_ATTACK_RANGE:
							unit.attack_cd = unit.get("attack_cd", 0.0) - delta
							if unit.attack_cd <= 0.0:
								_add_visual_effect("air_missile", unit.pos, air_enemy.pos, Color("#ff9b72"), 0.22, 0.0)
								_add_visual_effect("explosion", air_enemy.pos, air_enemy.pos, Color("#ffad72"), 0.42, 24.0)
								air_enemy.hp = maxi(0, int(air_enemy.hp) - _terrain_adjusted_damage(air_enemy, FIGHTER_DAMAGE))
								unit.attack_cd = FIGHTER_ATTACK_COOLDOWN
						else:
							unit.pos += (air_enemy.pos - unit.pos).normalized() * delta * FIGHTER_SPEED
					else:
						var escort_heli_index := -1
						var escort_heli_distance := 260.0
						for escort_index in range(units.size()):
							var escort_candidate: Dictionary = units[escort_index]
							if String(escort_candidate.get("team", "")) != "enemy" or String(escort_candidate.get("kind", "")) != "helicopter" or int(escort_candidate.get("hp", 0)) <= 0:
								continue
							var escort_distance: float = unit.pos.distance_to(escort_candidate.pos)
							if escort_distance < escort_heli_distance:
								escort_heli_distance = escort_distance
								escort_heli_index = escort_index
						if escort_heli_index >= 0:
							var escort_heli: Dictionary = units[escort_heli_index]
							var escort_side := -1.0 if unit.pos.y <= escort_heli.pos.y else 1.0
							var escort_spot: Vector2 = escort_heli.pos + Vector2(-42.0, escort_side * 48.0)
							if unit.pos.distance_to(escort_spot) > 18.0:
								unit.pos += (escort_spot - unit.pos).normalized() * delta * FIGHTER_PATROL_SPEED
							else:
								unit.pos += (enemy_base - unit.pos).normalized() * delta * FIGHTER_PATROL_SPEED * 0.35
						else:
							unit.pos += (enemy_base - unit.pos).normalized() * delta * FIGHTER_PATROL_SPEED
					continue
				if unit.kind in ["tank", "infantry", "artillery"] and _update_enemy_ground_assault(unit, i, delta):
					continue
				# Damaged player aircraft automatically recover at a powered, completed airfield.
				if unit.kind in ["fighter", "helicopter"]:
					var aircraft_ammo := int(unit.get("aircraft_ammo", 8 if unit.kind == "fighter" else 12))
					var aircraft_max_hp: int = _unit_repair_max_hp(unit)
					var aircraft_needs_repair: bool = aircraft_max_hp > 0 and float(unit.hp) <= float(aircraft_max_hp) * 0.30
					if not bool(unit.get("airfield_returning", false)) and (aircraft_ammo <= 0 or (not unit.has("target") and not unit.has("attack_target") and not unit.has("attack_building") and not bool(unit.get("attack_base", false)) and aircraft_needs_repair)):
						var nearest_airfield := -1
						var nearest_airfield_distance := INF
						for airfield_index in range(buildings.size()):
							var recovery_airfield: Dictionary = buildings[airfield_index]
							if String(recovery_airfield.get("kind", "")) != "airfield" or float(recovery_airfield.get("build_progress", 1.0)) < 1.0 or int(recovery_airfield.get("hp", 0)) <= 0 or not _is_player_building_powered(airfield_index):
								continue
							var recovery_distance: float = unit.pos.distance_to(recovery_airfield.pos)
							if recovery_distance < nearest_airfield_distance:
								nearest_airfield_distance = recovery_distance
								nearest_airfield = airfield_index
						if nearest_airfield >= 0:
							var recovery_id := int(buildings[nearest_airfield].get("production_id", -1))
							var recovery_slot := 0
							for queued_aircraft in units:
								if String(queued_aircraft.get("team", "")) == "player" and bool(queued_aircraft.get("airfield_returning", false)) and int(queued_aircraft.get("airfield_recovery_id", -2)) == recovery_id:
									recovery_slot += 1
							_save_aircraft_resume_order(unit)
							unit["airfield_returning"] = true
							unit["airfield_landed"] = false
							unit["airfield_rearm_progress"] = 0.0
							unit["airfield_recovery_id"] = recovery_id
							unit["airfield_recovery_slot"] = recovery_slot
							unit.erase("target")
							unit.erase("attack_target")
							unit.erase("attack_focus_pos")
							unit.erase("attack_base")
							unit.erase("attack_building")
				if bool(unit.get("airfield_returning", false)):
					var recovery_index := -1
					for airfield_index in range(buildings.size()):
						var recovery_airfield: Dictionary = buildings[airfield_index]
						if String(recovery_airfield.get("kind", "")) == "airfield" and int(recovery_airfield.get("production_id", -2)) == int(unit.get("airfield_recovery_id", -1)) and int(recovery_airfield.get("hp", 0)) > 0 and float(recovery_airfield.get("build_progress", 1.0)) >= 1.0 and _is_player_building_powered(airfield_index):
							recovery_index = airfield_index
							break
					if recovery_index < 0:
						unit.erase("airfield_returning")
						unit.erase("airfield_landed")
						unit.erase("airfield_recovery_id")
						unit.erase("airfield_recovery_slot")
						unit.erase("airfield_rearm_progress")
						_restore_aircraft_resume_order(unit)
					else:
						var recovery_airfield_pos: Vector2 = buildings[recovery_index].pos
						var landing_slot := int(unit.get("airfield_recovery_slot", 0))
						var landing_column := landing_slot % 3 - 1
						var landing_row := int(landing_slot / 3)
						var landing_spot := recovery_airfield_pos + Vector2(float(landing_column) * 24.0, 30.0 + float(landing_row) * 20.0)
						var recovery_distance: float = unit.pos.distance_to(landing_spot)
						if recovery_distance > 14.0:
							unit.pos += (landing_spot - unit.pos).normalized() * delta * (92.0 if unit.kind == "fighter" else 68.0)
						else:
							unit.pos = landing_spot
							unit["airfield_landed"] = true
							var rearm_duration := 4.5
							var rearm_progress := minf(rearm_duration, float(unit.get("airfield_rearm_progress", 0.0)) + delta)
							unit["airfield_rearm_progress"] = rearm_progress
							if rearm_progress >= rearm_duration:
								unit["aircraft_ammo"] = 8 if unit.kind == "fighter" else 12
							if rearm_progress >= rearm_duration and float(unit.hp) >= float(_unit_repair_max_hp(unit)) * 0.92:
								# Launch only after rearming and field repairs are both complete.
								unit["airfield_sortie_ready"] = true
								unit["airfield_sortie_launch"] = true
								unit["airfield_sortie_airfield_id"] = int(unit.get("airfield_recovery_id", -1))
								unit.erase("airfield_returning")
								unit.erase("airfield_landed")
								unit.erase("airfield_recovery_id")
								unit.erase("airfield_recovery_slot")
								unit.erase("airfield_rearm_progress")
					continue
				# Amphibious landing support is disabled with the naval system.
				# Never let this legacy automation replace a player's direct land-unit orders.
				if NAVAL_SYSTEM_ENABLED and (unit.kind == "tank" or unit.kind == "artillery"):
					var landing_support_target = _landing_assault_support_target(unit.pos, "player")
					if landing_support_target >= 0:
						if not bool(unit.get("landing_support_active", false)):
							if unit.has("attack_building"):
								unit["landing_support_building"] = int(unit.attack_building)
							if bool(unit.get("attack_base", false)):
								unit["landing_support_base"] = true
							unit["landing_support_active"] = true
						unit.erase("attack_building")
						unit.erase("attack_base")
						unit.attack_target = landing_support_target
					elif bool(unit.get("landing_support_active", false)):
						if unit.has("landing_support_building"):
							unit["attack_building"] = int(unit.landing_support_building)
							unit.erase("landing_support_building")
						if bool(unit.get("landing_support_base", false)):
							unit["attack_base"] = true
						unit.erase("landing_support_base")
						unit.erase("landing_support_active")
						unit.erase("attack_target")
						unit.erase("attack_focus_pos")
				# Recovered aircraft taxi clear of the landing area before resuming flight.
				if unit.kind in ["fighter", "helicopter"] and bool(unit.get("airfield_sortie_launch", false)):
					var sortie_airfield_id := int(unit.get("airfield_sortie_airfield_id", -1))
					var sortie_airfield_index := -1
					for sortie_index in range(buildings.size()):
						if String(buildings[sortie_index].get("kind", "")) == "airfield" and int(buildings[sortie_index].get("production_id", -2)) == sortie_airfield_id and int(buildings[sortie_index].get("hp", 0)) > 0:
							sortie_airfield_index = sortie_index
							break
					if sortie_airfield_index < 0:
						unit.erase("airfield_sortie_launch")
						unit.erase("airfield_sortie_ready")
						unit.erase("airfield_sortie_airfield_id")
						_restore_aircraft_resume_order(unit)
					else:
						var sortie_airfield_pos: Vector2 = buildings[sortie_airfield_index].pos
						var sortie_launch_spot := sortie_airfield_pos + Vector2(0.0, -28.0)
						if unit.pos.distance_to(sortie_launch_spot) > 8.0:
							unit.pos += (sortie_launch_spot - unit.pos).normalized() * delta * (48.0 if unit.kind == "fighter" else 38.0)
							continue
						unit.pos = sortie_launch_spot
						unit.erase("airfield_sortie_launch")
						unit.erase("airfield_sortie_ready")
						unit.erase("airfield_sortie_airfield_id")
						_restore_aircraft_resume_order(unit)
					continue
			if unit.team == "player":
				# Player aircraft use dedicated air-combat movement and weapons.
				# This branch handles explicit player orders only; enemy doctrine is untouched.
				if unit.kind == "transport_helicopter":
					_update_transport_helicopter(unit, delta)
					continue
				if unit.kind in ["fighter", "helicopter"]:
					if unit.has("attack_building"):
						var air_building_index := int(unit.attack_building)
						if air_building_index < 0 or air_building_index >= enemy_buildings.size() or int(enemy_buildings[air_building_index].get("hp", 0)) <= 0:
							unit.erase("attack_building")
							continue
						var air_building: Dictionary = enemy_buildings[air_building_index]
						var air_building_distance: float = unit.pos.distance_to(air_building.pos)
						var air_building_range := 245.0 if unit.kind == "fighter" else 225.0
						if air_building_distance <= air_building_range:
							unit.attack_cd = float(unit.get("attack_cd", 0.0)) - delta
							if unit.attack_cd <= 0.0 and int(unit.get("aircraft_ammo", 8 if unit.kind == "fighter" else 12)) > 0:
								unit["aircraft_ammo"] = maxi(0, int(unit.get("aircraft_ammo", 8 if unit.kind == "fighter" else 12)) - 1)
								var air_building_damage := 26 if unit.kind == "fighter" else _helicopter_damage(unit)
								var air_building_hp_before := int(air_building.hp)
								air_building.hp = maxi(0, air_building_hp_before - air_building_damage)
								_award_unit_experience(unit, air_building_hp_before - int(air_building.hp))
								_add_visual_effect("air_missile", unit.pos, air_building.pos, Color("#ffd18a"), 0.24, 0.0)
								_add_visual_effect("explosion", air_building.pos, air_building.pos, Color("#ffad62"), 0.42, 32.0)
								unit.attack_cd = FIGHTER_ATTACK_COOLDOWN if unit.kind == "fighter" else _helicopter_cooldown(unit)
								if air_building.hp <= 0:
									_remove_destroyed_buildings("enemy")
						else:
							unit.pos += (air_building.pos - unit.pos).normalized() * delta * (FIGHTER_SPEED if unit.kind == "fighter" else 78.0)
						continue
					if bool(unit.get("attack_base", false)):
						var air_base_distance: float = unit.pos.distance_to(enemy_base)
						if air_base_distance <= 250.0:
							unit.attack_cd = float(unit.get("attack_cd", 0.0)) - delta
							if unit.attack_cd <= 0.0 and int(unit.get("aircraft_ammo", 8 if unit.kind == "fighter" else 12)) > 0:
								unit["aircraft_ammo"] = maxi(0, int(unit.get("aircraft_ammo", 8 if unit.kind == "fighter" else 12)) - 1)
								var air_base_damage := 24 if unit.kind == "fighter" else _helicopter_damage(unit)
								enemy_base_hp = maxi(0, enemy_base_hp - air_base_damage)
								unit.attack_cd = FIGHTER_ATTACK_COOLDOWN if unit.kind == "fighter" else _helicopter_cooldown(unit)
								_add_visual_effect("air_missile", unit.pos, enemy_base, Color("#ffd18a"), 0.24, 0.0)
								_add_visual_effect("explosion", enemy_base, enemy_base, Color("#ffad62"), 0.42, 34.0)
						else:
							unit.pos += (enemy_base - unit.pos).normalized() * delta * (FIGHTER_SPEED if unit.kind == "fighter" else 78.0)
						continue
					if unit.has("air_patrol_points") and not unit.has("attack_target") and not unit.has("attack_building") and not bool(unit.get("attack_base", false)):
						var patrol_points: Array = unit.get("air_patrol_points", [])
						if patrol_points.size() >= 2:
							var patrol_threat_kinds: Array[String] = ["fighter", "helicopter", "transport_helicopter"] if unit.kind == "fighter" else ["tank", "artillery", "infantry"]
							var patrol_threat := _nearest_unit_by_priority(unit.pos, 245.0, "enemy", patrol_threat_kinds)
							if patrol_threat >= 0:
								unit["attack_target"] = patrol_threat
								unit["attack_focus_pos"] = units[patrol_threat].pos
								unit["air_patrol_resume"] = true
					var air_enemy_target := int(unit.get("attack_target", -1))
					if air_enemy_target < 0 or air_enemy_target >= units.size() or units[air_enemy_target].team != "enemy" or int(units[air_enemy_target].get("hp", 0)) <= 0:
						if unit.has("attack_focus_pos"):
							var air_preferred_kinds := ["fighter", "helicopter", "transport_helicopter"] if unit.kind == "fighter" else ["tank", "artillery", "infantry"]
							air_enemy_target = _nearest_unit_by_priority(unit.attack_focus_pos, 320.0, "enemy", air_preferred_kinds)
						if air_enemy_target >= 0:
							unit.attack_target = air_enemy_target
						else:
							unit.erase("attack_target")
							unit.erase("attack_focus_pos")
					if air_enemy_target >= 0:
						var air_enemy: Dictionary = units[air_enemy_target]
						unit.attack_focus_pos = air_enemy.pos
						var air_enemy_distance: float = unit.pos.distance_to(air_enemy.pos)
						var air_attack_range := FIGHTER_ATTACK_RANGE if unit.kind == "fighter" else 235.0
						if air_enemy_distance <= air_attack_range:
							unit.attack_cd = float(unit.get("attack_cd", 0.0)) - delta
							if unit.attack_cd <= 0.0 and int(unit.get("aircraft_ammo", 8 if unit.kind == "fighter" else 12)) > 0:
								unit["aircraft_ammo"] = maxi(0, int(unit.get("aircraft_ammo", 8 if unit.kind == "fighter" else 12)) - 1)
								var air_damage := FIGHTER_DAMAGE if unit.kind == "fighter" else _helicopter_damage(unit)
								_add_visual_effect("air_missile", unit.pos, air_enemy.pos, Color("#ffd18a"), 0.22, 0.0)
								if unit.kind == "helicopter":
									_apply_splash_damage(air_enemy.pos, 38.0, air_damage, "enemy", unit)
								else:
									var air_hp_before := int(air_enemy.hp)
									air_enemy.hp = maxi(0, air_hp_before - _terrain_adjusted_damage(air_enemy, air_damage))
									_award_unit_experience(unit, air_hp_before - int(air_enemy.hp))
									_register_unit_kill(unit, air_enemy, air_hp_before)
								_add_visual_effect("explosion", air_enemy.pos, air_enemy.pos, Color("#ffad72"), 0.38, 25.0)
								unit.attack_cd = FIGHTER_ATTACK_COOLDOWN if unit.kind == "fighter" else _helicopter_cooldown(unit)
						else:
							unit.pos += (air_enemy.pos - unit.pos).normalized() * delta * (FIGHTER_SPEED if unit.kind == "fighter" else 78.0)
					elif unit.has("air_patrol_points"):
						var active_patrol_points: Array = unit.get("air_patrol_points", [])
						if active_patrol_points.size() >= 2:
							var patrol_index := clampi(int(unit.get("air_patrol_index", 1)), 0, 1)
							var patrol_waypoint: Vector2 = active_patrol_points[patrol_index]
							if unit.pos.distance_to(patrol_waypoint) > 12.0:
								unit.pos += (patrol_waypoint - unit.pos).normalized() * delta * (FIGHTER_SPEED if unit.kind == "fighter" else 78.0)
							else:
								unit["air_patrol_index"] = 0 if patrol_index == 1 else 1
					elif unit.has("target"):
						var air_move_target: Vector2 = unit.target
						if unit.pos.distance_to(air_move_target) > 10.0:
							unit.pos += (air_move_target - unit.pos).normalized() * delta * (FIGHTER_SPEED if unit.kind == "fighter" else 78.0)
						else:
							unit.erase("target")
					continue
			if bool(unit.get("escort_active", false)):
				var escort_target_id := int(unit.get("escort_target_id", -1))
				var escort_target_index := -1
				for escort_candidate_index in range(units.size()):
					if units[escort_candidate_index].team == "player" and int(units[escort_candidate_index].get("3d_sync_id", -1)) == escort_target_id and String(units[escort_candidate_index].get("kind", "")) == "artillery" and int(units[escort_candidate_index].get("hp", 0)) > 0:
						escort_target_index = escort_candidate_index
						break
				if escort_target_index < 0:
					unit.erase("escort_active")
					unit.erase("escort_target_id")
					unit.erase("escort_offset")
				else:
					var escort_target: Dictionary = units[escort_target_index]
					var escort_offset: Vector2 = unit.get("escort_offset", Vector2(38.0, 0.0))
					var escort_position: Vector2 = escort_target.pos + escort_offset
					var escort_enemy_index := int(unit.get("attack_target", -1))
					if escort_enemy_index >= 0 and (escort_enemy_index >= units.size() or units[escort_enemy_index].team != "enemy" or int(units[escort_enemy_index].get("hp", 0)) <= 0 or units[escort_enemy_index].pos.distance_to(escort_target.pos) > 185.0):
						unit.erase("attack_target")
						unit.erase("attack_focus_pos")
						escort_enemy_index = -1
					if escort_enemy_index < 0 and not unit.has("attack_building"):
						var nearby_escort_enemy := _nearest_enemy_unit(escort_target.pos, 145.0)
						if nearby_escort_enemy >= 0:
							unit["attack_target"] = nearby_escort_enemy
							unit["attack_focus_pos"] = units[nearby_escort_enemy].pos
							escort_enemy_index = nearby_escort_enemy
					if escort_enemy_index < 0 and not unit.has("attack_building"):
						if unit.pos.distance_to(escort_position) > 16.0:
							var escort_direction := _ground_navigation_direction(unit, i, escort_position, delta, 38.0)
							unit.pos += escort_direction * delta * 38.0
						continue
			if bool(unit.get("guard_active", false)):
				var guard_post: Vector2 = unit.get("guard_position", unit.pos)
				var guard_radius := float(unit.get("guard_radius", 180.0))
				var guard_target_index := int(unit.get("attack_target", -1))
				if guard_target_index >= 0 and (guard_target_index >= units.size() or units[guard_target_index].team != "enemy" or int(units[guard_target_index].get("hp", 0)) <= 0 or units[guard_target_index].pos.distance_to(guard_post) > guard_radius):
					unit.erase("attack_target")
					unit.erase("attack_focus_pos")
				if unit.has("attack_building"):
					var guard_building_index := int(unit.attack_building)
					if guard_building_index < 0 or guard_building_index >= enemy_buildings.size() or int(enemy_buildings[guard_building_index].get("hp", 0)) <= 0 or enemy_buildings[guard_building_index].pos.distance_to(guard_post) > guard_radius:
						unit.erase("attack_building")
				if not unit.has("attack_target") and not unit.has("attack_building") and not bool(unit.get("attack_base", false)):
					var guard_enemy_index := -1
					var guard_enemy_distance := guard_radius
					for guard_candidate_index in range(units.size()):
						var guard_candidate: Dictionary = units[guard_candidate_index]
						if guard_candidate.team != "enemy" or int(guard_candidate.get("hp", 0)) <= 0:
							continue
						if String(guard_candidate.get("kind", "")) == "submarine" and not _is_submarine_detected(guard_candidate, "player"):
							continue
						if guard_candidate.pos.distance_to(guard_post) > guard_radius:
							continue
						var guard_candidate_distance: float = unit.pos.distance_to(guard_candidate.pos)
						if guard_candidate_distance < guard_enemy_distance:
							guard_enemy_distance = guard_candidate_distance
							guard_enemy_index = guard_candidate_index
					var guard_building_target := -1
					var guard_building_distance := guard_radius
					for guard_building_index in range(enemy_buildings.size()):
						var guard_building: Dictionary = enemy_buildings[guard_building_index]
						if int(guard_building.get("hp", 0)) <= 0 or guard_building.pos.distance_to(guard_post) > guard_radius:
							continue
						var candidate_distance: float = unit.pos.distance_to(guard_building.pos)
						if candidate_distance < guard_building_distance:
							guard_building_distance = candidate_distance
							guard_building_target = guard_building_index
					if guard_building_target >= 0 and guard_building_distance < guard_enemy_distance:
						unit["attack_building"] = guard_building_target
					elif guard_enemy_index >= 0:
						unit["attack_target"] = guard_enemy_index
						unit["attack_focus_pos"] = units[guard_enemy_index].pos
				if not unit.has("attack_target") and not unit.has("attack_building") and not bool(unit.get("attack_base", false)):
					if unit.pos.distance_to(guard_post) > 12.0:
						var guard_speed := 22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0)
						var guard_direction := _ground_navigation_direction(unit, i, guard_post, delta, guard_speed)
						unit.pos += guard_direction * delta * guard_speed
					continue
			if bool(unit.get("attack_move_active", false)) and not bool(unit.get("guard_active", false)) and not unit.has("attack_building") and not bool(unit.get("attack_base", false)):
				var current_attack_target := int(unit.get("attack_target", -1))
				var has_live_attack_target: bool = current_attack_target >= 0 and current_attack_target < units.size() and String(units[current_attack_target].get("team", "")) == "enemy" and int(units[current_attack_target].get("hp", 0)) > 0
				if not has_live_attack_target:
					var attack_move_unit_target := _nearest_enemy_ground_unit(unit.pos, 420.0 if unit.kind == "artillery" else 235.0)
					var attack_move_unit_distance := INF
					if attack_move_unit_target >= 0:
						attack_move_unit_distance = unit.pos.distance_to(units[attack_move_unit_target].pos)
					var attack_move_building_target := -1
					var attack_move_building_distance := 360.0 if unit.kind == "artillery" else 210.0
					for candidate_building_index in range(enemy_buildings.size()):
						var candidate_building: Dictionary = enemy_buildings[candidate_building_index]
						if int(candidate_building.get("hp", 0)) <= 0:
							continue
						var candidate_distance: float = unit.pos.distance_to(candidate_building.pos)
						if candidate_distance < attack_move_building_distance:
							attack_move_building_distance = candidate_distance
							attack_move_building_target = candidate_building_index
					if attack_move_building_target >= 0 and attack_move_building_distance < attack_move_unit_distance:
						unit["attack_building"] = attack_move_building_target
						unit.erase("attack_target")
						unit.erase("attack_focus_pos")
					elif attack_move_unit_target >= 0:
						unit["attack_target"] = attack_move_unit_target
						unit["attack_focus_pos"] = units[attack_move_unit_target].pos
			if unit.has("attack_building"):
				var building_target = int(unit.attack_building)
				if building_target < 0 or building_target >= enemy_buildings.size():
					unit.erase("attack_building")
					continue
				var target_building: Dictionary = enemy_buildings[building_target]
				var building_distance: float = unit.pos.distance_to(target_building.pos)
				var building_range := 350.0 if unit.kind == "artillery" else 75.0
				if building_distance <= building_range:
					unit.attack_cd = unit.get("attack_cd", 0.0) - delta
					if unit.attack_cd <= 0.0:
						var building_damage = _unit_damage_with_veterancy(unit, 48 if unit.kind == "artillery" else (32 if unit.kind == "tank" else 8))
						var building_hp_before := int(target_building.get("hp", 400))
						target_building.hp = maxi(0, building_hp_before - building_damage)
						_award_unit_experience(unit, building_hp_before - int(target_building.hp))
						_add_visual_effect("explosion" if unit.kind == "artillery" else "flash", target_building.pos, target_building.pos, Color("#ffad62"), 0.45, 30.0)
						unit.attack_cd = 2.0 if unit.kind == "artillery" else 0.9
						if target_building.hp <= 0:
							_remove_destroyed_buildings("enemy")
				else:
					var building_speed := 22.0 if unit.kind == "artillery" else 38.0
					var building_direction := _ground_navigation_direction(unit, i, target_building.pos, delta, building_speed)
					unit.pos += building_direction * delta * building_speed
				continue
			if unit.get("attack_base", false):
				var base_distance: float = unit.pos.distance_to(enemy_base)
				var base_range := 360.0 if unit.kind == "artillery" else 155.0
				if base_distance <= base_range:
					unit.attack_cd = unit.get("attack_cd", 0.0) - delta
					if unit.attack_cd <= 0.0:
						var base_damage := _unit_damage_with_veterancy(unit, 45 if unit.kind == "artillery" else (20 if unit.kind == "tank" else 10))
						var base_hp_before := enemy_base_hp
						enemy_base_hp = maxi(0, enemy_base_hp - base_damage)
						_award_unit_experience(unit, base_hp_before - enemy_base_hp)
						unit.attack_cd = 2.4 if unit.kind == "artillery" else (0.75 if unit.kind == "tank" else 1.0)
				else:
					var base_speed := 22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0)
					var base_direction := _ground_navigation_direction(unit, i, enemy_base, delta, base_speed)
					unit.pos += base_direction * delta * base_speed
				continue
			var enemy_target := int(unit.get("attack_target", -1))
			if enemy_target < 0 or enemy_target >= units.size() or units[enemy_target].team != "enemy" or units[enemy_target].get("hp", 0) <= 0 or String(units[enemy_target].get("kind", "")) in ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine", "landing_craft"]:
				if unit.has("attack_focus_pos"):
					enemy_target = _nearest_enemy_to_focus(unit.attack_focus_pos, 300.0)
				if enemy_target < 0:
					enemy_target = _nearest_enemy_ground_unit(unit.pos, 420.0 if unit.kind == "artillery" else 220.0)
				if enemy_target >= 0:
					unit.attack_target = enemy_target
			if enemy_target >= 0:
				unit.attack_focus_pos = units[enemy_target].pos
				var enemy: Dictionary = units[enemy_target]
				var distance: float = unit.pos.distance_to(enemy.pos)
				var attack_range := 360.0 if unit.kind == "artillery" else 160.0
				var has_group_attack_formation := unit.has("attack_formation_offset")
				var attack_formation_offset: Vector2 = unit.get("attack_formation_offset", Vector2.ZERO)
				var formation_goal: Vector2 = enemy.pos + attack_formation_offset
				var map_size := get_viewport_rect().size
				formation_goal.x = clampf(formation_goal.x, 24.0, map_size.x - 24.0)
				formation_goal.y = clampf(formation_goal.y, 24.0, map_size.y - 24.0)
				var formation_distance: float = unit.pos.distance_to(formation_goal)
				# Group-ordered artillery keeps a useful 185–330px standoff band instead of charging into close combat.
				var artillery_outside_support_band: bool = has_group_attack_formation and unit.kind == "artillery" and (distance < 185.0 or distance > 330.0)
				if not artillery_outside_support_band and distance <= attack_range:
					unit.attack_cd = unit.get("attack_cd", 0.0) - delta
					if unit.attack_cd <= 0.0:
						if unit.kind == "artillery":
							# Telegraph the impact zone and show the muzzle blast before the shell arc.
							_add_visual_effect("targeting", enemy.pos, enemy.pos, Color("#ffcc70"), 0.46, 76.0)
							_add_visual_effect("muzzle", unit.pos, unit.pos, Color("#ffd18a"), 0.20, 18.0)
							_add_visual_effect("shell", unit.pos, enemy.pos, Color("#ffb45e"), 0.42, 66.0)
							_apply_artillery_blast(enemy.pos, 76.0, _unit_damage_with_veterancy(unit, 48), "enemy", unit)
							unit.attack_cd = 2.4
						else:
							var enemy_hp_before := int(enemy.hp)
							var shot_damage := _unit_damage_with_veterancy(unit, 20 if unit.kind == "tank" else 10)
							if unit.kind == "tank":
								shot_damage = _player_armor_penetration_damage(enemy, shot_damage, unit.pos)
							enemy.hp = maxi(0, enemy_hp_before - _terrain_adjusted_damage(enemy, shot_damage))
							_award_unit_experience(unit, enemy_hp_before - int(enemy.hp))
							_register_unit_kill(unit, enemy, enemy_hp_before)
							if unit.kind == "tank":
								var tank_muzzle: Vector2 = unit.pos + Vector2(1.0, 0.0) + Vector2(27.0, 0.0).rotated(_unit_turret_angle(unit))
								unit["gun_recoil"] = 7.0
								_add_visual_effect("muzzle", tank_muzzle, tank_muzzle, Color("#ffd58d"), 0.16, 13.0)
								_add_visual_effect("tank_round", tank_muzzle, enemy.pos, Color("#ffe0a0"), 0.18, 0.0)
							else:
								_add_visual_effect("tracer", unit.pos, enemy.pos, Color("#ffe0a0"), 0.14, 0.0)
							_add_visual_effect("flash", enemy.pos, enemy.pos, Color("#ffb34d"), 0.18, 8.0)
							if unit.kind == "tank" and String(enemy.get("kind", "")) in ["tank", "artillery"]:
								_add_visual_effect("flash", enemy.pos, enemy.pos, Color("#fff0a8"), 0.24, 15.0)
							unit.attack_cd = 0.75 if unit.kind == "tank" else 1.0
					if has_group_attack_formation and formation_distance > 26.0:
						var formation_speed := 22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0)
						var formation_direction := _ground_navigation_direction(unit, i, formation_goal, delta, formation_speed)
						if formation_direction.length_squared() > 0.001:
							unit.pos += formation_direction * delta * formation_speed
				else:
					var combat_speed := 22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0)
					var combat_goal: Vector2 = formation_goal if has_group_attack_formation else enemy.pos
					var combat_direction := _ground_navigation_direction(unit, i, combat_goal, delta, combat_speed)
					unit.pos += combat_direction * delta * combat_speed
			elif unit.has("target"):
				var target: Vector2 = unit.target
				if unit.pos.distance_to(target) > 8.0:
					var move_speed := 22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0)
					var move_direction := _ground_navigation_direction(unit, i, target, delta, move_speed)
					unit.pos += move_direction * delta * move_speed
				else:
					# Clear completed ground move orders; attack-move remains active
					# and can still acquire a nearby hostile on the next simulation tick.
					unit.erase("target")
		_resolve_ground_unit_spacing()
		_resolve_fortification_collisions(wall_collision_origins)
		_cleanup_destroyed_units()
		_resolve_battle_result()
		_update_unit_facing(delta)
		queue_redraw()


func _fortification_resolve_segment(position: Vector2, previous: Vector2, segment_start: Vector2, segment_end: Vector2, radius: float) -> Vector2:
	var segment := segment_end - segment_start
	var segment_length_sq := segment.length_squared()
	if segment_length_sq <= 0.001:
		return position
	var projection := clampf((position - segment_start).dot(segment) / segment_length_sq, 0.0, 1.0)
	var closest := segment_start + segment * projection
	var offset := position - closest
	var distance := offset.length()
	if distance >= radius:
		return position
	var normal := offset.normalized()
	if distance <= 0.001:
		normal = (previous - closest).normalized()
		if normal.length_squared() <= 0.001:
			normal = Vector2.UP
	return closest + normal * radius


func _fortification_resolve_circle(position: Vector2, previous: Vector2, center: Vector2, radius: float) -> Vector2:
	var offset := position - center
	var distance := offset.length()
	if distance >= radius:
		return position
	var normal := offset.normalized()
	if distance <= 0.001:
		normal = (previous - center).normalized()
		if normal.length_squared() <= 0.001:
			normal = Vector2.UP
	return center + normal * radius


func _resolve_fortification_collisions(previous_positions: Array[Vector2]) -> void:
	var snapshot_count := mini(units.size(), previous_positions.size())
	for unit_index in range(snapshot_count):
		var unit: Dictionary = units[unit_index]
		if int(unit.get("hp", 0)) <= 0 or String(unit.get("kind", "")) in ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine", "landing_craft"]:
			continue
		var previous: Vector2 = previous_positions[unit_index]
		var resolved: Vector2 = unit.pos
		var collision_radius := 13.0 if String(unit.get("kind", "")) in ["tank", "artillery"] else 10.0
		for hostile_side in [buildings, enemy_buildings]:
			for fortification in hostile_side:
				var kind := String(fortification.get("kind", ""))
				if int(fortification.get("hp", 0)) <= 0:
					continue
				if kind == "wall":
					resolved = _fortification_resolve_segment(resolved, previous, fortification.pos + Vector2(-31.0, 0.0), fortification.pos + Vector2(31.0, 0.0), collision_radius + 7.0)
				elif kind == "wall_corner":
					resolved = _fortification_resolve_segment(resolved, previous, fortification.pos + Vector2(-31.0, 0.0), fortification.pos + Vector2(10.0, 0.0), collision_radius + 7.0)
					resolved = _fortification_resolve_segment(resolved, previous, fortification.pos + Vector2(10.0, 0.0), fortification.pos + Vector2(10.0, 40.0), collision_radius + 7.0)
				elif kind == "wall_gate":
					# The gate keeps a clear central passage; only its two guard pillars block ground traffic.
					for gate_side in [-1.0, 1.0]:
						var pillar_center: Vector2 = fortification.pos + Vector2(gate_side * 38.0, 0.0)
						resolved = _fortification_resolve_segment(resolved, previous, pillar_center + Vector2(0.0, -17.0), pillar_center + Vector2(0.0, 17.0), collision_radius + 6.0)
				elif kind in ["bunker", "turret", "anti_air", "missile_defense", "missile_silo"]:
					# Ground vehicles and infantry cannot pass through solid defensive structures.
					var structure_radius := 22.0 if kind in ["bunker", "missile_silo"] else (19.0 if kind == "missile_defense" else 16.0)
					resolved = _fortification_resolve_circle(resolved, previous, fortification.pos, collision_radius + structure_radius)
				elif kind in ["command", "barracks", "factory", "power_plant", "supply_depot", "airfield"]:
					# Main base buildings occupy physical ground space; the airfield gets a wider apron clearance.
					var structure_radius := 39.0 if kind == "airfield" else (27.0 if kind == "command" else 24.0)
					resolved = _fortification_resolve_circle(resolved, previous, fortification.pos, collision_radius + structure_radius)
				previous = resolved
		unit.pos = resolved
		units[unit_index] = unit


func _resolve_ground_unit_spacing() -> void:
	# Keep friendly ground formations readable without changing orders or combat ranges.
	var excluded_kinds := ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine", "landing_craft"]
	for pass_index in range(2):
		for first_index in range(units.size()):
			var first: Dictionary = units[first_index]
			if int(first.get("hp", 0)) <= 0 or String(first.get("kind", "")) in excluded_kinds:
				continue
			for second_index in range(first_index + 1, units.size()):
				var second: Dictionary = units[second_index]
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
				units[first_index] = first
				units[second_index] = second


func _resolve_battle_result() -> bool:
	# Resolve base destruction after combat as well as before simulation.
	# This prevents a one-frame delay after the final attack lands.
	if battle_result != "":
		return true
	if enemy_base_hp <= 0:
		battle_result = "انتصرت! دمرت قاعدة العدو"
	elif player_base_hp <= 0:
		battle_result = "هُزمت! سقطت قاعدتك"
	else:
		return false
	_record_battle_result()
	queue_redraw()
	return true


func _cleanup_destroyed_units() -> void:
	# Remove destroyed units to prevent unbounded array growth during long matches.
	# Remap every index-based selection and attack order before the next frame.
	if units.is_empty():
		selected.clear()
		return
	var old_to_new: Dictionary = {}
	var survivors: Array[Dictionary] = []
	for old_index in range(units.size()):
		var candidate: Dictionary = units[old_index]
		if int(candidate.get("hp", 0)) > 0:
			old_to_new[old_index] = survivors.size()
			survivors.append(candidate)
		else:
			# Death presentation is emitted here, while the authoritative record and its position still exist.
			if not bool(candidate.get("wreck_effect_spawned", false)):
				candidate["wreck_effect_spawned"] = true
				var destroyed_kind := String(candidate.get("kind", "tank"))
				if destroyed_kind == "transport_helicopter":
					var lost_passengers := Array(candidate.get("transport_cargo", [])).size()
					if lost_passengers > 0:
						notice = "سقطت مروحية النقل — فُقد %d من الجنود الذين كانوا على متنها" % lost_passengers
						notice_time = 3.2
						candidate["transport_cargo"] = []
						candidate["transport_firing"] = false
						candidate["attack_target_pos"] = Vector2.ZERO
				_add_visual_effect("explosion", candidate.pos, candidate.pos, Color("#d58a4c"), 0.62, 34.0)
				_spawn_environment_particle(candidate.pos + Vector2(-5.0, -8.0), Vector2(-5.0, -18.0), 13.0, 1.8, Color("#45433f"), "smoke")
				if is_instance_valid(battlefield_3d) and battlefield_3d.has_method("spawn_game_unit_destruction_effect"):
					var map_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
					battlefield_3d.call("spawn_game_unit_destruction_effect", candidate.pos, map_rect, destroyed_kind)
	units = survivors
	var remapped_selection: Array[int] = []
	for old_index in selected:
		if old_to_new.has(old_index):
			remapped_selection.append(int(old_to_new[old_index]))
	selected = remapped_selection
	for survivor in units:
		if not survivor.has("attack_target"):
			continue
		var old_target := int(survivor.attack_target)
		if old_to_new.has(old_target):
			survivor.attack_target = int(old_to_new[old_target])
		else:
			survivor.erase("attack_target")


func _add_visual_effect(kind: String, start: Vector2, finish: Vector2, tint: Color, duration: float, radius: float) -> void:
	if kind == "explosion":
		_play_battle_sound("explosion")
	elif kind == "tracer":
		_play_battle_sound("weapon")
	visual_effects.append({
		"id": next_visual_effect_id,
		"kind": kind,
		"start": start,
		"finish": finish,
		"color": tint,
		"life": duration,
		"duration": duration,
		"radius": radius
	})
	next_visual_effect_id += 1
	if kind == "explosion":
		_spawn_environment_particle(finish + Vector2(-5.0, -10.0), Vector2(-8.0, -24.0), 10.0, 1.25, Color("#66645f"), "smoke")
		_spawn_environment_particle(finish + Vector2(7.0, -5.0), Vector2(5.0, -19.0), 8.0, 0.95, Color("#817a6d"), "smoke")
		for dust_index in range(3):
			_spawn_environment_particle(finish + Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 7.0)), Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 2.0)), randf_range(5.0, 9.0), 0.55, Color("#b9a17d"), "dust")

func _update_environment_particles(delta: float) -> void:
	# Expire and drift lightweight smoke/dust particles without touching combat logic.
	for particle_index in range(environment_particles.size() - 1, -1, -1):
		var particle: Dictionary = environment_particles[particle_index]
		particle.life = float(particle.life) - delta
		particle.pos = particle.pos + particle.velocity * delta
		particle.velocity = particle.velocity * (0.96 if particle.kind == "smoke" else 0.82)
		if particle.life <= 0.0:
			environment_particles.remove_at(particle_index)
	# Emit short dust puffs behind moving ground forces.
	if game_started:
		for unit in units:
			if unit.get("hp", 0) <= 0 or not ["tank", "infantry", "artillery"].has(String(unit.kind)):
				continue
			var previous_pos: Vector2 = unit.get("environment_prev_pos", unit.pos)
			var moved_distance := previous_pos.distance_to(unit.pos)
			unit["environment_prev_pos"] = unit.pos
			unit["environment_cd"] = maxf(0.0, float(unit.get("environment_cd", 0.0)) - delta)
			if moved_distance > 1.5 and float(unit.environment_cd) <= 0.0:
				var is_tank: bool = unit.kind == "tank"
				var puff_count := 2 if is_tank else 1
				for puff_index in range(puff_count):
					var offset = Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
					_spawn_environment_particle(unit.pos + offset, Vector2(randf_range(-10.0, -2.0), randf_range(-8.0, -2.0)), 5.5 if is_tank else 3.5, 0.58 if is_tank else 0.42, Color("#bba98b") if map_type == "الساحل الصحراوي" else Color("#85877c"), "dust")
				unit["environment_cd"] = 0.12 if is_tank else 0.2
			if String(unit.kind) == "tank":
				var tank_hp_ratio := float(unit.get("hp", 0)) / 150.0
				unit["damage_smoke_cd"] = maxf(0.0, float(unit.get("damage_smoke_cd", 0.0)) - delta)
				if tank_hp_ratio <= 0.60 and float(unit.damage_smoke_cd) <= 0.0:
					var smoke_origin: Vector2 = unit.pos + Vector2(-7.0, -10.0).rotated(_unit_facing_angle(unit))
					var heavy_damage := tank_hp_ratio <= 0.25
					_spawn_environment_particle(smoke_origin, Vector2(randf_range(-5.0, 5.0), -randf_range(12.0, 21.0)), 7.0 if not heavy_damage else 10.0, 0.95 if not heavy_damage else 1.25, Color("#77736b") if not heavy_damage else Color("#45413c"), "smoke")
					if heavy_damage:
						_spawn_environment_particle(smoke_origin + Vector2(4.0, 3.0), Vector2(randf_range(-8.0, 8.0), -randf_range(3.0, 10.0)), 4.0, 0.42, Color("#e58b3d"), "spark")
					unit["damage_smoke_cd"] = 0.42 if not heavy_damage else 0.24
	while environment_particles.size() > 110:
		environment_particles.pop_front()

func _spawn_environment_particle(pos: Vector2, velocity: Vector2, radius: float, life: float, tint: Color, particle_kind: String) -> void:
	environment_particles.append({"pos": pos, "velocity": velocity, "radius": radius, "life": life, "max_life": life, "color": tint, "kind": particle_kind})

func _draw_environment_particles() -> void:
	for particle in environment_particles:
		var life_ratio = clampf(float(particle.life) / maxf(0.01, float(particle.max_life)), 0.0, 1.0)
		var fade: float = life_ratio * 0.42
		var center: Vector2 = particle.pos
		var radius: float = float(particle.radius) * (1.0 + (1.0 - life_ratio) * (1.25 if particle.kind == "smoke" else 0.55))
		var tint: Color = particle.color
		if particle.kind == "smoke":
			draw_circle(center, radius * 1.25, Color(tint.r * 0.72, tint.g * 0.74, tint.b * 0.76, fade * 0.42))
			draw_circle(center + Vector2(-radius * 0.28, -radius * 0.22), radius * 0.72, Color(tint.r, tint.g, tint.b, fade * 0.52))
		else:
			draw_circle(center, radius, Color(tint.r, tint.g, tint.b, fade * 0.62))

func _player_armor_penetration_damage(target: Dictionary, base_damage: int, attacker_pos: Vector2) -> int:
	# Tank shells distinguish frontal armor from side and rear aspects.
	var target_kind := String(target.get("kind", ""))
	var penetration_multiplier := 1.35 if target_kind == "tank" else (1.15 if target_kind == "artillery" else 1.0)
	var target_facing := float(target.get("facing", 0.0))
	var incoming_angle: float = (attacker_pos - target.pos).angle()
	var aspect_angle := absf(wrapf(incoming_angle - target_facing, -PI, PI))
	var aspect_multiplier := 0.78 if aspect_angle <= 0.78 else (1.20 if aspect_angle >= 2.35 else 1.0)
	return maxi(1, roundi(float(base_damage) * penetration_multiplier * aspect_multiplier))


func _unit_damage_with_veterancy(unit: Dictionary, base_damage: int) -> int:
	var rank := int(unit.get("veterancy", 0))
	var multiplier := 1.0 + (0.08 if rank == 1 else (0.15 if rank >= 2 else 0.0))
	return maxi(1, roundi(float(base_damage) * multiplier))


func _load_commander_profile() -> void:
	var config := ConfigFile.new()
	var load_error := config.load("user://storm_generals_profile.cfg")
	if load_error != OK:
		return
	var stored: Variant = config.get_value("commander", "profile", {})
	if stored is Dictionary:
		for key in commander_profile:
			if stored.has(key):
				commander_profile[key] = stored[key]


func _save_commander_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("commander", "profile", commander_profile)
	var save_error := config.save("user://storm_generals_profile.cfg")
	if save_error != OK:
		push_warning("Could not save commander profile: %s" % error_string(save_error))


func _campaign_secondary_objective_met() -> bool:
	match campaign_mission_index:
		0:
			return player_base_hp >= 500
		1:
			var controlled_points := 0
			for point in supply_points:
				if String(point.get("owner", "")) == "player":
					controlled_points += 1
			return controlled_points >= 2
		2:
			var completed_buildings := 0
			for building in buildings:
				if int(building.get("hp", 0)) > 0 and float(building.get("build_progress", 1.0)) >= 1.0:
					completed_buildings += 1
			return completed_buildings >= 4
		3:
			var has_air := false
			var has_armour := false
			for unit in units:
				if String(unit.get("team", "")) != "player" or int(unit.get("hp", 0)) <= 0:
					continue
				if String(unit.get("kind", "")) in ["fighter", "helicopter", "transport_helicopter"]:
					has_air = true
				if String(unit.get("kind", "")) in ["tank", "artillery"]:
					has_armour = true
			return has_air and has_armour
		4:
			return player_base_hp >= 600
	return false


func _record_battle_result() -> void:
	if battle_result == "" or commander_profile_saved_result == battle_result:
		return
	commander_profile_saved_result = battle_result
	commander_profile["battles_played"] = int(commander_profile.get("battles_played", 0)) + 1
	if enemy_base_hp <= 0:
		commander_profile["victories"] = int(commander_profile.get("victories", 0)) + 1
		if campaign_briefing or faction != "":
			var progress: Dictionary = commander_profile.get("campaign_progress", {})
			var current_progress := int(progress.get(faction, 0))
			if current_progress == campaign_mission_index and current_progress < CAMPAIGN_MISSIONS.size():
				progress[faction] = current_progress + 1
				commander_profile["campaign_progress"] = progress
				var completed_mission: Dictionary = CAMPAIGN_MISSIONS[campaign_mission_index]
				var total_reward := int(completed_mission.reward)
				if _campaign_secondary_objective_met():
					total_reward += int(completed_mission.get("bonus", 0))
					notice = "إنجاز ثانوي مكتمل! مكافأة إضافية — إجمالي المكافأة %d" % total_reward
				else:
					notice = "تم فتح المهمة التالية ومكافأة %d رصيد" % total_reward
				commander_profile["campaign_funds"] = int(commander_profile.get("campaign_funds", 0)) + total_reward
				notice_time = 4.0
	else:
		commander_profile["defeats"] = int(commander_profile.get("defeats", 0)) + 1
	_save_commander_profile()


func _register_unit_kill(attacker: Dictionary, target: Dictionary, target_hp_before: int) -> void:
	if String(attacker.get("team", "")) != "player" or target_hp_before <= 0 or int(target.get("hp", 0)) > 0:
		return
	var kills := int(attacker.get("combat_kills", 0)) + 1
	attacker["combat_kills"] = kills
	var target_kind := String(target.get("kind", ""))
	var air_kills := int(attacker.get("air_kills", 0))
	var armor_kills := int(attacker.get("armor_kills", 0))
	var naval_kills := int(attacker.get("naval_kills", 0))
	if target_kind in ["fighter", "helicopter", "transport_helicopter"]:
		air_kills += 1
		attacker["air_kills"] = air_kills
	elif target_kind in ["tank", "artillery"]:
		armor_kills += 1
		attacker["armor_kills"] = armor_kills
	elif _is_naval_kind(target_kind):
		naval_kills += 1
		attacker["naval_kills"] = naval_kills
	var medals: Array = attacker.get("combat_medals", [])
	var earned := ""
	if kills >= 5 and not medals.has("قاهر الميدان"):
		earned = "قاهر الميدان"
	elif air_kills >= 3 and not medals.has("صياد الجو"):
		earned = "صياد الجو"
	elif armor_kills >= 3 and not medals.has("مدمر الدروع"):
		earned = "مدمر الدروع"
	elif naval_kills >= 3 and not medals.has("سيد البحار"):
		earned = "سيد البحار"
	if earned != "":
		medals.append(earned)
		attacker["combat_medals"] = medals
		var career_medals: Array = commander_profile.get("earned_medals", [])
		if not career_medals.has(earned):
			career_medals.append(earned)
			commander_profile["earned_medals"] = career_medals
		notice = "وسام جديد: %s" % earned
		notice_time = 3.0
	var profile_kinds := {
		"total_kills": 1,
		"air_kills": 1 if target_kind in ["fighter", "helicopter", "transport_helicopter"] else 0,
		"armor_kills": 1 if target_kind in ["tank", "artillery"] else 0,
		"naval_kills": 1 if _is_naval_kind(target_kind) else 0
	}
	for profile_key in profile_kinds:
		commander_profile[profile_key] = int(commander_profile.get(profile_key, 0)) + int(profile_kinds[profile_key])
	_save_commander_profile()


func _award_unit_experience(unit: Dictionary, damage_dealt: int) -> void:
	if String(unit.get("team", "")) != "player" or damage_dealt <= 0:
		return
	var old_rank := int(unit.get("veterancy", 0))
	var xp := float(unit.get("combat_xp", 0.0)) + float(damage_dealt) * 0.5
	unit["combat_xp"] = xp
	var new_rank := 2 if xp >= 250.0 else (1 if xp >= 100.0 else 0)
	if new_rank > old_rank:
		unit["veterancy"] = new_rank
		var rank_name := "نخبة" if new_rank == 2 else "مخضرم"
		notice = "ترقية ميدانية! أصبحت الوحدة %s" % rank_name
		notice_time = 2.8


func _terrain_adjusted_damage(target: Dictionary, raw_damage: int) -> int:
	# Infantry benefit from natural cover in forests, mountains and dense urban theaters.
	# Units stationed near a friendly objective also gain a tactical garrison defense bonus.
	var kind := String(target.get("kind", ""))
	var team := String(target.get("team", ""))
	var damage_multiplier := 1.0
	if team == "player":
		for fortification in buildings:
			if String(fortification.get("kind", "")) != "bunker" or float(fortification.get("build_progress", 1.0)) < 1.0 or int(fortification.get("hp", 0)) <= 0:
				continue
			var bunker_level := maxi(1, int(fortification.get("level", 1)))
			var cover_radius := 82.0 + float(bunker_level - 1) * 8.0
			if target.get("pos", Vector2.ZERO).distance_to(fortification.pos) <= cover_radius:
				damage_multiplier *= 0.78 - float(bunker_level - 1) * 0.04
				break
	if kind == "infantry":
		if map_type == "ساحل الغابات":
			damage_multiplier *= 0.72
		elif map_type == "الساحل الجبلي":
			damage_multiplier *= 0.80
		elif map_type == "المدينة الساحلية":
			damage_multiplier *= 0.76
	for point in supply_points:
		if String(point.get("owner", "neutral")) != team or team == "":
			continue
		var point_pos: Vector2 = point.get("pos", Vector2.ZERO)
		if target.get("pos", Vector2.ZERO).distance_to(point_pos) > 72.0:
			continue
		var point_kind := String(point.get("kind", "supply"))
		var garrison_multiplier := 0.90
		if point_kind == "bridge":
			garrison_multiplier = 0.82
		elif point_kind == "port":
			garrison_multiplier = 0.88
		if kind == "infantry":
			garrison_multiplier = minf(garrison_multiplier, 0.84)
		elif kind == "tank":
			garrison_multiplier = minf(garrison_multiplier, 0.90)
		damage_multiplier *= garrison_multiplier
		break
	return maxi(1, roundi(float(raw_damage) * damage_multiplier))

func _terrain_effect_label() -> String:
	match map_type:
		"ساحل الغابات":
			return "غطاء الغابات: حماية المشاة 28% — الحاميات تحمي النقاط"
		"الساحل الجبلي":
			return "المرتفعات: حماية المشاة 20% — الحاميات تحمي النقاط"
		"المدينة الساحلية":
			return "المباني: حماية المشاة 24% — الحاميات تحمي النقاط"
		_:
			return "الصحراء: الحاميات تمنح حماية قرب نقاط السيطرة"

func _apply_splash_damage(center: Vector2, radius: float, damage: int, target_team: String, attacker: Dictionary = {}) -> void:
	for unit in units:
		if unit.team == target_team and unit.get("hp", 0) > 0 and unit.pos.distance_to(center) <= radius:
			var hp_before := int(unit.hp)
			unit.hp = maxi(0, hp_before - _terrain_adjusted_damage(unit, damage))
			if not attacker.is_empty():
				_award_unit_experience(attacker, hp_before - int(unit.hp))
				_register_unit_kill(attacker, unit, hp_before)

func _apply_artillery_blast(center: Vector2, radius: float, base_damage: int, target_team: String, attacker: Dictionary) -> void:
	# Heavy shells retain meaningful impact at the center while reducing damage toward the blast edge.
	for index in range(units.size()):
		var target: Dictionary = units[index]
		if String(target.get("team", "")) != target_team or int(target.get("hp", 0)) <= 0:
			continue
		if String(target.get("kind", "")) not in ["infantry", "tank", "artillery", "builder"]:
			continue
		var distance: float = target.pos.distance_to(center)
		if distance > radius:
			continue
		var falloff := 1.0 - 0.65 * clampf(distance / maxf(1.0, radius), 0.0, 1.0)
		var shell_damage := maxi(1, roundi(float(base_damage) * falloff))
		var hp_before := int(target.hp)
		target.hp = maxi(0, hp_before - _terrain_adjusted_damage(target, shell_damage))
		_award_unit_experience(attacker, hp_before - int(target.hp))
		_register_unit_kill(attacker, target, hp_before)

func _faction_profile(army: String) -> Dictionary:
	var profile: Dictionary = FACTION_BALANCE.get(army, FACTION_BALANCE["الصيني"])
	return profile


func _helicopter_cost(army: String) -> int:
	return int(_faction_profile(army)["helicopter_cost"])


func _helicopter_damage(unit: Dictionary) -> int:
	return int(_faction_profile(String(unit.get("faction", faction)))["helicopter_damage"])


func _helicopter_cooldown(unit: Dictionary) -> float:
	return float(_faction_profile(String(unit.get("faction", faction)))["helicopter_cooldown"])


func _helicopter_color(unit: Dictionary) -> Color:
	var army: String = unit.get("faction", faction)
	if army == "الأمريكي":
		return Color("#657b52")
	if army == "الصيني":
		return Color("#a94d3d")
	if army == "الجيش العربي":
		return Color("#c0a36b")
	return Color("#d5b64e")

func _naval_damage(unit: Dictionary, target_index: int) -> int:
	# Keep role-specific naval damage while reading faction base damage from one table.
	var kind := String(unit.get("kind", ""))
	if kind == "destroyer" and target_index >= 0 and target_index < units.size() and String(units[target_index].get("kind", "")) == "submarine":
		return 78
	if kind == "submarine":
		return 62
	if kind == "carrier":
		return 24
	return int(_faction_profile(String(unit.get("faction", faction)))["naval_damage"])


func _is_naval_kind(kind: String) -> bool:
	return kind in ["destroyer", "carrier", "submarine", "landing_craft"]


func _landing_craft_air_threat_target(from_pos: Vector2, team: String) -> int:
	# Fighters defend active landing craft before pursuing unrelated air contacts.
	var opposing_team := "player" if team == "enemy" else "enemy"
	var best_target := -1
	var best_score := INF
	for craft in units:
		if craft.team != team or craft.kind != "landing_craft" or craft.get("hp", 0) <= 0:
			continue
		var landing_state := String(craft.get("landing_state", "outbound"))
		if landing_state not in ["outbound", "returning"]:
			continue
		for target_index in range(units.size()):
			var threat: Dictionary = units[target_index]
			if threat.team != opposing_team or threat.get("hp", 0) <= 0:
				continue
			if threat.kind not in ["fighter", "helicopter", "transport_helicopter"]:
				continue
			var craft_distance: float = craft.pos.distance_to(threat.pos)
			if craft_distance > 270.0:
				continue
			var score: float = from_pos.distance_to(threat.pos) + craft_distance * 0.65
			if score < best_score:
				best_score = score
				best_target = target_index
	return best_target


func _update_carrier_fighter(unit: Dictionary, delta: float) -> bool:
	# Carrier-launched fighters return for recovery and rearm after each sortie.
	if not bool(unit.get("carrier_home", false)):
		return false
	var carrier_index := _nearest_friendly_carrier(unit.pos, String(unit.team))
	if carrier_index < 0:
		unit.erase("carrier_home")
		unit.erase("carrier_returning")
		return false
	var carrier_pos: Vector2 = units[carrier_index].pos
	if bool(unit.get("carrier_returning", false)):
		if unit.pos.distance_to(carrier_pos) <= 44.0:
			unit.hp = 120
			unit.attack_cd = 0.0
			unit.carrier_returning = false
			unit.sortie_timer = 24.0
			_add_visual_effect("flash", carrier_pos, carrier_pos, Color("#9ce5f0"), 0.45, 34.0)
			return true
		unit.pos += (carrier_pos - unit.pos).normalized() * delta * 112.0
		return true
	unit.sortie_timer = float(unit.get("sortie_timer", 24.0)) - delta
	if unit.sortie_timer <= 0.0:
		unit.carrier_returning = true
		unit.target = carrier_pos
	return false

func _update_landing_craft(unit: Dictionary, delta: float, landing_destination: Vector2) -> void:
	# Landing craft carry three marines, unload at the hostile shore, then return to their own dock.
	var team := String(unit.team)
	var state := String(unit.get("landing_state", "outbound"))
	var home_pos: Vector2 = unit.get("home_pos", unit.pos)
	if state == "outbound":
		var shore_distance: float = unit.pos.distance_to(landing_destination)
		if shore_distance <= 55.0:
			var passenger_count = int(unit.get("passengers", 3))
			# Keep the three-marine landing squad intact and wait if the team is at capacity.
			if _team_unit_count(team) + passenger_count > MAX_TEAM_UNITS:
				return
			for marine in range(passenger_count):
				var offset_x = -48.0 + marine * 18.0 if team == "player" else 48.0 - marine * 18.0
				var marine_pos := landing_destination + Vector2(offset_x, -34.0)
				var marine_unit: Dictionary = {
					"pos": marine_pos,
					"team": team,
					"kind": "infantry",
					"faction": String(unit.get("faction", faction)),
					"hp": 100 if team == "player" else 80,
					"attack_cd": 0.0,
					"landing_assault": true
				}
				if team == "player":
					var strategic_target = _strategic_enemy_building_index(landing_destination)
					if marine == 0 and strategic_target >= 0:
						marine_unit["attack_building"] = strategic_target
					else:
						marine_unit["attack_base"] = true
				else:
					marine_unit["target"] = base_pos
				units.append(marine_unit)
			unit["passengers"] = 0
			unit["landing_state"] = "returning"
			if team == "player":
				notice = "تم إنزال 3 جنود — سفينة الإنزال عائدة للميناء"
			else:
				notice = "قوات العدو أنزلت مشاتها وتعود لإعادة التحميل"
			notice_time = 2.2
		else:
			var shore_direction: Vector2 = landing_destination - unit.pos
			if shore_direction.length_squared() > 0.01:
				unit.pos += shore_direction.normalized() * delta * 34.0
		return
	if state == "returning":
		var dock_distance: float = unit.pos.distance_to(home_pos)
		if dock_distance <= 48.0:
			unit.pos = home_pos
			unit["landing_state"] = "loading"
			unit["landing_timer"] = 5.0
			if team == "player":
				notice = "وصلت سفينة الإنزال للميناء — إعادة تحميل الجنود"
				notice_time = 2.0
		else:
			var dock_direction: Vector2 = home_pos - unit.pos
			if dock_direction.length_squared() > 0.01:
				unit.pos += dock_direction.normalized() * delta * 42.0
		return
	if state == "loading":
		unit["landing_timer"] = maxf(0.0, float(unit.get("landing_timer", 5.0)) - delta)
		if float(unit["landing_timer"]) <= 0.0:
			unit["passengers"] = 3
			unit["landing_state"] = "outbound"


func _landing_assault_support_target(from_pos: Vector2, team: String) -> int:
	# Tanks and artillery support landing infantry by engaging nearby hostile ground defenders.
	var opposing_team := "enemy" if team == "player" else "player"
	var best_target := -1
	var best_score := INF
	for marine in units:
		if marine.team != team or marine.kind != "infantry" or marine.get("hp", 0) <= 0:
			continue
		if not bool(marine.get("landing_assault", false)):
			continue
		for target_index in range(units.size()):
			var threat: Dictionary = units[target_index]
			if threat.team != opposing_team or threat.get("hp", 0) <= 0:
				continue
			if threat.kind not in ["tank", "artillery", "infantry"]:
				continue
			var marine_distance: float = marine.pos.distance_to(threat.pos)
			if marine_distance > 230.0:
				continue
			var score: float = from_pos.distance_to(threat.pos) + marine_distance * 0.7
			if score < best_score:
				best_score = score
				best_target = target_index
	return best_target


func _enemy_assault_formation_rank(unit_index: int) -> int:
	# Only active assault-line units occupy attack lanes. Base guards and landing-support
	# units have separate orders and must never push the attacking formation out of position.
	var rank := 0
	for index in range(mini(unit_index, units.size())):
		var candidate: Dictionary = units[index]
		if candidate.team != "enemy" or int(candidate.get("hp", 0)) <= 0:
			continue
		if bool(candidate.get("defense_guard", false)) or bool(candidate.get("landing_support_active", false)):
			continue
		if String(candidate.get("kind", "")) in ["tank", "infantry"]:
			rank += 1
	return rank


func _enemy_infantry_support_position(infantry_pos: Vector2, target_pos: Vector2, assault_origin: Vector2, unit_index: int) -> Vector2:
	# Infantry screens the armor from behind instead of forming an unrelated front line.
	var attack_direction: Vector2 = target_pos - assault_origin
	if attack_direction.length_squared() <= 0.01:
		attack_direction = Vector2.LEFT
	else:
		attack_direction = attack_direction.normalized()
	var nearest_tank_index := -1
	var nearest_tank_distance := 180.0
	for candidate_index in range(units.size()):
		var candidate: Dictionary = units[candidate_index]
		if candidate.team != "enemy" or String(candidate.get("kind", "")) != "tank" or int(candidate.get("hp", 0)) <= 0:
			continue
		if bool(candidate.get("defense_guard", false)) or bool(candidate.get("landing_support_active", false)):
			continue
		if candidate.pos.distance_to(target_pos) > 240.0:
			continue
		var escort_distance: float = infantry_pos.distance_to(candidate.pos)
		if escort_distance < nearest_tank_distance:
			nearest_tank_distance = escort_distance
			nearest_tank_index = candidate_index
	if nearest_tank_index < 0:
		return _enemy_ground_assault_formation_position("infantry", target_pos, assault_origin, unit_index)
	var lateral_direction := Vector2(-attack_direction.y, attack_direction.x)
	var lane_side := -1.0 if unit_index % 2 == 0 else 1.0
	return units[nearest_tank_index].pos - attack_direction * 48.0 + lateral_direction * lane_side * 26.0


func _enemy_ground_assault_formation_position(unit_kind: String, target_pos: Vector2, assault_origin: Vector2, unit_index: int) -> Vector2:
	# Armor leads the advance; infantry follows in a staggered lane while artillery keeps its own standoff range.
	var attack_direction: Vector2 = target_pos - assault_origin
	if attack_direction.length_squared() <= 0.01:
		attack_direction = Vector2.LEFT
	else:
		attack_direction = attack_direction.normalized()
	var lateral_direction := Vector2(-attack_direction.y, attack_direction.x)
	var lane_side := -1.0 if unit_index % 2 == 0 else 1.0
	# Each pair gets its own lane depth so larger formations do not stack on the same two tracks.
	var lane_rank := int(floor(float(unit_index) / 2.0)) + 1
	var lane_offset := 22.0 * float(lane_rank)
	var role_offset := Vector2.ZERO
	if unit_kind == "tank":
		role_offset = -attack_direction * 65.0
	elif unit_kind == "infantry":
		role_offset = -attack_direction * 100.0
	return target_pos + role_offset + lateral_direction * lane_side * lane_offset


func _enemy_artillery_formation_rank(unit_index: int) -> int:
	# Only active offensive artillery reserves a fire-support lane; guarded batteries
	# and landing-support attachments use independent positions.
	var rank := 0
	for index in range(mini(unit_index, units.size())):
		var candidate: Dictionary = units[index]
		if candidate.team != "enemy" or int(candidate.get("hp", 0)) <= 0:
			continue
		if bool(candidate.get("defense_guard", false)) or bool(candidate.get("landing_support_active", false)):
			continue
		if String(candidate.get("kind", "")) == "artillery":
			rank += 1
	return rank


func _enemy_artillery_in_firing_band(distance: float) -> bool:
	return distance >= 185.0 and distance <= 330.0


func _enemy_artillery_support_position(target_pos: Vector2, assault_origin: Vector2, unit_index: int) -> Vector2:
	# Artillery trails the armored line and keeps a lateral offset while staying inside its firing envelope.
	var attack_direction: Vector2 = target_pos - assault_origin
	if attack_direction.length_squared() <= 0.01:
		attack_direction = Vector2.LEFT
	else:
		attack_direction = attack_direction.normalized()
	var lateral_direction := Vector2(-attack_direction.y, attack_direction.x)
	var lane_side := -1.0 if unit_index % 2 == 0 else 1.0
	var lane_rank := int(floor(float(unit_index) / 2.0)) + 1
	var lane_offset := minf(70.0 * float(lane_rank), 210.0)
	return target_pos - attack_direction * 250.0 + lateral_direction * lane_side * lane_offset


func _enemy_ground_assault_flank_anchor(target_pos: Vector2, assault_origin: Vector2, unit_index: int) -> Vector2:
	# When a target is covered by several defenses, approach from the less protected flank.
	if _enemy_ground_target_defense_risk(target_pos) < 1.15:
		return target_pos
	var attack_direction: Vector2 = target_pos - assault_origin
	if attack_direction.length_squared() <= 0.01:
		attack_direction = Vector2.LEFT
	else:
		attack_direction = attack_direction.normalized()
	var lateral_direction := Vector2(-attack_direction.y, attack_direction.x)
	var left_flank: Vector2 = target_pos - lateral_direction * 115.0
	var right_flank: Vector2 = target_pos + lateral_direction * 115.0
	var left_risk := _enemy_ground_target_defense_risk(left_flank)
	var right_risk := _enemy_ground_target_defense_risk(right_flank)
	if absf(left_risk - right_risk) <= 0.08:
		return left_flank if unit_index % 2 == 0 else right_flank
	return left_flank if left_risk < right_risk else right_flank


func _update_enemy_ground_assault(unit: Dictionary, unit_index: int, delta: float) -> bool:
	# Execute the enemy's land doctrine: armor leads, infantry screens, artillery stays in support.
	var unit_kind := String(unit.get("kind", ""))
	if unit_kind not in ["tank", "infantry", "artillery"]:
		return false
	var preferred_pos: Vector2 = unit.get("attack_focus_pos", Vector2(-1000000.0, -1000000.0))
	var target_index := _select_enemy_ground_assault_target(unit.pos, preferred_pos)
	# When the nearest hostile is far from the frontline, secure income first.
	# This gives the enemy a meaningful objective between major engagements.
	if target_index >= 0 and unit.pos.distance_to(units[target_index].pos) > 360.0:
		target_index = -1
	if target_index < 0:
		var supply_objective_index := _enemy_best_supply_objective(unit.pos)
		if supply_objective_index >= 0:
			unit.erase("attack_target")
			unit.erase("attack_focus_pos")
			var supply_objective_pos: Vector2 = supply_points[supply_objective_index].pos
			var objective_distance: float = unit.pos.distance_to(supply_objective_pos)
			if objective_distance > 48.0:
				var objective_speed := 22.0 if unit_kind == "artillery" else (55.0 if unit_kind == "infantry" else 36.0)
				var objective_direction := _ground_navigation_direction(unit, unit_index, supply_objective_pos, delta, objective_speed)
				unit.pos += objective_direction * delta * objective_speed
			return true
	var target_pos: Vector2 = base_pos
	if target_index >= 0:
		target_pos = units[target_index].pos
		unit["attack_target"] = target_index
		unit["attack_focus_pos"] = target_pos
	else:
		unit.erase("attack_target")
		unit.erase("attack_focus_pos")
	var attack_direction: Vector2 = target_pos - enemy_base
	if attack_direction.length_squared() <= 0.01:
		attack_direction = Vector2.LEFT
	else:
		attack_direction = attack_direction.normalized()
	var formation_goal: Vector2
	if unit_kind == "artillery":
		formation_goal = _enemy_artillery_support_position(target_pos, enemy_base, _enemy_artillery_formation_rank(unit_index))
	else:
		var approach_anchor := _enemy_ground_assault_flank_anchor(target_pos, enemy_base, unit_index)
		if unit_kind == "infantry":
			formation_goal = _enemy_infantry_support_position(unit.pos, approach_anchor, enemy_base, _enemy_assault_formation_rank(unit_index))
		else:
			formation_goal = _enemy_ground_assault_formation_position(unit_kind, approach_anchor, enemy_base, _enemy_assault_formation_rank(unit_index))
	var weapon_range := 300.0 if unit_kind == "artillery" else (150.0 if unit_kind == "tank" else 105.0)
	var target_distance: float = unit.pos.distance_to(target_pos)
	if target_index >= 0 and target_distance <= weapon_range:
		unit["attack_cd"] = float(unit.get("attack_cd", 0.0)) - delta
		if float(unit.get("attack_cd", 0.0)) <= 0.0:
			var threat: Dictionary = units[target_index]
			if unit_kind == "artillery":
				_add_visual_effect("targeting", threat.pos, threat.pos, Color("#ffcc70"), 0.46, 76.0)
				_add_visual_effect("muzzle", unit.pos, unit.pos, Color("#ffd18a"), 0.20, 18.0)
				_add_visual_effect("shell", unit.pos, threat.pos, Color("#ffb45e"), 0.42, 66.0)
				_apply_artillery_blast(threat.pos, 76.0, _unit_damage_with_veterancy(unit, 48), "player", unit)
				unit["attack_cd"] = 2.4
			else:
				var hp_before := int(threat.get("hp", 0))
				var base_damage := 20 if unit_kind == "tank" else 10
				var damage := _unit_damage_with_veterancy(unit, base_damage)
				threat["hp"] = maxi(0, hp_before - _terrain_adjusted_damage(threat, damage))
				_award_unit_experience(unit, hp_before - int(threat["hp"]))
				_register_unit_kill(unit, threat, hp_before)
				_add_visual_effect("tracer" if unit_kind == "tank" else "flash", unit.pos, threat.pos, Color("#ffe0a0"), 0.18, 8.0)
				unit["attack_cd"] = 0.75 if unit_kind == "tank" else 1.0
		return true
	if target_index < 0 and target_distance <= (360.0 if unit_kind == "artillery" else (155.0 if unit_kind == "tank" else 105.0)):
		unit["attack_cd"] = float(unit.get("attack_cd", 0.0)) - delta
		if float(unit.get("attack_cd", 0.0)) <= 0.0:
			var base_damage := _unit_damage_with_veterancy(unit, 45 if unit_kind == "artillery" else (20 if unit_kind == "tank" else 10))
			var hp_before := player_base_hp
			player_base_hp = maxi(0, player_base_hp - base_damage)
			_award_unit_experience(unit, hp_before - player_base_hp)
			_add_visual_effect("explosion" if unit_kind == "artillery" else "tracer", base_pos, base_pos, Color("#ffad62"), 0.35, 34.0)
			unit["attack_cd"] = 2.4 if unit_kind == "artillery" else (0.75 if unit_kind == "tank" else 1.0)
		return true
	var goal_distance: float = unit.pos.distance_to(formation_goal)
	var move_speed := 22.0 if unit_kind == "artillery" else (36.0 if unit_kind == "tank" else 55.0)
	var movement_goal := formation_goal
	# Close the final gap only when a formation slot still leaves the unit outside weapon range.
	if goal_distance <= 18.0 and target_distance > weapon_range:
		movement_goal = target_pos
	var move_direction := _ground_navigation_direction(unit, unit_index, movement_goal, delta, move_speed)
	if move_direction.length_squared() > 0.001:
		unit.pos += move_direction * delta * move_speed
	return true

func _strategic_enemy_building_index(from_pos: Vector2) -> int:
	# Landing infantry prioritize production and air facilities, then defensive assets.
	var best_index := -1
	var best_priority := -1
	var best_distance := INF
	for i in range(enemy_buildings.size()):
		var building: Dictionary = enemy_buildings[i]
		if int(building.get("hp", 0)) <= 0:
			continue
		var priority := 1
		match String(building.get("kind", "")):
			"missile_silo":
				# Remove a strategic missile threat before it can cycle another launch.
				priority = 6
			"barracks", "factory":
				priority = 5
			"airfield", "power_plant":
				priority = 4
			"shipyard":
				priority = 2
			"turret", "anti_air", "missile_defense":
				priority = 2
			_:
				priority = 1
		var distance: float = from_pos.distance_to(building.pos)
		if priority > best_priority or (priority == best_priority and distance < best_distance):
			best_priority = priority
			best_distance = distance
			best_index = i
	return best_index


func _nearest_friendly_landing_craft(from_pos: Vector2, team: String) -> int:
	var best_index = -1
	var best_distance := INF
	for i in units.size():
		var candidate: Dictionary = units[i]
		if candidate.team != team or candidate.kind != "landing_craft" or candidate.get("hp", 0) <= 0:
			continue
		var state := String(candidate.get("landing_state", "outbound"))
		if state not in ["outbound", "returning"]:
			continue
		var distance: float = from_pos.distance_to(candidate.pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _nearest_friendly_carrier(from_pos: Vector2, team: String) -> int:
	var best_index = -1
	var best_distance := INF
	for i in units.size():
		if units[i].team != team or units[i].kind != "carrier" or units[i].get("hp", 0) <= 0:
			continue
		var distance: float = from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _best_naval_target(from_pos: Vector2, target_team: String, attacker_kind: String) -> int:
	# Naval units select targets by tactical value, not distance alone.
	# Submarines remain hidden until a destroyer/helicopter provides sonar detection.
	var best_index := -1
	var best_score := INF
	var observer_team := "enemy" if target_team == "player" else "player"
	for i in units.size():
		var candidate: Dictionary = units[i]
		if candidate.team != target_team or not _is_naval_kind(String(candidate.kind)) or candidate.get("hp", 0) <= 0:
			continue
		if candidate.kind == "submarine" and not _is_submarine_detected(candidate, observer_team):
			continue
		var priority := 0.0
		match attacker_kind:
			"destroyer":
				match String(candidate.kind):
					"submarine": priority = 210.0
					"landing_craft": priority = 105.0
					"carrier": priority = 85.0
					"destroyer": priority = 65.0
			"submarine":
				match String(candidate.kind):
					"carrier": priority = 190.0
					"destroyer": priority = 125.0
					"landing_craft": priority = 95.0
					"submarine": priority = 35.0
			"carrier":
				match String(candidate.kind):
					"destroyer": priority = 115.0
					"carrier": priority = 90.0
					"landing_craft": priority = 70.0
					"submarine": priority = 45.0
			_:
				priority = 0.0
		var score: float = from_pos.distance_to(candidate.pos) - priority
		if score < best_score:
			best_score = score
			best_index = i
	return best_index

func _is_submarine_detected(submarine: Dictionary, observer_team: String) -> bool:
	for observer in units:
		if observer.team != observer_team or observer.get("hp", 0) <= 0:
			continue
		var detection_range := 190.0 if observer.kind == "destroyer" else (155.0 if observer.kind == "helicopter" else 0.0)
		if detection_range > 0.0 and observer.pos.distance_to(submarine.pos) <= detection_range:
			return true
	return false

func _update_submarine_detection() -> void:
	for submarine in units:
		if submarine.kind != "submarine" or submarine.get("hp", 0) <= 0:
			continue
		var observer_team := "enemy" if submarine.team == "player" else "player"
		var reveal_key := "sonar_revealed_to_enemy" if observer_team == "enemy" else "sonar_revealed_to_player"
		var detected := _is_submarine_detected(submarine, observer_team)
		if detected and not bool(submarine.get(reveal_key, false)):
			_add_visual_effect("flash", submarine.pos, submarine.pos, Color("#70e8ef"), 0.55, 42.0)
			notice = "كشف السونار غواصة معادية!" if observer_team == "player" else "رصد العدو غواصتك بالسونار!"
			notice_time = 1.8
		submarine[reveal_key] = detected

func _nearest_player_ground_unit(from_pos: Vector2, max_distance: float = 99999.0) -> int:
	# Ground troops and artillery must not divert toward aircraft or naval units.
	var best_index := -1
	var best_distance := max_distance
	for candidate_index in range(units.size()):
		var candidate: Dictionary = units[candidate_index]
		if candidate.team != "player" or candidate.get("hp", 0) <= 0:
			continue
		if not ["infantry", "tank", "artillery"].has(String(candidate.kind)):
			continue
		var distance: float = from_pos.distance_to(candidate.pos)
		if distance < best_distance:
			best_distance = distance
			best_index = candidate_index
	return best_index


func _enemy_ground_target_defense_risk(target_pos: Vector2) -> float:
	# Estimate the defensive screen around a player ground target.
	# Ground assaults should prefer exposed threats over targets covered by several defenses.
	var risk := 0.0
	for defense in buildings:
		if int(defense.get("hp", 0)) <= 0 or float(defense.get("build_progress", 1.0)) < 1.0:
			continue
		var defense_kind := String(defense.get("kind", ""))
		var weight := 0.0
		match defense_kind:
			"turret":
				weight = 1.0
			"anti_air":
				weight = 0.65
			"missile_defense":
				weight = 0.8
		if weight > 0.0:
			var distance: float = defense.pos.distance_to(target_pos)
			if distance <= 240.0:
				risk += weight * (1.0 - distance / 300.0)
	return risk


func _select_enemy_ground_assault_target(from_pos: Vector2 = Vector2.ZERO, preferred_pos: Vector2 = Vector2(-1000000.0, -1000000.0)) -> int:
	# Ground formations engage ground threats; air threats belong to fighters and anti-air defenses.
	# A unit-specific distance term distributes attackers across separate threats instead of making every squad chase one global target.
	var best_index := -1
	var best_score := INF
	var preferred_index := -1
	var preferred_score := INF
	var preferred_distance := INF
	for candidate_index in range(units.size()):
		var candidate: Dictionary = units[candidate_index]
		if candidate.team != "player" or candidate.get("hp", 0) <= 0:
			continue
		if not ["infantry", "tank", "artillery"].has(String(candidate.kind)):
			continue
		var asset_distance: float = candidate.pos.distance_to(enemy_base)
		for protected_building in enemy_buildings:
			if int(protected_building.get("hp", 0)) <= 0:
				continue
			asset_distance = minf(asset_distance, candidate.pos.distance_to(protected_building.pos) + 35.0)
		var threat_priority := 0.0
		match String(candidate.kind):
			"artillery":
				threat_priority = 85.0
			"tank":
				threat_priority = 65.0
			"infantry":
				threat_priority = 15.0
		# Let the selected doctrine influence target choice as well as production.
		# Anti-armor doctrine hunts tanks; area-denial doctrine suppresses artillery
		# and infantry concentrations before they can threaten the base.
		match enemy_strategy:
			"armor_breaker":
				if String(candidate.kind) == "tank":
					threat_priority += 42.0
			"area_denial":
				if String(candidate.kind) == "artillery":
					threat_priority += 32.0
				elif String(candidate.kind) == "infantry":
					threat_priority += 22.0
		var defensive_risk := _enemy_ground_target_defense_risk(candidate.pos)
		var score: float = asset_distance * 0.35 + from_pos.distance_to(candidate.pos) * 0.85 + defensive_risk * 78.0 - threat_priority
		if score < best_score:
			best_score = score
			best_index = candidate_index
		var lock_distance: float = candidate.pos.distance_to(preferred_pos)
		if preferred_pos.x > -999999.0 and lock_distance <= 120.0 and lock_distance < preferred_distance:
			preferred_distance = lock_distance
			preferred_score = score
			preferred_index = candidate_index
	# Keep the current focus while it remains tactically relevant; a wider hysteresis window
	# prevents the formation from oscillating between nearby targets as units move.
	# A clearly more dangerous target still overrides the lock immediately.
	if preferred_index >= 0 and preferred_score <= best_score + 60.0:
		return preferred_index
	return best_index


func _nearest_unit_by_priority(from_pos: Vector2, max_distance: float, target_team: String, preferred_kinds: Array) -> int:
	# Air units prefer targets suited to their role, then fall back to the nearest visible enemy.
	var observer_team := "player" if target_team == "enemy" else "enemy"
	for priority_pass in range(2):
		var best_index = -1
		var best_distance := max_distance
		for candidate_index in range(units.size()):
			var candidate: Dictionary = units[candidate_index]
			if candidate.team != target_team or candidate.get("hp", 0) <= 0:
				continue
			if candidate.kind == "submarine" and not _is_submarine_detected(candidate, observer_team):
				continue
			if priority_pass == 0 and not preferred_kinds.has(String(candidate.kind)):
				continue
			var distance: float = from_pos.distance_to(candidate.pos)
			if distance < best_distance:
				best_distance = distance
				best_index = candidate_index
		if best_index >= 0:
			return best_index
	return -1


func _priority_air_target(from_pos: Vector2, target_team: String, max_distance: float) -> int:
	# Select aircraft that threaten valuable installations, while retaining fighter-first priority.
	var protected_assets: Array = buildings if target_team == "enemy" else enemy_buildings
	var best_index := -1
	var best_score := INF
	for candidate_index in range(units.size()):
		var candidate: Dictionary = units[candidate_index]
		if String(candidate.get("team", "")) != target_team or int(candidate.get("hp", 0)) <= 0:
			continue
		var candidate_kind := String(candidate.get("kind", ""))
		if candidate_kind not in ["fighter", "helicopter", "transport_helicopter"]:
			continue
		var defense_distance: float = from_pos.distance_to(candidate.pos)
		if defense_distance > max_distance:
			continue
		var asset_threat_distance := 520.0
		var asset_priority := 0.0
		for asset in protected_assets:
			if int(asset.get("hp", 0)) <= 0:
				continue
			var asset_kind := String(asset.get("kind", ""))
			if asset_kind not in ["airfield", "power_plant", "factory", "missile_silo", "barracks"]:
				continue
			var threat_distance: float = candidate.pos.distance_to(asset.pos)
			if threat_distance < asset_threat_distance:
				asset_threat_distance = threat_distance
				asset_priority = 90.0 if asset_kind == "airfield" else (72.0 if asset_kind == "power_plant" else (60.0 if asset_kind == "factory" or asset_kind == "missile_silo" else 42.0))
		var kind_priority := 34.0 if candidate_kind == "fighter" else (8.0 if candidate_kind == "helicopter" else -12.0)
		var score: float = defense_distance * 0.55 + asset_threat_distance * 0.75 - asset_priority - kind_priority
		if score < best_score:
			best_score = score
			best_index = candidate_index
	return best_index


func _enemy_air_defense_build_position() -> Vector2:
	# Place new batteries around strategic installations and keep them spread apart.
	var protected_assets: Array = []
	for building in enemy_buildings:
		if int(building.get("hp", 0)) > 0 and String(building.get("kind", "")) in ["airfield", "power_plant", "factory", "missile_silo", "barracks"]:
			protected_assets.append(building)
	if protected_assets.is_empty():
		return _enemy_build_position()
	var arena_size := get_viewport_rect().size
	var best_position := Vector2(-1.0, -1.0)
	var best_score := INF
	for asset in protected_assets:
		for attempt in range(10):
			var angle := randf_range(0.0, TAU)
			var radius := randf_range(105.0, 145.0)
			var candidate: Vector2 = asset.pos + Vector2(cos(angle), sin(angle)) * radius
			candidate.x = clampf(candidate.x, arena_size.x * 0.52, arena_size.x - 65.0)
			candidate.y = clampf(candidate.y, 105.0, arena_size.y - 105.0)
			if candidate.distance_to(enemy_base) < 90.0:
				continue
			var occupied := false
			var nearest_battery := INF
			for existing in enemy_buildings:
				var existing_kind := String(existing.get("kind", ""))
				var separation: float = candidate.distance_to(existing.pos)
				if separation < 82.0:
					occupied = true
					break
				if existing_kind == "anti_air" and int(existing.get("hp", 0)) > 0:
					nearest_battery = minf(nearest_battery, separation)
			if occupied:
				continue
			var asset_distance: float = candidate.distance_to(asset.pos)
			var spacing_penalty := maxf(0.0, 145.0 - nearest_battery) * 2.0
			var score: float = asset_distance + spacing_penalty
			if score < best_score:
				best_score = score
				best_position = candidate
	if best_position.x < 0.0:
		return _enemy_build_position()
	return best_position


func _nearest_player_unit(from_pos: Vector2, air_only: bool = false) -> int:
	var best_index = -1
	var best_distance := INF
	for i in units.size():
		if units[i].team != "player" or units[i].get("hp", 0) <= 0:
			continue
		if units[i].kind == "submarine" and not _is_submarine_detected(units[i], "enemy"):
			continue
		if air_only and units[i].kind not in ["fighter", "helicopter", "transport_helicopter"]:
			continue
		var distance: float = from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _nearest_enemy_to_focus(focus_pos: Vector2, max_distance: float) -> int:
	# Reacquire one common target near the last squad focus point so a commanded
	# group stays together after its original target is destroyed.
	var best_index := -1
	var best_distance := max_distance
	for candidate_index in range(units.size()):
		var candidate: Dictionary = units[candidate_index]
		if candidate.team != "enemy" or candidate.get("hp", 0) <= 0:
			continue
		if candidate.kind == "submarine" and not _is_submarine_detected(candidate, "player"):
			continue
		var distance: float = focus_pos.distance_to(candidate.pos)
		if distance < best_distance:
			best_distance = distance
			best_index = candidate_index
	return best_index


func _nearest_enemy_ground_unit(from_pos: Vector2, max_distance: float) -> int:
	var best_index := -1
	var best_distance := max_distance
	for i in range(units.size()):
		var candidate: Dictionary = units[i]
		if String(candidate.get("team", "")) != "enemy" or int(candidate.get("hp", 0)) <= 0 or bool(candidate.get("retreating", false)):
			continue
		if String(candidate.get("kind", "")) in ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine", "landing_craft"]:
			continue
		var distance := from_pos.distance_to(candidate.pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _nearest_enemy_unit(from_pos: Vector2, max_distance: float, air_only: bool = false) -> int:
	var best_index = -1
	var best_distance := max_distance
	for i in units.size():
		if units[i].team != "enemy" or units[i].get("hp", 0) <= 0:
			continue
		if units[i].kind == "submarine" and not _is_submarine_detected(units[i], "player"):
			continue
		if air_only and units[i].kind not in ["fighter", "helicopter", "transport_helicopter"]:
			continue
		var distance: float = from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _unit_weapon_angle(unit: Dictionary) -> float:
	# Visual-only aiming: resolve the current tactical target without changing combat rules.
	var target_pos: Vector2 = unit.pos
	var found_target := false
	var target_index := -1
	if unit.has("attack_building") and unit.team == "player":
		var building_index = int(unit.attack_building)
		if building_index >= 0 and building_index < enemy_buildings.size():
			target_pos = enemy_buildings[building_index].pos
			found_target = true
	elif unit.team == "player":
		target_index = int(unit.get("attack_target", -1))
		if target_index >= 0 and target_index < units.size() and units[target_index].team == "enemy" and units[target_index].get("hp", 0) > 0:
			target_pos = units[target_index].pos
			found_target = true
		else:
			target_index = _nearest_enemy_unit(unit.pos, 520.0)
			if target_index >= 0:
				target_pos = units[target_index].pos
				found_target = true
	elif unit.team == "enemy":
		target_index = _nearest_player_unit(unit.pos)
		if target_index >= 0:
			target_pos = units[target_index].pos
			found_target = true
	if not found_target and unit.has("target"):
		target_pos = unit.target
		found_target = true
	if not found_target:
		target_pos = enemy_base if unit.team == "player" else base_pos
	var direction: Vector2 = target_pos - unit.pos
	if direction.length_squared() < 0.01:
		return 0.0
	return direction.angle()

func _unit_rotated_point(origin: Vector2, local_point: Vector2, angle: float) -> Vector2:
	return origin + local_point.rotated(angle)


func _unit_polygon_points(origin: Vector2, local_points: PackedVector2Array, angle: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for local_point in local_points:
		points.append(_unit_rotated_point(origin, local_point, angle))
	return points


func _rotated_rect_points(center: Vector2, dimensions: Vector2, angle: float) -> PackedVector2Array:
	var half = dimensions * 0.5
	return _unit_polygon_points(center, PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	]), angle)


func _unit_facing_angle(unit: Dictionary) -> float:
	return float(unit.get("facing", _unit_weapon_angle(unit)))


func _unit_turret_angle(unit: Dictionary) -> float:
	return float(unit.get("turret_facing", _unit_weapon_angle(unit)))


func _update_unit_facing(delta: float) -> void:
	for unit in units:
		var current_pos: Vector2 = unit.pos
		var previous_pos: Vector2 = unit.get("visual_previous_pos", current_pos)
		var movement := current_pos - previous_pos
		if movement.length_squared() > 4.0:
			var desired_angle = movement.angle()
			var current_angle := float(unit.get("facing", desired_angle))
			unit.facing = lerp_angle(current_angle, desired_angle, clampf(delta * 9.0, 0.0, 1.0))
		if String(unit.get("team", "")) == "player" and String(unit.get("kind", "")) == "tank":
			var desired_turret_angle := _unit_weapon_angle(unit)
			var current_turret_angle := float(unit.get("turret_facing", desired_turret_angle))
			unit.turret_facing = lerp_angle(current_turret_angle, desired_turret_angle, clampf(delta * 5.5, 0.0, 1.0))
			unit["gun_recoil"] = move_toward(float(unit.get("gun_recoil", 0.0)), 0.0, delta * 34.0)
		unit.visual_previous_pos = current_pos


func _draw() -> void:
	var size = get_viewport_rect().size
	if game_started and use_3d_view:
		_draw_3d_view_hud(size)
		return
	_draw_terrain(size)
	_draw_spring_sun(size)
	# Layered coastline, beach and navigable sea lane
	draw_rect(Rect2(0, size.y * 0.675, size.x, size.y * 0.065), Color("#b6a078"))
	draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color("#1d435d"))
	draw_rect(Rect2(0, size.y * 0.72, size.x, 7), Color("#d2c092"))
	for wave in range(10):
		var wy = size.y * 0.745 + wave * 19.0
		var wave_x := float((wave * 83) % maxi(1, int(size.x)))
		draw_line(Vector2(wave_x, wy), Vector2(minf(size.x, wave_x + size.x * 0.34), wy + 4), Color(0.58, 0.82, 0.9, 0.17), 2.0)
	# Rocky headlands frame the harbor entrance
	for rock in range(7):
		var rx = float(rock) * size.x / 6.0
		var ry: float = size.y * (0.665 + float((rock % 2)) * 0.018)
		draw_circle(Vector2(rx, ry), 8.0 + float(rock % 3) * 3.0, Color("#7d806a"))
	# A navigation buoy marks the sea lane
	draw_circle(Vector2(size.x * 0.82, size.y * 0.79), 7, Color("#e6c36b"))
	draw_line(Vector2(size.x * 0.82, size.y * 0.79), Vector2(size.x * 0.82, size.y * 0.79 - 16), Color("#e6c36b"), 3.0)
	_draw_supply_points()
	_draw_missiles()
	_draw_base(base_pos, Color("#3977bd"), "قاعدتك")
	_draw_base(enemy_base, Color("#b94b42"), "قاعدة العدو")
	_draw_base_health(base_pos, player_base_hp)
	_draw_base_health(enemy_base, enemy_base_hp)
	for building_index in buildings.size():
		var building: Dictionary = buildings[building_index]
		var is_captured = bool(building.get("captured", false))
		_draw_building(building.pos, building.kind, false, is_captured)
		if building_index == selected_player_building:
			draw_arc(building.pos, 41.0, 0.0, TAU, 48, Color("#8be0a0"), 3.0)
		if float(building.get("build_progress", 1.0)) < 1.0:
			_draw_construction_progress(building.pos, float(building.get("build_progress", 0.0)))
		var player_building_hp := int(building.get("hp", 400))
		var player_building_max_hp := _building_max_hp(building)
		_draw_building_health(building.pos, player_building_hp, player_building_max_hp)
		if _building_needs_repair_warning(player_building_hp, player_building_max_hp):
			_draw_building_repair_warning(building.pos)
	for building_index in enemy_buildings.size():
		var building: Dictionary = enemy_buildings[building_index]
		_draw_building(building.pos, building.kind, true)
		if float(building.get("build_progress", 1.0)) < 1.0:
			_draw_construction_progress(building.pos, float(building.get("build_progress", 0.0)))
		if building_index == selected_enemy_building:
			draw_arc(building.pos, 39.0, 0.0, TAU, 48, Color("#ffe27a"), 3.0)
		_draw_building_health(building.pos, int(building.get("hp", 400)), _building_max_hp(building))
		if float(building.get("capture_progress", 0.0)) > 0.0:
			_draw_capture_progress(building.pos, float(building.capture_progress))
	for i in units.size():
		var u = units[i]
		if u.get("hp", 0) <= 0:
			continue
		if u.team == "enemy" and u.kind == "submarine" and not _is_submarine_detected(u, "player"):
			continue
		var c := Color("#e7e7d8") if u.team == "player" else Color("#d84a3f")
		if u.kind == "carrier":
			draw_colored_polygon(PackedVector2Array([u.pos + Vector2(34, 0), u.pos + Vector2(25, -12), u.pos + Vector2(-31, -12), u.pos + Vector2(-38, -5), u.pos + Vector2(-38, 5), u.pos + Vector2(-31, 12), u.pos + Vector2(25, 12)]), Color("#aab5bb") if u.team == "player" else Color("#b65c55"))
			draw_rect(Rect2(u.pos + Vector2(-22, -7), Vector2(42, 14)), Color("#34434d"))
			draw_line(u.pos + Vector2(-15, -3), u.pos + Vector2(18, -3), Color("#e5e8e6"), 2.0)
		elif u.kind == "submarine":
			draw_colored_polygon(PackedVector2Array([u.pos + Vector2(24, 0), u.pos + Vector2(12, -7), u.pos + Vector2(-21, -6), u.pos + Vector2(-28, 0), u.pos + Vector2(-21, 6), u.pos + Vector2(12, 7)]), Color("#34434a") if u.team == "player" else Color("#6d3c3d"))
			draw_rect(Rect2(u.pos + Vector2(-5, -10), Vector2(11, 5)), Color("#c5d0d2"))
		elif u.kind == "landing_craft":
			draw_colored_polygon(PackedVector2Array([u.pos + Vector2(24, 0), u.pos + Vector2(15, -10), u.pos + Vector2(-22, -9), u.pos + Vector2(-26, 9), u.pos + Vector2(15, 10)]), Color("#b6a77c") if u.team == "player" else Color("#a85b52"))
			draw_rect(Rect2(u.pos + Vector2(-12, -6), Vector2(23, 12)), Color("#38444a"))
		elif u.kind == "destroyer":
			draw_colored_polygon(PackedVector2Array([u.pos + Vector2(27, 0), u.pos + Vector2(13, -10), u.pos + Vector2(-24, -8), u.pos + Vector2(-31, 0), u.pos + Vector2(-24, 8), u.pos + Vector2(13, 10)]), Color("#8c9da5") if u.team == "player" else Color("#b65c55"))
			draw_rect(Rect2(u.pos + Vector2(-9, -7), Vector2(19, 14)), Color("#303e47"))
			draw_line(u.pos + Vector2(2, 0), u.pos + Vector2(23, -2), Color("#d8dedc"), 3.0)
		elif u.kind in ["helicopter", "transport_helicopter"]:
			var heli_color = _helicopter_color(u)
			var heli_angle := _unit_facing_angle(u)
			draw_circle(_unit_rotated_point(u.pos, Vector2(0, 4), heli_angle), 13, Color(0, 0, 0, 0.22))
			draw_circle(u.pos, 12 if u.kind == "transport_helicopter" else 10, Color("#263238"))
			draw_circle(_unit_rotated_point(u.pos, Vector2(1, -2), heli_angle), 10 if u.kind == "transport_helicopter" else 8, heli_color)
			if u.kind == "transport_helicopter":
				draw_rect(Rect2(u.pos + Vector2(-9, -5), Vector2(17, 10)), Color("#5c665e"))
				if String(u.get("transport_state", "")) == "descending":
					var rope_target: Vector2 = u.get("transport_target_pos", u.pos + Vector2(0, 40))
					for rope_side in [-5.0, 5.0]:
						draw_line(_unit_rotated_point(u.pos, Vector2(rope_side, 8), heli_angle), rope_target + Vector2(rope_side, 0), Color("#e1d5b5"), 1.6)
			draw_colored_polygon(_unit_polygon_points(u.pos, PackedVector2Array([Vector2(8, -4), Vector2(30, -1), Vector2(9, 4)]), heli_angle), heli_color)
			draw_line(_unit_rotated_point(u.pos, Vector2(-19, -14), heli_angle), _unit_rotated_point(u.pos, Vector2(18, -14), heli_angle), Color("#252b2b"), 4)
			draw_line(_unit_rotated_point(u.pos, Vector2(0, -14), heli_angle), _unit_rotated_point(u.pos, Vector2(0, -23), heli_angle), Color("#252b2b"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(-14, -23), heli_angle), _unit_rotated_point(u.pos, Vector2(14, -23), heli_angle), Color("#252b2b"), 2)
			draw_circle(_unit_rotated_point(u.pos, Vector2(0, -14), heli_angle), 3, Color("#c7d0cd"))
			draw_line(_unit_rotated_point(u.pos, Vector2(-5, 8), heli_angle), _unit_rotated_point(u.pos, Vector2(9, 12), heli_angle), Color("#252b2b"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(-11, 4), heli_angle), _unit_rotated_point(u.pos, Vector2(-22, 10), heli_angle), Color("#343b3b"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(3, 7), heli_angle), _unit_rotated_point(u.pos, Vector2(14, 12), heli_angle), Color("#343b3b"), 2)
			draw_circle(_unit_rotated_point(u.pos, Vector2(5, -3), heli_angle), 3, Color("#9ed5df"))
			if u.kind == "transport_helicopter":
				var cargo_count := Array(u.get("transport_cargo", [])).size()
				if cargo_count > 0:
					draw_string(ThemeDB.fallback_font, u.pos + Vector2(-13, 29), "حمولة %d/8" % cargo_count, HORIZONTAL_ALIGNMENT_CENTER, 58, 9, Color("#f4dfad"))
		elif u.kind == "fighter":
			var plane_color = Color("#d7e4e8") if u.team == "player" else Color("#d95b51")
			var plane_angle := _unit_facing_angle(u)
			var plane_shape := PackedVector2Array([Vector2(24, 0), Vector2(-8, -6), Vector2(-23, -20), Vector2(-16, 0), Vector2(-23, 20), Vector2(-8, 6)])
			draw_colored_polygon(_unit_polygon_points(u.pos, plane_shape, plane_angle), Color(0, 0, 0, 0.18))
			draw_colored_polygon(_unit_polygon_points(u.pos, plane_shape, plane_angle), plane_color)
			draw_colored_polygon(_unit_polygon_points(u.pos, PackedVector2Array([Vector2(7, 0), Vector2(-7, -4), Vector2(-13, 0), Vector2(-7, 4)]), plane_angle), Color("#52636d"))
			draw_line(_unit_rotated_point(u.pos, Vector2(-4, 0), plane_angle), _unit_rotated_point(u.pos, Vector2(24, 0), plane_angle), Color("#303a42"), 3)
			draw_line(_unit_rotated_point(u.pos, Vector2(-12, -8), plane_angle), _unit_rotated_point(u.pos, Vector2(-18, -17), plane_angle), Color("#e4d9a7"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(-12, 8), plane_angle), _unit_rotated_point(u.pos, Vector2(-18, 17), plane_angle), Color("#e4d9a7"), 2)
			draw_circle(_unit_rotated_point(u.pos, Vector2(7, 0), plane_angle), 3, Color("#9bd5e5"))
		elif u.kind == "builder":
			var builder_facing := _unit_facing_angle(u)
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(38, 27), builder_facing), Color("#252d2b"))
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(32, 21), builder_facing), Color("#c3a45d") if u.team == "player" else Color("#9a554b"))
			draw_colored_polygon(_unit_polygon_points(u.pos, PackedVector2Array([Vector2(-12, -8), Vector2(12, -8), Vector2(12, 8), Vector2(-12, 8)]), builder_facing), Color("#4a5651"))
			draw_line(_unit_rotated_point(u.pos, Vector2(4, 0), builder_facing), _unit_rotated_point(u.pos, Vector2(19, 0), builder_facing), Color("#252c2c"), 4.0)
			draw_circle(_unit_rotated_point(u.pos, Vector2(-7, -2), builder_facing), 3.0, Color("#e4d39a"))
		elif u.kind == "tank":
			var facing = _unit_facing_angle(u)
			var track_color := Color("#20292b")
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(42, 26), facing), track_color)
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(36, 20), facing), c)
			for wheel in range(4):
				draw_circle(_unit_rotated_point(u.pos, Vector2(-12 + wheel * 8, 11), facing), 3.2, Color("#69736f"))
				draw_circle(_unit_rotated_point(u.pos, Vector2(-12 + wheel * 8, -11), facing), 3.2, Color("#69736f"))
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(19, 16), facing), Color("#3d4a45"))
			var tank_aim := _unit_turret_angle(u)
			var turret_center := _unit_rotated_point(u.pos, Vector2(1, 0), facing)
			var gun_recoil := float(u.get("gun_recoil", 0.0))
			var tank_hp_ratio := clampf(float(u.get("hp", 150)) / 150.0, 0.0, 1.0)
			if tank_hp_ratio <= 0.60:
				var scorch_color := Color(0.12, 0.13, 0.12, 0.72)
				draw_circle(_unit_rotated_point(u.pos, Vector2(-10, -5), facing), 4.0, scorch_color)
				draw_circle(_unit_rotated_point(u.pos, Vector2(9, 6), facing), 3.0, scorch_color)
			if tank_hp_ratio <= 0.25:
				draw_circle(_unit_rotated_point(u.pos, Vector2(-5, -10), facing), 5.0, Color("#55483a"))
			draw_circle(turret_center, 7, Color("#7f927f"))
			draw_line(_unit_rotated_point(turret_center, Vector2(3, 0), tank_aim), _unit_rotated_point(turret_center, Vector2(28.0 - gun_recoil, 0), tank_aim), Color("#252c2c"), 5)
			draw_line(_unit_rotated_point(turret_center, Vector2(-13, -5), tank_aim), _unit_rotated_point(turret_center, Vector2(13, -5), tank_aim), Color("#d5c99d"), 2)
			draw_circle(_unit_rotated_point(turret_center, Vector2(-1, -5), tank_aim), 2.5, Color("#d5c99d"))
		elif u.kind == "artillery":
			var facing = _unit_facing_angle(u)
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(39, 22), facing), Color("#20292b"))
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(33, 16), facing), c)
			for wheel in range(4):
				draw_circle(_unit_rotated_point(u.pos, Vector2(-12 + wheel * 8, 10), facing), 3.2, Color("#59645e"))
			draw_colored_polygon(_rotated_rect_points(u.pos, Vector2(17, 10), facing), Color("#45534c"))
			var artillery_aim := _unit_weapon_angle(u)
			var artillery_pivot := _unit_rotated_point(u.pos, Vector2(0, -2), facing)
			draw_line(artillery_pivot, _unit_rotated_point(artillery_pivot, Vector2(32, 0), artillery_aim), Color("#252b2b"), 7)
			draw_line(artillery_pivot, _unit_rotated_point(artillery_pivot, Vector2(32, 0), artillery_aim), Color("#aeb7a5"), 3)
			draw_circle(_unit_rotated_point(u.pos, Vector2(-3, 0), facing), 4, Color("#d4c59a"))
		else:
			draw_line(u.pos + Vector2(-5, 6), u.pos + Vector2(5, 6), Color("#283137"), 4)
			draw_line(u.pos + Vector2(-3, 2), u.pos + Vector2(-5, 10), Color("#283137"), 3)
			draw_line(u.pos + Vector2(3, 2), u.pos + Vector2(5, 10), Color("#283137"), 3)
			draw_rect(Rect2(u.pos + Vector2(-5, -3), Vector2(10, 11)), c)
			draw_circle(u.pos + Vector2(0, -8), 6, Color("#c4aa7a") if u.team == "player" else Color("#8e5149"))
			draw_arc(u.pos + Vector2(0, -8), 6, 3.2, 6.1, 16, Color("#30383a"), 3)
			draw_line(u.pos + Vector2(4, 0), u.pos + Vector2(13, -5), Color("#252b2b"), 2.5)
			draw_circle(u.pos + Vector2(-7, 1), 3, Color("#5d6c58"))
		# Additional deck fittings and ship silhouettes for the naval visual pass.
		if u.kind == "carrier":
			draw_line(u.pos + Vector2(-27, -9), u.pos + Vector2(23, -9), Color("#e1e7e8"), 1.5)
			draw_line(u.pos + Vector2(-27, 9), u.pos + Vector2(23, 9), Color("#56636a"), 1.5)
			draw_rect(Rect2(u.pos + Vector2(-7, -10), Vector2(12, 7)), Color("#52636b"))
			draw_rect(Rect2(u.pos + Vector2(-4, -12), Vector2(5, 3)), Color("#d7e1e1"))
			for deck_plane in range(3):
				var plane_x = -20.0 + deck_plane * 12.0
				draw_colored_polygon(PackedVector2Array([u.pos + Vector2(plane_x + 3, 4), u.pos + Vector2(plane_x - 3, 2), u.pos + Vector2(plane_x - 5, -1), u.pos + Vector2(plane_x - 4, 4), u.pos + Vector2(plane_x - 5, 8), u.pos + Vector2(plane_x - 3, 6)]), Color("#d7e1e1"))
		elif u.kind == "destroyer":
			draw_line(u.pos + Vector2(-25, -6), u.pos + Vector2(21, -6), Color("#d7e0df"), 1.3)
			draw_line(u.pos + Vector2(-25, 6), u.pos + Vector2(21, 6), Color("#52616a"), 1.3)
			draw_rect(Rect2(u.pos + Vector2(-6, -10), Vector2(11, 6)), Color("#aab8ba"))
			for turret_pos in [Vector2(15, 0), Vector2(-19, 0)]:
				draw_circle(u.pos + turret_pos, 3.2, Color("#303b42"))
				draw_line(u.pos + turret_pos, u.pos + turret_pos + Vector2(7, -1), Color("#d7dedb"), 2.0)
		elif u.kind == "submarine":
			draw_line(u.pos + Vector2(-19, 2), u.pos + Vector2(18, 2), Color("#89999b"), 1.5)
			draw_rect(Rect2(u.pos + Vector2(-2, -13), Vector2(5, 4)), Color("#53646a"))
			draw_line(u.pos + Vector2(0, -12), u.pos + Vector2(0, -18), Color("#cbd5d5"), 1.5)
		elif u.kind == "landing_craft":
			draw_line(u.pos + Vector2(18, -7), u.pos + Vector2(23, 0), Color("#e4e1d0"), 2.0)
			draw_line(u.pos + Vector2(18, 7), u.pos + Vector2(23, 0), Color("#e4e1d0"), 2.0)
			draw_rect(Rect2(u.pos + Vector2(-17, -4), Vector2(13, 8)), Color("#8c9b9c"))
			for passenger_marker in range(int(u.get("passengers", 0))):
				draw_circle(u.pos + Vector2(-10.0 + passenger_marker * 8.0, -1.0), 2.2, Color("#e0c995"))
		var max_hp := 520.0 if u.kind == "carrier" else (260.0 if u.kind == "destroyer" else (250.0 if u.kind == "transport_helicopter" else (220.0 if u.kind == "builder" or u.kind == "landing_craft" else (210.0 if u.kind == "submarine" else (180.0 if u.kind == "helicopter" else (120.0 if u.kind == "fighter" else (150.0 if u.kind == "tank" else (100.0 if u.kind == "artillery" or u.team == "player" else 60.0))))))))
		var hp_ratio := clampf(float(u.get("hp", 0)) / max_hp, 0.0, 1.0)
		var veterancy := int(u.get("veterancy", 0))
		if u.team == "player" and veterancy > 0:
			var rank_color := Color("#f0c85a") if veterancy == 1 else Color("#8be4ff")
			draw_circle(u.pos + Vector2(18, -19), 5.0, rank_color)
			draw_string(ThemeDB.fallback_font, u.pos + Vector2(14, -16), "★" if veterancy == 1 else "★★", HORIZONTAL_ALIGNMENT_LEFT, 20, 9, Color("#202a30"))
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32, 4)), Color("#352c2a"))
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32.0 * hp_ratio, 4)), Color("#5ed16f") if hp_ratio > 0.35 else Color("#e85c4a"))
		if selected.has(i):
			draw_arc(u.pos, 17, 0, TAU, 32, Color("#ffe45c"), 3)
	_draw_environment_particles()
	for effect in visual_effects:
		var progress = 1.0 - clampf(float(effect.life) / float(effect.duration), 0.0, 1.0)
		var fade: float = 1.0 - progress
		var tint: Color = effect.color
		tint.a = fade
		if effect.kind == "targeting":
			# Ground marker previews the full blast footprint for tactical readability.
			var marker_radius: float = float(effect.radius) * (0.82 + progress * 0.18)
			draw_arc(effect.finish, marker_radius, 0.0, TAU, 40, Color(1.0, 0.76, 0.30, fade * 0.88), 2.2)
			draw_arc(effect.finish, marker_radius * 0.78, 0.0, TAU, 32, Color(1.0, 0.88, 0.56, fade * 0.48), 1.0)
			for mark_index in range(4):
				var mark_angle := TAU * float(mark_index) / 4.0
				var mark_direction := Vector2(cos(mark_angle), sin(mark_angle))
				draw_line(effect.finish + mark_direction * marker_radius * 0.86, effect.finish + mark_direction * marker_radius * 1.08, Color(1.0, 0.78, 0.38, fade), 2.0)
		elif effect.kind == "muzzle":
			var muzzle_radius: float = float(effect.radius) * (0.35 + progress)
			draw_circle(effect.finish, muzzle_radius, Color(1.0, 0.64, 0.28, fade * 0.38))
			draw_circle(effect.finish, muzzle_radius * 0.42, Color(1.0, 0.94, 0.72, fade * 0.82))
		elif effect.kind == "shell":
			# A compact ballistic arc makes heavy artillery fire readable at a glance.
			var shell_position: Vector2 = effect.start.lerp(effect.finish, progress)
			var arc_height := sin(progress * PI) * minf(54.0, effect.start.distance_to(effect.finish) * 0.16)
			shell_position.y -= arc_height
			var trail_position := shell_position.lerp(effect.start, 0.16)
			draw_line(trail_position, shell_position, Color(1.0, 0.66, 0.32, fade * 0.72), 3.0)
			draw_circle(shell_position + Vector2(2.0, 3.0), 5.0, Color(0.18, 0.16, 0.14, fade * 0.48))
			draw_circle(shell_position, 3.6, Color(1.0, 0.82, 0.48, fade))
			draw_circle(shell_position, 1.5, Color(1.0, 0.98, 0.82, fade))
		elif effect.kind == "tank_round":
			# Fast, compact tank projectile with a bright core and short exhaust trail.
			var round_position: Vector2 = effect.start.lerp(effect.finish, progress)
			var round_direction: Vector2 = (effect.finish - effect.start).normalized()
			draw_line(round_position - round_direction * 11.0, round_position, Color(1.0, 0.68, 0.32, fade * 0.62), 3.0)
			draw_circle(round_position, 3.2, Color(1.0, 0.83, 0.48, fade))
			draw_circle(round_position, 1.4, Color(1.0, 0.98, 0.82, fade))
		elif effect.kind == "repair":
			var repair_pulse := 0.55 + sin(progress * TAU) * 0.25
			draw_line(effect.start, effect.finish, Color(0.42, 0.95, 0.62, fade * repair_pulse), 3.0)
			draw_circle(effect.finish, 5.0 + progress * 4.0, Color(0.58, 1.0, 0.70, fade * 0.72))
		elif effect.kind == "rope":
			# Fast-rope insertion: keep the line visible from the aircraft to the rooftop soldier.
			draw_line(effect.start, effect.finish, Color(tint.r, tint.g, tint.b, fade * 0.82), 2.4)
			draw_circle(effect.finish, 2.2, Color("#e8dfc8", fade))
		elif effect.kind == "tracer":
			# Two-pass tracer: a soft colored halo beneath a crisp hot core.
			var tracer_tint := Color(tint.r, tint.g, tint.b, fade * 0.24)
			draw_line(effect.start, effect.finish, tracer_tint, 7.0)
			draw_line(effect.start, effect.finish, tint, 2.6)
			draw_line(effect.start.lerp(effect.finish, 0.72), effect.finish, Color(1.0, 0.94, 0.76, fade * 0.9), 1.0)
			draw_circle(effect.finish, 3.0 * fade + 1.0, tint)
		elif effect.kind == "flash":
			var flash_radius: float = float(effect.radius) * (0.45 + progress)
			draw_circle(effect.finish, flash_radius, Color(tint.r, tint.g, tint.b, fade * 0.16))
			draw_circle(effect.finish, flash_radius * 0.42, Color(1.0, 0.94, 0.76, fade * 0.62))
			draw_arc(effect.finish, float(effect.radius) * (0.8 + progress), 0.0, TAU, 20, tint, 2.0)
		elif effect.kind == "explosion":
			var blast_radius: float = float(effect.radius) * (0.25 + progress)
			var shock_radius: float = float(effect.radius) * (0.35 + progress * 1.35)
			# Layered heat, dark debris and a bright core give explosions more depth.
			draw_circle(effect.finish, blast_radius * 1.22, Color(tint.r, tint.g * 0.42, tint.b * 0.16, fade * 0.18))
			draw_circle(effect.finish, blast_radius, Color(tint.r, tint.g * 0.62, tint.b * 0.28, fade * 0.42))
			draw_circle(effect.finish, blast_radius * 0.34, Color(1.0, 0.88, 0.62, fade * 0.72))
			draw_arc(effect.finish, blast_radius, 0.0, TAU, 32, tint, 4.0 * fade + 1.0)
			# Expanding pressure ring and deterministic sparks keep the effect light on mobile.
			draw_arc(effect.finish, shock_radius, 0.0, TAU, 36, Color(1.0, 0.78, 0.42, fade * 0.72), 2.0 * fade + 0.5)
			for spark_index in range(8):
				var spark_angle = TAU * float(spark_index) / 8.0 + progress * 0.35
				var spark_direction := Vector2(cos(spark_angle), sin(spark_angle))
				var spark_start: Vector2 = effect.finish + spark_direction * blast_radius * 0.42
				var spark_end: Vector2 = effect.finish + spark_direction * (blast_radius * (0.72 + progress * 0.55))
				draw_line(spark_start, spark_end, Color(1.0, 0.72, 0.36, fade * 0.82), 2.0 * fade + 0.4)
			draw_circle(effect.finish + Vector2(-blast_radius * 0.25, -blast_radius * 0.35), blast_radius * 0.28, Color(0.24, 0.22, 0.2, fade * 0.45))
	_draw_hud(size)
	if dragging:
		draw_rect(Rect2(drag_start, drag_end - drag_start).abs(), Color(0.3, 0.8, 1, 0.13), true)
		draw_rect(Rect2(drag_start, drag_end - drag_start).abs(), Color("#9fe7ff"), false, 2)
	if not game_started:
		_draw_faction_picker(size)
	elif battle_result != "":
		draw_rect(Rect2(size.x * 0.14, size.y * 0.30, size.x * 0.72, size.y * 0.40), Color(0.02, 0.03, 0.04, 0.96))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.19, size.y * 0.40), battle_result, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.62, 27, Color("#f4d77a"))
		var career_medals: Array = commander_profile.get("earned_medals", [])
		var career_summary := "المعارك: %d  |  انتصارات: %d  |  هزائم: %d" % [int(commander_profile.get("battles_played", 0)), int(commander_profile.get("victories", 0)), int(commander_profile.get("defeats", 0))]
		var kill_summary := "إجمالي القتلى: %d  |  الجو: %d  |  الدروع: %d  |  البحر: %d" % [int(commander_profile.get("total_kills", 0)), int(commander_profile.get("air_kills", 0)), int(commander_profile.get("armor_kills", 0)), int(commander_profile.get("naval_kills", 0))]
		var medal_names := PackedStringArray()
		for medal in career_medals:
			medal_names.append(String(medal))
		var medal_summary := "الأوسمة الدائمة: " + ("، ".join(medal_names) if not medal_names.is_empty() else "لم تحصل على أوسمة بعد")
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.18, size.y * 0.47), career_summary, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.64, 14, Color("#d8e6c2"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.18, size.y * 0.51), kill_summary, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.64, 13, Color("#c4dce8"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.18, size.y * 0.55), medal_summary, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.64, 12, Color("#f4d77a"))
		var restart := _restart_rect(size)
		draw_rect(restart, Color("#73552d"), true)
		draw_rect(restart, Color("#f4d77a"), false, 2)
		draw_string(ThemeDB.fallback_font, restart.position + Vector2(0, 31), "معركة جديدة", HORIZONTAL_ALIGNMENT_CENTER, restart.size.x, 21, Color.WHITE)
	elif paused:
		draw_rect(Rect2(size.x * 0.32, size.y * 0.36, size.x * 0.36, size.y * 0.2), Color(0.02, 0.03, 0.04, 0.88))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.36, size.y * 0.44), "المعركة متوقفة مؤقتاً", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.28, 27, Color("#f4d77a"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.36, size.y * 0.50), "اضغط استئناف لمتابعة القتال", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.28, 18, Color.WHITE)
	elif notice_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.35, 82), notice, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.3, 23, Color.WHITE)

func _draw_3d_view_hud(size: Vector2) -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, 58.0), Color(0.025, 0.045, 0.052, 0.88), true)
	draw_line(Vector2(0.0, 58.0), Vector2(size.x, 58.0), Color("#71858a"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(14.0, 25.0), "STORM GENERALS // 3D COMMAND", HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.55, 16, Color("#f4d77a"))
	draw_string(ThemeDB.fallback_font, Vector2(14.0, 45.0), "%s  |  الموارد: %d  |  الإمداد: %d" % [faction, credits, supplies], HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.62, 13, Color("#d8e6c2"))
	var toggle := _three_d_view_toggle_rect(size)
	draw_rect(toggle, Color("#73552d"), true)
	draw_rect(toggle, Color("#f4d77a"), false, 2.0)
	draw_string(ThemeDB.fallback_font, toggle.position + Vector2(0.0, 30.0), "العودة 2D", HORIZONTAL_ALIGNMENT_CENTER, toggle.size.x, 16, Color.WHITE)


func _pause_rect(size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x - 112.0, 5.0), Vector2(100.0, 48.0))


func _restart_rect(size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x * 0.4, size.y * 0.60), Vector2(size.x * 0.2, 48))

func _draw_base_health(p: Vector2, hp: int) -> void:
	var ratio = clampf(float(hp) / 1000.0, 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-45, -62), Vector2(90, 7)), Color("#292929"))
	draw_rect(Rect2(p + Vector2(-45, -62), Vector2(90.0 * ratio, 7)), Color("#55d879") if ratio > 0.3 else Color("#e85c4a"))

func _draw_base(p: Vector2, color: Color, label: String) -> void:
	draw_rect(Rect2(p - Vector2(48, 42), Vector2(96, 84)), Color("#343b35"))
	draw_rect(Rect2(p - Vector2(40, 34), Vector2(80, 68)), color)
	draw_rect(Rect2(p - Vector2(18, 54), Vector2(36, 20)), Color("#c7c6b3"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-48, 66), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 16, Color.WHITE)

func _draw_hud(size: Vector2) -> void:
	# Premium command header: restrained steel/navy layers with the game's gold identity.
	draw_rect(Rect2(0, 0, size.x, 58), Color("#09151b"))
	draw_rect(Rect2(0, 0, size.x, 3), Color("#c7a45b"))
	draw_rect(Rect2(0, 3, size.x, 55), Color(0.035, 0.055, 0.065, 0.97))
	draw_line(Vector2(0, 58), Vector2(size.x, 58), Color("#71858a"), 1.0)
	draw_rect(Rect2(10, 12, 3, 32), Color("#e0bd68"))
	draw_string(ThemeDB.fallback_font, Vector2(20, 36), "STORM GENERALS", HORIZONTAL_ALIGNMENT_LEFT, minf(210.0, size.x * 0.48), _hud_brand_font_size(size), Color("#f4d77a"))
	if not game_started:
		return
	var faction_tint := _hud_faction_accent()
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 12, 35), faction, HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.38, clampi(int(size.x * 0.018), 11, 16), faction_tint)
	draw_circle(Vector2(size.x - 12, 15), 3.5, Color("#8bd5a0"))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 22, 19), "LIVE", HORIZONTAL_ALIGNMENT_RIGHT, 55, 9, Color("#a9c5b6"))
	var margin := 10.0
	var gap := 6.0
	var metric_width := (size.x - margin * 2.0 - gap * 3.0) / 4.0
	var metric_y := 66.0
	var metric_h := 42.0
	var power_capacity := _player_power_capacity()
	var power_demand := _player_power_demand()
	var hostile_count := 0
	var nearby_threats := 0
	for contact in units:
		if String(contact.get("team", "")) == "enemy" and int(contact.get("hp", 0)) > 0:
			hostile_count += 1
			if contact.pos.distance_to(base_pos) < 280.0:
				nearby_threats += 1
	for metric_index in range(4):
		var metric_rect := Rect2(Vector2(margin + metric_index * (metric_width + gap), metric_y), Vector2(metric_width, metric_h))
		draw_rect(Rect2(metric_rect.position + Vector2(0, 2), metric_rect.size), Color(0.015, 0.035, 0.045, 0.45), true)
		draw_rect(metric_rect, Color("#17272d"), true)
		draw_rect(metric_rect, Color("#425b62"), false, 1.0)
		var metric_accents := [Color("#e2bd67"), Color("#83d9c5"), Color("#91c9e8"), Color("#e47c70")]
		draw_rect(Rect2(metric_rect.position, Vector2(3, metric_rect.size.y)), metric_accents[metric_index])
	var metric_values := [
		{"label": "الموارد", "value": str(credits), "color": Color("#f2d47b")},
		{"label": "الإمداد", "value": "%d / %d" % [supplies, _player_supply_capacity()], "color": Color("#9fe6d2")},
		{"label": "الطاقة", "value": "%d / %d" % [power_demand, power_capacity], "color": Color("#ff9c82") if power_demand > power_capacity else Color("#a8e6b0")},
		{"label": "التهديد", "value": "خطر %d" % nearby_threats if nearby_threats > 0 else "آمن %d" % hostile_count, "color": Color("#ff766b") if nearby_threats > 0 else Color("#a8e6b0")}
	]
	for metric_index in range(metric_values.size()):
		var metric_rect := Rect2(Vector2(margin + metric_index * (metric_width + gap), metric_y), Vector2(metric_width, metric_h))
		var metric: Dictionary = metric_values[metric_index]
		draw_string(ThemeDB.fallback_font, metric_rect.position + Vector2(5, 15), String(metric.label), HORIZONTAL_ALIGNMENT_LEFT, metric_width - 10, _hud_metric_label_font_size(metric_width), Color("#b6c7c8"))
		draw_string(ThemeDB.fallback_font, metric_rect.position + Vector2(5, 34), String(metric.value), HORIZONTAL_ALIGNMENT_LEFT, metric_width - 10, _hud_metric_value_font_size(metric_width), metric.color)
	var theatre_text := "%s  |  %s" % [map_type, _terrain_effect_label()]
	draw_string(ThemeDB.fallback_font, Vector2(12, 126), theatre_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, Color("#d8e6c2"))
	var power_state := "شبكة الطاقة مستقرة" if power_demand <= power_capacity else "تحذير: عجز الطاقة — بعض المنشآت متوقفة"
	draw_string(ThemeDB.fallback_font, Vector2(12, 145), power_state, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, Color("#a8e6b0") if power_demand <= power_capacity else Color("#ff9c82"))
	# Production panel remains visible even when the queue is empty.
	var production_rect := Rect2(Vector2(10, 154), Vector2(size.x - 20, 43))
	draw_rect(Rect2(production_rect.position + Vector2(0, 2), production_rect.size), Color(0.015, 0.035, 0.045, 0.42), true)
	draw_rect(production_rect, Color("#101f26", 0.96), true)
	draw_rect(production_rect, Color("#526b70"), false, 1.0)
	draw_rect(Rect2(production_rect.position, Vector2(3, production_rect.size.y)), Color("#c7a45b"))
	if production_orders.is_empty():
		# Building construction is a separate queue from unit production.
		# Report active construction here instead of claiming the base is idle.
		var construction_count := 0
		var first_construction_kind := ""
		var construction_progress := 0.0
		for building in buildings:
			if int(building.get("hp", 0)) > 0 and float(building.get("build_progress", 1.0)) < 1.0:
				construction_count += 1
				if first_construction_kind.is_empty():
					first_construction_kind = String(building.get("kind", "منشأة"))
					construction_progress = clampf(float(building.get("build_progress", 0.0)), 0.0, 1.0)
		if construction_count > 0:
			var construction_labels := {"power_plant": "محطة طاقة", "barracks": "ثكنة", "factory": "مصنع", "airfield": "مطار", "turret": "برج دفاع", "anti_air": "مضاد جو", "shipyard": "حوض سفن", "missile_silo": "منصة صواريخ", "missile_defense": "دفاع صاروخي"}
			var construction_name := String(construction_labels.get(first_construction_kind, "منشأة"))
			var construction_text := "الإنشاء: %s  |  %d منشآت قيد البناء" % [construction_name, construction_count]
			draw_string(ThemeDB.fallback_font, production_rect.position + Vector2(9, 16), construction_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 38, 12, Color("#e4eee8"))
			var construction_bar := Rect2(production_rect.position + Vector2(9, 25), Vector2(size.x - 38, 8))
			draw_rect(construction_bar, Color("#26383d"), true)
			draw_rect(Rect2(construction_bar.position, Vector2(construction_bar.size.x * construction_progress, construction_bar.size.y)), Color("#d9b66b"), true)
		else:
			draw_string(ThemeDB.fallback_font, production_rect.position + Vector2(9, 18), "الإنتاج والإنشاء: لا توجد أوامر قيد التنفيذ", HORIZONTAL_ALIGNMENT_LEFT, size.x - 38, 12, Color("#c0cece"))
	else:
		var first_order: Dictionary = production_orders[0]
		var duration := maxf(1.0, float(first_order.get("duration", 1.0)))
		var progress := clampf(1.0 - float(first_order.get("remaining", duration)) / duration, 0.0, 1.0)
		var production_text := "الإنتاج: %s  |  %d طلبات" % [String(first_order.get("kind", "وحدة")), production_orders.size()]
		draw_string(ThemeDB.fallback_font, production_rect.position + Vector2(9, 16), production_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 38, 12, Color("#e4eee8"))
		var bar_rect := Rect2(production_rect.position + Vector2(9, 25), Vector2(size.x - 38, 8))
		draw_rect(bar_rect, Color("#26383d"), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), Color("#8bd5a0"), true)
	# Selected-unit field dossier: rank, accumulated combat XP and progress to the next promotion.
	var selected_player_units: Array[Dictionary] = []
	for selected_index in selected:
		if selected_index >= 0 and selected_index < units.size():
			var selected_unit: Dictionary = units[selected_index]
			if String(selected_unit.get("team", "")) == "player" and int(selected_unit.get("hp", 0)) > 0:
				selected_player_units.append(selected_unit)
	if not selected_player_units.is_empty():
		var total_xp := 0.0
		var total_kills := 0
		var total_medals := 0
		var progress_total := 0.0
		var highest_rank := 0
		var elite_count := 0
		var infantry_count := 0
		var ground_support_count := 0
		var aircraft_count := 0
		var kind_labels := {"infantry": "المشاة", "tank": "الدبابة", "builder": "مركبة البناء", "artillery": "المدفعية", "fighter": "المقاتلة", "helicopter": "المروحية", "transport_helicopter": "مروحية النقل", "destroyer": "المدمرة", "submarine": "الغواصة", "carrier": "حاملة الطائرات", "landing_craft": "سفينة الإنزال"}
		var dossier_name := String(kind_labels.get(String(selected_player_units[0].get("kind", "")), "الوحدة"))
		for selected_unit in selected_player_units:
			var selected_kind := String(selected_unit.get("kind", ""))
			if selected_kind == "infantry":
				infantry_count += 1
			elif selected_kind in ["tank", "artillery", "builder"]:
				ground_support_count += 1
			elif selected_kind in ["fighter", "helicopter", "transport_helicopter"]:
				aircraft_count += 1
			var unit_xp := float(selected_unit.get("combat_xp", 0.0))
			var unit_rank := int(selected_unit.get("veterancy", 0))
			total_xp += unit_xp
			total_kills += int(selected_unit.get("combat_kills", 0))
			var unit_medals: Array = selected_unit.get("combat_medals", [])
			total_medals += unit_medals.size()
			highest_rank = maxi(highest_rank, unit_rank)
			if unit_rank >= 2:
				elite_count += 1
				progress_total += 1.0
			elif unit_rank == 1:
				progress_total += clampf((unit_xp - 100.0) / 150.0, 0.0, 1.0)
			else:
				progress_total += clampf(unit_xp / 100.0, 0.0, 1.0)
		var average_xp := total_xp / float(selected_player_units.size())
		var progress := progress_total / float(selected_player_units.size())
		var rank_label := "نخبة" if highest_rank >= 2 else ("مخضرم" if highest_rank == 1 else "مجند")
		var dossier := Rect2(Vector2(10, 203), Vector2(size.x - 20, 48))
		draw_rect(dossier, Color("#10232b", 0.94), true)
		draw_rect(dossier, Color("#d8b75e") if highest_rank == 1 else (Color("#83d9f4") if highest_rank >= 2 else Color("#526b73")), false, 1.2)
		var unit_label := dossier_name if selected_player_units.size() == 1 else "مجموعة: مشاة %d | أرضية %d | جوية %d" % [infantry_count, ground_support_count, aircraft_count]
		draw_string(ThemeDB.fallback_font, dossier.position + Vector2(8, 16), "%s | %s | خبرة %.0f | قتلى %d | أوسمة %d" % [unit_label, rank_label, average_xp, total_kills, total_medals], HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 10 if selected_player_units.size() > 1 else 12, Color("#f2e8ca"))
		var xp_bar := Rect2(dossier.position + Vector2(8, 26), Vector2(size.x - 36, 9))
		draw_rect(xp_bar, Color("#293b40"), true)
		var xp_color := Color("#d8b75e") if highest_rank == 1 else (Color("#83d9f4") if highest_rank >= 2 else Color("#8bd5a0"))
		draw_rect(Rect2(xp_bar.position, Vector2(xp_bar.size.x * progress, xp_bar.size.y)), xp_color, true)
		var progress_label := "أقصى رتبة" if elite_count == selected_player_units.size() else ("تقدم المجموعة نحو الترقية" if selected_player_units.size() > 1 else ("الحد التالي: 250 خبرة" if highest_rank == 1 else "الحد التالي: 100 خبرة"))
		draw_string(ThemeDB.fallback_font, dossier.position + Vector2(8, 44), progress_label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 9, Color("#b9c9c8"))
	var labels = ["مشاة 100", "دبابة 300", "ثكنة 250", "مصنع 450", "دفاع 350", "مدفعية 450", "مطار 600", "مقاتلة 500", "مضاد جو 400", "مروحية 650", "سيطرة مبنى", "تدمير مبنى", "إلغاء", "منصة صواريخ 800", "دفاع صاروخي 700", "إطلاق صاروخ %d" % _missile_cost(faction), "حوض سفن 700", "مدمرة 900", "حاملة 1600", "غواصة 1100", "إنزال 800", "مركبة بناء 600", "محطة طاقة 450", "مخبأ دفاعي 520", "مخزن إمداد 550", "جدار 90", "زاوية 120", "بوابة 150", "طائرة نقل 950", "تحميل الجنود", "إنزال على السطح", "إلغاء مهمة النقل"]
	if not selected.is_empty() and not _has_selected_player_building():
		labels[12] = "مسح التحديد"
	if _has_selected_player_building():
		labels[10] = "إصلاح المنشأة"
		labels[11] = "بيع المنشأة"
		labels[12] = "ترقية L%d" % int(buildings[selected_player_building].get("level", 1)) if int(buildings[selected_player_building].get("level", 1)) < 3 else "أقصى تطوير"
	elif build_mode != "":
		labels[12] = "إلغاء البناء"
	else:
		labels[12] = "ترقية / إلغاء"
	# The lower command deck is a visual layer only; hit rectangles remain unchanged.
	var deck_top := size.y - 172.0
	draw_rect(Rect2(0, deck_top, size.x, size.y - deck_top), Color(0.025, 0.045, 0.055, 0.94), true)
	draw_rect(Rect2(0, deck_top, size.x, 2), Color("#b89450"))
	for tab_index in range(_command_tab_count()):
		var tab_rect := _command_tab_rect(tab_index, size)
		var is_active_tab := tab_index == command_tab
		draw_rect(tab_rect, Color("#3a3020") if is_active_tab else Color("#142630"), true)
		draw_rect(tab_rect, Color("#e4c477") if is_active_tab else Color("#49616b"), false, 1.5)
		if is_active_tab:
			draw_rect(Rect2(tab_rect.position + Vector2(7, tab_rect.size.y - 3), Vector2(tab_rect.size.x - 14, 2)), Color("#f4d77a"))
		draw_string(ThemeDB.fallback_font, tab_rect.position + Vector2(0, 23), _command_tab_label(tab_index), HORIZONTAL_ALIGNMENT_CENTER, tab_rect.size.x, _command_tab_font_size(tab_rect.size.x), Color("#ffe6a6") if is_active_tab else Color("#d4e0df"))
	var visible_actions: Array = _command_action_ids()
	for slot in range(visible_actions.size()):
		var action_id := int(visible_actions[slot])
		var r := _button_rect(slot, size)
		draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Color(0.0, 0.0, 0.0, 0.28), true)
		draw_rect(r, Color("#263d50"), true)
		draw_rect(r, Color("#79919a"), false, 1.2)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), Color("#91a9b2", 0.72))
		draw_string(ThemeDB.fallback_font, r.position + Vector2(2, 30), labels[action_id], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4, _command_button_font_size(r.size.x), Color("#f2f5ed"))
	var pause_button := _pause_rect(size)
	draw_rect(pause_button, Color("#73552d") if paused else Color("#263d50"), true)
	draw_rect(pause_button, Color("#f4d77a") if paused else Color("#8fa8b8"), false, 2)
	draw_string(ThemeDB.fallback_font, pause_button.position + Vector2(0, 30), "استئناف" if paused else "إيقاف", HORIZONTAL_ALIGNMENT_CENTER, pause_button.size.x, 17, Color.WHITE)
	var view_button := _three_d_view_toggle_rect(size)
	draw_rect(view_button, Color("#284b43"), true)
	draw_rect(view_button, Color("#8bd5a0"), false, 2.0)
	draw_string(ThemeDB.fallback_font, view_button.position + Vector2(0, 30), "عرض 3D", HORIZONTAL_ALIGNMENT_CENTER, view_button.size.x, 16, Color.WHITE)

func _hud_faction_accent() -> Color:
	match faction:
		"الأمريكي":
			return Color("#8fc7ef")
		"الصيني":
			return Color("#e77b72")
		"الجيش العربي":
			return Color("#9bd29b")
		"وطن":
			return Color("#e5c36f")
		_:
			return Color("#d8e6c2")


func _has_only_selected_builders() -> bool:
	var has_builder := false
	for selected_index in selected:
		if selected_index < 0 or selected_index >= units.size():
			continue
		var selected_unit: Dictionary = units[selected_index]
		if String(selected_unit.get("team", "")) != "player" or int(selected_unit.get("hp", 0)) <= 0:
			continue
		if String(selected_unit.get("kind", "")) != "builder":
			return false
		has_builder = true
	return has_builder


func _command_tab_count() -> int:
	return 4 if _has_only_selected_builders() else COMMAND_TAB_LABELS.size()


func _command_tab_label(index: int) -> String:
	if _has_only_selected_builders():
		var builder_labels: Array[String] = ["المنشآت", "الدفاعات", "التحصينات", "مركبات البناء"]
		return builder_labels[clampi(index, 0, builder_labels.size() - 1)]
	return COMMAND_TAB_LABELS[clampi(index, 0, COMMAND_TAB_LABELS.size() - 1)]


func _command_action_ids() -> Array:
	if _has_only_selected_builders():
		var builder_actions: Array = [
			[22, 2, 3, 6, 13, 14],
			[4, 8, 23, 24, 25, 26],
			[27, 24, 25, 26, 23, 12],
			[21]
		]
		return builder_actions[clampi(command_tab, 0, builder_actions.size() - 1)]
	return COMMAND_ACTIONS[clampi(command_tab, 0, COMMAND_ACTIONS.size() - 1)]

# Keep Arabic labels legible without clipping on narrow Android viewports.
func _hud_brand_font_size(size: Vector2) -> int:
	return clampi(int(round(size.x * 0.05)), 12, 19)


func _hud_metric_label_font_size(metric_width: float) -> int:
	return clampi(int(floor(metric_width * 0.15)), 8, 11)


func _hud_metric_value_font_size(metric_width: float) -> int:
	return clampi(int(floor(metric_width * 0.18)), 9, 14)


func _command_tab_font_size(tab_width: float) -> int:
	return clampi(int(floor(tab_width * 0.11)), 9, 15)


func _command_button_font_size(button_width: float) -> int:
	return clampi(int(floor(button_width * 0.12)), 9, 15)

func _battle_pointer_target(pos: Vector2, size: Vector2) -> String:
	# Explicit command targets take priority over the non-interactive HUD band.
	if _pause_rect(size).has_point(pos):
		return "pause"
	if _three_d_view_toggle_rect(size).has_point(pos):
		return "view"
	for tab_index in range(_command_tab_count()):
		if _command_tab_rect(tab_index, size).has_point(pos):
			return "tab:%d" % tab_index
	var visible_actions: Array = _command_action_ids()
	for slot in range(visible_actions.size()):
		if _button_rect(slot, size).has_point(pos):
			return "button:%d" % int(visible_actions[slot])
	# Resource, production and selected-unit panels are informational only.
	if build_mode.is_empty() and pos.y >= 0.0 and pos.y <= 197.0:
		return "hud"
	return ""




func _command_tab_rect(index: int, size: Vector2) -> Rect2:
	var tab_width := (size.x - 44.0) / float(_command_tab_count())
	return Rect2(Vector2(8.0 + float(index) * (tab_width + 4.0), size.y - 166.0), Vector2(tab_width, 32.0))


func _button_rect(index: int, size: Vector2) -> Rect2:
	var column := index % 3
	var row := int(index / 3)
	var button_width := (size.x - 40.0) / 3.0
	return Rect2(Vector2(8.0 + column * (button_width + 8.0), size.y - 126.0 + row * 54.0), Vector2(button_width, 48.0))

func _draw_faction_picker(size: Vector2) -> void:
	if campaign_briefing:
		_draw_campaign_briefing(size)
		return
	# A two-column grid keeps all four armies reachable on both portrait and landscape phones.
	var panel := Rect2(size.x * 0.06, size.y * 0.18, size.x * 0.88, size.y * 0.64)
	draw_rect(panel, Color(0.04, 0.07, 0.08, 0.96), true)
	draw_rect(panel, Color("#52666c"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 12.0, size.y * 0.30), "عاصفة الجنرالات", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 24.0, clampi(int(size.x * 0.03), 24, 38), Color("#f4d77a"))
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 12.0, size.y * 0.37), "اختر الجيش الذي ستقوده", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 24.0, clampi(int(size.x * 0.019), 16, 22), Color.WHITE)
	var progress: Dictionary = commander_profile.get("campaign_progress", {})
	for i in FACTIONS.size():
		var r := _faction_rect(i, size)
		draw_rect(r, Color("#28445a") if i != 3 else Color("#73552d"), true)
		draw_rect(r, Color("#b7c6d1"), false, 2.0)
		var completed := int(progress.get(FACTIONS[i], 0))
		var progress_label := "الحملة مكتملة" if completed >= CAMPAIGN_MISSIONS.size() else "المهمة %d / %d" % [completed + 1, CAMPAIGN_MISSIONS.size()]
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0.0, r.size.y * 0.45), FACTIONS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, clampi(int(size.x * 0.018), 14, 22), Color.WHITE)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0.0, r.size.y * 0.76), progress_label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color("#f4d77a"))


func _campaign_start_rect(size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x * 0.55, size.y * 0.64), Vector2(size.x * 0.34, 52))


func _campaign_back_rect(size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x * 0.11, size.y * 0.64), Vector2(size.x * 0.34, 52))


func _draw_campaign_briefing(size: Vector2) -> void:
	var progress: Dictionary = commander_profile.get("campaign_progress", {})
	var completed := int(progress.get(faction, 0))
	var mission_number := mini(completed, CAMPAIGN_MISSIONS.size() - 1)
	var mission: Dictionary = CAMPAIGN_MISSIONS[mission_number]
	var panel := Rect2(size.x * 0.06, size.y * 0.18, size.x * 0.88, size.y * 0.66)
	draw_rect(panel, Color(0.03, 0.06, 0.07, 0.97), true)
	draw_rect(panel, Color("#b18b45"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.30), "قيادة حملة: %s" % faction, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 23, Color("#f4d77a"))
	if completed >= CAMPAIGN_MISSIONS.size():
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.40), "أكملت جميع عمليات الحملة!", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 19, Color("#a8e6b0"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.48), "يمكنك إعادة خوض العملية الأخيرة", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 15, Color.WHITE)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.39), "العملية %d من %d: %s" % [completed + 1, CAMPAIGN_MISSIONS.size(), String(mission.name)], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 19, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.47), "المسرح: %s  |  مكافأة الإنجاز: %d" % [String(mission.map), int(mission.reward)], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 14, Color("#c4dce8"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.53), String(mission.brief), HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 15, Color("#d8e6c2"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.58), "الهدف الإضافي: %s — مكافأة %d" % [String(mission.get("secondary", "")), int(mission.get("bonus", 0))], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 12, Color("#f4d77a"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.63), "الطقس: مشمس ربيعي صافٍ دائماً", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 12, Color("#bce5f2"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.12, size.y * 0.68), "التقدم: %d / %d عمليات" % [completed, CAMPAIGN_MISSIONS.size()], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 12, Color("#f4d77a"))
	for i in CAMPAIGN_MISSIONS.size():
		var dot_x := size.x * 0.32 + float(i) * size.x * 0.09
		draw_circle(Vector2(dot_x, size.y * 0.59), 5.0, Color("#a8e6b0") if i < completed else Color("#657477"))
	var start_rect := _campaign_start_rect(size)
	var back_rect := _campaign_back_rect(size)
	draw_rect(start_rect, Color("#73552d"), true)
	draw_rect(start_rect, Color("#f4d77a"), false, 2.0)
	draw_string(ThemeDB.fallback_font, start_rect.position + Vector2(0, 32), "ابدأ العملية", HORIZONTAL_ALIGNMENT_CENTER, start_rect.size.x, 18, Color.WHITE)
	draw_rect(back_rect, Color("#28445a"), true)
	draw_rect(back_rect, Color("#b7c6d1"), false, 2.0)
	draw_string(ThemeDB.fallback_font, back_rect.position + Vector2(0, 32), "عودة", HORIZONTAL_ALIGNMENT_CENTER, back_rect.size.x, 18, Color.WHITE)

func _faction_rect(i: int, size: Vector2) -> Rect2:
	var panel_left := size.x * 0.06
	var panel_width := size.x * 0.88
	var inner_margin := minf(12.0, size.x * 0.03)
	var gap_x := clampf(size.x * 0.018, 8.0, 16.0)
	var gap_y := clampf(size.y * 0.018, 8.0, 14.0)
	var button_width := (panel_width - inner_margin * 2.0 - gap_x) * 0.5
	var button_height := clampf(size.y * 0.12, 62.0, 88.0)
	var column := i % 2
	var row := int(i / 2)
	var button_x := panel_left + inner_margin + float(column) * (button_width + gap_x)
	var button_y := size.y * 0.44 + float(row) * (button_height + gap_y)
	return Rect2(Vector2(button_x, button_y), Vector2(button_width, button_height))

func _input(event: InputEvent) -> void:
	# Track one finger for the full press/drag/release cycle. Secondary fingers
	# must not steal a selection or accidentally activate a different command.
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_touch_index != -1:
				return
			active_touch_index = event.index
		elif event.index != active_touch_index:
			return
		if use_3d_view:
			# The result overlay is drawn by the 2D command layer above the 3D
			# battlefield, so keep its restart button interactive in 3D mode.
			if battle_result != "":
				_handle_pointer(event.position, event.pressed)
				get_viewport().set_input_as_handled()
			elif not event.pressed and _three_d_view_toggle_rect(get_viewport_rect().size).has_point(event.position):
				_set_3d_view_enabled(false)
		else:
			_handle_pointer(event.position, event.pressed)
			get_viewport().set_input_as_handled()
		if not event.pressed:
			active_touch_index = -1
		return
	if event is InputEventScreenDrag:
		if active_touch_index == -1 or event.index != active_touch_index:
			return
		if not use_3d_view:
			drag_end = event.position
			queue_redraw()
		return
	# Ignore emulated mouse events while a finger owns the pointer.
	if active_touch_index != -1:
		return
	if use_3d_view:
		if battle_result != "":
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				_handle_pointer(event.position, event.pressed)
				get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _three_d_view_toggle_rect(get_viewport_rect().size).has_point(event.position):
				_set_3d_view_enabled(false)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position, event.pressed)
	elif event is InputEventMouseMotion and dragging:
		drag_end = event.position
		queue_redraw()

func _begin_campaign_battle(size: Vector2) -> void:
	var progress: Dictionary = commander_profile.get("campaign_progress", {})
	campaign_mission_index = clampi(int(progress.get(faction, 0)), 0, CAMPAIGN_MISSIONS.size() - 1)
	var mission: Dictionary = CAMPAIGN_MISSIONS[campaign_mission_index]
	command_tab = 0
	map_type = String(mission.map)
	battle_result = ""
	commander_profile_saved_result = ""
	var campaign_bonus := int(commander_profile.get("campaign_funds", 0))
	credits = STARTING_CREDITS + campaign_bonus
	if campaign_bonus > 0:
		commander_profile["campaign_funds"] = 0
		_save_commander_profile()
	supplies = 5
	enemy_supplies = 5
	_initialize_supply_points(size)
	income_timer = 0.0
	units.clear()
	missiles.clear()
	enemy_missile_timer = 0.0
	buildings.clear()
	production_orders.clear()
	enemy_buildings.clear()
	selected.clear()
	selected_enemy_building = -1
	selected_player_building = -1
	dragging = false
	visual_effects.clear()
	environment_particles.clear()
	build_mode = ""
	enemy_credits = STARTING_CREDITS
	enemy_income_timer = 0.0
	enemy_timer = 0.0
	player_base_hp = 1000
	enemy_base_hp = 1000
	paused = false
	campaign_briefing = false
	game_started = true
	units.append({"pos": base_pos + Vector2(58, 0), "team": "player", "kind": "builder", "faction": faction, "hp": 220, "attack_cd": 0.0})
	notice = "بدأت العملية %d: %s — مركبة البناء جاهزة" % [campaign_mission_index + 1, String(mission.name)]
	notice_time = 3.0
	queue_redraw()


func _group_formation_role_for_kind(unit_kind: String) -> int:
	if unit_kind == "artillery":
		return 0 # Fire support holds the rear line.
	if unit_kind in ["infantry", "builder", "marine"]:
		return 1 # Infantry screens the two outer flanks.
	if unit_kind in ["tank", "destroyer", "carrier", "submarine", "landing_craft"]:
		return 2 # Armor and direct-combat vehicles hold the center line.
	if unit_kind in ["fighter", "helicopter"]:
		return 3 # Aircraft move as a forward support layer.
	return 4 # Transport and utility units stay in a separate support lane.


func _group_formation_columns(role: int, unit_count: int) -> int:
	if role == 1:
		return 2
	return mini(4, maxi(1, int(ceil(sqrt(float(maxi(1, unit_count)))))))


func _group_formation_spacing(selected_indices: Array[int]) -> float:
	var spacing := 24.0
	for unit_index in selected_indices:
		if unit_index < 0 or unit_index >= units.size():
			continue
		var unit_kind := String(units[unit_index].get("kind", "tank"))
		var unit_spacing := 36.0
		if unit_kind in ["infantry", "builder", "marine"]:
			unit_spacing = 24.0
		elif unit_kind == "artillery":
			unit_spacing = 48.0
		elif unit_kind in ["fighter", "helicopter"]:
			unit_spacing = 50.0
		elif unit_kind == "transport_helicopter":
			unit_spacing = 54.0
		spacing = maxf(spacing, unit_spacing)
	return spacing


func _group_move_destination(unit_index: int, selected_indices: Array[int], center: Vector2) -> Vector2:
	var valid_indices: Array[int] = []
	var group_center := Vector2.ZERO
	for candidate_index in selected_indices:
		if candidate_index < 0 or candidate_index >= units.size() or valid_indices.has(candidate_index):
			continue
		var candidate: Dictionary = units[candidate_index]
		if String(candidate.get("team", "")) != "player" or int(candidate.get("hp", 0)) <= 0:
			continue
		valid_indices.append(candidate_index)
		group_center += candidate.pos
	if not valid_indices.has(unit_index):
		return center
	if valid_indices.size() <= 1:
		return center
	group_center /= float(valid_indices.size())
	var forward := center - group_center
	if forward.length_squared() < 0.0001:
		forward = Vector2.RIGHT
	else:
		forward = forward.normalized()
	var right := Vector2(-forward.y, forward.x)
	var spacing := _group_formation_spacing(valid_indices)
	var role_counts: Array[int] = [0, 0, 0, 0, 0]
	var role := _group_formation_role_for_kind(String(units[unit_index].get("kind", "tank")))
	var role_index := 0
	for candidate_index in valid_indices:
		var candidate_role := _group_formation_role_for_kind(String(units[candidate_index].get("kind", "tank")))
		if candidate_index == unit_index:
			role_index = role_counts[candidate_role]
		role_counts[candidate_role] += 1
	var preceding_rows := 0
	var total_rows := 0
	for role_index_value in range(role_counts.size()):
		var role_columns := _group_formation_columns(role_index_value, role_counts[role_index_value])
		var role_rows := int(ceil(float(role_counts[role_index_value]) / float(role_columns))) if role_counts[role_index_value] > 0 else 0
		total_rows += role_rows
		if role_index_value < role:
			preceding_rows += role_rows
	var columns := _group_formation_columns(role, role_counts[role])
	var row := int(role_index / columns)
	var column := role_index % columns
	var lane_row := preceding_rows + row
	var depth := (float(lane_row) - (float(total_rows) - 1.0) * 0.5) * spacing
	var lateral := (float(column) - float(columns - 1) * 0.5) * spacing
	if role == 1:
		var flank := -1.0 if column == 0 else 1.0
		lateral = flank * (spacing * 1.25 + float(row) * spacing * 0.55)
	var destination := center + forward * depth + right * lateral
	var viewport_size := get_viewport_rect().size
	var margin := 24.0
	destination.x = clampf(destination.x, margin, viewport_size.x - margin)
	destination.y = clampf(destination.y, margin, viewport_size.y - margin)
	return destination


func _group_attack_formation_offsets(selected_indices: Array[int], target_pos: Vector2) -> Dictionary:
	# Build a target-relative combined-arms line: armor forward, infantry on the flanks, artillery in the rear.
	var ground_indices: Array[int] = []
	var role_counts: Dictionary = {"tank": 0, "infantry": 0, "artillery": 0}
	var group_center := Vector2.ZERO
	for unit_index in selected_indices:
		if unit_index < 0 or unit_index >= units.size() or ground_indices.has(unit_index):
			continue
		var attacker: Dictionary = units[unit_index]
		var unit_kind := String(attacker.get("kind", ""))
		if String(attacker.get("team", "")) != "player" or int(attacker.get("hp", 0)) <= 0 or not role_counts.has(unit_kind):
			continue
		ground_indices.append(unit_index)
		group_center += attacker.pos
		role_counts[unit_kind] = int(role_counts[unit_kind]) + 1
	if ground_indices.is_empty():
		return {}
	group_center /= float(ground_indices.size())
	var forward := target_pos - group_center
	if forward.length_squared() <= 0.01:
		forward = Vector2.RIGHT
	else:
		forward = forward.normalized()
	var lateral := Vector2(-forward.y, forward.x)
	var role_seen: Dictionary = {"tank": 0, "infantry": 0, "artillery": 0}
	var offsets: Dictionary = {}
	for unit_index in ground_indices:
		var unit_kind := String(units[unit_index].get("kind", ""))
		var rank := int(role_seen[unit_kind])
		role_seen[unit_kind] = rank + 1
		var row := int(rank / 2)
		var side := 0.0
		if int(role_counts[unit_kind]) > 1:
			side = -1.0 if rank % 2 == 0 else 1.0
		var offset := Vector2.ZERO
		match unit_kind:
			"tank":
				offset = -forward * (92.0 + float(row) * 28.0) + lateral * side * (28.0 + float(row) * 14.0)
			"infantry":
				offset = -forward * (142.0 + float(row) * 24.0) + lateral * side * (72.0 + float(row) * 20.0)
			"artillery":
				offset = -forward * (250.0 + float(row) * 38.0) + lateral * side * (54.0 + float(row) * 30.0)
		offsets[unit_index] = offset
	return offsets


func _issue_group_attack_order(target_index: int) -> void:
	if target_index < 0 or target_index >= units.size():
		return
	var target: Dictionary = units[target_index]
	if String(target.get("team", "")) != "enemy" or int(target.get("hp", 0)) <= 0:
		return
	var shared_focus: Vector2 = target.pos
	var group_offsets := _group_attack_formation_offsets(selected, shared_focus)
	var issued_indices: Array[int] = []
	for unit_index in selected:
		if unit_index < 0 or unit_index >= units.size() or issued_indices.has(unit_index):
			continue
		var attacker: Dictionary = units[unit_index]
		if String(attacker.get("team", "")) != "player" or int(attacker.get("hp", 0)) <= 0:
			continue
		issued_indices.append(unit_index)
		_cancel_airfield_recovery(attacker)
		attacker["attack_target"] = target_index
		attacker["attack_focus_pos"] = shared_focus
		if group_offsets.has(unit_index):
			attacker["attack_formation_offset"] = group_offsets[unit_index]
		else:
			attacker.erase("attack_formation_offset")
		# A focused attack replaces stale movement, patrol, defense, and escort orders.
		for order_key in ["target", "air_patrol_points", "air_patrol_index", "air_patrol_resume", "attack_base", "attack_building", "attack_move_active", "guard_active", "guard_position", "guard_radius", "escort_active", "escort_target_id", "escort_offset"]:
			attacker.erase(order_key)
	if not issued_indices.is_empty():
		notice = "أمر هجوم جماعي — تموضع تكتيكي حسب دور كل وحدة مع تركيز النيران"
		notice_time = 1.8


func _handle_pointer(pos: Vector2, pressed: bool) -> void:
	var size = get_viewport_rect().size
	if pressed:
		dragging = true
		drag_start = pos
		drag_end = pos
		pointer_start_target = _battle_pointer_target(pos, size) if game_started and battle_result == "" else ""
		return
	if not dragging:
		return
	dragging = false
	if game_started and battle_result == "":
		var release_target := _battle_pointer_target(pos, size)
		# A press/release pair belongs to one target. Never let a drag that
		# crosses between the command deck and battlefield become a stray order.
		if pointer_start_target != release_target or release_target == "hud":
			pointer_start_target = ""
			queue_redraw()
			return
	pointer_start_target = ""
	if battle_result != "":
		if _restart_rect(size).has_point(pos):
			_set_3d_view_enabled(false)
			game_started = false
			paused = false
			battle_result = ""
			faction = ""
			command_tab = 0
			units.clear()
			buildings.clear()
			production_orders.clear()
			enemy_buildings.clear()
			selected.clear()
			selected_enemy_building = -1
			selected_player_building = -1
			dragging = false
			build_mode = ""
			credits = STARTING_CREDITS
			supplies = 5
			enemy_supplies = 5
			supply_points.clear()
			enemy_credits = STARTING_CREDITS
			player_base_hp = 1000
			enemy_base_hp = 1000
			income_timer = 0.0
			enemy_income_timer = 0.0
			enemy_timer = 0.0
			visual_effects.clear()
			environment_particles.clear()
			missiles.clear()
			enemy_missile_timer = 0.0
			queue_redraw()
		return
	if game_started and _three_d_view_toggle_rect(size).has_point(pos):
		_set_3d_view_enabled(true)
		return
	if game_started and _pause_rect(size).has_point(pos):
		paused = not paused
		notice = "تم إيقاف المعركة مؤقتاً" if paused else "استؤنفت المعركة"
		notice_time = 2.0
		queue_redraw()
		return
	if paused:
		return
	if not game_started:
		if campaign_briefing:
			if _campaign_back_rect(size).has_point(pos):
				campaign_briefing = false
				faction = ""
				queue_redraw()
				return
			if _campaign_start_rect(size).has_point(pos):
				_begin_campaign_battle(size)
				return
		else:
			for i in FACTIONS.size():
				if _faction_rect(i, size).has_point(pos):
					faction = FACTIONS[i]
					var progress: Dictionary = commander_profile.get("campaign_progress", {})
					campaign_mission_index = clampi(int(progress.get(faction, 0)), 0, CAMPAIGN_MISSIONS.size() - 1)
					campaign_briefing = true
					queue_redraw()
					return
		return
	for tab_index in range(_command_tab_count()):
		if _command_tab_rect(tab_index, size).has_point(pos):
			command_tab = tab_index
			queue_redraw()
			return
	var command_actions: Array = _command_action_ids()
	for button_slot in range(command_actions.size()):
		var i := int(command_actions[button_slot])
		if _button_rect(button_slot, size).has_point(pos):
			if i == 0:
				_enqueue_unit("infantry")
			elif i == 1:
				_enqueue_unit("tank")
			elif i == 2:
				build_mode = "barracks"
				notice = "المس موقعاً في منطقتك لبناء الثكنة"
				notice_time = 3.0
			elif i == 3:
				build_mode = "factory"
				notice = "المس موقعاً في منطقتك لبناء المصنع"
				notice_time = 3.0
			elif i == 4:
				build_mode = "turret"
				notice = "المس موقعاً في منطقتك لبناء برج الدفاع"
				notice_time = 3.0
			elif i == 5:
				_enqueue_unit("artillery")
			elif i == 6:
				build_mode = "airfield"
				notice = "المس موقعاً مناسباً لبناء المطار"
				notice_time = 3.0
			elif i == 7:
				_enqueue_unit("fighter")
			elif i == 8:
				build_mode = "anti_air"
				notice = "المس موقعاً مناسباً لنشر الدفاع المضاد للطائرات"
				notice_time = 3.0
			elif i == 9:
				_enqueue_unit("helicopter")
			elif i == 10:
				if _has_selected_player_building():
					_repair_selected_building()
				else:
					_capture_selected_building()
			elif i == 11:
				if _has_selected_player_building():
					_sell_selected_building()
				else:
					_order_destroy_selected_building()
			elif i == 12:
				if build_mode != "":
					build_mode = ""
					notice = "تم إلغاء أمر البناء"
					notice_time = 1.8
				elif _has_selected_player_building():
					_upgrade_selected_building()
				else:
					selected.clear()
					selected_enemy_building = -1
					selected_player_building = -1
					notice = "حدد منشأة لترقيتها أو اختر أمر بناء"
					notice_time = 2.0
			elif i == 13:
				build_mode = "missile_silo"
				notice = "اختر موقعاً قرب قاعدتك لبناء منصة الصواريخ"
				notice_time = 3.0
			elif i == 14:
				build_mode = "missile_defense"
				notice = "اختر موقعاً لنشر منظومة الدفاع الصاروخي"
				notice_time = 3.0
			elif i == 15:
				_launch_player_missile()
			elif i == 16:
				build_mode = "shipyard"
				notice = "اختر منطقة ساحلية في أسفل الخريطة لبناء حوض السفن"
				notice_time = 3.0
			elif i == 17:
				_enqueue_unit("destroyer")
			elif i == 18:
				_enqueue_unit("carrier")
			elif i == 19:
				_enqueue_unit("submarine")
			elif i == 20:
				_enqueue_unit("landing_craft")
			elif i == 21:
				_enqueue_unit("builder")
			elif i == 22:
				build_mode = "power_plant"
				notice = "اختر موقعاً قرب قاعدتك لبناء محطة الطاقة"
				notice_time = 3.0
			elif i == 23:
				build_mode = "bunker"
				notice = "اختر موقعاً مناسباً لبناء مخبأ دفاعي — يوفر نيراناً وحماية للقوات القريبة"
				notice_time = 3.5
			elif i == 25:
				build_mode = "wall"
				notice = "اختر موضعاً لبناء مقطع جدار دفاعي مستقيم"
				notice_time = 3.0
			elif i == 26:
				build_mode = "wall_corner"
				notice = "اختر موضعاً لبناء زاوية تحصين"
				notice_time = 3.0
			elif i == 27:
				build_mode = "wall_gate"
				notice = "اختر موضعاً لإنشاء بوابة القاعدة"
				notice_time = 3.0
			elif i == 28:
				_enqueue_unit("transport_helicopter")
			elif i == 29:
				_load_selected_infantry_into_transport()
			elif i == 30:
				_prepare_transport_rooftop_landing()
			elif i == 31:
				_cancel_transport_order()
			elif i == 24:
				var depot_count := 0
				for building in buildings:
					if String(building.get("kind", "")) == "supply_depot":
						depot_count += 1
				if depot_count >= 2:
					notice = "وصلت إلى الحد الأقصى لمخازن الإمداد (2)"
					notice_time = 2.5
				else:
					build_mode = "supply_depot"
					notice = "اختر موقعاً مناسباً لبناء مخزن الإمداد — يزيد السعة ويجهز الإمدادات دورياً"
					notice_time = 3.5
			else:
				selected.clear()
				selected_enemy_building = -1
				build_mode = ""
			queue_redraw()
			return
	if build_mode != "":
		_place_building(pos)
		queue_redraw()
		return
	if _issue_transport_rooftop_order(pos):
		queue_redraw()
		return
	if drag_start.distance_to(pos) > 24.0:
		selected_enemy_building = -1
		selected_player_building = -1
		selected.clear()
		var area := Rect2(drag_start, pos - drag_start).abs()
		for i in units.size():
			if units[i].team == "player" and int(units[i].get("hp", 0)) > 0 and area.has_point(units[i].pos):
				selected.append(i)
	else:
		var player_building_found := -1
		for i in buildings.size():
			if buildings[i].pos.distance_to(pos) < 40.0:
				player_building_found = i
				break
		if player_building_found >= 0:
			selected_player_building = player_building_found
			selected_enemy_building = -1
			selected.clear()
			notice = "تم تحديد منشأتك — اختر الإصلاح أو البيع"
			notice_time = 2.5
			queue_redraw()
			return
		selected_player_building = -1
		var building_found = -1
		for i in enemy_buildings.size():
			if enemy_buildings[i].pos.distance_to(pos) < 38.0:
				building_found = i
				break
		if building_found >= 0:
			selected_player_building = -1
			selected_enemy_building = building_found
			notice = "تم تحديد مبنى العدو — اختر السيطرة أو التدمير"
			notice_time = 3.0
			queue_redraw()
			return
		var enemy_found := -1
		for i in units.size():
			if units[i].team == "enemy" and units[i].get("hp", 0) > 0 and units[i].pos.distance_to(pos) < 30 and (units[i].kind != "submarine" or _is_submarine_detected(units[i], "player")):
				enemy_found = i
				break
		if not selected.is_empty() and pos.distance_to(enemy_base) <= 65.0:
			for idx in selected:
				if idx < units.size() and units[idx].team == "player":
					_cancel_airfield_recovery(units[idx])
					units[idx].attack_base = true
					# A fresh attack order supersedes any stale movement or patrol route.
					units[idx].erase("target")
					units[idx].erase("air_patrol_points")
					units[idx].erase("air_patrol_index")
					units[idx].erase("air_patrol_resume")
					units[idx].erase("attack_target")
					units[idx].erase("attack_focus_pos")
					units[idx].erase("attack_building")
					units[idx].erase("attack_move_active")
					units[idx].erase("guard_active")
					units[idx].erase("escort_active")
					units[idx].erase("escort_target_id")
					units[idx].erase("escort_offset")
			notice = "هجوم على قاعدة العدو!"
			notice_time = 1.5
		elif enemy_found >= 0 and not selected.is_empty():
			_issue_group_attack_order(enemy_found)
		else:
			var found = -1
			for i in units.size():
				if units[i].team == "player" and units[i].get("hp", 0) > 0 and units[i].pos.distance_to(pos) < 24:
					found = i
					break
			if found >= 0:
				# Mobile-friendly additive selection: tap to add a unit, tap it again to remove it.
				# Drag-selection still replaces the current selection with the units inside the box.
				if selected.has(found):
					selected.erase(found)
				else:
					selected.append(found)
			else:
				var move_group_indices: Array[int] = selected.duplicate()
				for idx in move_group_indices:
					if idx >= 0 and idx < units.size() and units[idx].team == "player":
						_cancel_airfield_recovery(units[idx])
						units[idx].target = _group_move_destination(idx, move_group_indices, pos)
						# A direct group move overrides previous combat and stance orders.
						for order_key in ["attack_target", "attack_focus_pos", "attack_base", "attack_building", "attack_move_active", "guard_active", "guard_position", "guard_radius", "escort_active", "escort_target_id", "escort_offset", "air_patrol_points", "air_patrol_index", "air_patrol_resume"]:
							units[idx].erase(order_key)
	queue_redraw()

func _initialize_supply_points(size: Vector2) -> void:
	supply_points = [
		{"pos": Vector2(size.x * 0.34, size.y * 0.28), "owner": "player", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"},
		{"pos": Vector2(size.x * 0.66, size.y * 0.72), "owner": "enemy", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"},
		{"pos": Vector2(size.x * 0.50, size.y * 0.695), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "port"},
		{"pos": Vector2(size.x * 0.50, size.y * 0.52), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "bridge"}
	]

func _update_supply_control(delta: float) -> void:
	for i in range(supply_points.size()):
		var point_pos: Vector2 = supply_points[i].pos
		var player_near := false
		var enemy_near := false
		for unit in units:
			if unit.get("hp", 0) <= 0 or unit.pos.distance_to(point_pos) > 62.0:
				continue
			if unit.team == "player":
				player_near = true
			else:
				enemy_near = true
		if player_near and not enemy_near:
			if supply_points[i].owner != "player":
				supply_points[i].owner = "player"
				supply_points[i].payout = 0.0
				supply_points[i].supply_payout = 0.0
				var captured_kind := String(supply_points[i].get("kind", "supply"))
				notice = "سيطر جيشك على الميناء الاستراتيجي!" if captured_kind == "port" else ("أمّنت قواتك الجسر العسكري!" if captured_kind == "bridge" else "سيطر جيشك على نقطة إمداد!")
				notice_time = 2.5
		elif enemy_near and not player_near:
			if supply_points[i].owner != "enemy":
				supply_points[i].owner = "enemy"
				supply_points[i].payout = 0.0
				supply_points[i].supply_payout = 0.0
				var captured_kind := String(supply_points[i].get("kind", "supply"))
				notice = "العدو استولى على الميناء الاستراتيجي!" if captured_kind == "port" else ("العدو سيطر على الجسر العسكري!" if captured_kind == "bridge" else "العدو استولى على نقطة إمداد!")
				notice_time = 2.5
		if player_near and enemy_near:
			continue
		var point_kind := String(supply_points[i].get("kind", "supply"))
		var is_port := point_kind == "port"
		var is_bridge := point_kind == "bridge"
		var gold_rate := 8 if is_port else (6 if is_bridge else 4)
		var supply_interval := 6.0 if is_port else (7.0 if is_bridge else 8.0)
		if supply_points[i].owner == "player":
			supply_points[i].payout += delta
			supply_points[i].supply_payout += delta
			if supply_points[i].payout >= 1.0:
				credits = mini(MAX_CREDITS, credits + gold_rate * int(supply_points[i].payout))
				supply_points[i].payout = fmod(supply_points[i].payout, 1.0)
			if supply_points[i].supply_payout >= supply_interval:
				supplies = mini(_player_supply_capacity(), supplies + int(supply_points[i].supply_payout / supply_interval))
				supply_points[i].supply_payout = fmod(supply_points[i].supply_payout, supply_interval)
		elif supply_points[i].owner == "enemy":
			supply_points[i].payout += delta
			supply_points[i].supply_payout += delta
			if supply_points[i].payout >= 1.0:
				enemy_credits = mini(MAX_CREDITS, enemy_credits + gold_rate * int(supply_points[i].payout))
				supply_points[i].payout = fmod(supply_points[i].payout, 1.0)
			if supply_points[i].supply_payout >= supply_interval:
				enemy_supplies = mini(99, enemy_supplies + int(supply_points[i].supply_payout / supply_interval))
				supply_points[i].supply_payout = fmod(supply_points[i].supply_payout, supply_interval)


func _enemy_best_supply_objective(unit_pos: Vector2) -> int:
	# Enemy ground forces prioritize recapturing player-held income, then neutral objectives.
	var best_point := -1
	var best_priority := INF
	for point_index in range(supply_points.size()):
		var point: Dictionary = supply_points[point_index]
		if String(point.get("owner", "neutral")) == "enemy":
			continue
		var distance: float = unit_pos.distance_to(point.pos)
		var income_weight := 1.5 if String(point.get("kind", "supply")) == "port" else 1.0
		var ownership_weight := 2.2 if String(point.get("owner", "neutral")) == "player" else 1.0
		var priority: float = distance / (income_weight * ownership_weight)
		if priority < best_priority:
			best_priority = priority
			best_point = point_index
	return best_point


func _enemy_supply_reinforcement_point(unit_index: int) -> int:
	if unit_index < 0 or unit_index >= units.size():
		return -1
	var candidate_unit: Dictionary = units[unit_index]
	if candidate_unit.team != "enemy" or not ["infantry", "tank"].has(String(candidate_unit.kind)):
		return -1
	var best_point := -1
	var best_distance := INF
	for point_index in range(supply_points.size()):
		var point: Dictionary = supply_points[point_index]
		if String(point.get("owner", "neutral")) != "enemy":
			continue
		var player_threat := false
		var enemy_garrisoned := false
		for other_index in range(units.size()):
			var other: Dictionary = units[other_index]
			if int(other.get("hp", 0)) <= 0:
				continue
			var distance: float = other.pos.distance_to(point.pos)
			if other.team == "player" and distance <= 180.0:
				player_threat = true
			elif other.team == "enemy" and distance <= 85.0:
				enemy_garrisoned = true
		if not player_threat or enemy_garrisoned:
			continue
		var nearest_guard := -1
		var nearest_distance := INF
		for guard_index in range(units.size()):
			var guard: Dictionary = units[guard_index]
			if guard.team != "enemy" or int(guard.get("hp", 0)) <= 0 or not ["infantry", "tank"].has(String(guard.kind)):
				continue
			var guard_distance: float = guard.pos.distance_squared_to(point.pos)
			if guard_distance < nearest_distance:
				nearest_distance = guard_distance
				nearest_guard = guard_index
		if nearest_guard != unit_index:
			continue
		var distance_to_point: float = candidate_unit.pos.distance_to(point.pos)
		if distance_to_point < best_distance:
			best_distance = distance_to_point
			best_point = point_index
	return best_point

func _draw_spring_sun(size: Vector2) -> void:
	# The battlefield climate is intentionally fixed: clear, sunny spring daylight.
	var center := Vector2(size.x - 38.0, 42.0)
	draw_circle(center, 27.0, Color(1.0, 0.86, 0.48, 0.10))
	draw_circle(center, 20.0, Color(1.0, 0.88, 0.52, 0.18))
	for ray_index in range(12):
		var angle := TAU * float(ray_index) / 12.0
		var ray_start := center + Vector2(cos(angle), sin(angle)) * 23.0
		var ray_end := center + Vector2(cos(angle), sin(angle)) * 29.0
		draw_line(ray_start, ray_end, Color("#f5d77e", 0.62), 2.0)
	draw_circle(center, 15.0, Color("#f5d77e"))
	draw_circle(center + Vector2(-4.0, -4.0), 5.0, Color("#ffe9a6", 0.72))


func _draw_terrain(size: Vector2) -> void:
	var ground = Color("#9a835d")
	var road := Color("#b5a17c")
	match map_type:
		"ساحل الغابات":
			ground = Color("#405b43")
			road = Color("#8e9271")
		"الساحل الجبلي":
			ground = Color("#686d68")
			road = Color("#aaa99a")
		"المدينة الساحلية":
			ground = Color("#596168")
			road = Color("#a3a6a5")
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	for x in range(0, int(size.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, size.y * 0.675), Color(1, 1, 1, 0.025), 1)
	for y in range(0, int(size.y * 0.675), 64):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.025), 1)
	# A continuous military road connects both bases in every coastal theater
	draw_rect(Rect2(0, size.y * 0.365, size.x, 76), Color("#766b57"))
	draw_rect(Rect2(0, size.y * 0.375, size.x, 58), road)
	match map_type:
		"الساحل الصحراوي":
			for i in range(18):
				var p = Vector2(float((i * 137 + 38) % int(size.x)), 78.0 + float((i * 83) % maxi(1, int(size.y * 0.53))))
				draw_arc(p, 22.0 + float(i % 3) * 7.0, 3.3, 6.1, 28, Color("#d4bd8b", 0.35), 3.0)
				draw_circle(p + Vector2(18, 9), 2.0, Color("#d8c49a", 0.5))
		"ساحل الغابات":
			for i in range(26):
				var p = Vector2(float((i * 97 + 35) % int(size.x)), 75.0 + float((i * 61) % maxi(1, int(size.y * 0.55))))
				if absf(p.y - size.y * 0.40) < 52.0:
					continue
				draw_rect(Rect2(p + Vector2(-3, 7), Vector2(6, 13)), Color("#554432"))
				draw_circle(p, 15.0, Color("#294b35"))
				draw_circle(p + Vector2(-5, -5), 9.0, Color("#507348"))
		"الساحل الجبلي":
			for i in range(11):
				var x = float(i) * size.x / 10.0
				var y := 105.0 + float((i * 59) % maxi(1, int(size.y * 0.40)))
				var peak := Vector2(x, y)
				var mountain := PackedVector2Array([peak + Vector2(-48, 58), peak + Vector2(0, -38 - float(i % 3) * 12.0), peak + Vector2(55, 58)])
				draw_colored_polygon(mountain, Color("#505b58"))
				draw_line(peak + Vector2(0, -30), peak + Vector2(20, 4), Color("#c0c3b9", 0.55), 3.0)
		"المدينة الساحلية":
			for row in range(3):
				for col in range(10):
					var p = Vector2(24.0 + col * size.x / 10.0, 85.0 + row * 155.0)
					if absf(p.y - size.y * 0.40) < 72.0:
						continue
					var block_color := Color("#747d83") if (row + col) % 2 == 0 else Color("#69737a")
					draw_rect(Rect2(p, Vector2(35, 27)), block_color)
					draw_rect(Rect2(p + Vector2(5, 5), Vector2(8, 6)), Color("#d2c59a", 0.55))
					draw_rect(Rect2(p + Vector2(21, 5), Vector2(8, 6)), Color("#d2c59a", 0.45))
	# Decorative landmarks enrich each theater without blocking movement lanes.
	_draw_map_landmarks(size)
	# Bases, supply nodes and the shoreline remain in clear tactical lanes

func _draw_map_landmarks(size: Vector2) -> void:
	match map_type:
		"الساحل الصحراوي":
			# Small spring oasis and sunlit rock formations, kept clear of the central road.
			for oasis_index in range(3):
				var oasis := Vector2(size.x * (0.16 + oasis_index * 0.34), size.y * (0.19 + float(oasis_index % 2) * 0.34))
				if absf(oasis.y - size.y * 0.40) < 75.0:
					continue
				draw_ellipse_placeholder(oasis, Vector2(24, 8), Color("#477b65", 0.55))
				draw_circle(oasis + Vector2(-12, -5), 7, Color("#39714f"))
				draw_circle(oasis + Vector2(2, -8), 8, Color("#54875b"))
				draw_circle(oasis + Vector2(14, -3), 6, Color("#6c985e"))
			for rock_index in range(5):
				var rock_pos := Vector2(size.x * (0.08 + rock_index * 0.19), size.y * (0.12 + float((rock_index * 3) % 5) * 0.09))
				if absf(rock_pos.y - size.y * 0.40) > 78.0:
					draw_colored_polygon(PackedVector2Array([rock_pos + Vector2(-13, 8), rock_pos + Vector2(-5, -9), rock_pos + Vector2(11, -5), rock_pos + Vector2(16, 8)]), Color("#b49b70", 0.72))
		"ساحل الغابات":
			# Sunlit clearings and low shrubs add depth between the tree groups.
			for clearing_index in range(5):
				var clearing := Vector2(size.x * (0.10 + clearing_index * 0.20), size.y * (0.16 + float(clearing_index % 2) * 0.36))
				if absf(clearing.y - size.y * 0.40) < 70.0:
					continue
				draw_circle(clearing, 17, Color("#9db27a", 0.18))
				draw_circle(clearing + Vector2(15, 7), 5, Color("#718c58", 0.62))
				draw_circle(clearing + Vector2(-12, 9), 4, Color("#819b61", 0.62))
		"الساحل الجبلي":
			# Layered foothills and bright exposed stone at the edges of the battlefield.
			for ridge_index in range(6):
				var ridge_x := size.x * (0.08 + ridge_index * 0.17)
				var ridge_y := size.y * (0.18 + float(ridge_index % 3) * 0.12)
				if absf(ridge_y - size.y * 0.40) < 75.0:
					continue
				draw_line(Vector2(ridge_x - 23, ridge_y + 12), Vector2(ridge_x, ridge_y - 9), Color("#aeb6a6", 0.42), 3.0)
				draw_line(Vector2(ridge_x, ridge_y - 9), Vector2(ridge_x + 19, ridge_y + 12), Color("#d0c9a9", 0.32), 2.0)
		"المدينة الساحلية":
			# Sidewalks, planted squares and warm street lamps frame the urban lanes.
			for plaza_index in range(4):
				var plaza := Vector2(size.x * (0.13 + plaza_index * 0.25), size.y * (0.17 + float(plaza_index % 2) * 0.34))
				if absf(plaza.y - size.y * 0.40) < 78.0:
					continue
				draw_rect(Rect2(plaza - Vector2(13, 10), Vector2(26, 20)), Color("#a8a18b", 0.48))
				draw_circle(plaza, 5, Color("#6e9564"))
				draw_line(plaza + Vector2(17, -7), plaza + Vector2(17, 9), Color("#454e50"), 2.0)
				draw_circle(plaza + Vector2(17, -9), 3, Color("#f2d58a", 0.78))


func draw_ellipse_placeholder(center: Vector2, radii: Vector2, tint: Color) -> void:
	# Draw a compact ellipse from a polygon for broad Godot-version compatibility.
	var points := PackedVector2Array()
	for point_index in range(20):
		var angle := TAU * float(point_index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, tint)


func _draw_supply_points() -> void:
	for point in supply_points:
		var p: Vector2 = point.pos
		var owner: String = point.owner
		var point_kind := String(point.get("kind", "supply"))
		var is_port := point_kind == "port"
		var is_bridge := point_kind == "bridge"
		var tint := Color("#438bd2") if owner == "player" else (Color("#d65349") if owner == "enemy" else Color("#e0c16e"))
		if owner != "neutral":
			# The outer ring marks the radius where friendly garrison cover is active.
			draw_arc(p, 72.0, 0.0, TAU, 64, Color(tint, 0.30), 2.0)
		if is_bridge:
			draw_circle(p, 47, Color(tint, 0.12))
			draw_arc(p, 47, 0.0, TAU, 56, tint, 4.0)
			# A stone road bridge with two piers and visible deck markings.
			draw_rect(Rect2(p + Vector2(-48, -15), Vector2(96, 30)), Color("#716c5c"))
			draw_rect(Rect2(p + Vector2(-44, -11), Vector2(88, 22)), Color("#c0b18c"))
			for bridge_mark in range(5):
				draw_rect(Rect2(p + Vector2(-34 + bridge_mark * 17, -2), Vector2(9, 4)), Color("#766f5c"))
			for pier_x in [-34.0, 34.0]:
				draw_rect(Rect2(p + Vector2(pier_x, 15), Vector2(9, 12)), Color("#5d594d"))
			var bridge_label := "جسر محايد" if owner == "neutral" else ("جسرك العسكري" if owner == "player" else "جسر العدو")
			draw_string(ThemeDB.fallback_font, p + Vector2(-65, 66), bridge_label, HORIZONTAL_ALIGNMENT_CENTER, 130, 15, Color.WHITE)
		elif is_port:
			draw_circle(p, 43, Color(tint, 0.14))
			draw_arc(p, 43, 0.0, TAU, 56, tint, 4.0)
			# Pier, mooring posts and a small harbor office
			draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 54)), Color("#735c3e"))
			draw_rect(Rect2(p + Vector2(-35, 42), Vector2(70, 12)), Color("#b79b6b"))
			for post_x in [-29.0, 29.0]:
				draw_rect(Rect2(p + Vector2(post_x, 38), Vector2(6, 19)), Color("#4a4033"))
			draw_rect(Rect2(p + Vector2(-19, -26), Vector2(38, 25)), Color("#d0b98a"))
			draw_rect(Rect2(p + Vector2(-12, -20), Vector2(24, 19)), tint)
			var port_label := "ميناء محايد" if owner == "neutral" else ("ميناؤك" if owner == "player" else "ميناء العدو")
			draw_string(ThemeDB.fallback_font, p + Vector2(-65, 79), port_label, HORIZONTAL_ALIGNMENT_CENTER, 130, 16, Color.WHITE)
		else:
			draw_circle(p, 34, Color(tint, 0.18))
			draw_arc(p, 34, 0.0, TAU, 48, tint, 4.0)
			draw_circle(p, 12, Color("#d7c58a"))
			draw_rect(Rect2(p + Vector2(-4, -19), Vector2(8, 38)), Color("#493d2d"))
			draw_rect(Rect2(p + Vector2(4, -17), Vector2(18, 10)), tint)
			var label := "إمدادك" if owner == "player" else "إمداد العدو"
			draw_string(ThemeDB.fallback_font, p + Vector2(-48, 55), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 15, Color.WHITE)

func _building_cost(kind: String) -> int:
	var costs: Dictionary = ECONOMY_BALANCE["building_costs"]
	return int(costs.get(kind, TURRET_COST))

func _building_max_hp(building: Dictionary) -> int:
	var base_hp := 400
	if String(building.get("kind", "")) == "bunker":
		base_hp = 650
	match String(building.get("kind", "")):
		"missile_silo": base_hp = 500
		"missile_defense": base_hp = 450
		"wall": base_hp = 280
		"wall_corner": base_hp = 360
		"wall_gate": base_hp = 220
	return int(round(float(base_hp) * (1.0 + float(maxi(1, int(building.get("level", 1))) - 1) * 0.20)))


func _upgrade_selected_building() -> void:
	if not _has_selected_player_building():
		notice = "حدد منشأة من قاعدتك لترقيتها أو ألغِ وضع البناء"
		notice_time = 2.2
		return
	var index := selected_player_building
	var building: Dictionary = buildings[index]
	if float(building.get("build_progress", 1.0)) < 1.0 or int(building.get("hp", 0)) <= 0:
		notice = "لا يمكن ترقية منشأة غير مكتملة أو مدمرة"
		notice_time = 2.2
		return
	var level := maxi(1, int(building.get("level", 1)))
	if level >= 3:
		notice = "وصلت المنشأة إلى أقصى مستوى تطوير"
		notice_time = 2.2
		return
	var kind := String(building.get("kind", ""))
	var building_index := index
	if _power_demand(kind) > 0 and not _is_player_building_powered(building_index):
		notice = "أعد استقرار شبكة الطاقة قبل ترقية هذه المنشأة"
		notice_time = 2.5
		return
	var upgrade_cost := int(ceil(float(_building_cost(kind)) * (0.60 if level == 1 else 0.85)))
	if credits < upgrade_cost:
		notice = "الموارد غير كافية — الترقية تحتاج %d" % upgrade_cost
		notice_time = 2.5
		return
	credits -= upgrade_cost
	building["level"] = level + 1
	building["hp"] = mini(_building_max_hp(building), int(building.get("hp", 0)) + 80)
	buildings[index] = building
	var level_name := "الثاني" if level + 1 == 2 else "الثالث"
	notice = "تم تطوير المنشأة إلى المستوى %s — التكلفة %d" % [level_name, upgrade_cost]
	notice_time = 2.8
	queue_redraw()


func _has_selected_player_building() -> bool:
	return selected_player_building >= 0 and selected_player_building < buildings.size()


func _repair_selected_building() -> void:
	if not _has_selected_player_building():
		notice = "حدد إحدى منشآتك أولاً"
		notice_time = 2.0
		return
	var building: Dictionary = buildings[selected_player_building]
	if float(building.get("build_progress", 1.0)) < 1.0:
		notice = "لا يمكن إصلاح منشأة قبل اكتمال بنائها"
		notice_time = 2.0
		return
	var max_hp := _building_max_hp(building)
	var current_hp := clampi(int(building.get("hp", max_hp)), 0, max_hp)
	if current_hp <= 0:
		notice = "المنشأة مدمرة ولا يمكن إصلاحها — أعد بناءها"
		notice_time = 2.5
		return
	if current_hp >= max_hp:
		notice = "المنشأة سليمة ولا تحتاج إلى إصلاح"
		notice_time = 2.0
		return
	var missing_hp := max_hp - current_hp
	var repair_cost := maxi(1, int(ceil(float(_building_cost(String(building.get("kind", "")))) * float(missing_hp) / float(max_hp) * 0.5)))
	if credits < repair_cost:
		notice = "موارد غير كافية لإصلاح المنشأة — التكلفة %d" % repair_cost
		notice_time = 2.5
		return
	credits -= repair_cost
	building["hp"] = max_hp
	buildings[selected_player_building] = building
	notice = "اكتمل إصلاح المنشأة — التكلفة %d" % repair_cost
	notice_time = 2.5
	queue_redraw()


func _sell_selected_building() -> void:
	if not _has_selected_player_building():
		notice = "حدد إحدى منشآتك أولاً"
		notice_time = 2.0
		return
	var building: Dictionary = buildings[selected_player_building]
	if float(building.get("build_progress", 1.0)) < 1.0:
		notice = "لا يمكن بيع منشأة قيد الإنشاء"
		notice_time = 2.0
		return
	if int(building.get("hp", 0)) <= 0:
		notice = "لا يمكن بيع منشأة مدمرة"
		notice_time = 2.0
		return
	var refund := int(floor(float(_building_cost(String(building.get("kind", "")))) * 0.5))
	buildings.remove_at(selected_player_building)
	selected_player_building = -1
	credits = mini(MAX_CREDITS, credits + refund)
	notice = "تم بيع المنشأة واسترداد %d من الموارد" % refund
	notice_time = 2.5
	queue_redraw()



func _load_selected_infantry_into_transport() -> void:
	var transport_index := -1
	var infantry_indices: Array[int] = []
	for index in selected:
		if index < 0 or index >= units.size():
			continue
		var candidate: Dictionary = units[index]
		if String(candidate.get("team", "")) != "player" or int(candidate.get("hp", 0)) <= 0:
			continue
		if String(candidate.get("kind", "")) == "transport_helicopter":
			if transport_index >= 0:
				notice = "اختر طائرة نقل واحدة فقط"
				notice_time = 2.0
				return
			transport_index = index
		elif String(candidate.get("kind", "")) == "infantry":
			infantry_indices.append(index)
	if transport_index < 0 or infantry_indices.is_empty():
		notice = "حدد طائرة نقل ومجموعة مشاة لتحميلهم"
		notice_time = 2.2
		return
	var transport: Dictionary = units[transport_index]
	var cargo: Array = transport.get("transport_cargo", [])
	var available := 8 - cargo.size()
	if available <= 0:
		notice = "طائرة النقل ممتلئة — السعة 8 جنود"
		notice_time = 2.0
		return
	var load_count := mini(available, infantry_indices.size())
	for n in range(load_count):
		var passenger: Dictionary = units[infantry_indices[n]]
		# Keep the complete infantry record so upgrades, stance, cooldowns and future unit fields survive transport.
		var cargo_entry: Dictionary = passenger.duplicate(true)
		cargo_entry["team"] = "player"
		cargo_entry["faction"] = String(passenger.get("faction", faction))
		cargo_entry["kind"] = "infantry"
		cargo_entry["hp"] = int(passenger.get("hp", 100))
		cargo_entry["combat_medals"] = Array(passenger.get("combat_medals", [])).duplicate(true)
		cargo_entry["cargo_attack_cd"] = randf_range(0.0, 0.35)
		# Array indices are not stable while passengers are removed; preserve the target position instead.
		cargo_entry.erase("attack_target")
		if passenger.has("attack_target"):
			var passenger_target_index := int(passenger.get("attack_target", -1))
			if passenger_target_index >= 0 and passenger_target_index < units.size():
				var passenger_target: Dictionary = units[passenger_target_index]
				if String(passenger_target.get("team", "")) == "enemy" and int(passenger_target.get("hp", 0)) > 0:
					cargo_entry["attack_focus_pos"] = passenger_target.pos
		cargo.append(cargo_entry)
	transport["transport_cargo"] = cargo
	transport["transport_state"] = "loaded"
	var transport_record: Dictionary = transport
	# Remove only passengers that actually boarded; excess selected infantry stay on the field.
	var loaded_indices: Array = infantry_indices.slice(0, load_count)
	loaded_indices.sort()
	loaded_indices.reverse()
	for remove_index_value in loaded_indices:
		var remove_index := int(remove_index_value)
		if remove_index < 0 or remove_index >= units.size():
			continue
		var removed_unit: Dictionary = units[remove_index]
		# Repair every live unit's target index before compacting the shared units array.
		for reference_index in range(units.size()):
			if reference_index == remove_index:
				continue
			var referencing_unit: Dictionary = units[reference_index]
			if not referencing_unit.has("attack_target"):
				continue
			var referenced_index := int(referencing_unit.get("attack_target", -1))
			if referenced_index == remove_index:
				referencing_unit["attack_focus_pos"] = removed_unit.pos
				referencing_unit.erase("attack_target")
			elif referenced_index > remove_index:
				referencing_unit["attack_target"] = referenced_index - 1
		units.remove_at(remove_index)
	var updated_transport_index := units.find(transport_record)
	selected.clear()
	if updated_transport_index >= 0:
		selected.append(updated_transport_index)
	var remaining_infantry := infantry_indices.size() - load_count
	notice = "تم تحميل %d جندي — الحمولة %d / 8" % [load_count, cargo.size()]
	if remaining_infantry > 0:
		notice += " — بقي %d جندي على الأرض" % remaining_infantry
	notice_time = 2.8


func _prepare_transport_rooftop_landing() -> void:
	var found_transport := false
	for index in selected:
		if index < 0 or index >= units.size():
			continue
		var transport: Dictionary = units[index]
		if String(transport.get("team", "")) != "player" or String(transport.get("kind", "")) != "transport_helicopter":
			continue
		if Array(transport.get("transport_cargo", [])).is_empty():
			notice = "حمّل الجنود أولاً قبل إصدار أمر الإنزال"
			notice_time = 2.0
			return
		transport["transport_order_pending"] = true
		found_transport = true
	if found_transport:
		notice = "اختر سطح مبنى أو نقطة أرضية آمنة لنقل الجنود إليها"
	else:
		notice = "حدد طائرة نقل محمّلة بالجنود أولاً"
	notice_time = 2.4


func _issue_transport_rooftop_order(world_pos: Vector2) -> bool:
	for index in selected:
		if index < 0 or index >= units.size():
			continue
		var transport: Dictionary = units[index]
		if String(transport.get("kind", "")) != "transport_helicopter" or not bool(transport.get("transport_order_pending", false)):
			continue
		var target_pos := world_pos
		var rooftop_found := false
		var rooftop_kind := ""
		for building in buildings:
			var candidate_kind := String(building.get("kind", ""))
			if candidate_kind in ["wall", "wall_corner", "wall_gate", "airfield"]:
				continue
			if int(building.get("hp", 0)) > 0 and float(building.get("build_progress", 1.0)) >= 1.0 and building.pos.distance_to(world_pos) <= 48.0:
				target_pos = building.pos
				rooftop_kind = candidate_kind
				rooftop_found = true
				break
		if not rooftop_found:
			for building in enemy_buildings:
				var candidate_kind := String(building.get("kind", ""))
				if candidate_kind in ["wall", "wall_corner", "wall_gate", "airfield"]:
					continue
				if int(building.get("hp", 0)) > 0 and float(building.get("build_progress", 1.0)) >= 1.0 and building.pos.distance_to(world_pos) <= 48.0:
					target_pos = building.pos
					rooftop_kind = candidate_kind
					rooftop_found = true
					break
		if rooftop_found:
			for occupant in units:
				if String(occupant.get("team", "")) == "enemy" and int(occupant.get("hp", 0)) > 0 and occupant.pos.distance_to(target_pos) < 22.0:
					notice = "سطح المبنى غير آمن — اختر مبنى آخر"
					notice_time = 2.2
					return true
		else:
			var safe_map_rect := _transport_landing_bounds(false)
			if not safe_map_rect.has_point(target_pos):
				notice = "اختر نقطة إنزال داخل حدود الخريطة وبعيدة عن الحواف"
				notice_time = 2.2
				return true
			for building in buildings:
				if int(building.get("hp", 0)) > 0 and building.pos.distance_to(target_pos) < 54.0:
					notice = "نقطة الإنزال قريبة من منشأة — اختر مساحة مفتوحة"
					notice_time = 2.2
					return true
			for building in enemy_buildings:
				if int(building.get("hp", 0)) > 0 and building.pos.distance_to(target_pos) < 54.0:
					notice = "نقطة الإنزال قريبة من مبنى معادٍ — اختر مساحة آمنة"
					notice_time = 2.2
					return true
			for occupant_index in range(units.size()):
				if occupant_index == index:
					continue
				var occupant: Dictionary = units[occupant_index]
				if int(occupant.get("hp", 0)) > 0 and occupant.pos.distance_to(target_pos) < 42.0:
					notice = "الموقع مزدحم — اختر مساحة مفتوحة للإنزال"
					notice_time = 2.2
					return true
		transport["transport_target_pos"] = target_pos
		transport["transport_landing_type"] = "rooftop" if rooftop_found else "ground"
		if rooftop_found:
			transport["transport_target_building_kind"] = rooftop_kind
		else:
			transport.erase("transport_target_building_kind")
		transport["transport_state"] = "inbound"
		transport["transport_order_pending"] = false
		transport["transport_drop_index"] = 0
		transport["transport_drop_timer"] = 0.0
		transport.erase("target")
		notice = "انطلقت المروحية للإنزال على السطح" if rooftop_found else "انطلقت المروحية لنقل الجنود إلى الموقع المحدد"
		notice_time = 2.5
		return true
	return false

func _cancel_transport_order() -> void:
	var cancelled := 0
	for index in selected:
		if index < 0 or index >= units.size():
			continue
		var transport: Dictionary = units[index]
		if String(transport.get("team", "")) != "player" or String(transport.get("kind", "")) != "transport_helicopter":
			continue
		var state := String(transport.get("transport_state", "idle"))
		if state == "descending":
			continue
		transport.erase("transport_target_pos")
		transport.erase("transport_order_pending")
		transport.erase("target")
		transport["transport_state"] = "loaded" if not Array(transport.get("transport_cargo", [])).is_empty() else "idle"
		cancelled += 1
	if cancelled > 0:
		notice = "أُلغيت مهمة النقل — الجنود ما زالوا داخل الطائرة"
	else:
		notice = "لا توجد مهمة نقل قابلة للإلغاء"
	notice_time = 2.2




func _update_transport_helicopter(transport: Dictionary, delta: float) -> void:
	var state := String(transport.get("transport_state", "idle"))
	_update_transport_passenger_fire(transport, delta)
	if state == "inbound":
		var landing_pos: Vector2 = transport.get("transport_target_pos", transport.pos)
		if transport.pos.distance_to(landing_pos) > 14.0:
			transport.pos += (landing_pos - transport.pos).normalized() * delta * 72.0
			transport["facing"] = (landing_pos - transport.pos).angle()
		else:
			transport.pos = landing_pos
			transport["transport_state"] = "descending"
			transport["transport_drop_timer"] = 0.0
	elif state == "descending":
		var cargo: Array = transport.get("transport_cargo", [])
		if cargo.is_empty():
			transport["transport_state"] = "idle"
			transport.erase("transport_target_pos")
			return
		transport["transport_drop_timer"] = float(transport.get("transport_drop_timer", 0.0)) + delta
		if float(transport["transport_drop_timer"]) >= 0.72:
			var drop_index := int(transport.get("transport_drop_index", 0))
			var landing_center: Vector2 = transport.get("transport_target_pos", transport.pos)
			var drop_pos_value = _find_transport_drop_position(landing_center, drop_index, transport)
			if not drop_pos_value is Vector2:
				# Keep the passenger aboard and replay a complete rope descent on the next safe attempt.
				transport["transport_drop_timer"] = 0.0
				return
			transport["transport_drop_timer"] = 0.0
			var drop_pos: Vector2 = drop_pos_value
			var passenger: Dictionary = cargo.pop_front()
			# Restore the original record rather than rebuilding a reduced infantry dictionary.
			var restored_passenger: Dictionary = passenger.duplicate(true)
			restored_passenger["pos"] = drop_pos
			restored_passenger["team"] = "player"
			restored_passenger["kind"] = "infantry"
			# One-shot presentation hint for the 3D bridge; this passenger has just touched down.
			restored_passenger["transport_rope_drop"] = true
			if String(transport.get("transport_landing_type", "ground")) == "rooftop":
				restored_passenger["transport_rooftop_kind"] = String(transport.get("transport_target_building_kind", ""))
				restored_passenger["transport_rooftop_center"] = landing_center
			else:
				restored_passenger.erase("transport_rooftop_kind")
				restored_passenger.erase("transport_rooftop_center")
			restored_passenger["faction"] = String(passenger.get("faction", faction))
			restored_passenger["hp"] = int(passenger.get("hp", 100))
			restored_passenger["combat_medals"] = Array(passenger.get("combat_medals", [])).duplicate(true)
			restored_passenger["facing"] = float(passenger.get("facing", 0.0))
			restored_passenger["turret_facing"] = float(passenger.get("turret_facing", restored_passenger["facing"]))
			restored_passenger.erase("attack_target")
			# Units without a previous player order walk into a safe squad slot after touching down.
			var had_player_order := passenger.has("target") or passenger.has("attack_target") or passenger.has("attack_focus_pos") or passenger.has("attack_building") or bool(passenger.get("attack_base", false)) or bool(passenger.get("guard_active", false)) or bool(passenger.get("attack_move_active", false))
			if not had_player_order:
				restored_passenger["target"] = _transport_formation_slot(landing_center, drop_index, transport, drop_pos)
			# Resolve a fresh hostile target from its saved position after array changes.
			if passenger.has("attack_focus_pos"):
				var focus_pos: Vector2 = passenger["attack_focus_pos"]
				var reacquired_target := -1
				var closest_focus_distance := 120.0
				for enemy_index in range(units.size()):
					var enemy_candidate: Dictionary = units[enemy_index]
					if String(enemy_candidate.get("team", "")) != "enemy" or int(enemy_candidate.get("hp", 0)) <= 0:
						continue
					var focus_distance: float = enemy_candidate.pos.distance_to(focus_pos)
					if focus_distance < closest_focus_distance:
						closest_focus_distance = focus_distance
						reacquired_target = enemy_index
				if reacquired_target >= 0:
					restored_passenger["attack_target"] = reacquired_target
			units.append(restored_passenger)
			transport["transport_cargo"] = cargo
			transport["transport_drop_index"] = drop_index + 1
			_add_visual_effect("rope", transport.pos + Vector2(0, 8), drop_pos, Color("#e5d6b1"), 0.8, 0.0)
			_add_visual_effect("dust", drop_pos, drop_pos, Color("#c5b28b"), 0.42, 8.0)
			if cargo.is_empty():
				transport.erase("transport_target_pos")
				var nearest_airfield := Vector2.ZERO
				var airfield_found := false
				var nearest_distance := INF
				for airfield in buildings:
					if String(airfield.get("kind", "")) != "airfield" or int(airfield.get("hp", 0)) <= 0 or float(airfield.get("build_progress", 1.0)) < 1.0:
						continue
					var airfield_distance: float = transport.pos.distance_to(airfield.pos)
					if airfield_distance < nearest_distance:
						nearest_distance = airfield_distance
						nearest_airfield = airfield.pos
						airfield_found = true
				if airfield_found:
					transport["transport_return_pos"] = nearest_airfield
					transport["transport_state"] = "returning"
				else:
					transport["transport_state"] = "idle"
				notice = "اكتمل الإنزال الجوي — الجنود على السطح، والمروحية عائدة للمطار" if airfield_found else "اكتمل الإنزال الجوي — لا يوجد مطار صالح للعودة إليه"
				notice_time = 3.0
	elif state == "returning":
		var return_pos: Vector2 = transport.get("transport_return_pos", transport.pos)
		if transport.pos.distance_to(return_pos) > 14.0:
			transport.pos += (return_pos - transport.pos).normalized() * delta * 72.0
			transport["facing"] = (return_pos - transport.pos).angle()
		else:
			transport.pos = return_pos
			transport.erase("transport_return_pos")
			transport["transport_state"] = "loaded" if not Array(transport.get("transport_cargo", [])).is_empty() else "idle"
	elif transport.has("target"):
		var move_target: Vector2 = transport.target
		if transport.pos.distance_to(move_target) > 12.0:
			transport.pos += (move_target - transport.pos).normalized() * delta * 72.0
		else:
			transport.erase("target")




func _transport_landing_bounds(is_rooftop: bool) -> Rect2:
	# The 2D battlefield fills the viewport; its lower strip is beach/sea, not safe infantry ground.
	var map_size := get_viewport_rect().size
	var lower_edge := map_size.y - 36.0
	if not is_rooftop:
		lower_edge = minf(lower_edge, map_size.y * 0.66)
	return Rect2(
		Vector2(36.0, 36.0),
		Vector2(maxf(0.0, map_size.x - 72.0), maxf(0.0, lower_edge - 36.0))
	)


func _find_transport_drop_position(center: Vector2, drop_index: int, transport: Dictionary) -> Variant:
	# Rooftop drops stay close to the selected building; ground drops use a wider ring.
	var is_rooftop := String(transport.get("transport_landing_type", "ground")) == "rooftop"
	var rooftop_offsets: Array[Vector2] = [
		Vector2(-22, -14), Vector2(22, -14), Vector2(-22, 14), Vector2(22, 14),
		Vector2(0, -30), Vector2(0, 30), Vector2(-34, 0), Vector2(34, 0)
	]
	var ground_offsets: Array[Vector2] = [
		Vector2(-34, -22), Vector2(34, -22), Vector2(-34, 22), Vector2(34, 22),
		Vector2(0, -42), Vector2(0, 42), Vector2(-46, 0), Vector2(46, 0)
	]
	var offsets: Array[Vector2] = rooftop_offsets if is_rooftop else ground_offsets
	var safe_map_rect := _transport_landing_bounds(is_rooftop)
	for attempt in range(offsets.size()):
		var candidate: Vector2 = center + offsets[(drop_index + attempt) % offsets.size()]
		if not safe_map_rect.has_point(candidate):
			continue
		var blocked := false
		if not is_rooftop:
			for building in buildings:
				if int(building.get("hp", 0)) > 0 and building.pos.distance_to(candidate) < 48.0:
					blocked = true
					break
			if not blocked:
				for building in enemy_buildings:
					if int(building.get("hp", 0)) > 0 and building.pos.distance_to(candidate) < 48.0:
						blocked = true
						break
		if blocked:
			continue
		for occupant in units:
			if int(occupant.get("hp", 0)) <= 0:
				continue
			# Ignore the hovering transport itself, but keep clear of every ground unit.
			if String(occupant.get("kind", "")) == "transport_helicopter" and String(occupant.get("team", "")) == "player" and occupant.pos.distance_to(transport.pos) < 2.0:
				continue
			if occupant.pos.distance_to(candidate) < 15.0:
				blocked = true
				break
		if not blocked:
			return candidate
	return null


func _transport_formation_slot(center: Vector2, drop_index: int, transport: Dictionary, fallback: Vector2) -> Vector2:
	# Spread the squad into a compact eight-point perimeter after touchdown.
	var formation_offsets: Array[Vector2] = [
		Vector2(-66, -38), Vector2(0, -76), Vector2(66, -38), Vector2(76, 28),
		Vector2(0, 76), Vector2(-76, 28), Vector2(-42, 0), Vector2(42, 0)
	]
	var is_rooftop := String(transport.get("transport_landing_type", "ground")) == "rooftop"
	var safe_rect := _transport_landing_bounds(is_rooftop)
	for attempt in range(formation_offsets.size()):
		var candidate: Vector2 = center + formation_offsets[(drop_index + attempt) % formation_offsets.size()]
		if not safe_rect.has_point(candidate):
			continue
		var blocked := false
		if not is_rooftop:
			for building in buildings:
				if int(building.get("hp", 0)) > 0 and building.pos.distance_to(candidate) < 48.0:
					blocked = true
					break
			if not blocked:
				for building in enemy_buildings:
					if int(building.get("hp", 0)) > 0 and building.pos.distance_to(candidate) < 48.0:
						blocked = true
						break
		if blocked:
			continue
		for occupant in units:
			if int(occupant.get("hp", 0)) <= 0:
				continue
			if String(occupant.get("kind", "")) == "transport_helicopter" and String(occupant.get("team", "")) == "player" and occupant.pos.distance_to(transport.pos) < 2.0:
				continue
			if occupant.pos.distance_to(candidate) < 23.0:
				blocked = true
				break
		if not blocked:
			return candidate
	return fallback


func _update_transport_passenger_fire(transport: Dictionary, delta: float) -> void:
	# Loaded infantry fire from the transport's side doors at nearby hostile ground units.
	var cargo: Array = transport.get("transport_cargo", [])
	if cargo.is_empty():
		transport["transport_firing"] = false
		transport["attack_target_pos"] = Vector2.ZERO
		return
	var state := String(transport.get("transport_state", "idle"))
	if state == "descending":
		transport["transport_firing"] = false
		transport["attack_target_pos"] = Vector2.ZERO
		return
	var target_index := -1
	var target_distance := 158.0
	# A direct player attack order takes priority over opportunistic door-gunner fire.
	# Reacquire around the saved focus so array compaction cannot silently retarget the squad.
	if transport.has("attack_focus_pos"):
		var focus_pos: Vector2 = transport["attack_focus_pos"]
		var focus_distance := 96.0
		for enemy_index in range(units.size()):
			var focused_enemy: Dictionary = units[enemy_index]
			if String(focused_enemy.get("team", "")) != "enemy" or int(focused_enemy.get("hp", 0)) <= 0:
				continue
			if String(focused_enemy.get("kind", "")) in ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine"]:
				continue
			var distance_to_focus: float = focused_enemy.pos.distance_to(focus_pos)
			if distance_to_focus < focus_distance:
				focus_distance = distance_to_focus
				target_index = enemy_index
	if target_index < 0 and transport.has("attack_target"):
		var commanded_index := int(transport.get("attack_target", -1))
		if commanded_index >= 0 and commanded_index < units.size():
			var commanded_enemy: Dictionary = units[commanded_index]
			if String(commanded_enemy.get("team", "")) == "enemy" and int(commanded_enemy.get("hp", 0)) > 0 and String(commanded_enemy.get("kind", "")) not in ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine"]:
				target_index = commanded_index
	if target_index >= 0:
		var commanded_target: Dictionary = units[target_index]
		target_distance = transport.pos.distance_to(commanded_target.pos)
		if state in ["idle", "loaded"]:
			if target_distance > 158.0:
				transport["target"] = commanded_target.pos
				transport["transport_firing"] = false
				transport["attack_target_pos"] = commanded_target.pos
				for passenger in cargo:
					passenger["cargo_attack_cd"] = maxf(0.0, float(passenger.get("cargo_attack_cd", 0.0)) - delta)
				transport["transport_cargo"] = cargo
				return
			transport.erase("target")
	else:
		# No living commanded target remains; resume defensive fire at nearby ground threats.
		transport.erase("attack_target")
		transport.erase("attack_focus_pos")
		for index in range(units.size()):
			var enemy: Dictionary = units[index]
			if String(enemy.get("team", "")) != "enemy" or int(enemy.get("hp", 0)) <= 0:
				continue
			if String(enemy.get("kind", "")) in ["fighter", "helicopter", "transport_helicopter", "destroyer", "carrier", "submarine"]:
				continue
			var distance: float = transport.pos.distance_to(enemy.pos)
			if distance < target_distance:
				target_distance = distance
				target_index = index
	if target_index < 0:
		transport["transport_firing"] = false
		transport["attack_target_pos"] = Vector2.ZERO
		for passenger in cargo:
			passenger["cargo_attack_cd"] = maxf(0.0, float(passenger.get("cargo_attack_cd", 0.0)) - delta)
		transport["transport_cargo"] = cargo
		return
	var target: Dictionary = units[target_index]
	var fired := false
	for passenger_index in range(cargo.size()):
		var passenger: Dictionary = cargo[passenger_index]
		var cooldown := maxf(0.0, float(passenger.get("cargo_attack_cd", 0.0)) - delta)
		if cooldown <= 0.0 and int(target.get("hp", 0)) > 0:
			var base_damage := 4 + int(passenger.get("veterancy", 0)) * 1
			var damage := _unit_damage_with_veterancy(passenger, base_damage)
			var hp_before := int(target.get("hp", 0))
			target["hp"] = maxi(0, hp_before - _terrain_adjusted_damage(target, damage))
			var damage_dealt := hp_before - int(target["hp"])
			_award_unit_experience(passenger, damage_dealt)
			_register_unit_kill(passenger, target, hp_before)
			passenger["cargo_attack_cd"] = 0.95
			fired = true
		else:
			passenger["cargo_attack_cd"] = cooldown
		cargo[passenger_index] = passenger
	transport["transport_firing"] = fired
	if fired:
		var side_offset := Vector2(0.0, -9.0 if int(transport.get("cargo_fire_side", 0)) % 2 == 0 else 9.0)
		transport["cargo_fire_side"] = int(transport.get("cargo_fire_side", 0)) + 1
		var muzzle_pos: Vector2 = transport.pos + side_offset.rotated(float(transport.get("facing", 0.0)))
		_add_visual_effect("tracer", muzzle_pos, target.pos, Color("#ffe2a6"), 0.16, 0.0)
		_add_visual_effect("flash", target.pos, target.pos, Color("#ffbd65"), 0.12, 5.0)
	transport["transport_cargo"] = cargo
	transport["attack_target_pos"] = target.pos if int(target.get("hp", 0)) > 0 else Vector2.ZERO



func _unit_cost(kind: String, army: String) -> int:
	if kind == "helicopter":
		return _helicopter_cost(army)
	if kind == "transport_helicopter":
		return 1200 if army == "وطن" else 950
	var profile := _faction_profile(army)
	var faction_costs: Dictionary = profile.get("unit_costs", {})
	if faction_costs.has(kind):
		return int(faction_costs[kind])
	var costs: Dictionary = ECONOMY_BALANCE["unit_costs"]
	return int(costs.get(kind, TANK_COST))


func _unit_supply_cost(kind: String) -> int:
	var costs: Dictionary = ECONOMY_BALANCE["unit_supplies"]
	return int(costs.get(kind, 0))


func _update_supply_depots(delta: float) -> void:
	for i in range(buildings.size()):
		var depot: Dictionary = buildings[i]
		if String(depot.get("kind", "")) != "supply_depot" or int(depot.get("hp", 0)) <= 0 or float(depot.get("build_progress", 1.0)) < 1.0:
			continue
		var supply_cap := _player_supply_capacity()
		# A depot at capacity must not bank idle production time for an instant refill later.
		if supplies >= supply_cap:
			depot["supply_timer"] = 0.0
			buildings[i] = depot
			continue
		depot["supply_timer"] = float(depot.get("supply_timer", 0.0)) + delta
		var interval := maxf(7.0, 12.0 - float(maxi(1, int(depot.get("level", 1))) - 1) * 1.5)
		if float(depot["supply_timer"]) >= interval:
			var batches := int(floor(float(depot["supply_timer"]) / interval))
			depot["supply_timer"] = fmod(float(depot["supply_timer"]), interval)
			supplies = mini(_player_supply_capacity(), supplies + batches)
		buildings[i] = depot


func _player_supply_capacity() -> int:
	# Captured logistics nodes and completed depots expand the reserve.
	var controlled_nodes := 0
	for point in supply_points:
		if String(point.get("owner", "")) == "player":
			controlled_nodes += 1
	var depot_capacity := 0
	for building in buildings:
		if String(building.get("kind", "")) == "supply_depot" and int(building.get("hp", 0)) > 0 and float(building.get("build_progress", 1.0)) >= 1.0:
			depot_capacity += 30 + (maxi(1, int(building.get("level", 1))) - 1) * 10
	return 99 + controlled_nodes * 20 + depot_capacity


func _update_building_construction(delta: float) -> void:
	for i in range(buildings.size()):
		var building: Dictionary = buildings[i]
		var progress := float(building.get("build_progress", 1.0))
		if progress >= 1.0:
			continue
		var nearby_builders := 0
		for worker in units:
			if worker.team != "player" or worker.kind != "builder" or int(worker.get("hp", 0)) <= 0:
				continue
			var assigned_target: Vector2 = worker.get("build_target", Vector2(-9999, -9999))
			if assigned_target.distance_to(building.pos) >= 4.0:
				continue
			if worker.pos.distance_to(building.pos) <= 48.0:
				nearby_builders += 1
		if nearby_builders <= 0:
			continue
		# Coordinated builders speed up construction, with diminishing returns
		# and a hard cap so adding workers never makes buildings instantaneous.
		var construction_multiplier := minf(2.5, 1.0 + float(nearby_builders - 1) * 0.5)
		var duration := maxf(1.0, float(building.get("build_duration", 8.0)))
		progress = minf(1.0, progress + delta * construction_multiplier / duration)
		building["build_progress"] = progress
		buildings[i] = building
		if progress >= 1.0:
			for worker in units:
				if worker.team == "player" and worker.kind == "builder":
					var assigned_target: Vector2 = worker.get("build_target", Vector2(-9999, -9999))
					if assigned_target.distance_to(building.pos) < 4.0:
						worker.erase("build_target")
			notice = "اكتمل إنشاء المبنى — أصبح جاهزاً للعمل"
			notice_time = 2.5


func _unit_repair_max_hp(unit: Dictionary) -> int:
	match String(unit.get("kind", "")):
		"tank": return 150
		"artillery": return 100
		"fighter": return 120
		"helicopter": return 180
		"transport_helicopter": return 250
		"destroyer": return 260
		"carrier": return 520
		"submarine": return 210
		"landing_craft": return 220
	return 0


func _update_field_repairs(delta: float) -> void:
	# Idle builders restore nearby armor and artillery; shipyards service damaged vessels.
	for builder in units:
		if String(builder.get("team", "")) != "player" or String(builder.get("kind", "")) != "builder" or int(builder.get("hp", 0)) <= 0:
			continue
		if builder.has("build_target") or builder.has("target"):
			continue
		var nearest_unit_index := -1
		var nearest_distance := 68.0
		for unit_index in range(units.size()):
			var candidate: Dictionary = units[unit_index]
			if String(candidate.get("team", "")) != "player" or int(candidate.get("hp", 0)) <= 0:
				continue
			var max_hp := _unit_repair_max_hp(candidate)
			if max_hp <= 0 or int(candidate.get("hp", 0)) >= max_hp:
				continue
			var distance: float = builder.pos.distance_to(candidate.pos)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_unit_index = unit_index
		if nearest_unit_index < 0 or credits <= 0:
			continue
		var target_unit: Dictionary = units[nearest_unit_index]
		var target_max_hp := _unit_repair_max_hp(target_unit)
		builder["field_repair_work"] = minf(3.0, float(builder.get("field_repair_work", 0.0)) + delta * 6.0)
		var repair_points := mini(int(floor(float(builder.field_repair_work))), target_max_hp - int(target_unit.hp))
		if repair_points <= 0:
			continue
		var repair_cost_buffer := float(builder.get("field_repair_cost_buffer", 0.0)) + float(repair_points) * 0.5
		var whole_cost := int(floor(repair_cost_buffer))
		if whole_cost > credits:
			continue
		builder["field_repair_work"] = float(builder.field_repair_work) - float(repair_points)
		builder["field_repair_cost_buffer"] = repair_cost_buffer - float(whole_cost)
		credits -= whole_cost
		target_unit["hp"] = mini(target_max_hp, int(target_unit.hp) + repair_points)
		builder["field_repair_fx_cd"] = maxf(0.0, float(builder.get("field_repair_fx_cd", 0.0)) - delta)
		if float(builder.field_repair_fx_cd) <= 0.0:
			_add_visual_effect("repair", builder.pos, target_unit.pos, Color("#8ce6a0"), 0.32, 0.0)
			builder["field_repair_fx_cd"] = 0.75
	# Idle or explicitly assigned dozers automatically service damaged friendly structures.
	for builder_index in range(units.size()):
		var builder: Dictionary = units[builder_index]
		if String(builder.get("team", "")) != "player" or String(builder.get("kind", "")) != "builder" or int(builder.get("hp", 0)) <= 0:
			continue
		if builder.has("build_target") or (builder.has("target") and not builder.has("repair_building")):
			continue
		var repair_building_index := int(builder.get("repair_building", -1))
		if repair_building_index < 0 or repair_building_index >= buildings.size():
			repair_building_index = -1
			var closest_building_distance := 112.0
			for candidate_index in range(buildings.size()):
				var candidate_building: Dictionary = buildings[candidate_index]
				if String(candidate_building.get("team", "player")) != "player" or float(candidate_building.get("build_progress", 1.0)) < 1.0:
					continue
				var candidate_max_hp := _building_max_hp(candidate_building)
				var candidate_hp := int(candidate_building.get("hp", candidate_max_hp))
				if candidate_hp <= 0 or candidate_hp >= candidate_max_hp:
					continue
				var candidate_distance: float = builder.pos.distance_to(candidate_building.pos)
				if candidate_distance < closest_building_distance:
					closest_building_distance = candidate_distance
					repair_building_index = candidate_index
			if repair_building_index >= 0:
				builder["repair_building"] = repair_building_index
				builder["target"] = buildings[repair_building_index].pos
				units[builder_index] = builder
				continue
		var target_building: Dictionary = buildings[repair_building_index]
		var target_max_hp := _building_max_hp(target_building)
		var target_hp := int(target_building.get("hp", target_max_hp))
		if target_hp <= 0 or target_hp >= target_max_hp or float(target_building.get("build_progress", 1.0)) < 1.0:
			builder.erase("repair_building")
			builder.erase("repair_building_work")
			builder.erase("repair_building_cost_buffer")
			units[builder_index] = builder
			continue
		var target_distance: float = builder.pos.distance_to(target_building.pos)
		if target_distance > 48.0:
			builder["target"] = target_building.pos
			units[builder_index] = builder
			continue
		builder.erase("target")
		var repair_work := minf(3.0, float(builder.get("repair_building_work", 0.0)) + delta * 5.0)
		var repair_points := mini(int(floor(repair_work)), target_max_hp - target_hp)
		if repair_points <= 0:
			builder["repair_building_work"] = repair_work
			units[builder_index] = builder
			continue
		var repair_cost_buffer := float(builder.get("repair_building_cost_buffer", 0.0)) + float(repair_points) * 0.5
		var whole_repair_cost := int(floor(repair_cost_buffer))
		if whole_repair_cost > credits:
			builder["repair_building_work"] = repair_work
			units[builder_index] = builder
			continue
		credits -= whole_repair_cost
		builder["repair_building_work"] = repair_work - float(repair_points)
		builder["repair_building_cost_buffer"] = repair_cost_buffer - float(whole_repair_cost)
		target_building["hp"] = mini(target_max_hp, target_hp + repair_points)
		buildings[repair_building_index] = target_building
		builder["repair_building_fx_cd"] = maxf(0.0, float(builder.get("repair_building_fx_cd", 0.0)) - delta)
		if float(builder["repair_building_fx_cd"]) <= 0.0:
			_add_visual_effect("repair", builder.pos, target_building.pos, Color("#8ce6a0"), 0.32, 0.0)
			builder["repair_building_fx_cd"] = 0.7
		if int(target_building["hp"]) >= target_max_hp:
			builder.erase("repair_building")
			builder.erase("repair_building_work")
			builder.erase("repair_building_cost_buffer")
			builder.erase("target")
		units[builder_index] = builder

	for airfield_index in range(buildings.size()):
		var airfield: Dictionary = buildings[airfield_index]
		if String(airfield.get("kind", "")) != "airfield" or String(airfield.get("team", "player")) != "player":
			continue
		if float(airfield.get("build_progress", 1.0)) < 1.0 or int(airfield.get("hp", 0)) <= 0 or not _is_player_building_powered(airfield_index):
			continue
		for aircraft in units:
			if String(aircraft.get("team", "")) != "player" or String(aircraft.get("kind", "")) not in ["fighter", "helicopter", "transport_helicopter"]:
				continue
			if bool(aircraft.get("carrier_home", false)):
				continue
			var aircraft_max_hp := _unit_repair_max_hp(aircraft)
			if int(aircraft.get("hp", 0)) <= 0 or int(aircraft.hp) >= aircraft_max_hp:
				continue
			if aircraft.pos.distance_to(airfield.pos) > 105.0 or credits <= 0:
				continue
			aircraft["airfield_repair_work"] = minf(2.0, float(aircraft.get("airfield_repair_work", 0.0)) + delta * 4.0)
			var air_repair_points := mini(int(floor(float(aircraft.airfield_repair_work))), aircraft_max_hp - int(aircraft.hp))
			if air_repair_points <= 0:
				continue
			var air_cost_buffer := float(aircraft.get("airfield_repair_cost_buffer", 0.0)) + float(air_repair_points) * 0.55
			var air_cost := int(floor(air_cost_buffer))
			if air_cost > credits:
				continue
			aircraft["airfield_repair_work"] = float(aircraft.airfield_repair_work) - float(air_repair_points)
			aircraft["airfield_repair_cost_buffer"] = air_cost_buffer - float(air_cost)
			credits -= air_cost
			aircraft["hp"] = mini(aircraft_max_hp, int(aircraft.hp) + air_repair_points)
			aircraft["airfield_repair_fx_cd"] = maxf(0.0, float(aircraft.get("airfield_repair_fx_cd", 0.0)) - delta)
			if float(aircraft.airfield_repair_fx_cd) <= 0.0:
				_add_visual_effect("repair", airfield.pos, aircraft.pos, Color("#f4d77a"), 0.32, 0.0)
				aircraft["airfield_repair_fx_cd"] = 0.85

	for dock_index in range(buildings.size()):
		var dock: Dictionary = buildings[dock_index]
		if String(dock.get("kind", "")) != "shipyard" or String(dock.get("team", "player")) != "player":
			continue
		if float(dock.get("build_progress", 1.0)) < 1.0 or int(dock.get("hp", 0)) <= 0 or not _is_player_building_powered(dock_index):
			continue
		for vessel in units:
			if String(vessel.get("team", "")) != "player" or not _is_naval_kind(String(vessel.get("kind", ""))):
				continue
			var vessel_max_hp := _unit_repair_max_hp(vessel)
			if vessel_max_hp <= 0 or int(vessel.get("hp", 0)) <= 0 or int(vessel.hp) >= vessel_max_hp:
				continue
			if vessel.pos.distance_to(dock.pos) > 95.0 or credits <= 0:
				continue
			vessel["dock_repair_work"] = minf(2.0, float(vessel.get("dock_repair_work", 0.0)) + delta * 3.5)
			var dock_repair_points := mini(int(floor(float(vessel.dock_repair_work))), vessel_max_hp - int(vessel.hp))
			if dock_repair_points <= 0:
				continue
			var dock_cost_buffer := float(vessel.get("dock_repair_cost_buffer", 0.0)) + float(dock_repair_points) * 0.6
			var dock_cost := int(floor(dock_cost_buffer))
			if dock_cost > credits:
				continue
			vessel["dock_repair_work"] = float(vessel.dock_repair_work) - float(dock_repair_points)
			vessel["dock_repair_cost_buffer"] = dock_cost_buffer - float(dock_cost)
			credits -= dock_cost
			vessel["hp"] = mini(vessel_max_hp, int(vessel.hp) + dock_repair_points)
			vessel["dock_repair_fx_cd"] = maxf(0.0, float(vessel.get("dock_repair_fx_cd", 0.0)) - delta)
			if float(vessel.dock_repair_fx_cd) <= 0.0:
				_add_visual_effect("repair", dock.pos, vessel.pos, Color("#79d9f2"), 0.32, 0.0)
				vessel["dock_repair_fx_cd"] = 0.9

func _update_building_capture(delta: float) -> void:
	for i in range(enemy_buildings.size() - 1, -1, -1):
		var building: Dictionary = enemy_buildings[i]
		if float(building.get("build_progress", 1.0)) < 1.0:
			continue
		var infantry_near := false
		var enemy_guard_near := false
		for unit in units:
			if unit.get("hp", 0) <= 0 or unit.pos.distance_to(building.pos) > 48.0:
				continue
			if unit.team == "player" and unit.kind == "infantry":
				infantry_near = true
			elif unit.team == "enemy":
				enemy_guard_near = true
		if infantry_near and not enemy_guard_near:
			building.capture_progress = float(building.get("capture_progress", 0.0)) + delta
			if building.capture_progress >= 3.0:
				var captured = building.duplicate(true)
				captured.erase("capture_progress")
				captured["captured"] = true
				captured["production_id"] = next_building_production_id
				next_building_production_id += 1
				buildings.append(captured)
				enemy_buildings.remove_at(i)
				for assault_unit in units:
					if not assault_unit.has("attack_building"):
						continue
					var assault_index := int(assault_unit.attack_building)
					if assault_index == i:
						assault_unit.erase("attack_building")
					elif assault_index > i:
						assault_unit.attack_building = assault_index - 1
				selected_enemy_building = -1
				notice = "استوليت على مبنى العدو وأصبح تحت قيادتك!"
				notice_time = 3.0
		elif enemy_guard_near:
			building.capture_progress = 0.0
		else:
			building.capture_progress = maxf(0.0, float(building.get("capture_progress", 0.0)) - delta * 0.5)

func _capture_selected_building() -> void:
	if selected_enemy_building < 0 or selected_enemy_building >= enemy_buildings.size():
		notice = "حدد مبنى للعدو أولاً"
		notice_time = 2.0
		return
	var assigned := 0
	var target: Vector2 = enemy_buildings[selected_enemy_building].pos
	# Capture orders are issued only to infantry explicitly selected by the player.
	for selected_index in selected:
		if selected_index < 0 or selected_index >= units.size():
			continue
		var unit: Dictionary = units[selected_index]
		if unit.team != "player" or unit.kind != "infantry" or int(unit.get("hp", 0)) <= 0:
			continue
		# A fresh capture order must override every older combat or stance order.
		unit.target = target
		for order_key in ["attack_base", "attack_target", "attack_focus_pos", "attack_building", "attack_move_active", "guard_active", "guard_position", "guard_radius", "escort_active", "escort_target_id", "escort_offset", "air_patrol_points", "air_patrol_index", "air_patrol_resume"]:
			unit.erase(order_key)
		assigned += 1
	if assigned == 0:
		notice = "حدد مشاة أحياء أولاً للسيطرة على المبنى"
	else:
		notice = "تتقدم المشاة المحددة للاستيلاء — أمّن المنطقة!"
	notice_time = 3.0

func _order_destroy_selected_building() -> void:
	if selected_enemy_building < 0 or selected_enemy_building >= enemy_buildings.size():
		notice = "حدد مبنى للعدو أولاً"
		notice_time = 2.0
		return
	var assigned := 0
	# Only the player's selected combat units receive the demolition order.
	for selected_index in selected:
		if selected_index < 0 or selected_index >= units.size():
			continue
		var unit: Dictionary = units[selected_index]
		if unit.team != "player" or int(unit.get("hp", 0)) <= 0:
			continue
		if unit.kind not in ["tank", "artillery", "infantry", "fighter", "helicopter"]:
			continue
		# A direct demolition order takes priority over movement, patrol, guard, and escort stances.
		if String(unit.get("kind", "")) in ["fighter", "helicopter"]:
			_cancel_airfield_recovery(unit)
		unit.attack_building = selected_enemy_building
		for order_key in ["attack_base", "attack_target", "attack_focus_pos", "target", "attack_move_active", "guard_active", "guard_position", "guard_radius", "escort_active", "escort_target_id", "escort_offset", "air_patrol_points", "air_patrol_index", "air_patrol_resume"]:
			unit.erase(order_key)
		assigned += 1
	if assigned == 0:
		notice = "حدد قوات قتالية برية أو جوية لتدمير المبنى"
	else:
		notice = "صدرت أوامر تدمير المبنى للقوات المحددة!"
	notice_time = 3.0

func _building_needs_repair_warning(hp: int, max_hp: int) -> bool:
	return hp > 0 and float(hp) / float(maxi(1, max_hp)) <= 0.35


func _draw_building_repair_warning(p: Vector2) -> void:
	var warning_pos := p + Vector2(34.0, -29.0)
	draw_circle(warning_pos, 9.0, Color("#341d1b"))
	draw_circle(warning_pos, 7.0, Color("#e34c42"))
	draw_string(ThemeDB.fallback_font, warning_pos + Vector2(-2.8, 4.0), "!", HORIZONTAL_ALIGNMENT_LEFT, 8, 11, Color("#fff4e8"))


func _draw_building_health(p: Vector2, hp: int, max_hp: int = 400) -> void:
	var ratio = clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-25, -32), Vector2(50, 5)), Color("#292929"))
	draw_rect(Rect2(p + Vector2(-25, -32), Vector2(50.0 * ratio, 5)), Color("#79d47b"))

func _draw_construction_progress(p: Vector2, progress: float) -> void:
	var ratio := clampf(progress, 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-29, 34), Vector2(58, 7)), Color("#252525"))
	draw_rect(Rect2(p + Vector2(-28, 35), Vector2(56.0 * ratio, 5)), Color("#e5bd58"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-38, 53), "قيد الإنشاء %d%%" % int(ratio * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 76, 10, Color("#ffe7a5"))

func _draw_capture_progress(p: Vector2, progress: float) -> void:
	var ratio = clampf(progress / 3.0, 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-28, -41), Vector2(56, 7)), Color("#252525"))
	draw_rect(Rect2(p + Vector2(-27, -40), Vector2(54.0 * ratio, 5)), Color("#f2d15c"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-40, -46), "جارٍ الاستيلاء", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color("#ffe58a"))

func _enemy_faction() -> String:
	var player_faction_index = FACTIONS.find(faction)
	if player_faction_index < 0:
		return "الصيني"
	return FACTIONS[(player_faction_index + 1) % FACTIONS.size()]

func _missile_cost(army: String) -> int:
	return int(_faction_profile(army)["missile_cost"])


func _missile_damage(army: String) -> int:
	return int(_faction_profile(army)["missile_damage"])


func _missile_cooldown(army: String) -> float:
	return float(_faction_profile(army)["missile_cooldown"])


func _launch_player_missile() -> void:
	var has_silo := false
	for building in buildings:
		if building.kind == "missile_silo":
			has_silo = true
			break
	if not has_silo:
		notice = "ابنِ منصة صواريخ أولاً"
		notice_time = 2.5
		return
	var missile_cost := _missile_cost(faction)
	if credits < missile_cost or supplies < 4:
		notice = "الصاروخ يحتاج %d ذهب و4 إمدادات" % missile_cost
		notice_time = 2.5
		return
	var silo_index := -1
	for i in buildings.size():
		if buildings[i].kind == "missile_silo" and _is_player_building_powered(i) and float(buildings[i].get("attack_cd", 0.0)) <= 0.0:
			silo_index = i
			break
	if silo_index < 0:
		notice = "منصة الصواريخ تحتاج إلى طاقة أو تعيد التلقيم"
		notice_time = 2.0
		return
	var target_pos: Vector2 = enemy_base
	var target_kind := "base"
	if selected_enemy_building >= 0 and selected_enemy_building < enemy_buildings.size():
		target_pos = enemy_buildings[selected_enemy_building].pos
		target_kind = "building"
	credits -= missile_cost
	supplies -= 4
	buildings[silo_index].attack_cd = _missile_cooldown(faction)
	missiles.append({"pos": buildings[silo_index].pos + Vector2(0, -24), "target": target_pos, "target_kind": target_kind, "team": "player", "damage": _missile_damage(faction), "life": 8.0})
	notice = "انطلق الصاروخ!"
	notice_time = 2.0

func _launch_enemy_missile() -> void:
	var enemy_faction = _enemy_faction()
	var missile_cost := _missile_cost(enemy_faction)
	if enemy_credits < missile_cost or enemy_supplies < 4:
		return
	var silo_index := -1
	for i in enemy_buildings.size():
		if enemy_buildings[i].kind == "missile_silo" and _is_enemy_building_powered(i) and float(enemy_buildings[i].get("attack_cd", 0.0)) <= 0.0:
			silo_index = i
			break
	if silo_index < 0:
		return
	enemy_credits -= missile_cost
	enemy_supplies -= 4
	enemy_buildings[silo_index].attack_cd = _missile_cooldown(enemy_faction)
	missiles.append({"pos": enemy_buildings[silo_index].pos + Vector2(0, -24), "target": base_pos, "target_kind": "base", "team": "enemy", "damage": _missile_damage(enemy_faction), "life": 8.0})

func _update_missiles(delta: float) -> void:
	for building_index in range(buildings.size()):
		var building: Dictionary = buildings[building_index]
		if (building.kind == "missile_silo" or building.kind == "missile_defense") and _is_player_building_powered(building_index):
			building.attack_cd = maxf(0.0, float(building.get("attack_cd", 0.0)) - delta)
	for building_index in range(enemy_buildings.size()):
		var building: Dictionary = enemy_buildings[building_index]
		if (building.kind == "missile_silo" or building.kind == "missile_defense") and _is_enemy_building_powered(building_index):
			building.attack_cd = maxf(0.0, float(building.get("attack_cd", 0.0)) - delta)
	# Enemy missile readiness advances only while at least one silo has grid power.
	if _enemy_has_powered_building("missile_silo"):
		enemy_missile_timer += delta
		if enemy_missile_timer >= 24.0:
			enemy_missile_timer = 0.0
			_launch_enemy_missile()
	for i in range(missiles.size() - 1, -1, -1):
		var missile: Dictionary = missiles[i]
		var hostile_buildings: Array[Dictionary] = buildings if missile.team == "enemy" else enemy_buildings
		var intercepted := false
		for defense_index in range(hostile_buildings.size()):
			var defense: Dictionary = hostile_buildings[defense_index]
			if defense.kind != "missile_defense" or float(defense.get("attack_cd", 0.0)) > 0.0:
				continue
			# Player missile defenses must have grid power; enemy power is modeled separately.
			if missile.team == "enemy" and not _is_player_building_powered(defense_index):
				continue
			if missile.team == "player" and not _is_enemy_building_powered(defense_index):
				continue
			if defense.pos.distance_to(missile.pos) <= 190.0:
				defense.attack_cd = MISSILE_DEFENSE_INTERCEPT_COOLDOWN
				_add_visual_effect("explosion", missile.pos, missile.pos, Color("#8ee8ff"), 0.5, 34.0)
				missiles.remove_at(i)
				intercepted = true
				break
		if intercepted:
			continue
		var destination: Vector2 = missile.target
		var direction: Vector2 = destination - missile.pos
		var travel := 230.0 * delta
		if direction.length() <= travel + 8.0 or float(missile.life) <= delta:
			_add_visual_effect("explosion", destination, destination, Color("#ff9a52"), 0.8, 92.0)
			# Missile warheads now damage nearby hostile units as well as the primary target.
			var splash_team := "enemy" if missile.team == "player" else "player"
			var splash_damage := maxi(25, int(missile.damage * 0.65))
			_apply_missile_splash_damage(destination, 92.0, splash_damage, splash_team)
			if missile.team == "player":
				if missile.target_kind == "base":
					enemy_base_hp = maxi(0, enemy_base_hp - int(missile.damage))
				else:
					for building_index in range(enemy_buildings.size() - 1, -1, -1):
						if enemy_buildings[building_index].pos.distance_to(destination) < 36.0:
							enemy_buildings[building_index].hp = maxi(0, int(enemy_buildings[building_index].get("hp", 400)) - int(missile.damage))
							break
					_remove_destroyed_buildings("enemy")
			else:
				player_base_hp = maxi(0, player_base_hp - int(missile.damage))
			missiles.remove_at(i)
		else:
			missile.pos += direction.normalized() * travel
			missile.life = float(missile.life) - delta

func _apply_missile_splash_damage(center: Vector2, radius: float, base_damage: int, target_team: String) -> void:
	# Missile blast pressure falls off with distance; armored vehicles retain a little more protection.
	for unit in units:
		if String(unit.get("team", "")) != target_team or int(unit.get("hp", 0)) <= 0:
			continue
		var distance: float = unit.pos.distance_to(center)
		if distance > radius:
			continue
		var falloff := 1.0 - 0.58 * clampf(distance / maxf(1.0, radius), 0.0, 1.0)
		var armor_factor := 0.82 if String(unit.get("kind", "")) in ["tank", "artillery"] else 1.0
		var applied_damage := maxi(1, roundi(float(base_damage) * falloff * armor_factor))
		unit.hp = maxi(0, int(unit.hp) - _terrain_adjusted_damage(unit, applied_damage))
	var target_buildings: Array[Dictionary] = enemy_buildings if target_team == "enemy" else buildings
	for building in target_buildings:
		var distance: float = building.pos.distance_to(center)
		# Keep the direct-hit structure damage separate from surrounding blast damage.
		if distance <= 36.0 or distance > radius:
			continue
		var falloff := 1.0 - 0.68 * clampf(distance / maxf(1.0, radius), 0.0, 1.0)
		building.hp = maxi(0, int(building.get("hp", 400)) - maxi(1, roundi(float(base_damage) * falloff)))
	_remove_destroyed_buildings(target_team)


func _apply_building_splash_damage(center: Vector2, radius: float, damage: int, target_team: String) -> void:
	var targets: Array[Dictionary] = enemy_buildings if target_team == "enemy" else buildings
	for building in targets:
		var distance: float = building.pos.distance_to(center)
		# The primary structure is handled by its direct-hit damage.
		if distance > 36.0 and distance <= radius:
			building.hp = maxi(0, int(building.get("hp", 400)) - damage)
	_remove_destroyed_buildings(target_team)


func _remove_destroyed_buildings(target_team: String) -> void:
	var targets: Array[Dictionary] = enemy_buildings if target_team == "enemy" else buildings
	var removed_indices: Array[int] = []
	for building_index in range(targets.size() - 1, -1, -1):
		if int(targets[building_index].get("hp", 400)) <= 0:
			var destroyed_building: Dictionary = targets[building_index]
			if is_instance_valid(battlefield_3d) and battlefield_3d.has_method("spawn_game_building_destruction_effect"):
				var effect_map_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
				battlefield_3d.call("spawn_game_building_destruction_effect", destroyed_building.get("pos", Vector2.ZERO), effect_map_rect, String(destroyed_building.get("kind", "")))
			removed_indices.append(building_index)
			targets.remove_at(building_index)
	if target_team != "enemy" or removed_indices.is_empty():
		return
	for removed_index in removed_indices:
		if selected_enemy_building == removed_index:
			selected_enemy_building = -1
		elif selected_enemy_building > removed_index:
			selected_enemy_building -= 1
		for unit in units:
			if not unit.has("attack_building"):
				continue
			var target_index := int(unit.attack_building)
			if target_index == removed_index:
				unit.erase("attack_building")
			elif target_index > removed_index:
				unit.attack_building = target_index - 1
	notice = "دُمّر مبنى بفعل الانفجار!"
	notice_time = 2.0

func _draw_missiles() -> void:
	for missile in missiles:
		var p: Vector2 = missile.pos
		var tint := Color("#8ee8ff") if missile.team == "player" else Color("#ff856b")
		draw_line(p, p + Vector2(-13, 9), Color(tint, 0.75), 4.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(11, 0), p + Vector2(-7, -5), p + Vector2(-7, 5)]), tint)
		draw_circle(p + Vector2(-12, 0), 5.0, Color("#ffb45f", 0.7))

func _enemy_build_duration(kind: String) -> float:
	match kind:
		"barracks", "turret", "anti_air":
			return 7.0
		"factory", "missile_defense":
			return 10.0
		"airfield":
			return 11.0
		"missile_silo":
			return 13.0
		"shipyard":
			return 14.0
	return 8.0


func _enemy_add_building(kind: String, position: Vector2, hp: int, attack_cd: float = 0.0) -> void:
	enemy_buildings.append({
		"pos": position,
		"kind": kind,
		"hp": hp,
		"attack_cd": attack_cd,
		"build_progress": 0.0,
		"build_duration": _enemy_build_duration(kind)
	})


func _update_enemy_building_construction(delta: float) -> void:
	var completed_any := false
	for i in range(enemy_buildings.size()):
		var building: Dictionary = enemy_buildings[i]
		var progress := float(building.get("build_progress", 1.0))
		if progress >= 1.0:
			continue
		var duration := maxf(1.0, float(building.get("build_duration", 8.0)))
		progress = minf(1.0, progress + delta / duration)
		building["build_progress"] = progress
		enemy_buildings[i] = building
		if progress >= 1.0:
			completed_any = true
	if completed_any:
		notice = "اكتمل إنشاء أحد مباني العدو"
		notice_time = 1.8
		queue_redraw()


func _enemy_building_max_hp(building: Dictionary) -> int:
	match String(building.get("kind", "")):
		"factory", "missile_silo", "shipyard":
			return 500
		"airfield", "missile_defense":
			return 450
		"anti_air":
			return 380
		"turret":
			return 350
		"wall":
			return 280
		"wall_corner":
			return 360
		"wall_gate":
			return 220
		_:
			return 400


func _enemy_repair_damaged_building() -> bool:
	var repair_index := -1
	var repair_ratio := 0.30
	var repair_max_hp := 0
	for i in range(enemy_buildings.size()):
		var building: Dictionary = enemy_buildings[i]
		if int(building.get("hp", 0)) <= 0 or float(building.get("build_progress", 1.0)) < 1.0:
			continue
		var max_hp := _enemy_building_max_hp(building)
		var current_hp := clampi(int(building.get("hp", max_hp)), 0, max_hp)
		var missing_ratio := float(max_hp - current_hp) / float(max_hp)
		if missing_ratio < 0.30 or missing_ratio <= repair_ratio - 0.0001:
			continue
		repair_index = i
		repair_ratio = missing_ratio
		repair_max_hp = max_hp
	if repair_index < 0:
		return false
	var target: Dictionary = enemy_buildings[repair_index]
	var kind := String(target.get("kind", ""))
	var current_hp := clampi(int(target.get("hp", repair_max_hp)), 0, repair_max_hp)
	var missing_hp := repair_max_hp - current_hp
	var repair_cost := maxi(1, int(ceil(float(_building_cost(kind)) * float(missing_hp) / float(repair_max_hp) * 0.5)))
	# Keep enough cash for at least one infantry unit instead of sacrificing all production.
	var production_reserve := _unit_cost("infantry", _enemy_faction())
	if enemy_credits < repair_cost + production_reserve:
		return false
	enemy_credits -= repair_cost
	target["hp"] = repair_max_hp
	enemy_buildings[repair_index] = target
	notice = "العدو أصلح منشأة %s مقابل %d من الموارد" % [kind, repair_cost]
	notice_time = 2.0
	queue_redraw()
	return true


func _enemy_has_building(kind: String) -> bool:
	for building in enemy_buildings:
		if building.kind == kind and int(building.get("hp", 1)) > 0 and float(building.get("build_progress", 1.0)) >= 1.0:
			return true
	return false


func _enemy_has_any_building(kind: String) -> bool:
	for building in enemy_buildings:
		if String(building.get("kind", "")) == kind and int(building.get("hp", 1)) > 0:
			return true
	return false


func _enemy_has_building_under_construction(kind: String) -> bool:
	for building in enemy_buildings:
		if String(building.get("kind", "")) == kind and int(building.get("hp", 1)) > 0 and float(building.get("build_progress", 1.0)) < 1.0:
			return true
	return false


func _enemy_power_capacity() -> int:
	var capacity := BASE_POWER_OUTPUT
	for building in enemy_buildings:
		if String(building.get("kind", "")) == "power_plant" and float(building.get("build_progress", 1.0)) >= 1.0 and int(building.get("hp", 1)) > 0:
			capacity += POWER_PLANT_OUTPUT
	return capacity


func _enemy_power_demand() -> int:
	var demand := 0
	for building in enemy_buildings:
		if int(building.get("hp", 1)) > 0 and float(building.get("build_progress", 1.0)) >= 1.0:
			demand += _power_demand(String(building.get("kind", "")))
	return demand


func _is_enemy_building_powered(building_index: int) -> bool:
	if building_index < 0 or building_index >= enemy_buildings.size():
		return false
	var target: Dictionary = enemy_buildings[building_index]
	if int(target.get("hp", 1)) <= 0 or float(target.get("build_progress", 1.0)) < 1.0:
		return false
	var target_demand := _power_demand(String(target.get("kind", "")))
	if target_demand <= 0:
		return true
	var allocated := 0
	var target_priority := _power_priority(String(target.get("kind", "")))
	for i in range(enemy_buildings.size()):
		if i == building_index:
			continue
		var other: Dictionary = enemy_buildings[i]
		if int(other.get("hp", 1)) <= 0 or float(other.get("build_progress", 1.0)) < 1.0:
			continue
		var other_priority := _power_priority(String(other.get("kind", "")))
		if other_priority < target_priority or (other_priority == target_priority and i < building_index):
			allocated += _power_demand(String(other.get("kind", "")))
	return _enemy_power_capacity() >= allocated + target_demand


func _enemy_has_powered_building(kind: String) -> bool:
	for i in range(enemy_buildings.size()):
		if String(enemy_buildings[i].get("kind", "")) == kind and _is_enemy_building_powered(i):
			return true
	return false


func _enemy_defense_guard_role_penalty(unit_kind: String) -> int:
	match unit_kind:
		"infantry":
			return 0
		"tank":
			return 45000
		"artillery":
			return 250000
		_:
			return 500000


func _update_enemy_defense_assignments() -> void:
	# Keep a compact reserve: one base guard, then guards for the most valuable forward assets.
	var eligible_indices: Array[int] = []
	for unit_index in range(units.size()):
		var candidate: Dictionary = units[unit_index]
		if candidate.team == "enemy" and candidate.get("hp", 0) > 0 and ["infantry", "tank", "artillery"].has(String(candidate.kind)):
			eligible_indices.append(unit_index)
			units[unit_index]["defense_guard"] = false
			units[unit_index].erase("defense_anchor")
	var desired_guards := mini(3, maxi(1, int((eligible_indices.size() + 3) / 4))) if not eligible_indices.is_empty() else 0
	var assigned_buildings: Array[int] = []
	for guard_slot in range(desired_guards):
		var guard_asset_pos: Vector2 = enemy_base
		if guard_slot > 0:
			var best_building_index := -1
			var best_building_score := -INF
			for building_index in range(enemy_buildings.size()):
				if assigned_buildings.has(building_index):
					continue
				var building: Dictionary = enemy_buildings[building_index]
				if int(building.get("hp", 0)) <= 0 or float(building.get("build_progress", 1.0)) < 1.0:
					continue
				var building_priority := 0
				match String(building.get("kind", "")):
					"missile_silo":
						building_priority = 6
					"factory", "barracks":
						building_priority = 5
					"airfield", "power_plant":
						building_priority = 4
					"anti_air", "missile_defense":
						building_priority = 3
					"turret":
						building_priority = 2
				if building_priority <= 0:
					continue
				# Prefer critical production assets, then those furthest from the main base.
				var building_score: float = float(building_priority) * 10000.0 + enemy_base.distance_to(building.pos)
				if building_score > best_building_score:
					best_building_score = building_score
					best_building_index = building_index
			if best_building_index >= 0:
				assigned_buildings.append(best_building_index)
				guard_asset_pos = enemy_buildings[best_building_index].pos
		var best_index := -1
		var best_guard_score := INF
		for candidate_index in eligible_indices:
			var guard_candidate: Dictionary = units[candidate_index]
			var distance_score: float = guard_candidate.pos.distance_squared_to(guard_asset_pos)
			# Preserve assault power: infantry fill guard posts first, tanks remain a strong second choice, artillery is the last resort.
			var guard_score: float = distance_score + float(_enemy_defense_guard_role_penalty(String(guard_candidate.get("kind", ""))))
			if guard_score < best_guard_score:
				best_guard_score = guard_score
				best_index = candidate_index
		if best_index < 0:
			break
		var side := -1.0 if guard_slot % 2 == 0 else 1.0
		var lane := 48.0 + float(guard_slot / 2) * 32.0
		units[best_index]["defense_guard"] = true
		units[best_index]["defense_anchor"] = guard_asset_pos + Vector2(-54.0, side * lane)
		eligible_indices.erase(best_index)


func _update_combat_alerts() -> void:
	# Transition-based alerts avoid spamming the command channel every frame.
	var hostile_air := 0
	var hostile_ground := 0
	var incoming_missile := false
	for contact in units:
		if String(contact.get("team", "")) != "enemy" or int(contact.get("hp", 0)) <= 0:
			continue
		var kind := String(contact.get("kind", ""))
		var distance: float = contact.pos.distance_to(base_pos)
		if kind in ["fighter", "helicopter", "transport_helicopter"] and distance <= 460.0:
			hostile_air += 1
		elif kind in ["tank", "artillery", "infantry"] and distance <= 260.0:
			hostile_ground += 1
	for missile in missiles:
		if String(missile.get("team", "")) == "enemy":
			incoming_missile = true
			break
	if incoming_missile and not missile_alert_active:
		notice = "إنذار صاروخي! مقذوف معادٍ باتجاه القاعدة"
		notice_time = 4.0
	elif not incoming_missile and missile_alert_active:
		notice = "انتهى الإنذار الصاروخي — تحقق من الأضرار"
		notice_time = 3.0
	elif hostile_air > 0 and not air_alert_active:
		notice = "تحذير جوي! %d طائرة معادية تقترب من القاعدة" % hostile_air
		notice_time = 3.8
	elif hostile_ground > 0 and not ground_alert_active:
		notice = "تحذير بري! قوات معادية تقترب من محيط القاعدة"
		notice_time = 3.5
	elif air_alert_active and hostile_air == 0:
		notice = "المجال الجوي القريب خالٍ من التهديدات"
		notice_time = 2.5
	elif ground_alert_active and hostile_ground == 0:
		notice = "تم تأمين محيط القاعدة برياً"
		notice_time = 2.5
	air_alert_active = hostile_air > 0
	ground_alert_active = hostile_ground > 0
	missile_alert_active = incoming_missile


func _update_enemy_defense_guard(unit: Dictionary, unit_index: int, delta: float) -> bool:
	# Defensive reserves protect their assigned asset and engage only threats inside its local perimeter.
	var anchor: Vector2 = unit.get("defense_anchor", enemy_base)
	# A guard must abandon a forward post when its assigned structure is destroyed.
	var anchor_is_valid := anchor.distance_to(enemy_base) <= 120.0
	if not anchor_is_valid:
		for asset in enemy_buildings:
			if int(asset.get("hp", 0)) <= 0 or float(asset.get("build_progress", 1.0)) < 1.0:
				continue
			var asset_pos: Vector2 = asset.get("pos", enemy_base)
			if asset_pos.distance_to(anchor) <= 240.0:
				anchor_is_valid = true
				break
	if not anchor_is_valid:
		anchor = enemy_base
		unit["defense_anchor"] = enemy_base
	var guard_radius := 210.0
	var threat_index := -1
	var threat_distance := INF
	for candidate_index in range(units.size()):
		var candidate: Dictionary = units[candidate_index]
		if String(candidate.get("team", "")) != "player" or int(candidate.get("hp", 0)) <= 0:
			continue
		if String(candidate.get("kind", "")) not in ["infantry", "tank", "artillery"]:
			continue
		var perimeter_distance: float = candidate.pos.distance_to(anchor)
		if perimeter_distance > guard_radius:
			continue
		var distance: float = unit.pos.distance_to(candidate.pos)
		if distance < threat_distance:
			threat_distance = distance
			threat_index = candidate_index
	var weapon_range := 300.0 if String(unit.get("kind", "")) == "artillery" else (150.0 if String(unit.get("kind", "")) == "tank" else 105.0)
	if threat_index >= 0:
		var threat: Dictionary = units[threat_index]
		if threat_distance > weapon_range and unit.pos.distance_to(anchor) < guard_radius - 18.0:
			var approach_speed := 22.0 if String(unit.get("kind", "")) == "artillery" else (36.0 if String(unit.get("kind", "")) == "tank" else 55.0)
			var approach := _ground_navigation_direction(unit, unit_index, threat.pos, delta, approach_speed)
			unit.pos += approach * delta * approach_speed
		elif threat_distance <= weapon_range:
			unit["attack_cd"] = float(unit.get("attack_cd", 0.0)) - delta
			if float(unit.get("attack_cd", 0.0)) <= 0.0:
				if String(unit.get("kind", "")) == "artillery":
					_add_visual_effect("targeting", threat.pos, threat.pos, Color("#ffcc70"), 0.46, 76.0)
					_add_visual_effect("muzzle", unit.pos, unit.pos, Color("#ffd18a"), 0.20, 18.0)
					_add_visual_effect("shell", unit.pos, threat.pos, Color("#ffb45e"), 0.42, 66.0)
					_apply_artillery_blast(threat.pos, 76.0, _unit_damage_with_veterancy(unit, 48), "player", unit)
					unit["attack_cd"] = 2.4
				else:
					var hp_before := int(threat.get("hp", 0))
					var damage := _unit_damage_with_veterancy(unit, 20 if String(unit.get("kind", "")) == "tank" else 10)
					threat["hp"] = maxi(0, hp_before - _terrain_adjusted_damage(threat, damage))
					_award_unit_experience(unit, hp_before - int(threat["hp"]))
					_register_unit_kill(unit, threat, hp_before)
					_add_visual_effect("tracer" if String(unit.get("kind", "")) == "tank" else "flash", unit.pos, threat.pos, Color("#ffe0a0"), 0.18, 8.0)
					unit["attack_cd"] = 0.75 if String(unit.get("kind", "")) == "tank" else 1.0
		return true
	if unit.pos.distance_to(anchor) > 12.0:
		var return_speed := 22.0 if String(unit.get("kind", "")) == "artillery" else (36.0 if String(unit.get("kind", "")) == "tank" else 55.0)
		var return_direction := _ground_navigation_direction(unit, unit_index, anchor, delta, return_speed)
		unit.pos += return_direction * delta * return_speed
	return true


func _update_enemy_counterattack_reserve(unit: Dictionary, unit_index: int, delta: float) -> bool:
	# Keep at most two mobile reserves ready to repel a breach near critical enemy assets.
	var is_active := bool(unit.get("counterattack_active", false))
	var anchor: Vector2 = unit.get("counterattack_anchor", enemy_base)
	if not is_active:
		var active_reserves := 0
		for candidate in units:
			if String(candidate.get("team", "")) == "enemy" and bool(candidate.get("counterattack_active", false)) and int(candidate.get("hp", 0)) > 0:
				active_reserves += 1
		if active_reserves >= 2:
			return false
		var asset_positions: Array[Vector2] = [enemy_base]
		for building in enemy_buildings:
			if int(building.get("hp", 0)) <= 0 or float(building.get("build_progress", 1.0)) < 1.0:
				continue
			if String(building.get("kind", "")) in ["missile_silo", "factory", "barracks", "airfield", "power_plant", "anti_air", "missile_defense"]:
				asset_positions.append(building.pos)
		var best_anchor_distance := INF
		var breached_anchor := Vector2.ZERO
		var breach_found := false
		for asset_pos in asset_positions:
			var local_threat := _nearest_player_ground_unit(asset_pos, 185.0)
			if local_threat < 0:
				continue
			var asset_distance: float = unit.pos.distance_to(asset_pos)
			if asset_distance > 300.0:
				continue
			var score: float = asset_distance + asset_pos.distance_to(units[local_threat].pos) * 0.35
			if score < best_anchor_distance:
				best_anchor_distance = score
				breached_anchor = asset_pos
				breach_found = true
		if not breach_found:
			return false
		unit["counterattack_active"] = true
		unit["counterattack_anchor"] = breached_anchor
		anchor = breached_anchor
	var threat_index := _nearest_player_ground_unit(anchor, 205.0)
	if threat_index < 0:
		if unit.pos.distance_to(anchor) > 14.0:
			var return_speed := 36.0 if String(unit.get("kind", "")) == "tank" else 55.0
			var return_direction := _ground_navigation_direction(unit, unit_index, anchor, delta, return_speed)
			unit.pos += return_direction * delta * return_speed
		else:
			unit.erase("counterattack_active")
			unit.erase("counterattack_anchor")
		return true
	var threat: Dictionary = units[threat_index]
	var distance: float = unit.pos.distance_to(threat.pos)
	var weapon_range := 150.0 if String(unit.get("kind", "")) == "tank" else 105.0
	if distance > weapon_range and unit.pos.distance_to(anchor) < 225.0:
		var move_speed := 36.0 if String(unit.get("kind", "")) == "tank" else 55.0
		var direction := _ground_navigation_direction(unit, unit_index, threat.pos, delta, move_speed)
		unit.pos += direction * delta * move_speed
	elif distance <= weapon_range:
		unit["attack_cd"] = float(unit.get("attack_cd", 0.0)) - delta
		if float(unit.get("attack_cd", 0.0)) <= 0.0:
			var hp_before := int(threat.get("hp", 0))
			var damage := _unit_damage_with_veterancy(unit, 20 if String(unit.get("kind", "")) == "tank" else 10)
			threat["hp"] = maxi(0, hp_before - _terrain_adjusted_damage(threat, damage))
			_award_unit_experience(unit, hp_before - int(threat["hp"]))
			_register_unit_kill(unit, threat, hp_before)
			_add_visual_effect("tracer" if String(unit.get("kind", "")) == "tank" else "flash", unit.pos, threat.pos, Color("#ffe0a0"), 0.18, 8.0)
			unit["attack_cd"] = 0.75 if String(unit.get("kind", "")) == "tank" else 1.0
	return true


func _update_enemy_retreat(unit: Dictionary, delta: float) -> bool:
	# Critically damaged mobile troops withdraw, recover beside a safe asset, then rejoin the battle.
	var max_hp := 150 if String(unit.get("kind", "")) == "tank" else (60 if String(unit.get("kind", "")) == "infantry" else 100)
	var current_hp := int(unit.get("hp", max_hp))
	if current_hp <= 0:
		return false
	var is_defensive_assignment := bool(unit.get("defense_guard", false)) or bool(unit.get("landing_support_active", false))
	# Guards and landing-support units hold their post until critically wounded, but never fight to destruction.
	var retreat_threshold := 0.12 if is_defensive_assignment else 0.25
	if not bool(unit.get("retreating", false)) and float(current_hp) > float(max_hp) * retreat_threshold:
		return false
	unit["retreating"] = true
	unit.erase("landing_support_target")
	var retreat_destination: Vector2 = _enemy_retreat_destination(unit.pos)
	var retreat_distance: float = unit.pos.distance_to(retreat_destination)
	if retreat_distance > 48.0:
		var retreat_step: float = minf(28.0 * delta, retreat_distance - 48.0)
		unit.pos += (retreat_destination - unit.pos).normalized() * retreat_step
	else:
		# A damaged unit must actually reach a safe rally point before it can recover.
		# Do not regenerate while enemy troops are close enough to punish the retreat.
		var nearest_hostile_distance := INF
		for hostile in units:
			if String(hostile.get("team", "")) != "player" or int(hostile.get("hp", 0)) <= 0:
				continue
			nearest_hostile_distance = minf(nearest_hostile_distance, retreat_destination.distance_to(hostile.pos))
		if nearest_hostile_distance >= 150.0:
			var recovery_rate := 10.0 if String(unit.get("kind", "")) == "tank" else 8.0
			unit["hp"] = mini(max_hp, int(ceil(float(current_hp) + recovery_rate * delta)))
			if int(unit["hp"]) >= int(ceil(max_hp * 0.6)):
				unit.erase("retreating")
				return false
	return true


func _enemy_retreat_destination(from_pos: Vector2) -> Vector2:
	# Prefer completed friendly assets that are both reachable and away from nearby player forces.
	var candidate_positions: Array[Vector2] = [enemy_base]
	for building in enemy_buildings:
		if int(building.get("hp", 0)) <= 0 or float(building.get("build_progress", 1.0)) < 1.0:
			continue
		candidate_positions.append(building.pos)
	var safest_destination: Vector2 = enemy_base
	var best_score := INF
	for candidate in candidate_positions:
		var nearest_hostile_distance := INF
		for hostile in units:
			if String(hostile.get("team", "")) != "player" or int(hostile.get("hp", 0)) <= 0:
				continue
			nearest_hostile_distance = minf(nearest_hostile_distance, candidate.distance_to(hostile.pos))
		# A nearby hostile adds a proportional penalty, while distance still favors practical retreats.
		var danger_penalty := maxf(0.0, 220.0 - nearest_hostile_distance) * 2.5
		var candidate_score := from_pos.distance_to(candidate) + danger_penalty
		if candidate_score < best_score:
			best_score = candidate_score
			safest_destination = candidate
	return safest_destination


func _enemy_ai_turn() -> void:
	var player_air_threat = 0
	var player_heavy_ground_threat = 0
	var player_infantry_threat = 0
	var close_air_pressure := 0
	var close_heavy_pressure := 0
	var close_infantry_pressure := 0
	for player_unit in units:
		if player_unit.team != "player" or player_unit.get("hp", 0) <= 0:
			continue
		var unit_kind := String(player_unit.get("kind", ""))
		var is_air_threat := unit_kind in ["fighter", "helicopter", "transport_helicopter"]
		var is_heavy_threat := unit_kind == "tank" or unit_kind == "artillery"
		var is_infantry_threat := unit_kind == "infantry"
		if is_air_threat:
			player_air_threat += 1
		elif is_heavy_threat:
			player_heavy_ground_threat += 1
		elif is_infantry_threat:
			player_infantry_threat += 1
		# A unit near the enemy base or a critical installation is more urgent
		# than an identical unit still far from the defensive perimeter.
		var nearest_asset_distance: float = player_unit.pos.distance_to(enemy_base)
		for protected_asset in enemy_buildings:
			if int(protected_asset.get("hp", 0)) <= 0:
				continue
			var asset_kind := String(protected_asset.get("kind", ""))
			if asset_kind not in ["airfield", "power_plant", "factory", "missile_silo", "barracks"]:
				continue
			nearest_asset_distance = minf(nearest_asset_distance, player_unit.pos.distance_to(protected_asset.pos))
		if nearest_asset_distance <= 300.0:
			if is_air_threat:
				close_air_pressure += 1
			elif is_heavy_threat:
				close_heavy_pressure += 1
			elif is_infantry_threat:
				close_infantry_pressure += 1
	var next_strategy := _enemy_choose_strategy(player_air_threat + close_air_pressure, 0, player_heavy_ground_threat + close_heavy_pressure, player_infantry_threat + close_infantry_pressure)
	if next_strategy != enemy_strategy:
		enemy_strategy = next_strategy
		var strategy_names := {"air_control": "التفوق الجوي", "armor_breaker": "مكافحة القوات المدرعة", "area_denial": "القصف المساحي", "balanced": "التوازن"}
		notice = "العدو يغيّر خطته إلى: %s" % strategy_names.get(enemy_strategy, "التوازن")
		notice_time = 2.5
	var build_pos := _enemy_build_position()
	var player_missile_threat := _has_building("missile_silo")
	for incoming_missile in missiles:
		if String(incoming_missile.get("team", "")) == "player":
			player_missile_threat = true
			break
	# Expand enemy generation before adding more powered infrastructure.
	if build_pos.x >= 0.0 and _enemy_power_demand() >= _enemy_power_capacity() and not _enemy_has_building_under_construction("power_plant") and enemy_credits >= _building_cost("power_plant"):
		enemy_credits -= _building_cost("power_plant")
		_enemy_add_building("power_plant", build_pos, 400)
		notice = "العدو يعزز شبكة الطاقة بمحطة جديدة"
		notice_time = 2.0
		return
	# Prioritize a second anti-air position immediately when the player fields
	# a substantial air force; do not wait for every optional base structure.
	if player_air_threat >= 3 and enemy_credits >= _building_cost("anti_air"):
		var live_anti_air_count := 0
		for existing_building in enemy_buildings:
			if String(existing_building.get("kind", "")) == "anti_air" and int(existing_building.get("hp", 1)) > 0:
				live_anti_air_count += 1
		if live_anti_air_count < 2:
			var urgent_air_defense_pos := _enemy_air_defense_build_position()
			if urgent_air_defense_pos.x >= 0.0:
				enemy_credits -= _building_cost("anti_air")
				_enemy_add_building("anti_air", urgent_air_defense_pos, 380)
				notice = "العدو يعزز دفاعه بمضاد طائرات عاجل"
				notice_time = 2.0
				return
	# Repair critical damage before spending on optional base expansion.
	if _enemy_repair_damaged_building():
		return
	# A full base must not freeze the enemy's production and combat decisions.
	if build_pos.x >= 0.0 and not _enemy_has_any_building("barracks") and enemy_credits >= _building_cost("barracks"):
		enemy_credits -= _building_cost("barracks")
		_enemy_add_building("barracks", build_pos, 400)
		notice = "العدو أنشأ ثكنة عسكرية"
		notice_time = 2.0
		return
	if build_pos.x >= 0.0 and not _enemy_has_any_building("factory") and enemy_credits >= _building_cost("factory"):
		enemy_credits -= _building_cost("factory")
		_enemy_add_building("factory", build_pos, 500)
		notice = "العدو أنشأ مصنع دبابات"
		notice_time = 2.0
		return
	if build_pos.x >= 0.0 and not _enemy_has_any_building("turret") and enemy_credits >= _building_cost("turret"):
		enemy_credits -= _building_cost("turret")
		_enemy_add_building("turret", build_pos, 350)
		notice = "العدو نشر برجاً دفاعياً"
		notice_time = 2.0
		return
	if build_pos.x >= 0.0 and not _enemy_has_any_building("airfield") and enemy_credits >= _building_cost("airfield"):
		enemy_credits -= _building_cost("airfield")
		_enemy_add_building("airfield", build_pos, 450)
		notice = "العدو أنشأ مطاراً حربياً"
		notice_time = 2.0
		return
	if build_pos.x >= 0.0 and not _enemy_has_any_building("missile_silo") and enemy_credits >= _building_cost("missile_silo"):
		enemy_credits -= _building_cost("missile_silo")
		_enemy_add_building("missile_silo", build_pos, 500, 8.0)
		notice = "العدو أنشأ منصة صواريخ"
		notice_time = 2.0
		return
	if player_missile_threat and build_pos.x >= 0.0 and not _enemy_has_any_building("missile_defense") and enemy_credits >= _building_cost("missile_defense"):
		enemy_credits -= _building_cost("missile_defense")
		_enemy_add_building("missile_defense", build_pos, 450)
		notice = "العدو نشر دفاعاً صاروخياً"
		notice_time = 2.0
		return
	# Enemy naval expansion is intentionally disabled in the land-and-air release.
	if not _enemy_has_any_building("anti_air") and enemy_credits >= _building_cost("anti_air"):
		var initial_air_defense_pos := _enemy_air_defense_build_position()
		if initial_air_defense_pos.x >= 0.0:
			enemy_credits -= _building_cost("anti_air")
			_enemy_add_building("anti_air", initial_air_defense_pos, 380)
			notice = "العدو نشر دفاعاً مضاداً للطائرات"
			notice_time = 2.0
			return
	var enemy_tanks := 0
	var enemy_infantry := 0
	var enemy_artillery := 0
	var enemy_fighters := 0
	var enemy_helicopters := 0
	var enemy_destroyers := 0
	var enemy_landing_craft := 0
	var enemy_carriers := 0
	var enemy_submarines := 0
	for unit in units:
		if unit.team != "enemy" or unit.get("hp", 0) <= 0:
			continue
		if unit.kind == "tank":
			enemy_tanks += 1
		elif unit.kind == "artillery":
			enemy_artillery += 1
		elif unit.kind == "fighter":
			enemy_fighters += 1
		elif unit.kind == "helicopter":
			enemy_helicopters += 1
		elif unit.kind == "destroyer":
			enemy_destroyers += 1
		elif unit.kind == "landing_craft":
			enemy_landing_craft += 1
		elif unit.kind == "carrier":
			enemy_carriers += 1
		elif unit.kind == "submarine":
			enemy_submarines += 1
		elif unit.kind == "infantry":
			enemy_infantry += 1

	if _team_unit_count("enemy") >= MAX_TEAM_UNITS:
		return
	# Once an escort destroyer is available, launch the amphibious assault before
	# filling additional naval-counter slots; otherwise naval doctrine starves its landing force.
	if _enemy_has_powered_building("shipyard") and enemy_credits >= _unit_cost("landing_craft", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("landing_craft") and enemy_landing_craft < 1 and enemy_destroyers >= 1:
		enemy_credits -= _unit_cost("landing_craft", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("landing_craft")
		var landing_dock: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": landing_dock, "team": "enemy", "kind": "landing_craft", "faction": _enemy_faction(), "hp": 220, "attack_cd": 0.0, "home_pos": landing_dock, "landing_state": "outbound", "passengers": 3, "landing_timer": 0.0})
		return
	if _enemy_counter_production(enemy_strategy, enemy_fighters, enemy_helicopters, enemy_artillery, enemy_destroyers):
		return
	# Secure a minimum infantry screen before optional naval expansion; this keeps the AI base from becoming undefended.
	if _enemy_has_powered_building("barracks") and enemy_credits >= _unit_cost("infantry", _enemy_faction()) and enemy_infantry < 2:
		enemy_credits -= _unit_cost("infantry", _enemy_faction())
		units.append({"pos": enemy_base + Vector2(-75.0, randf_range(-65.0, 65.0)), "team": "enemy", "kind": "infantry", "faction": _enemy_faction(), "hp": 60, "target": enemy_base, "attack_cd": 0.0})
		return
	# Restore a minimum armored reserve before spending on optional naval expansion.
	if _enemy_has_powered_building("factory") and enemy_credits >= _unit_cost("tank", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("tank") and enemy_tanks < 2:
		enemy_credits -= _unit_cost("tank", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("tank")
		units.append({"pos": enemy_base + Vector2(-75.0, randf_range(-75.0, 75.0)), "team": "enemy", "kind": "tank", "faction": _enemy_faction(), "hp": 150, "target": base_pos, "attack_cd": 0.0})
		return
	if _enemy_has_powered_building("shipyard") and enemy_credits >= _unit_cost("carrier", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("carrier") and enemy_carriers < 1 and enemy_destroyers >= 1:
		enemy_credits -= _unit_cost("carrier", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("carrier")
		var enemy_dock_pos: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": enemy_dock_pos, "team": "enemy", "kind": "carrier", "faction": _enemy_faction(), "hp": 520, "attack_cd": 0.0, "launch_cd": 8.0})
	elif _enemy_has_powered_building("shipyard") and enemy_credits >= _unit_cost("submarine", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("submarine") and enemy_submarines < 1 and enemy_destroyers >= 1:
		enemy_credits -= _unit_cost("submarine", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("submarine")
		var enemy_dock_pos: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": enemy_dock_pos, "team": "enemy", "kind": "submarine", "faction": _enemy_faction(), "hp": 210, "attack_cd": 0.0})
	elif _enemy_has_powered_building("shipyard") and enemy_credits >= _unit_cost("destroyer", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("destroyer") and enemy_destroyers < 2:
		enemy_credits -= _unit_cost("destroyer", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("destroyer")
		var enemy_dock_pos: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": enemy_dock_pos, "team": "enemy", "kind": "destroyer", "faction": _enemy_faction(), "hp": 260, "target": base_pos, "attack_cd": 0.0})

	elif _enemy_has_powered_building("airfield") and enemy_credits >= _unit_cost("fighter", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("fighter") and enemy_fighters < (4 if player_air_threat >= 2 else 2):
		enemy_credits -= _unit_cost("fighter", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("fighter")
		units.append({"pos": enemy_base + Vector2(-90, randf_range(-75, 75)), "team": "enemy", "kind": "fighter", "faction": _enemy_faction(), "hp": 120, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_powered_building("airfield") and enemy_credits >= _helicopter_cost(_enemy_faction()) and enemy_supplies >= _unit_supply_cost("helicopter") and enemy_helicopters < (3 if player_heavy_ground_threat >= 3 else 2):
		enemy_credits -= _helicopter_cost(_enemy_faction())
		enemy_supplies -= _unit_supply_cost("helicopter")
		var rival_faction := _enemy_faction()
		units.append({"pos": enemy_base + Vector2(-90, randf_range(-75, 75)), "team": "enemy", "kind": "helicopter", "faction": rival_faction, "hp": 180, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_powered_building("factory") and enemy_credits >= _unit_cost("artillery", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("artillery") and (enemy_tanks >= 2 or player_infantry_threat >= 6) and enemy_artillery < min(3, max(1, int(ceil(float(enemy_tanks) / 2.0)))):
		enemy_credits -= _unit_cost("artillery", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("artillery")
		units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "artillery", "faction": _enemy_faction(), "hp": 100, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_powered_building("factory") and enemy_credits >= _unit_cost("tank", _enemy_faction()) and enemy_supplies >= _unit_supply_cost("tank") and enemy_tanks < (5 if player_heavy_ground_threat >= 4 else 4):
		enemy_credits -= _unit_cost("tank", _enemy_faction())
		enemy_supplies -= _unit_supply_cost("tank")
		units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "tank", "faction": _enemy_faction(), "hp": 150, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_powered_building("barracks") and enemy_credits >= _unit_cost("infantry", _enemy_faction()) and enemy_infantry < 8:
		enemy_credits -= _unit_cost("infantry", _enemy_faction())
		units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "infantry", "faction": _enemy_faction(), "hp": 60, "target": base_pos, "attack_cd": 0.0})

func _enemy_should_engage_player(has_player_target: bool, player_distance: float, objective_distance: float, strategy: String, landing_support_active: bool) -> bool:
	# Landing support and non-balanced doctrines may engage immediately; balanced forces weigh nearby supply objectives.
	if landing_support_active:
		return true
	if not has_player_target:
		return false
	return strategy != "balanced" or objective_distance == INF or player_distance <= objective_distance + 80.0


func _enemy_choose_strategy(air_threat: int, naval_threat: int, heavy_ground_threat: int, infantry_threat: int) -> String:
	# Score threats by battlefield impact instead of reacting to raw counts alone.
	# A small hysteresis margin prevents doctrine flicker when unit counts fluctuate.
	var threat_scores := {
		"air_control": float(air_threat) * 3.0,
		"naval_control": float(naval_threat) * 4.0,
		"armor_breaker": float(heavy_ground_threat) * 2.5,
		"area_denial": float(infantry_threat) * 1.1
	}
	var next_strategy := "balanced"
	var strongest_score := 5.0
	for strategy_name in threat_scores:
		var score := float(threat_scores[strategy_name])
		if score > strongest_score:
			strongest_score = score
			next_strategy = String(strategy_name)
	# Keep the current doctrine if it is still relevant and nearly as strong
	# as the new leader; switch immediately only for a clearly stronger threat.
	if enemy_strategy != "balanced" and threat_scores.has(enemy_strategy):
		var current_score := float(threat_scores[enemy_strategy])
		if current_score >= 5.0 and current_score >= strongest_score - 1.5:
			return enemy_strategy
	return next_strategy


func _enemy_counter_production(strategy: String, fighter_count: int, helicopter_count: int, artillery_count: int, destroyer_count: int) -> bool:
	var kind := ""
	var cost := 0
	var supply_cost := 0
	var unit_hp := 0
	match strategy:
		"air_control":
			if fighter_count < 4 and _enemy_has_powered_building("airfield"):
				kind = "fighter"
				cost = _unit_cost(kind, _enemy_faction())
				supply_cost = _unit_supply_cost(kind)
				unit_hp = 120
		"armor_breaker":
			if helicopter_count < 3 and _enemy_has_powered_building("airfield"):
				kind = "helicopter"
				cost = _helicopter_cost(_enemy_faction())
				supply_cost = _unit_supply_cost(kind)
				unit_hp = 180
		"area_denial":
			if artillery_count < 3 and _enemy_has_powered_building("factory"):
				kind = "artillery"
				cost = _unit_cost(kind, _enemy_faction())
				supply_cost = _unit_supply_cost(kind)
				unit_hp = 100
	if kind == "" or enemy_credits < cost or enemy_supplies < supply_cost:
		return false
	enemy_credits -= cost
	enemy_supplies -= supply_cost
	var spawn_pos := enemy_base + Vector2(-82.0, randf_range(-72.0, 72.0))
	if kind == "destroyer":
		# Naval counters must enter the water at the shipyard, not spawn on the land base.
		spawn_pos = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
	units.append({"pos": spawn_pos, "team": "enemy", "kind": kind, "faction": _enemy_faction(), "hp": unit_hp, "target": base_pos, "attack_cd": 0.0})
	return true


func _enemy_build_position() -> Vector2:
	var size = get_viewport_rect().size
	for attempt in 12:
		var candidate = enemy_base + Vector2(randf_range(-185.0, -105.0), randf_range(-175.0, 175.0))
		candidate.x = clampf(candidate.x, size.x * 0.52, size.x - 65.0)
		candidate.y = clampf(candidate.y, 105.0, size.y - 105.0)
		if candidate.distance_to(enemy_base) < 90.0:
			continue
		var occupied := false
		for building in enemy_buildings:
			if building.pos.distance_to(candidate) < 82.0:
				occupied = true
				break
		if not occupied:
			return candidate
	return Vector2(-1.0, -1.0)

func _draw_building(p: Vector2, kind: String, is_enemy: bool = false, is_captured: bool = false) -> void:
	var team_color = Color("#79d47b") if is_captured else (Color("#4c91d0") if not is_enemy else Color("#d65349"))
	var shell := Color("#a9b4ad") if not is_enemy else Color("#a87870")
	var dark := Color("#303b40")
	var accent := Color("#d8c58e") if not is_enemy else Color("#e0a18c")
	match kind:
		"barracks":
			shell = Color("#b5a078") if not is_enemy else Color("#a86a60")
		"factory":
			shell = Color("#778c9b") if not is_enemy else Color("#8e6870")
		"turret", "anti_air":
			shell = Color("#788b64") if not is_enemy else Color("#a45e50")
		"airfield":
			shell = Color("#8297a1") if not is_enemy else Color("#9d6d70")
		"missile_silo":
			shell = Color("#a18e5d") if not is_enemy else Color("#986d61")
		"missile_defense":
			shell = Color("#5e8792") if not is_enemy else Color("#9b6662")
		"shipyard":
			shell = Color("#6f929b") if not is_enemy else Color("#a66c65")
		"power_plant":
			shell = Color("#b69a58") if not is_enemy else Color("#a66c5d")
		"bunker":
			shell = Color("#777d73") if not is_enemy else Color("#98675e")
		"wall", "wall_corner", "wall_gate":
			shell = Color("#8d8b78") if not is_enemy else Color("#986e63")
	# Ground shadow, reinforced foundation and faction identification stripe.
	draw_colored_polygon(PackedVector2Array([p + Vector2(-36, 25), p + Vector2(-25, 17), p + Vector2(25, 17), p + Vector2(42, 25), p + Vector2(25, 33), p + Vector2(-25, 33)]), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(p + Vector2(-35, -25), Vector2(70, 54)), Color("#252d31"))
	draw_rect(Rect2(p + Vector2(-32, -22), Vector2(64, 48)), dark)
	draw_rect(Rect2(p + Vector2(-28, -19), Vector2(56, 40)), shell)
	draw_rect(Rect2(p + Vector2(-28, -19), Vector2(56, 5)), team_color)
	draw_rect(Rect2(p + Vector2(-28, 16), Vector2(56, 5)), Color(dark, 0.85))
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(p + Vector2(side * 23.0 - 3.0, -12), Vector2(6, 7)), accent)
		draw_rect(Rect2(p + Vector2(side * 23.0 - 3.0, 4), Vector2(6, 7)), accent)
	match kind:
		"barracks":
			draw_rect(Rect2(p + Vector2(-15, -12), Vector2(30, 25)), Color("#756b59"))
			draw_rect(Rect2(p + Vector2(-10, -8), Vector2(20, 17)), Color("#39464b"))
			draw_rect(Rect2(p + Vector2(-7, -5), Vector2(14, 11)), accent)
			draw_rect(Rect2(p + Vector2(-4, 9), Vector2(8, 7)), dark)
		"factory":
			draw_rect(Rect2(p + Vector2(-18, -15), Vector2(36, 29)), Color("#46535a"))
			draw_rect(Rect2(p + Vector2(-14, -11), Vector2(28, 19)), shell)
			for vent in range(3):
				draw_rect(Rect2(p + Vector2(-12 + vent * 10, -8), Vector2(5, 13)), dark)
			draw_rect(Rect2(p + Vector2(-20, 13), Vector2(40, 5)), accent)
			draw_circle(p + Vector2(19, -17), 5, Color("#59636a"))
			draw_circle(p + Vector2(19, -17), 2, Color("#c5d0ce"))
		"turret", "anti_air":
			draw_circle(p, 19, dark)
			draw_circle(p, 14, shell)
			draw_circle(p, 7, accent)
			if kind == "anti_air":
				draw_line(p + Vector2(-3, -2), p + Vector2(20, -19), dark, 5)
				draw_line(p + Vector2(3, 2), p + Vector2(23, -15), Color("#9ce5f0"), 3)
				draw_arc(p, 24, 3.5, 5.7, 24, Color("#9ce5f0"), 2)
			else:
				draw_line(p, p + Vector2(27, -7), dark, 8)
				draw_line(p, p + Vector2(27, -7), accent, 3)
		"airfield":
			draw_rect(Rect2(p + Vector2(-23, -13), Vector2(46, 26)), dark)
			draw_rect(Rect2(p + Vector2(-19, -9), Vector2(38, 18)), shell)
			draw_line(p + Vector2(-28, 0), p + Vector2(28, 0), accent, 3)
			draw_line(p + Vector2(-18, -16), p + Vector2(18, -16), team_color, 3)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(5, 1), p + Vector2(0, 8), p + Vector2(-5, 1)]), Color("#e3e8e4"))
		"missile_silo":
			draw_rect(Rect2(p + Vector2(-17, -16), Vector2(34, 31)), dark)
			draw_circle(p, 13, shell)
			draw_circle(p, 8, dark)
			draw_line(p + Vector2(0, -2), p + Vector2(0, -32), accent, 5)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -39), p + Vector2(-5, -28), p + Vector2(5, -28)]), Color("#e7d9b2"))
		"missile_defense":
			draw_circle(p, 18, dark)
			draw_circle(p, 12, shell)
			draw_circle(p, 5, Color("#9ce5f0"))
			draw_arc(p, 26, 3.3, 6.0, 32, Color("#9ce5f0"), 3)
			draw_line(p + Vector2(0, -5), p + Vector2(0, -28), accent, 4)
		"bunker":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-27, 12), p + Vector2(-20, -13), p + Vector2(20, -13), p + Vector2(27, 12)]), shell)
			draw_rect(Rect2(p + Vector2(-19, -5), Vector2(38, 18)), dark)
			draw_rect(Rect2(p + Vector2(-12, -2), Vector2(24, 9)), Color("#b7a27b"))
			draw_line(p + Vector2(-25, 13), p + Vector2(25, 13), accent, 4)
		"supply_depot":
			draw_rect(Rect2(p + Vector2(-22, -15), Vector2(44, 30)), dark)
			draw_rect(Rect2(p + Vector2(-18, -11), Vector2(36, 22)), Color("#6b887d"))
			for crate_x in [-10.0, 0.0, 10.0]:
				draw_rect(Rect2(p + Vector2(crate_x - 4.0, -7), Vector2(8, 14)), Color("#d3bd82"))
				draw_line(p + Vector2(crate_x - 4.0, 0), p + Vector2(crate_x + 4.0, 0), dark, 1.5)
		"power_plant":
			draw_rect(Rect2(p + Vector2(-18, -17), Vector2(36, 34)), dark)
			draw_rect(Rect2(p + Vector2(-13, -12), Vector2(26, 24)), shell)
			for coil in range(3):
				draw_circle(p + Vector2(-8 + coil * 8, 0), 4, Color("#f2d47b"))
			draw_line(p + Vector2(-18, 19), p + Vector2(18, 19), accent, 3)
		"wall":
			draw_rect(Rect2(p + Vector2(-34, -9), Vector2(68, 18)), dark)
			draw_rect(Rect2(p + Vector2(-31, -7), Vector2(62, 13)), shell)
			draw_line(p + Vector2(-34, -10), p + Vector2(34, -10), accent, 4)
			for merlon_x in [-22.0, -8.0, 8.0, 22.0]:
				draw_rect(Rect2(p + Vector2(merlon_x - 3.0, -16), Vector2(6, 7)), shell)
		"wall_corner":
			draw_rect(Rect2(p + Vector2(-32, -8), Vector2(42, 16)), dark)
			draw_rect(Rect2(p + Vector2(-29, -6), Vector2(38, 12)), shell)
			draw_rect(Rect2(p + Vector2(9, -8), Vector2(16, 42)), dark)
			draw_rect(Rect2(p + Vector2(11, -6), Vector2(12, 38)), shell)
			draw_line(p + Vector2(-31, -10), p + Vector2(10, -10), accent, 4)
			draw_line(p + Vector2(10, -10), p + Vector2(10, 32), accent, 4)
		"wall_gate":
			draw_rect(Rect2(p + Vector2(-44, -18), Vector2(12, 36)), dark)
			draw_rect(Rect2(p + Vector2(32, -18), Vector2(12, 36)), dark)
			draw_rect(Rect2(p + Vector2(-41, -16), Vector2(7, 32)), shell)
			draw_rect(Rect2(p + Vector2(34, -16), Vector2(7, 32)), shell)
			draw_line(p + Vector2(-38, -17), p + Vector2(38, -17), accent, 4)
			draw_line(p + Vector2(-24, 10), p + Vector2(24, 10), Color("#d6c18a"), 3)
		"shipyard":
			draw_rect(Rect2(p + Vector2(-27, -14), Vector2(54, 29)), Color("#354e5a"))
			draw_rect(Rect2(p + Vector2(-21, -9), Vector2(42, 19)), shell)
			draw_line(p + Vector2(-29, 12), p + Vector2(29, 12), accent, 4)
			draw_line(p + Vector2(-17, -3), p + Vector2(17, -3), Color("#d4e2e4"), 2)
			for post in [-23.0, 23.0]:
				draw_circle(p + Vector2(post, 18), 3, dark)
		_:
			draw_rect(Rect2(p + Vector2(-12, -13), Vector2(24, 27)), dark)
	if kind in ["barracks", "factory", "airfield", "missile_silo", "missile_defense"]:
		draw_line(p + Vector2(22, -17), p + Vector2(22, -31), dark, 2)
		draw_circle(p + Vector2(22, -32), 3, Color("#f1c66d"))
	var labels := {"power_plant": "محطة طاقة", "shipyard": "حوض سفن", "missile_silo": "منصة صواريخ", "missile_defense": "دفاع صاروخي", "barracks": "ثكنة", "factory": "مصنع", "airfield": "مطار", "anti_air": "مضاد جو", "bunker": "مخبأ دفاعي", "supply_depot": "مخزن إمداد", "wall": "جدار دفاعي", "wall_corner": "زاوية تحصين", "wall_gate": "بوابة القاعدة"}
	var label: String = labels.get(kind, "برج دفاع")
	var display_label := "مستولى عليها: " + label if is_captured else label
	draw_string(ThemeDB.fallback_font, p + Vector2(-52, 43), display_label, HORIZONTAL_ALIGNMENT_CENTER, 104, 12 if is_captured else 13, Color("#b8f0b4") if is_captured else Color.WHITE)

func _place_building(pos: Vector2) -> void:
	if not NAVAL_SYSTEM_ENABLED and build_mode == "shipyard":
		build_mode = ""
		notice = "الأحواض والمنشآت البحرية مؤجلة عن النسخة الحالية"
		notice_time = 2.5
		return
	var builder_index := -1
	for selected_index in selected:
		if selected_index >= 0 and selected_index < units.size() and units[selected_index].team == "player" and units[selected_index].kind == "builder" and units[selected_index].get("hp", 0) > 0:
			builder_index = selected_index
			break
	if builder_index < 0:
		notice = "حدد مركبة البناء أولاً ثم اختر موقع المبنى"
		notice_time = 2.5
		build_mode = ""
		return
	if units[builder_index].pos.distance_to(pos) > 220.0:
		notice = "موقع البناء بعيد — حرّك مركبة البناء بالقرب منه"
		notice_time = 2.5
		return
	var cost = _building_cost(build_mode)
	var is_wall_piece := build_mode in ["wall", "wall_corner", "wall_gate"]
	var wall_distance := pos.distance_to(base_pos)
	if (build_mode == "shipyard" and (pos.y < get_viewport_rect().size.y * 0.72 or pos.x > get_viewport_rect().size.x * 0.48 or wall_distance > 390.0)) or (build_mode != "shipyard" and (pos.x > get_viewport_rect().size.x * 0.48 or wall_distance > (420.0 if is_wall_piece else 390.0) or wall_distance < (60.0 if is_wall_piece else 85.0))):
		notice = "اختر موقعاً مناسباً قرب قاعدتك"
		notice_time = 2.0
		return
	for building in buildings:
		var existing_is_wall := String(building.get("kind", "")) in ["wall", "wall_corner", "wall_gate"]
		var required_spacing := 34.0 if is_wall_piece and existing_is_wall else (52.0 if is_wall_piece or existing_is_wall else 75.0)
		if building.pos.distance_to(pos) < required_spacing:
			notice = "الموقع مشغول أو قريب من قطعة تحصين أخرى"
			notice_time = 2.0
			return
	if credits < cost:
		notice = "موارد غير كافية للبناء"
		notice_time = 2.0
		return
	credits -= cost
	var construction_duration := 8.0
	match build_mode:
		"power_plant": construction_duration = 7.0
		"turret", "anti_air": construction_duration = 6.0
		"factory", "airfield": construction_duration = 10.0
		"missile_silo", "shipyard": construction_duration = 13.0
		"missile_defense", "bunker": construction_duration = 9.0
		"supply_depot": construction_duration = 10.0
		"wall", "wall_corner", "wall_gate": construction_duration = 3.5
	var new_building := {"pos": pos, "kind": build_mode, "hp": _building_max_hp({"kind": build_mode, "level": 1}), "attack_cd": 0.0, "build_progress": 0.0, "build_duration": construction_duration, "supply_timer": 0.0, "production_id": next_building_production_id}
	buildings.append(new_building)
	next_building_production_id += 1
	units[builder_index]["target"] = pos
	units[builder_index]["build_target"] = pos
	var building_labels := {"power_plant": "محطة الطاقة", "shipyard": "حوض السفن", "missile_silo": "منصة الصواريخ", "missile_defense": "الدفاع الصاروخي", "barracks": "الثكنة", "factory": "المصنع", "airfield": "المطار", "anti_air": "الدفاع المضاد للطائرات", "turret": "برج الدفاع", "bunker": "المخبأ الدفاعي", "wall": "الجدار الدفاعي", "wall_corner": "زاوية التحصين", "wall_gate": "بوابة القاعدة"}
	var building_name: String = building_labels.get(build_mode, "المبنى")
	notice = "بدأ إنشاء %s — انتظر اكتمال البناء" % building_name
	notice_time = 2.0
	build_mode = ""

const BASE_POWER_OUTPUT := 8
const POWER_PLANT_OUTPUT := 14

func _power_demand(kind: String) -> int:
	match kind:
		"barracks", "turret": return 2
		"factory", "airfield": return 4
		"anti_air", "shipyard": return 3
		"missile_silo": return 5
		"missile_defense": return 4
	return 0

func _power_priority(kind: String) -> int:
	if kind in ["turret", "anti_air", "missile_defense"]:
		return 0
	if kind in ["barracks", "factory", "airfield", "shipyard"]:
		return 1
	if kind == "missile_silo":
		return 2
	return 3

func _player_power_capacity() -> int:
	var capacity := BASE_POWER_OUTPUT
	for building in buildings:
		if int(building.get("hp", 1)) > 0 and String(building.get("kind", "")) == "power_plant" and float(building.get("build_progress", 1.0)) >= 1.0:
			capacity += POWER_PLANT_OUTPUT + (maxi(1, int(building.get("level", 1))) - 1) * 5
	return capacity

func _player_power_demand() -> int:
	var demand := 0
	for building in buildings:
		if int(building.get("hp", 1)) > 0 and float(building.get("build_progress", 1.0)) >= 1.0:
			demand += _power_demand(String(building.get("kind", "")))
	return demand

func _is_player_building_powered(building_index: int) -> bool:
	if building_index < 0 or building_index >= buildings.size():
		return false
	var target: Dictionary = buildings[building_index]
	if int(target.get("hp", 1)) <= 0 or float(target.get("build_progress", 1.0)) < 1.0:
		return false
	var target_demand := _power_demand(String(target.kind))
	if target_demand <= 0:
		return true
	var allocated := 0
	var target_priority := _power_priority(String(target.kind))
	for i in range(buildings.size()):
		if i == building_index:
			continue
		var other: Dictionary = buildings[i]
		if int(other.get("hp", 1)) <= 0 or float(other.get("build_progress", 1.0)) < 1.0:
			continue
		var other_priority := _power_priority(String(other.kind))
		if other_priority < target_priority or (other_priority == target_priority and i < building_index):
			allocated += _power_demand(String(other.kind))
	return _player_power_capacity() >= allocated + target_demand

func _has_building(kind: String) -> bool:
	for i in range(buildings.size()):
		if buildings[i].kind == kind and _is_player_building_powered(i):
			return true
	return false

func _team_unit_count(team: String) -> int:
	var count := 0
	for unit in units:
		if String(unit.get("team", "")) == team and int(unit.get("hp", 0)) > 0:
			count += 1
	return count


func _production_building_for(kind: String) -> String:
	if kind in ["infantry", "builder"]:
		return "barracks"
	if kind in ["tank", "artillery"]:
		return "factory"
	if kind in ["fighter", "helicopter", "transport_helicopter"]:
		return "airfield"
	if NAVAL_SYSTEM_ENABLED and kind in NAVAL_UNIT_KINDS:
		return "shipyard"
	return ""

func _production_duration(kind: String) -> float:
	match kind:
		"infantry": return 3.0
		"builder": return 8.0
		"tank": return 7.0
		"artillery": return 9.0
		"fighter": return 8.0
		"helicopter": return 10.0
		"transport_helicopter": return 14.0
		"destroyer": return 13.0
		"submarine": return 12.0
		"landing_craft": return 11.0
		"carrier": return 20.0
	return 6.0

func _enqueue_unit(kind: String) -> void:
	if not NAVAL_SYSTEM_ENABLED and kind in NAVAL_UNIT_KINDS:
		notice = "النظام البحري مؤجل — الإنتاج البري والجوي متاح حالياً"
		notice_time = 2.5
		return
	var producer_kind := _production_building_for(kind)
	var producer_pos := Vector2(-9999, -9999)
	var producer_id := -1
	var shortest_queue := 2147483647
	for i in range(buildings.size()):
		if String(buildings[i].get("kind", "")) != producer_kind or not _is_player_building_powered(i):
			continue
		if not buildings[i].has("production_id"):
			buildings[i]["production_id"] = next_building_production_id
			next_building_production_id += 1
		var candidate_id := int(buildings[i].production_id)
		var candidate_queue_size := 0
		for queued_order in production_orders:
			if int(queued_order.get("producer_id", -1)) == candidate_id:
				candidate_queue_size += 1
		# Spread new orders across equivalent buildings instead of overloading the first one.
		if candidate_queue_size < shortest_queue:
			shortest_queue = candidate_queue_size
			producer_pos = buildings[i].pos
			producer_id = candidate_id
	if producer_kind == "" or producer_pos.x < -9000.0:
		notice = "لا يوجد مبنى إنتاج مكتمل لهذه الوحدة"
		notice_time = 2.5
		return
	var reserved_units := production_orders.size()
	if _team_unit_count("player") + reserved_units >= MAX_TEAM_UNITS:
		notice = "لا توجد سعة كافية للقوات أو طوابير الإنتاج"
		notice_time = 2.5
		return
	var cost := _unit_cost(kind, faction)
	var supply_cost := _unit_supply_cost(kind)
	if supplies < supply_cost:
		notice = "الإمدادات غير كافية — سيطر على نقاط الإمداد"
		notice_time = 2.5
		return
	if credits < cost:
		notice = "لا توجد موارد كافية"
		notice_time = 2.0
		return
	credits -= cost
	supplies -= supply_cost
	production_orders.append({"producer_pos": producer_pos, "producer_kind": producer_kind, "producer_id": producer_id, "kind": kind, "remaining": _production_duration(kind), "duration": _production_duration(kind)})
	notice = "أضيفت الوحدة إلى طابور الإنتاج"
	notice_time = 2.0
	queue_redraw()

func _update_production_queues(delta: float) -> void:
	var active_producers: Array[Vector2] = []
	for i in range(production_orders.size()):
		var order: Dictionary = production_orders[i]
		var producer_pos: Vector2 = order.producer_pos
		if active_producers.has(producer_pos):
			continue
		active_producers.append(producer_pos)
		var producer_exists := false
		var producer_ready := false
		var expected_producer_kind := String(order.get("producer_kind", _production_building_for(String(order.get("kind", "")))))
		var expected_producer_id := int(order.get("producer_id", -1))
		for producer_index in range(buildings.size()):
			var candidate: Dictionary = buildings[producer_index]
			var matches_producer := false
			if expected_producer_id >= 0:
				matches_producer = int(candidate.get("production_id", -2)) == expected_producer_id
			else:
				# Compatibility for production orders created before producer IDs existed.
				matches_producer = String(candidate.get("kind", "")) == expected_producer_kind and candidate.pos.distance_to(producer_pos) < 2.0
			if matches_producer and String(candidate.get("kind", "")) == expected_producer_kind:
				producer_exists = true
				producer_ready = _is_player_building_powered(producer_index)
				break
		if not producer_exists:
			# A destroyed production building must not leave a paid order stuck forever.
			var cancelled_kind := String(order.get("kind", ""))
			var refund := int(floor(float(_unit_cost(cancelled_kind, faction)) * 0.75))
			credits = mini(MAX_CREDITS, credits + refund)
			supplies = mini(_player_supply_capacity(), supplies + _unit_supply_cost(cancelled_kind))
			production_orders.remove_at(i)
			notice = "دُمّر مبنى الإنتاج — أُلغي الطلب وأُعيد 75٪ من الموارد"
			notice_time = 2.5
			queue_redraw()
			return
		if not producer_ready:
			continue
		var producer_level := 1
		for producer_index in range(buildings.size()):
			var producer: Dictionary = buildings[producer_index]
			if int(producer.get("production_id", -2)) == expected_producer_id and expected_producer_id >= 0:
				producer_level = maxi(1, int(producer.get("level", 1)))
				break
		var production_speed := 1.0 + float(producer_level - 1) * 0.15
		order.remaining = maxf(0.0, float(order.remaining) - delta * production_speed)
		production_orders[i] = order
		if float(order.remaining) <= 0.0:
			if _team_unit_count("player") >= MAX_TEAM_UNITS:
				notice = "اكتمل الإنتاج — ينتظر الطابور توفر سعة للقوات"
				notice_time = 2.0
				continue
			var completed_kind := String(order.kind)
			var completed_producer_id := int(order.get("producer_id", -1))
			# Do not consume a completed order until a ground-unit exit is genuinely clear.
			if completed_kind not in ["fighter", "helicopter"] and completed_producer_id >= 0:
				var exit_is_clear := false
				for producer in buildings:
					if int(producer.get("production_id", -2)) == completed_producer_id and String(producer.get("kind", "")) == _production_building_for(completed_kind):
						exit_is_clear = _find_clear_ground_spawn(producer.pos, completed_kind, completed_producer_id).x >= 0.0
						break
				if not exit_is_clear:
					notice = "اكتمل الإنتاج — المخرج مزدحم، تنتظر الوحدة توفر ممر آمن"
					notice_time = 2.0
					continue
			production_orders.remove_at(i)
			_spawn_unit(completed_kind, true, completed_producer_id)
			if notice.begins_with("تم إنتاج"):
				notice = "اكتمل إنتاج الوحدة — أُضيفت إلى ساحة المعركة"
			queue_redraw()
			return

func _is_ground_spawn_position_clear(candidate: Vector2, unit_kind: String, producer_id: int, ignored_unit_index: int = -1) -> bool:
	var unit_radius := 13.0 if unit_kind in ["tank", "artillery"] else 10.0
	for building_side in [buildings, enemy_buildings]:
		for structure in building_side:
			if int(structure.get("hp", 0)) <= 0:
				continue
			var structure_kind := String(structure.get("kind", ""))
			var resolved := candidate
			if structure_kind == "wall":
				resolved = _fortification_resolve_segment(candidate, candidate, structure.pos + Vector2(-31.0, 0.0), structure.pos + Vector2(31.0, 0.0), unit_radius + 7.0)
			elif structure_kind == "wall_corner":
				resolved = _fortification_resolve_segment(candidate, candidate, structure.pos + Vector2(-31.0, 0.0), structure.pos + Vector2(10.0, 0.0), unit_radius + 7.0)
				if resolved.distance_to(candidate) <= 0.1:
					resolved = _fortification_resolve_segment(candidate, candidate, structure.pos + Vector2(10.0, 0.0), structure.pos + Vector2(10.0, 40.0), unit_radius + 7.0)
			elif structure_kind == "wall_gate":
				for gate_side in [-1.0, 1.0]:
					var pillar_center: Vector2 = structure.pos + Vector2(gate_side * 38.0, 0.0)
					resolved = _fortification_resolve_segment(resolved, candidate, pillar_center + Vector2(0.0, -17.0), pillar_center + Vector2(0.0, 17.0), unit_radius + 6.0)
			elif structure_kind in ["bunker", "turret", "anti_air", "missile_defense", "missile_silo"]:
				var defense_radius := 22.0 if structure_kind in ["bunker", "missile_silo"] else (19.0 if structure_kind == "missile_defense" else 16.0)
				resolved = _fortification_resolve_circle(candidate, candidate, structure.pos, unit_radius + defense_radius)
			elif structure_kind in ["command", "barracks", "factory", "power_plant", "supply_depot", "airfield"]:
				var building_radius := 39.0 if structure_kind == "airfield" else (27.0 if structure_kind == "command" else 24.0)
				resolved = _fortification_resolve_circle(candidate, candidate, structure.pos, unit_radius + building_radius)
			if resolved.distance_to(candidate) > 0.1:
				return false
	for existing_index in range(units.size()):
		if existing_index == ignored_unit_index:
			continue
		var existing: Dictionary = units[existing_index]
		if int(existing.get("hp", 0)) <= 0 or String(existing.get("kind", "")) in ["fighter", "helicopter", "destroyer", "carrier", "submarine", "landing_craft"]:
			continue
		var existing_radius := 13.0 if String(existing.get("kind", "")) in ["tank", "artillery"] else 9.0
		if candidate.distance_to(existing.pos) < unit_radius + existing_radius:
			return false
	return true


func _find_clear_ground_spawn(origin: Vector2, unit_kind: String, producer_id: int) -> Vector2:
	var unit_radius := 13.0 if unit_kind in ["tank", "artillery"] else 10.0
	# Expand the search in concentric rings so crowded bases can still find a safe exit.
	# A blocked exit returns a sentinel; the completed production order remains queued.
	var search_radii := [58.0, 76.0, 94.0, 112.0, 132.0, 152.0, 172.0, 192.0]
	for radius_value in search_radii:
		for direction_index in range(32):
			var angle := TAU * float(direction_index) / 32.0
			var candidate := origin + Vector2(cos(angle), sin(angle)) * (float(radius_value) + unit_radius * 0.15)
			if _is_ground_spawn_position_clear(candidate, unit_kind, producer_id):
				return candidate
	return Vector2(-1.0, -1.0)


func _ground_navigation_direction(unit: Dictionary, unit_index: int, destination: Vector2, delta: float, move_speed: float) -> Vector2:
	var to_destination: Vector2 = destination - unit.pos
	if to_destination.length_squared() <= 0.01:
		return Vector2.ZERO
	var forward: Vector2 = to_destination.normalized()
	var travel_distance := maxf(5.0, move_speed * delta)
	var direct_candidate: Vector2 = unit.pos + forward * travel_distance
	var kind := String(unit.get("kind", ""))
	if _is_ground_spawn_position_clear(direct_candidate, kind, -1, unit_index):
		return forward
	# A blocked direct step tries both shoulders; deterministic tie-breaking prevents jitter.
	var side := Vector2(-forward.y, forward.x)
	var side_offset := maxf(18.0, 13.0 if kind in ["tank", "artillery"] else 10.0)
	var best_direction := Vector2.ZERO
	var best_distance := INF
	for side_sign in [1.0, -1.0]:
		var candidate: Vector2 = unit.pos + forward * (travel_distance * 0.55) + side * side_offset * side_sign
		if not _is_ground_spawn_position_clear(candidate, kind, -1, unit_index):
			continue
		var remaining_distance: float = candidate.distance_to(destination)
		if remaining_distance < best_distance:
			best_distance = remaining_distance
			best_direction = (candidate - unit.pos).normalized()
	if best_direction != Vector2.ZERO:
		return best_direction
	# If both shoulders are blocked, hold position rather than repeatedly pushing into a wall.
	return Vector2.ZERO


func _spawn_unit(kind: String, already_paid: bool = false, producer_id: int = -1) -> void:
	if not NAVAL_SYSTEM_ENABLED and kind in NAVAL_UNIT_KINDS:
		notice = "الوحدات البحرية مؤجلة عن النسخة الحالية"
		notice_time = 2.5
		return
	if _team_unit_count("player") >= MAX_TEAM_UNITS:
		notice = "وصلت إلى الحد الأقصى للقوات (%d)" % MAX_TEAM_UNITS
		notice_time = 2.5
		return
	if kind in ["destroyer", "carrier", "submarine", "landing_craft"] and not _has_building("shipyard"):
		notice = "ابنِ حوض سفن أولاً لإنتاج المدمرة"
		notice_time = 2.5
		return
	if kind == "artillery" and not _has_building("factory"):
		notice = "ابنِ مصنعاً أولاً لإنتاج المدفعية"
		notice_time = 2.5
		return
	if kind in ["fighter", "helicopter", "transport_helicopter"] and not _has_building("airfield"):
		notice = "ابنِ مطاراً أولاً لإنتاج المقاتلات والمروحيات وطائرات النقل"
		notice_time = 2.5
		return
	if kind == "infantry" and not _has_building("barracks"):
		notice = "ابنِ ثكنة أولاً لإنتاج المشاة"
		notice_time = 2.5
		return
	if kind == "tank" and not _has_building("factory"):
		notice = "ابنِ مصنعاً أولاً لإنتاج الدبابات"
		notice_time = 2.5
		return
	if not already_paid:
		var cost := _unit_cost(kind, faction)
		var supply_cost := _unit_supply_cost(kind)
		if supplies < supply_cost:
			notice = "الإمدادات غير كافية — سيطر على نقاط الإمداد"
			notice_time = 2.5
			return
		if credits < cost:
			notice = "لا توجد موارد كافية"
			notice_time = 2.0
			return
		credits -= cost
		supplies -= supply_cost
	var unit_spawn := base_pos + Vector2(65, randf_range(-35, 35))
	# Search around the exact producer for a free exit lane, respecting walls, buildings, and units.
	if kind not in ["fighter", "helicopter", "transport_helicopter"] and producer_id >= 0:
		for producer in buildings:
			if int(producer.get("production_id", -2)) == producer_id and String(producer.get("kind", "")) == _production_building_for(kind):
				unit_spawn = _find_clear_ground_spawn(producer.pos, kind, producer_id)
				break
	var aircraft_launch := false
	var aircraft_airfield_id := -1
	var aircraft_launch_slot := 0
	if kind in ["fighter", "helicopter", "transport_helicopter"]:
		# Stagger aircraft along the runway so consecutive production never stacks proxies.
		for airfield_index in range(buildings.size()):
			var airfield: Dictionary = buildings[airfield_index]
			var matches_producer := producer_id < 0 or int(airfield.get("production_id", -2)) == producer_id
			if matches_producer and String(airfield.get("kind", "")) == "airfield" and float(airfield.get("build_progress", 1.0)) >= 1.0 and int(airfield.get("hp", 0)) > 0 and _is_player_building_powered(airfield_index):
				aircraft_airfield_id = int(airfield.get("production_id", -1))
				for existing_aircraft in units:
					if String(existing_aircraft.get("team", "")) == "player" and String(existing_aircraft.get("kind", "")) in ["fighter", "helicopter", "transport_helicopter"] and int(existing_aircraft.get("airfield_launch_id", -2)) == aircraft_airfield_id:
						aircraft_launch_slot += 1
				var runway_column := aircraft_launch_slot % 3 - 1
				var runway_row := int(aircraft_launch_slot / 3)
				unit_spawn = airfield.pos + Vector2(float(runway_column) * 22.0, 34.0 + float(runway_row) * 18.0)
				aircraft_launch = true
				break
	if _is_naval_kind(kind):
		for dock in buildings:
			if dock.kind == "shipyard":
				unit_spawn = dock.pos
				break
	var naval_hp := 520 if kind == "carrier" else (210 if kind == "submarine" else (220 if kind == "landing_craft" else 260))
	var unit_hp := naval_hp if kind in ["carrier", "submarine", "landing_craft", "destroyer"] else (250 if kind == "transport_helicopter" else (220 if kind == "builder" else (180 if kind == "helicopter" else (120 if kind == "fighter" else (150 if kind == "tank" else 100)))))
	var spawned_unit: Dictionary = {"pos": unit_spawn, "team": "player", "kind": kind, "faction": faction, "hp": unit_hp, "attack_cd": 0.0, "launch_cd": 16.0, "combat_xp": 0.0, "veterancy": 0, "combat_kills": 0, "air_kills": 0, "armor_kills": 0, "naval_kills": 0, "combat_medals": [], "facing": 0.0, "turret_facing": 0.0}
	if kind in ["fighter", "helicopter"]:
		spawned_unit["aircraft_ammo"] = 8 if kind == "fighter" else 12
	if aircraft_launch:
		spawned_unit["airfield_launch"] = true
		spawned_unit["airfield_launch_id"] = aircraft_airfield_id
		spawned_unit["airfield_launch_slot"] = aircraft_launch_slot
	if kind == "landing_craft":
		spawned_unit["home_pos"] = unit_spawn
		spawned_unit["landing_state"] = "outbound"
		spawned_unit["passengers"] = 3
		spawned_unit["landing_timer"] = 0.0
	units.append(spawned_unit)
	var unit_name := "مدفعية"
	if kind == "carrier":
		unit_name = "حاملة طائرات"
	elif kind == "submarine":
		unit_name = "غواصة"
	elif kind == "landing_craft":
		unit_name = "سفينة إنزال"
	elif kind == "destroyer":
		unit_name = "مدمرة بحرية"
	elif kind == "infantry":
		unit_name = "جندي"
	elif kind == "builder":
		unit_name = "مركبة بناء"
	elif kind == "tank":
		unit_name = "دبابة"
	elif kind == "helicopter":
		unit_name = "مروحية قتالية"
	elif kind == "transport_helicopter":
		unit_name = "مروحية نقل وإنزال"
	elif kind == "fighter":
		unit_name = "مقاتلة"
	notice = "تم إنتاج %s" % unit_name
	notice_time = 2.0
