extends "res://render_v4_scene.gd"
func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	var mode := _option("shadow_test","control")
	if mode=="control":return
	RenderingServer.directional_shadow_atlas_set_size(4096,false)
	for node in get_children():
		if not node is DirectionalLight3D:continue
		if mode=="single":node.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
		else:
			node.shadow_bias=0.06;node.shadow_normal_bias=1.0
	print("SHADOW_COMPARE ",mode)
