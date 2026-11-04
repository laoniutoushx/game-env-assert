extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://scene.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var camera: Camera3D = scene.review_camera
	var original_position := camera.position
	var original_size := camera.size
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	scene._unhandled_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(80, 25)
	scene._unhandled_input(move)
	assert(camera.position.distance_to(original_position) > 0.1, "orbit did not move camera")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	scene._unhandled_input(wheel)
	assert(camera.size < original_size, "zoom did not change camera size")
	var reset := InputEventKey.new()
	reset.keycode = KEY_R
	reset.pressed = true
	scene._unhandled_input(reset)
	assert(camera.position.distance_to(original_position) < 0.001, "reset did not restore camera")
	assert(absf(camera.size - original_size) < 0.001, "reset did not restore zoom")
	print("CAMERA_SMOKE_OK")
	quit()
