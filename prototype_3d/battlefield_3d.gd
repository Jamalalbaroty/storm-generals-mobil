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

func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_camera()
	_build_lighting()
	_build_showcase_units()

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
			if touch_points.size() == 2:
				var points: Array = touch_points.values()
				last_pinch_distance = points[0].distance_to(points[1])
		else:
			touch_points.erase(touch.index)
			if touch_points.size() < 2:
				last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touch_points.has(drag.index):
			touch_points[drag.index] = drag.position
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
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
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

	var turret := MeshInstance3D.new()
	var turret_mesh := BoxMesh.new()
	turret_mesh.size = Vector3(1.8, 0.62, 2.0)
	turret.mesh = turret_mesh
	turret.position = Vector3(0.0, 1.55, -0.15)
	turret.material_override = _make_armour_material(faction_color.darkened(0.12))
	tank.add_child(turret)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.09
	barrel_mesh.bottom_radius = 0.13
	barrel_mesh.height = 2.5
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 1.58, -1.75)
	barrel.material_override = _make_armour_material(Color(0.16, 0.17, 0.15))
	tank.add_child(barrel)

func _make_armour_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.28
	material.roughness = 0.72
	return material
