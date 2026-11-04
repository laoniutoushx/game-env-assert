extends RefCounted

static func export_scene_assets(scene: Node3D) -> void:
	var geometry := scene.get_node("EnvironmentGeometry")
	var names := ["RoadSlab_05","RoadSlab_17","RoadSlab_32","RoadSlab_45","TerrainGround"]
	var exported: Array = []
	for name in names:
		var source := geometry.get_node_or_null(name) as MeshInstance3D
		if not source:push_error("Export source missing "+name);continue
		var root := Node3D.new();root.name=name
		var mesh := MeshInstance3D.new();mesh.mesh=source.mesh;mesh.scale=source.scale
		mesh.material_override=source.material_override.duplicate() if source.material_override else null
		if mesh.material_override is ShaderMaterial and mesh.material_override.shader.resource_path.ends_with("road.gdshader"):
			var dry := PackedVector4Array()
			for i in range(4):dry.append(Vector4(1000,1000,0,0))
			mesh.material_override.set_shader_parameter("wet_centers",dry)
		var center: Vector3=source.mesh.get_aabb().get_center()*source.scale
		mesh.position=-Vector3(center.x,0,center.z)
		root.add_child(mesh);mesh.owner=root
		var packed := PackedScene.new();packed.pack(root)
		var file_name: String=name.to_snake_case()+".tscn"
		var err := ResourceSaver.save(packed,"res://atmosphere/assets/"+file_name)
		root.free()
		if err!=OK:push_error("Asset save failed "+name);continue
		exported.append(file_name)
	for lod in ["high","mid","low"]:exported.append("tree_"+lod+".tscn")
	var builder=load("res://atmosphere/plants.gd")
	var variants := {"grass":Color.TRANSPARENT,"daisy_white":Color(0.95,0.93,0.81),"flower_yellow":Color(0.88,0.65,0.12),"flower_pink":Color(0.75,0.35,0.48)}
	for name in variants:
		var root := MeshInstance3D.new();root.name=name
		root.mesh=builder.grass() if name=="grass" else builder.flower(variants[name])
		var material := ShaderMaterial.new();material.shader=load("res://atmosphere/grass.gdshader")
		material.set_shader_parameter("wind_strength",0.014);root.material_override=material
		var packed := PackedScene.new();packed.pack(root)
		if ResourceSaver.save(packed,"res://atmosphere/assets/"+name+".tscn")!=OK:push_error("Plant export failed "+name)
		root.free();exported.append(name+".tscn")
	var data := {"adopted_scenes":exported,"source_catalog":"../source_catalog.json","base_assets":"../../nextgen/assets/catalog.json","new_meshy_credits":0,"engraving":"height-map parallax and normal, not boolean-carved text geometry","tree_lods":"three spatial geometry LODs; no whole-plant billboard","gi_proxy":"temporary standard materials for static bake; plants receive GI without contribution"}
	var f := FileAccess.open("res://atmosphere/assets/catalog.json",FileAccess.WRITE);f.store_string(JSON.stringify(data,"  "))
	print("ATMOSPHERE_EXPORT_OK ",exported.size())
