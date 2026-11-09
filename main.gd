extends Node2D

const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const MAP_TYPES := ["الساحل الصحراوي", "ساحل الغابات", "الساحل الجبلي", "المدينة الساحلية"]
const INFANTRY_COST := 100
const TANK_COST := 300
const STARTING_CREDITS := 1200
const PASSIVE_INCOME := 6.0
const MAX_CREDITS := 5000
const BARRACKS_COST := 250
const FACTORY_COST := 450
const TURRET_COST := 350
const ARTILLERY_COST := 450
const AIRFIELD_COST := 600
const FIGHTER_COST := 500
const AA_COST := 400
const HELICOPTER_COST := 650
const MISSILE_SILO_COST := 800
const MISSILE_DEFENSE_COST := 700
const MISSILE_COST := 650

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
var build_mode := ""
var selected_enemy_building := -1
var notice := "اختر جيشك لبدء المعركة"
var notice_time := 4.0
var enemy_timer := 0.0
var enemy_credits := 1200
var enemy_income_timer := 0.0
var enemy_buildings: Array[Dictionary] = []
var game_started := false
var dragging := false
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

func _ready() -> void:
	randomize()
	_setup_battle_audio()
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _setup_battle_audio() -> void:
	audio_streams["weapon"] = _build_battle_sound("weapon")
	audio_streams["explosion"] = _build_battle_sound("explosion")
	for player_index in range(4):
		var player := AudioStreamPlayer.new()
		player.name = "BattleAudio" + str(player_index)
		player.volume_db = -7.0
		add_child(player)
		audio_players.append(player)


func _build_battle_sound(sound_name: String) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.34 if sound_name == "explosion" else 0.12
	var sample_count := int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count)
	for sample_index in range(sample_count):
		var t := float(sample_index) / float(sample_rate)
		var sample := 0.0
		if sound_name == "explosion":
			var envelope := exp(-t * 8.5)
			var sweep_frequency := 82.0 - 42.0 * (t / duration)
			var low_boom := sin(TAU * sweep_frequency * t) * 0.62
			var debris_noise := randf_range(-1.0, 1.0) * 0.38
			sample = (low_boom + debris_noise) * envelope
		else:
			var envelope := exp(-t * 38.0)
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
		var player_index := (audio_player_cursor + attempt) % audio_players.size()
		var player: AudioStreamPlayer = audio_players[player_index]
		if not player.playing:
			player.stream = audio_streams[sound_name]
			player.play()
			audio_player_cursor = (player_index + 1) % audio_players.size()
			return

