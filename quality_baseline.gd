extends "res://scene.gd"

func _ready() -> void:
	super._ready()
	var args := OS.get_cmdline_user_args()
	if "--meshy-side" in args:
		orbit_yaw = 0.65
		orbit_pitch = deg_to_rad(32.0)
		_update_camera()
		_capture.call_deferred("meshy_plan_b/trial_side.png")
	elif "--meshy-top" in args:
		_capture.call_deferred("meshy_plan_b/trial_top.png")
	elif "--meshy-benchmark" in args:
		_benchmark.call_deferred()

func _benchmark() -> void:
	await get_tree().create_timer(3.0).timeout
	var frames: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(360):
		orbit_yaw += TAU / 360.0
		orbit_pitch = deg_to_rad(35.0 + 30.0 * sin(TAU * i / 360.0))
		_update_camera()
		await get_tree().process_frame
		var current := Time.get_ticks_usec()
		frames.append((current - last) / 1000.0)
		last = current
	frames.sort()
	var report := {"samples": frames.size(), "frame_ms_p50": frames[frames.size() / 2], "frame_ms_p95": frames[int(frames.size() * 0.95)], "draw_calls_last": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives_last": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "adapter": RenderingServer.get_video_adapter_name(), "viewport": str(get_viewport().get_visible_rect().size), "notes": "360-frame orbit with pitch changing 5 to 65 degrees; first 3 seconds excluded"}
	var file := FileAccess.open("res://meshy_plan_b/orbit_benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("ORBIT_BENCHMARK ", JSON.stringify(report))
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		camera_target = Vector3(0, 0, 0.8)
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		var movement := Vector3.ZERO
		match event.keycode:
			KEY_W, KEY_UP: movement.z = -0.6
			KEY_S, KEY_DOWN: movement.z = 0.6
			KEY_A, KEY_LEFT: movement.x = -0.6
			KEY_D, KEY_RIGHT: movement.x = 0.6
		if movement != Vector3.ZERO:
			camera_target += movement.rotated(Vector3.UP, orbit_yaw)
			_update_camera()

func _add_camera_help() -> void:
	if "--meshy-top" in OS.get_cmdline_user_args() or "--meshy-side" in OS.get_cmdline_user_args():
		return
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "Right drag: orbit  |  WASD / arrows: pan  |  Wheel: zoom  |  R: reset"
	label.position = Vector2(14, 12)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	add_child(layer)

func _make_materials() -> void:
	super._make_materials()
	mats.edge.albedo_color = Color(0.50, 0.50, 0.46)
	mats.water.albedo_color = Color(0.43, 0.49, 0.49)

func _setup_world() -> void:
	super._setup_world()
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_color = Color(0.74, 0.76, 0.69)
			child.environment.ambient_light_energy = 0.65
		elif child is DirectionalLight3D:
			child.light_energy = 1.2

func _make_vegetation() -> void:
	super._make_vegetation()
	var mesh := SphereMesh.new()
	mesh.radius = 0.038
	mesh.height = 0.076
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := _mat(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var stems: Array[Transform3D] = []
	for i in range(2000):
		var x := rng.randf_range(-11, 11)
		var z := rng.randf_range(-7, 7)
		var d := _near_path(x, z)
		if d < 1.12 or d > 1.85 or rng.randf() < 0.45:
			continue
		var s := rng.randf_range(0.65, 1.2)
		var h := rng.randf_range(0.19, 0.44)
		transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(x, h, z)))
		stems.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, h, 1)), Vector3(x, h * 0.5, z)))
		var palette := [Color(0.98, 0.95, 0.83), Color(0.96, 0.77, 0.22), Color(0.82, 0.50, 0.60)]
		colors.append(palette[rng.randi_range(0, 2)])
	_scatter(mesh, material, transforms, colors)
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.006
	stem_mesh.bottom_radius = 0.009
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 5
	_scatter(stem_mesh, _mat(Color(0.25, 0.33, 0.12)), stems)

