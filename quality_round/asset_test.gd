extends Node

func _ready() -> void:
	call_deferred("_run")

func _has_mesh(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh and node.mesh.get_surface_count()>0:return true
	for child in node.get_children():
		if _has_mesh(child):return true
	return false

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://quality_assets/catalog.json"))
	var entries: Array = catalog.selected+catalog.additional_local_geometry
	for entry in entries:
		var packed := load("res://quality_assets/"+entry.scene) as PackedScene
		if not packed:push_error("Missing quality asset "+entry.scene);get_tree().quit(1);return
		var instance := packed.instantiate()
		add_child(instance)
		await get_tree().process_frame
		if not _has_mesh(instance):push_error("Empty quality asset "+entry.scene);get_tree().quit(1);return
		# Keep resources alive until shader compilation and renderer updates settle.
		await get_tree().create_timer(0.5).timeout
		print("QUALITY_ASSET_OK ",entry.id)
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)