func _process(delta: float) -> void:
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
			income_timer = 0.0
		_update_supply_control(delta)
		_update_building_capture(delta)
		_update_submarine_detection()
		_update_missiles(delta)
		if enemy_base_hp <= 0:
			battle_result = "انتصرت! دمرت قاعدة العدو"
			queue_redraw()
			return
		if player_base_hp <= 0:
			battle_result = "هُزمت! سقطت قاعدتك"
			queue_redraw()
			return
		enemy_income_timer += delta
		if enemy_income_timer >= 1.0:
			enemy_credits = mini(MAX_CREDITS, enemy_credits + int(PASSIVE_INCOME * enemy_income_timer))
			enemy_income_timer = 0.0
		enemy_timer += delta
		if enemy_timer >= 12.0:
			enemy_timer = 0.0
			_enemy_ai_turn()
		for building in buildings:
			if building.kind == "turret" or building.kind == "anti_air":
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var target := _nearest_enemy_unit(building.pos, 320.0 if building.kind == "anti_air" else 230.0, building.kind == "anti_air")
				if target >= 0 and building.attack_cd <= 0.0:
					units[target].hp = maxi(0, int(units[target].hp) - _terrain_adjusted_damage(units[target], 34 if building.kind == "anti_air" else 18))
					_add_visual_effect("tracer", building.pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ffd27a"), 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ffb34d"), 0.22, 13.0)
					building.attack_cd = 0.65 if building.kind == "anti_air" else 0.8
		for building in enemy_buildings:
			if building.kind == "turret" or building.kind == "anti_air":
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var target := _nearest_player_unit(building.pos, building.kind == "anti_air")
				var max_range := 320.0 if building.kind == "anti_air" else 230.0
				if target >= 0 and building.pos.distance_to(units[target].pos) <= max_range and building.attack_cd <= 0.0:
					units[target].hp = maxi(0, int(units[target].hp) - _terrain_adjusted_damage(units[target], 34 if building.kind == "anti_air" else 16))
					_add_visual_effect("tracer", building.pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ff8b72"), 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, Color("#8ee8ff") if building.kind == "anti_air" else Color("#ff704d"), 0.22, 12.0)
					building.attack_cd = 0.65 if building.kind == "anti_air" else 0.9
		for i in units.size():
			var unit := units[i]
			if unit.get("hp", 0) <= 0:
				continue
			if unit.team == "enemy":
				if _is_naval_kind(String(unit.kind)):
					var naval_target := _nearest_naval_unit(unit.pos, "player")
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
					var escort_carrier := _nearest_friendly_carrier(unit.pos, unit.team)
					if unit.kind == "destroyer" and escort_carrier >= 0 and naval_attack_destination.distance_to(units[escort_carrier].pos) > 240.0:
						var escort_side := -1.0 if unit.pos.y <= units[escort_carrier].pos.y else 1.0
						naval_destination = units[escort_carrier].pos + Vector2(-52.0, escort_side * 54.0)
					if unit.kind == "carrier":
						unit.launch_cd = float(unit.get("launch_cd", 16.0)) - delta
						var enemy_air := 0
						for air_unit in units:
							if air_unit.team == "enemy" and air_unit.kind == "fighter" and air_unit.get("hp", 0) > 0:
								enemy_air += 1
						if unit.launch_cd <= 0.0 and enemy_air < 3:
							units.append({"pos": unit.pos + Vector2(0, -18), "team": "enemy", "kind": "fighter", "faction": "الصيني", "hp": 120, "attack_cd": 0.0, "target": base_pos})
							unit.launch_cd = 18.0
					if unit.kind == "landing_craft":
						var landing_destination := Vector2(base_pos.x, get_viewport_rect().size.y * 0.82)
						if not unit.get("landed", false):
							if unit.pos.distance_to(landing_destination) <= 55.0:
								for marine in 3:
									units.append({"pos": landing_destination + Vector2(48.0 - marine * 18.0, -34.0), "team": "enemy", "kind": "infantry", "faction": "الصيني", "hp": 80, "attack_cd": 0.0, "target": base_pos})
								unit.landed = true
							else:
								unit.pos += (landing_destination - unit.pos).normalized() * delta * 30.0
						continue
					if unit.pos.distance_to(naval_attack_destination) <= 290.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0 and unit.kind != "landing_craft":
							var naval_damage := 78 if unit.kind == "destroyer" and naval_target >= 0 and units[naval_target].kind == "submarine" else (62 if unit.kind == "submarine" else (24 if unit.kind == "carrier" else (46 if unit.kind == "destroyer" else 40)))
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
					var heli_target := _nearest_player_unit(unit.pos)
					var heli_destination: Vector2 = base_pos if heli_target < 0 else units[heli_target].pos
					if unit.pos.distance_to(heli_destination) <= 235.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							_add_visual_effect("tracer", unit.pos, heli_destination, Color("#ffb56e"), 0.2, 0.0)
							_add_visual_effect("explosion", heli_destination, heli_destination, Color("#ff9b55"), 0.55, 46.0)
							if heli_target >= 0:
								var heli_damage := 58 if units[heli_target].kind == "submarine" else _helicopter_damage(unit)
								_apply_splash_damage(heli_destination, 42.0, heli_damage, "player")
								if units[heli_target].kind == "submarine":
									_add_visual_effect("flash", heli_destination, heli_destination, Color("#7fe8ef"), 0.35, 28.0)
							else:
								player_base_hp = maxi(0, player_base_hp - 26)
							unit.attack_cd = _helicopter_cooldown(unit)
					else:
						unit.pos += (heli_destination - unit.pos).normalized() * delta * 78.0
					continue
				if unit.kind == "fighter":
					var air_target := _nearest_player_unit(unit.pos)
					var air_destination: Vector2 = base_pos if air_target < 0 else units[air_target].pos
					if unit.pos.distance_to(air_destination) <= 280.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							_add_visual_effect("tracer", unit.pos, air_destination, Color("#ff9b72"), 0.18, 0.0)
							_add_visual_effect("explosion", air_destination, air_destination, Color("#ffad72"), 0.42, 24.0)
							if air_target >= 0:
								units[air_target].hp = maxi(0, int(units[air_target].hp) - _terrain_adjusted_damage(units[air_target], 28))
							else:
								player_base_hp = maxi(0, player_base_hp - 22)
							unit.attack_cd = 1.5
					else:
						unit.pos += (air_destination - unit.pos).normalized() * delta * 92.0
					continue
				if unit.kind == "artillery":
					var artillery_target := _nearest_player_unit(unit.pos)
					var artillery_destination: Vector2 = base_pos if artillery_target < 0 else units[artillery_target].pos
					var artillery_distance := unit.pos.distance_to(artillery_destination)
					if artillery_distance <= 330.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							_add_visual_effect("explosion", artillery_destination, artillery_destination, Color("#ff9855"), 0.65, 58.0)
							if artillery_target >= 0:
								_apply_splash_damage(artillery_destination, 52.0, 24, "player")
							else:
								player_base_hp = maxi(0, player_base_hp - 30)
							unit.attack_cd = 2.4
					else:
						unit.pos += (artillery_destination - unit.pos).normalized() * delta * 22.0
					continue
				var player_target := _nearest_player_unit(unit.pos)
				var destination: Vector2 = base_pos
				if player_target >= 0:
					destination = units[player_target].pos
				else:
					var nearest_objective_distance := INF
					for point in supply_points:
						if point.owner != "enemy":
							var objective_distance: float = unit.pos.distance_to(point.pos)
							if objective_distance < nearest_objective_distance:
								nearest_objective_distance = objective_distance
								destination = point.pos
				var distance_to_target := unit.pos.distance_to(destination)
				if player_target >= 0 and distance_to_target <= 150.0:
					unit.attack_cd = unit.get("attack_cd", 0.0) - delta
					if unit.attack_cd <= 0.0:
						units[player_target].hp = maxi(0, int(units[player_target].hp) - _terrain_adjusted_damage(units[player_target], 10))
						unit.attack_cd = 0.9
				elif player_target < 0 and distance_to_target <= 145.0:
					unit.attack_cd = unit.get("attack_cd", 0.0) - delta
					if unit.attack_cd <= 0.0:
						player_base_hp = maxi(0, player_base_hp - 10)
						unit.attack_cd = 0.9
				elif distance_to_target > 34.0:
					unit.pos += (destination - unit.pos).normalized() * delta * 22.0
			elif unit.team == "player":
				if _is_naval_kind(String(unit.kind)):
					var naval_target := _nearest_naval_unit(unit.pos, "enemy")
					var naval_destination := Vector2(enemy_base.x, get_viewport_rect().size.y * 0.82)
					var target_shipyard := -1
					for bi in enemy_buildings.size():
						if enemy_buildings[bi].kind == "shipyard":
							target_shipyard = bi
							break
					if naval_target >= 0:
						naval_destination = units[naval_target].pos
					elif target_shipyard >= 0:
						naval_destination = enemy_buildings[target_shipyard].pos
					var naval_attack_destination: Vector2 = naval_destination
					var escort_carrier := _nearest_friendly_carrier(unit.pos, unit.team)
					if unit.kind == "destroyer" and escort_carrier >= 0 and naval_attack_destination.distance_to(units[escort_carrier].pos) > 240.0:
						var escort_side := -1.0 if unit.pos.y <= units[escort_carrier].pos.y else 1.0
						naval_destination = units[escort_carrier].pos + Vector2(52.0, escort_side * 54.0)
					if unit.kind == "carrier":
						unit.launch_cd = float(unit.get("launch_cd", 16.0)) - delta
						var friendly_air := 0
						for air_unit in units:
							if air_unit.team == "player" and air_unit.kind == "fighter" and air_unit.get("hp", 0) > 0:
								friendly_air += 1
						if unit.launch_cd <= 0.0 and friendly_air < 3:
							units.append({"pos": unit.pos + Vector2(0, -18), "team": "player", "kind": "fighter", "faction": faction, "hp": 120, "attack_cd": 0.0, "target": enemy_base})
							unit.launch_cd = 18.0
					if unit.kind == "landing_craft":
						var landing_destination := Vector2(enemy_base.x, get_viewport_rect().size.y * 0.82)
						if not unit.get("landed", false):
							if unit.pos.distance_to(landing_destination) <= 55.0:
								for marine in 3:
									units.append({"pos": landing_destination + Vector2(-48.0 + marine * 18.0, -34.0), "team": "player", "kind": "infantry", "faction": faction, "hp": 100, "attack_cd": 0.0, "attack_base": true})
								unit.landed = true
							else:
								unit.pos += (landing_destination - unit.pos).normalized() * delta * 34.0
						continue
					if unit.pos.distance_to(naval_attack_destination) <= 290.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0 and unit.kind != "landing_craft":
							var naval_damage := 78 if unit.kind == "destroyer" and naval_target >= 0 and units[naval_target].kind == "submarine" else (62 if unit.kind == "submarine" else (24 if unit.kind == "carrier" else (50 if faction == "وطن" else (44 if faction == "الأمريكي" else (42 if faction == "الجيش العربي" else 40)))))
							_add_visual_effect("tracer", unit.pos, naval_attack_destination, Color("#a8eaff"), 0.2, 0.0)
							_add_visual_effect("explosion", naval_attack_destination, naval_attack_destination, Color("#ffbd78"), 0.5, 40.0)
							if naval_target >= 0:
								_apply_splash_damage(naval_attack_destination, 48.0, naval_damage, "enemy")
							elif target_shipyard >= 0:
								enemy_buildings[target_shipyard].hp = maxi(0, int(enemy_buildings[target_shipyard].get("hp", 500)) - naval_damage)
							else:
								enemy_base_hp = maxi(0, enemy_base_hp - naval_damage)
							unit.attack_cd = 2.0 if unit.kind == "submarine" else 2.2
					else:
						unit.pos += (naval_destination - unit.pos).normalized() * delta * (24.0 if unit.kind == "submarine" else 32.0)
					continue
				if unit.kind == "helicopter":
					var heli_target := _nearest_enemy_unit(unit.pos, 380.0)
					if heli_target >= 0:
						var heli_enemy: Dictionary = units[heli_target]
						if unit.pos.distance_to(heli_enemy.pos) <= 235.0:
							unit.attack_cd = unit.get("attack_cd", 0.0) - delta
							if unit.attack_cd <= 0.0:
								_add_visual_effect("tracer", unit.pos, heli_enemy.pos, Color("#b9f0b1"), 0.2, 0.0)
								_add_visual_effect("explosion", heli_enemy.pos, heli_enemy.pos, Color("#ffad62"), 0.52, 48.0)
								var heli_damage := 58 if heli_enemy.kind == "submarine" else _helicopter_damage(unit)
								_apply_splash_damage(heli_enemy.pos, 46.0, heli_damage, "enemy")
								if heli_enemy.kind == "submarine":
									_add_visual_effect("flash", heli_enemy.pos, heli_enemy.pos, Color("#7fe8ef"), 0.35, 28.0)
								unit.attack_cd = _helicopter_cooldown(unit)
						else:
							unit.pos += (heli_enemy.pos - unit.pos).normalized() * delta * 82.0
					else:
						var heli_base_distance := unit.pos.distance_to(enemy_base)
						if heli_base_distance <= 230.0:
							unit.attack_cd = unit.get("attack_cd", 0.0) - delta
							if unit.attack_cd <= 0.0:
								_add_visual_effect("explosion", enemy_base, enemy_base, Color("#ffad62"), 0.52, 48.0)
								enemy_base_hp = maxi(0, enemy_base_hp - 28)
								unit.attack_cd = _helicopter_cooldown(unit)
						else:
							unit.pos += (enemy_base - unit.pos).normalized() * delta * 82.0
					continue
				if unit.kind == "fighter":
					var air_target := _nearest_enemy_unit(unit.pos, 300.0)
					if air_target >= 0:
						var air_enemy: Dictionary = units[air_target]
						if unit.pos.distance_to(air_enemy.pos) <= 270.0:
							unit.attack_cd = unit.get("attack_cd", 0.0) - delta
							if unit.attack_cd <= 0.0:
								_add_visual_effect("tracer", unit.pos, air_enemy.pos, Color("#a8eaff"), 0.18, 0.0)
								_add_visual_effect("explosion", air_enemy.pos, air_enemy.pos, Color("#ffbd78"), 0.4, 22.0)
								air_enemy.hp = maxi(0, int(air_enemy.hp) - _terrain_adjusted_damage(air_enemy, 30))
								unit.attack_cd = 1.35
						else:
							unit.pos += (air_enemy.pos - unit.pos).normalized() * delta * 95.0
					else:
						unit.pos += (enemy_base - unit.pos).normalized() * delta * 65.0
					continue
				if unit.has("attack_building"):
					var building_target := int(unit.attack_building)
					if building_target < 0 or building_target >= enemy_buildings.size():
						unit.erase("attack_building")
						continue
					var target_building: Dictionary = enemy_buildings[building_target]
					var building_distance := unit.pos.distance_to(target_building.pos)
					var building_range := 350.0 if unit.kind == "artillery" else 75.0
					if building_distance <= building_range:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							var building_damage := 48 if unit.kind == "artillery" else (32 if unit.kind == "tank" else 8)
							target_building.hp = maxi(0, int(target_building.get("hp", 400)) - building_damage)
							_add_visual_effect("explosion" if unit.kind == "artillery" else "flash", target_building.pos, target_building.pos, Color("#ffad62"), 0.45, 30.0)
							unit.attack_cd = 2.0 if unit.kind == "artillery" else 0.9
							if target_building.hp <= 0:
								enemy_buildings.remove_at(building_target)
								selected_enemy_building = -1
								for other in units:
									if other.has("attack_building") and int(other.attack_building) == building_target:
										other.erase("attack_building")
									elif other.has("attack_building") and int(other.attack_building) > building_target:
										other.attack_building = int(other.attack_building) - 1
								notice = "تم تدمير مبنى العدو!"
								notice_time = 2.5
					else:
						unit.pos += (target_building.pos - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else 38.0)
					continue
				if unit.get("attack_base", false):
					var base_distance := unit.pos.distance_to(enemy_base)
					var base_range := 360.0 if unit.kind == "artillery" else 155.0
					if base_distance <= base_range:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							enemy_base_hp = maxi(0, enemy_base_hp - (45 if unit.kind == "artillery" else (20 if unit.kind == "tank" else 10)))
							unit.attack_cd = 2.4 if unit.kind == "artillery" else (0.75 if unit.kind == "tank" else 1.0)
					else:
						unit.pos += (enemy_base - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
					continue
				var enemy_target := int(unit.get("attack_target", -1))
				if enemy_target < 0 or enemy_target >= units.size() or units[enemy_target].team != "enemy" or units[enemy_target].get("hp", 0) <= 0 or (units[enemy_target].kind == "submarine" and not _is_submarine_detected(units[enemy_target], "player")):
					enemy_target = _nearest_enemy_unit(unit.pos, 420.0 if unit.kind == "artillery" else 220.0)
					if enemy_target >= 0:
						unit.attack_target = enemy_target
				if enemy_target >= 0:
					var enemy: Dictionary = units[enemy_target]
					var distance := unit.pos.distance_to(enemy.pos)
					var attack_range := 360.0 if unit.kind == "artillery" else 160.0
					if distance <= attack_range:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							if unit.kind == "artillery":
								_add_visual_effect("explosion", enemy.pos, enemy.pos, Color("#ffb45e"), 0.72, 66.0)
								_apply_splash_damage(enemy.pos, 58.0, 45, "enemy")
								unit.attack_cd = 2.4
							else:
								enemy.hp = maxi(0, int(enemy.hp) - _terrain_adjusted_damage(enemy, 20 if unit.kind == "tank" else 10))
								_add_visual_effect("tracer", unit.pos, enemy.pos, Color("#ffe0a0"), 0.14, 0.0)
								_add_visual_effect("flash", enemy.pos, enemy.pos, Color("#ffb34d"), 0.18, 8.0)
								unit.attack_cd = 0.75 if unit.kind == "tank" else 1.0
					else:
						unit.pos += (enemy.pos - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
				elif unit.has("target"):
					var target: Vector2 = unit.target
					if unit.pos.distance_to(target) > 8.0:
						unit.pos += (target - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
		_update_unit_facing(delta)
		queue_redraw()

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
				var is_tank := unit.kind == "tank"
				var puff_count := 2 if is_tank else 1
				for puff_index in range(puff_count):
					var offset := Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
					_spawn_environment_particle(unit.pos + offset, Vector2(randf_range(-10.0, -2.0), randf_range(-8.0, -2.0)), 5.5 if is_tank else 3.5, 0.58 if is_tank else 0.42, Color("#bba98b") if map_type == "الساحل الصحراوي" else Color("#85877c"), "dust")
				unit["environment_cd"] = 0.12 if is_tank else 0.2
	while environment_particles.size() > 110:
		environment_particles.pop_front()

func _spawn_environment_particle(pos: Vector2, velocity: Vector2, radius: float, life: float, tint: Color, particle_kind: String) -> void:
	environment_particles.append({"pos": pos, "velocity": velocity, "radius": radius, "life": life, "max_life": life, "color": tint, "kind": particle_kind})

func _draw_environment_particles() -> void:
	for particle in environment_particles:
		var life_ratio := clampf(float(particle.life) / maxf(0.01, float(particle.max_life)), 0.0, 1.0)
		var fade := life_ratio * 0.42
		var center: Vector2 = particle.pos
		var radius := float(particle.radius) * (1.0 + (1.0 - life_ratio) * (1.25 if particle.kind == "smoke" else 0.55))
		var tint: Color = particle.color
		if particle.kind == "smoke":
			draw_circle(center, radius * 1.25, Color(tint.r * 0.72, tint.g * 0.74, tint.b * 0.76, fade * 0.42))
			draw_circle(center + Vector2(-radius * 0.28, -radius * 0.22), radius * 0.72, Color(tint.r, tint.g, tint.b, fade * 0.52))
		else:
			draw_circle(center, radius, Color(tint.r, tint.g, tint.b, fade * 0.62))

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

func _apply_splash_damage(center: Vector2, radius: float, damage: int, target_team: String) -> void:
	for unit in units:
		if unit.team == target_team and unit.get("hp", 0) > 0 and unit.pos.distance_to(center) <= radius:
			unit.hp = maxi(0, int(unit.hp) - _terrain_adjusted_damage(unit, damage))

func _helicopter_damage(unit: Dictionary) -> int:
	var army: String = unit.get("faction", faction)
	if army == "وطن":
		return 38
	if army == "الجيش العربي":
		return 34
	if army == "الأمريكي":
		return 32
	return 30

func _helicopter_cooldown(unit: Dictionary) -> float:
	var army: String = unit.get("faction", faction)
	return 1.1 if army == "وطن" else (1.2 if army == "الجيش العربي" else (1.25 if army == "الأمريكي" else 1.35))

func _helicopter_color(unit: Dictionary) -> Color:
	var army: String = unit.get("faction", faction)
	if army == "الأمريكي":
		return Color("#657b52")
	if army == "الصيني":
		return Color("#a94d3d")
	if army == "الجيش العربي":
		return Color("#c0a36b")
	return Color("#d5b64e")

func _is_naval_kind(kind: String) -> bool:
	return kind in ["destroyer", "carrier", "submarine", "landing_craft"]

func _nearest_friendly_carrier(from_pos: Vector2, team: String) -> int:
	var best_index := -1
	var best_distance := INF
	for i in units.size():
		if units[i].team != team or units[i].kind != "carrier" or units[i].get("hp", 0) <= 0:
			continue
		var distance := from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _nearest_naval_unit(from_pos: Vector2, target_team: String) -> int:
	var best_index := -1
	var best_distance := INF
	var observer_team := "enemy" if target_team == "player" else "player"
	for i in units.size():
		if units[i].team != target_team or not _is_naval_kind(String(units[i].kind)) or units[i].get("hp", 0) <= 0:
			continue
		if units[i].kind == "submarine" and not _is_submarine_detected(units[i], observer_team):
			continue
		var distance := from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
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

func _nearest_player_unit(from_pos: Vector2, air_only: bool = false) -> int:
	var best_index := -1
	var best_distance := INF
	for i in units.size():
		if units[i].team != "player" or units[i].get("hp", 0) <= 0:
			continue
		if units[i].kind == "submarine" and not _is_submarine_detected(units[i], "enemy"):
			continue
		if air_only and units[i].kind != "fighter" and units[i].kind != "helicopter":
			continue
		var distance := from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _nearest_enemy_unit(from_pos: Vector2, max_distance: float, air_only: bool = false) -> int:
	var best_index := -1
	var best_distance := max_distance
	for i in units.size():
		if units[i].team != "enemy" or units[i].get("hp", 0) <= 0:
			continue
		if units[i].kind == "submarine" and not _is_submarine_detected(units[i], "player"):
			continue
		if air_only and units[i].kind != "fighter" and units[i].kind != "helicopter":
			continue
		var distance := from_pos.distance_to(units[i].pos)
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
		var building_index := int(unit.attack_building)
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
	var points := PackedVector2Array()
	for local_point in local_points:
		points.append(_unit_rotated_point(origin, local_point, angle))
	return points


func _rotated_rect_points(center: Vector2, dimensions: Vector2, angle: float) -> PackedVector2Array:
	var half := dimensions * 0.5
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
			var desired_angle := movement.angle()
			var current_angle := float(unit.get("facing", desired_angle))
			unit.facing = lerp_angle(current_angle, desired_angle, clampf(delta * 9.0, 0.0, 1.0))
		unit.visual_previous_pos = current_pos


func _draw() -> void:
	var size := get_viewport_rect().size
	_draw_terrain(size)
	# Layered coastline, beach and navigable sea lane
	draw_rect(Rect2(0, size.y * 0.675, size.x, size.y * 0.065), Color("#b6a078"))
	draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color("#1d435d"))
	draw_rect(Rect2(0, size.y * 0.72, size.x, 7), Color("#d2c092"))
	for wave in range(10):
		var wy := size.y * 0.745 + wave * 19.0
		var wave_x := float((wave * 83) % maxi(1, int(size.x)))
		draw_line(Vector2(wave_x, wy), Vector2(minf(size.x, wave_x + size.x * 0.34), wy + 4), Color(0.58, 0.82, 0.9, 0.17), 2.0)
	# Rocky headlands frame the harbor entrance
	for rock in range(7):
		var rx := float(rock) * size.x / 6.0
		var ry := size.y * (0.665 + float((rock % 2)) * 0.018)
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
	for building in buildings:
		_draw_building(building.pos, building.kind, false)
	for building_index in enemy_buildings.size():
		var building: Dictionary = enemy_buildings[building_index]
		_draw_building(building.pos, building.kind, true)
		if building_index == selected_enemy_building:
			draw_arc(building.pos, 39.0, 0.0, TAU, 48, Color("#ffe27a"), 3.0)
		_draw_building_health(building.pos, int(building.get("hp", 400)))
		if float(building.get("capture_progress", 0.0)) > 0.0:
			_draw_capture_progress(building.pos, float(building.capture_progress))
	for i in units.size():
		var u := units[i]
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
			var heli_color := _helicopter_color(u)
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
			var plane_color := Color("#d7e4e8") if u.team == "player" else Color("#d95b51")
			var plane_angle := _unit_facing_angle(u)
			var plane_shape := PackedVector2Array([Vector2(24, 0), Vector2(-8, -6), Vector2(-23, -20), Vector2(-16, 0), Vector2(-23, 20), Vector2(-8, 6)])
			draw_colored_polygon(_unit_polygon_points(u.pos, plane_shape, plane_angle), Color(0, 0, 0, 0.18))
			draw_colored_polygon(_unit_polygon_points(u.pos, plane_shape, plane_angle), plane_color)
			draw_colored_polygon(_unit_polygon_points(u.pos, PackedVector2Array([Vector2(7, 0), Vector2(-7, -4), Vector2(-13, 0), Vector2(-7, 4)]), plane_angle), Color("#52636d"))
			draw_line(_unit_rotated_point(u.pos, Vector2(-4, 0), plane_angle), _unit_rotated_point(u.pos, Vector2(24, 0), plane_angle), Color("#303a42"), 3)
			draw_line(_unit_rotated_point(u.pos, Vector2(-12, -8), plane_angle), _unit_rotated_point(u.pos, Vector2(-18, -17), plane_angle), Color("#e4d9a7"), 2)
			draw_line(_unit_rotated_point(u.pos, Vector2(-12, 8), plane_angle), _unit_rotated_point(u.pos, Vector2(-18, 17), plane_angle), Color("#e4d9a7"), 2)
			draw_circle(_unit_rotated_point(u.pos, Vector2(7, 0), plane_angle), 3, Color("#9bd5e5"))
		elif u.kind == "tank":
			var facing := _unit_facing_angle(u)
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
			var facing := _unit_facing_angle(u)
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
				var plane_x := -20.0 + deck_plane * 12.0
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
		var max_hp := 520.0 if u.kind == "carrier" else (260.0 if u.kind == "destroyer" else (220.0 if u.kind == "landing_craft" else (210.0 if u.kind == "submarine" else (180.0 if u.kind == "helicopter" else (120.0 if u.kind == "fighter" else (150.0 if u.kind == "tank" else (100.0 if u.kind == "artillery" or u.team == "player" else 60.0))))))
		var hp_ratio := clampf(float(u.get("hp", 0)) / max_hp, 0.0, 1.0)
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32, 4)), Color("#352c2a"))
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32.0 * hp_ratio, 4)), Color("#5ed16f") if hp_ratio > 0.35 else Color("#e85c4a"))
		if selected.has(i):
			draw_arc(u.pos, 17, 0, TAU, 32, Color("#ffe45c"), 3)
	_draw_environment_particles()
	for effect in visual_effects:
		var progress := 1.0 - clampf(float(effect.life) / float(effect.duration), 0.0, 1.0)
		var fade := 1.0 - progress
		var tint: Color = effect.color
		tint.a = fade
		if effect.kind == "tracer":
			draw_line(effect.start, effect.finish, tint, 3.0)
			draw_circle(effect.finish, 3.0 * fade + 1.0, tint)
		elif effect.kind == "flash":
			draw_circle(effect.finish, float(effect.radius) * (0.45 + progress), tint)
			draw_arc(effect.finish, float(effect.radius) * (0.8 + progress), 0.0, TAU, 20, tint, 2.0)
		elif effect.kind == "explosion":
			var blast_radius: float = float(effect.radius) * (0.25 + progress)
			var shock_radius: float = float(effect.radius) * (0.35 + progress * 1.35)
			draw_circle(effect.finish, blast_radius, Color(tint.r, tint.g * 0.62, tint.b * 0.28, fade * 0.42))
			draw_arc(effect.finish, blast_radius, 0.0, TAU, 32, tint, 4.0 * fade + 1.0)
			# Expanding pressure ring and deterministic sparks keep the effect light on mobile.
			draw_arc(effect.finish, shock_radius, 0.0, TAU, 36, Color(1.0, 0.78, 0.42, fade * 0.72), 2.0 * fade + 0.5)
			for spark_index in range(8):
				var spark_angle := TAU * float(spark_index) / 8.0 + progress * 0.35
				var spark_direction := Vector2(cos(spark_angle), sin(spark_angle))
				var spark_start := effect.finish + spark_direction * blast_radius * 0.42
				var spark_end := effect.finish + spark_direction * (blast_radius * (0.72 + progress * 0.55))
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
	elif notice_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.35, 82), notice, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.3, 23, Color.WHITE)

