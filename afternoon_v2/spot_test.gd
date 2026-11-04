extends SceneTree

func _initialize() -> void:
	_test.call_deferred()

func _test() -> void:
	root.content_scale_size=Vector2i(1600,900);root.size=Vector2i(1600,900)
	var world := Node3D.new();root.add_child(world)
	var environment := Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(0.025,0.035,0.045)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_energy=0.1
	environment.volumetric_fog_enabled=true;environment.volumetric_fog_density=0.025
	environment.volumetric_fog_length=20;environment.volumetric_fog_ambient_inject=0.0
	var env := WorldEnvironment.new();env.environment=environment;world.add_child(env)
	var cam := Camera3D.new();world.add_child(cam);cam.position=Vector3(6,5,9);cam.look_at(Vector3(0,2,0));cam.current=true
	var ground := MeshInstance3D.new();var plane := PlaneMesh.new();plane.size=Vector2(15,15);ground.mesh=plane
	world.add_child(ground)
	var spot := SpotLight3D.new();world.add_child(spot);spot.position=Vector3(0,6,0);spot.look_at(Vector3(0,0,0),Vector3.FORWARD)
	spot.spot_range=12;spot.spot_angle=15;spot.light_energy=2;spot.light_volumetric_fog_energy=20;spot.shadow_enabled=true
	var blocker := MeshInstance3D.new();var box := BoxMesh.new();box.size=Vector3(0.4,0.3,0.4);blocker.mesh=box;blocker.position=Vector3(0,4.5,0);world.add_child(blocker)
	await create_timer(5).timeout
	RenderingServer.force_draw(false)
	var err := root.get_texture().get_image().save_png("res://afternoon_v2/captures/spot_test.png")
	print("SPOT_TEST ",err)
	quit(0 if err==OK else 1)
