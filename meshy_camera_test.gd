extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://meshy_trial.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var before: Vector3 = scene.camera_target
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	scene._unhandled_input(key)
	if scene.camera_target.distance_to(before) < 0.1:
		push_error("Camera movement did not update target")
		quit(1)
		return
	print("CAMERA_MOVEMENT_OK ", before, " -> ", scene.camera_target)
	key.keycode = KEY_R
	scene._unhandled_input(key)
	if scene.camera_target.distance_to(before) > 0.001:
		push_error("Camera reset did not restore target")
		quit(1)
		return
	print("CAMERA_RESET_OK")
	quit(0)
