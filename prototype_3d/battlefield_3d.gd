extends Node3D
signal gameplay_order_issued(source_key: String, order_type: String, world_position: Vector3, target_key: String)
## 3D rendering foundation for Storm Generals.
## This is an isolated visual prototype; the production 2D match remains the active scene
## until real faction assets, gameplay conversion, and Android performance are verified.

const ARENA_SIZE := 42.0
const NAVAL_PRESENTATION_ENABLED := false
const NAVAL_GAMEPLAY_KINDS := ["destroyer", "carrier", "submarine", "landing_craft"]
const MIN_CAMERA_HEIGHT := 14.0
const MAX_CAMERA_HEIGHT := 48.0

var rts_camera: Camera3D
var sun_light: DirectionalLight3D
var camera_focus := Vector3.ZERO
var camera_height := 28.0
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var last_pinch_center := Vector2.ZERO
var touch_multi_gesture := false
var mouse_pan_active := false
var showcase_turrets: Array[Node3D] = []
var turret_scan_clock := 0.0
var showcase_tanks: Array[Node3D] = []
var selected_tank: Node3D
var selected_live_units: Array[Node3D] = []
var selection_gesture_start := Vector2.ZERO
var selection_gesture_active := false
var selection_gesture_dragging := false
var selected_destination := Vector3.ZERO
var has_selected_destination := false
var selection_ring: MeshInstance3D
var group_selection_rings: Array[MeshInstance3D] = []
var selection_count_label: Label
var order_marker: MeshInstance3D
var order_path_instance: MeshInstance3D
var order_path_mesh: ImmediateMesh
var order_path_material: StandardMaterial3D
var touch_start_positions: Dictionary = {}
var touch_moved: Dictionary = {}
var attack_target: Node3D
var attack_cooldown := 0.0
var showcase_health_bars: Dictionary = {}
var infantry_leg_pairs: Dictionary = {}
var infantry_gait_clock := 0.0
var aircraft_rotors: Array[Node3D] = []
var aircraft_tail_rotors: Array[Node3D] = []
var aircraft_lights: Array[MeshInstance3D] = []
var aircraft_clock := 0.0
var air_defense_nodes: Array[Node3D] = []
var air_defense_cooldowns: Array[float] = []
var radar_nodes: Array[Node3D] = []
var radar_sweeps: Array[Node3D] = []
var radar_blips: Dictionary = {}
var radar_alert_clock := 0.0
var radar_hud: Control
var radar_plot: Control
var radar_status_label: Label
var radar_count_label: Label
var radar_ground_label: Label
var radar_sweep_widget: ColorRect
var radar_blip_widgets: Dictionary = {}
var combat_fire_audio: AudioStreamWAV
var combat_impact_audio: AudioStreamWAV
var engine_audio_player: AudioStreamPlayer3D
var previous_ground_positions: Dictionary = {}
var ground_dust_timers: Dictionary = {}
var ground_dust_nodes: Array[Node3D] = []
var tank_wheels: Dictionary = {}
var tank_barrels: Dictionary = {}
var wheel_last_positions: Dictionary = {}
var game_building_nodes: Dictionary = {}
var game_unit_nodes: Dictionary = {}
var gameplay_effect_nodes: Dictionary = {}
var gameplay_debris_nodes: Array[Node3D] = []
var next_game_unit_sync_id := 1
var naval_propellers: Array[Node3D] = []
var naval_animation_clock := 0.0
var carrier_aircraft: Array[Dictionary] = []
var carrier_aircraft_clock := 0.0

func _ready() -> void:
	combat_fire_audio = _make_combat_audio(false)
	combat_impact_audio = _make_combat_audio(true)
	_build_environment()
	_build_terrain()
	_build_terrain_details()
	_build_battlefield_features()
	_build_camera()
	_build_lighting()
	_build_showcase_units()
	_build_order_indicators()
	_build_tactical_radar_hud()
	_setup_engine_audio()

func _exit_tree() -> void:
	# Stop every generated playback before releasing its stream resources.
	# The live bridge smoke test exercises combat audio and destroys the scene
	# immediately afterwards, so relying on natural playback completion leaks
	# AudioStreamPlayback instances at headless shutdown.
	for audio_node in find_children("*", "AudioStreamPlayer3D", true, false):
		var player := audio_node as AudioStreamPlayer3D
		if player == null:
			continue
		player.stop()
		player.stream = null
	if is_instance_valid(combat_fire_audio):
		combat_fire_audio = null
	if is_instance_valid(combat_impact_audio):
		combat_impact_audio = null
	engine_audio_player = null

func _process(delta: float) -> void:
	turret_scan_clock += delta
	for i in range(showcase_turrets.size()):
		var pivot := showcase_turrets[i]
		if not is_instance_valid(pivot) or i >= showcase_tanks.size():
			continue
		var parent_unit := showcase_tanks[i]
		# Showcase turrets may scan for atmosphere, but live gameplay turrets
		# must be driven only by the authoritative RTS unit record.
		if is_instance_valid(parent_unit) and not bool(parent_unit.get_meta("source_gameplay_unit", false)) and parent_unit != selected_tank:
			pivot.rotation.y = sin(turret_scan_clock * 0.42 + float(i) * 2.1) * 0.34
	_update_showcase_orders(delta)
	_update_gameplay_unit_visuals(delta)
	_update_showcase_combat(delta)
	_update_showcase_health_bars()
	_update_infantry_animation(delta)
	_update_aircraft_animation(delta)
	_update_naval_animation(delta)
	_update_naval_combat(delta)
	_update_carrier_air_operations(delta)
	_update_air_defenses(delta)
	_update_radar_network(delta)
	_update_radar_hud(delta)
	_update_engine_audio()
	_update_ground_vehicle_effects(delta)
	_update_tank_wheel_rotation()

func _make_combat_audio(is_impact: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.38 if is_impact else 0.14
	var sample_count := int(sample_rate * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var envelope := pow(1.0 - progress, 2.4) if not is_impact else pow(1.0 - progress, 1.7)
		var phase := t * (72.0 if is_impact else 145.0)
		var tone := sin(phase * TAU) * (0.72 if is_impact else 0.30)
		var noise_wave := sin(float(i) * 12.9898 + 78.233) * 0.5 + sin(float(i) * 4.1414) * 0.25
		var noise_level := 0.58 if is_impact else 0.88
		var sample := clampf((tone + noise_wave * noise_level) * envelope, -1.0, 1.0)
		samples.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	return stream

func _setup_engine_audio() -> void:
	var sample_rate := 22050
	var sample_count := sample_rate / 2
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var wave := sin(t * TAU * 54.0) * 0.34 + sin(t * TAU * 108.0) * 0.12 + sin(t * TAU * 162.0) * 0.05
		var pulse := 0.82 + 0.18 * sin(t * TAU * 2.0)
		samples.encode_s16(i * 2, int(clampf(wave * pulse, -1.0, 1.0) * 32767.0))
	var engine_stream := AudioStreamWAV.new()
	engine_stream.format = AudioStreamWAV.FORMAT_16_BITS
	engine_stream.mix_rate = sample_rate
	engine_stream.stereo = false
	engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	engine_stream.loop_begin = 0
	engine_stream.loop_end = sample_count
	engine_stream.data = samples
	engine_audio_player = AudioStreamPlayer3D.new()
	engine_audio_player.stream = engine_stream
	engine_audio_player.volume_db = -22.0
	engine_audio_player.unit_size = 12.0
	engine_audio_player.max_distance = 72.0
	add_child(engine_audio_player)

func _update_ground_vehicle_effects(delta: float) -> void:
	for unit in showcase_tanks:
		if not is_instance_valid(unit):
			continue
		var unit_type := String(unit.get_meta("unit_type", "tank"))
		if unit_type not in ["tank", "artillery"]:
			continue
		var previous: Vector3 = previous_ground_positions.get(unit, unit.global_position)
		var movement := unit.global_position.distance_to(previous)
		previous_ground_positions[unit] = unit.global_position
		var cooldown := maxf(0.0, float(ground_dust_timers.get(unit, 0.0)) - delta)
		if movement > 0.015 and cooldown <= 0.0:
			var rear := unit.global_transform.basis.z
			var track_spacing := 0.82 if unit_type == "tank" else 0.68
			var trail_offset := 1.45 if unit_type == "tank" else 1.15
			_spawn_track_dust(unit.global_position + rear * trail_offset + Vector3.LEFT * track_spacing)
			_spawn_track_dust(unit.global_position + rear * trail_offset + Vector3.RIGHT * track_spacing)
			cooldown = 0.20 if bool(unit.get_meta("source_gameplay_unit", false)) else 0.16
		ground_dust_timers[unit] = cooldown
	for unit in previous_ground_positions.keys():
		if not is_instance_valid(unit):
			previous_ground_positions.erase(unit)
			ground_dust_timers.erase(unit)
	for dust_variant in ground_dust_nodes.duplicate():
		if not is_instance_valid(dust_variant):
			ground_dust_nodes.erase(dust_variant)

func _spawn_track_dust(at: Vector3) -> void:
	# A strict cap keeps movement trails inexpensive with many live RTS vehicles.
	while ground_dust_nodes.size() >= 32:
		var oldest := ground_dust_nodes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var puff := MeshInstance3D.new()
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.24
	puff_mesh.height = 0.20
	puff.mesh = puff_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.43, 0.32, 0.30)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = material
	puff.position = at + Vector3.UP * 0.12
	puff.scale = Vector3(0.35, 0.24, 0.35)
	add_child(puff)
	ground_dust_nodes.append(puff)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector3(1.45, 0.58, 1.45), 0.62)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.62)
	tween.chain().tween_callback(_remove_track_dust.bind(puff))


func _remove_track_dust(puff: Node3D) -> void:
	ground_dust_nodes.erase(puff)
	if is_instance_valid(puff):
		puff.queue_free()

func _update_engine_audio() -> void:
	if not is_instance_valid(engine_audio_player):
		return
	if not is_instance_valid(selected_tank) or not has_selected_destination:
		if engine_audio_player.playing:
			engine_audio_player.stop()
		return
	var unit_type := str(selected_tank.get_meta("unit_type", "tank"))
	if unit_type == "infantry":
		if engine_audio_player.playing:
			engine_audio_player.stop()
		return
	engine_audio_player.global_position = selected_tank.global_position
	engine_audio_player.volume_db = -17.0 if unit_type == "tank" else -20.0
	if not engine_audio_player.playing:
		engine_audio_player.play()

func _play_combat_audio(at: Vector3, is_impact: bool) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = combat_impact_audio if is_impact else combat_fire_audio
	player.volume_db = -8.0 if is_impact else -11.0
	player.unit_size = 9.0
	player.max_distance = 58.0
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()

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

	# A shallow coastal shelf gives naval units a dedicated, readable operating area.
	var water := MeshInstance3D.new()
	water.name = "CoastalWater"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(ARENA_SIZE, ARENA_SIZE * 0.415)
	water.mesh = water_mesh
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.035, 0.14, 0.19)
	water_material.roughness = 0.28
	water_material.metallic = 0.12
	water_material.emission_enabled = true
	water_material.emission = Color(0.008, 0.035, 0.05)
	water_material.emission_energy_multiplier = 0.35
	water.material_override = water_material
	water.position = Vector3(0.0, -0.085, ARENA_SIZE * 0.2925)
	add_child(water)

	var shoreline := MeshInstance3D.new()
	shoreline.name = "CoastalShore"
	var shore_mesh := BoxMesh.new()
	shore_mesh.size = Vector3(ARENA_SIZE, 0.075, 2.2)
	shoreline.mesh = shore_mesh
	shoreline.position = Vector3(0.0, -0.055, 2.45)
	shoreline.material_override = _make_armour_material(Color(0.53, 0.46, 0.32))
	add_child(shoreline)

	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_color = Color(0.54, 0.72, 0.72, 0.34)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for foam_index in range(5):
		var foam := MeshInstance3D.new()
		var foam_mesh := BoxMesh.new()
		foam_mesh.size = Vector3(5.5 + float(foam_index % 2) * 2.0, 0.025, 0.045)
		foam.mesh = foam_mesh
		foam.position = Vector3(-13.0 + float(foam_index) * 6.3, -0.035, 4.2 + float(foam_index % 2) * 0.32)
		foam.material_override = foam_material
		add_child(foam)

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


func _build_terrain_details() -> void:
	# Deterministic low-poly scatter adds scale and texture without spawning
	# dozens of independent scene nodes on mobile devices.
	var rock_positions: Array[Vector3] = [
		Vector3(-16.0, 0.12, -8.0), Vector3(-11.5, 0.12, -15.0),
		Vector3(-7.0, 0.12, -11.0), Vector3(-4.5, 0.12, -16.0),
		Vector3(5.0, 0.12, -13.0), Vector3(10.5, 0.12, -9.0),
		Vector3(14.0, 0.12, -5.0), Vector3(-15.0, 0.12, 7.0),
		Vector3(-10.0, 0.12, 13.0), Vector3(-5.0, 0.12, 8.0),
		Vector3(5.0, 0.12, 9.0), Vector3(9.0, 0.12, 15.0),
		Vector3(14.0, 0.12, 8.0), Vector3(16.0, 0.12, -15.0)
	]
	var scrub_positions: Array[Vector3] = [
		Vector3(-17.0, 0.08, -15.0), Vector3(-13.0, 0.08, -5.5),
		Vector3(-8.0, 0.08, -18.0), Vector3(-5.5, 0.08, -7.0),
		Vector3(7.0, 0.08, -18.0), Vector3(12.0, 0.08, -14.0),
		Vector3(17.0, 0.08, -10.0), Vector3(-17.0, 0.08, 12.0),
		Vector3(-12.0, 0.08, 17.0), Vector3(-7.0, 0.08, 14.0),
		Vector3(6.0, 0.08, 16.0), Vector3(11.0, 0.08, 11.0),
		Vector3(17.0, 0.08, 13.0), Vector3(15.0, 0.08, 3.5)
	]
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.42
	rock_mesh.height = 0.58
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.35, 0.33, 0.27)
	rock_material.roughness = 1.0
	_add_terrain_scatter("TerrainRockScatter", rock_positions, rock_mesh, rock_material, Vector3(1.0, 0.72, 0.9))
	var scrub_mesh := SphereMesh.new()
	scrub_mesh.radius = 0.48
	scrub_mesh.height = 0.52
	scrub_mesh.radial_segments = 5
	scrub_mesh.rings = 2
	var scrub_material := StandardMaterial3D.new()
	scrub_material.albedo_color = Color(0.30, 0.34, 0.22)
	scrub_material.roughness = 1.0
	_add_terrain_scatter("TerrainScrubScatter", scrub_positions, scrub_mesh, scrub_material, Vector3(1.15, 0.42, 0.9))


func _add_terrain_scatter(scatter_name: String, positions: Array[Vector3], mesh: Mesh, material: Material, base_scale: Vector3) -> void:
	var scatter := MultiMeshInstance3D.new()
	scatter.name = scatter_name
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = positions.size()
	for i in range(positions.size()):
		var variation := 0.78 + float((i * 7) % 5) * 0.09
		var rotation := deg_to_rad(float((i * 37) % 360))
		var instance_scale := base_scale * variation
		var basis := Basis.from_euler(Vector3(0.0, rotation, 0.0)).scaled(instance_scale)
		instances.set_instance_transform(i, Transform3D(basis, positions[i]))
	scatter.multimesh = instances
	scatter.material_override = material
	add_child(scatter)


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
	# The central access road ends at the beach instead of continuing across the sea.
	_add_road(Vector3(0.0, -0.045, -ARENA_SIZE * 0.2357), Vector2(5.2, ARENA_SIZE * 0.5357), 0.0)
	_add_road(Vector3(0.0, -0.04, 0.0), Vector2(ARENA_SIZE, 4.2), 0.0)
	_add_road_markings()

	# Two opposing modular base complexes frame the central battlefield.
	_build_base_complex(Vector3(-20.0, 0.0, 0.0), Color(0.28, 0.36, 0.27), "american")
	_build_base_complex(Vector3(20.0, 0.0, 0.0), Color(0.39, 0.31, 0.25), "chinese")
	_add_watch_tower(Vector3(-12.0, 0.0, -20.0))
	_add_watch_tower(Vector3(12.0, 0.0, 20.0))

func _build_base_complex(origin: Vector3, tint: Color, faction_id: String) -> void:
	_add_base_building(origin + Vector3(0.0, 0.0, -12.0), "command", tint, faction_id)
	_add_base_building(origin + Vector3(0.0, 0.0, -4.0), "barracks", tint, faction_id)
	_add_base_building(origin + Vector3(0.0, 0.0, 4.0), "factory", tint, faction_id)
	_add_base_building(origin + Vector3(0.0, 0.0, 12.0), "airfield", tint, faction_id)

func spawn_game_building(kind: String, at: Vector3, faction_id: String, tint: Color, build_progress: float = 0.0) -> Node3D:
	# Public bridge for the gameplay layer to create a 3D counterpart for a logical building.
	return _add_base_building(at, kind, tint, faction_id, build_progress, true)

