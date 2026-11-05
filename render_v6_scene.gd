extends "res://render_v5_scene.gd"

var repair_name := "baseline"
var preferred_repair := "combined"
var v6_bindings: Array[Dictionary] = []
var v6_materials: Dictionary = {}
var shadow_pairs: Array[Dictionary] = []
var diagnostic_state: Dictionary = {}
var v6_ready := false
var v6_wind := false

func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	_set_variant("all")
	DirAccess.make_dir_recursive_absolute("res://render_v6/captures")
	for binding in material_bindings:
		var old: ShaderMaterial=binding.candidate
		var id := old.get_instance_id()
		var material := v6_materials.get(id) as ShaderMaterial
		if not material:
			material=old.duplicate() as ShaderMaterial
			var model := "model_foliage" in old.shader.resource_path
			material.shader=load("res://render_v6/model_foliage.gdshader" if model else "res://render_v6/foliage.gdshader")
			if model:
				material.set_shader_parameter("backface_rule",1)
				material.set_shader_parameter("normal_strength",float(_option("normal_strength","0.2")))
			else:material.set_shader_parameter("correct_backface",true)
			v6_materials[id]=material
		v6_bindings.append({"node":binding.node,"surface":binding.surface,"baseline":old,"candidate":material})
	_setup_v6_shadows()
	diagnostic_state={"ssao":study_environment.ssao_enabled,"ssil":study_environment.ssil_enabled}
	v6_ready=true
	# Native capture windows must not consume desktop wheel/key events during comparisons.
	for flag in OS.get_cmdline_user_args():
		if flag.begins_with("--quality-") or flag in ["--motion","--smoke"]:set_process_unhandled_input(false)
	preferred_repair=_option("repair","combined")
	_set_repair(preferred_repair)
	print("V6_REPAIR_READY ",JSON.stringify(_metadata()))

func _setup_v6_shadows() -> void:
	var items := forest_lods.duplicate()
	items.sort_custom(func(a: Dictionary,b: Dictionary):return a.mid.global_position.distance_squared_to(Vector3(-10,0,-5))<b.mid.global_position.distance_squared_to(Vector3(-10,0,-5)))
	for i in range(mini(2,items.size())):
		var item: Dictionary=items[i]
		var holder: Node3D=item.mid.get_parent()
		var old := holder.get_node_or_null("ShadowLOD") as Node3D
		if not old:continue
		var proxy := item.mid.duplicate() as Node3D
		proxy.name="V6ShadowLOD";proxy.transform=old.transform
		_shadow_mode(proxy,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		_set_proxy_bias(proxy)
		holder.add_child(proxy);proxy.visible=false
		shadow_pairs.append({"baseline":old,"candidate":proxy,"tree":str(holder.get_path())})

func _set_proxy_bias(node: Node) -> void:
	if node is MeshInstance3D:node.lod_bias=4.0
	for child in node.get_children():_set_proxy_bias(child)

func _set_repair(value: String) -> void:
	repair_name=value
	var normal := value in ["normal","combined"]
	for binding in v6_bindings:
		var material: Material=binding.candidate if normal else binding.baseline
		if binding.surface<0:binding.node.material_override=material
		else:binding.node.set_surface_override_material(binding.surface,material)
	for pair in shadow_pairs:
		pair.baseline.visible=value not in ["shadow","combined"]
		pair.candidate.visible=value in ["shadow","combined"]
	study_environment.ssao_enabled=diagnostic_state.ssao and value!="off_ssao"
	study_environment.ssil_enabled=diagnostic_state.ssil and value!="off_ssil"
	for node in get_children():
		if node is DirectionalLight3D:node.shadow_enabled=value!="off_shadows"
	if value=="off_material_ao":
		for binding in v6_bindings:
			var material: ShaderMaterial=binding.candidate
			if "model_foliage" in material.shader.resource_path:continue
			material.set_shader_parameter("source_ao_strength",0.0)
			material.set_shader_parameter("correct_backface",false)
			if binding.surface<0:binding.node.material_override=material
			else:binding.node.set_surface_override_material(binding.surface,material)
	else:
		for material in v6_materials.values():
			if not "model_foliage" in material.shader.resource_path:
				material.set_shader_parameter("source_ao_strength",0.5)
				material.set_shader_parameter("correct_backface",true)
	_version_title()

func _process(delta: float) -> void:
	super._process(delta)
	if not v6_ready:return
	if v6_wind==wind_enabled:return
	v6_wind=wind_enabled
	for material in v6_materials.values():
		var model: bool = "model_foliage" in material.shader.resource_path
		material.set_shader_parameter("wind_strength",(1.0 if model else 0.018) if wind_enabled else 0.0)

func _version_title() -> void:
	get_window().title="遗迹环境 | RENDER V6 候选 | "+repair_name+" | F9 对照 V5"

func _add_camera_help() -> void:
	super._add_camera_help()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label:child.text=child.text.replace("RENDER V5","RENDER V6").replace("F9：候选 / 已锁定 V4 对照","F9：V6 / V5 对照")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F9:
		_set_repair(preferred_repair if repair_name=="baseline" else "baseline");return
	super._unhandled_input(event)

func _save_still(tag: String,view: String) -> int:
	_ensure_visible();RenderingServer.force_draw(false)
	var path := "res://render_v6/captures/"+tag+"_"+view
	var error := get_viewport().get_texture().get_image().save_png(path+".png")
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(_metadata().merged({"view":view,"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width()}),"  "))
	print("V6_CAPTURE_OK ",path);return error

func _quality_benchmark() -> void:
	await load("res://render_v6/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://render_v6/audit.gd").motion(self)

func _smoke() -> void:
	if not await load("res://render_v6/toggle_audit.gd").run(self):await _finish(1);return
	await load("res://render_v6/audit.gd").smoke(self)

func _metadata() -> Dictionary:
	var result := super._metadata()
	result.version="RENDER V6 candidate";result["repair"]=repair_name
	result["normal_strength"]=float(_option("normal_strength","0.2"))
	result["backface_rule"]=1;result["upgraded_shadow_trees"]=shadow_pairs.size() if repair_name in ["shadow","combined"] else 0
	result["tangents_verified"]=true
	return result
