extends "res://atmosphere_scene.gd"

var pollen: GPUParticles3D
var pass_override := ""
var shadow_optimized := false
var tag_override := ""

func _tag() -> String:
	return tag_override if not tag_override.is_empty() else super._tag()

func _setup_shadow_lods() -> void:
	super._setup_shadow_lods()
	if _pass()!="baseline":_optimize_shadows()

func _optimize_shadows() -> void:
	if shadow_optimized:return
	var count := 0
	for item in quality_lods:
		var path: String=item.mid.scene_file_path
		var low_path := path.replace("_lod1.glb","_lod2.glb")
		if low_path==path or not ResourceLoader.exists(low_path):continue
		var holder: Node3D=item.mid.get_parent()
		var old := holder.get_node_or_null("ShadowLOD") as Node3D
		if not old:continue
		var low := (load(low_path) as PackedScene).instantiate() as Node3D
		low.transform=old.transform
		_configure_materials(low,low_path);_shadow_mode(low,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		old.free();low.name="ShadowLOD";holder.add_child(low);count+=1
	shadow_optimized=true
	print("RADIANCE_SHADOW_PROXY_OPTIMIZED ",count)

func _pass() -> String:
	return pass_override if not pass_override.is_empty() else _option("pass","final")

func _feature(feature: String) -> bool:
	if _cut(feature):return false
	var rank := ["baseline","light","ground","wet","final"].find(_pass())
	match feature:
		"grade":return rank>=1
		"surface":return rank>=2
		"wet","portal","probe":return rank>=3
		"pollen":return rank>=4
	return false

func _initialize_atmosphere() -> void:
	if "--quality-stages" in OS.get_cmdline_user_args() or "--quality-coverage" in OS.get_cmdline_user_args():pass_override="baseline"
	super._initialize_atmosphere()
	atmosphere_settings=JSON.parse_string(FileAccess.get_file_as_string("res://radiance/settings.json"))
	if _feature("grade"):_grade()
	if _feature("surface"):_surfaces()
	if _feature("wet"):_water()
	if _feature("portal"):_portal()
	if _feature("probe"):_reflection()
	if _feature("pollen"):_pollen()
	print("RADIANCE_READY pass=",_pass()," cuts=",_option("cut",atmosphere_settings.cut))
	if "--quality-batch" in OS.get_cmdline_user_args():_batch_stills.call_deferred()
	if "--quality-stages" in OS.get_cmdline_user_args():_batch_stages.call_deferred()
	if "--quality-coverage" in OS.get_cmdline_user_args():_batch_coverage.call_deferred()
	if "--bake-reflection" in OS.get_cmdline_user_args():_bake_reflection.call_deferred()

func _grade() -> void:
	_optimize_shadows()
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM,true,0.5,1,50.0,300.0)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	for node in get_children():
		if node is DirectionalLight3D:
			node.light_color=Color("ffe0ae");node.light_energy=1.6
			node.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		elif node is WorldEnvironment:
			var e: Environment=node.environment
			e.ambient_light_energy=0.44;e.tonemap_exposure=1.0
			e.glow_hdr_threshold=1.0;e.glow_intensity=0.30;e.glow_bloom=0
	for material in quality_materials.values():
		if material is ShaderMaterial and material.shader.resource_path.ends_with("foliage.gdshader"):
			material.shader=load("res://radiance/foliage.gdshader")
			material.set_shader_parameter("warm_leaf_tint",Vector3(1.03,1.02,0.96))