func spawn_game_unit(kind: String, at: Vector3, faction_id: String, tint: Color, health: float = 100.0) -> Node3D:
	if not NAVAL_PRESENTATION_ENABLED and kind in NAVAL_GAMEPLAY_KINDS:
		return null
	var unit: Node3D
	match kind:
		"fighter":
			_add_placeholder_fighter(at, tint, faction_id)
			unit = showcase_tanks.back()
		"helicopter":
			_add_placeholder_helicopter(at, tint, faction_id)
			unit = showcase_tanks.back()
		"infantry", "builder", "marine":
			_add_placeholder_infantry_squad(at, tint, faction_id)
			unit = showcase_tanks.back()
		"destroyer", "carrier", "submarine", "landing_craft":
			unit = _add_placeholder_naval_vessel(kind, at, tint, faction_id)
		"artillery":
			_add_placeholder_tank(at, tint, faction_id)
			unit = showcase_tanks.back()
			unit.set_meta("unit_type", "artillery")
			var artillery_barrel := MeshInstance3D.new()
			var artillery_mesh := CylinderMesh.new()
			artillery_mesh.top_radius = 0.11
			artillery_mesh.bottom_radius = 0.16
			artillery_mesh.height = 4.2
			artillery_barrel.mesh = artillery_mesh
			artillery_barrel.rotation_degrees.x = 90.0
			artillery_barrel.position = Vector3(0.0, 0.1, -2.6)
			artillery_barrel.material_override = _make_armour_material(Color(0.15, 0.16, 0.14))
			showcase_turrets.back().add_child(artillery_barrel)
		_:
			_add_placeholder_tank(at, tint, faction_id)
			unit = showcase_tanks.back()
	if is_instance_valid(unit):
		unit.set_meta("gameplay_unit_kind", kind)
		unit.set_meta("health", maxf(0.0, health))
		unit.set_meta("max_health", maxf(1.0, health))
		unit.set_meta("source_gameplay_unit", true)
	return unit

func _add_placeholder_naval_vessel(kind: String, at: Vector3, tint: Color, faction_id: String) -> Node3D:
	var vessel := Node3D.new()
	vessel.position = at
	add_child(vessel)
	showcase_tanks.append(vessel)
	vessel.set_meta("health", 100.0)
	vessel.set_meta("unit_type", kind)
	vessel.set_meta("faction_id", faction_id)
	_create_showcase_health_bar(vessel)

	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	var faction_badge_parent: Node3D = vessel
	if kind == "submarine":
		var hull_mesh := CapsuleMesh.new()
		hull_mesh.radius = 0.72
		hull_mesh.height = 7.4
		hull.mesh = hull_mesh
		hull.rotation_degrees.x = 90.0
		hull.position.y = -0.05
	else:
		var hull_mesh := BoxMesh.new()
		hull_mesh.size = Vector3(4.2, 0.8, 10.0) if kind == "carrier" else (Vector3(3.0, 0.75, 7.0) if kind == "landing_craft" else Vector3(2.8, 0.8, 8.2))
		hull.mesh = hull_mesh
		hull.position.y = 0.24
	hull.material_override = _make_armour_material(tint.darkened(0.18))
	vessel.add_child(hull)

	if kind == "submarine":
		var sail := MeshInstance3D.new()
		var sail_mesh := BoxMesh.new()
		sail_mesh.size = Vector3(0.9, 1.15, 1.5)
		sail.mesh = sail_mesh
		sail.position = Vector3(0.0, 0.78, 0.15)
		sail.material_override = _make_armour_material(tint)
		vessel.add_child(sail)
		faction_badge_parent = sail
		for side in [-1.0, 1.0]:
			var fin := MeshInstance3D.new()
			var fin_mesh := BoxMesh.new()
			fin_mesh.size = Vector3(2.0, 0.12, 0.65)
			fin.mesh = fin_mesh
			fin.position = Vector3(side * 0.72, -0.2, 2.9)
			fin.material_override = _make_armour_material(tint.darkened(0.25))
			vessel.add_child(fin)
	elif kind == "carrier":
		var runway := MeshInstance3D.new()
		var runway_mesh := BoxMesh.new()
		runway_mesh.size = Vector3(2.8, 0.08, 8.4)
		runway.mesh = runway_mesh
		runway.position.y = 0.91
		runway.material_override = _make_armour_material(Color(0.20, 0.22, 0.21))
		vessel.add_child(runway)
		var island := MeshInstance3D.new()
		var island_mesh := BoxMesh.new()
		island_mesh.size = Vector3(1.1, 2.0, 2.1)
		island.mesh = island_mesh
		island.position = Vector3(1.25, 1.75, -2.2)
		island.material_override = _make_armour_material(tint.lightened(0.08))
		vessel.add_child(island)
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.08
		mast_mesh.bottom_radius = 0.13
		mast_mesh.height = 1.4
		mast.mesh = mast_mesh
		mast.position = Vector3(1.25, 3.25, -2.2)
		mast.material_override = _make_armour_material(Color(0.16, 0.18, 0.17))
		vessel.add_child(mast)
	elif kind == "landing_craft":
		var ramp := MeshInstance3D.new()
		var ramp_mesh := BoxMesh.new()
		ramp_mesh.size = Vector3(2.4, 0.12, 1.3)
		ramp.mesh = ramp_mesh
		ramp.position = Vector3(0.0, 0.52, -4.0)
		ramp.rotation_degrees.x = -18.0
		ramp.material_override = _make_armour_material(tint.lightened(0.05))
		vessel.add_child(ramp)
		var cargo := MeshInstance3D.new()
		var cargo_mesh := BoxMesh.new()
		cargo_mesh.size = Vector3(1.9, 0.9, 2.2)
		cargo.mesh = cargo_mesh
		cargo.position = Vector3(0.0, 1.25, 0.1)
		cargo.material_override = _make_armour_material(tint)
		vessel.add_child(cargo)
	else:
		var bridge := MeshInstance3D.new()
		var bridge_mesh := BoxMesh.new()
		bridge_mesh.size = Vector3(1.6, 1.25, 1.8)
		bridge.mesh = bridge_mesh
		bridge.position = Vector3(0.0, 1.35, 0.6)
		bridge.material_override = _make_armour_material(tint.lightened(0.06))
		vessel.add_child(bridge)
		for turret_z in [-2.4, 2.5]:
			var turret := MeshInstance3D.new()
			var turret_mesh := CylinderMesh.new()
			turret_mesh.top_radius = 0.45
			turret_mesh.bottom_radius = 0.5
			turret_mesh.height = 0.42
			turret.mesh = turret_mesh
			turret.position = Vector3(0.0, 1.0, turret_z)
			turret.material_override = _make_armour_material(Color(0.18, 0.19, 0.17))
			vessel.add_child(turret)

	if kind == "submarine":
		_add_faction_insignia(faction_badge_parent, faction_id, Vector3(0.0, 0.68, 0.15), Vector3(0.42, 0.10, 0.34))
	else:
		var badge_position := Vector3(-0.78, 0.70, -1.7)
		if kind == "carrier":
			badge_position = Vector3(-1.35, 0.98, -0.2)
		elif kind == "landing_craft":
			badge_position = Vector3(0.95, 0.72, -1.6)
		_add_faction_insignia(vessel, faction_id, badge_position, Vector3(0.48, 0.08, 0.38))

	if kind != "submarine":
		_add_naval_propeller(vessel, "PropellerLeft", -0.72)
		_add_naval_propeller(vessel, "PropellerRight", 0.72)

	# Every selectable unit owns an aim pivot so shared combat arrays stay index-aligned.
	var weapon_pivot := Node3D.new()
	weapon_pivot.position = Vector3(0.0, 1.0, 0.0)
	vessel.add_child(weapon_pivot)
	showcase_turrets.append(weapon_pivot)
	return vessel

func _normalize_faction_id(faction_value: String) -> String:
	match faction_value:
		"الأمريكي", "American", "american":
			return "american"
		"الصيني", "Chinese", "chinese":
			return "chinese"
		"الجيش العربي", "Arab Army", "arab", "arab_army":
			return "arab"
		"وطن", "Watan", "watan":
			return "watan"
		_:
			return faction_value.to_lower()


func _gameplay_max_health_for_kind(kind: String) -> float:
	# Match the live 2D unit roster so 3D health bars show real damage from spawn.
	match kind:
		"tank":
			return 150.0
		"builder":
			return 220.0
		"helicopter":
			return 180.0
		"fighter":
			return 120.0
		"destroyer":
			return 260.0
		"carrier":
			return 520.0
		"submarine":
			return 210.0
		"landing_craft":
			return 220.0
		_:
			return 100.0


func _sync_gameplay_unit_orientation(unit: Node3D, record: Dictionary) -> void:
	# Convert authoritative 2D headings to smooth 3D body/turret rotations.
	if record.has("facing"):
		var source_facing := float(record.get("facing", 0.0))
		var previous_facing := float(unit.get_meta("gameplay_source_facing", source_facing))
		var turn_delta := wrapf(source_facing - previous_facing, -PI, PI)
		var kind := String(record.get("kind", "tank"))
		var is_aircraft := kind in ["fighter", "helicopter"]
		var bank_target := clampf(-turn_delta * 1.8, -0.34, 0.34) if is_aircraft else 0.0
		unit.set_meta("gameplay_flight_bank_target", bank_target)
		unit.set_meta("gameplay_source_facing", source_facing)
		unit.set_meta("gameplay_body_yaw_target", -source_facing + PI * 0.5)
	if record.has("turret_facing"):
		var desired_world_yaw := -float(record.get("turret_facing", record.get("facing", 0.0))) + PI * 0.5
		unit.set_meta("gameplay_turret_yaw_target", desired_world_yaw)


func sync_game_units(unit_records: Array, map_rect: Rect2) -> int:
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return 0
	var active_keys: Dictionary = {}
	var synced_count := 0
	for index in range(unit_records.size()):
		var record_value = unit_records[index]
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if not record.has("pos") or not record.get("pos") is Vector2:
			continue
		var source_pos: Vector2 = record.pos
		var team := String(record.get("team", "player"))
		var kind := String(record.get("kind", "tank"))
		if not NAVAL_PRESENTATION_ENABLED and kind in NAVAL_GAMEPLAY_KINDS:
			continue
		var faction_id := _normalize_faction_id(String(record.get("faction", "american")))
		if not record.has("3d_sync_id"):
			record["3d_sync_id"] = next_game_unit_sync_id
			next_game_unit_sync_id += 1
		var key := "%s|%s|%s" % [team, str(record["3d_sync_id"]), kind]
		active_keys[key] = true
		var nx := clampf((source_pos.x - map_rect.position.x) / map_rect.size.x, 0.0, 1.0)
		var nz := clampf((source_pos.y - map_rect.position.y) / map_rect.size.y, 0.0, 1.0)
		var altitude := 5.2 if kind == "helicopter" else (6.4 if kind == "fighter" else (-0.62 if kind == "submarine" else (0.12 if kind in ["destroyer", "carrier", "landing_craft"] else 0.0)))
		var world_pos := Vector3(lerpf(-ARENA_SIZE * 0.38, ARENA_SIZE * 0.38, nx), altitude, lerpf(-ARENA_SIZE * 0.38, ARENA_SIZE * 0.38, nz))
		var tint := Color(0.30, 0.43, 0.34) if team == "player" else Color(0.43, 0.31, 0.28)
		var current_health := maxf(0.0, float(record.get("hp", 100.0)))
		var maximum_health := maxf(1.0, float(record.get("max_hp", _gameplay_max_health_for_kind(kind))))
		var unit: Node3D = null
		var existing_unit_variant = game_unit_nodes.get(key)
		if is_instance_valid(existing_unit_variant):
			unit = existing_unit_variant as Node3D
		if not is_instance_valid(unit):
			unit = spawn_game_unit(kind, world_pos, faction_id, tint, current_health)
			if not is_instance_valid(unit):
				continue
			unit.set_meta("source_unit_key", key)
			unit.set_meta("source_team", team)
			unit.set_meta("source_faction", faction_id)
			unit.set_meta("max_health", maximum_health)
			unit.set_meta("gameplay_visual_target", world_pos)
			_sync_gameplay_unit_orientation(unit, record)
			game_unit_nodes[key] = unit
		else:
			# Keep simulation coordinates authoritative while smoothing the 3D proxy between sync ticks.
			unit.set_meta("gameplay_visual_target", world_pos)
			unit.set_meta("health", current_health)
			unit.set_meta("max_health", maximum_health)
			unit.set_meta("faction_id", faction_id)
			unit.set_meta("source_faction", faction_id)
		_sync_gameplay_unit_orientation(unit, record)
		synced_count += 1
	for existing_key in game_unit_nodes.keys():
		if not active_keys.has(existing_key):
			var stale_unit_variant = game_unit_nodes[existing_key]
			if is_instance_valid(stale_unit_variant):
				var stale_unit := stale_unit_variant as Node3D
				# Remove destroyed/despawned units from every active selection and target.
				if selected_live_units.has(stale_unit):
					selected_live_units.erase(stale_unit)
				if attack_target == stale_unit:
					attack_target = null
				if selected_tank == stale_unit:
					selected_tank = selected_live_units[0] if not selected_live_units.is_empty() else null
					selection_ring.visible = is_instance_valid(selected_tank)
				if selected_live_units.is_empty() and not is_instance_valid(selected_tank):
					has_selected_destination = false
					order_marker.visible = false
				# A stale proxy may have despawned or been removed for non-combat reasons.
				# Only the authoritative death callback creates a wreck.
				stale_unit.queue_free()
			game_unit_nodes.erase(existing_key)
	return synced_count

func _update_gameplay_unit_visuals(delta: float) -> void:
	# The 2D RTS remains authoritative; interpolate only its 3D presentation
	# so the 0.12-second bridge cadence does not make live units visibly jump.
	var blend := clampf(delta * 16.0, 0.0, 1.0)
	for unit_key in game_unit_nodes.keys():
		var unit_variant = game_unit_nodes[unit_key]
		if not is_instance_valid(unit_variant):
			continue
		var unit := unit_variant as Node3D
		var target_variant = unit.get_meta("gameplay_visual_target", unit.global_position)
		var aircraft_kind := String(unit.get_meta("gameplay_unit_kind", unit.get_meta("unit_type", "")))
		var is_aircraft := aircraft_kind in ["fighter", "helicopter"]
		var horizontal_travel := 0.0
		if target_variant is Vector3:
			horizontal_travel = Vector2(target_variant.x - unit.global_position.x, target_variant.z - unit.global_position.z).length()
			unit.global_position = unit.global_position.lerp(target_variant, blend)
		if is_aircraft:
			# Small climb under forward movement; helicopters retain a gentle hover motion.
			var base_altitude := 5.2 if aircraft_kind == "helicopter" else 6.4
			var climb_target := clampf(horizontal_travel * 0.035, 0.0, 0.42)
			var hover_phase := float(unit.get_meta("gameplay_hover_phase", 0.0)) + delta * (2.4 if aircraft_kind == "helicopter" else 1.15)
			unit.set_meta("gameplay_hover_phase", hover_phase)
			var hover_amount := sin(hover_phase) * (0.10 if aircraft_kind == "helicopter" else 0.035)
			var altitude_target := base_altitude + climb_target + hover_amount
			unit.global_position.y = lerpf(unit.global_position.y, altitude_target, clampf(delta * 3.2, 0.0, 1.0))
		var body_yaw := float(unit.get_meta("gameplay_body_yaw_target", unit.rotation.y))
		unit.rotation.y = lerp_angle(unit.rotation.y, body_yaw, blend)
		# Aircraft bank gently into turns; ground vehicles always settle level.
		var bank_target := float(unit.get_meta("gameplay_flight_bank_target", 0.0))
		unit.rotation.z = lerpf(unit.rotation.z, bank_target, clampf(delta * 5.5, 0.0, 1.0))
		if is_aircraft:
			var pitch_target := clampf(climb_target * 0.22, 0.0, 0.12)
			unit.rotation.x = lerpf(unit.rotation.x, pitch_target, clampf(delta * 3.0, 0.0, 1.0))
		else:
			unit.rotation.x = lerpf(unit.rotation.x, 0.0, clampf(delta * 4.0, 0.0, 1.0))
		var turret_pivot := unit.get_node_or_null("TurretPivot") as Node3D
		if is_instance_valid(turret_pivot) and unit.has_meta("gameplay_turret_yaw_target"):
			var turret_world_yaw := float(unit.get_meta("gameplay_turret_yaw_target", body_yaw))
			var turret_local_yaw := wrapf(turret_world_yaw - unit.rotation.y, -PI, PI)
			turret_pivot.rotation.y = lerp_angle(turret_pivot.rotation.y, turret_local_yaw, blend)


