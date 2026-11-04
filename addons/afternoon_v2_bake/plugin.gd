@tool
extends EditorPlugin

func _enter_tree() -> void:
	if "--afternoon-v2-bake" in OS.get_cmdline_user_args():_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().create_timer(0.5).timeout
	EditorInterface.open_scene_from_path("res://afternoon_v2/assets/static_lighting.tscn")
	await get_tree().create_timer(3.0).timeout
	var root := EditorInterface.get_edited_scene_root()
	if not root or not root.has_node("AfternoonBounce"):
		push_error("Afternoon bake scene not open");get_tree().quit(1);return
	var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://afternoon_v2/settings.json"))
	for child in root.get_children():
		if child is DirectionalLight3D:
			child.light_color=Color(settings.sun_color);child.light_energy=settings.sun_energy
			child.rotation_degrees=Vector3(settings.sun_pitch,settings.sun_yaw,0)
		elif child is WorldEnvironment:child.environment.ambient_light_energy=settings.ambient_energy
	EditorInterface.edit_node(root.get_node("AfternoonBounce"))
	var bake_node := root.get_node("AfternoonBounce") as LightmapGI
	# A fresh target avoids hot-reimporting a texture currently used by this editor.
	var target := "res://afternoon_v2/assets/indirect_%d.lmbake"%Time.get_unix_time_from_system()
	ResourceSaver.save(LightmapGIData.new(),target)
	bake_node.light_data=load(target) as LightmapGIData
	bake_node.quality=LightmapGI.BAKE_QUALITY_MEDIUM
	bake_node.texel_scale=0.5
	bake_node.max_texture_size=2048
	ProjectSettings.set_setting("rendering/lightmapping/bake_quality/medium_quality_ray_count",128)
	ProjectSettings.set_setting("rendering/lightmapping/bake_quality/medium_quality_probe_ray_count",128)
	await get_tree().create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(2.0).timeout
	var button := _find_bake(EditorInterface.get_base_control())
	if not button:
		push_error("Lightmap editor bake control unavailable");get_tree().quit(1);return
	print("AFTERNOON_LIGHTMAP_BEGIN")
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	var gi := root.get_node("AfternoonBounce") as LightmapGI
	if not gi.light_data or gi.light_data.get_user_count()==0:
		push_error("Lightmap contains no baked users");get_tree().quit(1);return
	# Publish a separate runtime scene; never overwrite the scene open in the editor.
	var output := "res://afternoon_v2/assets/baked_runtime_%d.tscn"%Time.get_unix_time_from_system()
	var packed := PackedScene.new()
	if packed.pack(root)!=OK or ResourceSaver.save(packed,output)!=OK:
		push_error("Cannot save baked runtime scene");get_tree().quit(1);return
	var f := FileAccess.open("res://afternoon_v2/assets/bake.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"look_version":2,"source_sha256":load("res://afternoon_v2/cache.gd").fingerprint(),"users":gi.light_data.get_user_count(),"success":true,"bounces":gi.bounces,"directional":gi.directional,"data":gi.light_data.resource_path,"scene":output,"quality":gi.quality,"texel_scale":gi.texel_scale},"  "))
	print("AFTERNOON_LIGHTMAP_OK users=",gi.light_data.get_user_count())
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

func _find_bake(node: Node) -> Button:
	if node is Button and node.is_visible_in_tree():
		for connection in node.get_signal_connection_list("pressed"):
			var callback: Callable=connection.callable
			if callback.get_method()=="_bake" and callback.get_object().get_class()=="LightmapGIEditorPlugin":return node
	for child in node.get_children():
		var result := _find_bake(child)
		if result:return result
	return null
