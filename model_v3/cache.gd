extends RefCounted

static func fingerprint() -> Dictionary:
	var result := {}
	for path in ["model_v3/models.gd","model_v3/model_foliage.gdshader","model_v3/rock.gdshader","model_v3/build_assets.py","model_v3/assets/geometry_catalog.json"]:
		result[path]=FileAccess.get_sha256("res://"+path)
	for path in ["model_v3_scene.gd","model_v3/settings.json","model_v3/details.gd","model_v3/refine.gd","model_v3/road.gdshader","model_v3/ground.gdshader","model_v3/foliage.gdshader","model_v3/sun_shaft.gdshader","model_v3/shaft_fog.gdshader"]:
		result[path]=FileAccess.get_sha256("res://"+path)
	for i in range(4):
		var path := "model_v3/textures/rune_%d.png"%i
		result[path]=FileAccess.get_sha256("res://"+path)
	return result