func _gameplay_effect_world_position(source_pos: Vector2, map_rect: Rect2, height: float = 0.35) -> Vector3:
	var nx := clampf((source_pos.x - map_rect.position.x) / map_rect.size.x, 0.0, 1.0)
	var nz := clampf((source_pos.y - map_rect.position.y) / map_rect.size.y, 0.0, 1.0)
	return Vector3(lerpf(-ARENA_SIZE * 0.38, ARENA_SIZE * 0.38, nx), height, lerpf(-ARENA_SIZE * 0.38, ARENA_SIZE * 0.38, nz))


func sync_gameplay_effects(effect_records: Array, map_rect: Rect2) -> int:
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return 0
	var active_ids: Dictionary = {}
	var synced := 0
	for value in effect_records:
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		var effect_id := int(record.get("id", -1))
		if effect_id < 0:
			continue
		active_ids[effect_id] = true
		if gameplay_effect_nodes.has(effect_id) and is_instance_valid(gameplay_effect_nodes[effect_id]):
			continue
		var effect_kind := String(record.get("kind", "flash"))
		var start_pos: Vector2 = record.get("start", Vector2.ZERO)
		var finish_pos: Vector2 = record.get("finish", start_pos)
		var tint: Color = record.get("color", Color(1.0, 0.65, 0.28))
		var duration := maxf(0.08, float(record.get("life", 0.2)))
		var radius := maxf(0.0, float(record.get("radius", 0.0)))
		var start_world := _gameplay_effect_world_position(start_pos, map_rect, 0.42)
		var finish_world := _gameplay_effect_world_position(finish_pos, map_rect, 0.48)
		var effect := MeshInstance3D.new()
		effect.name = "GameplayEffect_%d" % effect_id
		var mesh: Mesh
		if effect_kind == "targeting":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.72
			ring.outer_radius = 0.92
			mesh = ring
			effect.position = finish_world + Vector3.UP * 0.08
			effect.scale = Vector3.ONE * clampf(radius / 42.0, 0.65, 2.2)
		elif effect_kind == "air_missile":
			# A compact airborne projectile travels from launcher to impact point.
			var missile := CylinderMesh.new()
			missile.top_radius = 0.055
			missile.bottom_radius = 0.085
			missile.height = 0.72
			mesh = missile
			var missile_start := start_world + Vector3.UP * 1.15
			var missile_finish := finish_world + Vector3.UP * 4.6
			effect.position = missile_start
			if missile_start.distance_squared_to(missile_finish) > 0.01:
				effect.look_at(missile_finish, Vector3.UP)
				effect.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		elif effect_kind in ["tracer", "tank_round", "shell"]:
			var beam := CylinderMesh.new()
			beam.top_radius = 0.045 if effect_kind != "shell" else 0.10
			beam.bottom_radius = beam.top_radius
			beam.height = maxf(0.1, start_world.distance_to(finish_world))
			mesh = beam
			effect.position = (start_world + finish_world) * 0.5
			effect.look_at(finish_world, Vector3.UP)
			effect.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		else:
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 10
			sphere.rings = 6
			mesh = sphere
			effect.position = finish_world + Vector3.UP * 0.28
			var size := clampf(radius / 48.0, 0.22, 2.4)
			effect.scale = Vector3.ONE * size
		effect.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.4 if effect_kind in ["explosion", "muzzle", "flash"] else 0.65
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if tint.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
		effect.material_override = material
		add_child(effect)
		gameplay_effect_nodes[effect_id] = effect
		var tween := create_tween()
		tween.set_parallel(true)
		if effect_kind == "air_missile":
			tween.tween_property(effect, "position", finish_world + Vector3.UP * 4.6, duration)
		if effect_kind in ["explosion", "flash", "muzzle"]:
			tween.tween_property(effect, "scale", effect.scale * 1.65, duration)
		if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			tween.tween_property(material, "albedo_color:a", 0.0, duration)
		tween.chain().tween_callback(effect.queue_free)
		synced += 1
	for old_id in gameplay_effect_nodes.keys():
		if not active_ids.has(old_id):
			var old_effect = gameplay_effect_nodes[old_id]
			if is_instance_valid(old_effect):
				old_effect.queue_free()
			gameplay_effect_nodes.erase(old_id)
	return synced


func _update_gameplay_building_damage_visuals(building: Node3D, current_hp: float, maximum_hp: float, kind: String) -> void:
	var health_ratio := clampf(current_hp / maxf(1.0, maximum_hp), 0.0, 1.0)
	var smoke_variant = building.get_node_or_null("DamageSmoke")
	if health_ratio > 0.55:
		if is_instance_valid(smoke_variant):
			smoke_variant.queue_free()
		return
	var smoke := smoke_variant as GPUParticles3D
	if not is_instance_valid(smoke):
		smoke = GPUParticles3D.new()
		smoke.name = "DamageSmoke"
		smoke.position = Vector3(0.0, 3.0 if kind != "command" else 4.8, 0.0)
		smoke.amount = 7
		smoke.lifetime = 1.7
		smoke.explosiveness = 0.0
		smoke.emitting = true
		var particle_material := ParticleProcessMaterial.new()
		particle_material.direction = Vector3(0.0, 1.0, 0.0)
		particle_material.spread = 22.0
		particle_material.initial_velocity_min = 0.35
		particle_material.initial_velocity_max = 1.15
		particle_material.gravity = Vector3(0.0, 0.35, 0.0)
		particle_material.scale_min = 0.16
		particle_material.scale_max = 0.34
		particle_material.color = Color(0.24, 0.25, 0.23, 0.62)
		smoke.process_material = particle_material
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.32
		smoke_mesh.height = 0.64
		smoke_mesh.radial_segments = 6
		smoke_mesh.rings = 4
		var smoke_surface := StandardMaterial3D.new()
		smoke_surface.albedo_color = Color(0.25, 0.26, 0.24, 0.48)
		smoke_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_mesh.material = smoke_surface
		smoke.draw_pass_1 = smoke_mesh
		building.add_child(smoke)
		building.set_meta("damage_smoke", smoke)
	if health_ratio <= 0.25:
		smoke.amount = 13
		smoke.lifetime = 2.1
	else:
		smoke.amount = 7
		smoke.lifetime = 1.7


func spawn_game_building_destruction_effect(source_pos: Vector2, map_rect: Rect2, kind: String) -> void:
	# One-shot destruction burst at the authoritative 2D building position.
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return
	var world_pos := _gameplay_effect_world_position(source_pos, map_rect, 0.35)
	var blast := MeshInstance3D.new()
	blast.name = "BuildingDestructionBurst"
	var blast_mesh := SphereMesh.new()
	blast_mesh.radius = 1.0
	blast_mesh.height = 2.0
	blast_mesh.radial_segments = 12
	blast_mesh.rings = 8
	blast.mesh = blast_mesh
	blast.position = world_pos + Vector3.UP * (0.8 if kind != "command" else 1.5)
	blast.scale = Vector3.ONE * (1.25 if kind != "command" else 1.8)
	var blast_material := StandardMaterial3D.new()
	blast_material.albedo_color = Color(1.0, 0.43, 0.12, 0.92)
	blast_material.emission_enabled = true
	blast_material.emission = Color(1.0, 0.25, 0.06)
	blast_material.emission_energy_multiplier = 2.4
	blast_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blast.material_override = blast_material
	add_child(blast)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(blast, "scale", blast.scale * 3.2, 0.42)
	tween.tween_property(blast_material, "albedo_color:a", 0.0, 0.42)
	tween.chain().tween_callback(blast.queue_free)
	_spawn_light_building_debris(world_pos, kind)


func _spawn_light_building_debris(world_pos: Vector3, kind: String) -> void:
	# Small, static low-poly rubble; no rigid bodies, particles, or collision shapes.
	var rubble := Node3D.new()
	rubble.name = "LightBuildingDebris"
	rubble.position = world_pos
	add_child(rubble)
	var chunk_count := 2 if kind in ["command", "factory", "shipyard"] else 1
	for index in range(chunk_count):
		var chunk := MeshInstance3D.new()
		var chunk_mesh := BoxMesh.new()
		chunk_mesh.size = Vector3(0.9 + 0.18 * index, 0.32 + 0.08 * index, 0.72)
		chunk.mesh = chunk_mesh
		chunk.position = Vector3(-0.42 + 0.84 * index, 0.16, 0.18 - 0.36 * index)
		chunk.rotation = Vector3(0.08 * index, 0.55 * index, 0.12 - 0.24 * index)
		var rubble_material := StandardMaterial3D.new()
		rubble_material.albedo_color = Color(0.22, 0.23, 0.21) if index == 0 else Color(0.32, 0.29, 0.25)
		rubble_material.roughness = 1.0
		chunk.material_override = rubble_material
		rubble.add_child(chunk)
	gameplay_debris_nodes.append(rubble)
	while gameplay_debris_nodes.size() > 10:
		var oldest := gameplay_debris_nodes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var cleanup := create_tween()
	cleanup.tween_interval(24.0)
	cleanup.tween_callback(_remove_light_building_debris.bind(rubble))


func spawn_game_unit_destruction_effect(source_pos: Vector2, map_rect: Rect2, kind: String) -> void:
	# Called only by the authoritative combat cleanup when a gameplay unit reaches zero HP.
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return
	var is_aircraft := kind == "fighter" or kind == "helicopter"
	var world_pos := _gameplay_effect_world_position(source_pos, map_rect, 0.08)
	var wreck_source := Node3D.new()
	wreck_source.global_position = world_pos
	wreck_source.set_meta("gameplay_unit_kind", kind)
	wreck_source.set_meta("unit_type", kind)
	add_child(wreck_source)
	_spawn_light_unit_wreck(wreck_source)
	wreck_source.queue_free()
	_spawn_impact_flash(world_pos, true)
	if is_aircraft:
		# Aircraft wrecks settle to the ground instead of remaining at flight altitude.
		var wreck_variant = gameplay_debris_nodes.back() if not gameplay_debris_nodes.is_empty() else null
		if is_instance_valid(wreck_variant):
			(wreck_variant as Node3D).global_position.y = 0.08


func _spawn_light_unit_wreck(unit: Node3D) -> void:
	# Small static visual wrecks only; the 2D simulation owns unit removal and combat.
	if not is_instance_valid(unit):
		return
	# Prefer the authoritative gameplay kind; placeholder nodes may only expose unit_type.
	var unit_kind := String(unit.get_meta("gameplay_unit_kind", unit.get_meta("unit_type", unit.get_meta("source_kind", "tank"))))
	var wreck := Node3D.new()
	wreck.name = "LightUnitWreck"
	wreck.global_position = unit.global_position
	wreck.rotation.y = unit.rotation.y
	add_child(wreck)
	var wreck_mesh := BoxMesh.new()
	var wreck_chunk := MeshInstance3D.new()
	wreck_chunk.mesh = wreck_mesh
	match unit_kind:
		"fighter":
			wreck_mesh.size = Vector3(1.05, 0.12, 0.68)
			wreck.position.y += 0.08
		"helicopter":
			wreck_mesh.size = Vector3(0.78, 0.16, 0.58)
			wreck.position.y += 0.08
		"destroyer", "carrier", "submarine", "landing_craft":
			wreck_mesh.size = Vector3(1.35, 0.16, 0.62)
		"infantry", "builder":
			wreck_mesh.size = Vector3(0.22, 0.12, 0.22)
		_:
			wreck_mesh.size = Vector3(0.82, 0.22, 0.62)
	var wreck_material := StandardMaterial3D.new()
	wreck_material.albedo_color = Color(0.19, 0.20, 0.19)
	wreck_material.roughness = 1.0
	wreck_chunk.material_override = wreck_material
	wreck.add_child(wreck_chunk)
	if unit_kind == "fighter" or unit_kind == "helicopter":
		# A second low-poly fragment makes aircraft losses readable without physics.
		var fragment := MeshInstance3D.new()
		var fragment_mesh := BoxMesh.new()
		fragment_mesh.size = Vector3(0.42, 0.09, 0.18) if unit_kind == "fighter" else Vector3(0.52, 0.08, 0.12)
		fragment.mesh = fragment_mesh
		fragment.position = Vector3(0.28, 0.10, -0.20)
		fragment.rotation.y = 0.48
		fragment.rotation.z = -0.16
		fragment.material_override = wreck_material
		wreck.add_child(fragment)
	gameplay_debris_nodes.append(wreck)
	while gameplay_debris_nodes.size() > 12:
		var oldest := gameplay_debris_nodes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var cleanup := create_tween()
	cleanup.tween_interval(18.0)
	cleanup.tween_callback(_remove_light_unit_wreck.bind(wreck))


func _remove_light_unit_wreck(wreck: Node3D) -> void:
	gameplay_debris_nodes.erase(wreck)
	if is_instance_valid(wreck):
		wreck.queue_free()


func _remove_light_building_debris(rubble: Node3D) -> void:
	gameplay_debris_nodes.erase(rubble)
	if is_instance_valid(rubble):
		rubble.queue_free()


func _gameplay_max_health_for_building(kind: String) -> float:
	match kind:
		"bunker":
			return 650.0
		"missile_silo":
			return 500.0
		"missile_defense":
			return 450.0
		_:
			return 400.0


func sync_game_buildings(player_buildings: Array, enemy_buildings: Array, map_rect: Rect2, player_faction: String, enemy_faction: String) -> int:
	# Reconcile logical 2D building records with persistent 3D counterparts.
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return 0
	var active_keys: Dictionary = {}
	var synced_count := 0
	var teams := [
		{"records": player_buildings, "team": "player", "faction": player_faction, "tint": Color(0.30, 0.43, 0.34)},
		{"records": enemy_buildings, "team": "enemy", "faction": enemy_faction, "tint": Color(0.43, 0.31, 0.28)}
	]
	for team_data in teams:
		for record_value in team_data.records:
			if not record_value is Dictionary:
				continue
			var record: Dictionary = record_value
			if not record.has("pos") or not record.get("pos") is Vector2:
				continue
			var source_pos: Vector2 = record.pos
			var kind := String(record.get("kind", ""))
			if kind.is_empty():
				continue
			# production_id remains stable when a building is repaired, upgraded, or repositioned.
			var building_identity := str(record.get("production_id", "%.2f|%.2f" % [source_pos.x, source_pos.y]))
			var key := "%s|%s|%s" % [team_data.team, kind, building_identity]
			active_keys[key] = true
			var normalized_x := clampf((source_pos.x - map_rect.position.x) / map_rect.size.x, 0.0, 1.0)
			var normalized_z := clampf((source_pos.y - map_rect.position.y) / map_rect.size.y, 0.0, 1.0)
			var world_pos := Vector3(lerpf(-ARENA_SIZE * 0.38, ARENA_SIZE * 0.38, normalized_x), 0.0, lerpf(-ARENA_SIZE * 0.38, ARENA_SIZE * 0.38, normalized_z))
			var building: Node3D = null
			var existing_building_variant = game_building_nodes.get(key)
			if is_instance_valid(existing_building_variant):
				building = existing_building_variant as Node3D
			if not is_instance_valid(building):
				building = spawn_game_building(kind, world_pos, _normalize_faction_id(String(team_data.faction)), team_data.tint, float(record.get("build_progress", 1.0)))
				if not is_instance_valid(building):
					continue
				building.set_meta("source_key", key)
				building.set_meta("source_team", String(team_data.team))
				game_building_nodes[key] = building
			else:
				building.position = world_pos
				building.set_meta("faction_id", _normalize_faction_id(String(team_data.faction)))
				building.set_meta("source_team", String(team_data.team))
				update_game_building_progress(building, float(record.get("build_progress", 1.0)))
			var current_hp := maxf(0.0, float(record.get("hp", 400.0)))
			var maximum_hp := maxf(1.0, float(record.get("max_hp", _gameplay_max_health_for_building(kind))))
			building.set_meta("health", current_hp)
			building.set_meta("max_health", maximum_hp)
			_update_gameplay_building_damage_visuals(building, current_hp, maximum_hp, kind)
			if building.get_node_or_null("HealthBar") == null:
				_create_showcase_health_bar(building)
				var building_health_bar := building.get_node_or_null("HealthBar") as Node3D
				if is_instance_valid(building_health_bar):
					building_health_bar.position.y = 6.2 if kind == "command" else 4.2
			update_game_building_level(building, int(record.get("level", 1)))
			synced_count += 1
	for existing_key in game_building_nodes.keys():
		if not active_keys.has(existing_key):
			var stale_building_variant = game_building_nodes[existing_key]
			if is_instance_valid(stale_building_variant):
				var stale_building := stale_building_variant as Node3D
				stale_building.queue_free()
			game_building_nodes.erase(existing_key)
	return synced_count

func _ensure_building_production_bar(building: Node3D) -> Dictionary:
	var root := building.get_node_or_null("ProductionStatus") as Node3D
	if not is_instance_valid(root):
		root = Node3D.new()
		root.name = "ProductionStatus"
		root.position = Vector3(0.0, 4.65, 0.0)
		building.add_child(root)
		var background := MeshInstance3D.new()
		background.name = "Background"
		var background_mesh := BoxMesh.new()
		background_mesh.size = Vector3(2.8, 0.16, 0.12)
		background.mesh = background_mesh
		background.material_override = _make_armour_material(Color(0.055, 0.065, 0.06))
		root.add_child(background)
		var fill := MeshInstance3D.new()
		fill.name = "Fill"
		var fill_mesh := BoxMesh.new()
		fill_mesh.size = Vector3(2.62, 0.10, 0.15)
		fill.mesh = fill_mesh
		fill.position.z = -0.09
		fill.material_override = _make_armour_material(Color(0.24, 0.72, 0.96))
		root.add_child(fill)
	return {"root": root, "fill": root.get_node("Fill")}