func _make_imported_trees() -> void:
	var positions := [Vector3(-15.0, 0, -8), Vector3(-15.2, 0, 1), Vector3(15.0, 0, -7.8), Vector3(15.1, 0, 1.5), Vector3(14.7, 0, 9), Vector3(-8.5, 0, -9.5), Vector3(1, 0, -9.8), Vector3(9.5, 0, -9.5)]
	for i in range(positions.size()):
		var path := "res://meshy_assets/pilot_tree.glb" if i < 2 else "res://meshy_assets/tree_lod1.glb"
		if i % 3 == 1 and ResourceLoader.exists("res://meshy_assets/broadleaf_tree.glb"):
			path = "res://meshy_assets/broadleaf_tree.glb"
		_place_pilot(path, positions[i], 4.6, true)

func _column(x: float, z: float, height: float, tilted := false) -> void:
	var holder := _place_pilot("res://meshy_assets/column.glb", Vector3(x, 0, z), height + 0.4, true)
	if holder:
		holder.rotation = Vector3(0.18 if tilted else 0.0, rng.randf_range(-0.12, 0.12), -0.13 if tilted else 0.0)

func _make_ruins() -> void:
	super._make_ruins()
	if ResourceLoader.exists("res://meshy_assets/rubble.glb"):
		_place_pilot("res://meshy_assets/rubble.glb", Vector3(9.8, 0.05, 6.4), 1.3, false)
	if ResourceLoader.exists("res://meshy_assets/pot.glb"):
		for node in get_children():
			if node is MeshInstance3D and node.material_override in [mats.terra, mats.dark]:
				if absf(node.position.x + 10.8) < 0.1 or absf(node.position.x - 10.5) < 0.1:
					node.visible = false
		for pos in [Vector3(-10.8, 0.0, 2.4), Vector3(10.5, 0.0, 1.9)]:
			_place_pilot("res://meshy_assets/pot.glb", pos, 0.58, true)

func _make_3d_shrubs() -> void:
	for i in range(26):
		var x := rng.randf_range(-10.0, 10.0)
		var z: float = [-5.8, -1.7, 1.7, 5.6][i % 4] + rng.randf_range(-0.28, 0.28)
		var shrub_path := "res://meshy_assets/pilot_shrub.glb" if i < 3 else "res://meshy_assets/shrub_lod1.glb"
		_place_pilot(shrub_path, Vector3(x, 0.05, z), rng.randf_range(0.9, 1.4), false)
	if ResourceLoader.exists("res://meshy_assets/fern_lod1.glb"):
		for i in range(24):
			var x := rng.randf_range(-10.0, 10.0)
			var z: float = [-5.8, -1.7, 1.7, 5.6][i % 4] + rng.randf_range(-0.35, 0.35)
			_place_pilot("res://meshy_assets/fern_lod1.glb", Vector3(x, 0.05, z), rng.randf_range(0.7, 1.1), false)
	if ResourceLoader.exists("res://meshy_assets/flowers_lod1.glb"):
		for i in range(14):
			var x := rng.randf_range(-10.0, 10.0)
			var z: float = [-5.8, -1.7, 1.7, 5.6][i % 4] + rng.randf_range(-0.3, 0.3)
			_place_pilot("res://meshy_assets/flowers_lod1.glb", Vector3(x, 0.05, z), rng.randf_range(0.9, 1.4), false)
	for spec in [["shrub_lod2", 75], ["fern_lod2", 65], ["flowers_lod2", 100], ["grass_lod2", 70]]:
		_scatter_pilot("res://meshy_assets/" + spec[0] + ".glb", spec[1])

func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found:
			return found
	return null

