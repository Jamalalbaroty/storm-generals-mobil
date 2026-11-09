extends Node2D

const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const INFANTRY_COST := 100
const TANK_COST := 300
const STARTING_CREDITS := 1200
const PASSIVE_INCOME := 6.0
const MAX_CREDITS := 5000
const BARRACKS_COST := 250
const FACTORY_COST := 450
const TURRET_COST := 350
const ARTILLERY_COST := 450

var faction := ""
var credits := STARTING_CREDITS
var income_timer := 0.0
var units: Array[Dictionary] = []
var selected: Array[int] = []
var buildings: Array[Dictionary] = []
var build_mode := ""
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

func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _process(delta: float) -> void:
	if notice_time > 0.0:
		notice_time -= delta
	for effect_index in range(visual_effects.size() - 1, -1, -1):
		visual_effects[effect_index].life = float(visual_effects[effect_index].life) - delta
		if visual_effects[effect_index].life <= 0.0:
			visual_effects.remove_at(effect_index)
	if game_started:
		if battle_result != "":
			return
		income_timer += delta
		if income_timer >= 1.0:
			credits = mini(MAX_CREDITS, credits + int(PASSIVE_INCOME * income_timer))
			income_timer = 0.0
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
			if building.kind == "turret":
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var target := _nearest_enemy_unit(building.pos, 230.0)
				if target >= 0 and building.attack_cd <= 0.0:
					units[target].hp -= 18
					_add_visual_effect("tracer", building.pos, units[target].pos, Color("#ffd27a"), 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, Color("#ffb34d"), 0.22, 13.0)
					building.attack_cd = 0.8
		for building in enemy_buildings:
			if building.kind == "turret":
				building.attack_cd = building.get("attack_cd", 0.0) - delta
				var target := _nearest_player_unit(building.pos)
				if target >= 0 and building.pos.distance_to(units[target].pos) <= 230.0 and building.attack_cd <= 0.0:
					units[target].hp -= 16
					_add_visual_effect("tracer", building.pos, units[target].pos, Color("#ff8b72"), 0.16, 0.0)
					_add_visual_effect("flash", units[target].pos, units[target].pos, Color("#ff704d"), 0.22, 12.0)
					building.attack_cd = 0.9
		for i in units.size():
			var unit := units[i]
			if unit.get("hp", 0) <= 0:
				continue
			if unit.team == "enemy":
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
				var distance_to_target := unit.pos.distance_to(destination)
				if player_target >= 0 and distance_to_target <= 150.0:
					unit.attack_cd = unit.get("attack_cd", 0.0) - delta
					if unit.attack_cd <= 0.0:
						units[player_target].hp -= 10
						unit.attack_cd = 0.9
				elif player_target < 0 and distance_to_target <= 145.0:
					unit.attack_cd = unit.get("attack_cd", 0.0) - delta
					if unit.attack_cd <= 0.0:
						player_base_hp = maxi(0, player_base_hp - 10)
						unit.attack_cd = 0.9
				elif distance_to_target > 34.0:
					unit.pos += (destination - unit.pos).normalized() * delta * 22.0
			elif unit.team == "player":
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
				if enemy_target < 0 or enemy_target >= units.size() or units[enemy_target].team != "enemy" or units[enemy_target].get("hp", 0) <= 0:
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
								enemy.hp -= 20 if unit.kind == "tank" else 10
								_add_visual_effect("tracer", unit.pos, enemy.pos, Color("#ffe0a0"), 0.14, 0.0)
								_add_visual_effect("flash", enemy.pos, enemy.pos, Color("#ffb34d"), 0.18, 8.0)
								unit.attack_cd = 0.75 if unit.kind == "tank" else 1.0
					else:
						unit.pos += (enemy.pos - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
				elif unit.has("target"):
					var target: Vector2 = unit.target
					if unit.pos.distance_to(target) > 8.0:
						unit.pos += (target - unit.pos).normalized() * delta * (22.0 if unit.kind == "artillery" else (55.0 if unit.kind == "infantry" else 36.0))
		queue_redraw()

func _add_visual_effect(kind: String, start: Vector2, finish: Vector2, tint: Color, duration: float, radius: float) -> void:
	visual_effects.append({
		"kind": kind,
		"start": start,
		"finish": finish,
		"color": tint,
		"life": duration,
		"duration": duration,
		"radius": radius
	})

func _apply_splash_damage(center: Vector2, radius: float, damage: int, target_team: String) -> void:
	for unit in units:
		if unit.team == target_team and unit.get("hp", 0) > 0 and unit.pos.distance_to(center) <= radius:
			unit.hp = maxi(0, int(unit.hp) - damage)

func _nearest_player_unit(from_pos: Vector2) -> int:
	var best_index := -1
	var best_distance := INF
	for i in units.size():
		if units[i].team != "player" or units[i].get("hp", 0) <= 0:
			continue
		var distance := from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _nearest_enemy_unit(from_pos: Vector2, max_distance: float) -> int:
	var best_index := -1
	var best_distance := max_distance
	for i in units.size():
		if units[i].team != "enemy" or units[i].get("hp", 0) <= 0:
			continue
		var distance := from_pos.distance_to(units[i].pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#526b45"))
	for x in range(0, int(size.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.035), 1)
	for y in range(0, int(size.y), 64):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.035), 1)
	# Main road and terrain details
	draw_rect(Rect2(0, 292, size.x, 76), Color("#8b8064"))
	draw_rect(Rect2(0, 300, size.x, 60), Color("#a99a76"))
	for i in range(18):
		var p := Vector2(40 + i * 71, 80 + float((i * 47) % 510))
		draw_circle(p, 13, Color("#304b32"))
		draw_circle(p + Vector2(-5, -5), 8, Color("#426b3e"))
	_draw_base(base_pos, Color("#3977bd"), "قاعدتك")
	_draw_base(enemy_base, Color("#b94b42"), "قاعدة العدو")
	_draw_base_health(base_pos, player_base_hp)
	_draw_base_health(enemy_base, enemy_base_hp)
	for building in buildings:
		_draw_building(building.pos, building.kind, false)
	for building in enemy_buildings:
		_draw_building(building.pos, building.kind, true)
	for i in units.size():
		var u := units[i]
		if u.get("hp", 0) <= 0:
			continue
		var c := Color("#e7e7d8") if u.team == "player" else Color("#d84a3f")
		if u.kind == "tank":
			draw_rect(Rect2(u.pos - Vector2(17, 11), Vector2(34, 22)), c)
			draw_line(u.pos, u.pos + Vector2(24, 0), Color.BLACK, 5)
		elif u.kind == "artillery":
			draw_rect(Rect2(u.pos - Vector2(16, 9), Vector2(32, 18)), c)
			draw_circle(u.pos + Vector2(-10, 11), 5, Color("#252525"))
			draw_circle(u.pos + Vector2(10, 11), 5, Color("#252525"))
			draw_line(u.pos, u.pos + Vector2(30, -14), Color("#252525"), 5)
		else:
			draw_circle(u.pos, 9, c)
			draw_line(u.pos, u.pos + Vector2(14, -5), Color("#242424"), 3)
		var max_hp := 150.0 if u.kind == "tank" else (100.0 if u.kind == "artillery" or u.team == "player" else 60.0)
		var hp_ratio := clampf(float(u.get("hp", 0)) / max_hp, 0.0, 1.0)
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32, 4)), Color("#352c2a"))
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32.0 * hp_ratio, 4)), Color("#5ed16f") if hp_ratio > 0.35 else Color("#e85c4a"))
		if selected.has(i):
			draw_arc(u.pos, 17, 0, TAU, 32, Color("#ffe45c"), 3)
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
			draw_circle(effect.finish, blast_radius, Color(tint.r, tint.g * 0.62, tint.b * 0.28, fade * 0.42))
			draw_arc(effect.finish, blast_radius, 0.0, TAU, 32, tint, 4.0 * fade + 1.0)
			draw_circle(effect.finish + Vector2(-blast_radius * 0.25, -blast_radius * 0.35), blast_radius * 0.28, Color(0.24, 0.22, 0.2, fade * 0.45))
	_draw_hud(size)
	if dragging:
		draw_rect(Rect2(drag_start, drag_end - drag_start), Color(0.3, 0.8, 1, 0.13), true)
		draw_rect(Rect2(drag_start, drag_end - drag_start), Color("#9fe7ff"), false, 2)
	if not game_started:
		_draw_faction_picker(size)
	elif battle_result != "":
		draw_rect(Rect2(size.x * 0.2, size.y * 0.34, size.x * 0.6, size.y * 0.25), Color(0.02, 0.03, 0.04, 0.94))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.25, size.y * 0.49), battle_result, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.5, 30, Color("#f4d77a"))
	elif notice_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.35, 82), notice, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.3, 23, Color.WHITE)

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
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 270, 38), "الذهب: %d  (+%d/ث)" % [credits, int(PASSIVE_INCOME)], HORIZONTAL_ALIGNMENT_LEFT, 250, 22, Color.WHITE)
	if game_started:
		var labels := ["مشاة 100", "دبابة 300", "ثكنة 250", "مصنع 450", "دفاع 350", "مدفعية 450", "إلغاء"]
		for i in 7:
			var r := _button_rect(i, size)
			draw_rect(r, Color("#263d50"), true)
			draw_rect(r, Color("#8fa8b8"), false, 2)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(12, 34), labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 24, 19, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 18), "المس الوحدة لتحديدها • اسحب لتحديد عدة وحدات • المس الأرض لإصدار أمر الحركة", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 17, Color.WHITE)

