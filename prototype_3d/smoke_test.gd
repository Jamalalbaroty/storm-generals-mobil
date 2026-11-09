extends SceneTree

func _initialize() -> void:
	var packed := load("res://prototype_3d/battlefield_3d.tscn") as PackedScene
	if packed == null:
		push_error("Could not load the 3D battlefield scene")
		quit(1)
		return

	var battlefield := packed.instantiate()
	root.add_child(battlefield)
	await process_frame

	if not battlefield is Node3D:
		push_error("The 3D battlefield root is not Node3D")
		quit(1)
		return

	print("3D battlefield smoke test passed")
	battlefield.queue_free()
	await process_frame
	quit(0)
