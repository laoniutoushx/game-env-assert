extends "res://golden_scene.gd"

var afternoon_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://afternoon_v2/settings.json"))
var cinema := true
var local_fog: FogVolume
var camera_attributes: CameraAttributesPractical
var material_audit: Array[Dictionary] = []
var scanned_replacements := 0
var lighting_cache: Node3D

func _is_baseline() -> bool:
	return _option("style","afternoon")=="baseline"

func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	if not _is_baseline():
		atmosphere_settings=afternoon_config.duplicate()
		cinema=_option("presentation","cinema")!="clear"
		_grade()
		_material_finish(get_node("EnvironmentGeometry"))
		load("res://afternoon_v2/refine.gd").prepare(self)
		load("res://afternoon_v2/details.gd").apply(self)
		load("res://afternoon_v2/refine.gd").layout(self)
		_load_lighting()
		_create_atmosphere()
		_shadow_lod_bias(get_node("EnvironmentGeometry"))
		load("res://afternoon_v2/refine.gd").palette(self)
		_presentation()
	_version_title()
	DirAccess.make_dir_recursive_absolute("res://afternoon_v2/captures")
	print("AFTERNOON_READY ",JSON.stringify(_metadata()))
	if "--export-lighting" in OS.get_cmdline_user_args():
		load("res://afternoon_v2/export_lighting.gd").run.call_deferred(self)
	if "--coverage-v2" in OS.get_cmdline_user_args():
		load("res://afternoon_v2/coverage.gd").run.call_deferred(self)

func _grade() -> void:
	super._grade()
	if _is_baseline():return
	for node in get_children():
		if node is DirectionalLight3D:
			if not golden_enabled:continue
			node.light_color=Color(afternoon_config.sun_color)
			node.light_energy=afternoon_config.sun_energy
			node.rotation_degrees=Vector3(afternoon_config.sun_pitch,afternoon_config.sun_yaw,0)
			node.light_angular_distance=0.6
			node.shadow_blur=1.5
			node.light_volumetric_fog_energy=2.0
			node.light_bake_mode=Light3D.BAKE_DYNAMIC
		elif node is WorldEnvironment:
			var e: Environment=node.environment
			e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color=Color("8fb4d9")
			e.ambient_light_energy=afternoon_config.ambient_energy
			e.ambient_light_sky_contribution=0.35
			e.tonemap_mode=Environment.TONE_MAPPER_AGX if _option("tonemap","aces")=="agx" else Environment.TONE_MAPPER_ACES
			e.tonemap_exposure=afternoon_config.exposure
			e.adjustment_saturation=1.10;e.adjustment_contrast=1.02
			e.glow_enabled=true;e.glow_intensity=0.25;e.glow_hdr_threshold=1.25
			e.ssao_radius=0.38;e.ssao_intensity=0.75;e.ssao_power=1.1
			e.ssao_light_affect=0.12
			if e.sky and e.sky.sky_material is ProceduralSkyMaterial:
				var sky := e.sky.sky_material as ProceduralSkyMaterial
				sky.sky_top_color=Color(0.30,0.46,0.66)
				sky.sky_horizon_color=Color(0.66,0.75,0.85)
				sky.ground_horizon_color=Color(0.38,0.40,0.35)
	for material in quality_materials.values():
		if material is ShaderMaterial and material.shader.resource_path.ends_with("foliage.gdshader"):
			material.shader=load("res://afternoon_v2/foliage.gdshader")
			material.set_shader_parameter("species_tint",Color(1.0,1.0,0.98))
			material.set_shader_parameter("warm_leaf_tint",Vector3.ONE)

func _configure_materials(node: Node,path: String) -> void:
	# Save importer PBR information before the inherited material conversion.
	var originals: Array[StandardMaterial3D] = []
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):originals.append(node.get_active_material(i) as StandardMaterial3D)
	super._configure_materials(node,path)
	if _is_baseline():return
	if node is MeshInstance3D:
		for i in range(originals.size()):
			var source := originals[i]
			var m := node.get_active_material(i) as ShaderMaterial
			if not source or not m:continue
			if m.shader.resource_path.ends_with("foliage.gdshader"):
				m.shader=load("res://afternoon_v2/foliage.gdshader")
				m.set_shader_parameter("source_tint",source.albedo_color)
				var valid_rough := source.roughness_texture!=null and source.roughness_texture!=source.normal_texture
				m.set_shader_parameter("has_orm",valid_rough)
				m.set_shader_parameter("roughness_factor",source.roughness)
				m.set_shader_parameter("normal_strength",source.normal_scale if source.normal_enabled else 0.0)
				if source.ao_enabled and source.ao_texture:
					m.set_shader_parameter("ao_map",source.ao_texture);m.set_shader_parameter("has_ao",true)
				elif valid_rough:
					var name_lower: String=source.roughness_texture.resource_path.to_lower()
					m.set_shader_parameter("orm_has_ao","arm" in name_lower or "orm" in name_lower or "ort" in name_lower)
				var bark := "bark" in source.resource_name.to_lower() or "trunk" in source.resource_name.to_lower() or "branch" in source.resource_name.to_lower()
				m.set_shader_parameter("leaf_surface",0.0 if bark else 1.0)
				m.set_shader_parameter("species_tint",Color(1,1,0.98))
				material_audit.append({"source":path,"material":source.resource_name,"normal":source.normal_enabled,"roughness":source.roughness,"ao":source.ao_enabled,"bark":bark})

