extends RefCounted

static func prepare(scene: Node3D) -> void:
	var geometry := scene.get_node("EnvironmentGeometry")
	var maps := []
	for i in range(4):
		var image := Image.load_from_file("res://model_v3/textures/rune_%d.png"%i)
		image.generate_mipmaps();maps.append(ImageTexture.create_from_image(image))
	var ids := [5,17,32,45]
	for node in geometry.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("RoadSlab_"):
			var index := int(str(node.name).trim_prefix("RoadSlab_"))
			if index in ids:
				var m := node.material_override as ShaderMaterial
				m.set_shader_parameter("rune_map",maps[ids.find(index)])

static func layout(scene: Node3D) -> void:
	var geometry := scene.get_node("EnvironmentGeometry")
	var moved := 0
	for node in geometry.get_children():
		if node.get_class()!="Node3D" or node.position.z<4.0 or not scene._contains_foliage(node):continue
		scene.candidate_bounds_set=false;scene._collect_candidate_bounds(node,node)
		if not scene.candidate_bounds_set:continue
		var height: float=scene.candidate_bounds.size.y*node.scale.y
		if height<1.0:continue
		var shift := Vector3(0,0,2.0 if height>2.0 else 1.2)
		if absf(node.position.x)>8.5:shift.x=signf(node.position.x)*0.6
		scene._move_plant(node,shift);moved+=1
	var rng := RandomNumberGenerator.new();rng.seed=721102
	var mesh: ArrayMesh=scene._beveled_box(Vector3(0.11,0.055,0.08),0.012)
	var mm := MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh
	var points: Array[Transform3D] = []
	for i in range(1500):
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-5,5))
		var distance: float=load("res://atmosphere/terrain.gd").road_distance(p.x,p.y)
		if distance<0.76 or distance>1.03:continue
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(0.55,1.4))
		points.append(Transform3D(basis,Vector3(p.x,load("res://atmosphere/terrain.gd").height(p.x,p.y)+0.02,p.y)))
		if points.size()==48:break
	mm.instance_count=points.size()
	for i in range(points.size()):mm.set_instance_transform(i,points[i]);mm.set_instance_color(i,Color(0.40,0.43,0.36)*rng.randf_range(0.8,1.2))
	var debris := MultiMeshInstance3D.new();debris.name="RoadsideDebris";debris.multimesh=mm
	var material := StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=0.9
	debris.material_override=material;geometry.add_child(debris)
	print("V2_LAYOUT foreground_moved=",moved," debris=",points.size())

static func palette(scene: Node3D) -> void:
	_apply_palette(scene.get_node("EnvironmentGeometry"))

static func _tint(position: Vector3) -> Color:
	var seed_value := absf(sin(position.x*12.9898+position.z*78.233)*43758.5453)
	var number := seed_value-floorf(seed_value)
	return Color(0.78,0.98,0.84,1) if number<0.45 else (Color(0.72,0.99,0.98,1) if number<0.8 else Color(1.02,1.0,0.76,1))

static func _apply_palette(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var m := node.get_active_material(surface) as ShaderMaterial
			if m and m.shader.resource_path.ends_with("foliage.gdshader"):
				node.set_instance_shader_parameter("plant_palette",_tint(node.global_position))
	elif node is MultiMeshInstance3D:
		var m := node.material_override as ShaderMaterial
		if m and m.shader.resource_path.ends_with("foliage.gdshader"):
			var old: MultiMesh=node.multimesh
			var mm := MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=old.mesh;mm.instance_count=old.instance_count
			for i in range(old.instance_count):
				var transform := old.get_instance_transform(i);mm.set_instance_transform(i,transform)
				mm.set_instance_custom_data(i,_tint(node.global_transform*transform.origin))
			node.multimesh=mm
	for child in node.get_children():_apply_palette(child)

