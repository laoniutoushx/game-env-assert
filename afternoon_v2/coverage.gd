extends RefCounted

static func collect(node: Node, entries: Array) -> void:
	if node is GeometryInstance3D and node.is_visible_in_tree() and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			var source := str(node.get_meta("source_path",node.name))
			var kind := "road" if "RoadSlab_" in source or "Curb_" in source else "other"
			entries.append({"node":node,"visible":node.visible,"kind":kind})
	for child in node.get_children():collect(child,entries)

static func id_material(old: Material,kind: String) -> Material:
	if old is ShaderMaterial and old.shader and old.shader.resource_path.ends_with("foliage.gdshader"):
		var copy := old.duplicate() as ShaderMaterial
		var shader := Shader.new()
		shader.code=old.shader.code.replace("render_mode ","render_mode unshaded, ").replace("ALBEDO = base.rgb*species_tint*plant_tint;","ALBEDO = vec3(0.0,1.0,0.0);")
		copy.shader=shader;return copy
	if old is ShaderMaterial and old.shader and old.shader.resource_path.ends_with("grass.gdshader"):
		var copy := old.duplicate() as ShaderMaterial
		var shader := Shader.new()
		shader.code=old.shader.code.replace("render_mode ","render_mode unshaded, ").replace("ALBEDO=COLOR.rgb","ALBEDO=vec3(0.0,1.0,0.0)")
		copy.shader=shader;return copy
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color.RED if kind=="road" else Color(0.25,0.25,0.25)
	return mat

static func run(scene: Node3D) -> void:
	await scene.get_tree().create_timer(6).timeout
	scene.set_process(false)
	scene.review_camera.attributes=null
	for node in scene.get_children():
		if node is CanvasLayer:node.visible=false
		if node is WorldEnvironment:
			var e: Environment=node.environment
			e.glow_enabled=false;e.ssr_enabled=false;e.ssil_enabled=false;e.ssao_enabled=false
			e.volumetric_fog_enabled=false;e.adjustment_enabled=false
			e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.tonemap_exposure=1
	var entries := []
	collect(scene.get_node("EnvironmentGeometry"),entries)
	if is_instance_valid(scene.lighting_cache):collect(scene.lighting_cache,entries)
	for entry in entries:
		var node: GeometryInstance3D=entry.node
		if node is MeshInstance3D:
			var mats := []
			for i in range(node.mesh.get_surface_count()):mats.append(id_material(node.get_active_material(i),entry.kind))
			node.material_override=null
			for i in range(mats.size()):node.set_surface_override_material(i,mats[i])
		else:
			node.material_override=id_material(node.material_override,entry.kind)
	for view in ["top","left","side","low_side"]:
		scene.camera_target=Vector3(0,0,0.8);scene.orbit_yaw=0;scene.orbit_pitch=deg_to_rad(55);scene._set_width(24)
		if view in ["side","low_side"]:
			scene.orbit_yaw=0.65;scene.orbit_pitch=deg_to_rad(40 if view=="side" else 32);scene._set_width(25)
		else:scene._pose_detail(view)
		scene._process(0)
		for pass_name in ["full","road"]:
			for entry in entries:entry.node.visible=entry.visible and (pass_name=="full" or entry.kind=="road")
			await scene.get_tree().create_timer(0.5).timeout
			RenderingServer.force_draw(false)
			scene.get_viewport().get_texture().get_image().save_png("res://afternoon_v2/captures/coverage_%s_%s.png"%[view,pass_name])
	await scene._finish(0)
