extends SceneTree
func _initialize() -> void:
	for name in ["res://radiance_scene.gd","res://radiance/audit.gd","res://radiance/coverage.gd","res://radiance/export_assets.gd","res://radiance/test_assets.gd"]:
		var script=load(name)
		if not script or not script.can_instantiate():push_error("Invalid "+name);quit(1);return
	print("RADIANCE_STATIC_OK");quit(0)
