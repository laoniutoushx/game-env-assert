extends Node3D

# A deterministic, editable environment study. Geometry is generated from local
# primitives; no image is projected onto the scene.
var rng := RandomNumberGenerator.new()
var path_points: Array[Vector3] = []
var mats := {}
var groups := {}
var review_camera: Camera3D
var camera_target := Vector3(0, 0, 0.8)
var orbit_yaw := 0.0
var orbit_pitch := 0.0
var orbit_distance := 26.9
var orbit_dragging := false
var candidate_bounds := AABB()
var candidate_bounds_set := false

func _ready() -> void:
	rng.seed = 22026
	_make_materials()
	_setup_world()
	_make_path()
	_make_ground()
	_make_ruins()
	_make_vegetation()
	if "--fab-round2" in OS.get_cmdline_user_args() or "--fab-round2-side" in OS.get_cmdline_user_args() or "--fab-preview" in OS.get_cmdline_user_args():
		_make_fab_trial()
	_adjust_composition()
	_add_camera_help()
	var args := OS.get_cmdline_user_args()
	if "--fab-round2-side" in args:
		orbit_yaw = 0.65
		orbit_pitch = deg_to_rad(32.0)
		_update_camera()
		_capture.call_deferred("fab_round2_side.png")
	elif "--fab-round2" in args:
		_capture.call_deferred("fab_round2_top.png")
	elif "--capture-low" in args:
		camera_target = Vector3(12.0, 0.5, 1.0)
		orbit_yaw = 0.60
		orbit_pitch = deg_to_rad(20.0)
		review_camera.size = 9.0
		_update_camera()
		_capture.call_deferred("review_vegetation_low.png")
	elif "--capture-side" in args:
		orbit_yaw = 0.65
		orbit_pitch = deg_to_rad(32.0)
		_update_camera()
		_capture.call_deferred("review_side.png")
	elif "--capture" in args:
		_capture.call_deferred()

func _mat(color: Color, rough := 1.0, metallic := 0.0, noise_scale := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	if noise_scale > 0.0:
		var n := FastNoiseLite.new()
		n.seed = 87
		n.frequency = noise_scale
		var tex := NoiseTexture2D.new()
		tex.width = 512
		tex.height = 512
		tex.seamless = true
		tex.noise = n
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(0.45, 0.42, 0.35), Color(0.95, 0.92, 0.8)])
		tex.color_ramp = gradient
		m.albedo_texture = tex
		m.uv1_scale = Vector3(5, 5, 5)
	return m

