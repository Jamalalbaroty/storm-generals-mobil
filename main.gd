extends Node2D

const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const MAP_TYPES := ["الساحل الصحراوي", "ساحل الغابات", "الساحل الجبلي", "المدينة الساحلية"]
const COMMAND_TAB_LABELS := ["البرية", "الجوية", "الاستراتيجية", "البحرية"]
const COMMAND_ACTIONS := [
	[0, 1, 2, 3, 4, 5],
	[6, 7, 8, 9, 21, 22],
	[10, 11, 12, 13, 14, 15],
	[16, 17, 18, 19, 20, 12]
]
const INFANTRY_COST := 100
const TANK_COST := 300
const STARTING_CREDITS := 1200
const MAX_TEAM_UNITS := 40
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
		"missile_defense": MISSILE_DEFENSE_COST, "shipyard": 700, "power_plant": 450
	},
	"unit_costs": {
		"infantry": INFANTRY_COST, "tank": TANK_COST, "builder": 600, "artillery": ARTILLERY_COST,
		"fighter": FIGHTER_COST, "destroyer": 900, "carrier": 1600,
		"submarine": 1100, "landing_craft": 800
	},
	"unit_supplies": {
		"infantry": 0, "tank": 1, "builder": 0, "artillery": 2, "fighter": 2,
		"helicopter": 3, "destroyer": 4, "landing_craft": 4,
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
var paused := false
var dragging := false
var active_touch_index := -1
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var base_pos := Vector2(180, 330)
var enemy_base := Vector2(1090, 330)
var player_base_hp := 1000
var enemy_base_hp := 1000
var battle_result := ""
var visual_effects: Array[Dictionary] = []
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

func _ready() -> void:
	randomize()
	_setup_battle_audio()
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


const BATTLEFIELD_3D_SCENE: PackedScene = preload("res://prototype_3d/battlefield_3d.tscn")
var battlefield_3d: Node3D
var battlefield_sync_timer := 0.0
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
	if order_type == "move":
		var map_size := get_viewport_rect().size
		var world_limit := 42.0 * 0.38
		var nx := clampf((world_position.x + world_limit) / (world_limit * 2.0), 0.0, 1.0)
		var ny := clampf((world_position.z + world_limit) / (world_limit * 2.0), 0.0, 1.0)
		source_unit["target"] = Vector2(nx * map_size.x, ny * map_size.y)
		source_unit.erase("attack_target")
		source_unit.erase("attack_focus_pos")
		source_unit.erase("attack_base")
		source_unit.erase("attack_building")
		notice = "أمر حركة صادر من القيادة ثلاثية الأبعاد"
		notice_time = 1.6
	elif order_type == "attack":
		var target_parts := target_key.split("|")
		if target_parts.size() < 3 or target_parts[0] != "enemy":
			return
		var target_id := int(target_parts[1])
		var target_index := -1
		for index in range(units.size()):
			if units[index].team == "enemy" and int(units[index].get("3d_sync_id", -1)) == target_id and int(units[index].get("hp", 0)) > 0:
				target_index = index
				break
		if target_index < 0:
			return
		source_unit["attack_target"] = target_index
		source_unit["attack_focus_pos"] = units[target_index].pos
		source_unit.erase("target")
		source_unit.erase("attack_base")
		source_unit.erase("attack_building")
		notice = "أمر اشتباك صادر من القيادة ثلاثية الأبعاد"
		notice_time = 1.6
	queue_redraw()


func _sync_3d_gameplay_bridge() -> void:
	if not is_instance_valid(battlefield_3d) or not game_started:
		return
	var map_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	battlefield_3d.call("sync_game_units", units, map_rect)
	var enemy_faction_id := _enemy_faction()
	battlefield_3d.call("sync_game_buildings", buildings, enemy_buildings, map_rect, faction, enemy_faction_id)


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
			visual_effects.remove_at(effect_index)
	_update_environment_particles(delta)
	if game_started:
		if battle_result != "":
			return
		income_timer += delta
		if income_timer >= 1.0:
			credits = mini(MAX_CREDITS, credits + int(PASSIVE_INCOME * income_timer))
			income_timer = fmod(income_timer, 1.0)
		_update_supply_control(delta)
		_update_building_construction(delta)
		_update_production_queues(delta)
		_update_enemy_building_construction(delta)
		_update_building_capture(delta)
		_update_submarine_detection()
		_update_missiles(delta)
		_update_combat_alerts()
		if _resolve_battle_result():
			return
		enemy_income_timer += delta
		if enemy_income_timer >= 1.0:
			enemy_credits = mini(MAX_CREDITS, enemy_credits + int(PASSIVE_INCOME * enemy_income_timer))
			enemy_income_timer = fmod(enemy_income_timer, 1.0)
		enemy_timer += delta
		if enemy_timer >= 12.0:
			enemy_timer = 0.0
			_enemy_ai_turn()
			_update_enemy_defense_assignments()
		for defense_index in range(buildings.size()):
			var building: Dictionary = buildings[defense_index]
			if (building.kind == "turret" or building.kind == "anti_air") and _is_player_building_powered(defense_index):
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var target := _nearest_enemy_unit(building.pos, 320.0 if building.kind == "anti_air" else 230.0, building.kind == "anti_air")
				if target >= 0 and building.attack_cd <= 0.0:
					units[target].hp = maxi(0, int(units[target].hp) - _terrain_adjusted_damage(units[target], 34 if building.kind == "anti_air" else 18))
					_add_visual_effect("tracer", building.pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ffd27a"), 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ffb34d"), 0.22, 13.0)
					building.attack_cd = 0.65 if building.kind == "anti_air" else 0.8
		for defense_index in range(enemy_buildings.size()):
			var building: Dictionary = enemy_buildings[defense_index]
			if not _is_enemy_building_powered(defense_index):
				continue
			if building.kind == "turret" or building.kind == "anti_air":
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var target := _nearest_player_unit(building.pos, building.kind == "anti_air")
				var max_range := 320.0 if building.kind == "anti_air" else 230.0
				if target >= 0 and building.pos.distance_to(units[target].pos) <= max_range and building.attack_cd <= 0.0:
					units[target].hp = maxi(0, int(units[target].hp) - _terrain_adjusted_damage(units[target], 34 if building.kind == "anti_air" else 16))
					_add_visual_effect("tracer", building.pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ff8b72"), 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ff704d"), 0.22, 12.0)
					building.attack_cd = 0.65 if building.kind == "anti_air" else 0.9
		var enemy_ground_focus := _select_enemy_ground_assault_target()
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
					var heli_target = _nearest_unit_by_priority(unit.pos, 99999.0, "player", ["tank", "artillery", "infantry"])
					var heli_destination: Vector2 = base_pos if heli_target < 0 else units[heli_target].pos
					if unit.pos.distance_to(heli_destination) <= 235.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							_add_visual_effect("tracer", unit.pos, heli_destination, Color("#ffb56e"), 0.2, 0.0)
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
				if unit.kind == "fighter":
					var air_target = _landing_craft_air_threat_target(unit.pos, "enemy")
					if air_target < 0:
						air_target = _nearest_unit_by_priority(unit.pos, FIGHTER_TARGET_RANGE, "player", ["fighter", "helicopter"])
					if air_target >= 0:
						var air_enemy: Dictionary = units[air_target]
						if unit.pos.distance_to(air_enemy.pos) <= FIGHTER_ATTACK_RANGE:
							unit.attack_cd = unit.get("attack_cd", 0.0) - delta
							if unit.attack_cd <= 0.0:
								_add_visual_effect("tracer", unit.pos, air_enemy.pos, Color("#ff9b72"), 0.18, 0.0)
								_add_visual_effect("explosion", air_enemy.pos, air_enemy.pos, Color("#ffad72"), 0.42, 24.0)
								air_enemy.hp = maxi(0, int(air_enemy.hp) - _terrain_adjusted_damage(air_enemy, FIGHTER_DAMAGE))
								unit.attack_cd = FIGHTER_ATTACK_COOLDOWN
						else:
							unit.pos += (air_enemy.pos - unit.pos).normalized() * delta * FIGHTER_SPEED
					else:
						unit.pos += (enemy_base - unit.pos).normalized() * delta * FIGHTER_PATROL_SPEED
					continue
				if unit.kind == "tank" or unit.kind == "artillery":
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
						unit.pos += (target_building.pos - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else 38.0)
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
						unit.pos += (enemy_base - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
					continue
				var enemy_target := int(unit.get("attack_target", -1))
				if enemy_target < 0 or enemy_target >= units.size() or units[enemy_target].team != "enemy" or units[enemy_target].get("hp", 0) <= 0 or (units[enemy_target].kind == "submarine" and not _is_submarine_detected(units[enemy_target], "player")):
					if unit.has("attack_focus_pos"):
						enemy_target = _nearest_enemy_to_focus(unit.attack_focus_pos, 300.0)
					if enemy_target < 0:
						enemy_target = _nearest_enemy_unit(unit.pos, 420.0 if unit.kind == "artillery" else 220.0)
					if enemy_target >= 0:
						unit.attack_target = enemy_target
				if enemy_target >= 0:
					unit.attack_focus_pos = units[enemy_target].pos
					var enemy: Dictionary = units[enemy_target]
					var distance: float = unit.pos.distance_to(enemy.pos)
					var attack_range := 360.0 if unit.kind == "artillery" else 160.0
					if distance <= attack_range:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							if unit.kind == "artillery":
								_add_visual_effect("explosion", enemy.pos, enemy.pos, Color("#ffb45e"), 0.72, 66.0)
								_apply_splash_damage(enemy.pos, 58.0, _unit_damage_with_veterancy(unit, 45), "enemy", unit)
								unit.attack_cd = 2.4
							else:
								var enemy_hp_before := int(enemy.hp)
								enemy.hp = maxi(0, enemy_hp_before - _terrain_adjusted_damage(enemy, _unit_damage_with_veterancy(unit, 20 if unit.kind == "tank" else 10)))
								_award_unit_experience(unit, enemy_hp_before - int(enemy.hp))
								_register_unit_kill(unit, enemy, enemy_hp_before)
								_add_visual_effect("tracer", unit.pos, enemy.pos, Color("#ffe0a0"), 0.14, 0.0)
								_add_visual_effect("flash", enemy.pos, enemy.pos, Color("#ffb34d"), 0.18, 8.0)
								unit.attack_cd = 0.75 if unit.kind == "tank" else 1.0
					else:
						unit.pos += (enemy.pos - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
				elif unit.has("target"):
					var target: Vector2 = unit.target
					if unit.pos.distance_to(target) > 8.0:
						unit.pos += (target - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
		_cleanup_destroyed_units()
		_resolve_battle_result()
		_update_unit_facing(delta)
		queue_redraw()


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
		"kind": kind,
		"start": start,
		"finish": finish,
		"color": tint,
		"life": duration,
		"duration": duration,
		"radius": radius
	})
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

func _unit_damage_with_veterancy(unit: Dictionary, base_damage: int) -> int:
	var rank := int(unit.get("veterancy", 0))
	var multiplier := 1.0 + (0.08 if rank == 1 else (0.15 if rank >= 2 else 0.0))
	return maxi(1, roundi(float(base_damage) * multiplier))


func _register_unit_kill(attacker: Dictionary, target: Dictionary, target_hp_before: int) -> void:
	if String(attacker.get("team", "")) != "player" or target_hp_before <= 0 or int(target.get("hp", 0)) > 0:
		return
	var kills := int(attacker.get("combat_kills", 0)) + 1
	attacker["combat_kills"] = kills
	var target_kind := String(target.get("kind", ""))
	var air_kills := int(attacker.get("air_kills", 0))
	var armor_kills := int(attacker.get("armor_kills", 0))
	var naval_kills := int(attacker.get("naval_kills", 0))
	if target_kind in ["fighter", "helicopter"]:
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
		notice = "وسام جديد: %s" % earned
		notice_time = 3.0


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
	# Infantry use natural cover in forest, mountain and dense urban theaters.
	var kind := String(target.get("kind", ""))
	if kind == "infantry":
		if map_type == "ساحل الغابات":
			return maxi(1, roundi(raw_damage * 0.72))
		if map_type == "الساحل الجبلي":
			return maxi(1, roundi(raw_damage * 0.80))
		if map_type == "المدينة الساحلية":
			return maxi(1, roundi(raw_damage * 0.76))
	return raw_damage

func _terrain_effect_label() -> String:
	match map_type:
		"ساحل الغابات":
			return "غطاء الغابات: حماية المشاة 28%"
		"الساحل الجبلي":
			return "المرتفعات: حماية المشاة 20%"
		"المدينة الساحلية":
			return "المباني: حماية المشاة 24%"
		_:
			return "الصحراء: لا يوجد غطاء طبيعي"

func _apply_splash_damage(center: Vector2, radius: float, damage: int, target_team: String, attacker: Dictionary = {}) -> void:
	for unit in units:
		if unit.team == target_team and unit.get("hp", 0) > 0 and unit.pos.distance_to(center) <= radius:
			var hp_before := int(unit.hp)
			unit.hp = maxi(0, hp_before - _terrain_adjusted_damage(unit, damage))
			if not attacker.is_empty():
				_award_unit_experience(attacker, hp_before - int(unit.hp))
				_register_unit_kill(attacker, unit, hp_before)

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
			if threat.kind not in ["fighter", "helicopter"]:
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
		role_offset = attack_direction * 58.0
	elif unit_kind == "infantry":
		role_offset = -attack_direction * 22.0
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
			"barracks", "factory":
				priority = 5
			"airfield":
				priority = 4
			"shipyard", "missile_silo":
				priority = 3
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
		var score: float = asset_distance * 0.35 + from_pos.distance_to(candidate.pos) * 0.85 - threat_priority
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


func _nearest_player_unit(from_pos: Vector2, air_only: bool = false) -> int:
	var best_index = -1
	var best_distance := INF
	for i in units.size():
		if units[i].team != "player" or units[i].get("hp", 0) <= 0:
			continue
		if units[i].kind == "submarine" and not _is_submarine_detected(units[i], "enemy"):
			continue
		if air_only and units[i].kind != "fighter" and units[i].kind != "helicopter":
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


func _nearest_enemy_unit(from_pos: Vector2, max_distance: float, air_only: bool = false) -> int:
	var best_index = -1
	var best_distance := max_distance
	for i in units.size():
		if units[i].team != "enemy" or units[i].get("hp", 0) <= 0:
			continue
		if units[i].kind == "submarine" and not _is_submarine_detected(units[i], "player"):
			continue
		if air_only and units[i].kind != "fighter" and units[i].kind != "helicopter":
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


func _update_unit_facing(delta: float) -> void:
	for unit in units:
		var current_pos: Vector2 = unit.pos
		var previous_pos: Vector2 = unit.get("visual_previous_pos", current_pos)
		var movement := current_pos - previous_pos
		if movement.length_squared() > 4.0:
			var desired_angle = movement.angle()
			var current_angle := float(unit.get("facing", desired_angle))
			unit.facing = lerp_angle(current_angle, desired_angle, clampf(delta * 9.0, 0.0, 1.0))
		unit.visual_previous_pos = current_pos


func _draw() -> void:
	var size = get_viewport_rect().size
	if game_started and use_3d_view:
		_draw_3d_view_hud(size)
		return
	_draw_terrain(size)
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
		_draw_building_health(building.pos, int(building.get("hp", 400)), _building_max_hp(building))
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
		elif u.kind == "helicopter":
			var heli_color = _helicopter_color(u)
			var heli_angle := _unit_facing_angle(u)
			draw_circle(_unit_rotated_point(u.pos, Vector2(0, 4), heli_angle), 13, Color(0, 0, 0, 0.22))
			draw_circle(u.pos, 10, Color("#263238"))
			draw_circle(_unit_rotated_point(u.pos, Vector2(1, -2), heli_angle), 8, heli_color)
			draw_colored_polygon(_unit_polygon_points(u.pos, PackedVector2Array([Vector2(8, -4), Vector2(30, -1), Vector2(9, 4)]), heli_angle), heli_color)
			draw_line(_unit_rotated_point(u.pos, Vector2(-19, -14), heli_angle), _unit_rotated_point(u.pos, Vector2(18, -14), heli_angle), Color("#252b2b"), 4)
			draw_line(_unit_rotated_point(u.pos, Vector2(0, -14), heli_angle), _unit_rotated_point(u.pos, Vector2(0, -23), heli_angle), Color("#252b2b"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(-14, -23), heli_angle), _unit_rotated_point(u.pos, Vector2(14, -23), heli_angle), Color("#252b2b"), 2)
			draw_circle(_unit_rotated_point(u.pos, Vector2(0, -14), heli_angle), 3, Color("#c7d0cd"))
			draw_line(_unit_rotated_point(u.pos, Vector2(-5, 8), heli_angle), _unit_rotated_point(u.pos, Vector2(9, 12), heli_angle), Color("#252b2b"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(-11, 4), heli_angle), _unit_rotated_point(u.pos, Vector2(-22, 10), heli_angle), Color("#343b3b"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(3, 7), heli_angle), _unit_rotated_point(u.pos, Vector2(14, 12), heli_angle), Color("#343b3b"), 2)
			draw_circle(_unit_rotated_point(u.pos, Vector2(5, -3), heli_angle), 3, Color("#9ed5df"))
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
			var tank_aim := _unit_weapon_angle(u)
			var turret_center := _unit_rotated_point(u.pos, Vector2(1, 0), facing)
			draw_circle(turret_center, 7, Color("#7f927f"))
			draw_line(_unit_rotated_point(turret_center, Vector2(3, 0), tank_aim), _unit_rotated_point(turret_center, Vector2(28, 0), tank_aim), Color("#252c2c"), 5)
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
		var max_hp := 520.0 if u.kind == "carrier" else (260.0 if u.kind == "destroyer" else (220.0 if u.kind == "builder" or u.kind == "landing_craft" else (210.0 if u.kind == "submarine" else (180.0 if u.kind == "helicopter" else (120.0 if u.kind == "fighter" else (150.0 if u.kind == "tank" else (100.0 if u.kind == "artillery" or u.team == "player" else 60.0)))))))
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
		if effect.kind == "tracer":
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
		draw_rect(Rect2(drag_start, drag_end - drag_start), Color(0.3, 0.8, 1, 0.13), true)
		draw_rect(Rect2(drag_start, drag_end - drag_start), Color("#9fe7ff"), false, 2)
	if not game_started:
		_draw_faction_picker(size)
	elif battle_result != "":
		draw_rect(Rect2(size.x * 0.2, size.y * 0.34, size.x * 0.6, size.y * 0.25), Color(0.02, 0.03, 0.04, 0.94))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.25, size.y * 0.47), battle_result, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.5, 30, Color("#f4d77a"))
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
	return Rect2(Vector2(size.x * 0.4, size.y * 0.53), Vector2(size.x * 0.2, 48))

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
	# Compact mobile command deck: resources, grid power, threat state and production.
	draw_rect(Rect2(0, 0, size.x, 58), Color(0.035, 0.055, 0.065, 0.96))
	draw_line(Vector2(0, 58), Vector2(size.x, 58), Color("#71858a"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(14, 36), "STORM GENERALS", HORIZONTAL_ALIGNMENT_LEFT, minf(210.0, size.x * 0.48), 19, Color("#f4d77a"))
	if not game_started:
		return
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
		draw_rect(metric_rect, Color("#17272d"), true)
		draw_rect(metric_rect, Color("#425b62"), false, 1.0)
	var metric_values := [
		{"label": "الموارد", "value": str(credits), "color": Color("#f2d47b")},
		{"label": "الإمداد", "value": str(supplies), "color": Color("#9fe6d2")},
		{"label": "الطاقة", "value": "%d / %d" % [power_demand, power_capacity], "color": Color("#ff9c82") if power_demand > power_capacity else Color("#a8e6b0")},
		{"label": "التهديد", "value": "خطر %d" % nearby_threats if nearby_threats > 0 else "آمن %d" % hostile_count, "color": Color("#ff766b") if nearby_threats > 0 else Color("#a8e6b0")}
	]
	for metric_index in range(metric_values.size()):
		var metric_rect := Rect2(Vector2(margin + metric_index * (metric_width + gap), metric_y), Vector2(metric_width, metric_h))
		var metric: Dictionary = metric_values[metric_index]
		draw_string(ThemeDB.fallback_font, metric_rect.position + Vector2(5, 15), String(metric.label), HORIZONTAL_ALIGNMENT_LEFT, metric_width - 10, 11, Color("#b6c7c8"))
		draw_string(ThemeDB.fallback_font, metric_rect.position + Vector2(5, 34), String(metric.value), HORIZONTAL_ALIGNMENT_LEFT, metric_width - 10, 14, metric.color)
	var theatre_text := "%s  |  %s" % [map_type, _terrain_effect_label()]
	draw_string(ThemeDB.fallback_font, Vector2(12, 126), theatre_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, Color("#d8e6c2"))
	var power_state := "شبكة الطاقة مستقرة" if power_demand <= power_capacity else "تحذير: عجز الطاقة — بعض المنشآت متوقفة"
	draw_string(ThemeDB.fallback_font, Vector2(12, 145), power_state, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, Color("#a8e6b0") if power_demand <= power_capacity else Color("#ff9c82"))
	# Production panel remains visible even when the queue is empty.
	var production_rect := Rect2(Vector2(10, 154), Vector2(size.x - 20, 43))
	draw_rect(production_rect, Color(0.035, 0.055, 0.065, 0.86), true)
	draw_rect(production_rect, Color("#425b62"), false, 1.0)
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
		var kind_labels := {"infantry": "المشاة", "tank": "الدبابة", "builder": "مركبة البناء", "artillery": "المدفعية", "fighter": "المقاتلة", "helicopter": "المروحية", "destroyer": "المدمرة", "submarine": "الغواصة", "carrier": "حاملة الطائرات", "landing_craft": "سفينة الإنزال"}
		var dossier_name := String(kind_labels.get(String(selected_player_units[0].get("kind", "")), "الوحدة"))
		for selected_unit in selected_player_units:
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
		var unit_label := dossier_name if selected_player_units.size() == 1 else "%d وحدات محددة" % selected_player_units.size()
		draw_string(ThemeDB.fallback_font, dossier.position + Vector2(8, 16), "%s | %s | خبرة %.0f | قتلى %d | أوسمة %d" % [unit_label, rank_label, average_xp, total_kills, total_medals], HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 12, Color("#f2e8ca"))
		var xp_bar := Rect2(dossier.position + Vector2(8, 26), Vector2(size.x - 36, 9))
		draw_rect(xp_bar, Color("#293b40"), true)
		var xp_color := Color("#d8b75e") if highest_rank == 1 else (Color("#83d9f4") if highest_rank >= 2 else Color("#8bd5a0"))
		draw_rect(Rect2(xp_bar.position, Vector2(xp_bar.size.x * progress, xp_bar.size.y)), xp_color, true)
		var progress_label := "أقصى رتبة" if elite_count == selected_player_units.size() else ("تقدم المجموعة نحو الترقية" if selected_player_units.size() > 1 else ("الحد التالي: 250 خبرة" if highest_rank == 1 else "الحد التالي: 100 خبرة"))
		draw_string(ThemeDB.fallback_font, dossier.position + Vector2(8, 44), progress_label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 9, Color("#b9c9c8"))
	var labels = ["مشاة 100", "دبابة 300", "ثكنة 250", "مصنع 450", "دفاع 350", "مدفعية 450", "مطار 600", "مقاتلة 500", "مضاد جو 400", "مروحية 650", "سيطرة مبنى", "تدمير مبنى", "إلغاء", "منصة صواريخ 800", "دفاع صاروخي 700", "إطلاق صاروخ %d" % _missile_cost(faction), "حوض سفن 700", "مدمرة 900", "حاملة 1600", "غواصة 1100", "إنزال 800", "مركبة بناء 600", "محطة طاقة 450"]
	if _has_selected_player_building():
		labels[10] = "إصلاح المنشأة"
		labels[11] = "بيع المنشأة"
		labels[12] = "ترقية L%d" % int(buildings[selected_player_building].get("level", 1)) if int(buildings[selected_player_building].get("level", 1)) < 3 else "أقصى تطوير"
	elif build_mode != "":
		labels[12] = "إلغاء البناء"
	else:
		labels[12] = "ترقية / إلغاء"
	for tab_index in range(COMMAND_TAB_LABELS.size()):
		var tab_rect := _command_tab_rect(tab_index, size)
		draw_rect(tab_rect, Color("#73552d") if tab_index == command_tab else Color("#172a35"), true)
		draw_rect(tab_rect, Color("#f4d77a") if tab_index == command_tab else Color("#58717b"), false, 1.5)
		draw_string(ThemeDB.fallback_font, tab_rect.position + Vector2(0, 23), COMMAND_TAB_LABELS[tab_index], HORIZONTAL_ALIGNMENT_CENTER, tab_rect.size.x, 15, Color.WHITE)
	var visible_actions: Array = _command_action_ids()
	for slot in range(visible_actions.size()):
		var action_id := int(visible_actions[slot])
		var r := _button_rect(slot, size)
		draw_rect(r, Color("#263d50"), true)
		draw_rect(r, Color("#8fa8b8"), false, 2)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(2, 30), labels[action_id], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4, 15, Color.WHITE)
	var pause_button := _pause_rect(size)
	draw_rect(pause_button, Color("#73552d") if paused else Color("#263d50"), true)
	draw_rect(pause_button, Color("#f4d77a") if paused else Color("#8fa8b8"), false, 2)
	draw_string(ThemeDB.fallback_font, pause_button.position + Vector2(0, 30), "استئناف" if paused else "إيقاف", HORIZONTAL_ALIGNMENT_CENTER, pause_button.size.x, 17, Color.WHITE)
	var view_button := _three_d_view_toggle_rect(size)
	draw_rect(view_button, Color("#284b43"), true)
	draw_rect(view_button, Color("#8bd5a0"), false, 2.0)
	draw_string(ThemeDB.fallback_font, view_button.position + Vector2(0, 30), "عرض 3D", HORIZONTAL_ALIGNMENT_CENTER, view_button.size.x, 16, Color.WHITE)

