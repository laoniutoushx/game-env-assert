extends "res://afternoon_scene.gd"

func _save_still(tag: String,view: String) -> int:
	var result := super._save_still(tag,view)
	if result!=OK:return result
	return DirAccess.copy_absolute("res://afternoon/captures/%s_%s.png"%[tag,view],"res://afternoon_v2/captures/baseline_top.png")
