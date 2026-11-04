# 古迹环境：独立 Godot 场景工作流

当前默认入口为 **render_v4_live.tscn（已认可并锁定的 RENDER V4）**。使用原生 2560×1440、4×MSAA、真实遮挡体积散射、路径保护景深、烘焙间接光和动态日光阴影。V4 两轮 P95 为 32.362 / 31.972 ms，详见 [V4 实现记录](render_v4/README.md) 和 [验收数据](render_v4/validation.json)。

**RENDER V5 是独立候选**，入口 `render_v5.tscn`。基于 V4 小幅细化叶片背光、接触阴影与空气采样，按 F9 可在同一视角对照 V4。同期基线 P95 为 30.297 ms，V5 两轮为 30.111 / 30.328 ms，详见 [V5 记录](render_v5/README.md) 和 [验收数据](render_v5/validation.json)。不宣称达到概念图最终 90% 一致性。

本仓库使用 **Git LFS** 存储模型、贴图和大型生成场景。克隆前安装 Git LFS，克隆后执行 `git lfs pull`，再用 Godot 4.7.2 编辑器导入并打开 `project.godot`。`.godot` 缓存、工具虚拟环境和测试截图不进入版本库；验收页需要先在本机重跑对应 `run_reviews.ps1` 生成图片。资产来源与署名保留在下文及各资产目录。

右键旋转、WASD 平移、滚轮缩放、R 重置；**F8 切换电影展示 / 清晰检查**。在编辑器中使用 F5 运行项目，F6 会运行当前标签，旧 scene.tscn 仍是旧版。

## 前轮质量修复记录（Radiance）

Radiance 前轮使用 `radiance.tscn`，随后迭代至 `afternoon.tscn`。右键旋转、WASD 平移、滚轮缩放、R 重置；F1 预览、F2 原生 2K、F3 透视/正交、F4 低角度检查、F5 风动、F6 花粉。以下水面、资产与性能说明属于前轮历史记录；当前光影迭代的范围和结果以 V4/V5 记录为准。资产见 `radiance/assets/catalog.json`，原件与积分账本保留于前轮目录。

路径、植被和遗迹采用本地三维模型，植物的远处版本通过减面获得，仍是几何体，不是整株平面广告牌。若出现材质、背面、缝隙或性能问题，请以移动相机时的实际表现和对应截图为准。

本轮根因、修复、验证和剩余差距见 [质量报告](quality_round/root_cause_report.md)，可打开 [前后对照](quality_round/review.html) 查看截图。修复后的独立资产条目见 `quality_assets/catalog.json`。本轮新增 Meshy 消耗为 0。冻结基线为 `quality_baseline.tscn`。

## 入口

Godot 4.7.2 打开本目录的 `project.godot`，运行主场景。当前默认为小 FOV 透视相机，可切换正交投影。`scene.gd` 和 `meshy_trial.gd` 在运行时以固定随机种子生成场景；目前需修改脚本调整元素，编辑器中的场景树不是最终生成的布局。工程不依赖游戏工程，也不包含战斗逻辑。

在本机生成固定视角截图：

```powershell
& 'H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path 'H:\game-workflow\work\environment_ruins' -- --capture
```

输出 `review_capture.png`；参考为 `reference_pic/Gemini_Generated_Image_vu1s3vu1s3vu1s3v.jpg`。截图前应等待贴图和环境加载。项目目录需要可写。首次运行前用 Godot 编辑器导入贴图。

将末尾的 `--capture` 换成 `--capture-side` 或 `--capture-low` 可生成侧俯视图或低角度植物检查图。树木、灌木及蕨类均为三维模型；枝叶使用分布于三维空间中的透明叶片几何。草、石板、石柱和建筑为程序生成的三维简模。地面已扩展以改善镜头旋转时看到边界的问题。低角度检查中树冠仍显稀疏，尚未对所有角度及设备做全面验收。

## 可复用的制作与验收步骤

以下为早期制作与来源记录，所称主场景对应当时版本；当前状态、参数及验收结果以 V4/V5 报告为准。

1. 记录参考图、比例、镜头、光线、遮挡与取舍；标出道路与景物的主体位置。
2. 固定镜头及画幅，先以灰模核对大结构，再处理地形、道路和场景分区。
3. 按资源清单核对来源、许可证与质量；制作、导入或替换资源，保留母版与依赖。禁止把未经核验的第三方资产当作可分发素材。
4. 调整材质、光照和细节，固定参数渲染；每轮对照并记录差距。环境以外的 UI、角色、塔和护盾不计入评分，遮挡区只评价可推断部分。
5. 在独立 Godot 工程运行，检查加载、缺失依赖和画面错误，归档截图、对照、已知问题及人工评分。构图 30 分、材质 25 分、植被与遗迹 25 分、光照 20 分；目标总分 90，且每项至少达到该项满分的 80%。由人工确认，自动截图不代表视觉通过。

