extends Node3D

const STYLE_NAMES := ["① 写实 PBR", "② 风格化 PBR（默认基线）", "③ 俯视卡通"]
const LIGHT_NAMES := ["午后暖阳体积光", "中性日光", "阴天柔光"]

var rng := RandomNumberGenerator.new()
var path_points: Array[Vector3] = []
var mats := {}
var quality_materials: Dictionary = {}
var plant_materials: Array[ShaderMaterial] = []
var road_materials: Array[ShaderMaterial] = []
var stone_materials: Array[ShaderMaterial] = []
var ground_material: ShaderMaterial
var vertex_plant_material: ShaderMaterial

var benchmark_leaf_mats: Array[ShaderMaterial] = []
var benchmark_bark_mats: Array[Material] = []
var tree_leaf_nodes: Array[MeshInstance3D] = []
var tree_bark_nodes: Array[MeshInstance3D] = []

var forest_lods: Array[Dictionary] = []
var quality_lods: Array[Dictionary] = []
var model_lods: Array[Dictionary] = []
var stable_tree_tiers: Dictionary = {}
var stable_model_tiers: Dictionary = {}

var review_camera: Camera3D
var camera_attributes: CameraAttributesPractical
var sunlight: DirectionalLight3D
var study_environment: Environment
var local_fog: FogVolume
var hud_label: Label

var camera_target := Vector3(0, 0, 0.8)
var orbit_yaw := 0.0
var orbit_pitch := deg_to_rad(55.0)
var orbit_distance := 26.9
var orbit_dragging := false
var candidate_bounds := AABB()
var candidate_bounds_set := false
var wet_spots := PackedVector4Array()

var style_mode := 1
var light_mode := 0
var wind_enabled := true
var cinema := false
var inspection := false
var active_profile := "quality"
var lod_elapsed := 0.0

func _option(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + key + "="):
			return arg.trim_prefix("--" + key + "=")
	return fallback

func _ready() -> void:
	rng.seed = 22026
	for s in range(3):
		benchmark_leaf_mats.append((load("res://asset_lab/benchmark/materials/leaves_%d.tres" % s) as ShaderMaterial).duplicate())
		benchmark_bark_mats.append((load("res://asset_lab/benchmark/materials/bark_%d.tres" % s) as Material).duplicate())
	style_mode = clampi(int(_option("style", "1")), 0, 2)
	wind_enabled = not ("--freeze-wind" in OS.get_cmdline_user_args())
	cinema = _option("presentation", "clear") == "cinema"
	active_profile = _option("profile", "quality")

	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var res := Vector2i(1421, 736) if active_profile == "preview" else Vector2i(2560, 1440)
	window.content_scale_size = res
	window.size = res

	_make_materials()
	_setup_world()
	_make_path()
	_make_ground()
	_make_ruins()
	_make_vegetation()
	_adjust_composition()
	_align_water()
	_initialize_v10_pipeline()
	_add_camera_help()
	_apply_style(style_mode)
	_apply_lighting_preset(light_mode)
	_set_wind()
	_update_all_lods(true)

	var args := OS.get_cmdline_user_args()
	if "--v10-audit" in args or "--smoke" in args or "--quality-benchmark" in args:
		set_process_unhandled_input(false)
		load("res://render_v10/audit.gd").run.call_deferred(self)

