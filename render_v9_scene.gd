extends "res://render_v8_scene.gd"

var foliage_mode := "baseline"
var preferred_foliage := "combined"
var leaf_bindings: Array[Dictionary] = []
var leaf_materials: Dictionary = {}
var filtered_textures: Dictionary = {}
var shadow_meshes: Array[Dictionary] = []
var mesh_cache: Dictionary = {}
var frozen_lods: Array[Dictionary] = []
var stable_tiers: Dictionary = {}
var lod_events: Array[Dictionary] = []
var last_lod_signature := ""
var original_indirect: Dictionary = {}
var foliage_ready := false

func _initialize_atmosphere() -> void:
	super._initialize_atmosphere()
	super._set_shadow_profile("fine")
	DirAccess.make_dir_recursive_absolute("res://render_v9/captures")
	_collect_leaves(get_node("EnvironmentGeometry"))
	for tree in forest_lods:frozen_lods.append({"kind":"tree","entry":tree,"tier":tree.tier})
	for item in model_lods:frozen_lods.append({"kind":"plant","entry":item,"tier":item.tier})
	original_indirect={"ssao":study_environment.ssao_enabled,"ssil":study_environment.ssil_enabled}
	foliage_ready=true
	preferred_foliage=_option("foliage_mode","combined")
	_set_foliage_mode(preferred_foliage)
	if "--continuous" in OS.get_cmdline_user_args():
		set_process_unhandled_input(false)
		load("res://render_v9/continuous.gd").run.call_deferred(self)
	print("V9_FOLIAGE_READY ",JSON.stringify(_metadata()))

func _collect_leaves(node: Node) -> void:
	if node.is_queued_for_deletion():return
	if node is MeshInstance3D and node.mesh:
		if node.material_override:_bind_leaf(node,-1,node.material_override)
		else:
			for surface in range(node.mesh.get_surface_count()):_bind_leaf(node,surface,node.get_active_material(surface))
	elif node is MultiMeshInstance3D:_bind_leaf(node,-1,node.material_override)
	for child in node.get_children():_collect_leaves(child)

func _bind_leaf(node: GeometryInstance3D,surface: int,source: Material) -> void:
	if not source is ShaderMaterial or not source.shader or not source.shader.resource_path.ends_with("foliage.gdshader"):return
	var model: bool="model_foliage" in source.shader.resource_path
	var id := source.get_instance_id()
	var candidate := leaf_materials.get(id) as ShaderMaterial
	if not candidate:
		candidate=source.duplicate() as ShaderMaterial
		candidate.shader=load("res://render_v9/model_foliage.gdshader" if model else "res://render_v9/foliage.gdshader")
		leaf_materials[id]=candidate
	leaf_bindings.append({"node":node,"surface":surface,"baseline":source,"candidate":candidate,"model":model,"cast":node.cast_shadow})
	if node is MeshInstance3D and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		for record in shadow_meshes:
			if record.node==node:return
		shadow_meshes.append({"node":node,"baseline":node.mesh})

func _filtered(source: Texture2D,normal: bool) -> Texture2D:
	if not source:return null
	var key := str(source.get_instance_id())+str(normal)
	if filtered_textures.has(key):return filtered_textures[key]
	var pixels := source.get_image()
	if pixels.has_mipmaps():return source
	if pixels.is_compressed():pixels.decompress()
	pixels.generate_mipmaps(normal)
	var result := ImageTexture.create_from_image(pixels)
	filtered_textures[key]=result
	return result

func _fixed_mesh(source: Mesh) -> Mesh:
	var id := source.get_instance_id()
	if mesh_cache.has(id):return mesh_cache[id]
	if source.get_blend_shape_count()>0:return source
	var result := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface))
		result.surface_set_material(surface,source.surface_get_material(surface))
	mesh_cache[id]=result
	return result

func _surface_enabled() -> bool:
	return foliage_mode in ["surface","combined"]

func _lod_enabled() -> bool:
	return foliage_mode in ["lod","combined","lock_lod"]

func _shadow_lod_enabled() -> bool:
	return foliage_mode in ["lod","lock_lod"] or (foliage_mode=="combined" and _option("fixed_shadow","off")=="on")

