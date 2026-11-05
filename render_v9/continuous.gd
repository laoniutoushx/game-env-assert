extends RefCounted

static func run(scene: Node3D) -> void:
	var clip: String=scene._option("clip","pan")
	var count := int(scene._option("frames","600"))
	var folder: String="res://render_v9/captures/"+scene._tag()+"_sequence"
	DirAccess.make_dir_recursive_absolute(folder)
	var sample_folder := folder+"/roi"
	DirAccess.make_dir_recursive_absolute(sample_folder)
	scene._ensure_visible()
	scene.camera_target=Vector3(-3,0.4,-0.4);scene.orbit_pitch=deg_to_rad(55);scene.orbit_yaw=0.2;scene._set_width(14)
	scene.wind_enabled=clip in ["wind","orbit"]
	scene._set_wind()
	# Simulation is captured at fixed 30 Hz; timing/performance is measured separately without readback.
	for i in range(90):await scene.get_tree().process_frame
	var records: Array = []
	var world: Node3D=scene.get_node("EnvironmentGeometry")
	var quad: Array[Vector3]=[]
	for p in [Vector3(-6,0.16,-0.46),Vector3(-3,0.16,-0.46),Vector3(-3,0.16,0.46),Vector3(-6,0.16,0.46)]:quad.append(world.global_transform*p)
	var event_start: int=scene.lod_events.size()
	if scene.foliage_mode=="lock_lod":
		for frozen in scene.frozen_lods:frozen.tier=frozen.entry.tier
	var before := Time.get_ticks_usec()
	for i in range(count):
		var t := float(i)/maxi(count-1,1)
		if clip=="pan":scene.camera_target=Vector3(-3+0.8*t,0.4,-0.4);scene._set_width(14)
		elif clip=="orbit":
			scene.orbit_yaw=TAU*t;scene.orbit_pitch=deg_to_rad(55+15*sin(TAU*t));scene._set_width(21.23+5*sin(TAU*t))
		elif clip=="lod":scene._set_width((13.0 if i<count/2 else 28.0)+0.5*sin(TAU*i/120.0))
		await RenderingServer.frame_post_draw
		var capture: Image=scene.get_viewport().get_texture().get_image()
		var corners: Array = []
		for p in quad:
			var screen: Vector2=scene.review_camera.unproject_position(p);corners.append([screen.x,screen.y])
		var bounds := Rect2(Vector2(corners[0][0],corners[0][1]),Vector2.ZERO)
		for corner in corners:bounds=bounds.expand(Vector2(corner[0],corner[1]))
		var rect := Rect2i(bounds.grow(5)).intersection(Rect2i(Vector2i.ZERO,capture.get_size()))
		if rect.size.x<16 or rect.size.y<16:push_error("Continuous ROI outside viewport");await scene._finish(1);return
		var roi := capture.get_region(rect)
		if roi.save_png(sample_folder+"/%04d.png"%i)!=OK:push_error("ROI save failed");await scene._finish(1);return
		if capture.save_jpg(folder+"/%04d.jpg"%i,0.94)!=OK:push_error("Video frame save failed");await scene._finish(1);return
		var now := Time.get_ticks_usec()
		records.append({"frame":i,"capture_ms":(now-before)/1000.0,"quad":corners,"roi_origin":[rect.position.x,rect.position.y],"pitch":scene.orbit_pitch,"yaw":scene.orbit_yaw,"width":scene._view_width(),"lod_signature":scene.last_lod_signature})
		before=now
	var file := FileAccess.open(folder+"/frames.json",FileAccess.WRITE);file.store_string(JSON.stringify(records))
	var meta: Dictionary=scene._metadata().merged({"clip":clip,"frames":count,"simulation_fps":30,"capture_observed_fps":Engine.get_frames_per_second(),"lod_events_during_clip":scene.lod_events.size()-event_start,"wind":scene.wind_enabled,"taa":scene.get_viewport().use_taa,"msaa":scene.get_viewport().msaa_3d})
	file=FileAccess.open(folder+"/metadata.json",FileAccess.WRITE);file.store_string(JSON.stringify(meta,"  "))
	print("V9_CONTINUOUS_OK ",folder)
	await scene._finish(0)