func _mat(color: Color, rough := 1.0, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func _make_materials() -> void:
	mats.edge = _mat(Color(0.63, 0.63, 0.58), 1.0, 0.0)
	mats.dark = _mat(Color(0.19, 0.21, 0.16), 0.95, 0.0)
	mats.wood = _mat(Color(0.23, 0.15, 0.095), 0.95, 0.0)
	mats.terra = _mat(Color(0.38, 0.24, 0.16), 0.90, 0.0)
	mats.metal = _mat(Color(0.22, 0.23, 0.25), 0.42, 0.65)
	mats.purple = _mat(Color(0.61, 0.17, 0.85), 0.35, 0.0)
	mats.purple.emission_enabled = true
	mats.purple.emission = Color(0.62, 0.10, 0.95)
	mats.purple.emission_energy_multiplier = 3.0
	mats.fire = _mat(Color(1.0, 0.29, 0.04), 0.5, 0.0)
	mats.fire.emission_enabled = true
	mats.fire.emission = Color(1.0, 0.12, 0.01)
	mats.fire.emission_energy_multiplier = 2.5

	mats.stone = _mat(Color(0.60, 0.59, 0.53), 0.92, 0.0)
	mats.stone.albedo_texture = load("res://textures/slab_1_Color.jpg")
	mats.stone.normal_enabled = true
	mats.stone.normal_texture = load("res://textures/slab_1_NormalGL.jpg")
	mats.stone.roughness_texture = load("res://textures/slab_1_Roughness.jpg")

	var water := ShaderMaterial.new()
	water.shader = load("res://render_v10/shaders/water.gdshader")
	mats.water = water

	for i in range(8):
		var slab := _mat(Color(0.90, 0.92, 0.92), 0.9, 0.0)
		slab.albedo_texture = load("res://render_v10/textures/slab_%d_Color.png" % i)
		slab.normal_enabled = true
		slab.normal_texture = load("res://render_v10/textures/slab_%d_NormalGL.png" % i)
		slab.normal_scale = 0.28
		slab.roughness_texture = load("res://render_v10/textures/slab_%d_Roughness.png" % i)
		slab.cull_mode = BaseMaterial3D.CULL_DISABLED
		slab.vertex_color_use_as_albedo = true
		slab.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mats["slab%d" % i] = slab

	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://render_v10/shaders/ground.gdshader")
	ground_material.set_shader_parameter("soil_map", load("res://render_v10/textures/soil_balanced.png"))
	ground_material.set_shader_parameter("soil_normal", load("res://textures/Ground003_2K-JPG_NormalGL.jpg"))
	var noise := FastNoiseLite.new()
	noise.seed = 22026
	noise.frequency = 0.04
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true
	noise_tex.noise = noise
	ground_material.set_shader_parameter("noise_map", noise_tex)
	ground_material.set_shader_parameter("forest_map", load("res://render_v10/textures/forest_diff.png"))
	ground_material.set_shader_parameter("forest_normal", load("res://render_v10/textures/forest_nor_gl.png"))
	ground_material.set_shader_parameter("forest_rough", load("res://render_v10/textures/forest_rough.png"))
	ground_material.set_shader_parameter("road_distance_map", load("res://render_v10/textures/road_distance.png"))
	ground_material.set_shader_parameter("layered", 1.0)
	ground_material.set_shader_parameter("normal_strength", 0.20)
	mats.dirt = ground_material

	vertex_plant_material = _create_plant_material(load("res://render_v10/textures/leaf_detail.png"), load("res://render_v10/textures/leaf_normal.png"), null, null, Color(0.95, 0.98, 0.90), true, false)

func _create_plant_material(base_tex: Texture2D, norm_tex: Texture2D, orm_tex: Texture2D, ao_tex: Texture2D, spec_tint: Color, vertex_col: bool, alpha_cut: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render_v10/shaders/plant_pbr.gdshader")
	m.set_shader_parameter("has_base_map", base_tex != null)
	if base_tex:
		m.set_shader_parameter("base_map", base_tex)
	m.set_shader_parameter("has_normal", norm_tex != null)
	if norm_tex:
		m.set_shader_parameter("normal_map", norm_tex)
	m.set_shader_parameter("has_orm", orm_tex != null)
	if orm_tex:
		m.set_shader_parameter("orm_map", orm_tex)
	m.set_shader_parameter("has_ao", ao_tex != null)
	if ao_tex:
		m.set_shader_parameter("ao_map", ao_tex)
	m.set_shader_parameter("species_tint", Vector3(spec_tint.r, spec_tint.g, spec_tint.b))
	m.set_shader_parameter("use_vertex_color", vertex_col)
	m.set_shader_parameter("use_alpha_scissor", alpha_cut)
	plant_materials.append(m)
	return m

func _setup_world() -> void:
	var env_node := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.46, 0.66)
	sky_mat.sky_horizon_color = Color(0.66, 0.75, 0.85)
	sky_mat.ground_bottom_color = Color(0.13, 0.14, 0.10)
	sky_mat.ground_horizon_color = Color(0.38, 0.40, 0.35)
	sky.sky_material = sky_mat
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("779dc4")
	e.ambient_light_energy = 0.36
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.02
	e.tonemap_white = 4.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.06
	e.adjustment_contrast = 1.04
	e.glow_enabled = true
	e.glow_intensity = 0.22
	e.glow_hdr_threshold = 1.25
	e.ssao_enabled = true
	e.ssao_radius = 0.26
	e.ssao_intensity = 1.10
	e.ssao_power = 1.20
	e.ssao_light_affect = 0.05
	e.ssil_enabled = true
	e.ssil_radius = 1.6
	e.ssil_intensity = 0.36
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.0
	e.volumetric_fog_length = 60.0
	e.volumetric_fog_detail_spread = 0.7
	e.volumetric_fog_anisotropy = 0.35
	e.volumetric_fog_ambient_inject = 0.02
	e.volumetric_fog_gi_inject = 0.0
	e.volumetric_fog_temporal_reprojection_enabled = true
	e.volumetric_fog_temporal_reprojection_amount = 0.82
	study_environment = e
	env_node.environment = e
	add_child(env_node)

	sunlight = DirectionalLight3D.new()
	sunlight.name = "Sun"
	sunlight.rotation_degrees = Vector3(-32.0, -135.0, 0.0)
	sunlight.light_color = Color("ffdfb7")
	sunlight.light_energy = 1.75
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sunlight.directional_shadow_max_distance = 60.0
	sunlight.directional_shadow_fade_start = 1.0
	# Zero angular distance + filtered soft shadows eliminates penumbra speckle on geometric leaves
	sunlight.light_angular_distance = 0.0
	sunlight.shadow_blur = 1.0
	sunlight.shadow_normal_bias = 0.65
	sunlight.shadow_bias = 0.025
	sunlight.light_volumetric_fog_energy = 3.2
	add_child(sunlight)

	local_fog = FogVolume.new()
	local_fog.name = "ContinuousForestAir"
	local_fog.position = Vector3(-9.0, 3.5, -3.5)
	local_fog.size = Vector3(16.0, 8.0, 14.0)
	var air_mat := ShaderMaterial.new()
	air_mat.shader = load("res://render_v10/shaders/forest_air.gdshader")
	local_fog.material = air_mat
	add_child(local_fog)

	review_camera = Camera3D.new()
	review_camera.name = "ReviewCamera"
	review_camera.fov = 35.0
	review_camera.keep_aspect = Camera3D.KEEP_WIDTH
	review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if _option("camera", "perspective") == "orthographic" else Camera3D.PROJECTION_PERSPECTIVE
	camera_attributes = CameraAttributesPractical.new()
	review_camera.attributes = camera_attributes
	review_camera.current = true
	add_child(review_camera)
	_set_width(24.0)

	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().use_taa = false
	RenderingServer.directional_shadow_atlas_set_size(4096, false)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(160, 80)

func _view_width() -> float:
	return review_camera.size if review_camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 2.0 * orbit_distance * tan(deg_to_rad(review_camera.fov) * 0.5)

func _set_width(width: float) -> void:
	review_camera.size = width
	if review_camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		orbit_distance = width / (2.0 * tan(deg_to_rad(review_camera.fov) * 0.5))
	_update_camera()

func _update_camera() -> void:
	var horizontal := orbit_distance * cos(orbit_pitch)
	review_camera.position = camera_target + Vector3(sin(orbit_yaw) * horizontal, sin(orbit_pitch) * orbit_distance, cos(orbit_yaw) * horizontal)
	review_camera.look_at(camera_target, Vector3.UP)
	_focus()

func _focus() -> void:
	if not camera_attributes or not review_camera:
		return
	camera_attributes.dof_blur_far_enabled = cinema
	camera_attributes.dof_blur_near_enabled = cinema
	if not cinema:
		return
	var geometry := get_node_or_null("EnvironmentGeometry") as Node3D
	if not geometry or path_points.is_empty():
		return
	var near_depth := INF
	var far_depth := 0.0
	for point in path_points:
		var depth := -(review_camera.global_transform.affine_inverse() * (geometry.global_transform * point)).z
		near_depth = minf(near_depth, depth)
		far_depth = maxf(far_depth, depth)
	camera_attributes.dof_blur_near_distance = maxf(0.1, near_depth - 1.0)
	camera_attributes.dof_blur_far_distance = far_depth + 1.5
	camera_attributes.dof_blur_amount = 0.045

func _puddle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var phase := rng.randf_range(0, TAU)
	var rim: Array[Vector3] = []
	for i in range(32):
		var a := TAU * i / 32.0
		var r := 0.82 + 0.12 * sin(a * 3 + phase) + 0.09 * cos(a * 5 - phase)
		rim.append(Vector3(cos(a) * 0.36 * r, 0, sin(a) * 0.38 * r))
	for i in range(32):
		for point in [Vector3.ZERO, rim[i], rim[(i + 1) % 32]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(point.x / 0.8 + 0.5, point.z / 0.8 + 0.5))
			st.set_color(Color(1, 1, 1) if point == Vector3.ZERO else Color(0, 0, 0))
			st.add_vertex(point)
	st.generate_tangents()
	return st.commit()

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

func _beveled_box(size: Vector3, bevel: float) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	box.subdivide_width = 6
	box.subdivide_height = 6
	box.subdivide_depth = 6
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var half := size * 0.5
	var b := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.3)
	var inner := half - Vector3.ONE * b
	for i in range(vertices.size()):
		var v := vertices[i]
		var c := v.clamp(-inner, inner)
		var n := (v - c).normalized()
		vertices[i] = c + n * b
		normals[i] = n
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _make_path() -> void:
	load("res://render_v10/road.gd").build(self)

