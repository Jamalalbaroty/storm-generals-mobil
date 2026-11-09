extends Node3D
## 3D rendering foundation for Storm Generals.
## This is an isolated visual prototype; the production 2D match remains the active scene
## until real faction assets, gameplay conversion, and Android performance are verified.

const ARENA_SIZE := 42.0
const MIN_CAMERA_HEIGHT := 14.0
const MAX_CAMERA_HEIGHT := 48.0

var rts_camera: Camera3D
var camera_focus := Vector3.ZERO
var camera_height := 28.0
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var mouse_pan_active := false
var showcase_turrets: Array[Node3D] = []
var turret_scan_clock := 0.0
var showcase_tanks: Array[Node3D] = []
var selected_tank: Node3D
var selected_destination := Vector3.ZERO
var has_selected_destination := false
var selection_ring: MeshInstance3D
var order_marker: MeshInstance3D
var touch_start_positions: Dictionary = {}
var touch_moved: Dictionary = {}

func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_battlefield_features()
	_build_camera()
	_build_lighting()
	_build_showcase_units()
	_build_order_indicators()

func _process(delta: float) -> void:
	turret_scan_clock += delta
	for i in range(showcase_turrets.size()):
		var pivot := showcase_turrets[i]
		if is_instance_valid(pivot) and i < showcase_tanks.size() and showcase_tanks[i] != selected_tank:
			pivot.rotation.y = sin(turret_scan_clock * 0.42 + float(i) * 2.1) * 0.34
	_update_showcase_orders(delta)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.25, 0.34)
	sky_material.sky_horizon_color = Color(0.62, 0.68, 0.68)
	sky_material.ground_bottom_color = Color(0.12, 0.14, 0.12)
	sky_material.ground_horizon_color = Color(0.42, 0.40, 0.32)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)

func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_SIZE, ARENA_SIZE)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.35, 0.27)
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.12
	add_child(ground)

	# Low-cost boundary markers make the prototype arena readable from the RTS camera.
	for i in range(9):
		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.08, ARENA_SIZE)
		marker.mesh = mesh
		var marker_material := StandardMaterial3D.new()
		marker_material.albedo_color = Color(0.48, 0.43, 0.29, 0.45)
		marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		marker.material_override = marker_material
		marker.position = Vector3(-ARENA_SIZE * 0.5 + i * 5.25, -0.04, 0.0)
		add_child(marker)


func _build_battlefield_features() -> void:
	# Low-poly terrain berms: restrained geometry keeps the Android prototype lightweight.
	var berm_material := StandardMaterial3D.new()
	berm_material.albedo_color = Color(0.29, 0.30, 0.23)
	berm_material.roughness = 1.0
	for spec in [
		[Vector3(-15.0, 0.45, -13.0), Vector3(9.0, 0.9, 5.0)],
		[Vector3(14.0, 0.32, -14.0), Vector3(7.0, 0.64, 4.0)],
		[Vector3(-16.0, 0.28, 14.0), Vector3(8.0, 0.56, 5.0)],
		[Vector3(15.0, 0.38, 14.0), Vector3(10.0, 0.76, 5.0)]
	]:
		var berm := MeshInstance3D.new()
		var berm_mesh := BoxMesh.new()
		berm_mesh.size = spec[1]
		berm.mesh = berm_mesh
		berm.position = spec[0]
		berm.material_override = berm_material
		add_child(berm)

	# Two broad access roads crossing the arena.
	_add_road(Vector3(0.0, -0.045, 0.0), Vector2(5.2, ARENA_SIZE), 0.0)
	_add_road(Vector3(0.0, -0.04, 0.0), Vector2(ARENA_SIZE, 4.2), 0.0)
	_add_road_markings()

	# Compact field outposts placed away from the showcase vehicles.
	_add_field_structure(Vector3(-14.0, 0.0, -7.0), Vector3(5.0, 2.8, 4.0), Color(0.34, 0.38, 0.30), true)
	_add_field_structure(Vector3(14.0, 0.0, 8.0), Vector3(5.0, 3.2, 4.5), Color(0.39, 0.36, 0.29), false)
	_add_watch_tower(Vector3(17.0, 0.0, -15.0))
	_add_watch_tower(Vector3(-17.0, 0.0, 16.0))

