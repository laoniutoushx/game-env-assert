extends "res://quality_baseline.gd"

var quality_materials := {}
var quality_lods: Array[Dictionary] = []
var lod_elapsed := 0.0

func _enabled(feature: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--diagnostic="):
			return arg.trim_prefix("--diagnostic=") == feature
	return true

func _ready() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_size = Vector2i(1421,736)
	super._ready()
	_align_water()
	if _enabled("render"):
		get_viewport().msaa_3d = Viewport.MSAA_4X
		get_viewport().use_taa = false
	_update_quality_lods()
	var args := OS.get_cmdline_user_args()
	if "--quality-benchmark" in args:
		_quality_benchmark.call_deferred()
	elif "--quality-top" in args or "--quality-side" in args or "--quality-close" in args:
		if "--quality-side" in args:
			orbit_yaw = 0.65
			orbit_pitch = deg_to_rad(32.0)
			_update_camera()
		elif "--quality-close" in args:
			camera_target = Vector3(-2.3, 0.4, 2.1)
			review_camera.size = 5.0
			orbit_yaw = 0.2
			orbit_pitch = deg_to_rad(32)
			_update_camera()
		_quality_capture.call_deferred()

func _quality_capture() -> void:
	await get_tree().create_timer(6.0).timeout
	var name := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--diagnostic="):
			name = arg.trim_prefix("--diagnostic=")
		elif arg.begins_with("--probe="):
			name = arg.trim_prefix("--probe=")
	var view := "side" if "--quality-side" in OS.get_cmdline_user_args() else "top"
	if "--quality-close" in OS.get_cmdline_user_args(): view = "close"
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://quality_round/" + name + "_" + view + ".png")
	print("QUALITY_CAPTURE ", name, " ", view, " ", result)
	await _finish(0 if result == OK else 1)

func _finish(code: int) -> void:
	for child in get_children():
		if child is ReflectionProbe or child is WorldEnvironment:
			child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)

func _quality_benchmark() -> void:
	await get_tree().create_timer(6.0).timeout
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(600):
		orbit_yaw += TAU / 600.0
		orbit_pitch = deg_to_rad(35.0 + 25.0 * sin(TAU * i / 600.0))
		review_camera.size = 11.0 + 4.0 * sin(TAU * i / 600.0)
		_update_camera()
		await get_tree().process_frame
		var current := Time.get_ticks_usec()
		times.append((current - previous) / 1000.0)
		previous = current
	times.sort()
	var data := {"samples":600,"warmup_seconds":6,"p50_ms":times[300],"p95_ms":times[570],"gpu":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().get_visible_rect().size),"render_target_pixels":str(get_viewport().get_texture().get_size()),"msaa":get_viewport().msaa_3d,"draw_calls_last":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives_last":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	var file := FileAccess.open("res://quality_round/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"  "))
	print("QUALITY_BENCHMARK ",JSON.stringify(data))
	await _finish(0)

func _add_camera_help() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality-"): return
	super._add_camera_help()

func _setup_world() -> void:
	super._setup_world()
	if not _enabled("lighting"): return
	for child in get_children():
		if child is WorldEnvironment:
			var env: Environment = child.environment
			var sky := Sky.new()
			var daylight := ProceduralSkyMaterial.new()
			daylight.sky_top_color = Color(0.30,0.42,0.59)
			daylight.sky_horizon_color = Color(0.76,0.78,0.72)
			daylight.ground_bottom_color = Color(0.13,0.14,0.10)
			daylight.ground_horizon_color = Color(0.57,0.60,0.54)
			sky.sky_material = daylight
			env.sky = sky
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			env.ambient_light_energy = 0.38
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 0.9
			env.ssao_radius = 0.45
			env.ssao_intensity = 1.0
			env.ssao_power = 1.3
			env.ssao_light_affect = 0.25
		elif child is DirectionalLight3D:
			child.rotation_degrees = Vector3(-38,-48,-12)
			child.light_color = Color(1.0,0.91,0.79)
			child.light_energy = 1.5
			child.directional_shadow_max_distance = 45.0
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			child.shadow_bias = 0.025
			child.shadow_normal_bias = 0.7
			if "--no-shadows" in OS.get_cmdline_user_args(): child.shadow_enabled = false

