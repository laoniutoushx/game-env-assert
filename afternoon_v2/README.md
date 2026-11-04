# AFTERNOON v2

工程：`H:\game-workflow\work\environment_ruins\project.godot`

场景：`res://afternoon_v2.tscn`。运行 `open_v2.ps1` 可明确打开 v2，窗口标题含 `AFTERNOON v2`。旧版为 `afternoon.tscn`，旧编辑器中 F6 仍会运行当前打开的旧标签；请检查窗口标题。

- [实机对比与移动相机](review.html)
- [实施、取舍和剩余差距](report.md)
- [最终验收数据](validation.json)

右键旋转、WASD 平移、滚轮缩放、R 重置；F8 关闭/开启景深。检查光束请同时看左侧斜俯视和主视角，避免仅凭单张图判断空间效果。

重建：依次运行 `run_reviews.ps1 -Round Export`、`-Round Bake`、`-Round Perf`，再运行 `finish.ps1`。烘焙时勿修改资源，缓存指纹变动后需要重新导出和烘焙。
