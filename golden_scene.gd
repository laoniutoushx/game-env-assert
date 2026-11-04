extends "res://radiance_scene.gd"

var golden_enabled := true

func _initialize_atmosphere() -> void:
	golden_enabled=_option("sun","golden")!="baseline"
	super._initialize_atmosphere()
	_version_title()

func _grade() -> void:
	super._grade()
	for node in get_children():
		if node is DirectionalLight3D:
			node.rotation_degrees=Vector3(-28 if golden_enabled else -38,-135,0)
			if golden_enabled:
				node.light_color=Color("ffc56d")
				node.light_energy=2.7

func _version_title() -> void:
	get_window().title="遗迹环境 | GOLDEN v1 金色日光" if golden_enabled else "遗迹环境 | RADIANCE 对照（F7 返回金色日光）"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F7:
		golden_enabled=not golden_enabled
		_grade();_version_title();return
	super._unhandled_input(event)

func _add_camera_help() -> void:
	super._add_camera_help()
	for child in get_children():
		if child is CanvasLayer:
			for label in child.get_children():
				if label is Label:label.text="GOLDEN v1 | F7 sunlight A/B\n"+label.text

func _save_still(tag: String,view: String) -> int:
	var path := "res://golden/captures/"+tag+"_"+view
	var err := get_viewport().get_texture().get_image().save_png(path+".png")
	var f := FileAccess.open(path+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"golden":golden_enabled,"view":view,"output":str(get_viewport().get_texture().get_size()),"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width(),"projection":review_camera.projection},"  "))
	print("GOLDEN_CAPTURE_OK ",path)
	return err

func _quality_benchmark() -> void:
	await load("res://golden/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://golden/audit.gd").motion(self)

func _smoke() -> void:
	var event := InputEventKey.new();event.pressed=true;event.keycode=KEY_F7
	_unhandled_input(event)
	if golden_enabled:push_error("Golden comparison toggle failed");await _finish(1);return
	_unhandled_input(event)
	if not golden_enabled:push_error("Golden restore failed");await _finish(1);return
	await load("res://golden/audit.gd").smoke(self)