func _scatter_pilot(path: String, count: int) -> void:
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	var source := packed.instantiate() as Node3D
	add_child(source)
	var part := _first_mesh(source)
	if not part:
		source.queue_free()
		return
	candidate_bounds_set = false
	_collect_candidate_bounds(source, source)
	var bounds := candidate_bounds
	var part_transform := source.global_transform.affine_inverse() * part.global_transform
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var span := maxf(bounds.size.x, bounds.size.z)
	if span < 0.001:
		source.queue_free()
		return
	var transforms: Array[Transform3D] = []
	for i in range(count * 6):
		var x := rng.randf_range(-10.8, 10.8)
		var z := rng.randf_range(-8.8, 8.8)
		var d := _near_path(x, z)
		if d < 1.12 or (d > 1.9 and absf(z) < 6.4):
			continue
		var s := rng.randf_range(0.75, 1.35) / span
		var rotation := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * s)
		transforms.append(Transform3D(rotation * part_transform.basis, Vector3(x, 0.02, z) + rotation * (part_transform.origin - center)))
		if transforms.size() >= count:
			break
	var material := part.get_active_material(0) as BaseMaterial3D
	var copy: BaseMaterial3D = material.duplicate() if material else null
	if copy:
		copy.albedo_color *= Color(0.75, 0.84, 0.70)
	_scatter(part.mesh, copy, transforms)
	source.queue_free()

func _make_path() -> void:
	super._make_path()
	var index := 0
	for node in get_children():
		if not node is MeshInstance3D or not node.material_override in [mats.slab0, mats.slab1, mats.slab2, mats.slab3, mats.slab4, mats.slab5, mats.slab6, mats.slab7]:
			continue
		if index in [10, 25, 45] or (index % 3 != 1 and ResourceLoader.exists("res://meshy_assets/stone_plain.glb")):
			var tile_path := "res://meshy_assets/pilot_slab_v2.glb" if index % 4 == 0 else "res://meshy_assets/stone_plain.glb"
			if not ResourceLoader.exists(tile_path):
				tile_path = "res://meshy_assets/pilot_slab_v2.glb"
			var holder := _place_pilot(tile_path, Vector3(node.position.x, 0.01, node.position.z), 0.85, false)
			if holder:
				holder.rotation.y = node.rotation.y + (PI if index % 3 == 1 else 0.0)
				_vary_tint(holder, rng.randf_range(0.82, 1.12))
				var tile_bounds: AABB = node.mesh.get_aabb()
				holder.scale.x *= tile_bounds.size.x / 0.9
				holder.scale.z *= tile_bounds.size.z / 1.1
				node.visible = false
		index += 1

func _place_pilot(path: String, where: Vector3, size: float, height_based: bool) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Missing trial asset " + path)
		return null
	var holder := Node3D.new()
	holder.position = where
	add_child(holder)
	var model := packed.instantiate() as Node3D
	holder.add_child(model)
	var stone_or_pot := path.contains("slab") or path.contains("stone_plain") or path.contains("column") or path.contains("rubble") or path.contains("pot")
	_tint_materials(model, Color(0.78, 0.80, 0.75) if stone_or_pot else Color(0.75, 0.84, 0.70))
	candidate_bounds_set = false
	_collect_candidate_bounds(model, model)
	if not candidate_bounds_set:
		push_error("No geometry " + path)
		return null
	model.position = -Vector3(candidate_bounds.get_center().x, candidate_bounds.position.y, candidate_bounds.get_center().z)
	var span := candidate_bounds.size.y if height_based else maxf(candidate_bounds.size.x, candidate_bounds.size.z)
	if span > 0.001:
		holder.scale = Vector3.ONE * size / span
	if (path.contains("slab") or path.contains("stone_plain")) and candidate_bounds.size.y > 0.001:
		holder.scale = Vector3(0.9 / candidate_bounds.size.x, 0.14 / candidate_bounds.size.y, 1.1 / candidate_bounds.size.z)
	if not path.contains("slab") and not path.contains("stone_plain"):
		holder.rotation.y = rng.randf_range(0, TAU)
	return holder

func _tint_materials(node: Node, tint: Color) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var source := node.get_active_material(surface) as BaseMaterial3D
			if source:
				var copy := source.duplicate() as BaseMaterial3D
				copy.albedo_color *= tint
				node.set_surface_override_material(surface, copy)
	for child in node.get_children():
		_tint_materials(child, tint)

func _vary_tint(node: Node, amount: float) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var material := node.get_surface_override_material(surface) as BaseMaterial3D
			if material:
				material.albedo_color *= Color(amount, amount, amount)
	for child in node.get_children():
		_vary_tint(child, amount)
