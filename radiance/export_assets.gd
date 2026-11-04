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
		var err := ResourceSaver.save(packed,"res://radiance/assets/"+file_name)
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
		if ResourceSaver.save(packed,"res://radiance/assets/"+name+".tscn")!=OK:push_error("Plant export failed "+name)
		root.free();exported.append(name+".tscn")
	var portal := Node3D.new();portal.name="Portal";portal.scale=geometry.scale
	for node in geometry.get_children():
		if node is MeshInstance3D and node.position.distance_to(Vector3(9.2,1,-4.6))<2.0 and node.material_override in [scene.mats.metal,scene.mats.stone,scene.mats.purple,scene.mats.edge]:
			var part := MeshInstance3D.new();part.mesh=node.mesh;part.material_override=node.material_override
			part.transform=node.transform;part.position-=Vector3(9.2,0,-4.6)
			portal.add_child(part);part.owner=portal
	var packed_portal := PackedScene.new();packed_portal.pack(portal)
	if ResourceSaver.save(packed_portal,"res://radiance/assets/portal.tscn")!=OK:push_error("Portal export failed")
	portal.free();exported.append("portal.tscn")
	var source_water := geometry.get_node("RoadSlab_27") as MeshInstance3D
	var wet_slab := MeshInstance3D.new();wet_slab.name="WetRoadSlab";wet_slab.mesh=source_water.mesh
	var wet_material := source_water.material_override.duplicate() as ShaderMaterial
	wet_material.set_shader_parameter("water_enabled",1.0)
	wet_material.set_shader_parameter("has_wet",true)
	wet_material.set_shader_parameter("wet_centers",PackedVector4Array([Vector4(0,0,1,0),Vector4(1000,1000,0,0),Vector4(1000,1000,0,0),Vector4(1000,1000,0,0)]))
	wet_slab.material_override=wet_material
	var slab_center := wet_slab.mesh.get_aabb().get_center();wet_slab.position=-Vector3(slab_center.x,0,slab_center.z)
	var wet_packed := PackedScene.new();wet_packed.pack(wet_slab)
	if ResourceSaver.save(wet_packed,"res://radiance/assets/wet_road_slab.tscn")!=OK:push_error("Wet road export failed")
	wet_slab.free();exported.append("wet_road_slab.tscn")
	var data := {"adopted_scenes":exported,"source_catalog":"../../atmosphere/source_catalog.json","base_assets":"../../atmosphere/assets/catalog.json","new_meshy_credits":0,"engraving":"height-map parallax and normal, not boolean-carved text geometry","tree_lods":"three spatial geometry LODs; no whole-plant billboard","water":"opaque dielectric film integrated in stone; standalone slabs exported dry"}
	data["water_reflection"]="water_reflection.res"
	var f := FileAccess.open("res://radiance/assets/catalog.json",FileAccess.WRITE);f.store_string(JSON.stringify(data,"  "))
	print("ATMOSPHERE_EXPORT_OK ",exported.size())
