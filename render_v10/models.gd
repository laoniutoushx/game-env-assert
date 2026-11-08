extends RefCounted

static var meshes: Dictionary = {}

static func mesh(asset: String) -> ArrayMesh:
	if meshes.has(asset):
		return meshes[asset]
	var source: Node3D = (load("res://render_v10/assets/" + asset + ".glb") as PackedScene).instantiate()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(source, Transform3D.IDENTITY, tool)
	var result := tool.commit()
	source.free()
	meshes[asset] = result
	return result

static func _append(node: Node3D, parent_transform: Transform3D, tool: SurfaceTool) -> void:
	var transform := parent_transform * node.transform
	if node is MeshInstance3D:
		for s in range(node.mesh.get_surface_count()):
			tool.append_from(node.mesh, s, transform)
	for child in node.get_children():
		if child is Node3D:
			_append(child, transform, tool)

static func plant(scene: Node3D, asset: String, where: Vector3, width: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "V10Plant_" + asset
	var model := MeshInstance3D.new()
	model.mesh = mesh(asset + "_lod0")
	model.material_override = scene.vertex_plant_material
	model.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var box := model.mesh.get_aabb()
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.add_child(model)
	holder.position = where
	holder.scale = Vector3.ONE * width / maxf(box.size.x, box.size.z)
	holder.rotation.y = scene.rng.randf_range(0, TAU)
	scene.add_child(holder)
	scene.model_lods.append({"node": model, "meshes": [model.mesh, mesh(asset + "_lod1"), mesh(asset + "_lod2")], "tier": 0})
	return holder

static func apply_slabs_and_rocks(scene: Node3D) -> void:
	var geometry: Node3D = scene.get_node("EnvironmentGeometry")
	var changed := 0
	for node in geometry.get_children():
		if not node is MeshInstance3D or not str(node.name).begins_with("RoadSlab_"):
			continue
		var box: AABB = node.mesh.get_aabb()
		if box.size.z > 1.16:
			continue
		var index := int(str(node.name).trim_prefix("RoadSlab_"))
		var variant := index % 5
		if index in [5, 32, 45]:
			variant = 5 + index % 2
		var source := mesh("slab_%d" % variant)
		var bounds := source.get_aabb()
		var scale := Vector3(box.size.x / bounds.size.x, 0.18 / bounds.size.y, box.size.z / bounds.size.z)
		var transform := Transform3D(Basis.IDENTITY.scaled(scale), box.get_center() - bounds.get_center() * scale)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.append_from(source, 0, transform)
		node.mesh = tool.commit()
		var material: ShaderMaterial = node.material_override.duplicate()
		material.set_shader_parameter("rune_enabled", 0.0)
		node.material_override = material
		scene.road_materials.append(material)
		changed += 1
	scene.set_meta("refined_slabs", changed)
	var stone := ShaderMaterial.new()
	stone.shader = load("res://render_v10/shaders/rock.gdshader")
	for i in range(4):
		var rock := MeshInstance3D.new()
		rock.name = "V10_Rock_%d" % i
		rock.mesh = mesh("rock_%d_lod0" % (i % 2))
		rock.material_override = stone
		rock.position = [Vector3(-6.8, 0, -1.7), Vector3(1.8, 0, -1.65), Vector3(-3.4, 0, 1.7), Vector3(6.0, 0, 1.6)][i]
		rock.rotation.y = i * 2.399
		rock.scale = Vector3(0.85, 0.48, 0.68) * (0.85 + 0.10 * (i % 3))
		geometry.add_child(rock)
		for plant_node in geometry.get_children():
			if str(plant_node.name).begins_with("V10Plant_fern") and plant_node.position.distance_to(rock.position) < 0.5:
				plant_node.visible = false
	var column := MeshInstance3D.new()
	column.name = "V10_FallenColumn"
	column.mesh = mesh("fallen_column")
	column.material_override = stone
	column.rotation = Vector3(PI / 2, 0.4, 0)
	column.position = Vector3(-10.4, 0.25, -4.9)
	geometry.add_child(column)
