extends "res://render_v6_scene.gd"

var canopy_enabled := true
var canopy_strength := 0.25
var crown_bindings: Array[Dictionary] = []
var crown_meshes: Array[MeshInstance3D] = []
var crown_materials: Dictionary = {}
var crown_wind := false

func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	DirAccess.make_dir_recursive_absolute("res://render_v7/captures")
	canopy_strength=float(_option("canopy_strength","0.25"))
	for tree in forest_lods:
		for tier in ["high","mid","low"]:_bind_crown(tree[tier])
	_set_canopy(_option("canopy","on")=="on")
	print("V7_CANOPY_READY ",JSON.stringify(_metadata()))

func _bind_crown(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		var leaf_found := false
		for surface in range(node.mesh.get_surface_count()):
			var old := node.get_active_material(surface) as ShaderMaterial
			if not old or not old.shader or old.shader.resource_path!="res://render_v6/foliage.gdshader":continue
			if float(old.get_shader_parameter("leaf_surface"))<0.5:continue
			var id := old.get_instance_id()
			var material := crown_materials.get(id) as ShaderMaterial
			if not material:
				material=old.duplicate() as ShaderMaterial
				material.shader=load("res://render_v7/foliage.gdshader")
				crown_materials[id]=material
			crown_bindings.append({"node":node,"surface":surface,"baseline":old,"candidate":material})
			leaf_found=true
		if leaf_found:
			node.set_instance_shader_parameter("canopy_center",node.mesh.get_aabb().get_center())
			crown_meshes.append(node)
	for child in node.get_children():_bind_crown(child)

func _set_canopy(enabled: bool) -> void:
	canopy_enabled=enabled
	for binding in crown_bindings:binding.node.set_surface_override_material(binding.surface,binding.candidate if enabled else binding.baseline)
	for node in crown_meshes:node.set_instance_shader_parameter("canopy_normal_mix",canopy_strength if enabled else 0.0)
	_version_title()

func _process(delta: float) -> void:
	super._process(delta)
	if crown_wind==wind_enabled:return
	crown_wind=wind_enabled
	for material in crown_materials.values():material.set_shader_parameter("wind_strength",0.018 if wind_enabled else 0.0)

func _version_title() -> void:
	get_window().title="遗迹环境 | RENDER V7 候选 | "+("树冠受光" if canopy_enabled else "V6 基线")+" | F9 对照 V6"

func _add_camera_help() -> void:
	super._add_camera_help()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label:child.text=child.text.replace("RENDER V6","RENDER V7").replace("F9：V6 / V5 对照","F9：V7 / V6 对照")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F9:
		_set_canopy(not canopy_enabled);return
	super._unhandled_input(event)

func _save_still(tag: String,view: String) -> int:
	_ensure_visible();RenderingServer.force_draw(false)
	var path := "res://render_v7/captures/"+tag+"_"+view
	var error := get_viewport().get_texture().get_image().save_png(path+".png")
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(_metadata().merged({"view":view,"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width()}),"  "))
	print("V7_CAPTURE_OK ",path);return error

func _quality_benchmark() -> void:
	await load("res://render_v7/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://render_v7/audit.gd").motion(self)

func _smoke() -> void:
	if not await load("res://render_v7/toggle_audit.gd").run(self):await _finish(1);return
	await load("res://render_v7/audit.gd").smoke(self)

func _metadata() -> Dictionary:
	var result := super._metadata()
	result.version="RENDER V7 candidate";result["canopy_enabled"]=canopy_enabled
	result["canopy_strength"]=canopy_strength;result["crown_meshes"]=crown_meshes.size()
	return result