func sync_game_production_orders(orders: Array) -> void:
	# Only the first queued order for each producer advances in the RTS simulation.
	var active_producers: Dictionary = {}
	for order_value in orders:
		if not order_value is Dictionary:
			continue
		var order: Dictionary = order_value
		var producer_id := int(order.get("producer_id", -1))
		var producer_kind := String(order.get("producer_kind", ""))
		if producer_id < 0 or producer_kind.is_empty():
			continue
		var producer_key := "player|%s|%s" % [producer_kind, str(producer_id)]
		if active_producers.has(producer_key):
			continue
		active_producers[producer_key] = order
	for building_key in game_building_nodes.keys():
		if not String(building_key).begins_with("player|"):
			continue
		var building_variant = game_building_nodes[building_key]
		if not is_instance_valid(building_variant):
			continue
		var building := building_variant as Node3D
		var has_active_order := active_producers.has(String(building_key))
		var status := building.get_node_or_null("ProductionStatus") as Node3D
		if has_active_order and not is_instance_valid(status):
			var status_parts := _ensure_building_production_bar(building)
			status = status_parts.root as Node3D
		if not is_instance_valid(status):
			continue
		status.visible = has_active_order
		if not status.visible:
			continue
		var active_order: Dictionary = active_producers[String(building_key)]
		var duration := maxf(0.01, float(active_order.get("duration", 1.0)))
		var remaining := clampf(float(active_order.get("remaining", duration)), 0.0, duration)
		var progress := clampf(1.0 - remaining / duration, 0.0, 1.0)
		var fill := status.get_node_or_null("Fill") as MeshInstance3D
		if is_instance_valid(fill):
			fill.scale.x = maxf(progress, 0.001)
			fill.position.x = -1.31 * (1.0 - progress)


func update_game_building_level(building: Node3D, upgrade_level: int) -> void:
	if not is_instance_valid(building):
		return
	var level := clampi(upgrade_level, 1, 3)
	building.set_meta("upgrade_level", level)
	if String(building.get_meta("building_kind", "")) != "bunker":
		return
	if level >= 2 and building.get_node_or_null("UpgradeArmorL2") == null:
		var armor_plate := MeshInstance3D.new()
		armor_plate.name = "UpgradeArmorL2"
		var armor_mesh := BoxMesh.new()
		armor_mesh.size = Vector3(0.28, 0.34, 5.7)
		armor_plate.mesh = armor_mesh
		armor_plate.position = Vector3(-2.72, 2.38, 0.0)
		armor_plate.material_override = _make_armour_material(Color(0.48, 0.52, 0.48))
		building.add_child(armor_plate)
		var second_plate := MeshInstance3D.new()
		second_plate.name = "UpgradeArmorL2Right"
		second_plate.mesh = armor_mesh.duplicate()
		second_plate.position = Vector3(2.72, 2.38, 0.0)
		second_plate.material_override = _make_armour_material(Color(0.48, 0.52, 0.48))
		building.add_child(second_plate)
	if level >= 3 and building.get_node_or_null("UpgradeArmorL3") == null:
		var command_plate := MeshInstance3D.new()
		command_plate.name = "UpgradeArmorL3"
		var command_mesh := BoxMesh.new()
		command_mesh.size = Vector3(5.6, 0.30, 0.32)
		command_plate.mesh = command_mesh
		command_plate.position = Vector3(0.0, 2.55, 0.0)
		command_plate.material_override = _make_armour_material(Color(0.62, 0.56, 0.40))
		building.add_child(command_plate)


func update_game_building_progress(building: Node3D, build_progress: float) -> void:
	if not is_instance_valid(building):
		return
	var progress := clampf(build_progress, 0.0, 1.0)
	building.set_meta("construction_progress", progress)
	var fill := building.get_node_or_null("ConstructionProgressFill") as MeshInstance3D
	if fill:
		fill.scale.x = maxf(0.001, progress)
		fill.visible = progress < 1.0
	var background := building.get_node_or_null("ConstructionProgressBackground") as MeshInstance3D
	if background:
		background.visible = progress < 1.0

func _get_faction_accent_color(faction_id: String) -> Color:
	match faction_id:
		"american":
			return Color(0.20, 0.48, 0.82)
		"chinese":
			return Color(0.82, 0.20, 0.16)
		"arab":
			return Color(0.20, 0.58, 0.32)
		"watan":
			return Color(0.88, 0.68, 0.22)
		_:
			return Color(0.62, 0.62, 0.58)


func _add_faction_insignia(parent: Node3D, faction_id: String, local_position: Vector3, badge_size: Vector3) -> MeshInstance3D:
	var insignia := MeshInstance3D.new()
	insignia.name = "FactionInsignia"
	var badge_mesh := BoxMesh.new()
	badge_mesh.size = badge_size
	insignia.mesh = badge_mesh
	insignia.position = local_position
	insignia.material_override = _make_armour_material(_get_faction_accent_color(faction_id))
	parent.add_child(insignia)
	return insignia


func _add_base_building(at: Vector3, kind: String, tint: Color, faction_id: String, build_progress: float = 1.0, show_progress: bool = false) -> Node3D:
	var building := Node3D.new()
	building.name = faction_id + "_" + kind
	building.position = at
	building.set_meta("building_kind", kind)
	building.set_meta("faction_id", faction_id)
	add_child(building)

	if kind == "airfield":
		var apron := MeshInstance3D.new()
		var apron_mesh := PlaneMesh.new()
		apron_mesh.size = Vector2(9.0, 7.0)
		apron.mesh = apron_mesh
		apron.position.y = 0.025
		var apron_material := _make_armour_material(Color(0.16, 0.18, 0.17))
		apron_material.roughness = 1.0
		apron.material_override = apron_material
		building.add_child(apron)

	var body_size := Vector3(6.2, 3.0, 5.2)
	if kind == "shipyard":
		body_size = Vector3(8.0, 2.2, 6.5)
	elif kind == "missile_silo" or kind == "missile_defense":
		body_size = Vector3(5.8, 2.2, 5.0)
	elif kind == "power_plant":
		body_size = Vector3(6.8, 3.0, 5.8)
	elif kind == "bunker":
		body_size = Vector3(7.2, 1.8, 6.2)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = body_size
	body.mesh = body_mesh
	body.position.y = 1.5
	body.material_override = _make_armour_material(tint)
	building.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(7.6, 0.42, 6.6) if kind == "bunker" else Vector3(6.5, 0.28, 5.5)
	roof.mesh = roof_mesh
	roof.position.y = 2.18 if kind == "bunker" else 3.08
	roof.material_override = _make_armour_material(tint.darkened(0.30))
	building.add_child(roof)

	var faction_stripe := MeshInstance3D.new()
	faction_stripe.name = "FactionStripe"
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(5.5, 0.20, 0.12)
	faction_stripe.mesh = stripe_mesh
	faction_stripe.position = Vector3(0.0, 2.72, -2.67)
	faction_stripe.material_override = _make_armour_material(_get_faction_accent_color(faction_id))
	building.add_child(faction_stripe)

	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.15, 1.75, 0.10)
	door.mesh = door_mesh
	door.position = Vector3(0.0, 0.88, -2.66)
	door.material_override = _make_armour_material(Color(0.10, 0.12, 0.11))
	building.add_child(door)

	if kind == "bunker":
		var firing_slit := MeshInstance3D.new()
		firing_slit.name = "BunkerFiringSlit"
		var slit_mesh := BoxMesh.new()
		slit_mesh.size = Vector3(2.6, 0.22, 0.10)
		firing_slit.mesh = slit_mesh
		firing_slit.position = Vector3(0.0, 1.55, -3.12)
		firing_slit.material_override = _make_armour_material(Color(0.08, 0.10, 0.10))
		building.add_child(firing_slit)
	for side in [-1.0, 1.0]:
		var window := MeshInstance3D.new()
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(1.0, 0.58, 0.08)
		window.mesh = window_mesh
		window.position = Vector3(side * 1.72, 2.05, -2.67)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.12, 0.25, 0.30)
		glass.metallic = 0.35
		glass.roughness = 0.18
		glass.emission_enabled = true
		glass.emission = Color(0.035, 0.10, 0.13)
		glass.emission_energy_multiplier = 0.45
		window.material_override = glass
		building.add_child(window)

	if kind == "command":
		var command_tower := MeshInstance3D.new()
		var tower_mesh := BoxMesh.new()
		tower_mesh.size = Vector3(1.7, 1.35, 1.7)
		command_tower.mesh = tower_mesh
		command_tower.position = Vector3(0.0, 3.85, 0.0)
		command_tower.material_override = _make_armour_material(tint.lightened(0.12))
		building.add_child(command_tower)
		var antenna := MeshInstance3D.new()
		var antenna_mesh := CylinderMesh.new()
		antenna_mesh.top_radius = 0.025
		antenna_mesh.bottom_radius = 0.045
		antenna_mesh.height = 1.8
		antenna.mesh = antenna_mesh
		antenna.position = Vector3(0.0, 5.42, 0.0)
		antenna.material_override = _make_armour_material(Color(0.12, 0.14, 0.13))
		building.add_child(antenna)
	elif kind == "factory":
		for side in [-1.0, 1.0]:
			var vent := MeshInstance3D.new()
			var vent_mesh := CylinderMesh.new()
			vent_mesh.top_radius = 0.28
			vent_mesh.bottom_radius = 0.38
			vent_mesh.height = 1.15
			vent.mesh = vent_mesh
			vent.position = Vector3(side * 2.0, 3.78, 1.25)
			vent.material_override = _make_armour_material(Color(0.18, 0.19, 0.17))
			building.add_child(vent)
	elif kind == "airfield":
		for side in [-1.0, 1.0]:
			var runway_light := MeshInstance3D.new()
			var light_mesh := SphereMesh.new()
			light_mesh.radius = 0.11
			light_mesh.height = 0.22
			runway_light.mesh = light_mesh
			runway_light.position = Vector3(side * 3.8, 0.18, 0.0)
			var light_material := StandardMaterial3D.new()
			light_material.albedo_color = Color(0.18, 0.72, 0.95)
			light_material.emission_enabled = true
			light_material.emission = light_material.albedo_color
			light_material.emission_energy_multiplier = 1.3
			runway_light.material_override = light_material
			building.add_child(runway_light)

	elif kind == "turret" or kind == "anti_air":
		var mount := MeshInstance3D.new()
		var mount_mesh := CylinderMesh.new()
		mount_mesh.top_radius = 1.05
		mount_mesh.bottom_radius = 1.35
		mount_mesh.height = 0.72
		mount.mesh = mount_mesh
		mount.position.y = 3.35
		mount.material_override = _make_armour_material(tint.darkened(0.18))
		building.add_child(mount)
		for barrel_index in range(2 if kind == "anti_air" else 1):
			var barrel := MeshInstance3D.new()
			var barrel_mesh := BoxMesh.new()
			barrel_mesh.size = Vector3(0.20, 0.22, 2.25)
			barrel.mesh = barrel_mesh
			barrel.position = Vector3(-0.22 + float(barrel_index) * 0.44, 3.55, -1.55)
			barrel.material_override = _make_armour_material(Color(0.12, 0.14, 0.13))
			building.add_child(barrel)
	elif kind == "missile_silo":
		var silo := MeshInstance3D.new()
		var silo_mesh := CylinderMesh.new()
		silo_mesh.top_radius = 0.82
		silo_mesh.bottom_radius = 1.02
		silo_mesh.height = 2.8
		silo.mesh = silo_mesh
		silo.position = Vector3(0.0, 4.65, 0.0)
		silo.material_override = _make_armour_material(Color(0.24, 0.27, 0.24))
		building.add_child(silo)
		var hatch := MeshInstance3D.new()
		var hatch_mesh := CylinderMesh.new()
		hatch_mesh.top_radius = 1.12
		hatch_mesh.bottom_radius = 1.12
		hatch_mesh.height = 0.16
		hatch.mesh = hatch_mesh
		hatch.position = Vector3(0.0, 6.12, 0.0)
		hatch.material_override = _make_armour_material(Color(0.48, 0.43, 0.31))
		building.add_child(hatch)
	elif kind == "missile_defense":
		var radar_mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.06
		mast_mesh.bottom_radius = 0.12
		mast_mesh.height = 3.1
		radar_mast.mesh = mast_mesh
		radar_mast.position = Vector3(0.0, 4.75, 0.0)
		radar_mast.material_override = _make_armour_material(Color(0.14, 0.17, 0.16))
		building.add_child(radar_mast)
		var dish := MeshInstance3D.new()
		var dish_mesh := SphereMesh.new()
		dish_mesh.radius = 0.78
		dish_mesh.height = 0.28
		dish.mesh = dish_mesh
		dish.position = Vector3(0.0, 6.35, -0.12)
		dish.rotation.x = -0.48
		dish.material_override = _make_armour_material(Color(0.62, 0.68, 0.65))
		building.add_child(dish)
	elif kind == "power_plant":
		for side in [-1.0, 1.0]:
			var cooling_tower := MeshInstance3D.new()
			var tower_mesh := CylinderMesh.new()
			tower_mesh.top_radius = 0.62
			tower_mesh.bottom_radius = 0.92
			tower_mesh.height = 2.5
			cooling_tower.mesh = tower_mesh
			cooling_tower.position = Vector3(side * 1.8, 4.2, 0.5)
			cooling_tower.material_override = _make_armour_material(Color(0.55, 0.54, 0.45))
			building.add_child(cooling_tower)
	elif kind == "shipyard":
		var dock := MeshInstance3D.new()
		var dock_mesh := BoxMesh.new()
		dock_mesh.size = Vector3(10.0, 0.24, 8.5)
		dock.mesh = dock_mesh
		dock.position = Vector3(0.0, 0.12, 0.0)
		dock.material_override = _make_armour_material(Color(0.22, 0.29, 0.30))
		building.add_child(dock)
		for side in [-1.0, 1.0]:
			var crane_leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.22, 3.8, 0.22)
			crane_leg.mesh = leg_mesh
			crane_leg.position = Vector3(side * 3.3, 4.8, -1.8)
			crane_leg.material_override = _make_armour_material(Color(0.78, 0.58, 0.20))
			building.add_child(crane_leg)
		var crane_beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(7.0, 0.24, 0.24)
		crane_beam.mesh = beam_mesh
		crane_beam.position = Vector3(0.0, 6.65, -1.8)
		crane_beam.material_override = _make_armour_material(Color(0.78, 0.58, 0.20))
		building.add_child(crane_beam)

	if show_progress:
		building.set_meta("construction_progress", clampf(build_progress, 0.0, 1.0))
		var progress_back := MeshInstance3D.new()
		progress_back.name = "ConstructionProgressBackground"
		var back_mesh := BoxMesh.new()
		back_mesh.size = Vector3(3.2, 0.10, 0.16)
		progress_back.mesh = back_mesh
		progress_back.position = Vector3(0.0, 5.15, 0.0)
		progress_back.material_override = _make_armour_material(Color(0.07, 0.09, 0.08))
		progress_back.visible = build_progress < 1.0
		building.add_child(progress_back)

		var progress_fill := MeshInstance3D.new()
		progress_fill.name = "ConstructionProgressFill"
		var fill_mesh := BoxMesh.new()
		fill_mesh.size = Vector3(3.0, 0.12, 0.18)
		progress_fill.mesh = fill_mesh
		progress_fill.position = Vector3(-1.5, 5.16, -0.01)
		progress_fill.material_override = _make_armour_material(Color(0.34, 0.82, 0.48))
		progress_fill.scale.x = maxf(0.001, clampf(build_progress, 0.0, 1.0))
		progress_fill.visible = build_progress < 1.0
		building.add_child(progress_fill)
	return building

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
				touch_multi_gesture = true
				var points: Array = touch_points.values()
				last_pinch_distance = points[0].distance_to(points[1])
				last_pinch_center = (points[0] + points[1]) * 0.5
		else:
			var had_start := touch_start_positions.has(touch.index)
			var was_drag := had_start and bool(touch_moved.get(touch.index, false)) and touch_points.size() == 1 and not touch_multi_gesture
			var was_tap: bool = had_start and not bool(touch_moved.get(touch.index, true)) and touch_points.size() == 1 and not touch_multi_gesture
			if was_drag and _tank_at_screen_position(touch_start_positions[touch.index]) == null:
				_select_live_units_in_screen_rect(touch_start_positions[touch.index], touch.position)
			elif was_tap:
				_handle_world_tap(touch.position)
			touch_points.erase(touch.index)
			touch_start_positions.erase(touch.index)
			touch_moved.erase(touch.index)
			if touch_points.is_empty():
				last_pinch_distance = 0.0
				last_pinch_center = Vector2.ZERO
				touch_multi_gesture = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touch_points.has(drag.index):
			touch_points[drag.index] = drag.position
		if touch_start_positions.has(drag.index) and drag.position.distance_to(touch_start_positions[drag.index]) > 12.0:
			touch_moved[drag.index] = true
		if touch_points.size() >= 2:
			var points: Array = touch_points.values()
			var distance: float = points[0].distance_to(points[1])
			var first_point: Vector2 = points[0]
			var second_point: Vector2 = points[1]
			var center: Vector2 = (first_point + second_point) * 0.5
			if last_pinch_distance > 0.0 and distance > 1.0:
				_zoom_camera(last_pinch_distance / distance)
				_pan_camera(center - last_pinch_center)
			last_pinch_distance = distance
			last_pinch_center = center
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			selection_gesture_start = mouse_button.position
			selection_gesture_active = true
			selection_gesture_dragging = false
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed and selection_gesture_active:
			if selection_gesture_dragging:
				_select_live_units_in_screen_rect(selection_gesture_start, mouse_button.position)
			else:
				_handle_world_tap(mouse_button.position)
			selection_gesture_active = false
			selection_gesture_dragging = false
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_camera(0.90)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_camera(1.10)
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_pan_active = mouse_button.pressed
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if selection_gesture_active and selection_gesture_start.distance_to(motion.position) > 12.0:
			selection_gesture_dragging = true
		elif mouse_pan_active:
			_pan_camera(motion.relative)

