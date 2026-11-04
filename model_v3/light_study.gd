extends "res://model_v3_scene.gd"
var diagnostic_sources: Array[Material] = []

func _create_shafts() -> void:
	if _option("lighting","control")=="control":
		super._create_shafts();return
	RenderingServer.environment_set_volumetric_fog_volume_size(192,96)
	for node in get_children():
		if node is WorldEnvironment:
			node.environment.volumetric_fog_enabled=true
			node.environment.volumetric_fog_density=0.0
			node.environment.volumetric_fog_temporal_reprojection_enabled=true
			node.environment.volumetric_fog_temporal_reprojection_amount=0.8
	local_fog=FogVolume.new();local_fog.name="ContinuousForestAir"
	add_child(local_fog)
	camera_attributes=CameraAttributesPractical.new();review_camera.attributes=camera_attributes

func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	if _option("lighting","control")=="control":return
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.environment_set_volumetric_fog_volume_size(192,96)
	for node in get_children():
		if node is DirectionalLight3D:
			node.light_angular_distance=1.2
			node.shadow_blur=1.0
			node.shadow_normal_bias=0.7
			node.shadow_bias=0.025
			node.directional_shadow_max_distance=42.0
			if _option("shadow_range","fixed")=="fit":
				node.directional_shadow_max_distance=60.0
				node.directional_shadow_fade_start=1.0
			node.light_volumetric_fog_energy=2.0
			if _option("volume_shadow","on")=="off":node.shadow_enabled=false
		elif node is WorldEnvironment:
			var e: Environment=node.environment
			e.volumetric_fog_length=45.0
			if _option("shadow_range","fixed")=="fit":e.volumetric_fog_length=60.0
			e.volumetric_fog_anisotropy=0.35
			e.volumetric_fog_ambient_inject=0.02
			e.volumetric_fog_gi_inject=0.05
			e.ssao_radius=0.28;e.ssao_intensity=1.1;e.ssao_power=1.1
			e.ssao_light_affect=0.05
			e.ssil_enabled=true;e.ssil_radius=2.5;e.ssil_intensity=0.65
		elif node is FogVolume and str(node.name).begins_with("SunShaft_"):
			node.queue_free()
	local_fog.position=Vector3(-9,3.5,-3.5)
	local_fog.size=Vector3(16,8,14)
	var medium := ShaderMaterial.new();medium.shader=load("res://model_v3/forest_air.gdshader")
	local_fog.material=medium
	for material in quality_materials.values():
		if material is ShaderMaterial and material.shader.resource_path.ends_with("foliage.gdshader"):
			material.set_shader_parameter("canopy_openings",false)
	get_window().title="遗迹环境 | LIGHT STUDY | 真实遮挡体积光"
	print("LIGHT_STUDY physical_medium=true soft_shadow=1.2deg ssil=0.65")
	if _option("surfaces","off")=="on":
		_surface_study(self)
		for node in get_children():
			if node is WorldEnvironment:
				node.environment.tonemap_mode=Environment.TONE_MAPPER_AGX
				node.environment.adjustment_saturation=1.05
				node.environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
				node.environment.ambient_light_energy=0.42
	if _option("lookstudy","")=="balanced":
		_surface_study(self)
		for node in get_children():
			if node is DirectionalLight3D:
				node.light_color=Color("ffdfb7");node.light_energy=1.95
				node.light_volumetric_fog_energy=4.0
			elif node is WorldEnvironment:
				var e: Environment=node.environment
				e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
				e.ambient_light_color=Color("779dc4");e.ambient_light_energy=0.32
				e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=1.05
				e.adjustment_saturation=1.10;e.adjustment_contrast=1.05
				e.ssil_intensity=0.4;e.ssao_intensity=1.25;e.ssao_radius=0.32
				e.volumetric_fog_gi_inject=0.0
		_balance_stone(self)
	if _option("fog_debug","off")=="on":
		_black_surfaces(self)
		for node in get_children():
			if node is WorldEnvironment:
				node.environment.background_mode=Environment.BG_COLOR;node.environment.background_color=Color.BLACK
				node.environment.glow_enabled=false

func _balance_stone(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var m := node.get_active_material(i) as ShaderMaterial
			if m and m.shader.resource_path.ends_with("road.gdshader"):
				m.set_shader_parameter("road_gain",0.82)
	for child in node.get_children():_balance_stone(child)

func _black_surfaces(node: Node) -> void:
	if node.is_queued_for_deletion():return
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var old: Material=node.get_active_material(i)
			var material := _black_material(old)
			if node.material_override:node.material_override=material
			else:node.set_surface_override_material(i,material)
	elif node is MultiMeshInstance3D:node.material_override=_black_material(node.material_override)
	for child in node.get_children():_black_surfaces(child)

func _black_material(old: Material) -> Material:
	if old:diagnostic_sources.append(old)
	if old is ShaderMaterial:
		var material := old.duplicate() as ShaderMaterial
		var shader := Shader.new()
		var code: String=old.shader.code
		code=code.replace("render_mode ","render_mode unshaded, ")
		var end := code.rfind("}")
		shader.code=code.substr(0,end)+"\n ALBEDO=vec3(0.0); EMISSION=vec3(0.0);\n"+code.substr(end)
		material.shader=shader;return material
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color.BLACK
	return material

func _surface_study(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var old := node.get_active_material(surface) as ShaderMaterial
			if not old:continue
			var path: String=old.shader.resource_path
			var material := old.duplicate() as ShaderMaterial
			if path.ends_with("ground.gdshader"):
				material.shader=load("res://model_v3/study_ground.gdshader")
			elif path.ends_with("foliage.gdshader") and not "model_foliage" in path:
				material.shader=load("res://model_v3/study_foliage.gdshader")
				material.set_shader_parameter("canopy_openings",false)
				node.set_instance_shader_parameter("canopy_center",node.mesh.get_aabb().get_center())
				node.set_instance_shader_parameter("canopy_normal_mix",0.35 if node.mesh.get_aabb().size.y>1.5 else 0.15)
			else:continue
			if node.material_override:node.material_override=material
			else:node.set_surface_override_material(surface,material)
	for child in node.get_children():_surface_study(child)

func _focus() -> void:
	super._focus()
	if not camera_attributes or not review_camera or not cinema:return
	# Protect the full path depth interval, including after zoom and orbit.
	var near_depth := INF;var far_depth := 0.0
	var geometry := get_node_or_null("EnvironmentGeometry") as Node3D
	if not geometry:return
	for point in path_points:
		var depth := -(review_camera.global_transform.affine_inverse()*(geometry.global_transform*point)).z
		near_depth=minf(near_depth,depth);far_depth=maxf(far_depth,depth)
	camera_attributes.dof_blur_near_distance=maxf(0.1,near_depth-1.0)
	camera_attributes.dof_blur_far_distance=far_depth+1.5
	camera_attributes.dof_blur_amount=0.045

func _metadata() -> Dictionary:
	var result := super._metadata()
	result["lighting_study"]=_option("lighting","control")
	result["directional_shadows"]=_option("volume_shadow","on")
	result["preset_ray_density"]=_option("lighting","control")=="control"
	result["look_study"]=_option("lookstudy","")
	result["fog_only_diagnostic"]=_option("fog_debug","off")=="on"
	return result