func _add_road(at: Vector3, dimensions: Vector2, _angle: float) -> void:
	var road := MeshInstance3D.new()
	var road_mesh := PlaneMesh.new()
	road_mesh.size = dimensions
	road.mesh = road_mesh
	var road_material := StandardMaterial3D.new()
	road_material.albedo_color = Color(0.19, 0.20, 0.18)
	road_material.roughness = 1.0
	road.material_override = road_material
	road.position = at
	add_child(road)

func _add_road_markings() -> void:
	var marking_material := StandardMaterial3D.new()
	marking_material.albedo_color = Color(0.66, 0.59, 0.37)
	for i in range(9):
		var dash := MeshInstance3D.new()
		var dash_mesh := BoxMesh.new()
		dash_mesh.size = Vector3(0.16, 0.025, 1.5)
		dash.mesh = dash_mesh
		dash.material_override = marking_material
		dash.position = Vector3(0.0, 0.015, -18.0 + i * 4.5)
		add_child(dash)

func _add_field_structure(at: Vector3, dimensions: Vector3, tint: Color, has_radar: bool) -> void:
	var building := Node3D.new()
	building.position = at
	add_child(building)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = dimensions
	body.mesh = body_mesh
	body.position.y = dimensions.y * 0.5
	body.material_override = _make_armour_material(tint)
	building.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(dimensions.x * 0.82, 0.22, dimensions.z * 0.82)
	roof.mesh = roof_mesh
	roof.position.y = dimensions.y + 0.11
	roof.material_override = _make_armour_material(tint.darkened(0.28))
	building.add_child(roof)

	if has_radar:
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.08
		mast_mesh.bottom_radius = 0.12
		mast_mesh.height = 2.8
		mast.mesh = mast_mesh
		mast.position = Vector3(0.0, dimensions.y + 1.5, 0.0)
		mast.material_override = _make_armour_material(Color(0.15, 0.17, 0.16))
		building.add_child(mast)

func _add_watch_tower(at: Vector3) -> void:
	var tower := Node3D.new()
	tower.position = at
	add_child(tower)

	var leg_material := _make_armour_material(Color(0.22, 0.24, 0.21))
	for offset in [Vector3(-0.65, 1.3, -0.65), Vector3(0.65, 1.3, -0.65), Vector3(-0.65, 1.3, 0.65), Vector3(0.65, 1.3, 0.65)]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.18, 2.6, 0.18)
		leg.mesh = leg_mesh
		leg.position = offset
		leg.material_override = leg_material
		tower.add_child(leg)

	var platform := MeshInstance3D.new()
	var platform_mesh := BoxMesh.new()
	platform_mesh.size = Vector3(2.0, 0.28, 2.0)
	platform.mesh = platform_mesh
	platform.position.y = 2.65
	platform.material_override = _make_armour_material(Color(0.32, 0.34, 0.29))
	tower.add_child(platform)

func _build_camera() -> void:
	rts_camera = Camera3D.new()
	rts_camera.name = "RTSCamera"
	rts_camera.fov = 48.0
	rts_camera.current = true
	add_child(rts_camera)
	_update_camera_pose()

func _update_camera_pose() -> void:
	if not is_instance_valid(rts_camera):
		return
	rts_camera.position = camera_focus + Vector3(0.0, camera_height, camera_height * 1.07)
	rts_camera.look_at(camera_focus, Vector3.UP)

func _zoom_camera(factor: float) -> void:
	camera_height = clampf(camera_height * factor, MIN_CAMERA_HEIGHT, MAX_CAMERA_HEIGHT)
	_update_camera_pose()

