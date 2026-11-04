extends SceneTree
func _initialize() -> void:
	for name in ["res://atmosphere_scene.gd","res://atmosphere/terrain.gd","res://atmosphere/audit.gd","res://atmosphere/coverage.gd","res://atmosphere/export_assets.gd","res://atmosphere/test_assets.gd","res://atmosphere/assets/tree_asset.gd"]:
		var script=load(name)
		if not script or not script.can_instantiate():push_error("Invalid "+name);quit(1);return
	var terrain=load("res://atmosphere/terrain.gd")
	for point in [Vector2(0,0),Vector2(3,-3.4),Vector2(-8.48,-3.4)]:
		if absf(terrain.height(point.x,point.y)+0.03)>0.001:push_error("Road terrain clearance");quit(1);return
	print("ATMOSPHERE_STATIC_OK")
	quit(0)
