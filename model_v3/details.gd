extends RefCounted

static func apply(scene: Node3D) -> void:
	if scene._option("geometry","refined")=="original":return
	var geometry := scene.get_node("EnvironmentGeometry")
	var engravings := [5,17,32,45]
	var refined := 0
	var water_levels: Array[float] = []
	var water_distances: Array[float] = []
	var bases: Array[Vector3] = [];var axes_u: Array[Vector3] = [];var axes_v: Array[Vector3] = []
	var bottom_maps: Array[Texture2D] = []
	for spot in scene.wet_spots:
		water_levels.append(0.0);water_distances.append(INF)
		bases.append(Vector3.ZERO);axes_u.append(Vector3.RIGHT);axes_v.append(Vector3.FORWARD);bottom_maps.append(null)
	for node in geometry.get_children():
		if not node is MeshInstance3D or not str(node.name).begins_with("RoadSlab_"):continue
		var m := node.material_override as ShaderMaterial
		if not m:continue
		var index := int(str(node.name).trim_prefix("RoadSlab_"))
		var wet: bool=m.get_shader_parameter("has_wet")==true
		if index not in engravings and not wet:continue
		var rune_image: Image
		if index in engravings:
			var rune := m.get_shader_parameter("rune_map") as Texture2D
			if rune:
				rune_image=rune.get_image()
				if rune_image.is_compressed():rune_image.decompress()
		var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var arrays: Array=node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		if wet:
			var corners := PackedVector3Array();var uv_targets := [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]
			for target: Vector2 in uv_targets:
				var best := INF;var chosen := Vector3.ZERO
				for k in range(vertices.size()):
					if vertices[k].y<0.09:continue
					var distance := uvs[k].distance_squared_to(target)
					if distance<best:best=distance;chosen=node.global_transform*vertices[k]
				corners.append(chosen)
			for vertex in vertices:
				if vertex.y<0.09:continue
				var world: Vector3=node.global_transform*vertex
				for i in range(scene.wet_spots.size()):
					var spot: Vector4=scene.wet_spots[i]
					var distance := Vector2(world.x-spot.x,world.z-spot.y).length_squared()
					if spot.z>0.5 and distance<water_distances[i]:
						water_distances[i]=distance;water_levels[i]=world.y-0.015
						bases[i]=corners[0];axes_u[i]=corners[1]-corners[0];axes_v[i]=corners[2]-corners[0]
						bottom_maps[i]=m.get_shader_parameter("base_map") as Texture2D
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(vertices.size()):indices.append(i)
		for t in range(0,indices.size(),3):
			var ids := [indices[t],indices[t+1],indices[t+2]]
			var top: bool=vertices[ids[0]].y>0.09 and vertices[ids[1]].y>0.09 and vertices[ids[2]].y>0.09
			var steps := 4 if top else 1
			for a in range(steps):
				for b in range(steps-a):
					var points := [Vector2(a,b),Vector2(a+1,b),Vector2(a,b+1)]
					_emit(tool,points,steps,ids,vertices,uvs,colors,rune_image,wet,scene.wet_spots,top,node.global_transform)
					if a+b<steps-1:
						_emit(tool,[Vector2(a+1,b),Vector2(a+1,b+1),Vector2(a,b+1)],steps,ids,vertices,uvs,colors,rune_image,wet,scene.wet_spots,top,node.global_transform)
		tool.index();tool.generate_normals();tool.generate_tangents();node.mesh=tool.commit()
		if rune_image:m.set_shader_parameter("rune_geometry",true)
		if wet:m.set_shader_parameter("water_enabled",0.0)
		refined+=1
	for i in range(scene.wet_spots.size()):
		# Two surface candidates failed visual review; retain the wet stone/basin only.
		if scene._option("water_surface","off")!="on":continue
		var spot: Vector4=scene.wet_spots[i]
		if spot.z<0.5:continue
		var water := MeshInstance3D.new();water.name="ShallowWater_%d"%i
		var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in range(64):
			for ring in [Vector2.ZERO,Vector2(cos(TAU*segment/64.0),sin(TAU*segment/64.0)),Vector2(cos(TAU*(segment+1)/64.0),sin(TAU*(segment+1)/64.0))]:
				var shape := _outline(atan2(ring.y,ring.x),float(i))
				tool.set_uv(ring*0.5+Vector2(0.5,0.5));tool.set_normal(Vector3.UP)
				var world := Vector3(spot.x+ring.x*0.30*shape,water_levels[i],spot.y+ring.y*0.35*shape)
				var delta := world-bases[i]
				var u := axes_u[i];var v := axes_v[i];var determinant := maxf(u.length_squared()*v.length_squared()-pow(u.dot(v),2),0.00001)
				tool.set_uv2(Vector2((delta.dot(u)*v.length_squared()-delta.dot(v)*u.dot(v))/determinant,(delta.dot(v)*u.length_squared()-delta.dot(u)*u.dot(v))/determinant))
				tool.add_vertex(geometry.to_local(world))
		tool.generate_tangents();water.mesh=tool.commit()
		var material := ShaderMaterial.new();material.shader=load("res://model_v3/water.gdshader")
		material.set_shader_parameter("stone_map",bottom_maps[i]);material.set_shader_parameter("seed",float(i))
		material.set_shader_parameter("wave_speed",1.0 if scene.wind_enabled else 0.0)
		water.material_override=material;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
		geometry.add_child(water)
	scene.set_meta("refined_slabs",refined)
	print("AFTERNOON_DETAILS slabs=",refined," real_basins=true")

static func _emit(tool: SurfaceTool,points: Array,steps: int,ids: Array,vertices: PackedVector3Array,uvs: PackedVector2Array,colors: PackedColorArray,rune: Image,wet: bool,spots: PackedVector4Array,top: bool,world_transform: Transform3D) -> void:
	for point: Vector2 in points:
		var w := Vector3(1.0-(point.x+point.y)/steps,point.x/steps,point.y/steps)
		var v: Vector3=vertices[ids[0]]*w.x+vertices[ids[1]]*w.y+vertices[ids[2]]*w.z
		var uv: Vector2=uvs[ids[0]]*w.x+uvs[ids[1]]*w.y+uvs[ids[2]]*w.z
		if top and rune:
			var height := rune.get_pixel(clampi(int(uv.x*(rune.get_width()-1)),0,rune.get_width()-1),clampi(int(uv.y*(rune.get_height()-1)),0,rune.get_height()-1)).r
			v.y-=height*0.012
		if top and wet:
			var world: Vector3=world_transform*v
			for i in range(spots.size()):
				var spot := spots[i]
				if spot.z<0.5:continue
				var p := Vector2((world.x-spot.x)/0.32,(world.z-spot.y)/0.37)
				var radial := p.length()/_outline(atan2(p.y,p.x),float(i))
				v.y-=(1.0-smoothstep(0.75,1.15,radial))*0.035/world_transform.basis.y.length()
		tool.set_uv(uv)
		tool.set_color(colors[ids[0]]*w.x+colors[ids[1]]*w.y+colors[ids[2]]*w.z if not colors.is_empty() else Color.WHITE)
		tool.add_vertex(v)

static func _outline(angle: float,seed: float) -> float:
	return 1.0+0.13*sin(angle*2.0+seed*0.7)+0.09*sin(angle*3.0+1.1+seed*0.2)+0.045*cos(angle*7.0+0.9)

