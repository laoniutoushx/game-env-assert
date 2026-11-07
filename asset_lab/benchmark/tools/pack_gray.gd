extends SceneTree
func _initialize():
 var n = load("res://asset_lab/benchmark/models/broadleaf_lod0.glb").instantiate()
 var m = StandardMaterial3D.new()
 m.albedo_color = Color(0.42,0.48,0.35)
 m.roughness = 0.9
 m.cull_mode = BaseMaterial3D.CULL_DISABLED
 ResourceSaver.save(m,"res://asset_lab/benchmark/gray.tres")
 bind(n,n,m)
 var packed = PackedScene.new()
 packed.pack(n)
 ResourceSaver.save(packed,"res://asset_lab/benchmark/gray_tree.tscn")
 n.free()
 quit()
func bind(n,root,m):
 if n != root:
  n.scene_file_path = ""
  n.owner = root
 if n is MeshInstance3D:
  n.material_override=m
  n.lod_bias=100.0
 for c in n.get_children():bind(c,root,m)
