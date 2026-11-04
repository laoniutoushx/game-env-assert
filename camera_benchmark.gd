extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := (load("res://scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await create_timer(3.0).timeout
	var samples: Array[float] = []
	var max_primitives := 0.0
	var max_draws := 0.0
	var previous := Time.get_ticks_usec()
	for frame in range(360):
		scene.orbit_yaw = -0.7 + 1.4 * float(frame) / 359.0
		scene.orbit_pitch = deg_to_rad(20.0 + 45.0 * float(frame % 120) / 119.0)
		scene._update_camera()
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		max_primitives = maxf(max_primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		max_draws = maxf(max_draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	samples.sort()
	print("CAMERA_SWEEP frames=", samples.size(), " median_ms=", samples[samples.size() / 2], " p95_ms=", samples[int(samples.size() * 0.95)], " max_primitives=", max_primitives, " max_draw_calls=", max_draws)
	quit(0)