func _make_materials() -> void:
	mats.dirt = _mat(Color(0.36, 0.32, 0.23), 1.0, 0.0, 0.032)
	mats.stone = _mat(Color(0.67, 0.64, 0.51), 0.92, 0.0, 0.08)
	mats.edge = _mat(Color(0.40, 0.41, 0.34), 1.0, 0.0, 0.055)
	mats.dark = _mat(Color(0.19, 0.21, 0.16))
	mats.water = _mat(Color(0.38, 0.44, 0.46), 0.2, 0.12)
	mats.water.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats.water.emission_enabled = true
	mats.water.emission = Color(0.20, 0.25, 0.27)
	mats.water.emission_energy_multiplier = 0.6
	mats.wood = _mat(Color(0.23, 0.15, 0.095), 0.95)
	mats.terra = _mat(Color(0.38, 0.24, 0.16), 0.9)
	mats.metal = _mat(Color(0.22, 0.23, 0.25), 0.55, 0.45)
	mats.purple = _mat(Color(0.61, 0.17, 0.85), 0.35)
	mats.purple.emission_enabled = true
	mats.purple.emission = Color(0.62, 0.10, 0.95)
	mats.purple.emission_energy_multiplier = 2.0
	mats.fire = _mat(Color(1.0, 0.29, 0.04), 0.5)
	mats.fire.emission_enabled = true
	mats.fire.emission = Color(1.0, 0.12, 0.01)
	mats.fire.emission_energy_multiplier = 2.5
	for i in range(8):
		mats["slab%d" % i] = _mat(Color(0.47 + i * 0.018, 0.46 + i * 0.017, 0.38 + i * 0.014), 0.96, 0.0, 0.075)
	_apply_pbr(mats.dirt, "Ground003", Vector3(28, 28, 1))
	mats.dirt.albedo_texture = load("res://textures/ground_muted.jpg")
	mats.dirt.albedo_color = Color(0.9, 0.88, 0.82)
	_apply_pbr(mats.stone, "Tiles130", Vector3(0.75, 0.75, 1))
	mats.stone.albedo_texture = load("res://textures/slab_1_Color.jpg")
	mats.stone.normal_texture = load("res://textures/slab_1_NormalGL.jpg")
	mats.stone.roughness_texture = load("res://textures/slab_1_Roughness.jpg")
	mats.stone.albedo_color = Color(0.60, 0.59, 0.53)
	for i in range(8):
		var slab_mat: StandardMaterial3D = mats["slab%d" % i]
		slab_mat.albedo_texture = load("res://textures/slab_%d_Color.jpg" % i)
		slab_mat.normal_enabled = true
		slab_mat.normal_texture = load("res://textures/slab_%d_NormalGL.jpg" % i)
		slab_mat.normal_scale = 0.65
		slab_mat.roughness_texture = load("res://textures/slab_%d_Roughness.jpg" % i)
		slab_mat.uv1_scale = Vector3.ONE
		slab_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		slab_mat.vertex_color_use_as_albedo = true
		slab_mat.albedo_color = Color(1.05 + i * 0.012, 1.02 + i * 0.012, 0.94 + i * 0.012)

func _apply_pbr(material: StandardMaterial3D, name: String, uv_scale: Vector3) -> void:
	var prefix := "res://textures/%s_2K-JPG_" % name
	material.albedo_texture = load(prefix + "Color.jpg")
	material.normal_enabled = true
	material.normal_texture = load(prefix + "NormalGL.jpg")
	material.normal_scale = 0.65
	material.roughness_texture = load(prefix + "Roughness.jpg")
	material.uv1_scale = uv_scale

func _setup_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.18, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.67, 0.70, 0.64)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	e.ssao_radius = 1.0
	e.ssao_intensity = 1.5
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, -18)
	sun.light_color = Color(1.0, 0.90, 0.76)
	sun.light_energy = 1.10
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var camera := Camera3D.new()
	review_camera = camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.8
	camera.position = Vector3(0, 23, 14.8)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0.8), Vector3.UP)
	camera.current = true
	var offset := camera.position - camera_target
	orbit_distance = offset.length()
	orbit_yaw = atan2(offset.x, offset.z)
	orbit_pitch = asin(offset.y / orbit_distance)

func _add_camera_help() -> void:
	if "--capture" in OS.get_cmdline_user_args() or "--capture-side" in OS.get_cmdline_user_args() or "--capture-low" in OS.get_cmdline_user_args() or "--fab-round2" in OS.get_cmdline_user_args() or "--fab-round2-side" in OS.get_cmdline_user_args():
		return
	var layer := CanvasLayer.new()
	var label := Label.new()
	get_window().title = "遗迹环境 | LEGACY 旧版 scene.tscn（请用 F5 运行最新版）"
	label.text = "LEGACY scene.tscn - use F5 for the latest project scene\nRight drag: orbit   |   Wheel: zoom   |   R: reset"
	label.position = Vector2(14, 12)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	add_child(layer)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbit_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			review_camera.size = maxf(5.0, review_camera.size * 0.90)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			review_camera.size = minf(35.0, review_camera.size * 1.10)
	elif event is InputEventMouseMotion and orbit_dragging:
		orbit_yaw -= event.relative.x * 0.006
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, deg_to_rad(15.0), deg_to_rad(85.0))
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		review_camera.position = Vector3(0, 23, 14.8)
		review_camera.size = 15.8
		var offset := review_camera.position - camera_target
		orbit_distance = offset.length()
		orbit_yaw = atan2(offset.x, offset.z)
		orbit_pitch = asin(offset.y / orbit_distance)
		_update_camera()

