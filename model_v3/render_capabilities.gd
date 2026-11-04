extends SceneTree
func _initialize() -> void:
	var settings := {}
	for property in ProjectSettings.get_property_list():
		var key: String=property.name
		if "contact_shadow" in key or "directional_shadow" in key or "volumetric_fog" in key:settings[key]=ProjectSettings.get_setting(key)
	var light := DirectionalLight3D.new();var fields := {}
	for property in light.get_property_list():
		var key: String=property.name
		if "contact" in key or "fog" in key or "opacity" in key:fields[key]=light.get(key)
	light.free()
	print(JSON.stringify({"settings":settings,"light":fields},"  "));quit()