func _restart_rect(size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x * 0.4, size.y * 0.53), Vector2(size.x * 0.2, 48))

func _draw_base_health(p: Vector2, hp: int) -> void:
	var ratio := clampf(float(hp) / 1000.0, 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-45, -62), Vector2(90, 7)), Color("#292929"))
	draw_rect(Rect2(p + Vector2(-45, -62), Vector2(90.0 * ratio, 7)), Color("#55d879") if ratio > 0.3 else Color("#e85c4a"))

func _draw_base(p: Vector2, color: Color, label: String) -> void:
	draw_rect(Rect2(p - Vector2(48, 42), Vector2(96, 84)), Color("#343b35"))
	draw_rect(Rect2(p - Vector2(40, 34), Vector2(80, 68)), color)
	draw_rect(Rect2(p - Vector2(18, 54), Vector2(36, 20)), Color("#c7c6b3"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-48, 66), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 16, Color.WHITE)

func _draw_hud(size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, 58), Color(0.06, 0.08, 0.09, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(22, 38), "STORM GENERALS", HORIZONTAL_ALIGNMENT_LEFT, 300, 25, Color("#f4d77a"))
	draw_string(ThemeDB.fallback_font, Vector2(maxf(330.0, size.x - 410.0), 26), "الذهب: %d" % credits, HORIZONTAL_ALIGNMENT_LEFT, 170, 19, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(maxf(330.0, size.x - 230.0), 47), "الإمداد: %d" % supplies, HORIZONTAL_ALIGNMENT_LEFT, 180, 17, Color("#9fe6d2"))
	if game_started:
		var labels := ["مشاة 100", "دبابة 300", "ثكنة 250", "مصنع 450", "دفاع 350", "مدفعية 450", "مطار 600", "مقاتلة 500", "مضاد جو 400", "مروحية 650", "سيطرة مبنى", "تدمير مبنى", "إلغاء", "منصة صواريخ 800", "دفاع صاروخي 700", "إطلاق صاروخ 650", "حوض سفن 700", "مدمرة 900", "حاملة 1600", "غواصة 1100", "إنزال 800"]
		for i in labels.size():
			var r := _button_rect(i, size)
			draw_rect(r, Color("#263d50"), true)
			draw_rect(r, Color("#8fa8b8"), false, 2)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(2, 31), labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4, 15, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(16, 82), "المسرح: %s" % map_type, HORIZONTAL_ALIGNMENT_LEFT, 300, 16, Color("#fff0b5"))
		draw_string(ThemeDB.fallback_font, Vector2(16, 103), _terrain_effect_label(), HORIZONTAL_ALIGNMENT_LEFT, 360, 14, Color("#d8e6c2"))
		draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 368), "الأسطول: مدمرات وحاملات وغواصات وسفن إنزال — احمِ الممرات البحرية", HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 15, Color.WHITE)