func _update_camera() -> void:
	var horizontal := orbit_distance * cos(orbit_pitch)
	review_camera.position = camera_target + Vector3(sin(orbit_yaw) * horizontal, sin(orbit_pitch) * orbit_distance, cos(orbit_yaw) * horizontal)
	review_camera.look_at(camera_target, Vector3.UP)

func _adjust_composition() -> void:
	# Keep the camera unscaled while fitting the environment to the reference frame.
	var geometry := Node3D.new()
	geometry.name = "EnvironmentGeometry"
	add_child(geometry)
	for child in get_children():
		if child == geometry or child is Camera3D or child is DirectionalLight3D or child is WorldEnvironment:
			continue
		child.reparent(geometry, false)
	geometry.scale = Vector3(0.85, 1.0, 1.2)

func _box(pos: Vector3, size: Vector3, material: Material, angle := 0.0, parent: Node = self) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = material
	inst.position = pos
	inst.rotation.y = angle
	parent.add_child(inst)
	return inst

func _cylinder(pos: Vector3, radius: float, height: float, material: Material, parent: Node = self) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	inst.mesh = mesh
	inst.material_override = material
	inst.position = pos
	parent.add_child(inst)
	return inst

func _stone_mesh(width: float, depth: float) -> ArrayMesh:
	# Chamfered, uneven outline with separately normalled sides.
	var x := width * 0.5
	var z := depth * 0.5
	var c := rng.randf_range(0.045, 0.13)
	var points: Array[Vector2] = [Vector2(-x + c, -z), Vector2(x - c, -z), Vector2(x, -z + c), Vector2(x, z - c), Vector2(x - c, z), Vector2(-x + c, z), Vector2(-x, z - c), Vector2(-x, -z + c)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		for v in [Vector2.ZERO, q, p]:
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(v.x / width + 0.5, v.y / depth + 0.5))
			st.add_vertex(Vector3(v.x, 0.075, v.y))
		var normal := Vector3(q.y - p.y, 0, p.x - q.x).normalized()
		for v in [Vector3(p.x, -0.06, p.y), Vector3(q.x, -0.06, q.y), Vector3(q.x, 0.075, q.y), Vector3(p.x, -0.06, p.y), Vector3(q.x, 0.075, q.y), Vector3(p.x, 0.075, p.y)]:
			st.set_normal(normal)
			st.set_color(Color(0.48, 0.46, 0.40))
			st.set_uv(Vector2(v.x / width + 0.5, v.z / depth + 0.5))
			st.add_vertex(v)
	return st.commit()

func _puddle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for i in range(13):
		var a := TAU * i / 13.0
		var r := rng.randf_range(0.75, 1.0)
		rim.append(Vector3(cos(a) * 0.30 * r, 0, sin(a) * 0.37 * r))
	for i in range(rim.size()):
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(rim[(i + 1) % rim.size()])
		st.add_vertex(rim[i])
	return st.commit()

