extends Node3D
@export var model: PackedScene

func _ready() -> void:
	var instance := model.instantiate()
	_configure(instance)
	add_child(instance)

func _configure(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		node.lod_bias=100
		for i in range(node.mesh.get_surface_count()):
			var old := node.get_active_material(i) as StandardMaterial3D
			if not old:continue
			var material := ShaderMaterial.new();material.shader=load("res://atmosphere/foliage.gdshader")
			material.set_shader_parameter("base_map",old.albedo_texture)
			material.set_shader_parameter("normal_map",old.normal_texture)
			material.set_shader_parameter("orm_map",old.roughness_texture)
			var kind := "leaves" if old.resource_name.contains("leaves") else ("branch" if old.resource_name.contains("branch") else "trunk")
			material.set_shader_parameter("base_map",load("res://atmosphere/textures/tree_"+kind+"_base"+(".png" if kind=="leaves" else ".jpg")))
			material.set_shader_parameter("normal_map",load("res://atmosphere/textures/tree_"+kind+"_normal.jpg"))
			material.set_shader_parameter("orm_map",load("res://atmosphere/textures/tree_"+kind+"_orm.jpg"))
			material.set_shader_parameter("species_tint",Color(0.95,0.98,0.92))
			material.set_shader_parameter("leaf_surface",1.0 if old.resource_name.contains("leaves") else 0.0)
			node.set_surface_override_material(i,material)
	for child in node.get_children():_configure(child)
