extends RefCounted

static func collect(node: Node,entries: Array) -> void:
	if node is GeometryInstance3D:
		var kind := "other"
		var title := str(node.name)
		if title.begins_with("RoadSlab_") or title.begins_with("Curb_"):kind="road"
		elif title.contains("Ground"):kind="ground"
		else:
			if node is MultiMeshInstance3D:kind="plant"
			elif node is MeshInstance3D and node.mesh:
				for i in range(node.mesh.get_surface_count()):
					var m := node.get_active_material(i) as ShaderMaterial
					if m and (m.shader.resource_path.ends_with("foliage.gdshader") or m.shader.resource_path.ends_with("grass.gdshader")):kind="plant"
		entries.append({"node":node,"kind":kind})
	for child in node.get_children():collect(child,entries)

static func capture(scene: Node3D,finish: bool=true) -> void:
	await scene.get_tree().create_timer(6.0 if finish else 0.5).timeout
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png("res://radiance/captures/"+scene._tag()+"_beauty.png")
	scene.set_process(false)
	var environments: Array = []
	for node in scene.get_children():
		if node is WorldEnvironment:
			environments.append({"node":node,"environment":node.environment})
			node.environment=node.environment.duplicate()
			var e: Environment=node.environment
			e.glow_enabled=false;e.ssr_enabled=false;e.ssil_enabled=false;e.ssao_enabled=false;e.volumetric_fog_enabled=false;e.adjustment_enabled=false
			e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.tonemap_exposure=1.0
			e.background_mode=Environment.BG_COLOR;e.background_color=Color.BLACK
		if node is CanvasLayer:node.visible=false
	var colors := {"road":Color.RED,"plant":Color.GREEN,"ground":Color.BLUE,"other":Color(0.25,0.25,0.25)}
	var entries: Array = [];collect(scene.get_node("EnvironmentGeometry"),entries)
	for entry in entries:
		entry["visible"]=entry.node.visible
		entry["override"]=entry.node.material_override
		entry["surfaces"]=[]
		if entry.node is MeshInstance3D:
			for i in range(entry.node.mesh.get_surface_count()):entry.surfaces.append(entry.node.get_surface_override_material(i))
	for entry in entries:
		var mat := StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=colors[entry.kind];mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		# Preserve alpha-tested leaf coverage; never turn leaf cards into solid rectangles.
		if entry.kind=="plant" and entry.node is MeshInstance3D:
			var original_materials: Array = []
			for i in range(entry.node.mesh.get_surface_count()):original_materials.append(entry.node.get_active_material(i))
			entry.node.material_override=null
			for i in range(entry.node.mesh.get_surface_count()):
				var old := original_materials[i] as ShaderMaterial
				if old:
					# Unshaded textured colour would contaminate IDs: use a tiny ID shader.
					var id := ShaderMaterial.new();id.shader=load("res://atmosphere/id_leaf.gdshader");id.set_shader_parameter("base_map",old.get_shader_parameter("base_map"))
					entry.node.set_surface_override_material(i,id)
				else:entry.node.set_surface_override_material(i,mat)
		elif entry.kind=="plant" and entry.node is MultiMeshInstance3D and entry.node.material_override is ShaderMaterial and entry.node.material_override.shader.resource_path.ends_with("foliage.gdshader"):
			var previous := entry.node.material_override as ShaderMaterial
			var id := ShaderMaterial.new();id.shader=load("res://atmosphere/id_leaf.gdshader")
			id.set_shader_parameter("base_map",previous.get_shader_parameter("base_map"))
			entry.node.material_override=id
		else:entry.node.material_override=mat
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png("res://radiance/captures/"+scene._tag()+"_scene.png")
	for entry in entries:entry.node.visible=entry.kind=="road"
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png("res://radiance/captures/"+scene._tag()+"_road.png")
	# Direct-only pass identifies surfaces which stay in shadow after plants move.
	var gray := StandardMaterial3D.new();gray.albedo_color=Color(0.5,0.5,0.5);gray.roughness=1;gray.metallic_specular=0
	gray.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	for entry in entries:
		entry.node.visible=entry.visible
		if entry.kind!="plant":entry.node.material_override=gray
	var lights: Array = []
	for node in scene.get_children():
		if node is WorldEnvironment:
			node.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
			node.environment.ambient_light_energy=0
		elif node is Light3D:
			lights.append({"node":node,"color":node.light_color,"energy":node.light_energy})
			node.light_energy=1.0 if node is DirectionalLight3D else 0.0
			node.light_color=Color.WHITE
	for i in range(2):await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png("res://radiance/captures/"+scene._tag()+"_sun.png")
	for light in lights:light.node.light_color=light.color;light.node.light_energy=light.energy
	for entry in entries:
		entry.node.visible=entry.visible;entry.node.material_override=entry.override
		if entry.node is MeshInstance3D:
			for i in range(entry.surfaces.size()):entry.node.set_surface_override_material(i,entry.surfaces[i])
	for entry in environments:entry.node.environment=entry.environment
	scene.set_process(true)
	print("COVERAGE_CAPTURE_OK")
	if finish:await scene._finish(0)