func _button_rect(index: int, size: Vector2) -> Rect2:
	var column := index % 4
	var row := int(index / 4)
	var button_width := (size.x - 40.0) / 4.0
	return Rect2(Vector2(8.0 + column * (button_width + 8.0), size.y - 358.0 + row * 58.0), Vector2(button_width, 52.0))

func _draw_faction_picker(size: Vector2) -> void:
	draw_rect(Rect2(size.x * 0.22, size.y * 0.19, size.x * 0.56, size.y * 0.62), Color(0.04, 0.07, 0.08, 0.94))
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.32, size.y * 0.30), "عاصفة الجنرالات", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.36, 38, Color("#f4d77a"))
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.32, size.y * 0.37), "اختر الجيش الذي ستقوده", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.36, 22, Color.WHITE)
	for i in FACTIONS.size():
		var r := _faction_rect(i, size)
		draw_rect(r, Color("#28445a") if i != 3 else Color("#73552d"), true)
		draw_rect(r, Color("#b7c6d1"), false, 2)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 42), FACTIONS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color.WHITE)

func _faction_rect(i: int, size: Vector2) -> Rect2:
	var w := size.x * 0.21
	return Rect2(Vector2(size.x * 0.28 + i * (w + 12), size.y * 0.48), Vector2(w, 72))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_pointer(event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		drag_end = event.position
		queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		drag_end = event.position
		queue_redraw()

func _handle_pointer(pos: Vector2, pressed: bool) -> void:
	var size := get_viewport_rect().size
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
			game_started = false
			battle_result = ""
			faction = ""
			units.clear()
			buildings.clear()
			enemy_buildings.clear()
			selected.clear()
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
			missiles.clear()
			enemy_missile_timer = 0.0
			queue_redraw()
		return
	if not game_started:
		for i in FACTIONS.size():
			if _faction_rect(i, size).has_point(pos):
				faction = FACTIONS[i]
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
				enemy_buildings.clear()
				selected.clear()
				build_mode = ""
				enemy_credits = STARTING_CREDITS
				enemy_income_timer = 0.0
				enemy_timer = 0.0
				player_base_hp = 1000
				enemy_base_hp = 1000
				game_started = true
				notice = "بدأت المعركة — %s | %s" % [faction, map_type]
				notice_time = 3.0
				queue_redraw()
				return
		return
	for i in 21:
		if _button_rect(i, size).has_point(pos):
			if i == 0:
				_spawn_unit("infantry")
			elif i == 1:
				_spawn_unit("tank")
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
				_spawn_unit("artillery")
			elif i == 6:
				build_mode = "airfield"
				notice = "المس موقعاً مناسباً لبناء المطار"
				notice_time = 3.0
			elif i == 7:
				_spawn_unit("fighter")
			elif i == 8:
				build_mode = "anti_air"
				notice = "المس موقعاً مناسباً لنشر الدفاع المضاد للطائرات"
				notice_time = 3.0
			elif i == 9:
				_spawn_unit("helicopter")
			elif i == 10:
				_capture_selected_building()
			elif i == 11:
				_order_destroy_selected_building()
			elif i == 12:
				selected.clear()
				selected_enemy_building = -1
				build_mode = ""
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
				_spawn_unit("destroyer")
			elif i == 18:
				_spawn_unit("carrier")
			elif i == 19:
				_spawn_unit("submarine")
			elif i == 20:
				_spawn_unit("landing_craft")
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
		selected.clear()
		var area := Rect2(drag_start, pos - drag_start).abs()
		for i in units.size():
			if units[i].team == "player" and area.has_point(units[i].pos):
				selected.append(i)
	else:
		var building_found := -1
		for i in enemy_buildings.size():
			if enemy_buildings[i].pos.distance_to(pos) < 38.0:
				building_found = i
				break
		if building_found >= 0:
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
					units[idx].erase("attack_base")
			notice = "أمر هجوم!"
			notice_time = 1.5
		else:
			var found := -1
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

func _draw_terrain(size: Vector2) -> void:
	var ground := Color("#9a835d")
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
				var p := Vector2(float((i * 137 + 38) % int(size.x)), 78.0 + float((i * 83) % maxi(1, int(size.y * 0.53))))
				draw_arc(p, 22.0 + float(i % 3) * 7.0, 3.3, 6.1, 28, Color("#d4bd8b", 0.35), 3.0)
				draw_circle(p + Vector2(18, 9), 2.0, Color("#d8c49a", 0.5))
		"ساحل الغابات":
			for i in range(26):
				var p := Vector2(float((i * 97 + 35) % int(size.x)), 75.0 + float((i * 61) % maxi(1, int(size.y * 0.55))))
				if absf(p.y - size.y * 0.40) < 52.0:
					continue
				draw_rect(Rect2(p + Vector2(-3, 7), Vector2(6, 13)), Color("#554432"))
				draw_circle(p, 15.0, Color("#294b35"))
				draw_circle(p + Vector2(-5, -5), 9.0, Color("#507348"))
		"الساحل الجبلي":
			for i in range(11):
				var x := float(i) * size.x / 10.0
				var y := 105.0 + float((i * 59) % maxi(1, int(size.y * 0.40)))
				var peak := Vector2(x, y)
				var mountain := PackedVector2Array([peak + Vector2(-48, 58), peak + Vector2(0, -38 - float(i % 3) * 12.0), peak + Vector2(55, 58)])
				draw_colored_polygon(mountain, Color("#505b58"))
				draw_line(peak + Vector2(0, -30), peak + Vector2(20, 4), Color("#c0c3b9", 0.55), 3.0)
		"المدينة الساحلية":
			for row in range(3):
				for col in range(10):
					var p := Vector2(24.0 + col * size.x / 10.0, 85.0 + row * 155.0)
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

func _unit_supply_cost(kind: String) -> int:
	if kind == "helicopter":
		return 3
	if kind == "fighter" or kind == "artillery":
		return 2
	if kind == "tank":
		return 1
	return 0

func _update_building_capture(delta: float) -> void:
	for i in range(enemy_buildings.size() - 1, -1, -1):
		var building: Dictionary = enemy_buildings[i]
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
				var captured := building.duplicate(true)
				captured.erase("capture_progress")
				buildings.append(captured)
				enemy_buildings.remove_at(i)
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

func _draw_building_health(p: Vector2, hp: int) -> void:
	var ratio := clampf(float(hp) / 400.0, 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-25, -32), Vector2(50, 5)), Color("#292929"))
	draw_rect(Rect2(p + Vector2(-25, -32), Vector2(50.0 * ratio, 5)), Color("#79d47b"))

