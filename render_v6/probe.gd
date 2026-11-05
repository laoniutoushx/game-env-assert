extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://render_v6/captures")
	var kit=load("res://model_v3/models.gd")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://model_v3/assets/geometry_catalog.json"))
	var rows := []
	for entry in catalog.assets:
		if not entry.kind in ["fern","flowers"]:continue
		var mesh: ArrayMesh=kit.mesh(entry.name)
		for surface in range(mesh.get_surface_count()):
			var arrays: Array=mesh.surface_get_arrays(surface)
			var vertices: int=arrays[Mesh.ARRAY_VERTEX].size()
			var tangents: int=0 if arrays[Mesh.ARRAY_TANGENT]==null else arrays[Mesh.ARRAY_TANGENT].size()
			rows.append({"asset":entry.name,"vertices":vertices,"tangents":tangents,"valid":tangents==vertices*4})
	var constants: PackedStringArray=ClassDB.class_get_integer_constant_list("Viewport")
	var report := {"surfaces":rows,"normal_buffer_debug":"DEBUG_DRAW_NORMAL_BUFFER" in constants,"engine":Engine.get_version_info()}
	var file := FileAccess.open("res://render_v6/captures/probe.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("V6_PROBE_OK ",JSON.stringify(report));quit()
