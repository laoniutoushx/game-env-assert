extends "res://render_v4_scene.gd"
func _add_camera_help() -> void:
	super._add_camera_help()
	for layer in get_children():
		if not layer is CanvasLayer:continue
		for child in layer.get_children():
			if child is Label:child.text="RENDER V4 · 原生 2K · 真实遮挡体积光\n右键拖动：旋转 | WASD：平移 | 滚轮：缩放 | R：重置\nF8：景深展示 / 清晰验收 | F3：透视 / 正交 | F2：2K | F1：预览\nF5：风动 | F4：扩展检查角度"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_F7:return
	super._unhandled_input(event)