func _pan_camera(screen_delta: Vector2) -> void:
	if not is_instance_valid(rts_camera):
		return
	var right := rts_camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var back := rts_camera.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	var world_delta := (-right * screen_delta.x + back * screen_delta.y) * (camera_height / 850.0)
	camera_focus.x = clampf(camera_focus.x + world_delta.x, -ARENA_SIZE * 0.42, ARENA_SIZE * 0.42)
	camera_focus.z = clampf(camera_focus.z + world_delta.z, -ARENA_SIZE * 0.42, ARENA_SIZE * 0.42)
	_update_camera_pose()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touch_points[touch.index] = touch.position
			touch_start_positions[touch.index] = touch.position
			touch_moved[touch.index] = false
			if touch_points.size() == 2:
				var points: Array = touch_points.values()
				last_pinch_distance = points[0].distance_to(points[1])
		else:
			var was_tap := touch_start_positions.has(touch.index) and not touch_moved.get(touch.index, true) and touch_points.size() == 1
			if was_tap:
				_handle_world_tap(touch.position)
			touch_points.erase(touch.index)
			touch_start_positions.erase(touch.index)
			touch_moved.erase(touch.index)
			if touch_points.size() < 2:
				last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touch_points.has(drag.index):
			touch_points[drag.index] = drag.position
		if touch_start_positions.has(drag.index) and drag.position.distance_to(touch_start_positions[drag.index]) > 12.0:
			touch_moved[drag.index] = true
		if touch_points.size() >= 2:
			var points: Array = touch_points.values()
			var distance: float = points[0].distance_to(points[1])
			if last_pinch_distance > 0.0 and distance > 1.0:
				_zoom_camera(last_pinch_distance / distance)
			last_pinch_distance = distance
		elif touch_points.size() == 1:
			_pan_camera(drag.relative)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_handle_world_tap(mouse_button.position)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_camera(0.90)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_camera(1.10)
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_pan_active = mouse_button.pressed
	elif event is InputEventMouseMotion and mouse_pan_active:
		_pan_camera((event as InputEventMouseMotion).relative)

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _build_showcase_units() -> void:
	_add_placeholder_tank(Vector3(-7.0, 0.0, 1.0), Color(0.28, 0.34, 0.22))
	_add_placeholder_tank(Vector3(0.0, 0.0, -2.0), Color(0.34, 0.37, 0.40))
	_add_placeholder_tank(Vector3(7.0, 0.0, 1.0), Color(0.48, 0.39, 0.25))

func _add_placeholder_tank(at: Vector3, faction_color: Color) -> void:
	var tank := Node3D.new()
	tank.position = at
	add_child(tank)
	showcase_tanks.append(tank)

	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(3.0, 0.8, 4.4)
	hull.mesh = hull_mesh
	hull.position.y = 0.85
	hull.material_override = _make_armour_material(faction_color)
	tank.add_child(hull)

	for side in [-1.0, 1.0]:
		var track := MeshInstance3D.new()
		var track_mesh := BoxMesh.new()
		track_mesh.size = Vector3(0.48, 0.72, 4.6)
		track.mesh = track_mesh
		track.position = Vector3(side * 1.62, 0.55, 0.0)
		track.material_override = _make_armour_material(Color(0.12, 0.13, 0.12))
		tank.add_child(track)

	# Rotating turret pivot keeps the gun and armour aligned while scanning.
	var turret_pivot := Node3D.new()
	turret_pivot.position = Vector3(0.0, 1.55, -0.15)
	tank.add_child(turret_pivot)
	showcase_turrets.append(turret_pivot)

	var turret := MeshInstance3D.new()
	var turret_mesh := BoxMesh.new()
	turret_mesh.size = Vector3(1.8, 0.62, 2.0)
	turret.mesh = turret_mesh
	turret.position.y = 0.0
	turret.material_override = _make_armour_material(faction_color.darkened(0.12))
	turret_pivot.add_child(turret)

	var mantlet := MeshInstance3D.new()
	var mantlet_mesh := CylinderMesh.new()
	mantlet_mesh.top_radius = 0.28
	mantlet_mesh.bottom_radius = 0.28
	mantlet_mesh.height = 0.72
	mantlet.mesh = mantlet_mesh
	mantlet.rotation_degrees.z = 90.0
	mantlet.position = Vector3(0.0, 0.02, -0.92)
	mantlet.material_override = _make_armour_material(Color(0.18, 0.19, 0.17))
	turret_pivot.add_child(mantlet)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.085
	barrel_mesh.bottom_radius = 0.13
	barrel_mesh.height = 2.7
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 0.04, -2.05)
	barrel.material_override = _make_armour_material(Color(0.16, 0.17, 0.15))
	turret_pivot.add_child(barrel)

	# Low-profile commander's hatch and sight block add readable tank silhouettes.
	var hatch := MeshInstance3D.new()
	var hatch_mesh := CylinderMesh.new()
	hatch_mesh.top_radius = 0.24
	hatch_mesh.bottom_radius = 0.24
	hatch_mesh.height = 0.12
	hatch.mesh = hatch_mesh
	hatch.position = Vector3(-0.48, 0.36, 0.18)
	hatch.material_override = _make_armour_material(faction_color.lightened(0.08))
	turret_pivot.add_child(hatch)

	var sight := MeshInstance3D.new()
	var sight_mesh := BoxMesh.new()
	sight_mesh.size = Vector3(0.34, 0.18, 0.28)
	sight.mesh = sight_mesh
	sight.position = Vector3(0.48, 0.34, 0.35)
	sight.material_override = _make_armour_material(Color(0.10, 0.13, 0.12))
	turret_pivot.add_child(sight)

	# Six road wheels per side, partially visible beneath the tracks.
	for side in [-1.0, 1.0]:
		for wheel_index in range(6):
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.34
			wheel_mesh.bottom_radius = 0.34
			wheel_mesh.height = 0.16
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(side * 1.78, 0.48, -1.65 + wheel_index * 0.66)
			wheel.material_override = _make_armour_material(Color(0.19, 0.20, 0.18))
			tank.add_child(wheel)


