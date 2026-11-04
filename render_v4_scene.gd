extends "res://model_v3/light_study.gd"

func _option(key: String,fallback: String) -> String:
	var defaults := {"lighting":"physical","lookstudy":"balanced","shadow_range":"fit"}
	return super._option(key,str(defaults.get(key,fallback)))

func _initialize_atmosphere() -> void:
	afternoon_config=JSON.parse_string(FileAccess.get_file_as_string("res://render_v4/settings.json"))
	super._initialize_atmosphere()
	RenderingServer.directional_shadow_atlas_set_size(4096,false)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM,true,0.5,2,50.0,300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(160,80)
	for node in get_children():
		if node is DirectionalLight3D:node.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	DirAccess.make_dir_recursive_absolute("res://render_v4/captures")
	_version_title()
	if "--v4-export-lighting" in OS.get_cmdline_user_args():load("res://render_v4/export_lighting.gd").run.call_deferred(self)

func _version_title() -> void:
	get_window().title="遗迹环境 | RENDER V4 | 真实遮挡体积光 | "+("展示" if cinema else "清晰验收")

func _load_lighting() -> void:
	if _cut("lightmap") or "--v4-export-lighting" in OS.get_cmdline_user_args():return
	if not FileAccess.file_exists("res://render_v4/assets/bake.json"):return
	var bake: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://render_v4/assets/bake.json"))
	if bake.source_sha256!=load("res://render_v4/cache.gd").fingerprint():
		push_error("V4 lighting cache stale");return
	lighting_cache=(load(bake.scene) as PackedScene).instantiate() as Node3D
	for child in lighting_cache.get_children():
		if child is Light3D or child is WorldEnvironment:child.free()
	add_child(lighting_cache)
	var static_count := 0
	for child in lighting_cache.get_node("StaticMeshes").get_children():
		child.gi_mode=GeometryInstance3D.GI_MODE_STATIC
		var original := get_node_or_null(NodePath(child.get_meta("source_path",""))) as GeometryInstance3D
		if not original:push_error("Missing cached source");continue
		original.visible=false;static_count+=1
	print("V4_STATIC_GI_OK ",static_count)

func _save_still(tag: String,view: String) -> int:
	_ensure_visible();RenderingServer.force_draw(false)
	var path := "res://render_v4/captures/"+tag+"_"+view
	var error := get_viewport().get_texture().get_image().save_png(path+".png")
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(_metadata().merged({"view":view,"pitch":orbit_pitch,"yaw":orbit_yaw,"width":_view_width()}),"  "))
	print("V4_CAPTURE_OK ",path);return error

func _quality_benchmark() -> void:
	await load("res://render_v4/audit.gd").benchmark(self)

func _motion_capture() -> void:
	await load("res://render_v4/audit.gd").motion(self)

func _smoke() -> void:
	await load("res://render_v4/audit.gd").smoke(self)

func _metadata() -> Dictionary:
	var result := super._metadata()
	result.version="RENDER V4"
	var suns := []
	for node in get_children():
		if node is DirectionalLight3D:suns.append({"color":node.light_color.to_html(),"energy":node.light_energy,"shadow_range":node.directional_shadow_max_distance,"fade_start":node.directional_shadow_fade_start,"fog_energy":node.light_volumetric_fog_energy,"shadow_mode":node.directional_shadow_mode})
		elif node is WorldEnvironment:
			var e: Environment=node.environment
			result["actual_environment"]={"ssao":e.ssao_enabled,"ssao_radius":e.ssao_radius,"ssil":e.ssil_enabled,"fog_length":e.volumetric_fog_length,"anisotropy":e.volumetric_fog_anisotropy,"ambient_energy":e.ambient_light_energy,"tonemap":e.tonemap_mode}
	result["actual_sun"]=suns
	return result