func _surfaces() -> void:
	var geometry := get_node("EnvironmentGeometry")
	for node in geometry.get_children():
		if node is MeshInstance3D and str(node.name).contains("Ground"):
			var m := node.material_override as ShaderMaterial
			if m:
				m.shader=load("res://radiance/ground.gdshader")
				m.set_shader_parameter("road_distance_map",load("res://radiance/textures/road_distance.png"))
		elif node is MeshInstance3D and str(node.name).begins_with("RoadSlab_"):
			var m := node.material_override as ShaderMaterial
			if m:
				m.shader=load("res://radiance/road.gdshader")
				m.set_shader_parameter("road_gain",1.06)
	# Move existing foreground trees outward; no additional instances or transparency.
	for node in geometry.get_children():
		if node.get_class()=="Node3D" and node.position.z>7.0:
			var is_tree := false
			for item in forest_lods:
				if item.mid.get_parent()==node:is_tree=true
			# Meshy foreground trees also have a height above 2.5 m.
			candidate_bounds_set=false;_collect_candidate_bounds(node,node)
			if candidate_bounds_set and candidate_bounds.size.y*node.scale.y>2.5:is_tree=true
			if is_tree:_move_plant(node,Vector3(0,0,2.0))
	# Clear actual plant volumes around the device, and move side trees outward.
	var portal_clearance := AABB(Vector3(7.65,-0.1,-5.85),Vector3(3.1,3.6,2.5))
	for node in geometry.get_children():
		if node is Node3D and not node is MultiMeshInstance3D and _contains_foliage(node):
			var is_tree := false
			candidate_bounds_set=false;_collect_candidate_bounds(node,node)
			if candidate_bounds_set and candidate_bounds.size.y*node.scale.y>2.5:is_tree=true
			if is_tree and absf(node.position.x)>12.5:_move_plant(node,Vector3(signf(node.position.x)*1.6,0,0))
			if not is_tree:
				var target := _plant_clearance(node.position)
				_move_plant(node,target-node.position)
			candidate_bounds_set=false;_collect_candidate_bounds(node,node)
			if candidate_bounds_set:
				var bounds: AABB=node.transform*candidate_bounds
				if bounds.intersects(portal_clearance):_move_plant(node,Vector3(0,0,portal_clearance.position.z-bounds.end.z-0.35))
		elif node is MultiMeshInstance3D:
			for i in range(node.multimesh.instance_count):
				var t: Transform3D=node.multimesh.get_instance_transform(i)
				var previous := t.origin
				t.origin=_plant_clearance(t.origin)
				t.origin.y+=load("res://atmosphere/terrain.gd").height(t.origin.x,t.origin.z)-load("res://atmosphere/terrain.gd").height(previous.x,previous.z)
				var bounds: AABB=t*node.multimesh.mesh.get_aabb()
				if bounds.intersects(portal_clearance):
					var old := t.origin
					t.origin.z+=portal_clearance.position.z-bounds.end.z-0.35
					t.origin.y+=load("res://atmosphere/terrain.gd").height(t.origin.x,t.origin.z)-load("res://atmosphere/terrain.gd").height(old.x,old.z)
				node.multimesh.set_instance_transform(i,t)

func _plant_clearance(point: Vector3) -> Vector3:
	if absf(point.x)<9 and absf(point.z)>0.8 and absf(point.z)<2.6:
		point.z=signf(point.z)*clampf(absf(point.z),1.5,1.9)
	elif absf(point.z)>4.6 and absf(point.z)<7.0:
		point.z+=signf(point.z)*0.5
	return point

func _portal_obstructions() -> int:
	var zone := AABB(Vector3(7.65,-0.1,-5.85),Vector3(3.1,3.6,2.5))
	var count := 0
	for node in get_node("EnvironmentGeometry").get_children():
		if node is MultiMeshInstance3D:
			for i in range(node.multimesh.instance_count):
				var bounds: AABB=node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb()
				if bounds.intersects(zone):count+=1
		elif node is Node3D and _contains_foliage(node):
			candidate_bounds_set=false;_collect_candidate_bounds(node,node)
			if candidate_bounds_set and (node.transform*candidate_bounds).intersects(zone):count+=1
	return count