func _button_rect(index: int, size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x - 729 + index * 104, size.y - 76), Vector2(100, 52))

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
		return
	if not game_started:
		for i in FACTIONS.size():
			if _faction_rect(i, size).has_point(pos):
				faction = FACTIONS[i]
				battle_result = ""
				credits = STARTING_CREDITS
				income_timer = 0.0
				units.clear()
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
				notice = "بدأت المعركة — %s" % faction
				notice_time = 3.0
				queue_redraw()
				return
		return
	for i in 7:
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
			else:
				selected.clear()
				build_mode = ""
			queue_redraw()
			return
	if build_mode != "":
		_place_building(pos)
		queue_redraw()
		return
	if drag_start.distance_to(pos) > 24.0:
		selected.clear()
		var area := Rect2(drag_start, pos - drag_start).abs()
		for i in units.size():
			if units[i].team == "player" and area.has_point(units[i].pos):
				selected.append(i)
	else:
		var enemy_found := -1
		for i in units.size():
			if units[i].team == "enemy" and units[i].get("hp", 0) > 0 and units[i].pos.distance_to(pos) < 30:
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
	var enemy_tanks := 0
	var enemy_infantry := 0
	var enemy_artillery := 0
	for unit in units:
		if unit.team != "enemy" or unit.get("hp", 0) <= 0:
			continue
		if unit.kind == "tank":
			enemy_tanks += 1
		elif unit.kind == "artillery":
			enemy_artillery += 1
		else:
			enemy_infantry += 1
	if _enemy_has_building("factory") and enemy_credits >= ARTILLERY_COST and enemy_tanks >= 2 and enemy_artillery < 2:
		enemy_credits -= ARTILLERY_COST
		units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "artillery", "hp": 100, "target": base_pos, "attack_cd": 0.0})
	elif _enemy_has_building("factory") and enemy_credits >= TANK_COST and enemy_tanks < 4:
		enemy_credits -= TANK_COST
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
	var color := Color("#b69b68") if kind == "barracks" else (Color("#657b8d") if kind == "factory" else Color("#718b56"))
	if is_enemy:
		color = Color("#a85b52") if kind == "barracks" else (Color("#805b67") if kind == "factory" else Color("#a34b42"))
	var body := Rect2(p - Vector2(27, 22), Vector2(54, 44))
	draw_rect(body, Color("#252b2b"))
	draw_rect(body.grow(-4), color)
	if kind == "turret":
		draw_circle(p, 13, Color("#343b3b"))
		draw_line(p, p + Vector2(25, -8), Color("#d2d1b8"), 6)
	else:
		draw_rect(Rect2(p + Vector2(-9, -17), Vector2(18, 34)), Color("#343b3b"))
	var label := "ثكنة" if kind == "barracks" else ("مصنع" if kind == "factory" else ("مدفعية" if kind == "artillery" else "دفاع"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-35, 39), label, HORIZONTAL_ALIGNMENT_CENTER, 70, 13, Color.WHITE)

