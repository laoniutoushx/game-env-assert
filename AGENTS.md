# 场景迭代约定

- 当前默认基线入口为 **`res://render_v10.tscn`（RENDER V10 标准母材质与标杆阔叶树场景）**；历史 V1–V9 临时版本、脚本继承链与无用数据已彻底清理。
- 单资产与三风格母材质标杆实验室入口为 **`res://asset_lab/tree_comparison.tscn`**。
- 全场景植被统一搭载三风格标准母材质架构（`① 写实 PBR` / `② 风格化 PBR（默认）` / `③ 俯视卡通`），支持运行时 `F1 / F2 / F3` 实时切换。
- 每轮优化完成后，先完成实机对照与自动化验收（`-- --v10-audit` 与 `asset_lab/benchmark/tools/audit.gd`），再提交本轮修改到 Git。
