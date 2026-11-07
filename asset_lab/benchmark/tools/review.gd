extends Node
var report={"renderer":"Forward+ Vulkan", "snapshots":[], "triangles":[], "motion_frames":0}
func frames(count):
 for i in count:await get_tree().process_frame
func screenshot(name):
 await RenderingServer.frame_post_draw
 var err=get_viewport().get_texture().get_image().save_png("res://asset_lab/benchmark/reports/"+name+".png")
 assert(err==OK,"Screenshot write failed")
 report.snapshots.append(name)
func measure(n):
 var count=0
 if n is MeshInstance3D:
  for i in n.mesh.get_surface_count():
   count+=n.mesh.surface_get_array_index_len(i)/3
   var mat=n.get_active_material(i)
   assert(mat!=null,"Unbound material")
   if "LeafClump" in n.name:
    assert(mat is ShaderMaterial)
    assert(mat.get_shader_parameter("base_map") is Texture2D)
    assert(mat.get_shader_parameter("normal_map") is Texture2D)
   else:
    assert(mat is ORMMaterial3D)
    assert(mat.albedo_texture!=null and mat.normal_texture!=null and mat.orm_texture!=null)
 for c in n.get_children():count+=measure(c)
 return count
func keypress(code):
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
 Input.parse_input_event(event);await frames(2)
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(1)
func test_input(v):
 await keypress(KEY_F1);assert(v.style_index==0)
 await keypress(KEY_F2);assert(v.style_index==1)
 await keypress(KEY_1);assert(v.tree_index==0)
 await keypress(KEY_B);assert(v.tree_index==-1)
 await keypress(KEY_L);assert(v.light_index==1)
 await keypress(KEY_TAB);assert(v.camera_index==1)
 var camera=v.get_node("Camera3D")
 var pose=camera.transform
 camera.position+=Vector3(1,0,0)
 await keypress(KEY_HOME);assert(camera.transform.is_equal_approx(pose))
 v.light_index=0;v.camera_index=0;v.apply_lighting();v.apply_camera()
 var before=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 for i in 12:
  v.style_index=i%3;v.refresh();await frames(2)
 var after=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 assert(after<=before+2,"Node count grows after repeated switching")
 report.input_checks={"F1_F2":true,"original_and_benchmark":true,"light_camera":true,"home":true,"node_count_before":before,"node_count_after":after}
func run(v):
 v.panel.visible=false
 await test_input(v)
 DirAccess.make_dir_recursive_absolute("res://asset_lab/benchmark/captures")
 report.reference_combinations=0
 for original in 5:
  for style in 3:
   v.tree_index=original;v.style_index=style;v.refresh()
   assert(v.tree.get_child_count()>0,"Empty reference scene")
   await frames(2)
   report.reference_combinations+=1
 v.tree_index=0;v.style_index=1;v.refresh();v.camera_index=0;v.apply_camera()
 await frames(15);await screenshot("original_polyhaven_reference")
 v.tree_index=-1
 for lod in 3:
  v.lod_index=lod;v.refresh()
  report.triangles.append(measure(v.tree))
 for i in 3:assert(report.triangles[i]>0 and report.triangles[i]<=[8000,4000,1500][i])
 v.lod_index=0
 for style in 3:
  v.style_index=style;v.refresh()
  for light in 3:
   v.light_index=light;v.apply_lighting()
   for camera in 3:
    v.camera_index=camera;v.apply_camera()
    await frames(12)
    await screenshot("style%d_light%d_camera%d"%[style,light,camera])
 v.style_index=1;v.light_index=0;v.camera_index=0
 v.apply_lighting();v.refresh();v.apply_camera()
 v.quarter=true;get_viewport().scaling_3d_scale=0.25
 await frames(15);await screenshot("quarter_resolution")
 get_viewport().scaling_3d_scale=1.0
 # Sun energy changes and rotation are evaluated with the same material/camera.
 for energy in [0.0,0.5,1.5]:
  v.get_node("Sun").light_energy=energy
  await frames(12);await screenshot("sun_energy_%.1f"%energy)
 v.apply_lighting()
 v.get_node("Sun").rotation_degrees.y+=180
 await frames(12);await screenshot("sun_reversed")
 v.apply_lighting()
 for lod in 3:
  v.lod_index=lod;v.refresh()
  v.get_node("Camera3D").position=Vector3(0,13,20)
  v.get_node("Camera3D").look_at(Vector3(0,2,0))
  await frames(12);await screenshot("lod_%d"%lod)
 v.lod_index=0;v.refresh()
 var cam=v.get_node("Camera3D")
 var motion_index=0
 for wind in [false,true]:
  v.wind=wind;v.set_wind(v.tree)
  for i in 120:
   var angle=float(i)*TAU/120
   cam.position=Vector3(cos(angle)*8,3.8,sin(angle)*8)
   cam.look_at(Vector3(0,2.1,0))
   await frames(1)
   report.motion_frames+=1
   await RenderingServer.frame_post_draw
   var motion=get_viewport().get_texture().get_image()
   motion.resize(1280,720,Image.INTERPOLATE_LANCZOS)
   motion.save_png("res://asset_lab/benchmark/captures/frame_%04d.png"%motion_index)
   motion_index+=1
   if i%20==0:await screenshot("orbit_%s_%03d"%[str(wind),i])
 # Measure without screenshot readback or file encoding.
 v.wind=false;v.set_wind(v.tree);v.camera_index=0;v.apply_camera()
 v.auto_lod=true
 report.lod_hysteresis=[]
 for pair in [[14.5,0],[15.3,1],[14.5,1],[12.5,0],[31.0,2],[27.0,2],[25.0,1]]:
  cam.position=Vector3(0,2,pair[0])
  await frames(3)
  assert(v.lod_index==pair[1],"LOD hysteresis failure")
  report.lod_hysteresis.append([pair[0],v.lod_index])
 v.auto_lod=false;v.lod_index=0;v.refresh();v.apply_camera()
 var rid=get_viewport().get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(rid,true)
 await frames(60)
 var wall=[];var gpu=[];var last=Time.get_ticks_usec()
 for i in 180:
  await frames(1)
  var now=Time.get_ticks_usec()
  wall.append((now-last)/1000.0);last=now
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
 wall.sort();gpu.sort()
 report.performance={"samples":180,"wall_p95_ms":wall[170],"gpu_p95_ms":gpu[170],"resolution":str(get_viewport().get_visible_rect().size),"note":"Single tree only; uncapped render, no screenshot readbacks in sampling loop."}
 var file=FileAccess.open("res://asset_lab/benchmark/reports/validation.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"\t"));file.close()
 print("BENCHMARK_REVIEW_PASS ",JSON.stringify(report.performance))
 get_tree().quit()
