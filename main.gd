extends Node2D

const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]
const INFANTRY_COST := 100
const TANK_COST := 300

var faction := ""
var credits := 1000
var units: Array[Dictionary] = []
var selected: Array[int] = []
var notice := "اختر جيشك لبدء المعركة"
var notice_time := 4.0
var enemy_timer := 0.0
var game_started := false
var dragging := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var base_pos := Vector2(180, 330)
var enemy_base := Vector2(1090, 330)

func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _process(delta: float) -> void:
	if notice_time > 0.0:
		notice_time -= delta
	if game_started:
		enemy_timer += delta
		if enemy_timer >= 16.0:
			enemy_timer = 0.0
			units.append({"pos": enemy_base + Vector2(-75, randf_range(-75, 75)), "team": "enemy", "kind": "infantry", "hp": 60, "target": base_pos, "attack_cd": 0.0})
		for i in units.size():
			var unit := units[i]
			if unit.get("hp", 0) <= 0:
				continue
			if unit.team == "enemy":
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
				elif distance_to_target > 34.0:
					unit.pos += (destination - unit.pos).normalized() * delta * 22.0
			elif unit.team == "player":
				var enemy_target := int(unit.get("attack_target", -1))
				if enemy_target < 0 or enemy_target >= units.size() or units[enemy_target].team != "enemy" or units[enemy_target].get("hp", 0) <= 0:
					enemy_target = _nearest_enemy_unit(unit.pos, 220.0)
					if enemy_target >= 0:
						unit.attack_target = enemy_target
				if enemy_target >= 0:
					var enemy: Dictionary = units[enemy_target]
					var distance := unit.pos.distance_to(enemy.pos)
					if distance <= 160.0:
						unit.attack_cd = unit.get("attack_cd", 0.0) - delta
						if unit.attack_cd <= 0.0:
							enemy.hp -= 20 if unit.kind == "tank" else 10
							unit.attack_cd = 0.75 if unit.kind == "tank" else 1.0
					else:
						unit.pos += (enemy.pos - unit.pos).normalized() * delta * (55.0 if unit.kind == "infantry" else 36.0)
				elif unit.has("target"):
					var target: Vector2 = unit.target
					if unit.pos.distance_to(target) > 8.0:
						unit.pos += (target - unit.pos).normalized() * delta * (55.0 if unit.kind == "infantry" else 36.0)
		queue_redraw()

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
	for i in units.size():
		var u := units[i]
		if u.get("hp", 0) <= 0:
			continue
		var c := Color("#e7e7d8") if u.team == "player" else Color("#d84a3f")
		if u.kind == "tank":
			draw_rect(Rect2(u.pos - Vector2(17, 11), Vector2(34, 22)), c)
			draw_line(u.pos, u.pos + Vector2(24, 0), Color.BLACK, 5)
		else:
			draw_circle(u.pos, 9, c)
			draw_line(u.pos, u.pos + Vector2(14, -5), Color("#242424"), 3)
		var hp_ratio := clampf(float(u.get("hp", 0)) / (100.0 if u.team == "player" else 60.0), 0.0, 1.0)
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32, 4)), Color("#352c2a"))
		draw_rect(Rect2(u.pos + Vector2(-16, -25), Vector2(32.0 * hp_ratio, 4)), Color("#5ed16f") if hp_ratio > 0.35 else Color("#e85c4a"))
		if selected.has(i):
			draw_arc(u.pos, 17, 0, TAU, 32, Color("#ffe45c"), 3)
	_draw_hud(size)
	if dragging:
		draw_rect(Rect2(drag_start, drag_end - drag_start), Color(0.3, 0.8, 1, 0.13), true)
		draw_rect(Rect2(drag_start, drag_end - drag_start), Color("#9fe7ff"), false, 2)
	if not game_started:
		_draw_faction_picker(size)
	elif notice_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.35, 82), notice, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.3, 23, Color.WHITE)

func _draw_base(p: Vector2, color: Color, label: String) -> void:
	draw_rect(Rect2(p - Vector2(48, 42), Vector2(96, 84)), Color("#343b35"))
	draw_rect(Rect2(p - Vector2(40, 34), Vector2(80, 68)), color)
	draw_rect(Rect2(p - Vector2(18, 54), Vector2(36, 20)), Color("#c7c6b3"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-48, 66), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 16, Color.WHITE)

func _draw_hud(size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, 58), Color(0.06, 0.08, 0.09, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(22, 38), "STORM GENERALS", HORIZONTAL_ALIGNMENT_LEFT, 300, 25, Color("#f4d77a"))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 230, 38), "الذهب: %d" % credits, HORIZONTAL_ALIGNMENT_LEFT, 200, 22, Color.WHITE)
	if game_started:
		var labels := ["مشاة  100", "دبابة  300", "إلغاء التحديد"]
		for i in 3:
			var r := _button_rect(i, size)
			draw_rect(r, Color("#263d50"), true)
			draw_rect(r, Color("#8fa8b8"), false, 2)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(12, 34), labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 24, 19, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 18), "المس الوحدة لتحديدها • اسحب لتحديد عدة وحدات • المس الأرض لإصدار أمر الحركة", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 17, Color.WHITE)

func _button_rect(index: int, size: Vector2) -> Rect2:
	return Rect2(Vector2(size.x - 510 + index * 165, size.y - 78), Vector2(150, 54))

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
	if not game_started:
		for i in FACTIONS.size():
			if _faction_rect(i, size).has_point(pos):
				faction = FACTIONS[i]
				game_started = true
				notice = "بدأت المعركة — %s" % faction
				notice_time = 3.0
				queue_redraw()
				return
		return
	for i in 3:
		if _button_rect(i, size).has_point(pos):
			if i == 0:
				_spawn_unit("infantry")
			elif i == 1:
				_spawn_unit("tank")
			else:
				selected.clear()
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
		if enemy_found >= 0 and not selected.is_empty():
			for idx in selected:
				if idx < units.size() and units[idx].team == "player":
					units[idx].attack_target = enemy_found
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
	queue_redraw()

func _spawn_unit(kind: String) -> void:
	var cost := INFANTRY_COST if kind == "infantry" else TANK_COST
	if credits < cost:
		notice = "لا توجد موارد كافية"
		notice_time = 2.0
		return
	credits -= cost
	units.append({"pos": base_pos + Vector2(65, randf_range(-35, 35)), "team": "player", "kind": kind, "hp": 100, "attack_cd": 0.0})
	notice = "تم إنتاج %s" % ("جندي" if kind == "infantry" else "دبابة")
	notice_time = 2.0