func _place_pilot(path: String,where: Vector3,size: float,height_based: bool) -> Node3D:
	if _is_baseline() or not ("fern" in path or "shrub" in path):return super._place_pilot(path,where,size,height_based)
	var source_path := "res://fern_02/fern_02_prepared.gltf" if "fern" in path else "res://shrub_02/shrub_02_prepared.gltf"
	var source := (load(source_path) as PackedScene).instantiate() as Node3D
	var choices: Array[MeshInstance3D] = []
	_collect_scan_parts(source,choices)
	var part := choices[scanned_replacements%choices.size()].duplicate() as MeshInstance3D
	var bounds: AABB=part.transform*part.mesh.get_aabb()
	part.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var holder := Node3D.new();holder.name="ScannedPlant_%02d"%scanned_replacements
	holder.add_child(part)
	var dimension := bounds.size.y if height_based else maxf(bounds.size.x,bounds.size.z)
	holder.scale=Vector3.ONE*size/maxf(dimension,0.01);holder.position=where
	holder.rotation.y=rng.randf_range(0,TAU)
	_configure_materials(holder,source_path);add_child(holder)
	part.lod_bias=1.0
	source.free();scanned_replacements+=1
	return holder

func _collect_scan_parts(node: Node,parts: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh:parts.append(node)
	for child in node.get_children():_collect_scan_parts(child,parts)

func _material_finish(node: Node) -> void:
	if node is GeometryInstance3D:node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
	if node is MeshInstance3D:
		var m := node.material_override as ShaderMaterial
		if m and m.shader.resource_path.ends_with("road.gdshader"):
			m.shader=load("res://afternoon_v2/road.gdshader")
			m.set_shader_parameter("road_gain",1.02)
			m.set_shader_parameter("tint",Color(0.90,0.93,0.98))
			m.set_shader_parameter("reflection_energy",1.0)
		elif m and m.shader.resource_path.ends_with("ground.gdshader"):
			m.shader=load("res://afternoon_v2/ground.gdshader")
	for child in node.get_children():_material_finish(child)

func _create_atmosphere() -> void:
	if _option("foglook","shafts")!="old":
		_create_shafts()
		return
	RenderingServer.environment_set_volumetric_fog_volume_size(96,64)
	for node in get_children():
		if node is WorldEnvironment:
			var e: Environment=node.environment
			e.volumetric_fog_enabled=true;e.volumetric_fog_density=0.0
			e.volumetric_fog_length=42.0
			e.volumetric_fog_anisotropy=0.45
			e.volumetric_fog_temporal_reprojection_enabled=true
			e.volumetric_fog_temporal_reprojection_amount=0.85
	local_fog=FogVolume.new();local_fog.name="AfternoonAir"
	local_fog.size=Vector3(36,9,27);local_fog.position=Vector3(-2,3,0)
	var fog_material := ShaderMaterial.new();fog_material.shader=load("res://afternoon_v2/fog.gdshader")
	fog_material.set_shader_parameter("density",0.0025)
	local_fog.material=fog_material;add_child(local_fog)
	var shafts := FogVolume.new();shafts.name="CanopyLightAir"
	shafts.size=Vector3(12,7,18);shafts.position=Vector3(-10,2.5,-3)
	var shaft_material := ShaderMaterial.new();shaft_material.shader=load("res://afternoon_v2/fog.gdshader")
	shaft_material.set_shader_parameter("density",0.010)
	shafts.material=shaft_material;add_child(shafts)
	camera_attributes=CameraAttributesPractical.new();review_camera.attributes=camera_attributes
	camera_attributes.dof_blur_amount=afternoon_config.dof_amount

func _create_shafts() -> void:
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_LOW,false)
	RenderingServer.environment_set_volumetric_fog_volume_size(128,64)
	for node in get_children():
		if node is WorldEnvironment:
			var e: Environment=node.environment
			e.volumetric_fog_enabled=true;e.volumetric_fog_density=0.0
			e.volumetric_fog_length=60.0;e.volumetric_fog_detail_spread=1.0
			e.volumetric_fog_anisotropy=0.15
			e.volumetric_fog_ambient_inject=0.0;e.volumetric_fog_gi_inject=0.0
			e.volumetric_fog_temporal_reprojection_enabled=true
			e.volumetric_fog_temporal_reprojection_amount=0.80
		elif node is DirectionalLight3D:node.light_volumetric_fog_energy=18.0
	local_fog=FogVolume.new();local_fog.name="AfternoonAir"
	local_fog.size=Vector3(17,3.2,16);local_fog.position=Vector3(-7.5,1.8,-4)
	var medium := ShaderMaterial.new();medium.shader=load("res://afternoon_v2/shaft_fog.gdshader")
	medium.set_shader_parameter("density",0.0004)
	local_fog.material=medium;add_child(local_fog)
	var direction := Vector3(0.6,-0.53,0.6).normalized()
	var endings := [Vector3(-8.0,0.2,-4.08),Vector3(-5.0,0.2,0.0),Vector3(-2.0,0.2,-4.08)]
	var ray_origins := PackedVector3Array()
	for i in range(endings.size()):
		var length := 12.0
		var origin: Vector3=endings[i]-direction*length
		ray_origins.append(origin)
		var volume := FogVolume.new();volume.name="SunShaft_%d"%i
		volume.position=origin+direction*length*0.5
		volume.size=direction.abs()*length+Vector3.ONE*2.2
		var material := ShaderMaterial.new();material.shader=load("res://afternoon_v2/sun_shaft.gdshader")
		material.set_shader_parameter("ray_origin",origin);material.set_shader_parameter("ray_direction",direction)
		material.set_shader_parameter("ray_length",length);material.set_shader_parameter("density",0.04)
		volume.material=material;add_child(volume)
	for material in quality_materials.values():
		if material is ShaderMaterial and material.shader.resource_path.ends_with("foliage.gdshader"):
			material.set_shader_parameter("canopy_openings",_option("canopy_openings","on")=="on")
			material.set_shader_parameter("lightpath_origins",ray_origins)
			material.set_shader_parameter("lightpath_direction",direction)
	var candidates := forest_lods.duplicate()
	candidates.sort_custom(func(a: Dictionary,b: Dictionary):return a.mid.global_position.distance_squared_to(Vector3(-10,0,-5))<b.mid.global_position.distance_squared_to(Vector3(-10,0,-5)))
	for i in range(mini(2,candidates.size())):
		var item: Dictionary=candidates[i]
		var holder: Node3D=item.mid.get_parent()
		var old := holder.get_node_or_null("ShadowLOD") as Node3D
		if old:
			var proxy := item.mid.duplicate() as Node3D
			proxy.transform=old.transform;old.free();proxy.name="ShadowLOD"
			proxy.visible=true;_shadow_mode(proxy,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
			holder.add_child(proxy)
	camera_attributes=CameraAttributesPractical.new();review_camera.attributes=camera_attributes
	camera_attributes.dof_blur_amount=afternoon_config.dof_amount
	print("SHAFTS_CONFIG length=60 grid=128x64 anisotropy=.15 energy=18 density_shaped_rays=3 crown_proxies=2")

func _shadow_lod_bias(node: Node) -> void:
	# Imported shadow meshes contain generated LODs; the inherited bias=100 disabled them.
	# Visible geometry retains its explicit high/mid/low selection.
	if node is MeshInstance3D and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		node.lod_bias=0.5
	for child in node.get_children():_shadow_lod_bias(child)

func _presentation() -> void:
	if is_instance_valid(local_fog):local_fog.visible=not _cut("fog")
	var shafts := get_node_or_null("CanopyLightAir") as FogVolume
	if shafts:shafts.visible=not _cut("fog")
	for child in get_children():
		if child is SpotLight3D and str(child.name).begins_with("CanopyShaft"):child.visible=not _cut("fog")
		if child is FogVolume and str(child.name).begins_with("SunShaft_"):child.visible=not _cut("fog")
	if camera_attributes:
		camera_attributes.dof_blur_far_enabled=cinema and not _cut("dof")
		camera_attributes.dof_blur_near_enabled=cinema and not _cut("dof")
	_focus()

func _focus() -> void:
	if not camera_attributes or not review_camera:return
	var distance := review_camera.global_position.distance_to(camera_target)
	camera_attributes.dof_blur_far_distance=distance+3.5
	camera_attributes.dof_blur_far_transition=6.0
	camera_attributes.dof_blur_near_distance=maxf(0.1,distance-5.0)
	camera_attributes.dof_blur_near_transition=4.0

func _process(delta: float) -> void:
	super._process(delta);_focus()

func _load_lighting() -> void:
	if _cut("lightmap") or "--export-lighting" in OS.get_cmdline_user_args():return
	if not FileAccess.file_exists("res://afternoon_v2/assets/bake.json"):return
	var bake: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://afternoon_v2/assets/bake.json"))
	if bake.get("look_version",0)==2 and bake.get("source_sha256",{})!=load("res://afternoon_v2/cache.gd").fingerprint():
		push_error("AFTERNOON v2 baked cache is stale; export and rebake required")
		return
	var baked_scene: String=bake.get("scene","res://afternoon_v2/assets/static_lighting.tscn")
	if not ResourceLoader.exists(baked_scene):return
	lighting_cache=(load(baked_scene) as PackedScene).instantiate() as Node3D
	for child in lighting_cache.get_children():
		if child is Light3D or child is WorldEnvironment:child.free()
	add_child(lighting_cache)
	_material_finish(lighting_cache)
	var cache_audit: Array = []
	for child in lighting_cache.get_node("StaticMeshes").get_children():
		var original := get_node_or_null(NodePath(child.get_meta("source_path",""))) as GeometryInstance3D
		if original:original.visible=false
		else:push_error("Baked geometry source is missing: "+str(child.get_meta("source_path","")))
		cache_audit.append({"source":child.get_meta("source_path",""),"found":original!=null,"position":str(child.global_position),"center":str((child.global_transform*child.mesh.get_aabb()).get_center()),"material":str(child.get_active_material(0))})
	var audit_file := FileAccess.open("res://afternoon_v2/assets/runtime_cache_audit.json",FileAccess.WRITE)
	audit_file.store_string(JSON.stringify(cache_audit,"  "))

func _version_title() -> void:
	get_window().title="遗迹环境 | AFTERNOON v2 | "+("GOLDEN baseline" if _is_baseline() else ("电影展示" if cinema else "清晰检查"))

func _add_camera_help() -> void:
	super._add_camera_help()
	for child in get_children():
		if child is CanvasLayer:
			for label in child.get_children():
				if label is Label:label.text="AFTERNOON v2 | F8 cinema / clear\n"+label.text.replace("GOLDEN v1 | F7 sunlight A/B","F7 sunlight A/B")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		cinema=not cinema;_presentation();_version_title();return
	super._unhandled_input(event)

func _save_still(tag: String,view: String) -> int:
	_ensure_visible()
	RenderingServer.force_draw(false)
	var path := "res://afternoon_v2/captures/"+tag+"_"+view
	var err := get_viewport().get_texture().get_image().save_png(path+".png")
	var f := FileAccess.open(path+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(_metadata().merged({"view":view,"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width()}),"  "))
	print("AFTERNOON_CAPTURE_OK ",path);return err

func _ensure_visible() -> void:
	if get_window().mode==Window.MODE_MINIMIZED:get_window().mode=Window.MODE_WINDOWED
	if not get_window().visible:get_window().show()

func _quality_capture() -> void:
	await get_tree().create_timer(8.0).timeout
	var view := _option("view","side" if "--quality-side" in OS.get_cmdline_user_args() else "top")
	var err := _save_still(_tag(),view)
	await _finish(0 if err==OK else 1)

func _pose_detail(view: String) -> void:
	super._pose_detail("water" if view=="plants" else view)
	if view=="water":
		camera_target=Vector3(wet_spots[1].x,0.13,wet_spots[1].y)
		orbit_yaw=0.2;orbit_pitch=deg_to_rad(65);_set_width(2.5)

func _batch_stills() -> void:
	await get_tree().create_timer(8).timeout
	for view in ["top","left","side","low_side","water","portal","plants"]:
		camera_target=Vector3(0,0,0.8);orbit_yaw=0;orbit_pitch=deg_to_rad(55);_set_width(24)
		if view in ["side","low_side"]:orbit_yaw=0.65;orbit_pitch=deg_to_rad(40 if view=="side" else 32);_set_width(25)
		else:_pose_detail(view)
		_process(0.21)
		await get_tree().create_timer(0.7).timeout
		if _save_still(_tag(),view)!=OK:await _finish(1);return
	await _finish(0)

func _metadata() -> Dictionary:
	return {"version":"AFTERNOON v2","style":_option("style","afternoon"),"cinema":cinema,"output":str(get_viewport().get_texture().get_size()),"internal_scale":get_viewport().scaling_3d_scale,"scanned_replacements":scanned_replacements,"lightmap_loaded":is_instance_valid(lighting_cache),"settings":afternoon_config,"cut":_option("cut",atmosphere_settings.get("cut","")),"material_audit_count":material_audit.size(),"refined_slabs":get_meta("refined_slabs",0),"tonemap":_option("tonemap","aces"),"dof_enabled":camera_attributes!=null and camera_attributes.dof_blur_far_enabled}

func _quality_benchmark() -> void:
	await load("res://afternoon_v2/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://afternoon_v2/audit.gd").motion(self)

func _smoke() -> void:
	await load("res://afternoon_v2/audit.gd").smoke(self)
