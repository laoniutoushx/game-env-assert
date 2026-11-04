extends RefCounted

static func run(scene: Node3D) -> void:
	# Scatter builders queue_free their source templates during _ready().
	# Wait for that deletion queue before collecting persistent scene geometry.
	await scene.get_tree().process_frame
	await scene.get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://afternoon_v2/assets")
	var root := Node3D.new();root.name="StaticLighting"
	var meshes := Node3D.new();meshes.name="StaticMeshes";root.add_child(meshes);meshes.owner=root
	scene.add_child(root)
	# Reuse verified UV2 from unchanged v1 geometry; carved slabs use new planar UV2.
	var previous := {}
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://afternoon/assets/bake.json"))
	var old_root := (load(manifest.scene) as PackedScene).instantiate()
	for item in old_root.get_node("StaticMeshes").get_children():previous[str(item.get_meta("source_path",""))]=item.mesh
	var count := _collect(scene.get_node("EnvironmentGeometry"),scene,root,meshes,0,previous)
	old_root.free()
	for child in scene.get_children():
		if child is DirectionalLight3D or child is WorldEnvironment:
			var copy := child.duplicate();root.add_child(copy);copy.owner=root
			if copy is DirectionalLight3D:copy.light_bake_mode=Light3D.BAKE_DYNAMIC
	var gi := LightmapGI.new();gi.name="AfternoonBounce";root.add_child(gi);gi.owner=root
	gi.directional=true;gi.bounces=3;gi.quality=LightmapGI.BAKE_QUALITY_HIGH
	gi.max_texture_size=4096;gi.generate_probes_subdiv=LightmapGI.GENERATE_PROBES_SUBDIV_8
	gi.use_denoiser=true;gi.environment_mode=LightmapGI.ENVIRONMENT_MODE_SCENE
	var data := LightmapGIData.new();ResourceSaver.save(data,"res://afternoon_v2/assets/indirect.lmbake")
	gi.light_data=load("res://afternoon_v2/assets/indirect.lmbake") as LightmapGIData
	var packed := PackedScene.new();var err := packed.pack(root)
	if err==OK:err=ResourceSaver.save(packed,"res://afternoon_v2/assets/static_lighting.tscn")
	var f := FileAccess.open("res://afternoon_v2/assets/export.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"meshes":count,"status":"uv2_ready_not_baked","error":err},"  "))
	print("AFTERNOON_STATIC_EXPORT ",count," error=",err)
	await scene._finish(0 if err==OK else 1)

static func _collect(node: Node,scene: Node3D,root: Node3D,meshes: Node3D,count: int,previous: Dictionary) -> int:
	if node.is_queued_for_deletion():return count
	if node is MeshInstance3D and node.mesh and node.is_visible_in_tree() and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		var material: Material=node.get_active_material(0)
		var skip := str(node.name)=="DistantGround" or str(node.name).begins_with("ShallowWater")
		if material is ShaderMaterial:
			var shader_path: String=material.shader.resource_path
			skip=skip or "foliage" in shader_path or "grass" in shader_path or "water" in shader_path
		if not skip and node.mesh.get_aabb().size.length()>0.15:
			var copy := MeshInstance3D.new();copy.name="M%04d"%count
			var combined := ArrayMesh.new()
			var planar := "RoadSlab_" in str(node.name) or "Curb_" in str(node.name) or str(node.name)=="TerrainGround"
			for s in range(node.mesh.get_surface_count()):
				var tool := SurfaceTool.new();tool.create_from(node.mesh,s);tool.index()
				var indexed := tool.commit()
				var arrays: Array=indexed.surface_get_arrays(0)
				if planar:
					var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
					var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
					var uv2 := PackedVector2Array()
					for i in range(uv.size()):
						if normals[i].y>0.5:uv2.append(uv[i]*Vector2(0.9,0.75)+Vector2(0.05,0.05))
						else:uv2.append(Vector2(uv[i].x*0.45+0.05,(uv[i].y-0.4)*0.8+0.84))
					arrays[Mesh.ARRAY_TEX_UV2]=uv2
				combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				combined.surface_set_material(s,node.get_active_material(s))
			var unwrap_error := OK
			if planar:combined.lightmap_size_hint=Vector2i(512,512) if "Ground" in str(node.name) else Vector2i(128,128)
			else:
				var old := previous.get(str(scene.get_path_to(node))) as ArrayMesh
				if old and _same_positions(old,combined):
					combined=old.duplicate() as ArrayMesh
					for s in range(combined.get_surface_count()):combined.surface_set_material(s,node.get_active_material(s))
				else:unwrap_error=combined.lightmap_unwrap(node.global_transform,0.1)
			if unwrap_error!=OK:
				push_error("UV2 unwrap failed: "+str(scene.get_path_to(node)));return count
			copy.mesh=combined;copy.transform=node.global_transform
			copy.gi_mode=GeometryInstance3D.GI_MODE_STATIC;copy.layers=node.layers
			copy.set_meta("source_path",str(scene.get_path_to(node)))
			meshes.add_child(copy);copy.owner=root
			count+=1
			if count%50==0:print("AFTERNOON_UV2_PROGRESS ",count)
	for child in node.get_children():count=_collect(child,scene,root,meshes,count,previous)
	return count

static func _same_positions(a: ArrayMesh,b: ArrayMesh) -> bool:
	if a.get_surface_count()!=b.get_surface_count():return false
	for s in range(a.get_surface_count()):
		var left := {};var right := {}
		for vertex in a.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:left[vertex]=true
		for vertex in b.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:right[vertex]=true
		if left!=right:return false
	return true
