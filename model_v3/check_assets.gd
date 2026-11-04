extends SceneTree
func _initialize() -> void:
	var kit=load("res://model_v3/models.gd")
	var mesh: ArrayMesh=kit.mesh("fern_0_lod0")
	var a: Array=mesh.surface_get_arrays(0)
	print("COLOR ",a[Mesh.ARRAY_COLOR][0]," NORMAL ",a[Mesh.ARRAY_NORMAL][0]," BOUNDS ",mesh.get_aabb())
	quit()