func _build_lighting() -> void:
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun_light.light_energy = 1.25
	sun_light.shadow_enabled = true
	add_child(sun_light)
	_apply_mobile_quality_profile(OS.has_feature("mobile"))


func _apply_mobile_quality_profile(mobile_device: bool) -> void:
	# Real-time directional shadows are one of the costliest parts of this
	# prototype on mobile GPUs. Keep desktop presentation intact, but prefer
	# stable frame time on phones and tablets.
	if is_instance_valid(sun_light):
		sun_light.shadow_enabled = not mobile_device

func _build_showcase_units() -> void:
	_add_placeholder_tank(Vector3(-7.0, 0.0, 1.0), Color(0.28, 0.34, 0.22), "american")
	_add_placeholder_tank(Vector3(0.0, 0.0, -2.0), Color(0.34, 0.37, 0.40), "chinese")
	_add_placeholder_tank(Vector3(7.0, 0.0, 1.0), Color(0.48, 0.39, 0.25), "arab")
	_build_showcase_infantry()
	_build_showcase_aircraft()
	_build_showcase_air_defenses()
	_build_showcase_radars()


func _build_showcase_aircraft() -> void:
	_add_placeholder_helicopter(Vector3(-12.0, 5.2, -9.0), Color(0.28, 0.36, 0.25), "american")
	_add_placeholder_fighter(Vector3(12.0, 6.4, -10.0), Color(0.40, 0.43, 0.46), "chinese")

func _add_placeholder_helicopter(at: Vector3, tint: Color, faction_id: String) -> void:
	var helicopter := Node3D.new()
	helicopter.position = at
	add_child(helicopter)
	showcase_tanks.append(helicopter)
	helicopter.set_meta("health", 100.0)
	helicopter.set_meta("unit_type", "helicopter")
	helicopter.set_meta("faction_id", faction_id)
	_create_showcase_health_bar(helicopter)

	var hull := MeshInstance3D.new()
	var hull_mesh := CapsuleMesh.new()
	hull_mesh.radius = 0.58
	hull_mesh.height = 2.7
	hull.mesh = hull_mesh
	hull.rotation_degrees.x = 90.0
	hull.material_override = _make_armour_material(tint)
	helicopter.add_child(hull)
	_add_faction_insignia(helicopter, faction_id, Vector3(0.0, 0.58, 0.25), Vector3(0.48, 0.07, 0.32))

	var cockpit := MeshInstance3D.new()
	var cockpit_mesh := SphereMesh.new()
	cockpit_mesh.radius = 0.48
	cockpit_mesh.height = 0.75
	cockpit.mesh = cockpit_mesh
	cockpit.position = Vector3(0.0, 0.08, -1.0)
	cockpit.material_override = _make_armour_material(Color(0.12, 0.20, 0.22))
	helicopter.add_child(cockpit)

	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.18, 0.18, 2.3)
	tail.mesh = tail_mesh
	tail.position.z = 2.0
	tail.material_override = _make_armour_material(tint.darkened(0.18))
	helicopter.add_child(tail)

	var rotor_pivot := Node3D.new()
	rotor_pivot.position.y = 0.72
	helicopter.add_child(rotor_pivot)
	aircraft_rotors.append(rotor_pivot)
	for side in [-1.0, 1.0]:
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.18, 0.055, 5.0)
		blade.mesh = blade_mesh
		blade.rotation.y = PI * 0.25 if side < 0.0 else -PI * 0.25
		blade.material_override = _make_armour_material(Color(0.12, 0.13, 0.12))
		rotor_pivot.add_child(blade)

	# Tail rotor provides a second independent, low-cost animation axis.
	var tail_rotor := Node3D.new()
	tail_rotor.position = Vector3(0.0, 0.18, 3.05)
	helicopter.add_child(tail_rotor)
	aircraft_tail_rotors.append(tail_rotor)
	for blade_index in range(2):
		var tail_blade := MeshInstance3D.new()
		var tail_blade_mesh := BoxMesh.new()
		tail_blade_mesh.size = Vector3(0.10, 1.05, 0.16)
		tail_blade.mesh = tail_blade_mesh
		tail_blade.rotation.z = float(blade_index) * PI * 0.5
		tail_blade.material_override = _make_armour_material(Color(0.10, 0.11, 0.10))
		tail_rotor.add_child(tail_blade)

	var weapon_pivot := Node3D.new()
	weapon_pivot.position = Vector3(0.0, -0.32, -0.15)
	helicopter.add_child(weapon_pivot)
	showcase_turrets.append(weapon_pivot)
	for side in [-1.0, 1.0]:
		var rocket := MeshInstance3D.new()
		var rocket_mesh := CylinderMesh.new()
		rocket_mesh.top_radius = 0.10
		rocket_mesh.bottom_radius = 0.10
		rocket_mesh.height = 1.25
		rocket.mesh = rocket_mesh
		rocket.rotation_degrees.x = 90.0
		rocket.position = Vector3(side * 0.78, -0.12, -0.35)
		rocket.material_override = _make_armour_material(Color(0.18, 0.19, 0.17))
		weapon_pivot.add_child(rocket)

func _add_placeholder_fighter(at: Vector3, tint: Color, faction_id: String) -> void:
	var fighter := Node3D.new()
	fighter.position = at
	add_child(fighter)
	showcase_tanks.append(fighter)
	fighter.set_meta("health", 100.0)
	fighter.set_meta("unit_type", "fighter")
	fighter.set_meta("faction_id", faction_id)
	_create_showcase_health_bar(fighter)

	var fuselage := MeshInstance3D.new()
	var fuselage_mesh := BoxMesh.new()
	fuselage_mesh.size = Vector3(0.72, 0.48, 4.8)
	fuselage.mesh = fuselage_mesh
	fuselage.material_override = _make_armour_material(tint)
	fighter.add_child(fuselage)

	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.03
	nose_mesh.bottom_radius = 0.34
	nose_mesh.height = 1.0
	nose.mesh = nose_mesh
	nose.rotation_degrees.x = 90.0
	nose.position.z = -2.55
	nose.material_override = _make_armour_material(tint.lightened(0.08))
	fighter.add_child(nose)

	var wings := MeshInstance3D.new()
	var wings_mesh := BoxMesh.new()
	wings_mesh.size = Vector3(6.2, 0.16, 1.35)
	wings.mesh = wings_mesh
	wings.position.z = 0.15
	wings.material_override = _make_armour_material(tint.darkened(0.12))
	fighter.add_child(wings)
	var left_faction_insignia := _add_faction_insignia(fighter, faction_id, Vector3(-1.65, 0.12, 0.15), Vector3(0.52, 0.07, 0.36))
	left_faction_insignia.name = "FactionInsignia_Left"
	var right_faction_insignia := _add_faction_insignia(fighter, faction_id, Vector3(1.65, 0.12, 0.15), Vector3(0.52, 0.07, 0.36))
	right_faction_insignia.name = "FactionInsignia_Right"

	var tail_wing := MeshInstance3D.new()
	var tail_wing_mesh := BoxMesh.new()
	tail_wing_mesh.size = Vector3(2.0, 0.12, 0.65)
	tail_wing.mesh = tail_wing_mesh
	tail_wing.position.z = 1.85
	tail_wing.material_override = _make_armour_material(tint.darkened(0.15))
	fighter.add_child(tail_wing)

	var cockpit := MeshInstance3D.new()
	var cockpit_mesh := SphereMesh.new()
	cockpit_mesh.radius = 0.28
	cockpit_mesh.height = 0.48
	cockpit.mesh = cockpit_mesh
	cockpit.position = Vector3(0.0, 0.32, -0.65)
	cockpit.material_override = _make_armour_material(Color(0.10, 0.19, 0.24))
	fighter.add_child(cockpit)

	# Small red/green navigation lamps improve aircraft readability at RTS scale.
	for side in [-1.0, 1.0]:
		var nav_light := MeshInstance3D.new()
		var nav_mesh := SphereMesh.new()
		nav_mesh.radius = 0.10
		nav_mesh.height = 0.20
		nav_light.mesh = nav_mesh
		nav_light.position = Vector3(side * 3.08, 0.12, 0.18)
		var nav_material := StandardMaterial3D.new()
		nav_material.albedo_color = Color(0.95, 0.12, 0.08) if side < 0.0 else Color(0.12, 0.82, 0.38)
		nav_material.emission_enabled = true
		nav_material.emission = nav_material.albedo_color
		nav_material.emission_energy_multiplier = 2.2
		nav_light.material_override = nav_material
		fighter.add_child(nav_light)
		aircraft_lights.append(nav_light)

	var weapon_pivot := Node3D.new()
	weapon_pivot.position.y = -0.12
	fighter.add_child(weapon_pivot)
	showcase_turrets.append(weapon_pivot)

func _add_naval_propeller(vessel: Node3D, propeller_name: String, side_x: float) -> void:
	var propeller := Node3D.new()
	propeller.name = propeller_name
	propeller.position = Vector3(side_x, 0.08, 3.85)
	vessel.add_child(propeller)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.13
	hub_mesh.bottom_radius = 0.13
	hub_mesh.height = 0.28
	hub.mesh = hub_mesh
	hub.material_override = _make_armour_material(Color(0.12, 0.14, 0.15))
	propeller.add_child(hub)
	for blade_index in range(3):
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.10, 0.07, 0.72)
		blade.mesh = blade_mesh
		blade.rotation.y = TAU * float(blade_index) / 3.0
		blade.position.z = 0.32
		blade.material_override = _make_armour_material(Color(0.20, 0.23, 0.23))
		propeller.add_child(blade)
	naval_propellers.append(propeller)

func _update_naval_combat(delta: float) -> void:
	# Destroyers automatically engage the nearest hostile contact in cannon range.
	for unit_key in game_unit_nodes.keys():
		var vessel_variant = game_unit_nodes[unit_key]
		if not is_instance_valid(vessel_variant):
			continue
		var vessel := vessel_variant as Node3D
		if not is_instance_valid(vessel) or str(vessel.get_meta("unit_type", "")) != "destroyer":
			continue
		var team := str(vessel.get_meta("source_team", ""))
		if team.is_empty():
			continue
		var target := _find_naval_target(vessel, team, 15.0)
		if not is_instance_valid(target):
			continue
		var cooldown := maxf(0.0, float(vessel.get_meta("naval_fire_cooldown", 0.0)) - delta)
		if cooldown > 0.0:
			vessel.set_meta("naval_fire_cooldown", cooldown)
			continue
		var vessel_index := showcase_tanks.find(vessel)
		if vessel_index < 0 or vessel_index >= showcase_turrets.size():
			continue
		var weapon_pivot := showcase_turrets[vessel_index]
		weapon_pivot.look_at(target.global_position + Vector3.UP * 0.8, Vector3.UP)
		_fire_naval_shell(weapon_pivot, target, vessel)
		vessel.set_meta("naval_fire_cooldown", 2.4)

func _find_naval_target(vessel: Node3D, team: String, max_range: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance := max_range
	for candidate_key in game_unit_nodes.keys():
		var candidate_variant = game_unit_nodes[candidate_key]
		if not is_instance_valid(candidate_variant):
			continue
		var candidate := candidate_variant as Node3D
		if not is_instance_valid(candidate) or candidate == vessel:
			continue
		if str(candidate.get_meta("source_team", "")) == team:
			continue
		var distance := vessel.global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _fire_naval_shell(pivot: Node3D, target: Node3D, vessel: Node3D) -> void:
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.11
	shell_mesh.height = 0.22
	shell.mesh = shell_mesh
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(1.0, 0.72, 0.28)
	shell_material.emission_enabled = true
	shell_material.emission = Color(1.0, 0.32, 0.06)
	shell_material.emission_energy_multiplier = 2.6
	shell.material_override = shell_material
	add_child(shell)
	shell.global_position = pivot.global_position + (-pivot.global_transform.basis.z * 2.2) + Vector3.UP * 0.25
	_spawn_muzzle_flash(shell.global_position, 1.35)
	_play_combat_audio(shell.global_position, false)
	var destination := target.global_position + Vector3.UP * 0.75
	var tween := create_tween()
	tween.tween_property(shell, "global_position", destination, 0.38)
	tween.tween_callback(_resolve_naval_shell_hit.bind(shell, target, 22.0))

func _resolve_naval_shell_hit(shell: Node3D, target: Node3D, damage: float) -> void:
	if is_instance_valid(shell):
		shell.queue_free()
	if not is_instance_valid(target):
		return
	var remaining := float(target.get_meta("health", 100.0)) - damage
	target.set_meta("health", remaining)
	_spawn_impact_flash(target.global_position, remaining <= 0.0)
	_play_combat_audio(target.global_position, true)
	if remaining <= 0.0:
		var source_key := str(target.get_meta("source_unit_key", ""))
		if not source_key.is_empty():
			game_unit_nodes.erase(source_key)
		var target_index := showcase_tanks.find(target)
		if target_index >= 0:
			showcase_tanks.remove_at(target_index)
			if target_index < showcase_turrets.size():
				showcase_turrets.remove_at(target_index)
		showcase_health_bars.erase(target)
		if is_instance_valid(selected_tank) and selected_tank == target:
			selected_tank = null
			selection_ring.visible = false
		if is_instance_valid(attack_target) and attack_target == target:
			attack_target = null
		target.queue_free()

func _update_carrier_air_operations(delta: float) -> void:
	carrier_aircraft_clock += delta
	# Launch a light visual patrol flight from each carrier at a measured interval.
	for unit_key in game_unit_nodes.keys():
		var carrier_variant = game_unit_nodes[unit_key]
		if not is_instance_valid(carrier_variant):
			continue
		var carrier := carrier_variant as Node3D
		if not is_instance_valid(carrier) or str(carrier.get_meta("unit_type", "")) != "carrier":
			continue
		var cooldown := maxf(0.0, float(carrier.get_meta("air_ops_cooldown", 0.0)) - delta)
		carrier.set_meta("air_ops_cooldown", cooldown)
		if cooldown <= 0.0:
			_launch_carrier_aircraft(carrier)
			carrier.set_meta("air_ops_cooldown", 14.0)
	# Aircraft circle the carrier group briefly, then return to the flight deck.
	for flight_index in range(carrier_aircraft.size() - 1, -1, -1):
		var flight: Dictionary = carrier_aircraft[flight_index]
		var aircraft_variant = flight.get("node")
		var carrier_variant = flight.get("carrier")
		var aircraft: Node3D = aircraft_variant as Node3D if is_instance_valid(aircraft_variant) else null
		var carrier: Node3D = carrier_variant as Node3D if is_instance_valid(carrier_variant) else null
		if not is_instance_valid(aircraft) or not is_instance_valid(carrier):
			if is_instance_valid(aircraft):
				aircraft.queue_free()
			carrier_aircraft.remove_at(flight_index)
			continue
		var age := float(flight.get("age", 0.0)) + delta
		flight.age = age
		var phase := float(flight.get("phase", 0.0)) + delta * 0.72
		flight.phase = phase
		var landing_progress := clampf((age - 6.0) / 3.0, 0.0, 1.0)
		var radius := 5.5 if age < 6.0 else lerpf(5.5, 0.0, landing_progress)
		var angle := phase + float(flight.get("lane", 0.0))
		var flight_height := 4.8 + sin(phase * 2.0) * 0.18 if age < 6.0 else lerpf(4.8, 1.48, landing_progress)
		aircraft.position = carrier.position + Vector3(cos(angle) * radius, flight_height, sin(angle) * radius)
		aircraft.rotation.y = -angle
		if age >= 9.0:
			aircraft.queue_free()
			carrier_aircraft.remove_at(flight_index)
		else:
			carrier_aircraft[flight_index] = flight

func _launch_carrier_aircraft(carrier: Node3D) -> void:
	var aircraft := Node3D.new()
	aircraft.name = "CarrierPatrolAircraft"
	var fuselage := MeshInstance3D.new()
	var fuselage_mesh := BoxMesh.new()
	fuselage_mesh.size = Vector3(0.34, 0.22, 1.8)
	fuselage.mesh = fuselage_mesh
	fuselage.material_override = _make_armour_material(Color(0.48, 0.54, 0.55))
	aircraft.add_child(fuselage)
	var wings := MeshInstance3D.new()
	var wings_mesh := BoxMesh.new()
	wings_mesh.size = Vector3(2.0, 0.10, 0.48)
	wings.mesh = wings_mesh
	wings.position.z = 0.08
	wings.material_override = _make_armour_material(Color(0.32, 0.39, 0.42))
	aircraft.add_child(wings)
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.92, 0.08, 0.3)
	tail.mesh = tail_mesh
	tail.position.z = 0.68
	tail.material_override = _make_armour_material(Color(0.32, 0.39, 0.42))
	aircraft.add_child(tail)
	add_child(aircraft)
	aircraft.position = carrier.position + Vector3(0.0, 1.45, -3.0)
	carrier_aircraft.append({
		"node": aircraft,
		"carrier": carrier,
		"age": 0.0,
		"phase": 0.0,
		"lane": float(carrier.get_instance_id() % 7) * 0.72
	})
	_spawn_muzzle_flash(aircraft.global_position, 0.75)

