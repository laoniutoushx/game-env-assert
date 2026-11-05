extends RefCounted

static func _difference(a: Image,b: Image) -> float:
	var left := a.duplicate() as Image;var right := b.duplicate() as Image
	left.resize(256,144,Image.INTERPOLATE_BILINEAR);right.resize(256,144,Image.INTERPOLATE_BILINEAR)
	left.convert(Image.FORMAT_RGB8);right.convert(Image.FORMAT_RGB8)
	var x := left.get_data();var y := right.get_data();var difference := 0.0
	for i in range(x.size()):difference+=absf(float(x[i])-float(y[i]))
	return difference/x.size()

static func run(scene: Node3D) -> bool:
	await scene.get_tree().create_timer(6.0).timeout
	var camera: Transform3D=scene.review_camera.global_transform
	var event := InputEventKey.new();event.pressed=true;event.keycode=KEY_F9
	scene._unhandled_input(event)
	if scene.canopy_enabled:push_error("F9 did not reach baseline");return false
	for pair in scene.shadow_pairs:
		if pair.baseline.visible or not pair.candidate.visible:push_error("Baseline shadow proxy restoration failed");return false
	await scene.get_tree().create_timer(0.7).timeout
	scene._ensure_visible();RenderingServer.force_draw(false)
	var baseline: Image=scene.get_viewport().get_texture().get_image()
	scene._unhandled_input(event)
	if not scene.canopy_enabled:push_error("F9 did not reach candidate");return false
	for pair in scene.shadow_pairs:
		if pair.baseline.visible or not pair.candidate.visible:push_error("Candidate shadow proxy switch failed");return false
	await scene.get_tree().create_timer(0.7).timeout
	RenderingServer.force_draw(false)
	var candidate: Image=scene.get_viewport().get_texture().get_image()
	scene._unhandled_input(event)
	await scene.get_tree().create_timer(0.7).timeout
	RenderingServer.force_draw(false)
	var restored: Image=scene.get_viewport().get_texture().get_image()
	var restore_error := _difference(baseline,restored)
	if restore_error>1.5:push_error("F9 failed visual restoration: "+str(restore_error));return false
	if not camera.is_equal_approx(scene.review_camera.global_transform):push_error("F9 moved camera");return false
	scene._unhandled_input(event)
	event.keycode=KEY_F5
	var debris: MultiMeshInstance3D=scene.get_node("EnvironmentGeometry/RoadsideDebris")
	var debris_material: Material=debris.material_override
	var debris_shadow: int=debris.cast_shadow
	for enabled in [true,false]:
		scene._unhandled_input(event);scene._process(0.01)
		if scene.wind_enabled!=enabled:push_error("Wind toggle state failed");return false
		for entry in scene.wind_materials:
			var expected := (1.0 if entry.model else 0.018) if enabled else 0.0
			if absf(float(entry.material.get_shader_parameter("wind_strength"))-expected)>0.0001:push_error("Candidate wind material mismatch");return false
		for material in scene.v6_materials.values():
			var model: bool="model_foliage" in material.shader.resource_path
			var expected := (1.0 if model else 0.018) if enabled else 0.0
			if absf(float(material.get_shader_parameter("wind_strength"))-expected)>0.0001:push_error("V6 wind mismatch");return false
		for material in scene.crown_materials.values():
			if absf(float(material.get_shader_parameter("wind_strength"))-(0.018 if enabled else 0.0))>0.0001:push_error("V7 crown wind mismatch");return false
		if debris.material_override!=debris_material or debris.cast_shadow!=debris_shadow:push_error("F5 changed debris");return false
	var report := {"f9_baseline_restore":true,"camera_unchanged":true,"restored_mean_abs_8bit":restore_error,"candidate_difference_mean_abs_8bit":_difference(baseline,candidate),"wind_toggle":true,"final_variant":scene.canopy_enabled}
	var file := FileAccess.open("res://render_v7/captures/toggle_smoke.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("V7_TOGGLE_SMOKE_OK ",JSON.stringify(report));return true
