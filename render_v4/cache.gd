extends RefCounted
static func fingerprint() -> Dictionary:
	var result: Dictionary=load("res://model_v3/cache.gd").fingerprint()
	for path in ["render_v4_scene.gd","render_v4/settings.json","model_v3/light_study.gd","model_v3/forest_air.gdshader","model_v3/study_ground.gdshader","model_v3/study_foliage.gdshader"]:
		result[path]=FileAccess.get_sha256("res://"+path)
	return result