func _make_path() -> void:
	# Connected switchbacks, laid as individual worn slabs with edge stones.
	for i in range(37):
		path_points.append(Vector3(8.8 - i * 0.48, 0, -3.4))
	for i in range(1, 15):
		var a := -PI / 2.0 - PI * i / 14.0
		path_points.append(Vector3(-8.48 + 1.7 * cos(a), 0, -1.7 + 1.7 * sin(a)))
	for i in range(1, 36):
		path_points.append(Vector3(-8.48 + i * 0.48, 0, 0))
	for i in range(1, 15):
		var a := -PI / 2.0 + PI * i / 14.0
		path_points.append(Vector3(8.32 + 1.7 * cos(a), 0, 1.7 + 1.7 * sin(a)))
	for i in range(1, 37):
		path_points.append(Vector3(8.32 - i * 0.48, 0, 3.4))
	var skip_until := -1
	for i in range(path_points.size() - 1):
		if i % 2 != 0:
			continue
		if i < skip_until:
			continue
		var p := path_points[i]
		var direction := (path_points[i + 1] - p).normalized()
		var angle := atan2(-direction.z, direction.x)
		var side := Vector3(-direction.z, 0, direction.x)
		var on_curve := (i >= 37 and i < 51) or (i >= 86 and i < 100)
		var merge_pair := i % 8 == 0 and ((i >= 2 and i <= 32) or (i >= 52 and i <= 80) or (i >= 102 and i <= 130))
		if merge_pair:
			p += direction * 0.48
			skip_until = i + 4
		var slab_width := (1.87 if merge_pair else (0.81 if on_curve else 0.92)) * rng.randf_range(0.95, 0.99)
		# A continuous dark foundation keeps soil from showing through curve joints.
		_box(p + Vector3(0, 0.025, 0), Vector3((1.93 if merge_pair else (0.90 if on_curve else 0.97)), 0.045, 1.30), mats.edge, angle)
		var slab := MeshInstance3D.new()
		slab.mesh = _stone_mesh(slab_width, 1.12 * rng.randf_range(0.92, 1.0))
		slab.material_override = mats["slab%d" % rng.randi_range(0, 7)]
		slab.position = p + Vector3(0, 0.075 + rng.randf_range(-0.008, 0.008), 0)
		slab.rotation.y = angle + rng.randf_range(-0.025, 0.025)
		add_child(slab)
		for s in [-1, 1]:
			_box(p + side * s * 0.62 + Vector3(0, 0.05, 0), Vector3((1.85 if merge_pair else (0.80 if on_curve else 0.91)), 0.13, 0.16), mats.edge, angle)
		if rng.randf() < 0.32:
			var crack := _box(p + side * rng.randf_range(-0.2, 0.2) + Vector3(0, 0.147, 0), Vector3(0.012, 0.004, rng.randf_range(0.2, 0.55)), mats.edge, angle + rng.randf_range(-0.5, 0.5))
			crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i in [12, 72, 118, 130]:
			var puddle := MeshInstance3D.new()
			puddle.mesh = _puddle_mesh()
			puddle.material_override = mats.water
			puddle.position = p + Vector3(0, 0.154, 0)
			add_child(puddle)
		elif not on_curve and i % 6 == 0:
			# Shallow, irregular marks suggest weathered inscriptions at game distance.
			for stroke in range(4):
				var along := (stroke - 1.5) * 0.11
				var mark := _box(p + direction * along + side * rng.randf_range(-0.18, 0.18) + Vector3(0, 0.153, 0), Vector3(0.012, 0.003, rng.randf_range(0.09, 0.22)), mats.edge, angle + rng.randf_range(-0.45, 0.45))
				mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for item in [[-5.7, 3.4, "MEMORIA"], [-1.9, 3.4, "TEMPVS"], [2.5, 3.4, "VIA · VETVS"], [-3.1, 0.0, "SAXVM"], [3.8, -3.4, "ORIGO"]]:
		var inscription := Label3D.new()
		inscription.text = item[2]
		inscription.font_size = 32
		inscription.pixel_size = 0.0024
		inscription.modulate = Color(0.30, 0.28, 0.22, 0.76)
		inscription.outline_size = 0
		inscription.position = Vector3(float(item[0]), 0.157, float(item[1]))
		inscription.rotation.x = -PI / 2.0
		add_child(inscription)
	for x in [-4.4, 1.5]:
		var puddle := MeshInstance3D.new()
		puddle.mesh = _puddle_mesh()
		puddle.material_override = mats.water
		puddle.position = Vector3(float(x), 0.158, 3.4)
		add_child(puddle)

func _make_ground() -> void:
	_box(Vector3(0, -0.18, 0), Vector3(120, 0.3, 120), mats.dirt)

func _near_path(x: float, z: float) -> float:
	var best := 100.0
	for p in path_points:
		best = minf(best, Vector2(x - p.x, z - p.z).length())
	return best

