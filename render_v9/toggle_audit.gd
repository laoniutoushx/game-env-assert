extends RefCounted

static func run(scene: Node3D) -> bool:
	await scene.get_tree().create_timer(6.0).timeout
	var difference: Script=load("res://render_v8/toggle_audit.gd")
	var camera: Transform3D=scene.review_camera.global_transform
	var event := InputEventKey.new();event.pressed=true;event.keycode=KEY_F9
	scene._unhandled_input(event)
	if scene.foliage_mode!="baseline":push_error("F9 did not reach V8");return false
	for binding in scene.leaf_bindings:
		var active: Material=binding.node.material_override if binding.surface<0 else binding.node.get_active_material(binding.surface)
		if active!=binding.baseline:push_error("F9 did not restore original material");return false
	if not is_equal_approx(scene.sunlight.light_angular_distance,0.6):push_error("F9 sun mismatch");return false
	await scene.get_tree().create_timer(0.7).timeout
	scene._ensure_visible();RenderingServer.force_draw(false)
	var baseline: Image=scene.get_viewport().get_texture().get_image()
	scene._unhandled_input(event)
	if scene.foliage_mode!="combined":push_error("F9 did not reach V9");return false
	if not is_equal_approx(scene.sunlight.light_angular_distance,float(scene._option("sun_angle","0.3"))):push_error("V9 sun profile mismatch");return false
	for material in scene.leaf_materials.values():
		if "model_foliage" in material.shader.resource_path:
			for key in ["leaf_detail","leaf_normal"]:
				var texture: Texture2D=material.get_shader_parameter(key)
				if not texture.get_image().has_mipmaps():push_error("Missing candidate mipmaps");return false
	await scene.get_tree().create_timer(0.7).timeout
	RenderingServer.force_draw(false)
	var candidate: Image=scene.get_viewport().get_texture().get_image()
	scene._unhandled_input(event)
	await scene.get_tree().create_timer(0.7).timeout
	RenderingServer.force_draw(false)
	var restored: Image=scene.get_viewport().get_texture().get_image()
	var restore_error: float=difference._difference(baseline,restored)
	if restore_error>1.5 or not camera.is_equal_approx(scene.review_camera.global_transform):push_error("F9 restoration failed");return false
	scene._unhandled_input(event)
	var debris: MultiMeshInstance3D=scene.get_node("EnvironmentGeometry/RoadsideDebris")
	var old_material: Material=debris.material_override
	var old_shadow: int=debris.cast_shadow
	event.keycode=KEY_F5
	for enabled in [true,false]:
		scene._unhandled_input(event);scene._process(0.01)
		if scene.wind_enabled!=enabled:push_error("Wind state failed");return false
		for material in scene.leaf_materials.values():
			var model: bool="model_foliage" in material.shader.resource_path
			var expected := (1.0 if model else 0.018) if enabled else 0.0
			if absf(float(material.get_shader_parameter("wind_strength"))-expected)>0.0001:push_error("V9 wind sync failed");return false
		if debris.material_override!=old_material or debris.cast_shadow!=old_shadow:push_error("F5 changed debris");return false
	var old_width: float=scene._view_width()
	scene._set_width(11);scene._process(0.0)
	for width in [12.8,13.2,12.8,13.2]:
		scene._set_width(width);scene._process(0.0)
		for item in scene.model_lods:
			if item.tier!=0:push_error("Near LOD hysteresis failed");return false
	scene._set_width(26);scene._process(0.0)
	for width in [27.7,28.3,27.7,28.3]:
		scene._set_width(width);scene._process(0.0)
		for item in scene.model_lods:
			if item.tier!=1:push_error("Far LOD hysteresis failed");return false
	scene._set_width(old_width)
	var report := {"f9_baseline_restore":true,"camera_unchanged":true,"restored_mean_abs_8bit":restore_error,"candidate_difference_mean_abs_8bit":difference._difference(baseline,candidate),"wind_toggle":true,"lod_hysteresis":true,"mipmaps":true,"final_variant":scene.foliage_mode}
	var file := FileAccess.open("res://render_v9/captures/toggle_smoke.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("V9_TOGGLE_SMOKE_OK ",JSON.stringify(report));return true
