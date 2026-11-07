# 单树标杆与三风格验收台

打开 `res://asset_lab/tree_comparison.tscn`，按 F6。默认是新标杆的②风格化 PBR。B 返回新标杆；1–5 切换旧参考；F1–F3 切风格；L 换光；Tab 换机位；F5 风动；F8 缩小检查。右键＋WASD/QE 移动，Shift 加速，Ctrl 慢移，Home 复位。

- 原生工程：`benchmark/source/broadleaf_editable.blend`。
- 人工跟做：`benchmark/制作与跟做.md`。
- 实机对照、视频与验收：`benchmark/review.html`。
- 统一标准：`STYLE_SPEC.md`。
- 技术检查：`benchmark/tools/audit.gd`；完整 Vulkan 检查：运行本场景时追加 `-- --review`。

新增标杆为 7144 / 3778 / 1010 三角面，三个真实几何LOD。30个空间叶团，LOD0共360片圆润薄叶；整树无billboard，无预塑光柱，无固定黑圆接触贴花。所有外部材质都能在Inspector中修改，三套光照资源在 `benchmark/lighting`。

初始组装采用离线Blender工具，运行场景不生成树。六张贴图已打包进blend；叶片底色是可编辑节点烘焙，不宣称已经手绘。源文件保留一个整树场景和一个贴图烘焙场景。

状态：工程与资源检查通过，艺术质量仍为WIP；尚未达到用户概念图的成熟树冠、树皮衔接与笔触质量。旧五棵树仅作为reference，不能因Shader参数合规就当成正式资产。

树干/树皮来源：Poly Haven Tree Small 02，CC0，https://polyhaven.com/a/tree_small_02 ，https://polyhaven.com/license 。Meshy/Fab参考来源沿用项目原记录；本轮不把它们标为已完成商业许可审计。