func _make_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "TerrainGround"
	ground.mesh = load("res://render_v10/terrain.gd").mesh()
	ground.material_override = mats.dirt
	add_child(ground)
	_box(Vector3(0, -0.28, 0), Vector3(120, 0.3, 120), mats.dirt).name = "DistantGround"

func _near_path(x: float, z: float) -> float:
	var best := 100.0
	for p in path_points:
		best = minf(best, Vector2(x - p.x, z - p.z).length())
	return best

func _column(x: float, z: float, height: float, tilted := false) -> void:
	var holder := _place_pilot("res://meshy_assets/column.glb", Vector3(x, 0, z), height + 0.4, true)
	if holder:
		holder.rotation = Vector3(0.18 if tilted else 0.0, rng.randf_range(-0.12, 0.12), -0.13 if tilted else 0.0)

func _make_ruins() -> void:
	_column(-12.0, -1.0, 2.9, true)
	_column(-11.3, 1.8, 2.1, true)
	_column(11.8, 0.3, 2.5, true)
	_column(11.5, 3.2, 1.45, true)
	_column(-7.0, -7.4, 2.4)
	_column(8.0, -7.3, 1.8, true)
	for pos in [Vector3(-10.8, 0.0, 2.4), Vector3(10.5, 0.0, 1.9)]:
		_place_pilot("res://meshy_assets/pot.glb", pos, 0.58, true)
	_place_pilot("res://meshy_assets/rubble.glb", Vector3(9.8, 0.05, 6.4), 1.3, false)
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
	_box(Vector3(-12.1, 0.20, -3.5), Vector3(2.6, 0.35, 2.0), mats.edge)
	for x in [-13.0, -11.3]:
		_cylinder(Vector3(x, 1.0, -3.7), 0.20, 1.6, mats.stone)
	_box(Vector3(-12.15, 1.85, -3.7), Vector3(2.25, 0.28, 0.5), mats.stone, -0.10)
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

func _bind_benchmark_tree_nodes(node: Node, shadow_only := false) -> void:
	if node is MeshInstance3D and node.mesh:
		node.lod_bias = 100.0
		node.extra_cull_margin = 0.1
		if shadow_only:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		else:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var is_leaf := "LeafClump" in node.name
		if is_leaf:
			tree_leaf_nodes.append(node)
		else:
			tree_bark_nodes.append(node)
		var mat: Material = benchmark_leaf_mats[style_mode] if is_leaf else benchmark_bark_mats[style_mode]
		for s in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(s, mat)
	for child in node.get_children():
		_bind_benchmark_tree_nodes(child, shadow_only)

func _make_imported_trees() -> void:
	var lod0_pack := load("res://asset_lab/benchmark/models/broadleaf_lod0.glb") as PackedScene
	var lod1_pack := load("res://asset_lab/benchmark/models/broadleaf_lod1.glb") as PackedScene
	var lod2_pack := load("res://asset_lab/benchmark/models/broadleaf_lod2.glb") as PackedScene
	var positions: Array[Vector3] = []
	for x in [-13.0, -9.5, -5.9, -2.1, 1.8, 5.7, 9.4, 13.0]:
		positions.append(Vector3(x, 0, -6.0 - 0.3 * sin(x)))
	for z in [-5.0, -1.8, 1.8, 5.3]:
		positions.append(Vector3(-12.8, 0, z))
		positions.append(Vector3(12.8, 0, z))
	for x in [-12, -8, -4, 0, 4, 8, 12]:
		positions.append(Vector3(x, 0, 8.0 + 0.3 * cos(x)))

	for i in range(positions.size()):
		var holder := Node3D.new()
		holder.name = "BenchmarkBroadleaf_%02d" % i
		holder.position = positions[i]
		var target_height := (3.35 if i < 8 else 4.05) + 0.42 * sin(i * 1.7)
		holder.scale = Vector3.ONE * (target_height / 3.755)
		holder.rotation.y = rng.randf_range(0, TAU)
		add_child(holder)

		var high := lod0_pack.instantiate() as Node3D
		high.name = "LOD0"
		_bind_benchmark_tree_nodes(high, false)
		holder.add_child(high)

		var mid := lod1_pack.instantiate() as Node3D
		mid.name = "LOD1"
		_bind_benchmark_tree_nodes(mid, false)
		mid.visible = false
		holder.add_child(mid)

		var low := lod2_pack.instantiate() as Node3D
		low.name = "LOD2"
		_bind_benchmark_tree_nodes(low, false)
		low.visible = false
		holder.add_child(low)

		var shadow_proxy := lod1_pack.instantiate() as Node3D
		shadow_proxy.name = "ShadowLOD"
		_bind_benchmark_tree_nodes(shadow_proxy, true)
		holder.add_child(shadow_proxy)

		forest_lods.append({"holder": holder, "high": high, "mid": mid, "low": low, "tier": 0})

func _make_vegetation() -> void:
	_make_imported_trees()
	_make_3d_shrubs()
	_woodland_edges()

