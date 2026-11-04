extends SceneTree
func _initialize() -> void:
	var kit=load("res://model_v3/models.gd")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://model_v3/assets/geometry_catalog.json"))
	DirAccess.make_dir_recursive_absolute("res://model_v3/scenes")
	var stone := StandardMaterial3D.new();stone.albedo_texture=load("res://model_v3/textures/stone_base.png")
	stone.normal_enabled=true;stone.normal_texture=load("res://model_v3/textures/stone_normal.png")
	stone.normal_scale=0.35;stone.roughness_texture=load("res://model_v3/textures/stone_roughness.png");stone.roughness=0.85
	stone.ao_enabled=true;stone.ao_texture=load("res://model_v3/textures/stone_ao.png");stone.vertex_color_use_as_albedo=true
	var rock := ShaderMaterial.new();rock.shader=load("res://model_v3/rock.gdshader")
	var checks := []
	for asset in catalog.assets:
		var root := Node3D.new();root.name=asset.name
		var instance := MeshInstance3D.new();instance.name="Geometry";instance.mesh=kit.mesh(asset.name)
		instance.material_override=kit.leaf_material() if asset.kind in ["fern","flowers","tree"] else (stone if asset.kind=="stone" else rock)
		root.add_child(instance);instance.owner=root
		var packed := PackedScene.new();packed.pack(root)
		var error := ResourceSaver.save(packed,"res://model_v3/scenes/"+asset.name+".tscn")
		if error!=OK:push_error("Asset scene save failed");quit(1);return
		var arrays: Array=instance.mesh.surface_get_arrays(0)
		checks.append({"name":asset.name,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"has_color":arrays[Mesh.ARRAY_COLOR]!=null,"has_uv2":arrays[Mesh.ARRAY_TEX_UV2]!=null,"scene":asset.name+".tscn"})
		root.free()
	var file := FileAccess.open("res://model_v3/assets/import_audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"  "))
	print("MODEL_ASSET_SCENES_OK ",checks.size());quit()