func _make_materials() -> void:
	super._make_materials()
	if not _enabled("materials"): return
	var water := ShaderMaterial.new()
	water.shader = load("res://quality_round/water.gdshader")
	mats.water = water
	mats.edge.albedo_color = Color(0.63,0.63,0.58)
	for i in range(8):
		var slab: StandardMaterial3D = mats["slab%d"%i]
		slab.normal_scale = 0.4
		slab.albedo_color = Color(0.62+i*0.012,0.63+i*0.010,0.59+i*0.010)
		slab.roughness_texture = null
		slab.roughness = 0.85
		slab.metallic_specular = 0.25
		slab.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if "--no-legacy-normal" in OS.get_cmdline_user_args(): slab.normal_enabled = false
		if "--grey-old" in OS.get_cmdline_user_args():
			slab.normal_enabled = false
			slab.albedo_texture = null
			slab.albedo_color = Color(0.5,0.5,0.5)
	var ground := ShaderMaterial.new()
	ground.shader = load("res://quality_round/ground.gdshader")
	ground.set_shader_parameter("soil_map",load("res://textures/ground_muted.jpg"))
	ground.set_shader_parameter("soil_normal",load("res://textures/Ground003_2K-JPG_NormalGL.jpg"))
	var noise := FastNoiseLite.new()
	noise.seed = 22026
	noise.frequency = 0.04
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	ground.set_shader_parameter("noise_map",texture)
	mats.dirt = ground

func _stone_mesh(width: float, depth: float) -> ArrayMesh:
	var mesh := super._stone_mesh(width,depth)
	if not _enabled("assets"): return mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,vertices.size(),3):
		var order := [i,i+1,i+2]
		var cross := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
		if cross.dot(normals[i])>0:
			order = [i,i+2,i+1]
		for index in order:
			surface.set_normal(normals[index])
			surface.set_color(colors[index])
			surface.set_uv(uvs[index])
			surface.add_vertex(vertices[index])
	surface.generate_tangents()
	return surface.commit()

func _align_water() -> void:
	if not _enabled("materials"): return
	var geometry := get_node_or_null("EnvironmentGeometry")
	if not geometry: return
	for node in geometry.get_children():
		if node is MeshInstance3D and node.material_override is ShaderMaterial and node.material_override.shader.resource_path.ends_with("water.gdshader"):
			var roof := _surface_roof(geometry,node.global_position,node)
			if roof > 0.05: node.global_position.y = roof + 0.0015

func _surface_roof(node: Node, point: Vector3, water: Node) -> float:
	var result := -INF
	if node is MeshInstance3D and node!=water and node.is_visible_in_tree() and node.mesh:
		var box: AABB = node.global_transform*node.mesh.get_aabb()
		if point.x>box.position.x and point.x<box.end.x and point.z>box.position.z and point.z<box.end.z and box.end.y>0.05 and box.end.y<0.25:
			result = box.end.y
	for child in node.get_children(): result=maxf(result,_surface_roof(child,point,water))
	return result

func _puddle_mesh() -> ArrayMesh:
	if not _enabled("materials"): return super._puddle_mesh()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var phase := rng.randf_range(0,TAU)
	var rim: Array[Vector3] = []
	for i in range(32):
		var a := TAU*i/32.0
		var r := 0.82+0.12*sin(a*3+phase)+0.09*cos(a*5-phase)
		rim.append(Vector3(cos(a)*0.36*r,0,sin(a)*0.38*r))
	for i in range(32):
		for point in [Vector3.ZERO,rim[i],rim[(i+1)%32]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(point.x/0.8+0.5,point.z/0.8+0.5))
			st.set_color(Color(1,1,1) if point==Vector3.ZERO else Color(0,0,0))
			st.add_vertex(point)
	st.generate_tangents()
	return st.commit()

func _tint_materials(node: Node, tint: Color) -> void:
	if not _enabled("materials"):
		super._tint_materials(node,tint)

func _vary_tint(node: Node, amount: float) -> void:
	if not _enabled("materials"):
		super._vary_tint(node,amount)
		return
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var shader_shared := node.get_surface_override_material(surface) as ShaderMaterial
			if shader_shared and shader_shared.shader.resource_path.ends_with("stone.gdshader"):
				var shader_unique := shader_shared.duplicate() as ShaderMaterial
				var tint: Color = shader_shared.get_meta("base_tint",Color(0.95,0.97,1.0))
				shader_unique.set_meta("base_tint",tint*amount)
				shader_unique.set_shader_parameter("base_tint",tint*amount)
				node.set_surface_override_material(surface,shader_unique)
				continue
			var shared := node.get_surface_override_material(surface) as BaseMaterial3D
			if shared:
				var unique := shared.duplicate() as BaseMaterial3D
				unique.albedo_color *= Color(amount,amount,amount)
				node.set_surface_override_material(surface,unique)
	for child in node.get_children(): _vary_tint(child,amount)

