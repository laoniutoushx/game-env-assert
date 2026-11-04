extends RefCounted

static func benchmark(scene: Node3D) -> void:
	await scene.get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png("res://radiance/captures/"+scene._tag()+"_initial.png")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(scene.get_viewport().get_viewport_rid(),true)
	# Warm the whole visibility/LOD trajectory before measuring steady performance.
	for i in range(120):
		scene.orbit_yaw=TAU*i/120.0
		scene.orbit_pitch=deg_to_rad(35+25*sin(TAU*i/120.0))
		scene._set_width(21.23+7.72*sin(TAU*i/120.0))
		await scene.get_tree().process_frame
	var samples: Array[float] = []
	var gpu_samples: Array[float] = []
	var cpu_samples: Array[float] = []
	var before := Time.get_ticks_usec()
	for i in range(600):
		scene.orbit_yaw=TAU*i/600.0
		scene.orbit_pitch=deg_to_rad(35+25*sin(TAU*i/600.0))
		scene._set_width(21.23+7.72*sin(TAU*i/600.0))
		await scene.get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-before)/1000.0);before=now
		gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(scene.get_viewport().get_viewport_rid()))
		cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(scene.get_viewport().get_viewport_rid()))
	samples.sort()
	gpu_samples.sort();cpu_samples.sort()
	var report := {"samples":600,"warmup_seconds":6,"p50_ms":samples[300],"p95_ms":samples[570],"output":str(scene.get_viewport().get_texture().get_size()),"internal_scale":scene.get_viewport().scaling_3d_scale,"projection":scene.review_camera.projection,"cut":scene._option("cut",scene.atmosphere_settings.get("cut","")),"gpu":RenderingServer.get_video_adapter_name(),"draw_calls_last":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives_last":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	report["warmup_orbit_frames"]=120
	report["settings"]=scene.atmosphere_settings
	report["render_gpu_p95_ms"]=gpu_samples[570];report["render_cpu_p95_ms"]=cpu_samples[570]
	var file := FileAccess.open("res://radiance/captures/"+scene._tag()+"_benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("ATMOSPHERE_BENCHMARK ",JSON.stringify(report))
	await scene._finish(0)

static func motion(scene: Node3D) -> void:
	await scene.get_tree().create_timer(6.0).timeout
	var folder: String="res://radiance/captures/"+scene._tag()+"_motion"
	DirAccess.make_dir_recursive_absolute(folder)
	var poses: Array = []
	for i in range(48):
		scene.orbit_yaw=TAU*i/48.0
		scene.orbit_pitch=deg_to_rad(35+25*sin(TAU*i/48.0))
		scene._set_width(21.23+7.72*sin(TAU*i/48.0))
		scene._process(0.21)
		await scene.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var err: int=scene.get_viewport().get_texture().get_image().save_png(folder+"/%03d.png"%i)
		if err!=OK:push_error("Motion save failed");await scene._finish(1);return
		poses.append({"yaw":scene.orbit_yaw,"pitch":scene.orbit_pitch,"width":scene._view_width()})
	var f := FileAccess.open(folder+"/poses.json",FileAccess.WRITE);f.store_string(JSON.stringify(poses,"  "))
	print("ATMOSPHERE_MOTION_OK ",folder)
	await scene._finish(0)

static func smoke(scene: Node3D) -> void:
	await scene.get_tree().create_timer(6.0).timeout
	var event := InputEventKey.new();event.pressed=true
	var emitting: bool=scene.pollen.emitting if is_instance_valid(scene.pollen) else false
	event.keycode=KEY_F6;scene._unhandled_input(event)
	if scene.pollen.emitting==emitting:push_error("Pollen toggle failed");await scene._finish(1);return
	scene._unhandled_input(event)
	var target: Vector3=scene.camera_target
	event.keycode=KEY_W;scene._unhandled_input(event)
	if scene.camera_target.distance_to(target)<0.1:push_error("Pan failed");await scene._finish(1);return
	event.keycode=KEY_R;scene._unhandled_input(event)
	if scene.camera_target.distance_to(target)>0.001:push_error("Reset failed");await scene._finish(1);return
	var width: float=scene._view_width()
	var screen_before: Vector2=scene.review_camera.unproject_position(target+scene.review_camera.global_basis.x*3.0)
	event.keycode=KEY_F3;scene._unhandled_input(event)
	if absf(scene._view_width()-width)>0.01:push_error("Projection framing jump");await scene._finish(1);return
	var screen_after: Vector2=scene.review_camera.unproject_position(target+scene.review_camera.global_basis.x*3.0)
	if screen_before.distance_to(screen_after)>1.5:push_error("Actual projection target-plane mismatch");await scene._finish(1);return
	event.keycode=KEY_F3;scene._unhandled_input(event)
	var mouse := InputEventMouseButton.new();mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_WHEEL_UP
	scene._unhandled_input(mouse)
	if scene._view_width()>=width:push_error("Perspective zoom failed");await scene._finish(1);return
	event.keycode=KEY_R;scene._unhandled_input(event)
	for key in [KEY_F1,KEY_F2]:
		event.keycode=key;scene._unhandled_input(event)
		await scene.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var expected := Vector2i(1421,736) if key==KEY_F1 else Vector2i(2560,1440)
		if Vector2i(scene.get_viewport().get_texture().get_size())!=expected:push_error("Output mismatch");await scene._finish(1);return
	var report := {"camera_pan_reset":true,"projection_toggle_preserves_width":true,"perspective_zoom":true,"quality_output":[2560,1440],"preview_output":[1421,736],"forest_lod_groups":scene.forest_lods.size(),"terrain":scene.get_node("EnvironmentGeometry/TerrainGround").mesh.get_surface_count()>0,"credits":0}
	var wet_hosts := 0
	for node in scene.get_node("EnvironmentGeometry").get_children():
		if node is MeshInstance3D and node.material_override is ShaderMaterial:
			var m := node.material_override as ShaderMaterial
			if m.shader.resource_path=="res://radiance/road.gdshader" and m.get_shader_parameter("has_wet"):wet_hosts+=1
	if wet_hosts<3 or wet_hosts>9:push_error("Wet mask host mismatch");await scene._finish(1);return
	report["wet_host_slabs"]=wet_hosts;report["pollen_toggle"]=true
	report["portal_plant_intersections"]=scene._portal_obstructions()
	if report.portal_plant_intersections!=0:push_error("Plants intersect portal clearance");await scene._finish(1);return
	var file := FileAccess.open("res://radiance/captures/smoke.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("ATMOSPHERE_SMOKE_OK ",JSON.stringify(report))
	await scene._finish(0)