func _command_action_ids() -> Array:
	return COMMAND_ACTIONS[clampi(command_tab, 0, COMMAND_ACTIONS.size() - 1)]


func _command_tab_rect(index: int, size: Vector2) -> Rect2:
	var tab_width := (size.x - 44.0) / float(COMMAND_TAB_LABELS.size())
	return Rect2(Vector2(8.0 + float(index) * (tab_width + 4.0), size.y - 166.0), Vector2(tab_width, 32.0))


func _button_rect(index: int, size: Vector2) -> Rect2:
	var column := index % 3
	var row := int(index / 3)
	var button_width := (size.x - 40.0) / 3.0
	return Rect2(Vector2(8.0 + column * (button_width + 8.0), size.y - 126.0 + row * 54.0), Vector2(button_width, 48.0))

func _draw_faction_picker(size: Vector2) -> void:
	# A two-column grid keeps all four armies reachable on both portrait and landscape phones.
	var panel := Rect2(size.x * 0.06, size.y * 0.18, size.x * 0.88, size.y * 0.64)
	draw_rect(panel, Color(0.04, 0.07, 0.08, 0.96), true)
	draw_rect(panel, Color("#52666c"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 12.0, size.y * 0.30), "عاصفة الجنرالات", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 24.0, clampi(int(size.x * 0.03), 24, 38), Color("#f4d77a"))
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 12.0, size.y * 0.37), "اختر الجيش الذي ستقوده", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 24.0, clampi(int(size.x * 0.019), 16, 22), Color.WHITE)
	for i in FACTIONS.size():
		var r := _faction_rect(i, size)
		draw_rect(r, Color("#28445a") if i != 3 else Color("#73552d"), true)
		draw_rect(r, Color("#b7c6d1"), false, 2.0)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0.0, r.size.y * 0.59), FACTIONS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, clampi(int(size.x * 0.018), 14, 22), Color.WHITE)

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

