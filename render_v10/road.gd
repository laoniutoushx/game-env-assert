extends RefCounted

static func build(scene: Node3D) -> void:
	var route: Array[Vector3] = []
	for i in range(101):
		route.append(Vector3(8.8 - 17.28 * i / 100.0, 0, -3.4))
	for i in range(1, 65):
		var a := -PI / 2 - PI * i / 64.0
		route.append(Vector3(-8.48 + 1.7 * cos(a), 0, -1.7 + 1.7 * sin(a)))
	for i in range(1, 101):
		route.append(Vector3(-8.48 + 16.8 * i / 100.0, 0, 0))
	for i in range(1, 65):
		var a := -PI / 2 + PI * i / 64.0
		route.append(Vector3(8.32 + 1.7 * cos(a), 0, 1.7 + 1.7 * sin(a)))
	for i in range(1, 101):
		route.append(Vector3(8.32 - 17.28 * i / 100.0, 0, 3.4))
	scene.path_points.assign(route)
	var distances: Array[float] = [0.0]
	for i in range(1, route.size()):
		distances.append(distances[-1] + route[i].distance_to(route[i - 1]))
	var length: float = distances[-1]
	var joints: Array[float] = [0.0]
	var cursor := 0.0
	var k := 0
	var boundaries: Array[float] = [17.28, 17.28 + PI * 1.7, 34.08 + PI * 1.7, 34.08 + TAU * 1.7, length]
	while cursor < length - 0.001:
		var curved: bool = (cursor >= boundaries[0] - 0.001 and cursor < boundaries[1] - 0.001) or (cursor >= boundaries[2] - 0.001 and cursor < boundaries[3] - 0.001)
		var step: float = 0.69 if curved else [1.18, 1.50, 1.78, 1.30, 1.65][k % 5]
		var finish := minf(length, cursor + step)
		for boundary in boundaries:
			if boundary > cursor + 0.001:
				finish = minf(finish, boundary)
				if boundary - finish > 0.001 and boundary - finish < 0.45:
					finish = boundary
				break
		joints.append(finish)
		cursor = finish
		k += 1
	var count := joints.size() - 1
	for index in range(count):
		var start := joints[index]
		var finish := joints[index + 1]
		var slab := MeshInstance3D.new()
		slab.name = "RoadSlab_%02d" % index
		slab.mesh = _segment(route, distances, start + 0.012, finish - 0.012, -0.55, 0.55, 0.148, index, true)
		slab.material_override = scene.mats["slab%d" % ((index * 5 + index / 8) % 8)]
		scene.add_child(slab)
		for side in [-1, 1]:
			var curb := MeshInstance3D.new()
			curb.name = "Curb_%02d_%d" % [index, side]
			curb.mesh = _segment(route, distances, start + 0.007, finish - 0.007, side * 0.635 - 0.065, side * 0.635 + 0.065, 0.17, index, false)
			curb.material_override = scene.mats["slab%d" % ((index + 3) % 8)]
			scene.add_child(curb)
		if index in [8, 27, 43, 59]:
			var puddle := MeshInstance3D.new()
			puddle.mesh = scene._puddle_mesh()
			puddle.material_override = scene.mats.water
			puddle.position = _sample(route, distances, (start + finish) * 0.5) + Vector3(0, 0.150, 0)
			scene.add_child(puddle)

static func _sample(route: Array[Vector3], distances: Array[float], d: float) -> Vector3:
	d = clampf(d, 0, distances[-1])
	var lo := 0
	var hi := distances.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if distances[mid] < d:
			lo = mid
		else:
			hi = mid
	return route[lo].lerp(route[hi], (d - distances[lo]) / maxf(0.0001, distances[hi] - distances[lo]))

static func _point(route: Array[Vector3], distances: Array[float], d: float, across: float, height: float) -> Vector3:
	var center := _sample(route, distances, d)
	var direction := (_sample(route, distances, d + 0.025) - _sample(route, distances, d - 0.025)).normalized()
	return center + Vector3(-direction.z, 0, direction.x) * across + Vector3.UP * height

static func _height(u: float, v: float, top: float, index: int, detail: bool) -> float:
	var rim := minf(minf(u, 1 - u), minf(v, 1 - v))
	var h := top - (1 - smoothstep(0.0, 0.045, rim)) * 0.018
	h += sin(u * 4.2 + index) * sin(v * 3.8 + index * 0.7) * 0.0025
	if detail and index % 6 == 2:
		var groove := absf(v - (0.32 + u * 0.3 + 0.03 * sin(u * 12)))
		h -= (1 - smoothstep(0.012, 0.032, groove)) * 0.009 * smoothstep(0.08, 0.15, u) * (1 - smoothstep(0.8, 0.95, u))
	if detail and index % 7 == 3:
		var notch := Vector2((u - 0.2) * 1.2, v).length()
		h -= (1 - smoothstep(0.03, 0.16, notch)) * 0.035
	return h

static func _segment(route: Array[Vector3], distances: Array[float], start: float, finish: float, left: float, right: float, top: float, index: int, detail: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 32 if detail else 8
	var ny := 28 if detail else 3
	var color := Color(0.94 + 0.035 * sin(index * 3.1), 0.95 + 0.025 * sin(index * 3.1), 0.91 + 0.025 * sin(index * 3.1))
	for x in range(nx):
		for y in range(ny):
			var corners: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for t in [Vector2(float(x) / nx, float(y) / ny), Vector2(float(x + 1) / nx, float(y) / ny), Vector2(float(x + 1) / nx, float(y + 1) / ny), Vector2(float(x) / nx, float(y + 1) / ny)]:
				corners.append(_point(route, distances, lerpf(start, finish, t.x), lerpf(left, right, t.y), _height(t.x, t.y, top, index, detail)))
				uv.append(t if detail else Vector2(0.25 + t.x * 0.4, 0.45 + t.y * 0.08))
			_quad(st, corners, uv, color, Vector3.UP)
	var perimeter: Array[Vector2] = []
	for x in range(nx):
		perimeter.append(Vector2(float(x) / nx, 0))
	for y in range(ny):
		perimeter.append(Vector2(1, float(y) / ny))
	for x in range(nx):
		perimeter.append(Vector2(1 - float(x) / nx, 1))
	for y in range(ny):
		perimeter.append(Vector2(0, 1 - float(y) / ny))
	for i in range(perimeter.size()):
		var uv0 := perimeter[i]
		var uv1 := perimeter[(i + 1) % perimeter.size()]
		var a := _point(route, distances, lerpf(start, finish, uv0.x), lerpf(left, right, uv0.y), _height(uv0.x, uv0.y, top, index, detail))
		var b := _point(route, distances, lerpf(start, finish, uv1.x), lerpf(left, right, uv1.y), _height(uv1.x, uv1.y, top, index, detail))
		var bottom_a := Vector3(a.x, -0.04, a.z)
		var bottom_b := Vector3(b.x, -0.04, b.z)
		var normal := (b - a).cross(Vector3.DOWN).normalized()
		var u0 := float(i) / perimeter.size() * 2.0
		var u1 := float(i + 1) / perimeter.size() * 2.0
		_quad(st, [a, b, bottom_b, bottom_a], [Vector2(u0, 0.4), Vector2(u1, 0.4), Vector2(u1, 0.55), Vector2(u0, 0.55)], color.darkened(0.12), normal)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _quad(st: SurfaceTool, points: Array, uvs: Array, color: Color, outward: Vector3) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(outward) > 0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_uv(uvs[i])
		st.set_color(color)
		st.add_vertex(points[i])
