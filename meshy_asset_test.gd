extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _has_mesh(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh and node.mesh.get_surface_count() > 0:
		return true
	for child in node.get_children():
		if _has_mesh(child):
			return true
	return false

func _run() -> void:
	var file := FileAccess.open("res://meshy_assets/catalog.json", FileAccess.READ)
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	for item in catalog.assets:
		var path: String = "res://meshy_assets/" + item.scene
		var scene := load(path) as PackedScene
		if not scene:
			push_error("Missing asset scene " + path)
			quit(1)
			return
		var instance := scene.instantiate()
		if not _has_mesh(instance):
			push_error("No mesh in " + path)
			instance.free()
			quit(1)
			return
		instance.free()
		print("ASSET_OK ", item.id)
	quit(0)