func _column(x: float, z: float, height: float, tilted := false) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	if tilted:
		root.rotation.z = 0.4
	add_child(root)
	_box(Vector3(0, 0.13, 0), Vector3(0.9, 0.26, 0.9), mats.edge, 0, root)
	_box(Vector3(0, 0.31, 0), Vector3(0.72, 0.12, 0.72), mats.stone, 0, root)
	_cylinder(Vector3(0, height / 2.0 + 0.35, 0), 0.29, height, mats.stone, root)
	_box(Vector3(0, height + 0.40, 0), Vector3(0.75, 0.20, 0.75), mats.stone, 0, root)
	for i in range(12):
		var a := TAU * i / 12.0
		_cylinder(Vector3(cos(a) * 0.28, height / 2.0 + 0.35, sin(a) * 0.28), 0.035, height * 0.97, mats.edge, root)

func _make_ruins() -> void:
	_column(-12.0, -1.0, 2.9, true)
	_column(-11.3, 1.8, 2.1, true)
	_column(11.8, 0.3, 2.5, true)
	_column(11.5, 3.2, 1.45, true)
	_column(-7.0, -7.4, 2.4)
	_column(8.0, -7.3, 1.8, true)
	for pos in [Vector3(-10.8, 0, 2.4), Vector3(10.5, 0, 1.9)]:
		_cylinder(pos + Vector3(0, 0.25, 0), 0.29, 0.5, mats.terra)
		_cylinder(pos + Vector3(0, 0.51, 0), 0.21, 0.025, mats.dark)
	var fallen := _cylinder(Vector3(10.5, 0.32, 6.1), 0.3, 1.3, mats.stone)
	fallen.rotation.z = PI / 2.0
	fallen.rotation.y = 0.32
	for end in [-1.0, 1.0]:
		_box(Vector3(10.5 + end * 0.65, 0.31, 6.1), Vector3(0.18, 0.65, 0.65), mats.stone, 0.32)
	for i in range(22):
		var x := rng.randf_range(-13, 13)
		var z := rng.randf_range(-7.5, 7.5)
		if _near_path(x, z) > 1.1:
			_box(Vector3(x, 0.08, z), Vector3(rng.randf_range(0.15, 0.48), 0.16, rng.randf_range(0.15, 0.4)), mats.edge, rng.randf_range(0, TAU))
	# The purple structure is part of the environment, without gameplay components.
	var base := Vector3(9.2, 0, -4.6)
	_box(base + Vector3(0, 0.25, 0), Vector3(2.2, 0.5, 1.55), mats.edge)
	_box(base + Vector3(0, 0.56, 0), Vector3(1.9, 0.18, 1.3), mats.metal)
	for x in [-0.65, 0.65]:
		var post := _box(base + Vector3(x, 1.4, 0), Vector3(0.25, 1.9, 0.4), mats.metal)
		post.rotation.z = -0.20
		var strip := _box(base + Vector3(x - 0.05, 1.4, 0.23), Vector3(0.08, 1.65, 0.035), mats.purple)
		strip.rotation.z = -0.20
	_box(base + Vector3(0, 0.85, 0), Vector3(1.4, 0.2, 0.45), mats.metal)
	for side in [-1, 1]:
		_box(base + Vector3(side * 1.02, 0.73, 0.42), Vector3(0.35, 0.4, 0.45), mats.stone)
		_cylinder(base + Vector3(side * 0.85, 0.8, -0.42), 0.13, 1.1, mats.metal).rotation.z = side * 0.55
	_box(base + Vector3(0, 0.66, 0.68), Vector3(1.45, 0.09, 0.12), mats.purple)
	# Fragmentary colonnade at the left edge of the composition.
	_box(Vector3(-12.1, 0.20, -3.5), Vector3(2.6, 0.35, 2.0), mats.edge)
	for x in [-13.0, -11.3]:
		_cylinder(Vector3(x, 1.0, -3.7), 0.20, 1.6, mats.stone)
	_box(Vector3(-12.15, 1.85, -3.7), Vector3(2.25, 0.28, 0.5), mats.stone, -0.10)
	# Irregular broken masonry and steps surrounding the colonnade.
	for j in range(3):
		_box(Vector3(-12.0, 0.10 + j * 0.10, -2.55 - j * 0.25), Vector3(2.6 - j * 0.18, 0.16, 0.48), mats.edge)
	for j in range(9):
		var x := -13.0 + rng.randf_range(-0.35, 0.35)
		var z := -4.1 + j * 0.25
		_box(Vector3(x, 0.25 + (j % 3) * 0.23, z), Vector3(0.5, 0.24, 0.32), mats.stone, rng.randf_range(-0.12, 0.12))
	for x in [-1.8, 0.8]:
		_cylinder(Vector3(x, 0.18, -1.7), 0.10, 0.32, mats.edge)
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.085
		flame_mesh.height = 0.24
		flame.mesh = flame_mesh
		flame.material_override = mats.fire
		flame.position = Vector3(x, 0.43, -1.7)
		add_child(flame)