## 资源来源

场景几何与程序化材质由本工程脚本创建。`textures` 中 Ground003 与 Tiles130 贴图复制自本机 `work/demo/Asserts/materials`；名称和预览与 ambientCG 的 [Ground003](https://ambientcg.com/view?id=Ground003) 和 [Tiles130](https://ambientcg.com/view?id=Tiles130) 相符，官方页面标示 CC0。原始下载记录和文件校验值尚未找到，分发前应从官方来源重新下载或核对文件，以确认本地副本的来源。石块的八组贴图是用 `make_stone_variants.py` 从 Tiles130 派生。未使用 Demo 内其他第三方模型。

蕨类使用 [Poly Haven Fern 02](https://polyhaven.com/a/fern_02)，CC0；原始 glTF、依赖及透明蒙版通过官方清单的 MD5 校验。`prepare_fern.py` 将官方单独的透明蒙版与颜色贴图合并，生成适用于 Godot 的 glTF 副本；原始文件保留在 `fern_02`。

灌木使用 Poly Haven [Shrub 02](https://polyhaven.com/a/shrub_02)，CC0。此前的 [Tree Small 02](https://polyhaven.com/a/tree_small_02) 原始模型及约 109 万面测试版本保留在工程中，用于候选对照，但已不在主场景实例化。

主场景树木取自森林示例附带的 Sketchfab 资源，随附的 `license.txt` 标明 CC-BY 4.0，需保留以下署名。原页面本次访问返回 403，公开分发前仍需独立核验原站许可。

- “Pine Tree” by [evolveduk](https://sketchfab.com/evolveduk)，[原始模型](https://sketchfab.com/3d-models/pine-tree-d45218a3fab349e5b1de040f29e7b6f9)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。从森林示例中复制并重新导入模型内置材质。
- “Tree Bake Upload” by [restlessmonkey](https://sketchfab.com/restlessmonkey)，[原始模型](https://sketchfab.com/3d-models/tree-bake-upload-4e78d13152cf4214a256230765f6d6d3)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。从森林示例中复制；候选文件将叶片材质由 alpha blend 改为 alpha mask。
- 仅用于对照的 “Margarita flower bush” by [Maf'j Alvarez](https://sketchfab.com/blujay)，[原始模型](https://sketchfab.com/3d-models/margarita-flower-bush-c88faac7729b49e688dbc4d95f182168)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。重新导入了内置材质，不在主场景中使用。

参考示例、候选对照、截图及相机扫视测试详见 [研究与验证](../environment_research/研究与验证.md)。

`textures/woodland_shrub_ai_v1.png` 与 `textures/tree_crown_ai_v1.png` 使用内置 imagegen 创建，是先前的贴片试验素材，**当前场景不再使用**。提示词：

- “Create a production-ready photorealistic game foliage texture asset: one dense, low wild woodland shrub clump seen from directly above, approximately circular, made of distinct small fern fronds, fine grasses, tiny white and pale yellow wildflowers and moss. Natural irregular outline, richly detailed individual leaves, olive and deep green hues, sunlight-neutral, no cast shadow outside object. Isolated on genuinely transparent background, fills most of the frame with generous transparent margin. No ground, stones, text, border, pot, or other objects. Intended as an alpha-cutout ground vegetation decal for a 3D game.”
- “Production game asset, overhead top-down view of one mature evergreen woodland tree canopy, dense natural asymmetrical branches and small leaves, rich realistic deep forest green with lighter leaf tips, intricate natural foliage silhouette, no trunk visible, no ground, no cast shadow, neutral daylight, photorealistic. Isolated single tree crown on truly transparent background, margin all around, no text or frame. Intended for a 3D game's outdoor forest border.”

## 历史状态：早期布局版本（以下为旧记录）

这是可运行的布局与材质研究，不是 90% 成品。主场景使用较低面数的三维树木、灌木及蕨类，支持旋转镜头，并用 Forward+ 实际渲染。但树冠及外围植被仍稀疏，草仍为简化程序几何；道路仍明显重复，弯道的缝隙与重叠需要继续修整，刻字和破损还不够真实；石柱、陶罐、建筑和水坑缺少参考图中的造型及材质细节。植物分布、构图、色调和阴影也需要重新校准。未完成逐项人工评分或用户验收。

后续应优先用高质量、来源明确的植物和遗迹资源替换占位几何，重做道路模块及其 UV，补充损坏与雕刻细节，再依据固定视角逐轮调整光照与构图。Meshy 如需付费抽卡，应先确定任务和预算。