func _update_naval_animation(delta: float) -> void:
	naval_animation_clock += delta
	for propeller in naval_propellers:
		if is_instance_valid(propeller):
			propeller.rotation.z += delta * 12.0
	for vessel in showcase_tanks:
		if not is_instance_valid(vessel):
			continue
		var vessel_kind := str(vessel.get_meta("unit_type", ""))
		if vessel_kind in ["destroyer", "carrier", "landing_craft"]:
			var base_height := float(vessel.get_meta("waterline_height", 0.12))
			vessel.position.y = base_height + sin(naval_animation_clock * 1.45 + float(vessel.get_instance_id() % 11)) * 0.035
			vessel.rotation.z = sin(naval_animation_clock * 0.72 + float(vessel.get_instance_id() % 7)) * 0.008
		elif vessel_kind == "submarine":
			var submerged_height := float(vessel.get_meta("waterline_height", -0.62))
			vessel.position.y = submerged_height + sin(naval_animation_clock * 0.8 + float(vessel.get_instance_id() % 5)) * 0.012

func _update_aircraft_animation(delta: float) -> void:
	aircraft_clock += delta
	for rotor in aircraft_rotors:
		if is_instance_valid(rotor):
			rotor.rotation.y += delta * 18.0
	for rotor in aircraft_tail_rotors:
		if is_instance_valid(rotor):
			rotor.rotation.z += delta * 25.0
	var light_on := sin(aircraft_clock * 5.0) > 0.0
	for light in aircraft_lights:
		if is_instance_valid(light):
			var light_material := light.material_override as StandardMaterial3D
			light_material.emission_energy_multiplier = 2.2 if light_on else 0.12
	for unit in showcase_tanks:
		if not is_instance_valid(unit):
			continue
		var unit_type := str(unit.get_meta("unit_type", "tank"))
		if unit_type == "helicopter" and unit != selected_tank and not (unit == selected_tank and has_selected_destination):
			unit.position.y = 5.2 + sin(aircraft_clock * 2.1 + float(unit.get_instance_id() % 9)) * 0.12
		elif unit_type == "fighter" and unit != selected_tank and not (unit == selected_tank and has_selected_destination):
			unit.position.y = 6.4 + sin(aircraft_clock * 1.7 + float(unit.get_instance_id() % 7)) * 0.16

func _build_showcase_air_defenses() -> void:
	_add_air_defense_turret(Vector3(-16.0, 0.0, -1.0), Color(0.30, 0.37, 0.27), "american")
	_add_air_defense_turret(Vector3(16.0, 0.0, 1.0), Color(0.37, 0.38, 0.40), "chinese")

func _add_air_defense_turret(at: Vector3, tint: Color, faction_id: String) -> void:
	var emplacement := Node3D.new()
	emplacement.position = at
	add_child(emplacement)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.05
	base_mesh.bottom_radius = 1.35
	base_mesh.height = 0.65
	base.mesh = base_mesh
	base.position.y = 0.34
	base.material_override = _make_armour_material(tint.darkened(0.20))
	emplacement.add_child(base)

	var shield := MeshInstance3D.new()
	var shield_mesh := BoxMesh.new()
	shield_mesh.size = Vector3(1.7, 1.0, 1.35)
	shield.mesh = shield_mesh
	shield.position.y = 1.05
	shield.material_override = _make_armour_material(tint)
	emplacement.add_child(shield)

	var tracking_pivot := Node3D.new()
	tracking_pivot.position.y = 1.42
	emplacement.add_child(tracking_pivot)
	for side in [-1.0, 1.0]:
		var launcher := MeshInstance3D.new()
		var launcher_mesh := CylinderMesh.new()
		launcher_mesh.top_radius = 0.16
		launcher_mesh.bottom_radius = 0.20
		launcher_mesh.height = 1.8
		launcher.mesh = launcher_mesh
		launcher.rotation_degrees.x = 90.0
		launcher.position = Vector3(side * 0.43, 0.15, -0.45)
		launcher.material_override = _make_armour_material(Color(0.13, 0.15, 0.14))
		tracking_pivot.add_child(launcher)
	tracking_pivot.set_meta("faction_id", faction_id)
	air_defense_nodes.append(tracking_pivot)
	air_defense_cooldowns.append(0.8)

func _update_air_defenses(delta: float) -> void:
	for defense_index in range(air_defense_nodes.size()):
		var defense := air_defense_nodes[defense_index]
		if not is_instance_valid(defense):
			continue
		air_defense_cooldowns[defense_index] = maxf(0.0, air_defense_cooldowns[defense_index] - delta)
		var nearest_aircraft: Node3D = null
		var nearest_distance := 22.0
		for candidate in showcase_tanks:
			if not is_instance_valid(candidate):
				continue
			var candidate_type := str(candidate.get_meta("unit_type", "tank"))
			if candidate_type != "helicopter" and candidate_type != "fighter":
				continue
			if str(candidate.get_meta("faction_id", "")) == str(defense.get_meta("faction_id", "")):
				continue
			var distance := defense.global_position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_aircraft = candidate
		if nearest_aircraft == null:
			continue
		defense.look_at(nearest_aircraft.global_position, Vector3.UP)
		if air_defense_cooldowns[defense_index] > 0.0:
			continue
		air_defense_cooldowns[defense_index] = 2.2
		_fire_air_defense_missile(defense, nearest_aircraft)

func _fire_air_defense_missile(defense: Node3D, target: Node3D) -> void:
	var missile := MeshInstance3D.new()
	var missile_mesh := CapsuleMesh.new()
	missile_mesh.radius = 0.10
	missile_mesh.height = 0.65
	missile.mesh = missile_mesh
	missile.rotation_degrees.x = 90.0
	var missile_material := StandardMaterial3D.new()
	missile_material.albedo_color = Color(0.82, 0.84, 0.72)
	missile_material.emission_enabled = true
	missile_material.emission = Color(1.0, 0.38, 0.08)
	missile_material.emission_energy_multiplier = 1.4
	missile.material_override = missile_material
	add_child(missile)
	missile.global_position = defense.global_position + (-defense.global_transform.basis.z * 1.0)
	var flight_time := clampf(missile.global_position.distance_to(target.global_position) / 18.0, 0.35, 1.1)
	var tween := create_tween()
	tween.tween_property(missile, "global_position", target.global_position, flight_time)
	tween.tween_callback(_resolve_air_defense_hit.bind(missile, target))

func _resolve_air_defense_hit(missile: Node3D, target: Node3D) -> void:
	if is_instance_valid(missile):
		missile.queue_free()
	if not is_instance_valid(target):
		return
	_resolve_showcase_hit(null, target, 35.0)



func _build_tactical_radar_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TacticalRadarHUD"
	layer.layer = 8
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "RadarPanel"
	# CanvasLayer controls can remain visible when their Node3D parent is hidden.
	# Start hidden and let the active 3D-view toggle control this overlay explicitly.
	panel.visible = false
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -274.0
	panel.offset_top = -218.0
	panel.offset_right = -12.0
	panel.offset_bottom = -12.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.045, 0.04, 0.94)
	panel_style.border_color = Color(0.24, 0.48, 0.36, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "شبكة التهديدات التكتيكية"
	heading.add_theme_color_override("font_color", Color(0.66, 0.86, 0.72))
	heading.add_theme_font_size_override("font_size", 13)
	column.add_child(heading)
	var plot := Control.new()
	plot.name = "RadarPlot"
	plot.custom_minimum_size = Vector2(240.0, 132.0)
	plot.clip_contents = true
	column.add_child(plot)
	radar_plot = plot
	var plot_bg := ColorRect.new()
	plot_bg.color = Color(0.035, 0.085, 0.065, 1.0)
	plot_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plot.add_child(plot_bg)
	for grid_x in range(1, 4):
		var line := ColorRect.new()
		line.color = Color(0.18, 0.36, 0.27, 0.48)
		line.position = Vector2(float(grid_x) * 60.0, 0.0)
		line.size = Vector2(1.0, 132.0)
		plot.add_child(line)
	for grid_y in range(1, 3):
		var line := ColorRect.new()
		line.color = Color(0.18, 0.36, 0.27, 0.48)
		line.position = Vector2(0.0, float(grid_y) * 44.0)
		line.size = Vector2(240.0, 1.0)
		plot.add_child(line)
	var center_h := ColorRect.new()
	center_h.color = Color(0.30, 0.55, 0.40, 0.55)
	center_h.position = Vector2(0.0, 65.5)
	center_h.size = Vector2(240.0, 1.0)
	plot.add_child(center_h)
	var center_v := ColorRect.new()
	center_v.color = Color(0.30, 0.55, 0.40, 0.55)
	center_v.position = Vector2(119.5, 0.0)
	center_v.size = Vector2(1.0, 132.0)
	plot.add_child(center_v)
	var sweep := ColorRect.new()
	sweep.color = Color(0.30, 0.92, 0.55, 0.65)
	sweep.position = Vector2(119.0, 2.0)
	sweep.size = Vector2(2.0, 62.0)
	sweep.pivot_offset = Vector2(1.0, 64.0)
	plot.add_child(sweep)
	radar_sweep_widget = sweep
	var own_base := ColorRect.new()
	own_base.color = Color(0.20, 0.78, 0.95)
	own_base.position = Vector2(116.0, 62.0)
	own_base.size = Vector2(8.0, 8.0)
	plot.add_child(own_base)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var status := Label.new()
	status.text = "جوي 0  |  بري 0"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(0.42, 0.88, 0.60))
	footer.add_child(status)
	radar_status_label = status
	var count := Label.new()
	count.text = "اتصالات  0"
	count.add_theme_font_size_override("font_size", 11)
	count.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
	footer.add_child(count)
	radar_count_label = count
	var ground_status := Label.new()
	ground_status.text = "القطاع آمن  //  المسح نشط"
	ground_status.add_theme_font_size_override("font_size", 10)
	ground_status.add_theme_color_override("font_color", Color(0.55, 0.70, 0.59))
	column.add_child(ground_status)
	radar_ground_label = ground_status
	radar_hud = panel


func set_tactical_radar_visible(enabled: bool) -> void:
	if is_instance_valid(radar_hud):
		radar_hud.visible = enabled


func _update_radar_hud(delta: float) -> void:
	if not is_instance_valid(radar_plot):
		return
	if is_instance_valid(radar_sweep_widget):
		radar_sweep_widget.rotation += delta * 2.2
	var active_keys: Array[String] = []
	var hostile_air := 0
	var hostile_ground := 0
	for unit in showcase_tanks:
		if not is_instance_valid(unit):
			continue
		if str(unit.get_meta("faction_id", "")) == "american":
			continue
		var unit_type := str(unit.get_meta("unit_type", "tank"))
		var is_air := unit_type == "helicopter" or unit_type == "fighter"
		if not is_air and unit_type != "tank" and unit_type != "infantry":
			continue
		if Vector2(unit.global_position.x, unit.global_position.z).length() > 30.0:
			continue
		if is_air:
			hostile_air += 1
		else:
			hostile_ground += 1
		var key := str(unit.get_instance_id())
		active_keys.append(key)
		var blip := radar_blip_widgets.get(key) as ColorRect
		if not is_instance_valid(blip):
			blip = ColorRect.new()
			blip.size = Vector2(8.0, 8.0) if is_air else Vector2(6.0, 6.0)
			blip.color = Color(1.0, 0.20, 0.12) if is_air else Color(1.0, 0.48, 0.12)
			radar_plot.add_child(blip)
			radar_blip_widgets[key] = blip
		var px := clampf((unit.global_position.x + 30.0) / 60.0 * 240.0, 3.0, 233.0)
		var py := clampf((unit.global_position.z + 30.0) / 60.0 * 132.0, 3.0, 125.0)
		blip.position = Vector2(px, py)
		blip.visible = true
	for key_variant in radar_blip_widgets.keys():
		var key := str(key_variant)
		if not active_keys.has(key):
			var stale := radar_blip_widgets[key] as ColorRect
			if is_instance_valid(stale):
				stale.queue_free()
			radar_blip_widgets.erase(key)
	if is_instance_valid(radar_count_label):
		radar_count_label.text = "اتصالات  %d" % (hostile_air + hostile_ground)
	if is_instance_valid(radar_status_label):
		radar_status_label.text = "جوي %d  |  بري %d" % [hostile_air, hostile_ground]
		radar_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.20) if hostile_air + hostile_ground > 0 else Color(0.42, 0.88, 0.60))
	if is_instance_valid(radar_ground_label):
		radar_ground_label.text = "رصد تحرك معادٍ // المسح نشط" if hostile_air + hostile_ground > 0 else "القطاع آمن // المسح نشط"
		radar_ground_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.25) if hostile_air + hostile_ground > 0 else Color(0.55, 0.70, 0.59))

func _build_showcase_radars() -> void:
	_add_radar_station(Vector3(-14.0, 0.0, -7.0), "american")
	_add_radar_station(Vector3(14.0, 0.0, 8.0), "chinese")

func _add_radar_station(at: Vector3, faction_id: String) -> void:
	var station := Node3D.new()
	station.position = at
	station.set_meta("faction_id", faction_id)
	add_child(station)
	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.10
	mast_mesh.bottom_radius = 0.15
	mast_mesh.height = 3.2
	mast.mesh = mast_mesh
	mast.position.y = 1.6
	mast.material_override = _make_armour_material(Color(0.19, 0.21, 0.19))
	station.add_child(mast)
	var pivot := Node3D.new()
	pivot.position.y = 3.15
	station.add_child(pivot)
	var dish := MeshInstance3D.new()
	var dish_mesh := SphereMesh.new()
	dish_mesh.radius = 0.72
	dish_mesh.height = 0.28
	dish.mesh = dish_mesh
	dish.rotation_degrees.x = -18.0
	dish.material_override = _make_armour_material(Color(0.38, 0.43, 0.38))
	pivot.add_child(dish)
	var scanner := MeshInstance3D.new()
	var scanner_mesh := BoxMesh.new()
	scanner_mesh.size = Vector3(0.12, 0.12, 2.0)
	scanner.mesh = scanner_mesh
	scanner.position.z = -0.85
	scanner.material_override = _make_armour_material(Color(0.20, 0.78, 0.48))
	pivot.add_child(scanner)
	radar_nodes.append(station)
	radar_sweeps.append(pivot)