func _set_foliage_mode(value: String) -> void:
	foliage_mode=value
	if not foliage_ready:return
	var surface := _surface_enabled()
	var custom := surface or value in ["no_specular","no_normals"]
	for binding in leaf_bindings:
		var candidate: ShaderMaterial=binding.candidate
		candidate.set_shader_parameter("surface_features",surface)
		candidate.set_shader_parameter("leaf_roughness_floor",float(_option("leaf_floor","0.60")))
		candidate.set_shader_parameter("leaf_backlight_gain",1.15 if surface else 1.0)
		candidate.set_shader_parameter("leaf_specular_scale",0.0 if value=="no_specular" else 1.0)
		candidate.set_shader_parameter("normal_enabled",value!="no_normals")
		if binding.model:
			for key in ["leaf_detail","leaf_normal"]:
				var old: Texture2D=binding.baseline.get_shader_parameter(key)
				candidate.set_shader_parameter(key,_filtered(old,key=="leaf_normal") if surface else old)
		var material: Material=candidate if custom else binding.baseline
		if binding.surface<0:binding.node.material_override=material
		else:binding.node.set_surface_override_material(binding.surface,material)
		binding.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if value=="no_plant_shadow" else binding.cast
	for entry in shadow_meshes:entry.node.mesh=_fixed_mesh(entry.baseline) if _shadow_lod_enabled() else entry.baseline
	study_environment.ssao_enabled=original_indirect.ssao and value!="no_screen_indirect"
	study_environment.ssil_enabled=original_indirect.ssil and value!="no_screen_indirect"
	sunlight.light_angular_distance=float(_option("sun_angle","0.3")) if value in ["shadow","combined"] else 0.6
	var high := value in ["shadow","combined"] and _option("shadow_filter","medium")=="high"
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if high else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.directional_shadow_atlas_set_size(int(_option("shadow_atlas","4096")) if value in ["shadow","combined"] else 4096,false)
	sunlight.shadow_blur=float(_option("shadow_blur","1.0")) if value in ["shadow","combined"] else 1.0
	stable_tiers.clear()
	_version_title()

func _process(delta: float) -> void:
	# The inherited hard-threshold manager must not swap meshes and then immediately
	# swap them back inside the hysteresis band. Keep its other frame work unchanged.
	var managed_models: Array[Dictionary]=model_lods
	var manage := foliage_ready and _lod_enabled()
	if manage:model_lods=[]
	super._process(delta)
	if manage:model_lods=managed_models
	if not foliage_ready:return
	if _lod_enabled():
		for item in model_lods:
			var id: int=item.node.get_instance_id()
			var width := _view_width()
			# First selection must match V8 at the current camera width. Hysteresis
			# preserves a previous selection; it must not preserve the builder's LOD0.
			var initial := 0 if width<13.0 else (1 if width<28.0 else 2)
			var tier: int=stable_tiers.get(id,initial)
			if width<11.96:tier=0
			elif width>30.24:tier=2
			elif tier==0 and width>14.04:tier=1
			elif tier==2 and width<25.76:tier=1
			stable_tiers[id]=tier;item.tier=tier;item.node.mesh=item.meshes[tier]
	if foliage_mode=="lock_lod":
		for frozen in frozen_lods:
			var item: Dictionary=frozen.entry
			item.tier=frozen.tier
			if frozen.kind=="plant":item.node.mesh=item.meshes[item.tier]
			else:
				item.high.visible=item.tier==2;item.mid.visible=item.tier==1;item.low.visible=item.tier==0
	for id in leaf_materials:
		var candidate: ShaderMaterial=leaf_materials[id]
		var source := instance_from_id(id) as ShaderMaterial
		if source:
			var strength: Variant=source.get_shader_parameter("wind_strength")
			if candidate.get_shader_parameter("wind_strength")!=strength:candidate.set_shader_parameter("wind_strength",strength)
	var signature := ""
	for tree in forest_lods:signature+=str(tree.tier)
	for plant in model_lods:signature+=str(plant.tier)
	if signature!=last_lod_signature:
		last_lod_signature=signature;lod_events.append({"frame":Engine.get_process_frames(),"signature":signature})

func _version_title() -> void:
	get_window().title="遗迹环境 | RENDER V9 | "+foliage_mode+" | F9 对照 V8"

func _add_camera_help() -> void:
	super._add_camera_help()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label:child.text=child.text.replace("RENDER V8","RENDER V9").replace("F9：V8 / V7 对照","F9：V9 / V8 对照")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F9:
		_set_foliage_mode(preferred_foliage if foliage_mode=="baseline" else "baseline");return
	super._unhandled_input(event)

func _save_still(tag: String,view: String) -> int:
	_ensure_visible();RenderingServer.force_draw(false)
	var path := "res://render_v9/captures/"+tag+"_"+view
	var error := get_viewport().get_texture().get_image().save_png(path+".png")
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(_metadata().merged({"view":view,"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width()}),"  "))
	print("V9_CAPTURE_OK ",path);return error

func _quality_benchmark() -> void:
	await load("res://render_v9/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://render_v9/audit.gd").motion(self)

func _smoke() -> void:
	if not await load("res://render_v9/toggle_audit.gd").run(self):await _finish(1);return
	await load("res://render_v9/audit.gd").smoke(self)

func _metadata() -> Dictionary:
	var result := super._metadata()
	result.version="RENDER V9 candidate";result["foliage_mode"]=foliage_mode
	result["filtered_textures"]=filtered_textures.size();result["leaf_floor"]=float(_option("leaf_floor","0.60"))
	result["surface_features_active"]=_surface_enabled()
	result["shadow_filter"]=_option("shadow_filter","medium") if foliage_mode in ["shadow","combined"] else "medium"
	result["shadow_atlas"]=int(_option("shadow_atlas","4096")) if foliage_mode in ["shadow","combined"] else 4096
	result["lod_events"]=lod_events.size();result["fixed_shadow_meshes"]=shadow_meshes.size() if _shadow_lod_enabled() else 0
	return result