func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Intersecting tapered blades: individual blades catch the light.
	for i in range(5):
		var a := TAU * i / 5.0
		var side := Vector3(cos(a), 0, sin(a))
		var tip := side * 0.23 + Vector3(0, 0.65, 0)
		var across := Vector3(-side.z, 0, side.x) * 0.065
		st.set_normal(Vector3.UP)
		st.add_vertex(-across)
		st.add_vertex(across)
		st.add_vertex(tip)
	return st.commit()

func _fern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for branch in range(9):
		var a := TAU * branch / 9.0
		var outward := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		for j in range(1, 7):
			var t := float(j) / 7.0
			var center := outward * (0.7 * t) + Vector3(0, 0.48 * sin(t * PI * 0.7), 0)
			for sign_value in [-1.0, 1.0]:
				var base := center - outward * 0.045
				var tip: Vector3 = center + side * float(sign_value) * 0.18 * (1.0 - t * 0.65) + outward * 0.09
				st.set_normal(Vector3.UP)
				st.add_vertex(base)
				st.add_vertex(tip)
				st.add_vertex(center + outward * 0.08)
	return st.commit()

func _scatter(mesh: Mesh, material: Material, transforms: Array[Transform3D], colors: Array[Color] = []) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	add_child(inst)

func _make_vegetation() -> void:
	_make_imported_trees()
	_make_3d_shrubs()
	var grass_mat := _mat(Color(0.32, 0.39, 0.15))
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mat.vertex_color_use_as_albedo = true
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in range(7000):
		var x := rng.randf_range(-14, 14)
		var z := rng.randf_range(-9, 9)
		var distance := _near_path(x, z)
		if distance < 0.96 or (x > 7.6 and z < -3.55 and z > -5.7):
			continue
		# Open dirt next to the route, dense borders and long central islands.
		var density := 0.055
		if abs(z) > 6.5 or (distance > 1.05 and distance < 1.6):
			density = 0.78
		if rng.randf() > density:
			continue
		var scale := rng.randf_range(0.20, 0.58)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(scale, scale * rng.randf_range(0.7, 1.3), scale))
		transforms.append(Transform3D(basis, Vector3(x, 0, z)))
		var v := rng.randf_range(0.65, 1.15)
		colors.append(Color(v * 0.40, v * 0.53, v * 0.20))
	_scatter(_leaf_mesh(), grass_mat, transforms, colors)
	var fern_scene: PackedScene = load("res://fern_02/fern_02_prepared.gltf")
	var fern_root := fern_scene.instantiate()
	for fern in fern_root.get_children():
		if not fern is MeshInstance3D:
			continue
		var fern_transforms: Array[Transform3D] = []
		for i in range(900):
			var x := rng.randf_range(-13.5, 13.5)
			var z := rng.randf_range(-8.5, 8.5)
			var d := _near_path(x, z)
			if d < 1.26 or (abs(z) < 6.5 and d > 1.8) or (x > 7.3 and z < -3.3 and z > -5.9):
				continue
			var s := rng.randf_range(0.9, 1.55)
			fern_transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s, s)), Vector3(x, 0.02, z)))
		_scatter(fern.mesh, null, fern_transforms)
	fern_root.free()
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.045
	flower_mesh.height = 0.09
	var flower_mat := _mat(Color.WHITE)
	flower_mat.vertex_color_use_as_albedo = true
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var stems: Array[Transform3D] = []
	for i in range(650):
		var x := rng.randf_range(-13, 13)
		var z := rng.randf_range(-8, 8)
		var d := _near_path(x, z)
		if d < 1.0 or (abs(z) < 6.5 and d > 1.7):
			continue
		var h := rng.randf_range(0.18, 0.44)
		flowers.append(Transform3D(Basis.IDENTITY, Vector3(x, h, z)))
		stems.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, h, 1)), Vector3(x, h * 0.5, z)))
		var palette := [Color(0.95, 0.91, 0.75), Color(0.95, 0.72, 0.19), Color(0.76, 0.41, 0.50)]
		flower_colors.append(palette[rng.randi_range(0, 2)])
	_scatter(flower_mesh, flower_mat, flowers, flower_colors)
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.009
	stem_mesh.bottom_radius = 0.012
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 5
	_scatter(stem_mesh, _mat(Color(0.25, 0.33, 0.12)), stems)
	var foliage := _mat(Color(0.19, 0.27, 0.11))
	for i in range(0):
		var x := rng.randf_range(-14, 14)
		var z: float = (-1.0 if rng.randi_range(0, 1) == 0 else 1.0) * rng.randf_range(8.3, 10.0)
		var h := rng.randf_range(1.4, 3.8)
		_cylinder(Vector3(x, h * 0.4, z), 0.11, h * 0.8, mats.wood)
		for j in range(3):
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.0
			mesh.bottom_radius = 0.95 - j * 0.18
			mesh.height = 1.25
			mesh.radial_segments = 9
			var crown := MeshInstance3D.new()
			crown.mesh = mesh
			crown.material_override = foliage
			crown.position = Vector3(x, h * 0.55 + j * 0.45, z)
			add_child(crown)