func _build_order_indicators() -> void:
	selection_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.82
	ring_mesh.outer_radius = 1.98
	selection_ring.mesh = ring_mesh
	selection_ring.rotation_degrees.x = 90.0
	selection_ring.position.y = 0.08
	selection_ring.material_override = _make_armour_material(Color(0.24, 0.82, 0.42))
	selection_ring.visible = false
	add_child(selection_ring)

	order_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.48
	marker_mesh.bottom_radius = 0.48
	marker_mesh.height = 0.035
	order_marker.mesh = marker_mesh
	order_marker.position.y = 0.04
	order_marker.material_override = _make_armour_material(Color(0.92, 0.76, 0.25))
	order_marker.visible = false
	add_child(order_marker)

func _handle_world_tap(screen_position: Vector2) -> void:
	var tapped_tank := _tank_at_screen_position(screen_position)
	if tapped_tank != null:
		selected_tank = tapped_tank
		has_selected_destination = false
		selection_ring.visible = true
		order_marker.visible = false
		return
	if selected_tank == null:
		return
	var ground_point: Variant = _screen_to_ground(screen_position)
	if ground_point == null:
		return
	selected_destination = Vector3(
		clampf(ground_point.x, -ARENA_SIZE * 0.42, ARENA_SIZE * 0.42),
		0.0,
		clampf(ground_point.z, -ARENA_SIZE * 0.42, ARENA_SIZE * 0.42)
	)
	has_selected_destination = true
	order_marker.position = selected_destination + Vector3.UP * 0.04
	order_marker.visible = true

func _tank_at_screen_position(screen_position: Vector2) -> Node3D:
	if not is_instance_valid(rts_camera):
		return null
	var nearest: Node3D
	var nearest_distance := 68.0
	for tank in showcase_tanks:
		if not is_instance_valid(tank) or rts_camera.is_position_behind(tank.global_position):
			continue
		var tank_screen := rts_camera.unproject_position(tank.global_position + Vector3.UP * 1.0)
		var distance := tank_screen.distance_to(screen_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = tank
	return nearest

func _screen_to_ground(screen_position: Vector2) -> Variant:
	var ray_origin := rts_camera.project_ray_origin(screen_position)
	var ray_direction := rts_camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return null
	return Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)

func _update_showcase_orders(delta: float) -> void:
	if not is_instance_valid(selected_tank):
		selected_tank = null
		selection_ring.visible = false
		return
	selection_ring.global_position = selected_tank.global_position + Vector3.UP * 0.08
	if not has_selected_destination:
		return
	var direction := selected_destination - selected_tank.global_position
	direction.y = 0.0
	if direction.length() < 0.22:
		selected_tank.global_position = selected_destination
		has_selected_destination = false
		order_marker.visible = false
		return
	var heading := direction.normalized()
	selected_tank.global_position += heading * minf(3.2 * delta, direction.length())
	selected_tank.rotation.y = atan2(-heading.x, -heading.z)

func _make_armour_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.28
	material.roughness = 0.72
	return material