func _handle_pointer(pos: Vector2, pressed: bool) -> void:
	var size = get_viewport_rect().size
	if pressed:
		dragging = true
		drag_start = pos
		drag_end = pos
		return
	if not dragging:
		return
	dragging = false
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
		for i in FACTIONS.size():
			if _faction_rect(i, size).has_point(pos):
				faction = FACTIONS[i]
				command_tab = 0
				map_type = MAP_TYPES[randi_range(0, MAP_TYPES.size() - 1)]
				battle_result = ""
				credits = STARTING_CREDITS
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
				game_started = true
				units.append({"pos": base_pos + Vector2(58, 0), "team": "player", "kind": "builder", "faction": faction, "hp": 220, "attack_cd": 0.0})
				notice = "بدأت المعركة — مركبة البناء جاهزة. حددها وابدأ إنشاء قاعدتك"
				notice_time = 3.0
				queue_redraw()
				return
		return
	for tab_index in range(COMMAND_TAB_LABELS.size()):
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
	if drag_start.distance_to(pos) > 24.0:
		selected_enemy_building = -1
		selected_player_building = -1
		selected.clear()
		var area := Rect2(drag_start, pos - drag_start).abs()
		for i in units.size():
			if units[i].team == "player" and area.has_point(units[i].pos):
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
					units[idx].attack_base = true
					units[idx].erase("attack_target")
			notice = "هجوم على قاعدة العدو!"
			notice_time = 1.5
		elif enemy_found >= 0 and not selected.is_empty():
			for idx in selected:
				if idx < units.size() and units[idx].team == "player":
					units[idx].attack_target = enemy_found
					units[idx].attack_focus_pos = units[enemy_found].pos
					units[idx].erase("attack_base")
			notice = "أمر هجوم!"
			notice_time = 1.5
		else:
			var found = -1
			for i in units.size():
				if units[i].team == "player" and units[i].get("hp", 0) > 0 and units[i].pos.distance_to(pos) < 24:
					found = i
					break
			if found >= 0:
				if not selected.has(found):
					selected = [found]
			else:
				for idx in selected:
					if idx < units.size():
						units[idx].target = pos
						units[idx].erase("attack_target")
						units[idx].erase("attack_base")
	queue_redraw()

