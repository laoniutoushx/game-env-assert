# 古迹环境：Render V10 标准母材质基线与标杆资产工程

当前项目默认主场景已切换并锁定为 **`res://render_v10.tscn`（RENDER V10）**，同时彻底清理了 V1–V9 历史过渡版本、14 层旧脚本继承链及无用数据，仅保留自包含的 `render_v10` 正式环境、共享底层资产（`textures/`、`meshy_assets/`、`shrub_02/`、`fab_candidates/`）以及 `asset_lab/` 标杆资产实验室。

---

## 一、核心架构与入口

### 1. 主场景：`res://render_v10.tscn`（默认 F5 启动）
- **自包含场景脚本**：[`render_v10_scene.gd`](render_v10_scene.gd) 及模块化构建器（[`terrain.gd`](render_v10/terrain.gd)、[`road.gd`](render_v10/road.gd)、[`plants.gd`](render_v10/plants.gd)、[`models.gd`](render_v10/models.gd)、[`audit.gd`](render_v10/audit.gd)）。
- **标杆阔叶树全量入场**：场景内 22 棵主乔木全部升级为 `asset_lab/benchmark/exports/broadleaf_lod0/1/2.glb` 标杆阔叶树，配备距离滞回 LOD（`LOD0 < 34m < LOD1 < 58m < LOD2`）与独立暗部投影网格 `ShadowLOD`。
- **三风格标准植被母材质**：
  - 全场景乔木、灌木（Shrub / Bramble / Hazel）、蕨类（Fern）、野花与草丛统一绑定 `render_v10/shaders/plant_pbr.gdshader`（风格 ①/②）与 `render_v10/shaders/plant_toon.gdshader`（风格 ③）及 `asset_lab/benchmark/materials/leaves_0..2.tres`、`bark_0..2.tres`。
  - 遵循**路径最亮（55–75% 明度）、植被三层明度（冷青绿暗部 $\rightarrow$ 翠绿中调 $\rightarrow$ 暖黄绿冠顶）、单一间接光 AO（`AO_LIGHT_AFFECT = 0.0`）**规范。

### 2. 标杆资产实验室：`res://asset_lab/tree_comparison.tscn`
- 用于单棵树与候选资产在三套光照（中性 / 下午暖光 / 阴天）、三个机位（塔防俯视 / 45° 斜视 / 近景）及 1/4 分辨率下的对照验收。
- 详见 [`asset_lab/benchmark/FINAL.md`](asset_lab/benchmark/FINAL.md) 与 [`asset_lab/benchmark/制作与跟做.md`](asset_lab/benchmark/制作与跟做.md)。

---

## 二、运行快捷键（`render_v10.tscn`）

| 按键 | 功能 |
|---|---|
| `F1` / `F2` / `F3` | 实时切换全场景植被渲染风格：`① 写实 PBR` / `② 风格化 PBR（默认）` / `③ 俯视卡通` |
| `L` | 循环切换三套标准光照：`下午暖光（默认）` / `中性参考光` / `阴天漫射光` |
| `1` / `2` / `3` / `R` | 切换机位：`1 塔防俯视主镜头` / `2 45° 侧视镜头` / `3 林下近景镜头` |
| `Tab` | 切换透视 / 正交相机 |
| `F4` | 切换原生 `2560×1440` / `1920×1080` |
| `F5` | 开关顶点风场摆动 |
| `F8` | 开关远景景深（DoF） |
| `鼠标右键 + WASD + 滚轮` | 自由飞行漫游与焦距缩放 |

---

## 三、自动化验收与截图命令

1. **执行 Render V10 全套自动化审计与多风格截图**：
   ```powershell
   & 'H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path 'H:\game-workflow\work\environment_ruins' 'res://render_v10.tscn' -- --v10-audit
   ```
   输出截图与报告位于 `render_v10/captures/` 及 `render_v10/validation.json`。

2. **执行标杆树技术指标审计**：
   ```powershell
   & 'H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path 'H:\game-workflow\work\environment_ruins' -s 'res://asset_lab/benchmark/tools/audit.gd'
   ```
