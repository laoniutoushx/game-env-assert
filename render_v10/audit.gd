extends RefCounted

static func run(scene: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute("res://render_v10/captures")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in range(12):
		await scene.get_tree().process_frame

	var snapshots: Array[String] = []
	var poses := [
		["top", Vector3(0, 0, 0.8), 0.0, deg_to_rad(55.0), 24.0],
		["side", Vector3(0, 0, 0.8), 0.65, deg_to_rad(36.0), 25.0],
		["close", Vector3(-6.2, 0.8, -3.2), 0.35, deg_to_rad(28.0), 10.2]
	]

	for style in range(3):
		scene._apply_style(style)
		for pose in poses:
			var view_name: String = pose[0]
			if style != 1 and view_name == "close":
				continue
			scene.camera_target = pose[1]
			scene.orbit_yaw = pose[2]
			scene.orbit_pitch = pose[3]
			scene._set_width(pose[4])
			scene._update_all_lods(true)
			for f in range(4):
				await scene.get_tree().process_frame
			await RenderingServer.frame_post_draw
			var fname := "res://render_v10/captures/style%d_%s.png" % [style, view_name]
			var err := scene.get_viewport().get_texture().get_image().save_png(fname)
			assert(err == OK, "Failed to save " + fname)
			snapshots.append(fname)

	# Restore default style 1 (Stylized PBR) and default top-down overview
	scene._apply_style(1)
	scene.camera_target = Vector3(0, 0, 0.8)
	scene.orbit_yaw = 0.0
	scene.orbit_pitch = deg_to_rad(55.0)
	scene._set_width(24.0)
	scene._update_all_lods(true)

	# Verify LOD hysteresis across zoom sweep
	var widths := [9.5, 13.2, 16.0, 13.5, 29.0, 32.0, 27.5]
	var lod_tiers: Array[int] = []
	for w in widths:
		scene._set_width(w)
		scene._update_all_lods(false)
		lod_tiers.append(scene.forest_lods[0].tier)
	assert(lod_tiers == [0, 0, 1, 1, 1, 2, 2], "LOD hysteresis sequence mismatch: " + str(lod_tiers))

	# 120-frame uncapped performance benchmark
	scene._set_width(24.0)
	scene._update_all_lods(true)
	for w in range(15):
		await scene.get_tree().process_frame
	var wall_times: Array[float] = []
	var prev := Time.get_ticks_usec()
	for i in range(120):
		scene.orbit_yaw = 0.15 * sin(TAU * i / 120.0)
		scene._update_camera()
		await scene.get_tree().process_frame
		var now := Time.get_ticks_usec()
		wall_times.append((now - prev) / 1000.0)
		prev = now
	wall_times.sort()
	var report := {
		"version": "RENDER V10 baseline",
		"default_main_scene": ProjectSettings.get_setting("application/run/main_scene"),
		"trees_count": scene.forest_lods.size(),
		"plants_lod_count": scene.model_lods.size(),
		"lod_hysteresis_sequence": lod_tiers,
		"snapshots": snapshots,
		"frame_p50_ms": wall_times[wall_times.size() / 2],
		"frame_p95_ms": wall_times[int(wall_times.size() * 0.95)],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"gpu": RenderingServer.get_video_adapter_name()
	}
	var f := FileAccess.open("res://render_v10/validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("RENDER_V10_AUDIT_PASS ", JSON.stringify(report))
	for child in scene.get_children():
		if child is WorldEnvironment or child is FogVolume:
			child.queue_free()
	await scene.get_tree().process_frame
	await scene.get_tree().process_frame
	scene.get_tree().quit(0)
