extends RefCounted

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for p in [a,b,c,a,c,d]:
		st.set_color(color)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(p)

static func grass() -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 87
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(32):
		var angle := random.randf_range(0,TAU)
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-direction.z,0,direction.x)
		var root := direction*random.randf_range(0.01,0.18)
		var h := random.randf_range(0.16,0.34)
		var bend := random.randf_range(0.10,0.25)
		var width := random.randf_range(0.016,0.032)
		var palette := [Color(0.06,0.14,0.018),Color(0.10,0.20,0.03),Color(0.16,0.24,0.05)]
		for part in range(5):
			var t0 := part/5.0
			var t1 := (part+1)/5.0
			var p0 := root+Vector3.UP*h*t0+direction*bend*t0*t0
			var p1 := root+Vector3.UP*h*t1+direction*bend*t1*t1
			_quad(st,p0-side*width*(1-t0),p0+side*width*(1-t0),p1+side*width*(1-t1),p1-side*width*(1-t1),palette[blade%3].lightened(t0*0.12))
	st.generate_normals()
	return st.commit()

static func flower(petal_color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.29
	# A bent, real stem and two pairs of leaves.
	for ring in range(8):
		var a := ring*TAU/8
		var b := (ring+1)*TAU/8
		_quad(st,Vector3(cos(a)*0.006,0,sin(a)*0.006),Vector3(cos(b)*0.006,0,sin(b)*0.006),Vector3(cos(b)*0.004+0.025,h,sin(b)*0.004),Vector3(cos(a)*0.004+0.025,h,sin(a)*0.004),Color(0.17,0.26,0.055))
	for leaf in range(4):
		var a := leaf*2.4
		var base := Vector3(0.01,0.10+leaf*0.045,0)
		var out := Vector3(cos(a),0.35,sin(a))
		var side := Vector3(-sin(a),0,cos(a))*0.026
		var mid := base+out*0.075
		var tip := base+out*0.15
		_quad(st,base,mid-side,tip,mid+side,Color(0.21,0.32,0.075))
	var center := Vector3(0.025,h,0)
	for petal in range(9):
		var angle := petal*TAU/9
		var out := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-out.z,0,out.x)
		for segment in range(4):
			var t0 := segment/4.0
			var t1 := (segment+1)/4.0
			var p0 := center+out*(0.012+t0*0.055)+Vector3.UP*(0.007*sin(t0*PI)-t0*t0*0.012)
			var p1 := center+out*(0.012+t1*0.055)+Vector3.UP*(0.007*sin(t1*PI)-t1*t1*0.012)
			var w0 := 0.012*sin(t0*PI*0.85+0.15)
			var w1 := 0.012*sin(t1*PI*0.85+0.15)
			_quad(st,p0-side*w0,p0+side*w0,p1+side*w1,p1-side*w1,petal_color.darkened((1-t0)*0.12))
	for i in range(12):
		var a := i*TAU/12
		var b := (i+1)*TAU/12
		st.set_color(Color(0.72,0.43,0.035))
		for p in [center+Vector3(0,0.009,0),center+Vector3(cos(b)*0.019,0.002,sin(b)*0.019),center+Vector3(cos(a)*0.019,0.002,sin(a)*0.019)]:
			st.set_uv(Vector2.ZERO)
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()

static func material() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.albedo_color = Color.WHITE
	result.roughness = 0.8
	result.metallic_specular = 0.18
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.backlight_enabled = true
	result.backlight = Color(0.02,0.04,0.008)
	return result

static func broadleaf() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in range(15):
		var a := leaf*2.39996
		var out := Vector3(cos(a),0,sin(a))
		var side := Vector3(-sin(a),0,cos(a))
		var length := 0.23+0.09*sin(leaf*2.1)
		for seg in range(6):
			var t0 := seg/6.0
			var t1 := (seg+1)/6.0
			var p0 := out*(0.02+t0*length)+Vector3.UP*(0.04+0.12*sin(t0*PI*0.8))
			var p1 := out*(0.02+t1*length)+Vector3.UP*(0.04+0.12*sin(t1*PI*0.8))
			var w0 := 0.075*sin(t0*PI)
			var w1 := 0.075*sin(t1*PI)
			var color := Color(0.11,0.22,0.045).lightened(0.04*t0)
			# Two folded halves produce a broad leaf with a raised central vein.
			_quad(st,p0-side*w0-Vector3.UP*0.012,p0,p1,p1-side*w1-Vector3.UP*0.012,color)
			_quad(st,p0,p0+side*w0-Vector3.UP*0.012,p1+side*w1-Vector3.UP*0.012,p1,color.darkened(0.07))
	st.generate_normals()
	return st.commit()