func _make_3d_shrubs() -> void:
	var anchors := [
		Vector2(-7.5, -1.7), Vector2(-3.7, -1.7), Vector2(0.4, -1.7), Vector2(4.5, -1.7),
		Vector2(-6, 1.7), Vector2(-1.4, 1.7), Vector2(3.8, 1.7), Vector2(7.2, 1.7),
		Vector2(-8, 5.9), Vector2(-3.7, 5.8), Vector2(1, 5.9), Vector2(5.8, 5.9),
		Vector2(9.5, 5.6), Vector2(-6.8, -6.0), Vector2(-1.5, -6.0), Vector2(3.5, -6.0)
	]
	var models_helper = load("res://render_v10/models.gd")
	for i in range(anchors.size()):
		var a: Vector2 = anchors[i]
		var size := rng.randf_range(1.0, 1.6)
		var path := "res://meshy_assets/pilot_shrub.glb" if i % 3 == 0 else "res://meshy_assets/shrub_lod1.glb"
		_place_pilot(path, Vector3(a.x, 0.02, a.y), size, false)
		if i % 2 == 0:
			models_helper.plant(self, "fern_0", Vector3(a.x + 0.65, 0.02, a.y + 0.14), 1.25)
		if i % 3 == 1:
			models_helper.plant(self, "fern_1", Vector3(a.x - 0.6, 0.02, a.y - 0.1), 1.1)
		if i % 4 == 1:
			_place_pilot("res://fab_candidates/07/converted/bramble.glb", Vector3(a.x + 0.5, 0.02, a.y + 0.25), 1.4, false)
	_scatter_pilot("res://meshy_assets/shrub_lod2.glb", 24)
	_clean_plants(anchors)

func _clean_plants(anchors: Array) -> void:
	var plant_builder = load("res://render_v10/plants.gd")
	var models_helper = load("res://render_v10/models.gd")
	var grass_transforms: Array[Transform3D] = []
	var flower_transforms: Array = [[], [], []]
	var centers := anchors.duplicate()
	for x in range(-11, 12, 3):
		centers.append(Vector2(x, 7.5))
		centers.append(Vector2(x, -7.2))
	for center: Vector2 in centers:
		for i in range(28):
			var x := center.x + rng.randfn(0, 0.72)
			var z := center.y + rng.randfn(0, 0.35)
			if _near_path(x, z) < 1.03:
				continue
			var s := rng.randf_range(0.75, 1.35)
			grass_transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * s), Vector3(x, 0.0, z)))
		for i in range(20):
			var x := center.x + rng.randfn(0, 0.75)
			var z := center.y + rng.randfn(0, 0.33)
			if _near_path(x, z) < 1.04:
				continue
			var s := rng.randf_range(0.65, 1.15)
			var kind := 0 if i % 5 < 3 else (1 if i % 5 == 3 else 2)
			flower_transforms[kind].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * s), Vector3(x, 0.0, z)))
	_scatter(plant_builder.grass(), vertex_plant_material, grass_transforms)
	for i in range(centers.size()):
		var point: Vector2 = centers[i]
		var where := Vector3(point.x - 0.5, 0.015, point.y + 0.15)
		_place_fab_variant("res://fab_candidates/05/with_tangents.glb", i % 4, where, 0.65)
		models_helper.plant(self, "fern_%d" % (i % 2), where + Vector3(0.55, 0, -0.25), 1.3)
		models_helper.plant(self, "fern_%d" % ((i + 1) % 2), where + Vector3(-0.2, 0, 0.25), 1.2)
	for kind in range(3):
		var transforms: Array[Transform3D] = []
		transforms.assign(flower_transforms[kind])
		var reduced: Array[Transform3D] = []
		var count := ceili(transforms.size() / 7.0)
		for idx in range(count):
			reduced.append(transforms[mini(idx * 7, transforms.size() - 1)])
		_scatter(models_helper.mesh("flowers_%d_lod0" % (kind % 2)), vertex_plant_material, reduced)

func _woodland_edges() -> void:
	var models_helper = load("res://render_v10/models.gd")
	for row in [-5.2, 5.2]:
		for i in range(14):
			var x := -12 + i * 1.85
			var z: float = row + 0.45 * sin(i * 2.4)
			_place_pilot("res://fab_candidates/07/converted/hazel.glb" if i % 4 == 0 else "res://fab_candidates/07/converted/bramble.glb", Vector3(x, 0, z), 2.2 + 0.25 * sin(i), false)
	for row in [-1.7, 1.7]:
		for i in range(16):
			var x := -8.4 + i * 1.1
			models_helper.plant(self, "fern_%d" % (i % 2), Vector3(x, 0, row + 0.15 * sin(i * 2.4)), 1.3)
	var perimeter: Array[Vector3] = []
	for row in [-6.4, 6.5]:
		for i in range(14):
			var x := -12.0 + i * 1.85
			if row < 0 and x > 7:
				continue
			perimeter.append(Vector3(x, 0, row + 0.25 * sin(i * 2.4)))
	for side in [-12.0, 12.0]:
		for i in range(8):
			perimeter.append(Vector3(side, 0, -5.5 + i * 1.5))
	_batch_foliage("res://fab_candidates/07/converted/bramble.glb", perimeter, 2.4)

	var belts: Array[Vector3] = []
	for row in [-1.7, 1.7]:
		for i in range(24):
			belts.append(Vector3(-8.4 + i * 0.72, 0, row + (0.0 if i % 2 == 0 else 0.45)))
	var low_edges: Array[Vector3] = []
	for i in range(26):
		var x := -12 + i * 0.95
		if x < 7:
			low_edges.append(Vector3(x, 0, -4.3 + 0.08 * sin(i * 2)))
	for side in [-12.6, 12.6]:
		for i in range(10):
			low_edges.append(Vector3(side, 0, -5.5 + i * 1.15))
	for pts_info in [[belts, 1.5], [low_edges, 1.75]]:
		var pts: Array[Vector3] = pts_info[0]
		var w: float = pts_info[1]
		for i in range(pts.size()):
			if i % 3 == 1:
				continue
			var where := pts[i] + Vector3(0.13 * sin(i * 2.7), 0, 0.12 * cos(i * 1.8))
			var holder: Node3D = models_helper.plant(self, "fern_%d" % (i % 2), where, w * (0.65 + 0.15 * sin(i * 1.7)))
			holder.scale.y *= 0.8

