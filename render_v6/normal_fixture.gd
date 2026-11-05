extends Node3D
var camera: Camera3D
var shader_materials: Array[ShaderMaterial] = []
var reference: StandardMaterial3D
var report: Array[Dictionary] = []

func _ready() -> void:
	get_window().size=Vector2i(1280,512);get_window().content_scale_size=Vector2i(1280,512)
	get_viewport().debug_draw=ClassDB.class_get_integer_constant("Viewport","DEBUG_DRAW_NORMAL_BUFFER")
	var environment := WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_color=Color.BLACK;add_child(environment)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.0;camera.current=true;add_child(camera)
	var quad := QuadMesh.new();quad.size=Vector2(1.6,2.5)
	var arrays := quad.surface_get_arrays(0)
	var colors := PackedColorArray();colors.resize(arrays[Mesh.ARRAY_VERTEX].size());colors.fill(Color(0.2,0.33,0.065,1))
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	reference=StandardMaterial3D.new();reference.cull_mode=BaseMaterial3D.CULL_DISABLED;reference.vertex_color_use_as_albedo=true
	reference.normal_enabled=true;reference.normal_texture=load("res://model_v3/textures/leaf_normal.png")
	for index in range(5):
		var node := MeshInstance3D.new();node.mesh=mesh;node.position.x=-4+index*2;add_child(node)
		if index==0:node.material_override=reference
		else:
			var material := ShaderMaterial.new();material.shader=load("res://render_v6/model_foliage.gdshader")
			material.set_shader_parameter("leaf_normal",reference.normal_texture)
			material.set_shader_parameter("leaf_detail",load("res://model_v3/textures/leaf_detail.png"))
			material.set_shader_parameter("backface_rule",index-1);node.material_override=material;shader_materials.append(material)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	for strength in [0.0,0.2,0.35]:
		reference.normal_scale=strength
		for material in shader_materials:material.set_shader_parameter("normal_strength",strength)
		for front in [true,false]:
			camera.position=Vector3(0,0,6 if front else -6);camera.look_at(Vector3.ZERO)
			await get_tree().process_frame;RenderingServer.force_draw(false)
			var capture := get_viewport().get_texture().get_image()
			var errors := []
			for rule in range(4):
				var error := 0.0;var samples := 0
				for u in [0.2,0.38,0.5,0.62,0.8]:
					for v in [0.18,0.31,0.47,0.65,0.81]:
						var reference_point := camera.unproject_position(Vector3(-4+(u-0.5)*1.6,(v-0.5)*2.5,0))
						var candidate_point := camera.unproject_position(Vector3(-2+rule*2+(u-0.5)*1.6,(v-0.5)*2.5,0))
						var a := capture.get_pixelv(Vector2i(reference_point));var b := capture.get_pixelv(Vector2i(candidate_point))
						error+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);samples+=3
				errors.append(error/samples)
			report.append({"strength":strength,"front":front,"mean_abs_rgb":errors})
			capture.save_png("res://render_v6/captures/fixture_%s_%s.png"%[str(strength),"front" if front else "back"])
	var totals := [0.0,0.0,0.0,0.0]
	for entry in report:
		for rule in range(4):totals[rule]+=entry.mean_abs_rgb[rule]
	var winner := 0
	for rule in range(1,4):
		if totals[rule]<totals[winner]:winner=rule
	var file := FileAccess.open("res://render_v6/captures/normal_fixture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"selected_backface_rule":winner,"errors":totals,"cases":report},"  "))
	print("V6_FIXTURE_OK rule=",winner," errors=",totals);get_tree().quit()
