extends Node3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.20, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.73, 0.65)
	env.environment.ambient_light_energy = 0.8
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, -18)
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(8, 5)
	ground.mesh = ground_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.25, 0.18)
	ground.material_override = mat
	add_child(ground)
	var paths := ["res://fab_candidates/01/with_tangents.glb", "res://fab_candidates/02/with_tangents.glb"]
	for row in range(paths.size()):
		var packed := load(paths[row]) as PackedScene
		if packed == null:
			push_error("Candidate failed to load: " + paths[row])
			get_tree().quit(2)
			return
		var source := packed.instantiate()
		add_child(source)
		var index := 0
		for child in source.get_children():
			if not child is MeshInstance3D:
				continue
			child.position = Vector3((index - 3.5) * 0.60, 0.02, (row - 0.5) * 1.6)
			index += 1
		print("FAB_VARIANTS row=", row + 1, " count=", index)
		if index != 8:
			push_error("Unexpected variant count")
			get_tree().quit(2)
			return
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.5
	var is_top := "--fab-top" in OS.get_cmdline_user_args()
	camera.position = Vector3(1, 16, 6) if is_top else Vector3(1, 5, 12)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	camera.current = true
	_capture.call_deferred("fab_round1_top.png" if is_top else "fab_round1_side.png")

func _capture(name: String) -> void:
	await get_tree().create_timer(5.0).timeout
	RenderingServer.force_draw()
	await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png("res://" + name)
	print("FAB_CAPTURE=", error, " FPS=", Engine.get_frames_per_second(), " DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit(0 if error == OK else 1)
