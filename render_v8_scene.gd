extends "res://render_v7_scene.gd"

var shadow_profile := "baseline"
var preferred_shadow := "fine"
var sunlight: DirectionalLight3D
var original_shadow: Dictionary = {}

func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	DirAccess.make_dir_recursive_absolute("res://render_v8/captures")
	for node in get_children():
		if node is DirectionalLight3D:sunlight=node;break
	original_shadow={"normal_bias":sunlight.shadow_normal_bias,"bias":sunlight.shadow_bias,"angular_distance":sunlight.light_angular_distance}
	preferred_shadow=_option("shadow_profile","fine")
	_set_shadow_profile(preferred_shadow)
	print("V8_SHADOW_READY ",JSON.stringify(_metadata()))

func _set_shadow_profile(value: String) -> void:
	shadow_profile=value
	sunlight.shadow_normal_bias=original_shadow.normal_bias
	sunlight.shadow_bias=original_shadow.bias
	sunlight.light_angular_distance=original_shadow.angular_distance
	if value=="contact":
		sunlight.shadow_normal_bias=0.35;sunlight.shadow_bias=0.015
	elif value=="fine":
		sunlight.light_angular_distance=0.6
	_version_title()

func _version_title() -> void:
	get_window().title="遗迹环境 | RENDER V8 候选 | "+shadow_profile+" | F9 对照 V7"

func _add_camera_help() -> void:
	super._add_camera_help()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label:child.text=child.text.replace("RENDER V7","RENDER V8").replace("F9：V7 / V6 对照","F9：V8 / V7 对照")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F9:
		_set_shadow_profile(preferred_shadow if shadow_profile=="baseline" else "baseline");return
	super._unhandled_input(event)

func _save_still(tag: String,view: String) -> int:
	_ensure_visible();RenderingServer.force_draw(false)
	var path := "res://render_v8/captures/"+tag+"_"+view
	var error := get_viewport().get_texture().get_image().save_png(path+".png")
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(_metadata().merged({"view":view,"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width()}),"  "))
	print("V8_CAPTURE_OK ",path);return error

func _quality_benchmark() -> void:
	await load("res://render_v8/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://render_v8/audit.gd").motion(self)

func _smoke() -> void:
	if not await load("res://render_v8/toggle_audit.gd").run(self):await _finish(1);return
	await load("res://render_v8/audit.gd").smoke(self)

func _metadata() -> Dictionary:
	var result := super._metadata()
	result.version="RENDER V8 candidate";result["shadow_profile"]=shadow_profile
	if sunlight:
		result["shadow_normal_bias"]=sunlight.shadow_normal_bias
		result["shadow_bias"]=sunlight.shadow_bias
		result["sun_angular_distance"]=sunlight.light_angular_distance
	return result
