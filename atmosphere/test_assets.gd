extends Node3D

func _ready() -> void:
	var camera := Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;add_child(camera)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,-135,0);light.light_energy=1.5;add_child(light)
	var world := WorldEnvironment.new();var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(0.12,0.16,0.20)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_energy=0.5;environment.ambient_light_color=Color(0.65,0.75,0.85)
	world.environment=environment;add_child(world)
	get_viewport().msaa_3d=Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute("res://atmosphere/captures/assets")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://atmosphere/assets/catalog.json"))
	for asset_name in catalog.adopted_scenes:
		var scene := load("res://atmosphere/assets/"+asset_name) as PackedScene
		if not scene:push_error("Missing asset "+asset_name);get_tree().quit(1);return
		var node := scene.instantiate();add_child(node)
		await get_tree().process_frame
		var boxes: Array = [];_bounds(node,boxes)
		if boxes.is_empty():push_error("Empty asset bounds "+asset_name);get_tree().quit(1);return
		var box: AABB=boxes[0]
		for item in boxes:box=box.merge(item)
		var span := maxf(box.size.x,maxf(box.size.y,box.size.z))
		camera.size=maxf(span*1.8,0.5)
		camera.position=box.get_center()+Vector3(1,0.8,1)*maxf(span*1.5,1.0);camera.look_at(box.get_center(),Vector3.UP)
		await get_tree().create_timer(0.5).timeout
		if not _has_mesh(node):push_error("Empty asset "+asset_name);get_tree().quit(1);return
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png("res://atmosphere/captures/assets/"+asset_name+".png")!=OK:push_error("Asset screenshot failed");get_tree().quit(1);return
		print("ATMOSPHERE_ASSET_OK ",asset_name)
		node.visible=false
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)

func _bounds(node: Node,boxes: Array) -> void:
	if node is MeshInstance3D and node.mesh:boxes.append(node.global_transform*node.get_aabb())
	for child in node.get_children():_bounds(child,boxes)

func _has_mesh(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh and node.mesh.get_surface_count()>0:return true
	for child in node.get_children():
		if _has_mesh(child):return true
	return false