func _draw_capture_progress(p: Vector2, progress: float) -> void:
	var ratio := clampf(progress / 3.0, 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-28, -41), Vector2(56, 7)), Color("#252525"))
	draw_rect(Rect2(p + Vector2(-27, -40), Vector2(54.0 * ratio, 5)), Color("#f2d15c"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-40, -46), "جارٍ الاستيلاء", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color("#ffe58a"))

func _missile_damage(army: String) -> int:
	if army == "وطن":
		return 230
	if army == "الجيش العربي":
		return 205
	if army == "الأمريكي":
		return 195
	return 185

func _missile_cooldown(army: String) -> float:
	if army == "وطن":
		return 11.0
	if army == "الجيش العربي":
		return 12.0
	if army == "الأمريكي":
		return 13.0
	return 14.0

func _launch_player_missile() -> void:
	if not _has_building("missile_silo"):
		notice = "ابنِ منصة صواريخ أولاً"
		notice_time = 2.5
		return
	if credits < MISSILE_COST or supplies < 4:
		notice = "الصاروخ يحتاج 650 ذهب و4 إمدادات"
		notice_time = 2.5
		return
	var silo_index := -1
	for i in buildings.size():
		if buildings[i].kind == "missile_silo" and float(buildings[i].get("attack_cd", 0.0)) <= 0.0:
			silo_index = i
			break
	if silo_index < 0:
		notice = "منصة الصواريخ تعيد التلقيم — انتظر قليلاً"
		notice_time = 2.0
		return
	var target_pos: Vector2 = enemy_base
	var target_kind := "base"
	if selected_enemy_building >= 0 and selected_enemy_building < enemy_buildings.size():
		target_pos = enemy_buildings[selected_enemy_building].pos
		target_kind = "building"
	credits -= MISSILE_COST
	supplies -= 4
	buildings[silo_index].attack_cd = _missile_cooldown(faction)
	missiles.append({"pos": buildings[silo_index].pos + Vector2(0, -24), "target": target_pos, "target_kind": target_kind, "team": "player", "damage": _missile_damage(faction), "life": 8.0})
	notice = "انطلق الصاروخ!"
	notice_time = 2.0