func _initialize_supply_points(size: Vector2) -> void:
	supply_points = [
		{"pos": Vector2(size.x * 0.34, size.y * 0.28), "owner": "player", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"},
		{"pos": Vector2(size.x * 0.66, size.y * 0.72), "owner": "enemy", "payout": 0.0, "supply_payout": 0.0, "kind": "supply"},
		{"pos": Vector2(size.x * 0.50, size.y * 0.695), "owner": "neutral", "payout": 0.0, "supply_payout": 0.0, "kind": "port"}
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
				notice = "سيطر جيشك على الميناء الاستراتيجي!" if supply_points[i].get("kind", "supply") == "port" else "سيطر جيشك على نقطة إمداد!"
				notice_time = 2.5
		elif enemy_near and not player_near:
			if supply_points[i].owner != "enemy":
				supply_points[i].owner = "enemy"
				supply_points[i].payout = 0.0
				supply_points[i].supply_payout = 0.0
				notice = "العدو استولى على الميناء الاستراتيجي!" if supply_points[i].get("kind", "supply") == "port" else "العدو استولى على نقطة إمداد!"
				notice_time = 2.5
		if player_near and enemy_near:
			continue
		var is_port := String(supply_points[i].get("kind", "supply")) == "port"
		var gold_rate := 8 if is_port else 4
		var supply_interval := 6.0 if is_port else 8.0
		if supply_points[i].owner == "player":
			supply_points[i].payout += delta
			supply_points[i].supply_payout += delta
			if supply_points[i].payout >= 1.0:
				credits = mini(MAX_CREDITS, credits + gold_rate * int(supply_points[i].payout))
				supply_points[i].payout = fmod(supply_points[i].payout, 1.0)
			if supply_points[i].supply_payout >= supply_interval:
				supplies = mini(99, supplies + int(supply_points[i].supply_payout / supply_interval))
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
		var ownership_weight := 1.6 if String(point.get("owner", "neutral")) == "player" else 1.0
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
	# Bases, supply nodes and the shoreline remain in clear tactical lanes

func _draw_supply_points() -> void:
	for point in supply_points:
		var p: Vector2 = point.pos
		var owner: String = point.owner
		var is_port := String(point.get("kind", "supply")) == "port"
		var tint := Color("#438bd2") if owner == "player" else (Color("#d65349") if owner == "enemy" else Color("#e0c16e"))
		if is_port:
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
	match String(building.get("kind", "")):
		"missile_silo": base_hp = 500
		"missile_defense": base_hp = 450
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



func _unit_cost(kind: String, army: String) -> int:
	if kind == "helicopter":
		return _helicopter_cost(army)
	var profile := _faction_profile(army)
	var faction_costs: Dictionary = profile.get("unit_costs", {})
	if faction_costs.has(kind):
		return int(faction_costs[kind])
	var costs: Dictionary = ECONOMY_BALANCE["unit_costs"]
	return int(costs.get(kind, TANK_COST))


func _unit_supply_cost(kind: String) -> int:
	var costs: Dictionary = ECONOMY_BALANCE["unit_supplies"]
	return int(costs.get(kind, 0))


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
	for unit in units:
		if unit.team == "player" and unit.kind == "infantry" and unit.get("hp", 0) > 0:
			unit.target = target
			unit.erase("attack_base")
			unit.erase("attack_target")
			unit.erase("attack_building")
			assigned += 1
	if assigned == 0:
		notice = "تحتاج مشاة أحياء للسيطرة على المبنى"
	else:
		notice = "تتقدم قوات المشاة للاستيلاء — أمّن المنطقة!"
	notice_time = 3.0

func _order_destroy_selected_building() -> void:
	if selected_enemy_building < 0 or selected_enemy_building >= enemy_buildings.size():
		notice = "حدد مبنى للعدو أولاً"
		notice_time = 2.0
		return
	var assigned := 0
	for unit in units:
		if unit.team == "player" and unit.get("hp", 0) > 0 and (unit.kind == "tank" or unit.kind == "artillery" or unit.kind == "infantry"):
			unit.attack_building = selected_enemy_building
			unit.erase("attack_base")
			unit.erase("attack_target")
			unit.erase("target")
			assigned += 1
	if assigned == 0:
		notice = "أنت بحاجة إلى قوات برية لتدمير المبنى"
	else:
		notice = "صدرت أوامر تدمير المبنى المحدد!"
	notice_time = 3.0

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
			_apply_splash_damage(destination, 92.0, splash_damage, splash_team)
			_apply_building_splash_damage(destination, 92.0, splash_damage, splash_team)
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
					"factory", "barracks":
						building_priority = 5
					"airfield", "missile_silo":
						building_priority = 4
					"shipyard", "anti_air", "missile_defense":
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
		if kind in ["fighter", "helicopter"] and distance <= 460.0:
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
	var player_naval_threat = 0
	var player_heavy_ground_threat = 0
	var player_infantry_threat = 0
	for player_unit in units:
		if player_unit.team != "player" or player_unit.get("hp", 0) <= 0:
			continue
		if player_unit.kind == "fighter" or player_unit.kind == "helicopter":
			player_air_threat += 1
		elif _is_naval_kind(String(player_unit.kind)):
			player_naval_threat += 1
		elif player_unit.kind == "tank" or player_unit.kind == "artillery":
			player_heavy_ground_threat += 1
		elif player_unit.kind == "infantry":
			player_infantry_threat += 1
	var next_strategy := _enemy_choose_strategy(player_air_threat, player_naval_threat, player_heavy_ground_threat, player_infantry_threat)
	if next_strategy != enemy_strategy:
		enemy_strategy = next_strategy
		var strategy_names := {"air_control": "التفوق الجوي", "naval_control": "السيطرة البحرية", "armor_breaker": "مكافحة الدروع", "area_denial": "القصف المساحي", "balanced": "التوازن"}
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
	if player_air_threat >= 3 and build_pos.x >= 0.0 and enemy_credits >= _building_cost("anti_air"):
		var live_anti_air_count := 0
		for existing_building in enemy_buildings:
			if String(existing_building.get("kind", "")) == "anti_air" and int(existing_building.get("hp", 1)) > 0:
				live_anti_air_count += 1
		if live_anti_air_count < 2:
			enemy_credits -= _building_cost("anti_air")
			_enemy_add_building("anti_air", build_pos, 380)
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
	if not _enemy_has_any_building("shipyard") and enemy_credits >= _building_cost("shipyard"):
		enemy_credits -= _building_cost("shipyard")
		var naval_site := Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		_enemy_add_building("shipyard", naval_site, 500)
		notice = "العدو أنشأ حوض سفن ساحلياً"
		notice_time = 2.0
		return
	if build_pos.x >= 0.0 and not _enemy_has_any_building("anti_air") and enemy_credits >= _building_cost("anti_air"):
		enemy_credits -= _building_cost("anti_air")
		_enemy_add_building("anti_air", build_pos, 380)
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
		"naval_control": float(naval_threat) * 3.2,
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
		"naval_control":
			if destroyer_count < 3 and _enemy_has_powered_building("shipyard"):
				kind = "destroyer"
				cost = _unit_cost(kind, _enemy_faction())
				supply_cost = _unit_supply_cost(kind)
				unit_hp = 260
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
		"power_plant":
			draw_rect(Rect2(p + Vector2(-18, -17), Vector2(36, 34)), dark)
			draw_rect(Rect2(p + Vector2(-13, -12), Vector2(26, 24)), shell)
			for coil in range(3):
				draw_circle(p + Vector2(-8 + coil * 8, 0), 4, Color("#f2d47b"))
			draw_line(p + Vector2(-18, 19), p + Vector2(18, 19), accent, 3)
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
	var labels := {"power_plant": "محطة طاقة", "shipyard": "حوض سفن", "missile_silo": "منصة صواريخ", "missile_defense": "دفاع صاروخي", "barracks": "ثكنة", "factory": "مصنع", "airfield": "مطار", "anti_air": "مضاد جو"}
	var label: String = labels.get(kind, "برج دفاع")
	var display_label := "مستولى عليها: " + label if is_captured else label
	draw_string(ThemeDB.fallback_font, p + Vector2(-52, 43), display_label, HORIZONTAL_ALIGNMENT_CENTER, 104, 12 if is_captured else 13, Color("#b8f0b4") if is_captured else Color.WHITE)

func _place_building(pos: Vector2) -> void:
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
	if (build_mode == "shipyard" and (pos.y < get_viewport_rect().size.y * 0.72 or pos.x > get_viewport_rect().size.x * 0.48 or pos.distance_to(base_pos) > 390.0)) or (build_mode != "shipyard" and (pos.x > get_viewport_rect().size.x * 0.48 or pos.distance_to(base_pos) > 390.0 or pos.distance_to(base_pos) < 85.0)):
		notice = "اختر موقعاً مناسباً قرب قاعدتك"
		notice_time = 2.0
		return
	for building in buildings:
		if building.pos.distance_to(pos) < 75.0:
			notice = "الموقع مشغول، اختر مكاناً آخر"
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
		"missile_defense": construction_duration = 9.0
	buildings.append({"pos": pos, "kind": build_mode, "hp": 500 if build_mode == "missile_silo" else (450 if build_mode == "missile_defense" else 400), "attack_cd": 0.0, "build_progress": 0.0, "build_duration": construction_duration, "production_id": next_building_production_id})
	next_building_production_id += 1
	units[builder_index]["target"] = pos
	units[builder_index]["build_target"] = pos
	var building_labels := {"power_plant": "محطة الطاقة", "shipyard": "حوض السفن", "missile_silo": "منصة الصواريخ", "missile_defense": "الدفاع الصاروخي", "barracks": "الثكنة", "factory": "المصنع", "airfield": "المطار", "anti_air": "الدفاع المضاد للطائرات", "turret": "برج الدفاع"}
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
	if kind in ["fighter", "helicopter"]:
		return "airfield"
	if kind in ["destroyer", "carrier", "submarine", "landing_craft"]:
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
		"destroyer": return 13.0
		"submarine": return 12.0
		"landing_craft": return 11.0
		"carrier": return 20.0
	return 6.0

func _enqueue_unit(kind: String) -> void:
	var producer_kind := _production_building_for(kind)
	var producer_pos := Vector2(-9999, -9999)
	var producer_id := -1
	for i in range(buildings.size()):
		if buildings[i].kind == producer_kind and _is_player_building_powered(i):
			if not buildings[i].has("production_id"):
				buildings[i]["production_id"] = next_building_production_id
				next_building_production_id += 1
			producer_pos = buildings[i].pos
			producer_id = int(buildings[i].production_id)
			break
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
			supplies = mini(99, supplies + _unit_supply_cost(cancelled_kind))
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
			production_orders.remove_at(i)
			_spawn_unit(completed_kind, true)
			if notice.begins_with("تم إنتاج"):
				notice = "اكتمل إنتاج الوحدة — أُضيفت إلى ساحة المعركة"
			queue_redraw()
			return

func _spawn_unit(kind: String, already_paid: bool = false) -> void:
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
	if (kind == "fighter" or kind == "helicopter") and not _has_building("airfield"):
		notice = "ابنِ مطاراً أولاً لإنتاج المقاتلات والمروحيات"
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
	if _is_naval_kind(kind):
		for dock in buildings:
			if dock.kind == "shipyard":
				unit_spawn = dock.pos
				break
	var naval_hp := 520 if kind == "carrier" else (210 if kind == "submarine" else (220 if kind == "landing_craft" else 260))
	var unit_hp := naval_hp if kind in ["carrier", "submarine", "landing_craft", "destroyer"] else (220 if kind == "builder" else (180 if kind == "helicopter" else (120 if kind == "fighter" else (150 if kind == "tank" else 100))))
	var spawned_unit: Dictionary = {"pos": unit_spawn, "team": "player", "kind": kind, "faction": faction, "hp": unit_hp, "attack_cd": 0.0, "launch_cd": 16.0, "combat_xp": 0.0, "veterancy": 0, "combat_kills": 0, "air_kills": 0, "armor_kills": 0, "naval_kills": 0, "combat_medals": []}
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
	elif kind == "fighter":
		unit_name = "مقاتلة"
	notice = "تم إنتاج %s" % unit_name
	notice_time = 2.0