func _update_radar_network(delta: float) -> void:
	radar_alert_clock += delta
	for radar_index in range(radar_nodes.size()):
		var radar := radar_nodes[radar_index]
		if not is_instance_valid(radar):
			continue
		var sweep := radar_sweeps[radar_index]
		if is_instance_valid(sweep):
			sweep.rotation.y += delta * 2.8
		var radar_faction := str(radar.get_meta("faction_id", ""))
		var active_contacts: Array[String] = []
		for unit in showcase_tanks:
			if not is_instance_valid(unit):
				continue
			var unit_type := str(unit.get_meta("unit_type", "tank"))
			if unit_type != "helicopter" and unit_type != "fighter":
				continue
			var is_hostile := str(unit.get_meta("faction_id", "")) != radar_faction
			var in_range := radar.global_position.distance_to(unit.global_position) <= 26.0
			var blip_key := str(radar.get_instance_id()) + ":" + str(unit.get_instance_id())
			if is_hostile and in_range:
				active_contacts.append(blip_key)
				var blip: MeshInstance3D = null
				var existing_blip_variant = radar_blips.get(blip_key)
				if is_instance_valid(existing_blip_variant):
					blip = existing_blip_variant as MeshInstance3D
				if not is_instance_valid(blip):
					blip = MeshInstance3D.new()
					var blip_mesh := SphereMesh.new()
					blip_mesh.radius = 0.22
					blip_mesh.height = 0.44
					blip.mesh = blip_mesh
					var blip_material := StandardMaterial3D.new()
					blip_material.albedo_color = Color(1.0, 0.16, 0.10)
					blip_material.emission_enabled = true
					blip_material.emission = Color(1.0, 0.08, 0.03)
					blip_material.emission_energy_multiplier = 1.8
					blip.material_override = blip_material
					add_child(blip)
					radar_blips[blip_key] = blip
				blip.global_position = unit.global_position + Vector3.UP * (1.4 + sin(radar_alert_clock * 5.0) * 0.12)
				blip.visible = true
		for old_key_variant in radar_blips.keys():
			var old_key := str(old_key_variant)
			if old_key.begins_with(str(radar.get_instance_id()) + ":") and not active_contacts.has(old_key):
				var old_blip_variant = radar_blips[old_key]
				if is_instance_valid(old_blip_variant):
					var old_blip := old_blip_variant as MeshInstance3D
					old_blip.queue_free()
				radar_blips.erase(old_key)
func _build_showcase_infantry() -> void:
	_add_placeholder_infantry_squad(Vector3(-9.0, 0.0, 8.0), Color(0.30, 0.38, 0.25), "american")
	_add_placeholder_infantry_squad(Vector3(0.0, 0.0, 10.0), Color(0.34, 0.37, 0.40), "chinese")
	_add_placeholder_infantry_squad(Vector3(9.0, 0.0, 8.0), Color(0.48, 0.39, 0.25), "arab")

func _add_placeholder_infantry_squad(at: Vector3, faction_color: Color, faction_id: String) -> void:
	var squad := Node3D.new()
	squad.position = at
	add_child(squad)
	showcase_tanks.append(squad)
	squad.set_meta("health", 100.0)
	squad.set_meta("unit_type", "infantry")
	squad.set_meta("faction_id", faction_id)
	_create_showcase_health_bar(squad)

	var soldier_offsets := [
		Vector3(-0.72, 0.0, -0.48),
		Vector3(0.72, 0.0, -0.48),
		Vector3(-0.72, 0.0, 0.72),
		Vector3(0.72, 0.0, 0.72)
	]
	for soldier_index in range(soldier_offsets.size()):
		var soldier := Node3D.new()
		soldier.name = "Soldier_" + str(soldier_index)
		soldier.position = soldier_offsets[soldier_index]
		squad.add_child(soldier)

		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.22
		body_mesh.height = 0.92
		body.mesh = body_mesh
		body.position.y = 0.86
		body.material_override = _make_armour_material(faction_color)
		soldier.add_child(body)

		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.19
		head_mesh.height = 0.38
		head.mesh = head_mesh
		head.position.y = 1.48
		head.material_override = _make_armour_material(Color(0.48, 0.37, 0.29))
		soldier.add_child(head)

		var helmet := MeshInstance3D.new()
		var helmet_mesh := SphereMesh.new()
		helmet_mesh.radius = 0.22
		helmet_mesh.height = 0.20
		helmet.mesh = helmet_mesh
		helmet.position.y = 1.66
		helmet.material_override = _make_armour_material(faction_color.darkened(0.22))
		soldier.add_child(helmet)
		_add_faction_insignia(soldier, faction_id, Vector3(0.0, 1.02, -0.215), Vector3(0.18, 0.20, 0.045))

		var soldier_legs: Array[Node3D] = []
		for leg_side in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.085
			leg_mesh.bottom_radius = 0.10
			leg_mesh.height = 0.58
			leg.mesh = leg_mesh
			leg.position = Vector3(leg_side * 0.13, 0.30, 0.0)
			leg.material_override = _make_armour_material(Color(0.16, 0.18, 0.16))
			soldier.add_child(leg)
			soldier_legs.append(leg)
		infantry_leg_pairs[soldier] = soldier_legs

		var pack := MeshInstance3D.new()
		var pack_mesh := BoxMesh.new()
		pack_mesh.size = Vector3(0.34, 0.42, 0.20)
		pack.mesh = pack_mesh
		pack.position = Vector3(0.0, 0.94, 0.30)
		pack.material_override = _make_armour_material(faction_color.darkened(0.30))
		soldier.add_child(pack)

	# A separate aim pivot turns the squad weapon without rotating the whole formation.
	var aim_pivot := Node3D.new()
	aim_pivot.position = Vector3(0.0, 1.15, 0.0)
	squad.add_child(aim_pivot)
	showcase_turrets.append(aim_pivot)

	var rifle := MeshInstance3D.new()
	var rifle_mesh := BoxMesh.new()
	rifle_mesh.size = Vector3(0.12, 0.12, 1.05)
	rifle.mesh = rifle_mesh
	rifle.position = Vector3(0.0, 0.0, -0.48)
	rifle.material_override = _make_armour_material(Color(0.10, 0.12, 0.11))
	aim_pivot.add_child(rifle)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.035
	barrel_mesh.bottom_radius = 0.045
	barrel_mesh.height = 0.42
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 0.015, -1.18)
	barrel.material_override = _make_armour_material(Color(0.08, 0.09, 0.08))
	aim_pivot.add_child(barrel)


func _update_infantry_animation(delta: float) -> void:
	infantry_gait_clock += delta
	var moving_squad: Node3D = selected_tank if has_selected_destination and is_instance_valid(selected_tank) else null
	for soldier_variant in infantry_leg_pairs.keys():
		if not is_instance_valid(soldier_variant):
			infantry_leg_pairs.erase(soldier_variant)
			continue
		var soldier := soldier_variant as Node3D
		if not is_instance_valid(soldier):
			infantry_leg_pairs.erase(soldier_variant)
			continue
		var legs: Array = infantry_leg_pairs[soldier_variant]
		var is_walking := soldier.get_parent() == moving_squad
		var phase := infantry_gait_clock * 9.0 + float(soldier.get_instance_id() % 7)
		for leg_index in range(legs.size()):
			var leg_variant = legs[leg_index]
			if not is_instance_valid(leg_variant):
				continue
			var leg := leg_variant as Node3D
			if is_instance_valid(leg):
				leg.rotation.x = sin(phase + (PI if leg_index == 1 else 0.0)) * (0.52 if is_walking else 0.025)
		if is_walking:
			soldier.position.y = sin(phase * 2.0) * 0.025
		else:
			soldier.position.y = 0.0

func _add_placeholder_tank(at: Vector3, faction_color: Color, faction_id: String) -> void:
	var tank := Node3D.new()
	tank.position = at
	add_child(tank)
	showcase_tanks.append(tank)
	tank.set_meta("health", 100.0)
	tank.set_meta("unit_type", "tank")
	tank.set_meta("faction_id", faction_id)
	_create_showcase_health_bar(tank)

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
	turret_pivot.name = "TurretPivot"
	turret_pivot.position = Vector3(0.0, 1.55, -0.15)
	tank.add_child(turret_pivot)
	_add_faction_insignia(turret_pivot, faction_id, Vector3(0.0, 0.36, 0.15), Vector3(0.48, 0.12, 0.28))
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
	tank_barrels[tank] = barrel

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
	var wheel_nodes: Array[MeshInstance3D] = []
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
			wheel_nodes.append(wheel)
	tank_wheels[tank] = wheel_nodes
	wheel_last_positions[tank] = tank.global_position


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

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "TacticalSelectionHud"
	hud_layer.layer = 8
	add_child(hud_layer)
	selection_count_label = Label.new()
	selection_count_label.name = "SelectionCountLabel"
	selection_count_label.position = Vector2(22.0, 22.0)
	selection_count_label.add_theme_font_size_override("font_size", 22)
	selection_count_label.add_theme_color_override("font_color", Color(0.48, 0.94, 0.58))
	selection_count_label.add_theme_color_override("font_shadow_color", Color(0.01, 0.025, 0.015, 0.96))
	selection_count_label.add_theme_constant_override("shadow_offset_x", 2)
	selection_count_label.add_theme_constant_override("shadow_offset_y", 2)
	var selection_hud_panel := StyleBoxFlat.new()
	selection_hud_panel.bg_color = Color(0.025, 0.075, 0.045, 0.88)
	selection_hud_panel.border_color = Color(0.22, 0.62, 0.34, 0.92)
	selection_hud_panel.set_border_width_all(2)
	selection_hud_panel.set_corner_radius_all(7)
	selection_hud_panel.content_margin_left = 12.0
	selection_hud_panel.content_margin_right = 12.0
	selection_hud_panel.content_margin_top = 6.0
	selection_hud_panel.content_margin_bottom = 6.0
	selection_count_label.add_theme_stylebox_override("normal", selection_hud_panel)
	selection_count_label.visible = false
	hud_layer.add_child(selection_count_label)

	order_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.48
	marker_mesh.bottom_radius = 0.48
	marker_mesh.height = 0.035
	order_marker.mesh = marker_mesh
	order_marker.position.y = 0.04
	order_marker.material_override = _make_armour_material(Color(0.92, 0.76, 0.25))
	add_child(order_marker)
	order_path_instance = MeshInstance3D.new()
	order_path_instance.name = "TacticalMovePath"
	order_path_mesh = ImmediateMesh.new()
	order_path_instance.mesh = order_path_mesh
	order_path_material = StandardMaterial3D.new()
	order_path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	order_path_material.albedo_color = Color(0.38, 0.92, 0.58, 0.92)
	order_path_material.emission_enabled = true
	order_path_material.emission = Color(0.12, 0.72, 0.32)
	order_path_material.emission_energy_multiplier = 1.35
	order_path_instance.material_override = order_path_material
	order_path_instance.visible = false
	add_child(order_path_instance)
	var reticle_material := _make_armour_material(Color(1.0, 0.84, 0.32))
	for reticle_index in range(4):
		var reticle_tick := MeshInstance3D.new()
		reticle_tick.name = "DestinationReticle%d" % reticle_index
		var tick_mesh := BoxMesh.new()
		tick_mesh.size = Vector3(0.34, 0.045, 0.075)
		reticle_tick.mesh = tick_mesh
		reticle_tick.material_override = reticle_material
		match reticle_index:
			0:
				reticle_tick.position = Vector3(0.66, 0.075, 0.0)
				reticle_tick.rotation.y = PI * 0.5
			1:
				reticle_tick.position = Vector3(-0.66, 0.075, 0.0)
				reticle_tick.rotation.y = PI * 0.5
			2:
				reticle_tick.position = Vector3(0.0, 0.075, 0.66)
			3:
				reticle_tick.position = Vector3(0.0, 0.075, -0.66)
		order_marker.add_child(reticle_tick)
	order_marker.visible = false

func _set_live_selection(units_to_select: Array[Node3D]) -> void:
	selected_live_units.clear()
	for unit in units_to_select:
		if _is_live_player_unit(unit) and not selected_live_units.has(unit):
			selected_live_units.append(unit)
	selected_tank = selected_live_units[0] if not selected_live_units.is_empty() else null
	attack_target = null
	has_selected_destination = false
	selection_ring.visible = is_instance_valid(selected_tank)
	_refresh_group_selection_rings()
	_update_selection_count_label()
	order_marker.visible = false


func _update_selection_count_label() -> void:
	if not is_instance_valid(selection_count_label):
		return
	var count := selected_live_units.size()
	selection_count_label.text = "UNITS: %d" % count
	selection_count_label.visible = count > 0


func _refresh_group_selection_rings() -> void:
	for ring in group_selection_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	group_selection_rings.clear()
	if selected_live_units.size() <= 1:
		return
	for index in range(1, selected_live_units.size()):
		var unit := selected_live_units[index]
		if not _is_live_player_unit(unit):
			continue
		var ring := selection_ring.duplicate() as MeshInstance3D
		ring.name = "GroupSelectionRing_%d" % index
		ring.visible = true
		add_child(ring)
		group_selection_rings.append(ring)


func _selection_ring_scale_for_unit(unit: Node3D) -> float:
	var unit_type := str(unit.get_meta("unit_type", "tank"))
	if unit_type == "infantry":
		return 0.62
	if unit_type == "helicopter" or unit_type == "fighter":
		return 1.18
	return 1.0

func _select_live_units_in_screen_rect(start: Vector2, finish: Vector2) -> void:
	var bounds := Rect2(start, finish - start).abs()
	var picked: Array[Node3D] = []
	for unit in showcase_tanks:
		if not _is_live_player_unit(unit) or rts_camera.is_position_behind(unit.global_position):
			continue
		var screen_pos := rts_camera.unproject_position(unit.global_position + Vector3.UP)
		if bounds.has_point(screen_pos):
			picked.append(unit)
	_set_live_selection(picked)

func _handle_world_tap(screen_position: Vector2) -> void:
	var tapped_tank := _tank_at_screen_position(screen_position)
	if tapped_tank == null and not selected_live_units.is_empty():
		var tapped_building := _building_at_screen_position(screen_position)
		if is_instance_valid(tapped_building) and str(tapped_building.get_meta("source_team", "")) == "enemy":
			for friendly in selected_live_units:
				if is_instance_valid(friendly):
					gameplay_order_issued.emit(str(friendly.get_meta("source_unit_key", "")), "attack", Vector3.ZERO, str(tapped_building.get_meta("source_key", "")))
			attack_target = null
			has_selected_destination = false
			order_marker.visible = false
			return
	if tapped_tank != null:
		if _is_live_player_unit(tapped_tank):
			var single_selection: Array[Node3D] = [tapped_tank]
			_set_live_selection(single_selection)
			return
		if not selected_live_units.is_empty() and str(tapped_tank.get_meta("source_team", "")) == "enemy":
			for friendly in selected_live_units:
				if is_instance_valid(friendly):
					gameplay_order_issued.emit(str(friendly.get_meta("source_unit_key", "")), "attack", Vector3.ZERO, str(tapped_tank.get_meta("source_unit_key", "")))
			attack_target = tapped_tank
			has_selected_destination = false
			order_marker.visible = false
			return
		selected_tank = tapped_tank
		selected_live_units.clear()
		_refresh_group_selection_rings()
		_update_selection_count_label()
		attack_target = null
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
	if not selected_live_units.is_empty():
		var valid_units: Array[Node3D] = []
		var formation_center := Vector3.ZERO
		for friendly in selected_live_units:
			if is_instance_valid(friendly):
				valid_units.append(friendly)
				formation_center += friendly.global_position
		if not valid_units.is_empty():
			formation_center /= float(valid_units.size())
			var forward := selected_destination - formation_center
			forward.y = 0.0
			if forward.length_squared() < 0.01:
				forward = Vector3.FORWARD
			else:
				forward = forward.normalized()
			var formation_spacing := _group_formation_spacing(valid_units)
			var formation_offsets: Array[Vector3] = []
			for friendly in valid_units:
				formation_offsets.append(_group_formation_offset_for_unit(friendly, valid_units, forward, formation_spacing))
			var formation_destination := _fit_group_formation_to_arena(selected_destination, formation_offsets)
			for index in range(valid_units.size()):
				var friendly := valid_units[index]
				gameplay_order_issued.emit(str(friendly.get_meta("source_unit_key", "")), "move", formation_destination + formation_offsets[index], "")
	has_selected_destination = true
	order_marker.position = selected_destination + Vector3.UP * 0.04
	order_marker.visible = true



func _fit_group_formation_to_arena(destination: Vector3, offsets: Array[Vector3]) -> Vector3:
	# Shift the whole formation near arena edges instead of clipping individual unit destinations.
	var limit := ARENA_SIZE * 0.42
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var max_z := 0.0
	for offset in offsets:
		min_x = minf(min_x, offset.x)
		max_x = maxf(max_x, offset.x)
		min_z = minf(min_z, offset.z)
		max_z = maxf(max_z, offset.z)
	var fitted := destination
	fitted.x = clampf(fitted.x, -limit - min_x, limit - max_x)
	fitted.z = clampf(fitted.z, -limit - min_z, limit - max_z)
	return fitted


func _group_formation_spacing(units: Array[Node3D]) -> float:
	# Use the largest footprint in a mixed group so long hulls and heavy vehicles
	# do not overlap even when they share a formation with smaller units.
	var spacing := 2.4
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var unit_type := str(unit.get_meta("unit_type", "tank"))
		var unit_spacing := 3.8
		if unit_type == "infantry" or unit_type == "builder" or unit_type == "marine":
			unit_spacing = 2.4
		elif unit_type == "artillery":
			unit_spacing = 4.8
		elif unit_type == "helicopter" or unit_type == "fighter":
			unit_spacing = 5.0
		elif unit_type in ["destroyer", "carrier", "submarine", "landing_craft"]:
			unit_spacing = 10.5
		spacing = maxf(spacing, unit_spacing)
	return spacing



