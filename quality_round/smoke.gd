extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://quality_round.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var before: Vector3 = scene.camera_target
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_W
	scene._unhandled_input(event)
	if scene.camera_target.distance_to(before)<0.1:
		push_error("Camera pan failed");quit(1);return
	event.keycode = KEY_R
	scene._unhandled_input(event)
	if scene.camera_target.distance_to(before)>0.001:
		push_error("Camera reset failed");quit(1);return
	var geometry: Node3D = scene.get_node("EnvironmentGeometry")
	var tangent_slabs := 0
	for node in geometry.get_children():
		if node is MeshInstance3D and node.material_override in [scene.mats.slab0,scene.mats.slab1,scene.mats.slab2,scene.mats.slab3,scene.mats.slab4,scene.mats.slab5,scene.mats.slab6,scene.mats.slab7] and node.visible:
			var arrays: Array = node.mesh.surface_get_arrays(0)
			if arrays[Mesh.ARRAY_TANGENT]==null or arrays[Mesh.ARRAY_TANGENT].is_empty():
				push_error("Procedural slab has a normal map but no tangents");quit(1);return
			tangent_slabs += 1
			if tangent_slabs == 1:
				print("SLAB_ATTRIBUTES normal=",arrays[Mesh.ARRAY_NORMAL][0]," color=",arrays[Mesh.ARRAY_COLOR][0]," albedo=",node.material_override.albedo_color," roughness=",node.material_override.roughness," metallic=",node.material_override.metallic)
				var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				if (v[1]-v[0]).cross(v[2]-v[0]).dot(n[0])>=0:
					push_error("Slab winding conflicts with outward normals and Godot clockwise front faces");quit(1);return
	for child in geometry.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			if child.material_override.shader.resource_path.ends_with("water.gdshader"):
				print("WATER_DIAGNOSTIC ",child.global_position," ",child.visible)
				_probe_overlaps(geometry,child.global_position,child)
	if geometry.scale.distance_to(Vector3.ONE)>0.001:
		push_error("Global asset stretching remains");quit(1);return
	if scene.quality_lods.is_empty():
		push_error("No repaired asset LODs registered");quit(1);return
	scene.review_camera.size = 24.0
	scene._update_quality_lods()
	var far_count := 0
	for item in scene.quality_lods:
		if item.high.visible:far_count+=1
	scene.review_camera.size = 3.0
	scene._update_quality_lods()
	var near_count := 0
	for item in scene.quality_lods:
		if item.high.visible:near_count+=1
	if near_count<=far_count:
		push_error("LOD did not respond to orthographic zoom");quit(1);return
	# Repeated color variants must not mutate the shared stone template.
	var template := StandardMaterial3D.new()
	template.albedo_color = Color(0.7,0.7,0.7)
	for i in range(4):
		var instance := MeshInstance3D.new()
		instance.mesh = BoxMesh.new()
		instance.set_surface_override_material(0,template)
		scene._vary_tint(instance,0.8)
		if template.albedo_color.r<0.699:
			push_error("Shared material was cumulatively darkened");quit(1);return
		instance.free()
	print("QUALITY_SMOKE_OK camera_pan_reset, uniform_root, lod_far=",far_count," lod_near=",near_count," independent_tints tangented_slabs=",tangent_slabs)
	quit(0)

func _probe_overlaps(node: Node, point: Vector3, water: Node) -> void:
	if node is MeshInstance3D and node!=water and node.is_visible_in_tree() and node.mesh:
		var box: AABB = node.global_transform*node.mesh.get_aabb()
		if point.x>box.position.x and point.x<box.end.x and point.z>box.position.z and point.z<box.end.z and box.end.y>0.05 and box.end.y<0.6:
			print("WATER_NEARBY_TOP ",box.end.y," ",node.get_path())
	for child in node.get_children(): _probe_overlaps(child,point,water)
