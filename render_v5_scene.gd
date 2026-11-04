extends "res://render_v4/interactive.gd"

var variant_name := "baseline"
var preferred_variant := "all"
var material_bindings: Array[Dictionary] = []
var wind_materials: Array[Dictionary] = []
var candidate_materials: Dictionary = {}
var environment_state: Dictionary = {}
var study_environment: Environment
var baseline_air: Material
var candidate_air: ShaderMaterial
var previous_wind := false

func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	DirAccess.make_dir_recursive_absolute("res://render_v5/captures")
	for node in get_children():
		if node is WorldEnvironment:study_environment=node.environment
	for key in ["ssao_radius","ssao_intensity","ssao_power","ssil_radius","ssil_intensity","volumetric_fog_detail_spread"]:environment_state[key]=study_environment.get(key)
	baseline_air=local_fog.material
	candidate_air=ShaderMaterial.new();candidate_air.shader=load("res://render_v5/forest_air.gdshader")
	_collect_materials(get_node("EnvironmentGeometry"))
	preferred_variant=_option("variant","all")
	_set_variant(preferred_variant)
	print("V5_VARIANT_READY ",JSON.stringify(_metadata()))

func _collect_materials(node: Node) -> void:
	if node.is_queued_for_deletion():return
	if node is MeshInstance3D and node.mesh:
		if node.material_override:_bind_material(node,-1,node.material_override)
		else:
			for surface in range(node.mesh.get_surface_count()):_bind_material(node,surface,node.get_active_material(surface))
	elif node is MultiMeshInstance3D:_bind_material(node,-1,node.material_override)
	for child in node.get_children():_collect_materials(child)

func _bind_material(node: GeometryInstance3D,surface: int,old: Material) -> void:
	if not old is ShaderMaterial or not old.shader:return
	var path: String=old.shader.resource_path
	if not path.ends_with("foliage.gdshader"):return
	var model := "model_foliage" in path
	var source_id := old.get_instance_id()
	var candidate := candidate_materials.get(source_id) as ShaderMaterial
	if not candidate:
		candidate=old.duplicate() as ShaderMaterial
		candidate.shader=load("res://render_v5/model_foliage.gdshader" if model else "res://render_v5/foliage.gdshader")
		candidate_materials[source_id]=candidate
		wind_materials.append({"material":candidate,"baseline":old,"model":model})
	material_bindings.append({"node":node,"surface":surface,"baseline":old,"candidate":candidate})

func _set_variant(value: String) -> void:
	variant_name=value
	var leaf := value in ["leaf","all"]
	for binding in material_bindings:
		var material: Material=binding.candidate if leaf else binding.baseline
		if binding.surface<0:binding.node.material_override=material
		else:binding.node.set_surface_override_material(binding.surface,material)
	for key in environment_state:study_environment.set(key,environment_state[key])
	local_fog.material=baseline_air
	if value in ["air","all"]:
		local_fog.material=candidate_air
		study_environment.volumetric_fog_detail_spread=0.7
	if value in ["contact","all"]:
		study_environment.ssao_radius=0.23
		study_environment.ssao_intensity=1.2
		study_environment.ssao_power=1.25
		study_environment.ssil_radius=1.6
		study_environment.ssil_intensity=0.38
	_version_title()

func _process(delta: float) -> void:
	super._process(delta)
	if previous_wind!=wind_enabled:
		previous_wind=wind_enabled
		for entry in wind_materials:
			var strength := (1.0 if entry.model else 0.018) if wind_enabled else 0.0
			entry.material.set_shader_parameter("wind_strength",strength)
			entry.baseline.set_shader_parameter("wind_strength",strength)

func _set_wind() -> void:
	# The inherited setup converts vertex-colored MultiMeshes to grass shaders.
	# Debris is also vertex-colored, but must retain its stone material/shadows.
	var debris := get_node_or_null("EnvironmentGeometry/RoadsideDebris") as MultiMeshInstance3D
	var material: Material=debris.material_override if debris else null
	var shadow: int=debris.cast_shadow if debris else 0
	super._set_wind()
	if debris:
		debris.material_override=material;debris.cast_shadow=shadow

func _version_title() -> void:
	get_window().title="遗迹环境 | RENDER V5 候选 | "+variant_name+" | F9 对照 V4"

func _add_camera_help() -> void:
	super._add_camera_help()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label:child.text=child.text.replace("RENDER V4","RENDER V5 候选")+"\nF9：候选 / 已锁定 V4 对照"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F9:
		_set_variant(preferred_variant if variant_name=="baseline" else "baseline");return
	super._unhandled_input(event)

func _save_still(tag: String,view: String) -> int:
	_ensure_visible();RenderingServer.force_draw(false)
	var path := "res://render_v5/captures/"+tag+"_"+view
	var error := get_viewport().get_texture().get_image().save_png(path+".png")
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(_metadata().merged({"view":view,"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width()}),"  "))
	print("V5_CAPTURE_OK ",path);return error

func _quality_benchmark() -> void:
	await load("res://render_v5/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://render_v5/audit.gd").motion(self)

func _smoke() -> void:
	if not await load("res://render_v5/toggle_audit.gd").run(self):await _finish(1);return
	await load("res://render_v5/audit.gd").smoke(self)

func _metadata() -> Dictionary:
	var result := super._metadata()
	result.version="RENDER V5 candidate";result["variant"]=variant_name
	if study_environment:result["fog_detail_spread"]=study_environment.volumetric_fog_detail_spread
	result["baseline_bake_reused"]=true
	return result