func _launch_enemy_missile() -> void:
	if enemy_credits < MISSILE_COST or enemy_supplies < 4:
		return
	var player_faction_index := FACTIONS.find(faction)
	var enemy_faction := FACTIONS[(player_faction_index + 1) % FACTIONS.size()]
	var silo_index := -1
	for i in enemy_buildings.size():
		if enemy_buildings[i].kind == "missile_silo" and float(enemy_buildings[i].get("attack_cd", 0.0)) <= 0.0:
			silo_index = i
			break
	if silo_index < 0:
		return
	enemy_credits -= MISSILE_COST
	enemy_supplies -= 4
	enemy_buildings[silo_index].attack_cd = _missile_cooldown(enemy_faction)
	missiles.append({"pos": enemy_buildings[silo_index].pos + Vector2(0, -24), "target": base_pos, "target_kind": "base", "team": "enemy", "damage": _missile_damage(enemy_faction), "life": 8.0})

func _update_missiles(delta: float) -> void:
	for building in buildings:
		if building.kind == "missile_silo" or building.kind == "missile_defense":
			building.attack_cd = maxf(0.0, float(building.get("attack_cd", 0.0)) - delta)
	for building in enemy_buildings:
		if building.kind == "missile_silo" or building.kind == "missile_defense":
			building.attack_cd = maxf(0.0, float(building.get("attack_cd", 0.0)) - delta)
	enemy_missile_timer += delta
	if enemy_missile_timer >= 24.0:
		enemy_missile_timer = 0.0
		_launch_enemy_missile()
	for i in range(missiles.size() - 1, -1, -1):
		var missile: Dictionary = missiles[i]
		var hostile_buildings: Array[Dictionary] = buildings if missile.team == "enemy" else enemy_buildings
		var intercepted := false
		for defense in hostile_buildings:
			if defense.kind != "missile_defense" or float(defense.get("attack_cd", 0.0)) > 0.0:
				continue
			if defense.pos.distance_to(missile.pos) <= 190.0:
				defense.attack_cd = 2.0
				_add_visual_effect("explosion", missile.pos, missile.pos, Color("#8ee8ff"), 0.5, 34.0)
				missiles.remove_at(i)
				intercepted = true
				break
		if intercepted:
			continue
		var destination: Vector2 = missile.target
		var direction := destination - missile.pos
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
							if enemy_buildings[building_index].hp <= 0:
								enemy_buildings.remove_at(building_index)
								if selected_enemy_building == building_index:
									selected_enemy_building = -1
								elif selected_enemy_building > building_index:
									selected_enemy_building -= 1
							break
			else:
				player_base_hp = maxi(0, player_base_hp - int(missile.damage))
			missiles.remove_at(i)
		else:
			missile.pos += direction.normalized() * travel
			missile.life = float(missile.life) - delta

