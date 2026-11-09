extends Node3D
## 3D rendering foundation for Storm Generals.
## This is an isolated visual prototype; the production 2D match remains the active scene
## until real faction assets, gameplay conversion, and Android performance are verified.

const ARENA_SIZE := 42.0

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
	var camera := Camera3D.new()
	camera.name = "RTSCamera"
	camera.position = Vector3(0.0, 28.0, 30.0)
	camera.rotation_degrees = Vector3(-43.0, 0.0, 0.0)
	camera.fov = 48.0
	camera.current = true
	add_child(camera)

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
