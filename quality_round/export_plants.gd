extends SceneTree

func _initialize() -> void:
	var builder = load("res://quality_round/plants.gd")
	var variants := {"grass_blades":Color.TRANSPARENT,"daisy_white":Color(0.95,0.93,0.81),"wildflower_yellow":Color(0.88,0.65,0.12),"wildflower_pink":Color(0.75,0.35,0.48)}
	for name in variants:
		var root := Node3D.new()
		root.name = name
		root.set_meta("source","local procedural geometry; individual 3D stems, leaves and petals")
		var instance := MeshInstance3D.new()
		instance.mesh = builder.grass() if name=="grass_blades" else builder.flower(variants[name])
		instance.material_override = builder.material()
		root.add_child(instance)
		instance.owner = root
		var scene := PackedScene.new()
		scene.pack(root)
		var error := ResourceSaver.save(scene,"res://quality_assets/"+name+".tscn")
		root.free()
		if error != OK:
			push_error("Plant export failed " + name)
			quit(1)
			return
		print("PLANT_EXPORTED ",name)
	quit()
