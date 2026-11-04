extends Node3D

var bounds := AABB()
var has_bounds := false

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.23, 0.25, 0.2)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.7, 0.72, 0.67)
	world.environment.ambient_light_energy = 0.75
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.ssao_enabled = true
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, -18)
	sun.light_color = Color(1, 0.9, 0.76)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(25, 25)
	floor_mesh.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.25, 0.23, 0.17)
	floor_mesh.material_override = ground
	add_child(floor_mesh)
	var paths := ["res://tree_small_02/tree_components.gltf", "res://candidates/pine-tree-1/scene_prepared.gltf", "res://candidates/birch-tree-1/scene_prepared.gltf", "res://candidates/flower-1/scene_prepared.gltf"]
	var names := ["Poly Haven tree (~1.09M)", "Pine 5627 triangles", "Birch 29010 triangles", "Flowers 2740 triangles"]
	for i in range(paths.size()):
		var holder := Node3D.new()
		holder.position = Vector3(-7.5 + i * 5.0, 0, 0)
		add_child(holder)
		var packed := load(paths[i]) as PackedScene
		if packed == null:
			push_error("Candidate failed to load: " + paths[i])
			get_tree().quit(2)
			return
		var asset := packed.instantiate() as Node3D
		holder.add_child(asset)
		has_bounds = false
		_collect(asset, asset)
		if not has_bounds or bounds.size.y <= 0.001:
			push_error("No mesh bounds for " + paths[i])
			continue
		var size := 2.1 if i == 3 else 4.8
		asset.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		holder.scale = Vector3.ONE * (size / bounds.size.y)
		var label := Label3D.new()
		label.text = names[i]
		label.font_size = 32
		label.pixel_size = 0.008
		label.position = Vector3(-7.5 + i * 5.0, 5.2, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	var args := OS.get_cmdline_user_args()
	if "--compare-top" in args:
		camera.position = Vector3(0, 19, 9)
	else:
		camera.position = Vector3(4, 8, 16)
	camera.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	camera.current = true
	if "--compare-top" in args or "--compare-side" in args:
		_capture.call_deferred("vegetation_compare_top.png" if "--compare-top" in args else "vegetation_compare_side.png")

func _collect(node: Node, source: Node3D) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var local_transform: Transform3D = source.global_transform.affine_inverse() * node.global_transform
		var aabb: AABB = local_transform * node.get_aabb()
		if not has_bounds:
			bounds = aabb
			has_bounds = true
		else:
			bounds = bounds.merge(aabb)
	for child in node.get_children():
		_collect(child, source)

func _capture(filename: String) -> void:
	await get_tree().create_timer(8).timeout
	RenderingServer.force_draw()
	await get_tree().process_frame
	var err := get_viewport().get_texture().get_image().save_png("res://" + filename)
	print("COMPARE_CAPTURE=", err, " FPS=", Engine.get_frames_per_second(), " DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit(0 if err == OK else 1)
