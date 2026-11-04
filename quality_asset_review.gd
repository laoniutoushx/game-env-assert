extends "res://meshy_pilot_review.gd"

func _load_asset(path: String, x: float, _max_size: float) -> void:
	var model: Node3D
	if path.begins_with("H:"):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path,state)
		if error != OK:
			push_error("Raw asset import failed " + path)
			return
		model = document.generate_scene(state) as Node3D
	else:
		var packed := load(path) as PackedScene
		if packed: model = packed.instantiate() as Node3D
	if not model:
		push_error("Missing review model " + path)
		return
	var holder := Node3D.new()
	holder.position.x = x
	add_child(holder)
	holder.add_child(model)
	var bounds := _bounds(model,model)
	var span := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	var factor := 2.0/maxf(span,0.001)
	model.scale = Vector3.ONE*factor
	model.position = Vector3(-bounds.get_center().x*factor,-bounds.position.y*factor,-bounds.get_center().z*factor)
	if "--grey" in OS.get_cmdline_user_args():
		_grey(model)
	elif "--checker" in OS.get_cmdline_user_args():
		_checker(model)

func _checker(node: Node) -> void:
	if node is MeshInstance3D:
		var material := ShaderMaterial.new()
		material.shader = load("res://quality_round/uvchecker.gdshader")
		node.material_override = material
		node.lod_bias = 100.0
	for child in node.get_children(): _checker(child)

func _grey(node: Node) -> void:
	if node is MeshInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5,0.5,0.5)
		material.roughness = 0.75
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = material
	for child in node.get_children(): _grey(child)