func _make_imported_trees() -> void:
	var pine: PackedScene = load("res://candidates/pine-tree-1/scene_prepared.gltf")
	var birch: PackedScene = load("res://candidates/birch-tree-1/scene_prepared.gltf")
	var positions := [Vector3(-16.2, 0, -8.0), Vector3(-16.1, 0, 1.0), Vector3(-15.5, 0, 9.0), Vector3(16.2, 0, -7.8), Vector3(16.1, 0, 1.5), Vector3(15.7, 0, 9.0), Vector3(-8.5, 0, -11.2), Vector3(1.0, 0, -11.5), Vector3(9.5, 0, -11.3)]
	for i in range(positions.size()):
		var holder := Node3D.new()
		holder.position = positions[i]
		add_child(holder)
		var tree := (birch if i % 3 == 1 else pine).instantiate() as Node3D
		holder.add_child(tree)
		candidate_bounds_set = false
		_collect_candidate_bounds(tree, tree)
		if not candidate_bounds_set or candidate_bounds.size.y < 0.001:
			push_error("Tree candidate has no valid bounds")
			continue
		tree.position = -Vector3(candidate_bounds.get_center().x, candidate_bounds.position.y, candidate_bounds.get_center().z)
		var height := rng.randf_range(4.0, 5.0)
		holder.scale = Vector3.ONE * height / candidate_bounds.size.y
		holder.rotation.y = rng.randf_range(0, TAU)

func _collect_candidate_bounds(node: Node, source: Node3D) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var local_transform: Transform3D = source.global_transform.affine_inverse() * node.global_transform
		var aabb: AABB = local_transform * node.get_aabb()
		if candidate_bounds_set:
			candidate_bounds = candidate_bounds.merge(aabb)
		else:
			candidate_bounds = aabb
			candidate_bounds_set = true
	for child in node.get_children():
		_collect_candidate_bounds(child, source)

