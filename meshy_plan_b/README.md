# Meshy Plan B 场景资产

本批授权上限为 800 API 积分，独立于角色工作台预算。账本为 `ledger.sqlite3`；`actual` 为空表示费用未知，按 `reserved` 计入。已提交但状态未知的请求会阻止后续提交，不能直接重试。

首轮样品：`pilot_tree`、`pilot_shrub`、`pilot_slab`。其他类别在三项全部完成视觉与 Godot 多视角检查之前禁止提交；`pilot_review.json` 只在实际检查通过后建立。下载文件和 SHA-256 位于每个任务文件夹的 `archive.json`。原始模型不覆盖，优化版应另存。

常用命令（在工作区根目录）：

```powershell
.\.venv\Scripts\python.exe work/environment_ruins/meshy_plan_b.py status
.\.venv\Scripts\python.exe work/environment_ruins/meshy_plan_b.py poll
.\.venv\Scripts\python.exe work/environment_ruins/test_meshy_plan_b.py
```

`../meshy_pilot_review.tscn` 是独立审阅场景，可通过用户参数 `--tree=res://路径.glb`、`--shrub=...`、`--slab=...` 加载已导入模型。右键拖动旋转，滚轮缩放，R 重置；附加 `--capture` 或 `--capture --side` 可保存截图并退出。
