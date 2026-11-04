extends Node3D
@export var model: PackedScene
@export var material_kind := "foliage"

func _ready() -> void:
	if not model: return
	var instance := model.instantiate()
	_apply(instance)
	add_child(instance)

func _apply(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		node.lod_bias = 100.0
		for i in range(node.mesh.get_surface_count()):
			var source := node.get_active_material(i) as StandardMaterial3D
			if not source: continue
			var material := ShaderMaterial.new()
			material.shader = load("res://quality_round/" + material_kind + ".gdshader")
			material.set_shader_parameter("base_map",source.albedo_texture)
			material.set_shader_parameter("normal_map",source.normal_texture)
			material.set_shader_parameter("orm_map",source.roughness_texture)
			if material_kind=="foliage":
				material.set_shader_parameter("species_tint",Color(0.82,0.92,0.76) if model.resource_path.contains("fern") else Color(0.66,0.76,0.64))
				var ao := model.resource_path.get_basename()+"_ao.png"
				if ResourceLoader.exists(ao):
					material.set_shader_parameter("has_ao",true)
					material.set_shader_parameter("ao_map",load(ao))
			else:
				material.set_shader_parameter("normal_depth",0.45)
			node.set_surface_override_material(i,material)
	for child in node.get_children(): _apply(child)
