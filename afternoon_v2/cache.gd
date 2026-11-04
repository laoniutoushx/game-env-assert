extends RefCounted

static func fingerprint() -> Dictionary:
	var result := {}
	for path in ["afternoon_v2_scene.gd","afternoon_v2/settings.json","afternoon_v2/details.gd","afternoon_v2/refine.gd","afternoon_v2/road.gdshader","afternoon_v2/ground.gdshader","afternoon_v2/foliage.gdshader","afternoon_v2/sun_shaft.gdshader","afternoon_v2/shaft_fog.gdshader"]:
		result[path]=FileAccess.get_sha256("res://"+path)
	for i in range(4):
		var path := "afternoon_v2/textures/rune_%d.png"%i
		result[path]=FileAccess.get_sha256("res://"+path)
	return result