func _place_building(pos: Vector2) -> void:
	var cost := BARRACKS_COST if build_mode == "barracks" else (FACTORY_COST if build_mode == "factory" else TURRET_COST)
	if pos.x > get_viewport_rect().size.x * 0.48 or pos.distance_to(base_pos) > 390.0 or pos.distance_to(base_pos) < 85.0:
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
	buildings.append({"pos": pos, "kind": build_mode, "hp": 400})
	notice = "تم إنشاء %s" % ("الثكنة" if build_mode == "barracks" else ("المصنع" if build_mode == "factory" else "برج الدفاع"))
	notice_time = 2.0
	build_mode = ""

func _has_building(kind: String) -> bool:
	for building in buildings:
		if building.kind == kind:
			return true
	return false

func _spawn_unit(kind: String) -> void:
	if kind == "artillery" and not _has_building("factory"):
		notice = "ابنِ مصنعاً أولاً لإنتاج المدفعية"
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
	var cost := INFANTRY_COST if kind == "infantry" else (ARTILLERY_COST if kind == "artillery" else TANK_COST)
	if credits < cost:
		notice = "لا توجد موارد كافية"
		notice_time = 2.0
		return
	credits -= cost
	units.append({"pos": base_pos + Vector2(65, randf_range(-35, 35)), "team": "player", "kind": kind, "hp": 150 if kind == "tank" else 100, "attack_cd": 0.0})
	var unit_name := "جندي" if kind == "infantry" else ("دبابة" if kind == "tank" else "مدفعية")
	notice = "تم إنتاج %s" % unit_name
	notice_time = 2.0