func _group_formation_role(unit: Node3D) -> int:
	var unit_type := str(unit.get_meta("unit_type", "tank")) if is_instance_valid(unit) else "tank"
	if unit_type == "artillery":
		return 0 # Fire-support line stays behind the main force.
	if unit_type in ["infantry", "builder", "marine"]:
		return 1 # Foot soldiers and builders occupy the center line.
	if unit_type in ["helicopter", "fighter"]:
		return 3 # Aircraft take the forward air-support lane.
	return 2 # Armor and other direct-combat units form the front line.


func _group_formation_offset_for_unit(unit: Node3D, units: Array[Node3D], forward: Vector3, spacing: float) -> Vector3:
	var role := _group_formation_role(unit)
	var role_index := 0
	var role_counts: Array[int] = [0, 0, 0, 0]
	for candidate in units:
		if not is_instance_valid(candidate):
			continue
		var candidate_role := _group_formation_role(candidate)
		if candidate == unit:
			role_index = role_counts[candidate_role]
		role_counts[candidate_role] += 1
	role_counts[role] = maxi(1, role_counts[role])
	var preceding_rows := 0
	var total_rows := 0
	for role_index_value in range(role_counts.size()):
		var role_rows := int(ceil(float(role_counts[role_index_value]) / 3.0)) if role_counts[role_index_value] > 0 else 0
		total_rows += role_rows
		if role_index_value < role:
			preceding_rows += role_rows
	var columns := mini(3, role_counts[role])
	var row := int(role_index / columns)
	var column := role_index % columns
	var lane_row := preceding_rows + row
	var direction := Vector3(forward.x, 0.0, forward.z)
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	var lateral := (float(column) - float(columns - 1) * 0.5) * spacing
	var depth := (float(lane_row) - (float(total_rows) - 1.0) * 0.5) * spacing
	return right * lateral + direction * depth


func _group_formation_offset(index: int, unit_count: int, forward: Vector3, spacing: float = 2.6) -> Vector3:
	# Orient the grid toward the movement direction so the formation advances as a coherent line.
	var count := maxi(1, unit_count)
	var safe_index := clampi(index, 0, count - 1)
	var columns := int(ceil(sqrt(float(count))))
	var rows := int(ceil(float(count) / float(columns)))
	var row := int(safe_index / columns)
	var column := safe_index % columns
	var direction := Vector3(forward.x, 0.0, forward.z)
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	var lateral := (float(column) - float(columns - 1) * 0.5) * spacing
	var depth := (float(row) - float(rows - 1) * 0.5) * spacing
	return right * lateral + direction * depth


func _is_live_player_unit(unit: Node3D) -> bool:
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() and str(unit.get_meta("source_team", "")) == "player" and not str(unit.get_meta("source_unit_key", "")).is_empty()

func _building_at_screen_position(screen_position: Vector2) -> Node3D:
	if not is_instance_valid(rts_camera):
		return null
	var nearest: Node3D = null
	var nearest_distance := 82.0
	for building_key in game_building_nodes.keys():
		var building_variant = game_building_nodes[building_key]
		if not is_instance_valid(building_variant):
			continue
		var building := building_variant as Node3D
		if str(building.get_meta("source_team", "")) != "enemy" or float(building.get_meta("health", 1.0)) <= 0.0:
			continue
		if rts_camera.is_position_behind(building.global_position):
			continue
		var screen_pos := rts_camera.unproject_position(building.global_position + Vector3.UP * 1.8)
		var distance := screen_pos.distance_to(screen_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = building
	return nearest


func _tank_at_screen_position(screen_position: Vector2) -> Node3D:
	if not is_instance_valid(rts_camera):
		return null
	var nearest: Node3D
	var nearest_distance := 68.0
	for tank in showcase_tanks:
		if not is_instance_valid(tank) or tank.is_queued_for_deletion() or rts_camera.is_position_behind(tank.global_position):
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

func _unit_separation_vector(unit: Node3D) -> Vector3:
	var push := Vector3.ZERO
	var unit_type := str(unit.get_meta("unit_type", "tank"))
	var is_aircraft := unit_type == "helicopter" or unit_type == "fighter"
	var clearance := 3.4 if unit_type == "tank" else (2.5 if unit_type == "infantry" else 4.2)
	for other in showcase_tanks:
		if not is_instance_valid(other) or other == unit:
			continue
		var other_type := str(other.get_meta("unit_type", "tank"))
		var other_is_aircraft := other_type == "helicopter" or other_type == "fighter"
		if is_aircraft != other_is_aircraft:
			continue
		var offset := unit.global_position - other.global_position
		if not is_aircraft:
			offset.y = 0.0
		var distance := offset.length()
		if distance > 0.05 and distance < clearance:
			push += offset / distance * ((clearance - distance) / clearance)
	return push

func _update_order_path_visual() -> void:
	if not is_instance_valid(order_path_instance) or order_path_mesh == null:
		return
	order_path_mesh.clear_surfaces()
	if not has_selected_destination or not is_instance_valid(selected_tank):
		order_path_instance.visible = false
		return
	var start_point := selected_tank.global_position + Vector3.UP * 0.16
	var end_point := selected_destination + Vector3.UP * 0.16
	var unit_type := str(selected_tank.get_meta("unit_type", "tank"))
	if unit_type == "helicopter":
		start_point.y += 5.2
		end_point.y += 5.2
	elif unit_type == "fighter":
		start_point.y += 6.4
		end_point.y += 6.4
	order_path_mesh.surface_begin(Mesh.PRIMITIVE_LINES, order_path_material)
	order_path_mesh.surface_add_vertex(order_path_instance.to_local(start_point))
	order_path_mesh.surface_add_vertex(order_path_instance.to_local(end_point))
	order_path_mesh.surface_end()
	order_path_instance.visible = true


func _update_showcase_orders(delta: float) -> void:
	selected_live_units = selected_live_units.filter(func(unit): return is_instance_valid(unit) and _is_live_player_unit(unit))
	_update_selection_count_label()
	if not is_instance_valid(selected_tank):
		selected_tank = selected_live_units[0] if not selected_live_units.is_empty() else null
	if not is_instance_valid(selected_tank):
		if is_instance_valid(order_path_instance):
			order_path_instance.visible = false
		selection_ring.visible = false
		for ring in group_selection_rings:
			if is_instance_valid(ring):
				ring.visible = false
		return
	if group_selection_rings.size() != maxi(0, selected_live_units.size() - 1):
		_refresh_group_selection_rings()
	selection_ring.visible = true
	selection_ring.global_position = selected_tank.global_position + Vector3.UP * 0.08
	selection_ring.scale = Vector3.ONE * _selection_ring_scale_for_unit(selected_tank)
	_update_order_path_visual()
	for index in range(group_selection_rings.size()):
		var ring := group_selection_rings[index]
		var unit_index := index + 1
		if not is_instance_valid(ring) or unit_index >= selected_live_units.size():
			continue
		var unit := selected_live_units[unit_index]
		ring.visible = true
		ring.global_position = unit.global_position + Vector3.UP * 0.08
		ring.scale = Vector3.ONE * _selection_ring_scale_for_unit(unit)
	# Live RTS units are moved by the authoritative 2D simulation; never move their 3D proxies locally.
	if _is_live_player_unit(selected_tank) or str(selected_tank.get_meta("source_team", "")) == "enemy":
		return
	if not has_selected_destination:
		return
	var unit_type := str(selected_tank.get_meta("unit_type", "tank"))
	var is_aircraft := unit_type == "helicopter" or unit_type == "fighter"
	var destination := selected_destination
	if is_aircraft:
		destination.y = 5.2 if unit_type == "helicopter" else 6.4
	var direction := destination - selected_tank.global_position
	if not is_aircraft:
		direction.y = 0.0
	if direction.length() < 0.22:
		selected_tank.global_position = destination
		has_selected_destination = false
		order_marker.visible = false
		return
	# Gentle local avoidance keeps formations from stacking while preserving the issued destination.
	var separation := _unit_separation_vector(selected_tank)
	if separation.length_squared() > 0.001:
		direction += separation * minf(1.15, separation.length() * 0.22)
		if not is_aircraft:
			direction.y = 0.0
	var heading := direction.normalized()
	var movement_speed := 7.0 if is_aircraft else 3.2
	selected_tank.global_position += heading * minf(movement_speed * delta, direction.length())
	selected_tank.rotation.y = atan2(-heading.x, -heading.z)


func _create_showcase_health_bar(tank: Node3D) -> void:
	var bar_root := Node3D.new()
	bar_root.name = "HealthBar"
	bar_root.position = Vector3(0.0, 3.15, 0.0)
	tank.add_child(bar_root)

	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(1.45, 0.13, 0.06)
	background.mesh = background_mesh
	background.material_override = _make_armour_material(Color(0.055, 0.065, 0.06))
	bar_root.add_child(background)

	var fill := MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(1.34, 0.085, 0.075)
	fill.mesh = fill_mesh
	fill.position.z = -0.045
	fill.material_override = _make_armour_material(Color(0.22, 0.82, 0.34))
	bar_root.add_child(fill)
	showcase_health_bars[tank] = fill

func _update_showcase_health_bars() -> void:
	for tank_variant in showcase_health_bars.keys():
		if not is_instance_valid(tank_variant):
			showcase_health_bars.erase(tank_variant)
			continue
		var tank := tank_variant as Node3D
		var fill_variant = showcase_health_bars[tank_variant]
		if not is_instance_valid(fill_variant):
			showcase_health_bars.erase(tank_variant)
			continue
		var fill := fill_variant as MeshInstance3D
		if not is_instance_valid(tank) or not is_instance_valid(fill):
			showcase_health_bars.erase(tank_variant)
			continue
		var maximum_health := maxf(1.0, float(tank.get_meta("max_health", 100.0)))
		var ratio := clampf(float(tank.get_meta("health", maximum_health)) / maximum_health, 0.0, 1.0)
		fill.scale.x = maxf(ratio, 0.001)
		fill.position.x = -0.67 * (1.0 - ratio)
		var material := fill.material_override as StandardMaterial3D
		if ratio <= 0.3:
			material.albedo_color = Color(0.9, 0.19, 0.12)
		elif ratio <= 0.6:
			material.albedo_color = Color(0.95, 0.65, 0.16)
		else:
			material.albedo_color = Color(0.22, 0.82, 0.34)

func _spawn_impact_flash(at: Vector3, is_destruction: bool = false) -> void:
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.32 if not is_destruction else 0.65
	flash_mesh.height = flash_mesh.radius * 2.0
	flash.mesh = flash_mesh
	var flash_material := StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.48, 0.12, 0.88)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.24, 0.04)
	flash_material.emission_energy_multiplier = 2.5
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = flash_material
	flash.position = at + Vector3.UP * 0.8
	add_child(flash)
	var tween := create_tween()
	var burst_scale := Vector3.ONE * (2.8 if is_destruction else 1.7)
	tween.tween_property(flash, "scale", burst_scale, 0.22)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.05, 0.16)
	tween.tween_callback(flash.queue_free)
	if is_destruction:
		var smoke := MeshInstance3D.new()
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.38
		smoke_mesh.height = 0.76
		smoke.mesh = smoke_mesh
		var smoke_material := StandardMaterial3D.new()
		smoke_material.albedo_color = Color(0.16, 0.17, 0.15, 0.62)
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.roughness = 1.0
		smoke.material_override = smoke_material
		smoke.position = at + Vector3.UP * 0.85
		add_child(smoke)
		var smoke_tween := create_tween()
		smoke_tween.set_parallel(true)
		smoke_tween.tween_property(smoke, "position", smoke.position + Vector3.UP * 2.0, 0.85)
		smoke_tween.tween_property(smoke, "scale", Vector3.ONE * 2.1, 0.85)
		smoke_tween.tween_property(smoke_material, "albedo_color", Color(0.16, 0.17, 0.15, 0.0), 0.85)
		smoke_tween.chain().tween_callback(smoke.queue_free)

func _update_showcase_combat(delta: float) -> void:
	if not is_instance_valid(selected_tank) or not is_instance_valid(attack_target):
		attack_target = null
		return
	var tank_index := showcase_tanks.find(selected_tank)
	if tank_index < 0 or tank_index >= showcase_turrets.size():
		return
	var pivot := showcase_turrets[tank_index]
	var target_position := attack_target.global_position + Vector3.UP * 1.0
	pivot.look_at(target_position, Vector3.UP)
	attack_cooldown -= delta
	if attack_cooldown > 0.0:
		return
	var unit_type := str(selected_tank.get_meta("unit_type", "tank"))
	attack_cooldown = 0.42 if unit_type == "infantry" else (0.72 if unit_type == "helicopter" or unit_type == "fighter" else 1.25)
	_fire_showcase_projectile(pivot, attack_target)

func _spawn_muzzle_flash(at: Vector3, scale_factor: float = 1.0) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16 * scale_factor
	mesh.height = mesh.radius * 2.0
	flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.72, 0.25, 0.92)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.34, 0.06)
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = material
	add_child(flash)
	flash.global_position = at
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.8, 0.055)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.05, 0.07)
	tween.tween_callback(flash.queue_free)

func _update_tank_wheel_rotation() -> void:
	for tank_variant in tank_wheels.keys():
		if not is_instance_valid(tank_variant):
			tank_wheels.erase(tank_variant)
			wheel_last_positions.erase(tank_variant)
			tank_barrels.erase(tank_variant)
			continue
		var tank := tank_variant as Node3D
		if not is_instance_valid(tank):
			tank_wheels.erase(tank_variant)
			wheel_last_positions.erase(tank_variant)
			tank_barrels.erase(tank_variant)
			continue
		var previous: Vector3 = wheel_last_positions.get(tank_variant, tank.global_position)
		var distance := tank.global_position.distance_to(previous)
		wheel_last_positions[tank_variant] = tank.global_position
		if distance <= 0.0001:
			continue
		var wheels: Array = tank_wheels[tank_variant]
		var rotation_step := distance / 0.34
		for wheel_variant in wheels:
			if not is_instance_valid(wheel_variant):
				continue
			var wheel := wheel_variant as MeshInstance3D
			if is_instance_valid(wheel):
				wheel.rotate_object_local(Vector3.UP, rotation_step)

func _animate_tank_recoil(tank: Node3D) -> void:
	var barrel_variant = tank_barrels.get(tank)
	if not is_instance_valid(barrel_variant):
		return
	var barrel := barrel_variant as MeshInstance3D
	if not is_instance_valid(barrel):
		return
	var tween := create_tween()
	tween.tween_property(barrel, "position:z", -1.72, 0.055)
	tween.tween_property(barrel, "position:z", -2.05, 0.14)

func _fire_showcase_projectile(pivot: Node3D, target: Node3D) -> void:
	var unit_type := str(selected_tank.get_meta("unit_type", "tank"))
	var is_infantry := unit_type == "infantry"
	var is_aircraft := unit_type == "helicopter" or unit_type == "fighter"
	if unit_type == "tank":
		_animate_tank_recoil(selected_tank)
	var projectile := MeshInstance3D.new()
	var projectile_mesh := SphereMesh.new()
	projectile_mesh.radius = 0.055 if is_infantry else (0.09 if is_aircraft else 0.13)
	projectile_mesh.height = 0.12 if is_infantry else (0.18 if is_aircraft else 0.26)
	projectile.mesh = projectile_mesh
	var projectile_material := StandardMaterial3D.new()
	projectile_material.albedo_color = Color(1.0, 0.86, 0.34) if is_infantry or is_aircraft else Color(1.0, 0.58, 0.16)
	projectile_material.emission_enabled = true
	projectile_material.emission = Color(1.0, 0.72, 0.18) if is_infantry or is_aircraft else Color(1.0, 0.32, 0.06)
	projectile_material.emission_energy_multiplier = 2.0
	projectile.material_override = projectile_material
	add_child(projectile)
	projectile.global_position = pivot.global_position + (-pivot.global_transform.basis.z * 2.4) + Vector3.UP * 0.04
	_spawn_muzzle_flash(projectile.global_position, 0.72 if is_infantry else (0.9 if is_aircraft else 1.25))
	_play_combat_audio(projectile.global_position, false)
	var destination := target.global_position + Vector3.UP * 0.95
	var tween := create_tween()
	tween.tween_property(projectile, "global_position", destination, 0.22 if is_infantry else (0.28 if is_aircraft else 0.32))
	var damage := 12.5 if is_infantry else (20.0 if is_aircraft else 25.0)
	tween.tween_callback(_resolve_showcase_hit.bind(projectile, target, damage))

func _resolve_showcase_hit(projectile: Node3D, target: Node3D, damage: float) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not is_instance_valid(target):
		return
	var remaining_health := float(target.get_meta("health", 100.0)) - damage
	target.set_meta("health", remaining_health)
	_spawn_impact_flash(target.global_position, remaining_health <= 0.0)
	_play_combat_audio(target.global_position, true)
	if remaining_health <= 0.0:
		if target == attack_target:
			attack_target = null
		if target == selected_tank:
			selected_tank = null
			selection_ring.visible = false
		showcase_tanks.erase(target)
		showcase_health_bars.erase(target)
		target.queue_free()

func _make_armour_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.28
	material.roughness = 0.72
	return material