func _contains_foliage(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var m := node.get_active_material(i) as ShaderMaterial
			if m and m.shader.resource_path.ends_with("foliage.gdshader"):return true
	for child in node.get_children():
		if _contains_foliage(child):return true
	return false

func _move_plant(node: Node3D,offset: Vector3) -> void:
	var old := node.position
	node.position+=offset
	node.position.y+=load("res://atmosphere/terrain.gd").height(node.position.x,node.position.z)-load("res://atmosphere/terrain.gd").height(old.x,old.z)

func _water() -> void:
	var geometry := get_node("EnvironmentGeometry")
	wet_spots=PackedVector4Array()
	for node in geometry.get_children():
		if node is MeshInstance3D and node.material_override is ShaderMaterial and node.material_override.shader.resource_path.ends_with("water.gdshader"):
			wet_spots.append(Vector4(node.global_position.x,node.global_position.z,1,0))
	while wet_spots.size()<4:wet_spots.append(Vector4(1000,1000,0,0))
	for node in geometry.get_children():
		if not node is MeshInstance3D:continue
		var m := node.material_override as ShaderMaterial
		if not m:continue
		if m.shader.resource_path.ends_with("water.gdshader"):
			node.visible=false;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif m.shader.resource_path.ends_with("road.gdshader"):
			if m.shader.resource_path!="res://radiance/road.gdshader":
				m.shader=load("res://radiance/road.gdshader");m.set_shader_parameter("road_gain",1.0)
			node.layers=3
			m.set_shader_parameter("water_enabled",1.0)
			var box: AABB=(node.global_transform*node.get_aabb()).grow(0.52)
			var local_spots := PackedVector4Array()
			var active := false
			for spot in wet_spots:
				if spot.z>0.5 and box.has_point(Vector3(spot.x,node.global_position.y+0.1,spot.y)):
					local_spots.append(spot);active=true
				else:local_spots.append(Vector4(1000,1000,0,0))
			m.set_shader_parameter("wet_centers",local_spots)
			m.set_shader_parameter("has_wet",active)
			if not _cut("baked_reflection") and ResourceLoader.exists("res://radiance/assets/water_reflection.res"):
				m.set_shader_parameter("water_reflection",load("res://radiance/assets/water_reflection.res"))
				m.set_shader_parameter("has_baked_reflection",true)
	for node in get_children():
		if node is WorldEnvironment:node.environment.ssr_max_steps=int(atmosphere_settings.get("ssr_steps",32))

func _portal() -> void:
	mats.purple.emission_energy_multiplier=3.0
	mats.metal.roughness=0.42;mats.metal.metallic=0.65
	var geometry := get_node("EnvironmentGeometry") as Node3D
	var center := Vector3(9.2,0,-4.6)
	for node in geometry.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and node.position.distance_to(center+Vector3(0,1,0))<2.0:
			if node.material_override==mats.metal:
				node.mesh=_beveled_box((node.mesh as BoxMesh).size,0.025)
	var light := OmniLight3D.new();light.name="PortalBounce"
	light.position=geometry.to_global(center+Vector3(0,0.75,0.6))
	light.light_color=Color(0.65,0.22,1.0);light.light_energy=1.2
	light.omni_range=2.5;light.shadow_enabled=false;add_child(light)

func _beveled_box(size: Vector3,bevel: float) -> ArrayMesh:
	# Project a subdivided box onto a rounded box; explicit 3D chamfer silhouette.
	var box := BoxMesh.new();box.size=size;box.subdivide_width=6;box.subdivide_height=6;box.subdivide_depth=6
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var half := size*0.5
	var b := minf(bevel,minf(half.x,minf(half.y,half.z))*0.3)
	var inner := half-Vector3.ONE*b
	for i in range(vertices.size()):
		var v := vertices[i]
		var c := v.clamp(-inner,inner)
		var n := (v-c).normalized()
		vertices[i]=c+n*b;normals[i]=n
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _reflection() -> void:
	var probe := ReflectionProbe.new();probe.name="RoadReflection"
	probe.position=Vector3(0,1.8,0);probe.size=Vector3(28,9,24)
	probe.origin_offset=Vector3(0,0.3,0);probe.max_distance=45
	# Godot 4 uses a project-wide reflection atlas; individual probes have no resolution property.
	print("REFLECTION_ATLAS ",ProjectSettings.get_setting("rendering/reflections/reflection_atlas/reflection_size",256))
	probe.update_mode=ReflectionProbe.UPDATE_ONCE;probe.enable_shadows=false
	probe.reflection_mask=2
	probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
	add_child(probe)

func _bake_reflection() -> void:
	for child in get_children():
		if child is CanvasLayer:child.visible=false
		if child is WorldEnvironment:
			child.environment.glow_enabled=false;child.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
			child.environment.tonemap_exposure=1.0
	for node in get_node("EnvironmentGeometry").get_children():
		if node is MeshInstance3D and node.material_override is ShaderMaterial:
			var m := node.material_override as ShaderMaterial
			if m.shader.resource_path=="res://radiance/road.gdshader":
				m.set_shader_parameter("has_wet",false);m.set_shader_parameter("has_baked_reflection",false)
	get_window().content_scale_size=Vector2i(256,256);get_window().size=Vector2i(256,256)
	review_camera.fov=90;review_camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	review_camera.position=Vector3(wet_spots[1].x,0.55,wet_spots[1].y)
	var directions := [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	var ups := [Vector3.DOWN,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD,Vector3.DOWN,Vector3.DOWN]
	var images: Array[Image] = []
	DirAccess.make_dir_recursive_absolute("res://radiance/captures/reflection_faces")
	await get_tree().create_timer(4).timeout
	for i in range(6):
		review_camera.look_at(review_camera.position+directions[i],ups[i]);_process(0.21)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		picture.convert(Image.FORMAT_RGBA8);picture.flip_y();picture.generate_mipmaps()
		picture.save_png("res://radiance/captures/reflection_faces/%d.png"%i)
		images.append(picture)
	var cube := Cubemap.new()
	if cube.create_from_images(images)!=OK:push_error("Reflection cubemap creation failed");await _finish(1);return
	var err := ResourceSaver.save(cube,"res://radiance/assets/water_reflection.res")
	print("WATER_REFLECTION_BAKED ",err)
	await _finish(0 if err==OK else 1)

func _pollen() -> void:
	pollen=GPUParticles3D.new();pollen.name="ForestPollen";pollen.amount=96;pollen.lifetime=14
	pollen.preprocess=14;pollen.fixed_fps=30;pollen.position=Vector3(0,0.8,1)
	pollen.visibility_aabb=AABB(Vector3(-13,-1,-10),Vector3(26,7,20))
	pollen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	var points := PackedVector3Array()
	for row in [-2.04,2.04]:
		for i in range(32):points.append(Vector3(-8+16.0*i/31,0,row))
	var image := Image.create(points.size(),1,false,Image.FORMAT_RGBF)
	for i in range(points.size()):image.set_pixel(i,0,Color(points[i].x,points[i].y,points[i].z))
	process.emission_point_texture=ImageTexture.create_from_image(image);process.emission_point_count=points.size()
	process.direction=Vector3(0.7,0.4,0.2);process.spread=28
	process.initial_velocity_min=0.025;process.initial_velocity_max=0.075
	process.gravity=Vector3.ZERO;process.scale_min=0.012;process.scale_max=0.026
	pollen.process_material=process
	var mesh := SphereMesh.new();mesh.radius=0.5;mesh.height=1;mesh.radial_segments=6;mesh.rings=3
	var material := StandardMaterial3D.new();material.albedo_color=Color(0.62,0.57,0.34)
	material.emission_enabled=true;material.emission=Color(0.3,0.24,0.1);material.emission_energy_multiplier=0.2
	material.roughness=1;mesh.material=material;pollen.draw_pass_1=mesh;add_child(pollen)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F6:
		if not is_instance_valid(pollen):_pollen()
		else:pollen.emitting=not pollen.emitting;pollen.visible=pollen.emitting
		return
	super._unhandled_input(event)

func _add_camera_help() -> void:
	super._add_camera_help()
	for child in get_children():
		if child is CanvasLayer:
			for label in child.get_children():
				if label is Label:label.text+=" | F6 pollen"

func _apply_capture_view() -> void:
	super._apply_capture_view()
	if "--quality-side" in OS.get_cmdline_user_args():orbit_pitch=deg_to_rad(40);_set_width(25)
	_pose_detail(_option("view",""))

func _pose_detail(view: String) -> void:
	match view:
		"left":orbit_yaw=-0.65;orbit_pitch=deg_to_rad(40);_set_width(25)
		"water":
			camera_target=Vector3(wet_spots[1].x,0.15,wet_spots[1].y)
			orbit_yaw=0.2;orbit_pitch=deg_to_rad(25);_set_width(3.7)
		"portal":camera_target=Vector3(7.82,0.75,-5.52);orbit_yaw=0.4;orbit_pitch=deg_to_rad(35);_set_width(5.0)

func _quality_capture() -> void:
	await get_tree().create_timer(8.0).timeout
	await RenderingServer.frame_post_draw
	var view := _option("view","side" if "--quality-side" in OS.get_cmdline_user_args() else "top")
	var err := _save_still(_tag(),view)
	await _finish(0 if err==OK else 1)

func _save_still(tag: String,view: String) -> int:
	var file_name := "res://radiance/captures/"+tag+"_"+view
	var err := get_viewport().get_texture().get_image().save_png(file_name+".png")
	var f := FileAccess.open(file_name+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"pass":_pass(),"view":view,"output":str(get_viewport().get_texture().get_size()),"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width(),"projection":review_camera.projection,"settings":atmosphere_settings},"  "))
	print("RADIANCE_CAPTURE_OK ",file_name)
	return err

func _batch_stills() -> void:
	await get_tree().create_timer(8).timeout
	for view in ["top","left","side","low_side","water","portal"]:
		camera_target=Vector3(0,0,0.8);orbit_yaw=0;orbit_pitch=deg_to_rad(55);_set_width(24)
		if view in ["side","low_side"]:orbit_yaw=0.65;orbit_pitch=deg_to_rad(40 if view=="side" else 32);_set_width(25)
		else:_pose_detail(view)
		_process(0.21)
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		if _save_still("final",view)!=OK:await _finish(1);return
	await _finish(0)

func _batch_stages() -> void:
	await get_tree().create_timer(8).timeout
	for pass_name in ["baseline","light","ground","wet","final"]:
		pass_override=pass_name
		match pass_name:
			"light":_grade()
			"ground":_surfaces()
			"wet":
				if _feature("wet"):_water()
				if _feature("portal"):_portal()
				if _feature("probe"):_reflection()
			"final":
				if _feature("pollen"):_pollen()
		_process(0.21)
		await get_tree().create_timer(2).timeout
		await RenderingServer.frame_post_draw
		if _save_still(pass_name,"top")!=OK:await _finish(1);return
	await _finish(0)

func _batch_coverage() -> void:
	await get_tree().create_timer(8).timeout
	var helper=load("res://radiance/coverage.gd")
	tag_override="baseline_ids"
	await helper.capture(self,false)
	pass_override="final"
	if _feature("grade"):_grade()
	if _feature("surface"):_surfaces()
	if _feature("wet"):_water()
	if _feature("portal"):_portal()
	if _feature("probe"):_reflection()
	for view in ["top","left","side","low_side"]:
		camera_target=Vector3(0,0,0.8);orbit_yaw=0;orbit_pitch=deg_to_rad(55);_set_width(24)
		if view in ["side","low_side"]:orbit_yaw=0.65;orbit_pitch=deg_to_rad(40 if view=="side" else 32);_set_width(25)
		else:_pose_detail(view)
		_process(0.21)
		tag_override="coverage_"+view
		await helper.capture(self,false)
	await _finish(0)

func _quality_benchmark() -> void:
	await load("res://radiance/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://radiance/audit.gd").motion(self)

func _smoke() -> void:
	await load("res://radiance/audit.gd").smoke(self)

func _coverage_capture() -> void:
	_apply_capture_view()
	if pollen:pollen.visible=false
	await load("res://radiance/coverage.gd").capture(self)

func _export_scene_assets() -> void:
	load("res://radiance/export_assets.gd").export_scene_assets(self)

func _finish(code: int) -> void:
	if is_instance_valid(pollen):
		pollen.emitting=false;pollen.free();pollen=null
	for child in get_children():
		if child is ReflectionProbe:child.free()
	for i in range(4):await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	await super._finish(code)