func _place_pilot(path: String, where: Vector3, size: float, height_based: bool) -> Node3D:
	var chosen := path
	if _enabled("assets") and path.contains("fern") and ResourceLoader.exists("res://quality_assets/fern_repaired.glb"):
		chosen = "res://quality_assets/fern_repaired.glb"
	elif _enabled("assets") and path.contains("shrub") and not path.contains("lod2") and ResourceLoader.exists("res://quality_assets/shrub_repaired.glb"):
		chosen = "res://quality_assets/shrub_repaired.glb"
	elif _enabled("assets") and path.contains("stone_plain") and ResourceLoader.exists("res://quality_assets/stone_plain_repaired.glb"):
		chosen = "res://quality_assets/stone_plain_repaired.glb"
	var holder := super._place_pilot(chosen,where,size,height_based)
	if holder and _enabled("materials"):
		_configure_materials(holder,chosen)
	if holder and chosen != path and _enabled("assets") and (path.contains("fern") or path.contains("shrub")):
		var original_path := "res://meshy_assets/fern_lod1.glb" if path.contains("fern") else "res://meshy_assets/shrub_lod1.glb"
		var packed := load(original_path) as PackedScene
		var mid := packed.instantiate() as Node3D
		var high := holder.get_child(0) as Node3D
		mid.transform = high.transform
		holder.add_child(mid)
		if _enabled("materials"): _configure_materials(mid,original_path)
		mid.visible = false
		candidate_bounds_set = false
		_collect_candidate_bounds(high,high)
		quality_lods.append({"high":high,"mid":mid,"bounds":candidate_bounds,"using_high":true})
	return holder

func _process(delta: float) -> void:
	lod_elapsed += delta
	if lod_elapsed > 0.2:
		lod_elapsed = 0.0
		_update_quality_lods()

func _update_quality_lods() -> void:
	if not review_camera: return
	for item in quality_lods:
		var high: Node3D = item.high
		var bounds: AABB = item.bounds
		var minimum := Vector2(INF,INF)
		var maximum := Vector2(-INF,-INF)
		for i in range(8):
			var projected := review_camera.unproject_position(high.global_transform*bounds.get_endpoint(i))
			minimum = minimum.min(projected)
			maximum = maximum.max(projected)
		var span := maxf(maximum.x-minimum.x,maximum.y-minimum.y)
		var use_high: bool = item.using_high
		if span > 140.0: use_high = true
		elif span < 110.0: use_high = false
		high.visible = use_high
		item.mid.visible = not use_high
		item.using_high = use_high

func _configure_materials(node: Node, path: String) -> void:
	if node is MeshInstance3D and node.mesh:
		node.lod_bias = 100.0
		for surface in range(node.mesh.get_surface_count()):
			var original := node.get_active_material(surface) as StandardMaterial3D
			if not original: continue
			var key := path + ":" + str(original.get_rid())
			if not quality_materials.has(key):
				var plant := path.contains("tree") or path.contains("shrub") or path.contains("fern") or path.contains("grass") or path.contains("flowers") or path.contains("fab_candidates/03") or path.contains("bramble")
				if plant:
					var foliage := ShaderMaterial.new()
					foliage.shader = load("res://quality_round/foliage.gdshader")
					foliage.set_shader_parameter("base_map",original.albedo_texture)
					foliage.set_shader_parameter("normal_map",original.normal_texture)
					foliage.set_shader_parameter("orm_map",original.roughness_texture)
					var tint := Color(0.85,0.88,0.82)
					if path.contains("shrub"): tint = Color(0.66,0.76,0.64)
					elif path.contains("tree"): tint = Color(0.74,0.82,0.72)
					elif path.contains("fern"): tint = Color(0.82,0.92,0.76)
					foliage.set_shader_parameter("species_tint",tint)
					var ao_path := path.get_basename() + "_ao.png"
					if ResourceLoader.exists(ao_path):
						foliage.set_shader_parameter("has_ao",true)
						foliage.set_shader_parameter("ao_map",load(ao_path))
					quality_materials[key] = foliage
				else:
					var stone := ShaderMaterial.new()
					stone.shader = load("res://quality_round/stone.gdshader")
					stone.set_shader_parameter("base_map",original.albedo_texture)
					stone.set_shader_parameter("normal_map",original.normal_texture)
					stone.set_shader_parameter("orm_map",original.roughness_texture)
					stone.set_shader_parameter("normal_depth",0.45 if path.contains("repaired") else 0.75)
					stone.set_shader_parameter("base_tint",Color(0.95,0.97,1.0))
					stone.set_meta("base_tint",Color(0.95,0.97,1.0))
					quality_materials[key] = stone
			node.set_surface_override_material(surface,quality_materials[key])
	for child in node.get_children():
		_configure_materials(child,path)

func _make_vegetation() -> void:
	if not _enabled("layout"):
		super._make_vegetation()
		return
	_make_imported_trees()
	_make_3d_shrubs()

