extends SceneTree

func _initialize() -> void:
	var scene := Node3D.new()
	# Load scripts explicitly to catch parse errors before expensive GPU reviews.
	for path in ["res://nextgen_scene.gd","res://nextgen/road.gd","res://nextgen/plants.gd"]:
		var script = load(path)
		if not script or not script.can_instantiate():push_error("Invalid script "+path);quit(1);return
	var builder = load("res://nextgen/road.gd")
	var route: Array[Vector3] = [Vector3.ZERO,Vector3(1,0,0),Vector3(2,0,0)]
	var distances: Array[float] = [0.0,1.0,2.0]
	var mesh: ArrayMesh = builder._segment(route,distances,0.01,0.99,-0.55,0.55,0.148,2,true)
	var a := mesh.surface_get_arrays(0)
	if a[Mesh.ARRAY_TANGENT]==null or a[Mesh.ARRAY_TANGENT].is_empty():push_error("Road missing tangents");quit(1);return
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bad := 0
	for i in range(0,v.size(),3):
		if (v[i+1]-v[i]).cross(v[i+2]-v[i]).dot(n[i])>0.000001:bad+=1
	if bad:push_error("Incorrect road winding "+str(bad));quit(1);return
	print("NEXTGEN_GEOMETRY_OK triangles=",v.size()/3," tangent_and_winding_valid=true")
	scene.free()
	quit(0)
