extends Node3D

var collected := AABB()
var found := false

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.22, 0.24, 0.2)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.7, 0.72, 0.65)
	world.environment.ambient_light_energy = 0.8
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.ssao_enabled = true
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, -18)
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	add_child(sun)
	var floor_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 18)
	floor_instance.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.26, 0.23, 0.17)
	floor_instance.material_override = ground
	add_child(floor_instance)
	var entries := [
		["03 fern A", "res://fab_candidates/03/with_tangents.glb", 0],
		["03 fern B", "res://fab_candidates/03/with_tangents.glb", 1],
		["04 fern A", "res://fab_candidates/04/with_tangents.glb", 0],
		["04 fern B", "res://fab_candidates/04/with_tangents.glb", 1],
		["05 balsam A", "res://fab_candidates/05/with_tangents.glb", 0],
		["05 balsam B", "res://fab_candidates/05/with_tangents.glb", 1],
		["06 poppy A", "res://fab_candidates/06/with_tangents.glb", 0],
		["06 poppy B", "res://fab_candidates/06/with_tangents.glb", 1],
		["07 bramble", "res://fab_candidates/07/converted/bramble.glb", -1],
		["07 hazel", "res://fab_candidates/07/converted/hazel.glb", -1],
		["08 tree A", "res://fab_candidates/08/tree_1.gltf", -1],
		["08 tree B", "res://fab_candidates/08/tree_2.gltf", -1],
	]
	for i in range(entries.size()):
		var entry: Array = entries[i]
		var packed := load(entry[1]) as PackedScene
		if packed == null:
			push_error("Missing candidate " + str(entry[1]))
			get_tree().quit(2)
			return
		var holder := Node3D.new()
		holder.position = Vector3((i % 4 - 1.5) * 4.0, 0, (i / 4 - 1) * 4.2)
		add_child(holder)
		var item := packed.instantiate() as Node3D
		holder.add_child(item)
		if entry[2] >= 0:
			var meshes := item.get_children().filter(func(n): return n is MeshInstance3D)
			if meshes.size() <= entry[2]:
				push_error("Missing variant " + str(entry[0]))
				get_tree().quit(2)
				return
			for j in range(meshes.size()):
				if j != entry[2]:
					item.remove_child(meshes[j])
					meshes[j].free()
		if i == 8 or i == 9:
			_apply_alpha_mask(item)
		found = false
		_collect(item, item)
		if not found or collected.size.y < 0.0001:
			push_error("Invalid bounds " + str(entry[0]))
			get_tree().quit(2)
			return
		item.position = -Vector3(collected.get_center().x, collected.position.y, collected.get_center().z)
		holder.scale = Vector3.ONE * (3.0 if i >= 10 else 1.5) / collected.size.y
		var label := Label3D.new()
		label.text = entry[0]
		label.font_size = 24
		label.pixel_size = 0.01
		label.position = Vector3((i % 4 - 1.5) * 4.0, 3.4, (i / 4 - 1) * 4.2)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	var top := "--batch-top" in OS.get_cmdline_user_args()
	camera.position = Vector3(1, 23, 7) if top else Vector3(4, 11, 18)
	camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	camera.current = true
	_capture.call_deferred("fab_03_08_top.png" if top else "fab_03_08_side.png")

func _collect(node: Node, source: Node3D) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var local_transform: Transform3D = source.global_transform.affine_inverse() * node.global_transform
		var aabb: AABB = local_transform * node.get_aabb()
		if found:
			collected = collected.merge(aabb)
		else:
			collected = aabb
			found = true
	for child in node.get_children():
		_collect(child, source)

func _apply_alpha_mask(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in range(node.mesh.get_surface_count()):
			var material: Material = node.mesh.surface_get_material(i)
			if material is BaseMaterial3D:
				var copy := material.duplicate() as BaseMaterial3D
				copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				copy.alpha_scissor_threshold = 0.5
				copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				node.set_surface_override_material(i, copy)
	for child in node.get_children():
		_apply_alpha_mask(child)

func _capture(name: String) -> void:
	await get_tree().create_timer(6.0).timeout
	RenderingServer.force_draw()
	await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png("res://" + name)
	print("FAB_BATCH_CAPTURE=", error, " FPS=", Engine.get_frames_per_second(), " DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit(0 if error == OK else 1)