func _make_3d_shrubs() -> void:
	if not _enabled("layout"):
		super._make_3d_shrubs()
		return
	var anchors := [Vector2(-7.5,-1.7),Vector2(-3.7,-1.7),Vector2(0.4,-1.7),Vector2(4.5,-1.7),Vector2(-6,1.7),Vector2(-1.4,1.7),Vector2(3.8,1.7),Vector2(7.2,1.7),Vector2(-8,5.9),Vector2(-3.7,5.8),Vector2(1,5.9),Vector2(5.8,5.9),Vector2(9.5,5.6),Vector2(-6.8,-6.0),Vector2(-1.5,-6.0),Vector2(3.5,-6.0)]
	for i in range(anchors.size()):
		var a: Vector2 = anchors[i]
		var size := rng.randf_range(1.0,1.6)
		var path := "res://meshy_assets/pilot_shrub.glb" if i % 3 == 0 else "res://meshy_assets/shrub_lod1.glb"
		_place_pilot(path,Vector3(a.x,0.02,a.y),size,false)
		if i % 2 == 0:
			_place_pilot("res://meshy_assets/fern_lod1.glb",Vector3(a.x+0.65,0.02,a.y+0.14),1.25,false)
		if i % 3 == 1:
			_place_pilot("res://fab_candidates/03/with_tangents.glb",Vector3(a.x-0.6,0.02,a.y-0.1),1.1,false)
		if i % 4 == 1:
			_place_pilot("res://fab_candidates/07/converted/bramble.glb",Vector3(a.x+0.5,0.02,a.y+0.25),1.4,false)
	for spec in [["shrub_lod2",45]]:
		_scatter_pilot("res://meshy_assets/"+spec[0]+".glb",spec[1])
	_clean_plants(anchors)

func _clean_plants(anchors: Array) -> void:
	var plant_builder = load("res://quality_round/plants.gd")
	var grass_transforms: Array[Transform3D] = []
	var flower_transforms: Array = [[],[],[]]
	var centers := anchors.duplicate()
	for x in range(-11,12,3):
		centers.append(Vector2(x,7.5))
		centers.append(Vector2(x,-7.2))
	for center: Vector2 in centers:
		for i in range(45):
			var x := center.x+rng.randfn(0,0.72)
			var z := center.y+rng.randfn(0,0.35)
			if _near_path(x,z)<1.03: continue
			var scale := rng.randf_range(0.75,1.35)
			var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale)
			grass_transforms.append(Transform3D(basis,Vector3(x,0.0,z)))
		for i in range(20):
			var x := center.x+rng.randfn(0,0.75)
			var z := center.y+rng.randfn(0,0.33)
			if _near_path(x,z)<1.04: continue
			var scale := rng.randf_range(0.65,1.15)
			var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale)
			var kind := 0 if i%5<3 else (1 if i%5==3 else 2)
			flower_transforms[kind].append(Transform3D(basis,Vector3(x,0.0,z)))
	var material: StandardMaterial3D = plant_builder.material()
	_scatter(plant_builder.grass(),material,grass_transforms)
	var palette := [Color(0.95,0.93,0.81),Color(0.88,0.65,0.12),Color(0.75,0.35,0.48)]
	for kind in range(3):
		var transforms: Array[Transform3D] = []
		transforms.assign(flower_transforms[kind])
		_scatter(plant_builder.flower(palette[kind]),material,transforms)

func _scatter_pilot(path: String, count: int) -> void:
	var before := get_child_count()
	super._scatter_pilot(path,count)
	if not _enabled("materials"): return
	for i in range(before,get_child_count()):
		var node := get_child(i)
		if node is MultiMeshInstance3D:
			var proxy := MeshInstance3D.new()
			proxy.mesh = node.multimesh.mesh
			_configure_materials(proxy,path)
			if proxy.mesh.get_surface_count()>0:
				node.material_override = proxy.get_surface_override_material(0)
			proxy.free()

func _adjust_composition() -> void:
	if not _enabled("layout"):
		super._adjust_composition()
		return
	var geometry := Node3D.new()
	geometry.name = "EnvironmentGeometry"
	add_child(geometry)
	for child in get_children():
		if child == geometry or child is Camera3D or child is DirectionalLight3D or child is WorldEnvironment or child is ReflectionProbe: continue
		if child is MultiMeshInstance3D:
			for i in range(child.multimesh.instance_count):
				var t: Transform3D = child.multimesh.get_instance_transform(i)
				t.origin *= Vector3(0.85,1.0,1.2)
				child.multimesh.set_instance_transform(i,t)
		elif child is Node3D:
			child.position *= Vector3(0.85,1.0,1.2)
			if child is MeshInstance3D: child.scale *= Vector3(0.85,1.0,1.2)
		child.reparent(geometry,false)
