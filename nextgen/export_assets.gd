extends SceneTree

func _initialize() -> void:
	var builder = load("res://nextgen/plants.gd")
	DirAccess.make_dir_recursive_absolute("res://nextgen/assets")
	var variants := {"grass_blades":Color.TRANSPARENT,"broadleaf_rosette":Color.TRANSPARENT,"daisy_white":Color(0.95,0.93,0.81),"wildflower_yellow":Color(0.88,0.65,0.12),"wildflower_pink":Color(0.75,0.35,0.48)}
	for asset_name in variants:
		var root_node := Node3D.new()
		root_node.name=asset_name
		var mesh := MeshInstance3D.new()
		if asset_name=="grass_blades":mesh.mesh=builder.grass()
		elif asset_name=="broadleaf_rosette":mesh.mesh=builder.broadleaf()
		else:mesh.mesh=builder.flower(variants[asset_name])
		mesh.material_override=builder.material()
		root_node.add_child(mesh)
		mesh.owner=root_node
		var packed := PackedScene.new()
		packed.pack(root_node)
		var err := ResourceSaver.save(packed,"res://nextgen/assets/"+asset_name+".tscn")
		root_node.free()
		if err!=OK:push_error("Export failed "+asset_name);quit(1);return
		print("NEXTGEN_ASSET_EXPORTED ",asset_name)
	var road = load("res://nextgen/road.gd")
	for curved in [false,true]:
		var route: Array[Vector3] = []
		var distances: Array[float] = [0.0]
		for i in range(33):
			var a := i/32.0*0.55
			route.append(Vector3(1.7*sin(a),0,1.7*(1-cos(a))) if curved else Vector3(i/32.0*0.94,0,0))
			if i>0:distances.append(distances[-1]+route[-1].distance_to(route[-2]))
		var node := MeshInstance3D.new()
		node.name="RoadCurve" if curved else "RoadStraight"
		node.mesh=road._segment(route,distances,0.01,distances[-1]-0.01,-0.55,0.55,0.148,2,true)
		var material := StandardMaterial3D.new()
		material.albedo_texture=load("res://nextgen/textures/slab_0_Color.png")
		material.normal_enabled=true
		material.normal_texture=load("res://nextgen/textures/slab_0_NormalGL.png")
		material.normal_scale=0.28
		material.roughness_texture=load("res://nextgen/textures/slab_0_Roughness.png")
		material.vertex_color_use_as_albedo=true
		material.albedo_color=Color(0.90,0.92,0.92)
		node.material_override=material
		var packed := PackedScene.new()
		packed.pack(node)
		var asset_name := "road_curve" if curved else "road_straight"
		if ResourceSaver.save(packed,"res://nextgen/assets/"+asset_name+".tscn")!=OK:push_error("Road export failed");quit(1);return
		node.free()
		print("NEXTGEN_ASSET_EXPORTED ",asset_name)
	quit(0)
