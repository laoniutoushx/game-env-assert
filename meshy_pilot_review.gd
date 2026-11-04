extends Node3D

var camera: Camera3D
var yaw := 0.45
var pitch := 0.75
var distance := 13.0
var dragging := false
var target := Vector3(0, 1, 0)

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.25, 0.26, 0.22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.76, 0.69)
	environment.environment.ambient_light_energy = 0.8
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, -18)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(30, 30)
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.24, 0.24, 0.19)
	floor_mesh.material_override = ground
	add_child(floor_mesh)
	var args := OS.get_cmdline_user_args()
	for item in [["tree", -3.0, 4.5], ["shrub", 0.0, 1.9], ["slab", 3.0, 1.6]]:
		var option: String = "--" + item[0] + "="
		for arg in args:
			if arg.begins_with(option):
				_load_asset(arg.trim_prefix(option), item[1], item[2])
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.5
	add_child(camera)
	camera.current = true
	if "--focus-slab" in args:
		target = Vector3(3, 0.25, 0)
		camera.size = 3.0
	elif "--focus-shrub" in args:
		target = Vector3(0, 0.75, 0)
		camera.size = 3.5
	elif "--focus-tree" in args:
		target = Vector3(-3, 2, 0)
		camera.size = 5.5
	if "--side" in args:
		pitch = 0.28
	if "--back" in args:
		yaw += PI
	_update_camera()
	if "--capture" in args:
		await get_tree().create_timer(5.0).timeout
		var suffix := "side" if "--side" in args else "top"
		if "--back" in args:
			suffix += "_back"
		for name in ["tree", "shrub", "slab"]:
			if "--focus-" + name in args:
				suffix = name + "_" + suffix
		var prefix := "pilot"
		for arg in args:
			if arg.begins_with("--prefix="):
				prefix = arg.trim_prefix("--prefix=")
		get_viewport().get_texture().get_image().save_png("res://meshy_plan_b/" + prefix + "_" + suffix + ".png")
		get_tree().quit()

func _load_asset(path: String, x: float, max_size: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Missing or invalid asset: " + path)
		return
	var holder := Node3D.new()
	holder.position.x = x
	add_child(holder)
	var model := packed.instantiate() as Node3D
	holder.add_child(model)
	var bounds := _bounds(model, model)
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest < 0.0001:
		push_error("Asset has no visible geometry: " + path)
		return
	var factor := max_size / longest
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-bounds.get_center().x * factor, -bounds.position.y * factor, -bounds.get_center().z * factor)

func _bounds(root: Node3D, current: Node) -> AABB:
	var combined := AABB()
	var first := true
	var stack: Array[Node] = [current]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and node.mesh:
			var local_bounds: AABB = (root.global_transform.affine_inverse() * node.global_transform) * node.mesh.get_aabb()
			combined = local_bounds if first else combined.merge(local_bounds)
			first = false
		for child in node.get_children():
			stack.push_back(child)
	return combined

func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(3.0, camera.size * 0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(25.0, camera.size * 1.1)
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.006, 0.08, 1.45)
		_update_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		yaw = 0.45
		pitch = 0.75
		camera.size = 10.5
		_update_camera()
