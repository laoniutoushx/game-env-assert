extends RefCounted

static func road_distance(x: float, z: float) -> float:
	var d := INF
	for segment in [[-8.48, 8.8, -3.4], [-8.48, 8.32, 0.0], [-8.96, 8.32, 3.4]]:
		d = minf(d, Vector2(x - clampf(x, segment[0], segment[1]), z - segment[2]).length())
	if x < -8.48:
		d = minf(d, absf(Vector2(x + 8.48, z + 1.7).length() - 1.7))
	if x > 8.32:
		d = minf(d, absf(Vector2(x - 8.32, z - 1.7).length() - 1.7))
	return d

static func height(x: float, z: float) -> float:
	var shoulder := smoothstep(0.8, 1.5, road_distance(x, z))
	var edge := 1.0 - smoothstep(12.0, 16.0, maxf(absf(x) * 0.8, absf(z)))
	return -0.03 + shoulder * edge * (0.11 + 0.07 * sin(x * 0.65 + z * 0.3) + 0.04 * cos(z * 0.9 - x * 0.24))

static func mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(160):
		for z in range(128):
			var points := [
				Vector2(-20 + x * 0.25, -16 + z * 0.25),
				Vector2(-20 + (x + 1) * 0.25, -16 + z * 0.25),
				Vector2(-20 + (x + 1) * 0.25, -16 + (z + 1) * 0.25),
				Vector2(-20 + x * 0.25, -16 + (z + 1) * 0.25)
			]
			for i in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = points[i]
				var dx := (height(p.x + 0.02, p.y) - height(p.x - 0.02, p.y)) / 0.04
				var dz := (height(p.x, p.y + 0.02) - height(p.x, p.y - 0.02)) / 0.04
				tool.set_normal(Vector3(-dx, 1, -dz).normalized())
				tool.set_uv((p + Vector2(20, 16)) / Vector2(40, 32))
				tool.add_vertex(Vector3(p.x, height(p.x, p.y), p.y))
	tool.generate_tangents()
	return tool.commit()