func _make_3d_shrubs() -> void:
	var packed: PackedScene = load("res://shrub_02/shrub_02_prepared.gltf")
	var source := packed.instantiate()
	for shrub in source.get_children():
		if not shrub is MeshInstance3D:
			continue
		var instances: Array[Transform3D] = []
		for i in range(75):
			var x := rng.randf_range(-13.5, 13.5)
			var z := rng.randf_range(-9.5, 9.5)
			var d := _near_path(x, z)
			if d < 1.35 or (abs(z) < 6.3 and d > 1.9) or (x > 7.3 and z < -3.3 and z > -5.9):
				continue
			var s := rng.randf_range(0.35, 0.6)
			var basis: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)) * shrub.transform.basis
			instances.append(Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(x, 0.04, z)))
		_scatter(shrub.mesh, null, instances)
	source.free()

func _make_fab_trial() -> void:
	var packs := [
		["res://fab_candidates/01/with_tangents.glb", 90, 1.2, 2.3, 8],
		["res://fab_candidates/02/with_tangents.glb", 18, 1.2, 2.3, 8],
		["res://fab_candidates/03/with_tangents.glb", 30, 0.45, 0.75, 9],
		["res://fab_candidates/04/with_tangents.glb", 25, 0.45, 0.75, 8],
		["res://fab_candidates/05/with_tangents.glb", 5, 0.35, 0.6, 4],
		["res://fab_candidates/06/with_tangents.glb", 8, 0.8, 1.3, 8],
		["res://fab_candidates/07/converted/bramble.glb", 16, 0.6, 1.0, 1],
		["res://fab_candidates/07/converted/hazel.glb", 16, 0.6, 1.0, 1],
	]
	for pack_index in range(packs.size()):
		var spec: Array = packs[pack_index]
		var packed := load(spec[0]) as PackedScene
		if packed == null:
			push_error("Fab candidate is unavailable: " + str(spec[0]))
			continue
		var source := packed.instantiate()
		var child_count := 0
		for child in source.get_children():
			if not child is MeshInstance3D or "_LOD" in child.name:
				continue
			child_count += 1
			if child_count > int(spec[4]):
				break
			var instances: Array[Transform3D] = []
			for i in range(int(spec[1])):
				var x := rng.randf_range(-10.0, 10.0)
				var z := rng.randf_range(-6.5, 6.5)
				var d := _near_path(x, z)
				if d < 1.0 or d > 1.7 or (x > 7.3 and z < -3.3 and z > -5.9):
					continue
				var size := rng.randf_range(float(spec[2]), float(spec[3]))
				var rotation := Basis(Vector3.UP, rng.randf_range(0, TAU))
				var basis: Basis = (rotation * child.transform.basis).scaled(Vector3.ONE * size)
				instances.append(Transform3D(basis, Vector3(x, 0.03, z)))
			var override_material: Material = null
			if pack_index >= 6:
				var original: Material = child.mesh.surface_get_material(0)
				if original is BaseMaterial3D:
					var alpha_mat := original.duplicate() as BaseMaterial3D
					alpha_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					alpha_mat.alpha_scissor_threshold = 0.5
					alpha_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					override_material = alpha_mat
			_scatter(child.mesh, override_material, instances)
		source.free()
	var tree_scene := load("res://fab_candidates/08/tree_1.gltf") as PackedScene
	if tree_scene != null:
		var holder := Node3D.new()
		holder.position = Vector3(13.0, 0, 5.5)
		add_child(holder)
		var tree := tree_scene.instantiate() as Node3D
		holder.add_child(tree)
		candidate_bounds_set = false
		_collect_candidate_bounds(tree, tree)
		if candidate_bounds_set and candidate_bounds.size.y > 0.001:
			tree.position = -Vector3(candidate_bounds.get_center().x, candidate_bounds.position.y, candidate_bounds.get_center().z)
			holder.scale = Vector3.ONE * 4.5 / candidate_bounds.size.y

func _capture(filename := "review_capture.png") -> void:
	await get_tree().create_timer(3.0).timeout
	RenderingServer.force_draw()
	await get_tree().process_frame
	var result := get_viewport().get_texture().get_image().save_png("res://" + filename)
	print("CAPTURE_RESULT=", result)
	print("CAPTURE_FPS=", Engine.get_frames_per_second())
	print("DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit(0 if result == OK else 1)