func _batch_foliage(path: String, points: Array[Vector3], width: float) -> void:
	var packed := load(path) as PackedScene
	var source := packed.instantiate() as Node3D
	add_child(source)
	var part := _first_mesh(source)
	var local: Transform3D = source.global_transform.affine_inverse() * part.global_transform
	var bounds: AABB = local * part.mesh.get_aabb()
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var span := maxf(bounds.size.x, bounds.size.z)
	var proxy := MeshInstance3D.new()
	proxy.mesh = part.mesh
	_configure_materials(proxy, path)
	var material := proxy.get_surface_override_material(0)
	var transforms: Array[Transform3D] = []
	for point in points:
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * width / span * rng.randf_range(0.9, 1.1))
		transforms.append(Transform3D(basis * local.basis, point + basis * (local.origin - center)))
		if transforms.size() == 8:
			_scatter(part.mesh, material, transforms)
			transforms = []
	if not transforms.is_empty():
		_scatter(part.mesh, material, transforms)
	proxy.free()
	source.queue_free()

func _place_fab_variant(path: String, variant: int, where: Vector3, width: float) -> Node3D:
	var packed := load(path) as PackedScene
	var source := packed.instantiate() as Node3D
	var choices: Array[MeshInstance3D] = []
	for child in source.get_children():
		if child is MeshInstance3D and child.mesh and not "_LOD" in child.name:
			choices.append(child)
	if choices.is_empty():
		source.free()
		return null
	var selected := choices[variant % choices.size()].duplicate() as MeshInstance3D
	var box: AABB = selected.transform * selected.mesh.get_aabb()
	selected.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var holder := Node3D.new()
	holder.name = "FabVariant_" + str(variant)
	holder.add_child(selected)
	holder.scale = Vector3.ONE * width / maxf(box.size.x, box.size.z)
	holder.position = where
	holder.rotation.y = rng.randf_range(0, TAU)
	add_child(holder)
	_configure_materials(holder, path)
	source.free()
	return holder

func _place_pilot(path: String, where: Vector3, size: float, height_based: bool) -> Node3D:
	if "shrub" in path and not "lod2" in path:
		var source_path := "res://shrub_02/shrub_02_prepared.gltf"
		var source := (load(source_path) as PackedScene).instantiate() as Node3D
		var choices: Array[MeshInstance3D] = []
		_collect_scan_parts(source, choices)
		var part := choices[rng.randi() % choices.size()].duplicate() as MeshInstance3D
		var bounds: AABB = part.transform * part.mesh.get_aabb()
		part.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var holder := Node3D.new()
		holder.name = "ScannedShrub"
		holder.add_child(part)
		var dimension := bounds.size.y if height_based else maxf(bounds.size.x, bounds.size.z)
		holder.scale = Vector3.ONE * size / maxf(dimension, 0.01)
		holder.position = where
		holder.rotation.y = rng.randf_range(0, TAU)
		add_child(holder)
		_configure_materials(holder, source_path)
		source.free()
		return holder

	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var holder := Node3D.new()
	holder.position = where
	add_child(holder)
	var model := packed.instantiate() as Node3D
	holder.add_child(model)
	candidate_bounds_set = false
	_collect_candidate_bounds(model, model)
	if not candidate_bounds_set:
		return null
	model.position = -Vector3(candidate_bounds.get_center().x, candidate_bounds.position.y, candidate_bounds.get_center().z)
	var span := candidate_bounds.size.y if height_based else maxf(candidate_bounds.size.x, candidate_bounds.size.z)
	if span > 0.001:
		holder.scale = Vector3.ONE * size / span
	holder.rotation.y = rng.randf_range(0, TAU)
	_configure_materials(holder, path)
	return holder

