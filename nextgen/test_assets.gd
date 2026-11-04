extends Node

func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://nextgen/assets/catalog.json"))
	for asset_name in catalog.scenes:
		var packed := load("res://nextgen/assets/"+asset_name+".tscn") as PackedScene
		if not packed:push_error("Missing asset "+asset_name);get_tree().quit(1);return
		var instance := packed.instantiate()
		add_child(instance)
		await get_tree().create_timer(0.5).timeout
		if not _mesh_exists(instance):push_error("Empty asset "+asset_name);get_tree().quit(1);return
		print("NEXTGEN_ASSET_OK ",asset_name)
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)

func _mesh_exists(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh and node.mesh.get_surface_count()>0:return true
	for child in node.get_children():
		if _mesh_exists(child):return true
	return false