func _apply_building_splash_damage(center: Vector2, radius: float, damage: int, target_team: String) -> void:
	var targets: Array[Dictionary] = enemy_buildings if target_team == "enemy" else buildings
	for building in targets:
		var distance := building.pos.distance_to(center)
		# The primary structure is handled by its direct-hit damage.
		if distance > 36.0 and distance <= radius:
			building.hp = maxi(0, int(building.get("hp", 400)) - damage)

func _draw_missiles() -> void:
	for missile in missiles:
		var p: Vector2 = missile.pos
		var tint := Color("#8ee8ff") if missile.team == "player" else Color("#ff856b")
		draw_line(p, p + Vector2(-13, 9), Color(tint, 0.75), 4.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(11, 0), p + Vector2(-7, -5), p + Vector2(-7, 5)]), tint)
		draw_circle(p + Vector2(-12, 0), 5.0, Color("#ffb45f", 0.7))

func _enemy_has_building(kind: String) -> bool:
	for building in enemy_buildings:
		if building.kind == kind:
			return true
	return false

func _enemy_ai_turn() -> void:
	var build_pos := _enemy_build_position()
	if build_pos.x < 0.0:
		return
	if not _enemy_has_building("barracks") and enemy_credits >= BARRACKS_COST:
		enemy_credits -= BARRACKS_COST
		enemy_buildings.append({"pos": build_pos, "kind": "barracks", "hp": 400, "attack_cd": 0.0})
		notice = "العدو أنشأ ثكنة عسكرية"
		notice_time = 2.0
		return
	if not _enemy_has_building("factory") and enemy_credits >= FACTORY_COST:
		enemy_credits -= FACTORY_COST
		enemy_buildings.append({"pos": build_pos, "kind": "factory", "hp": 500, "attack_cd": 0.0})
		notice = "العدو أنشأ مصنع دبابات"
		notice_time = 2.0
		return
	if not _enemy_has_building("turret") and enemy_credits >= TURRET_COST:
		enemy_credits -= TURRET_COST
		enemy_buildings.append({"pos": build_pos, "kind": "turret", "hp": 350, "attack_cd": 0.0})
		notice = "العدو نشر برجاً دفاعياً"
		notice_time = 2.0
		return
	if not _enemy_has_building("airfield") and enemy_credits >= AIRFIELD_COST:
		enemy_credits -= AIRFIELD_COST
		enemy_buildings.append({"pos": build_pos, "kind": "airfield", "hp": 450, "attack_cd": 0.0})
		notice = "العدو أنشأ مطاراً حربياً"
		notice_time = 2.0
		return
	if not _enemy_has_building("missile_silo") and enemy_credits >= MISSILE_SILO_COST:
		enemy_credits -= MISSILE_SILO_COST
		enemy_buildings.append({"pos": build_pos, "kind": "missile_silo", "hp": 500, "attack_cd": 8.0})
		notice = "العدو أنشأ منصة صواريخ"
		notice_time = 2.0
		return
	if not _enemy_has_building("missile_defense") and enemy_credits >= MISSILE_DEFENSE_COST:
		enemy_credits -= MISSILE_DEFENSE_COST
		enemy_buildings.append({"pos": build_pos, "kind": "missile_defense", "hp": 450, "attack_cd": 0.0})
		notice = "العدو نشر دفاعاً صاروخياً"
		notice_time = 2.0
		return
	if not _enemy_has_building("shipyard") and enemy_credits >= 700:
		enemy_credits -= 700
		var naval_site := Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		enemy_buildings.append({"pos": naval_site, "kind": "shipyard", "hp": 500, "attack_cd": 0.0})
		notice = "العدو أنشأ حوض سفن ساحلياً"
		notice_time = 2.0
		return
	if not _enemy_has_building("anti_air") and enemy_credits >= AA_COST:
		enemy_credits -= AA_COST
		enemy_buildings.append({"pos": build_pos, "kind": "anti_air", "hp": 380, "attack_cd": 0.0})
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
		else:
			enemy_infantry += 1

	# Read the player's visible force composition and scale counter-unit limits.
	var player_air_threat := 0
	var player_heavy_ground_threat := 0
	for unit in units:
		if unit.team != "player" or unit.get("hp", 0) <= 0:
			continue
		if unit.kind == "fighter" or unit.kind == "helicopter":
			player_air_threat += 1
		elif unit.kind == "tank" or unit.kind == "artillery":
			player_heavy_ground_threat += 1
	if _enemy_has_building("shipyard") and enemy_credits >= 1600 and enemy_supplies >= 8 and enemy_carriers < 1 and enemy_destroyers >= 1:
		enemy_credits -= 1600
		enemy_supplies -= 8
		var enemy_dock_pos: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": enemy_dock_pos, "team": "enemy", "kind": "carrier", "faction": "الصيني", "hp": 520, "attack_cd": 0.0, "launch_cd": 8.0})
	elif _enemy_has_building("shipyard") and enemy_credits >= 1100 and enemy_supplies >= 5 and enemy_submarines < 1 and enemy_destroyers >= 1:
		enemy_credits -= 1100
		enemy_supplies -= 5
		var enemy_dock_pos: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": enemy_dock_pos, "team": "enemy", "kind": "submarine", "faction": "الصيني", "hp": 210, "attack_cd": 0.0})
	elif _enemy_has_building("shipyard") and enemy_credits >= 800 and enemy_supplies >= 4 and enemy_landing_craft < 1 and enemy_destroyers >= 1:
		enemy_credits -= 800
		enemy_supplies -= 4
		var landing_dock: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": landing_dock, "team": "enemy", "kind": "landing_craft", "faction": "الصيني", "hp": 220, "attack_cd": 0.0, "landed": false})
	elif _enemy_has_building("shipyard") and enemy_credits >= 900 and enemy_supplies >= 4 and enemy_destroyers < 2:
		enemy_credits -= 900
		enemy_supplies -= 4
		var enemy_dock_pos: Vector2 = Vector2(enemy_base.x - 120.0, get_viewport_rect().size.y * 0.82)
		units.append({"pos": enemy_dock_pos, "team": "enemy", "kind": "destroyer", "faction": "الصيني", "hp": 260, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_building("airfield") and enemy_credits >= FIGHTER_COST and enemy_supplies >= 2 and enemy_fighters < (4 if player_air_threat >= 2 else 2):
		enemy_credits -= FIGHTER_COST
		enemy_supplies -= 2
		units.append({"pos": enemy_base + Vector2(-90, randf_range(-75, 75)), "team": "enemy", "kind": "fighter", "hp": 120, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_building("airfield") and enemy_credits >= HELICOPTER_COST and enemy_supplies >= 3 and enemy_helicopters < (3 if player_heavy_ground_threat >= 3 else 2):
		enemy_credits -= HELICOPTER_COST
		enemy_supplies -= 3
		var rival_faction: String = FACTIONS[(FACTIONS.find(faction) + 1) % FACTIONS.size()]
		units.append({"pos": enemy_base + Vector2(-90, randf_range(-75, 75)), "team": "enemy", "kind": "helicopter", "faction": rival_faction, "hp": 180, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_building("factory") and enemy_credits >= ARTILLERY_COST and enemy_supplies >= 2 and enemy_tanks >= 2 and enemy_artillery < (3 if player_heavy_ground_threat >= 4 else 2):
		enemy_credits -= ARTILLERY_COST
		enemy_supplies -= 2
		units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "artillery", "hp": 100, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_building("factory") and enemy_credits >= TANK_COST and enemy_supplies >= 1 and enemy_tanks < (5 if player_heavy_ground_threat >= 4 else 4):
		enemy_credits -= TANK_COST
		enemy_supplies -= 1
		units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "tank", "hp": 150, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_building("barracks") and enemy_credits >= INFANTRY_COST and enemy_infantry < 8:
		enemy_credits -= INFANTRY_COST
		units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "infantry", "hp": 60, "target": base_pos, "attack_cd": 0.0})

func _enemy_build_position() -> Vector2:
	var size := get_viewport_rect().size
	for attempt in 12:
		var candidate := enemy_base + Vector2(randf_range(-185.0, -105.0), randf_range(-175.0, 175.0))
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

func _draw_building(p: Vector2, kind: String, is_enemy: bool = false) -> void:
	var team_color := Color("#4c91d0") if not is_enemy else Color("#d65349")
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
	var label := "حوض سفن" if kind == "shipyard" else ("منصة صواريخ" if kind == "missile_silo" else ("دفاع صاروخي" if kind == "missile_defense" else ("ثكنة" if kind == "barracks" else ("مصنع" if kind == "factory" else ("مطار" if kind == "airfield" else ("مضاد جو" if kind == "anti_air" else "برج دفاع"))))))
	draw_string(ThemeDB.fallback_font, p + Vector2(-42, 43), label, HORIZONTAL_ALIGNMENT_CENTER, 84, 13, Color.WHITE)

func _place_building(pos: Vector2) -> void:
	var cost := 700 if build_mode == "shipyard" else (MISSILE_SILO_COST if build_mode == "missile_silo" else (MISSILE_DEFENSE_COST if build_mode == "missile_defense" else (BARRACKS_COST if build_mode == "barracks" else (FACTORY_COST if build_mode == "factory" else (AIRFIELD_COST if build_mode == "airfield" else (AA_COST if build_mode == "anti_air" else TURRET_COST))))))
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
	buildings.append({"pos": pos, "kind": build_mode, "hp": 500 if build_mode == "missile_silo" else (450 if build_mode == "missile_defense" else 400), "attack_cd": 0.0})
	var building_name := "حوض السفن" if build_mode == "shipyard" else ("منصة الصواريخ" if build_mode == "missile_silo" else ("الدفاع الصاروخي" if build_mode == "missile_defense" else ("الثكنة" if build_mode == "barracks" else ("المصنع" if build_mode == "factory" else ("المطار" if build_mode == "airfield" else ("الدفاع المضاد للطائرات" if build_mode == "anti_air" else "برج الدفاع"))))))
	notice = "تم إنشاء %s" % building_name
	notice_time = 2.0
	build_mode = ""

func _has_building(kind: String) -> bool:
	for building in buildings:
		if building.kind == kind:
			return true
	return false

func _spawn_unit(kind: String) -> void:
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
	var cost := 1600 if kind == "carrier" else (1100 if kind == "submarine" else (800 if kind == "landing_craft" else (900 if kind == "destroyer" else (INFANTRY_COST if kind == "infantry" else (ARTILLERY_COST if kind == "artillery" else (HELICOPTER_COST if kind == "helicopter" else (FIGHTER_COST if kind == "fighter" else TANK_COST))))))
	var supply_cost := 8 if kind == "carrier" else (5 if kind == "submarine" else (4 if kind == "destroyer" or kind == "landing_craft" else _unit_supply_cost(kind)))
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
	var unit_hp := naval_hp if kind in ["carrier", "submarine", "landing_craft", "destroyer"] else (180 if kind == "helicopter" else (120 if kind == "fighter" else (150 if kind == "tank" else 100)))
	units.append({"pos": unit_spawn, "team": "player", "kind": kind, "faction": faction, "hp": unit_hp, "attack_cd": 0.0, "launch_cd": 16.0})
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
	elif kind == "tank":
		unit_name = "دبابة"
	elif kind == "helicopter":
		unit_name = "مروحية قتالية"
	elif kind == "fighter":
		unit_name = "مقاتلة"
	notice = "تم إنتاج %s" % unit_name
	notice_time = 2.0