func _collect_scan_parts(node: Node, parts: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh:
		parts.append(node)
	for child in node.get_children():
		_collect_scan_parts(child, parts)

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
	var proxy := MeshInstance3D.new()
	proxy.mesh = part.mesh
	_configure_materials(proxy, path)
	var mat := proxy.get_surface_override_material(0)
	_scatter(part.mesh, mat, transforms)
	proxy.free()
	source.queue_free()

func _scatter(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_custom_data(i, _instance_tint(transforms[i].origin))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	add_child(inst)

func _instance_tint(pos: Vector3) -> Color:
	var seed_value := absf(sin(pos.x * 12.9898 + pos.z * 78.233) * 43758.5453)
	var number := seed_value - floorf(seed_value)
	return Color(0.84, 0.98, 0.86, 1) if number < 0.45 else (Color(0.78, 0.96, 0.92, 1) if number < 0.8 else Color(1.02, 1.0, 0.82, 1))

func _configure_materials(node: Node, path: String) -> void:
	if node is MeshInstance3D and node.mesh:
		node.lod_bias = 100.0
		node.extra_cull_margin = 0.05
		for surface in range(node.mesh.get_surface_count()):
			var original := node.get_active_material(surface) as StandardMaterial3D
			if not original:
				continue
			var key := path + ":" + str(original.get_rid())
			if not quality_materials.has(key):
				var is_plant := path.contains("shrub") or path.contains("fern") or path.contains("grass") or path.contains("flowers") or path.contains("bramble") or path.contains("hazel")
				if is_plant:
					var tint := Color(0.86, 0.92, 0.82)
					if path.contains("shrub"):
						tint = Color(0.76, 0.86, 0.72)
					var ao_path := path.get_basename() + "_ao.png"
					var ao_tex: Texture2D = load(ao_path) if ResourceLoader.exists(ao_path) else (original.ao_texture if original.ao_enabled else null)
					var valid_rough := original.roughness_texture != null and original.roughness_texture != original.normal_texture
					var orm_tex: Texture2D = original.roughness_texture if valid_rough else null
					var cut := original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or "bramble" in path or "hazel" in path or "shrub_02" in path
					var m := _create_plant_material(original.albedo_texture, original.normal_texture if original.normal_enabled else null, orm_tex, ao_tex, tint, false, cut)
					m.set_shader_parameter("source_tint", original.albedo_color)
					quality_materials[key] = m
				else:
					var stone := ShaderMaterial.new()
					stone.shader = load("res://render_v10/shaders/stone.gdshader")
					stone.set_shader_parameter("base_map", original.albedo_texture)
					stone.set_shader_parameter("normal_map", original.normal_texture)
					stone.set_shader_parameter("orm_map", original.roughness_texture)
					stone.set_shader_parameter("normal_depth", 0.45 if path.contains("repaired") else 0.65)
					stone.set_shader_parameter("base_tint", Color(0.95, 0.97, 1.0))
					stone_materials.append(stone)
					quality_materials[key] = stone
			node.set_surface_override_material(surface, quality_materials[key])
			var node_pos: Vector3 = node.global_position if node.is_inside_tree() else node.position
			node.set_instance_shader_parameter("plant_palette", _instance_tint(node_pos))
	for child in node.get_children():
		_configure_materials(child, path)

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

func _ground_scene_objects() -> void:
	var terrain = load("res://render_v10/terrain.gd")
	for child in get_children():
		if not child is Node3D or child is Camera3D or child is Light3D or child is WorldEnvironment or child is FogVolume:
			continue
		if str(child.name) in ["TerrainGround", "DistantGround"]:
			continue
		if str(child.name).begins_with("RoadSlab_") or str(child.name).begins_with("Curb_"):
			continue
		if child is MultiMeshInstance3D:
			for i in range(child.multimesh.instance_count):
				var t: Transform3D = child.multimesh.get_instance_transform(i)
				t.origin.y += terrain.height(t.origin.x, t.origin.z)
				child.multimesh.set_instance_transform(i, t)
		elif child.get_class() == "Node3D":
			candidate_bounds_set = false
			_collect_candidate_bounds(child, child)
			if candidate_bounds_set:
				var rotated: AABB = Transform3D(child.basis, Vector3.ZERO) * candidate_bounds
				child.position.y = terrain.height(child.position.x, child.position.z) - rotated.position.y + 0.002
		else:
			child.position.y += terrain.height(child.position.x, child.position.z)

func _adjust_composition() -> void:
	_ground_scene_objects()
	var geometry := Node3D.new()
	geometry.name = "EnvironmentGeometry"
	add_child(geometry)
	for child in get_children():
		if child == geometry or child is Camera3D or child is DirectionalLight3D or child is WorldEnvironment or child is FogVolume:
			continue
		if child is MultiMeshInstance3D:
			for i in range(child.multimesh.instance_count):
				var t: Transform3D = child.multimesh.get_instance_transform(i)
				t.origin *= Vector3(0.85, 1.0, 1.2)
				child.multimesh.set_instance_transform(i, t)
		elif child is Node3D:
			child.position *= Vector3(0.85, 1.0, 1.2)
			if child is MeshInstance3D:
				child.scale *= Vector3(0.85, 1.0, 1.2)
		child.reparent(geometry, false)

func _align_water() -> void:
	var geometry := get_node_or_null("EnvironmentGeometry")
	if not geometry:
		return
	for node in geometry.get_children():
		if node is MeshInstance3D and node.material_override == mats.water:
			var roof := _surface_roof(geometry, node.global_position, node)
			if roof > 0.05:
				node.global_position.y = roof + 0.0015

func _surface_roof(node: Node, point: Vector3, water: Node) -> float:
	var result := -INF
	if node is MeshInstance3D and node != water and node.is_visible_in_tree() and node.mesh and not str(node.name).contains("Ground"):
		var box: AABB = node.global_transform * node.mesh.get_aabb()
		if point.x > box.position.x and point.x < box.end.x and point.z > box.position.z and point.z < box.end.z and box.end.y > 0.05 and box.end.y < 0.25:
			result = box.end.y
	for child in node.get_children():
		result = maxf(result, _surface_roof(child, point, water))
	return result

func _initialize_v10_pipeline() -> void:
	var geometry := get_node("EnvironmentGeometry") as Node3D
	wet_spots = PackedVector4Array()
	for child in geometry.get_children():
		if child is MeshInstance3D and child.material_override == mats.water:
			wet_spots.append(Vector4(child.global_position.x, child.global_position.z, 1, 0))
			child.visible = false
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	while wet_spots.size() < 4:
		wet_spots.append(Vector4(1000, 1000, 0, 0))

	var rune_maps := []
	for i in range(4):
		var tex := load("res://render_v10/textures/rune_%d.png" % i) as Texture2D
		rune_maps.append(tex)
	var engraving_ids := [5, 17, 32, 45]
	var has_refl := ResourceLoader.exists("res://render_v10/assets/water_reflection.res")
	var refl_cube: TextureLayered = load("res://render_v10/assets/water_reflection.res") if has_refl else null

	for child in geometry.get_children():
		if child is MeshInstance3D and (str(child.name).begins_with("RoadSlab_") or str(child.name).begins_with("Curb_")):
			var original := child.material_override as StandardMaterial3D
			if not original:
				continue
			var m := ShaderMaterial.new()
			m.shader = load("res://render_v10/shaders/road.gdshader")
			m.set_shader_parameter("base_map", original.albedo_texture)
			m.set_shader_parameter("normal_map", original.normal_texture)
			m.set_shader_parameter("rough_map", original.roughness_texture)
			m.set_shader_parameter("road_gain", 0.84)
			m.set_shader_parameter("tint", Color(0.90, 0.93, 0.98))
			m.set_shader_parameter("water_enabled", 1.0)
			var box: AABB = (child.global_transform * child.get_aabb()).grow(0.52)
			var local_spots := PackedVector4Array()
			var active := false
			for spot in wet_spots:
				if spot.z > 0.5 and box.has_point(Vector3(spot.x, child.global_position.y + 0.1, spot.y)):
					local_spots.append(spot)
					active = true
				else:
					local_spots.append(Vector4(1000, 1000, 0, 0))
			m.set_shader_parameter("wet_centers", local_spots)
			m.set_shader_parameter("has_wet", active)
			if has_refl:
				m.set_shader_parameter("water_reflection", refl_cube)
				m.set_shader_parameter("has_baked_reflection", true)
				m.set_shader_parameter("reflection_energy", 1.0)
			var slab_index := int(str(child.name).trim_prefix("RoadSlab_")) if str(child.name).begins_with("RoadSlab_") else -1
			if slab_index in engraving_ids:
				m.set_shader_parameter("rune_enabled", 1.0)
				m.set_shader_parameter("rune_map", rune_maps[engraving_ids.find(slab_index)])
			child.material_override = m
			road_materials.append(m)

	# Clear foreground trees/plants blocking the road or portal device
	var terrain = load("res://render_v10/terrain.gd")
	var portal_clearance := AABB(Vector3(7.65, -0.1, -5.85), Vector3(3.1, 3.6, 2.5))
	for node in geometry.get_children():
		if node is Node3D and not node is MultiMeshInstance3D and (str(node.name).begins_with("BenchmarkBroadleaf") or str(node.name).begins_with("V10Plant") or str(node.name).begins_with("Scanned") or str(node.name).begins_with("FabVariant")):
			var is_tree := str(node.name).begins_with("BenchmarkBroadleaf")
			if is_tree and node.position.z > 7.0:
				_move_plant(node, Vector3(0, 0, 2.0))
			if is_tree and absf(node.position.x) > 12.5:
				_move_plant(node, Vector3(signf(node.position.x) * 1.6, 0, 0))
			if not is_tree:
				var target := _plant_clearance(node.position)
				_move_plant(node, target - node.position)
				if node.position.z >= 4.0:
					_move_plant(node, Vector3(signf(node.position.x) * 0.6 if absf(node.position.x) > 8.5 else 0.0, 0, 1.2))
			candidate_bounds_set = false
			_collect_candidate_bounds(node, node)
			if candidate_bounds_set:
				var bounds: AABB = node.transform * candidate_bounds
				if bounds.intersects(portal_clearance):
					_move_plant(node, Vector3(0, 0, portal_clearance.position.z - bounds.end.z - 0.35))

	load("res://render_v10/models.gd").apply_slabs_and_rocks(self)

	# Roadside pebble debris
	var debris_rng := RandomNumberGenerator.new()
	debris_rng.seed = 721102
	var d_mesh: ArrayMesh = _beveled_box(Vector3(0.11, 0.055, 0.08), 0.012)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = d_mesh
	var d_points: Array[Transform3D] = []
	for i in range(1500):
		var p := Vector2(debris_rng.randf_range(-11, 11), debris_rng.randf_range(-5, 5))
		var dist: float = terrain.road_distance(p.x, p.y)
		if dist < 0.76 or dist > 1.03:
			continue
		var basis := Basis(Vector3.UP, debris_rng.randf_range(0, TAU)).scaled(Vector3.ONE * debris_rng.randf_range(0.55, 1.4))
		d_points.append(Transform3D(basis, Vector3(p.x, terrain.height(p.x, p.y) + 0.02, p.y)))
		if d_points.size() == 48:
			break
	mm.instance_count = d_points.size()
	for i in range(d_points.size()):
		mm.set_instance_transform(i, d_points[i])
		mm.set_instance_color(i, Color(0.40, 0.43, 0.36) * debris_rng.randf_range(0.8, 1.2))
	var debris := MultiMeshInstance3D.new()
	debris.name = "RoadsideDebris"
	debris.multimesh = mm
	var d_mat := StandardMaterial3D.new()
	d_mat.vertex_color_use_as_albedo = true
	d_mat.roughness = 0.9
	debris.material_override = d_mat
	geometry.add_child(debris)

	# Portal bounce light & beveled metal posts
	var center := Vector3(9.2, 0, -4.6)
	for node in geometry.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and node.position.distance_to(center + Vector3(0, 1, 0)) < 2.0:
			if node.material_override == mats.metal:
				node.mesh = _beveled_box((node.mesh as BoxMesh).size, 0.025)
	var portal_light := OmniLight3D.new()
	portal_light.name = "PortalBounce"
	portal_light.position = geometry.to_global(center + Vector3(0, 0.75, 0.6))
	portal_light.light_color = Color(0.65, 0.22, 1.0)
	portal_light.light_energy = 1.2
	portal_light.omni_range = 2.5
	portal_light.shadow_enabled = false
	add_child(portal_light)

func _plant_clearance(point: Vector3) -> Vector3:
	if absf(point.x) < 9 and absf(point.z) > 0.8 and absf(point.z) < 2.6:
		point.z = signf(point.z) * clampf(absf(point.z), 1.5, 1.9)
	elif absf(point.z) > 4.6 and absf(point.z) < 7.0:
		point.z += signf(point.z) * 0.5
	return point

func _move_plant(node: Node3D, offset: Vector3) -> void:
	var terrain = load("res://render_v10/terrain.gd")
	var old := node.position
	node.position += offset
	node.position.y += terrain.height(node.position.x, node.position.z) - terrain.height(old.x, old.z)

func _apply_style(mode: int) -> void:
	style_mode = clampi(mode, 0, 2)
	var leaf_mat := benchmark_leaf_mats[style_mode]
	var bark_mat := benchmark_bark_mats[style_mode]
	for n in tree_leaf_nodes:
		if is_instance_valid(n):
			for s in range(n.mesh.get_surface_count()):
				n.set_surface_override_material(s, leaf_mat)
	for n in tree_bark_nodes:
		if is_instance_valid(n):
			for s in range(n.mesh.get_surface_count()):
				n.set_surface_override_material(s, bark_mat)

	var p_shader: Shader = load("res://render_v10/shaders/plant_toon.gdshader" if style_mode == 2 else "res://render_v10/shaders/plant_pbr.gdshader")
	var n_str: float = [0.32, 0.12, 0.02][style_mode]
	var n_blend: float = [0.18, 0.64, 0.86][style_mode]
	var rough: float = [0.54, 0.78, 0.94][style_mode]
	var vari: float = [0.18, 0.36, 0.40][style_mode]
	var tex_w: float = [0.95, 0.52, 0.16][style_mode]
	var ao_s: float = [0.50, 0.58, 0.62][style_mode]
	for pm in plant_materials:
		pm.shader = p_shader
		pm.set_shader_parameter("style_mode", style_mode)
		pm.set_shader_parameter("normal_strength", n_str)
		pm.set_shader_parameter("normal_blend", n_blend)
		pm.set_shader_parameter("roughness", rough)
		pm.set_shader_parameter("variation", vari)
		pm.set_shader_parameter("texture_weight", tex_w)
		pm.set_shader_parameter("ao_strength", ao_s)
		pm.set_shader_parameter("wind_strength", 1.0 if wind_enabled else 0.0)

	if ground_material:
		ground_material.set_shader_parameter("style_mode", style_mode)
	for rm in road_materials:
		rm.set_shader_parameter("style_mode", style_mode)
	for sm in stone_materials:
		sm.set_shader_parameter("style_mode", style_mode)
	_update_hud()

func _apply_lighting_preset(index: int) -> void:
	light_mode = posmod(index, 3)
	if light_mode == 0:
		# Afternoon Golden Volumetric Sun (Default)
		sunlight.rotation_degrees = Vector3(-32.0, -135.0, 0.0)
		sunlight.light_color = Color("ffdfb7")
		sunlight.light_energy = 1.75
		sunlight.light_volumetric_fog_energy = 3.2
		study_environment.ambient_light_color = Color("779dc4")
		study_environment.ambient_light_energy = 0.36
		study_environment.tonemap_exposure = 1.02
		local_fog.visible = true
	elif light_mode == 1:
		# Neutral Daylight
		sunlight.rotation_degrees = Vector3(-48.0, -125.0, 0.0)
		sunlight.light_color = Color(1.0, 0.97, 0.92)
		sunlight.light_energy = 1.35
		sunlight.light_volumetric_fog_energy = 1.2
		study_environment.ambient_light_color = Color(0.68, 0.76, 0.88)
		study_environment.ambient_light_energy = 0.45
		study_environment.tonemap_exposure = 1.00
		local_fog.visible = true
	else:
		# Overcast Soft Light
		sunlight.rotation_degrees = Vector3(-62.0, -110.0, 0.0)
		sunlight.light_color = Color(0.84, 0.90, 0.98)
		sunlight.light_energy = 0.72
		sunlight.light_volumetric_fog_energy = 0.4
		study_environment.ambient_light_color = Color(0.64, 0.72, 0.82)
		study_environment.ambient_light_energy = 0.62
		study_environment.tonemap_exposure = 1.05
		local_fog.visible = false
	_update_hud()

func _set_wind() -> void:
	var w := 1.0 if wind_enabled else 0.0
	for m in benchmark_leaf_mats:
		m.set_shader_parameter("wind_strength", w)
	for pm in plant_materials:
		pm.set_shader_parameter("wind_strength", w)
	_update_hud()

func _process(delta: float) -> void:
	lod_elapsed += delta
	if lod_elapsed > 0.15:
		lod_elapsed = 0.0
		_update_all_lods(false)

func _update_all_lods(force_initial: bool) -> void:
	if not review_camera:
		return
	var width := _view_width()
	var initial_tier := 0 if width < 13.0 else (1 if width < 28.0 else 2)
	for item in forest_lods:
		var id: int = item.holder.get_instance_id()
		var tier: int = initial_tier if force_initial else stable_tree_tiers.get(id, initial_tier)
		if width < 11.96:
			tier = 0
		elif width > 30.24:
			tier = 2
		elif tier == 0 and width > 14.04:
			tier = 1
		elif tier == 2 and width < 25.76:
			tier = 1
		stable_tree_tiers[id] = tier
		item.tier = tier
		item.high.visible = (tier == 0)
		item.mid.visible = (tier == 1)
		item.low.visible = (tier == 2)
	for item in model_lods:
		var id: int = item.node.get_instance_id()
		var tier: int = initial_tier if force_initial else stable_model_tiers.get(id, initial_tier)
		if width < 11.96:
			tier = 0
		elif width > 30.24:
			tier = 2
		elif tier == 0 and width > 14.04:
			tier = 1
		elif tier == 2 and width < 25.76:
			tier = 1
		stable_model_tiers[id] = tier
		item.tier = tier
		item.node.mesh = item.meshes[tier]

func _add_camera_help() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg in ["--v10-audit", "--smoke", "--quality-benchmark"]:
			return
	var layer := CanvasLayer.new()
	hud_label = Label.new()
	hud_label.position = Vector2(18, 14)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud_label.add_theme_constant_override("shadow_offset_x", 2)
	hud_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud_label)
	add_child(layer)
	_update_hud()

func _update_hud() -> void:
	var title := "古迹环境场景验收 | RENDER V10 基线 | %s | %s" % [STYLE_NAMES[style_mode], LIGHT_NAMES[light_mode]]
	get_window().title = title
	if is_instance_valid(hud_label):
		hud_label.text = "%s\nF1/F2/F3：切换三渲染风格 | L：切换光照（午后/中性/阴天） | F5：风动（%s） | F8：景深（%s）\nTab：透视/正交 | F4：2K/预览分辨率 | 右键拖动：旋转 | WASD：平移 | 滚轮：缩放 | R/Home：重置机位" % [
			title,
			"开" if wind_enabled else "关",
			"展示" if cinema else "清晰验收"
		]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbit_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_set_width(clampf(_view_width() * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 6.0, 40.0))
			_update_all_lods(false)
		return
	if event is InputEventMouseMotion and orbit_dragging:
		orbit_yaw -= event.relative.x * 0.006
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, deg_to_rad(12.0), deg_to_rad(82.0))
		_update_camera()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_apply_style(0)
			KEY_F2:
				_apply_style(1)
			KEY_F3:
				_apply_style(2)
			KEY_L:
				_apply_lighting_preset(light_mode + 1)
			KEY_F5:
				wind_enabled = not wind_enabled
				_set_wind()
			KEY_F8:
				cinema = not cinema
				_focus()
				_update_hud()
			KEY_TAB:
				var w := _view_width()
				review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if review_camera.projection == Camera3D.PROJECTION_PERSPECTIVE else Camera3D.PROJECTION_PERSPECTIVE
				_set_width(w)
			KEY_F4:
				active_profile = "preview" if active_profile == "quality" else "quality"
				var size := Vector2i(1421, 736) if active_profile == "preview" else Vector2i(2560, 1440)
				get_window().content_scale_size = size
				get_window().size = size
			KEY_R, KEY_HOME:
				camera_target = Vector3(0, 0, 0.8)
				orbit_yaw = 0.0
				orbit_pitch = deg_to_rad(55.0)
				_set_width(24.0)
				_update_all_lods(true)
			KEY_W, KEY_UP:
				camera_target += Vector3(0, 0, -0.6).rotated(Vector3.UP, orbit_yaw)
				_update_camera()
			KEY_S, KEY_DOWN:
				camera_target += Vector3(0, 0, 0.6).rotated(Vector3.UP, orbit_yaw)
				_update_camera()
			KEY_A, KEY_LEFT:
				camera_target += Vector3(-0.6, 0, 0).rotated(Vector3.UP, orbit_yaw)
				_update_camera()
			KEY_D, KEY_RIGHT:
				camera_target += Vector3(0.6, 0, 0).rotated(Vector3.UP, orbit_yaw)
				_update_camera()

func _metadata() -> Dictionary:
	return {
		"version": "RENDER V10 baseline",
		"style_mode": style_mode,
		"style_name": STYLE_NAMES[style_mode],
		"light_mode": light_mode,
		"light_name": LIGHT_NAMES[light_mode],
		"trees_count": forest_lods.size(),
		"plants_lod_count": model_lods.size(),
		"wind_enabled": wind_enabled,
		"cinema_dof": cinema,
		"resolution": str(get_viewport().get_texture().get_size())
	}
