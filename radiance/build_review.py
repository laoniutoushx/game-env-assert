from pathlib import Path
import json,re
p=Path(__file__).resolve().parent
def read(name):return json.loads((p/name).read_text(encoding='utf-8-sig'))
assets=read('assets/catalog.json')['adopted_scenes']
perf=[read(f'captures/perf_{i}_benchmark.json') for i in (1,2)]
metrics=read('captures/measurements.json');settings=read('settings.json')
old=(p.parent/'atmosphere/review.html').read_text(encoding='utf-8')
head=old[:old.index('<h1>')].replace('森林场景 · Godot 独立验收','暖光与湿润材质 · Godot 验收')
ui=old[old.index('<label>视图'):old.index('<h2>新增')]
options=[('compare','同机位前后拖动对比（左上一轮 / 右最终）'),('final_top.png','最终主视角 55°'),('final_left.png','左侧俯视 40°'),('final_side.png','右侧俯视 40°'),('final_low_side.png','低角度检查 32°'),('final_water.png','水坑近景'),('final_portal.png','出生门近景'),('baseline_top.png','阶段 0 · 上一轮基线'),('light_top.png','阶段 1 · 暖光与阴影'),('ground_top.png','阶段 2 · 道路与地面'),('wet_top.png','阶段 3 · 水面与出生门'),('final_top.png','阶段 4 · 最终'),('motion','移动相机 · 风动开'),('frozen','移动相机 · 风动关')]
ui=re.sub(r'<select id="view">.*?</select>','<select id="view">'+''.join(f'<option value="{value}">{label}</option>' for value,label in options)+'</select>',ui,flags=re.S)
ui=ui.replace('F5 风动','F5 风动、F6 花粉')
gallery=''.join(f'<figure><a href="assets/{a}"><img loading="lazy" src="captures/assets/{a}.png"></a><figcaption>{a}</figcaption></figure>' for a in assets)
script=old[old.index('<script>'):]
gain=metrics['photometry']['persistent_shadow_gain']*100
top=f'''<h1>暖光、湿润材质与环境融合 · 本轮验收</h1><p>真实 Godot Forward+ 渲染，原生 2K + 4×MSAA。两轮 600 帧移动测试 P95：<b>{perf[0]['p95_ms']:.3f} / {perf[1]['p95_ms']:.3f} ms</b>（RTX 3060）。暗部固定 ROI 线性亮度变化 {gain:+.1f}%。<b>尚未认定达到 90% 还原度。</b></p>
<p><a href="report.md">实施与剩余差距</a> · <a href="../../../reference_pic/Gemini_Generated_Image_vu1s3vu1s3vu1s3v.jpg">原概念图</a> · <a href="captures/measurements.json">亮度与遮挡测量</a> · <a href="validation.json">交付检查</a> · <a href="../atmosphere/review.html">上一轮验收</a> · <a href="../atmosphere/source_catalog.json">沿用资产来源</a></p>'''
(p/'review.html').write_text(head+top+ui+f'<h2>可复用资产 · {len(assets)} 项独立渲染</h2><p>水坑采用石板内的不透明薄水膜材质；无折射模拟。花粉默认按性能预算关闭，可用 F6 查看。</p><div class="gallery">'+gallery+'</div>'+script,encoding='utf-8')
table='\n'.join(f"| {name} | {data['road_plant_occlusion']*100:.2f}% |" for name,data in metrics['coverage'].items())
report=f'''# 暖光与湿润感迭代报告

本轮通过同机位阶段对照、侧俯视、近景及独立 Godot 移动验收。当前入口为 `radiance.tscn`，上一轮 `atmosphere.tscn` 保留。[打开交互对照](review.html)。尚未认定达到 90% 还原度。

## 已确认的根源

ACES、SSAO、Glow、SSR 和天空反射此前已启用。主要问题是阴影填充不足、地面过渡只匹配直路、水坑使用深色覆盖 mesh，以及湿润遮罩中心使用局部坐标、shader 却按世界坐标采样，导致场景缩放后错位。

## 最终实现

- 暖阳 `#FFE0AE`、能量 1.6，曝光 1.0、环境能量参数 0.44。当前使用 Sky 环境来源，实测单改 ambient_light_energy 不足以独立控制天空填充，因此按实际图像校准曝光与光色。首版 0.55 / 1.10 的暗部提亮过多，已收回。保留 ACES 和半分辨率 SSAO，未加重 AO。Glow 阈值 1.0、强度 0.30、Bloom 0。提高全局天空辐射的候选会过度提亮地面，未采用。
- 叶片轻微偏暖，树干不统一染色；路面提亮 6%。按实际路线的直段、半圆弯道及场景缩放生成 1024 道路距离遮罩，让苔藓过渡连续；泥土增加旋转纹理采样以打散重复。既有前景树向外移动 2 个场景单位，侧边树外移 1.6 单位，并清空出生门周围的植物穿插；植物移到外围，没有增加数量。
- 三处既有水坑整合到原石板材质，取消覆盖 mesh，统一使用世界坐标湿润遮罩。中心粗糙度 0.06、湿边 0.20，Metallic 0，湿石水膜采用标准 Specular 0.50；使用较暗的浅水中心、石底纹理、渐变湿边和微波纹。仅相交石板启用湿区计算，干燥区域跳过水坑三角函数。没有真实折射、流体或新的水体几何；25° 近景用于检查反射角度变化。
- 出生门金属部件增加真实倒角，粗糙度 0.42、金属度 0.65；发光强度 3，增加范围 2.5 m、无阴影的紫色局部点光。
- 实现 96 个低亮花粉粒子与 F6 开关；按预算默认关闭。保持三维植物、三档 LOD、现有风动；DOF、颗粒、暗角、GI、SSIL、体积雾均未启用。
- 使用既有低复杂度蕨类／灌木模型替换阴影代理，保留可见表面模型与贴图；主光保留 4096 图集、四级阴影和 45 m 覆盖范围，阴影软过滤使用中档。SSAO 保持半分辨率，改为中档采样和一次模糊。地面落叶材质只在实际参与混合的区域读取对应贴图，使用显式纹理梯度保持 mipmap 稳定。

## 性能筛选

最终配置：`{json.dumps(settings,ensure_ascii=False)}`。

RTX 3060，Forward+，原生 2560×1440、4×MSAA，两轮均为 6 秒预热 + 120 帧轨道预热 + 600 帧移动采样。

| 测试 | P50 | P95 |
| --- | --- | --- |
| 1 | {perf[0]['p50_ms']:.3f} ms | {perf[0]['p95_ms']:.3f} ms |
| 2 | {perf[1]['p50_ms']:.3f} ms | {perf[1]['p95_ms']:.3f} ms |

全效果、关闭花粉、降低探针分辨率等未通过候选保留在 `captures/trial_*.json` 和 Tune 日志中。探针分辨率属于 Godot 4 项目反射图集设置，并非 ReflectionProbe 节点属性。启用探针的候选在退出时产生 7 个纹理 RID 警告，原日志保留，不将其算作干净的资源验收。

最终默认关闭探针，保留天空反射与 24 步 SSR；花粉可手动启用。性能验收以最终配置的连续两轮结果为准。

水面补充一张离线烘焙的 256×256×6 Cubemap，来自本场景六个方向的真实渲染，带 mipmap，以曝光倍率 3 补充水面的反射辐射，不提高全场景环境填充，也不使用自发光伪造水面。运行时只在湿区读取一次反射纹理，没有持续更新探针。它是静态、单点的环境反射近似，不能反映后续模型移动或提供精确平面视差；SSR 补充当前屏幕中的细节。[Godot Cubemap](https://docs.godotengine.org/en/4.4/classes/class_cubemap.html)、[反射辐射接口](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)。

## 图像与遮挡验证

暗部 ROI 线性亮度变化 **{gain:+.2f}%**；路面与邻近裸地中位线性亮度比 **{metrics['photometry']['road_to_adjacent_ground_ratio']:.2f}**；接近纯白像素占比 **{metrics['photometry']['near_white_fraction']*100:.4f}%**。

暗部 ROI 由仅主光、灰材质、无环境光的通道确定：只比较前后均在阴影中、均分类为道路／裸地的同一批像素。基线最暗四分之一像素的原指标另行保留，因为移开植物会改变阴影覆盖，不能把它全部算作阴影填充变化。完整方法见 [测量记录](captures/measurements.json)。覆盖率仍是布局指标，不是概念图相似度。

| 视角 | 植物对道路遮挡 |
| --- | --- |
{table}

植物总数未增加。为让出道路与出生门，移位后的主机位外围／中间带投影覆盖约 {metrics['coverage']['top']['perimeter_plant_coverage']*100:.1f}% / {metrics['coverage']['top']['middle_belts_plant_coverage']*100:.1f}%，低于上一轮的 70.4% / 66.6%；这是本轮可读性取舍，不能继续沿用上一轮密度通过结论。

默认视角为 55°，左右正常侧视均为 40°；另外保留 32° 低角度检查，后者不计入正常相机遮挡 ≤8% 的通过条件。环绕序列包含更低视角，可直接观察遮挡与模型表现，并不保证任意视角都无遮挡。

出生门避让按植物实际三维包围盒检查，覆盖单独 Mesh、模型根节点和 MultiMesh 实例；最终检查区内植物相交数为 0。

已输出五阶段同机位对照、左右侧俯视、32° 检查、水坑及出生门近景、两组各 48 帧同轨迹风动开关序列、{len(assets)} 个独立资产预览，并检查投影切换、缩放、画质档及花粉开关。

## 操作、复现与边界

右键旋转、WASD 平移、滚轮缩放、R 复位；F1/F2 画质、F3 投影、F4 低角度检查、F5 风动、F6 花粉。手动启用花粉不属于最终性能保证配置。

`run_reviews.ps1 -Round Stages/Final/Coverage/Assets/Perf` 可分别重做阶段、视角与移动序列、分类图、资产渲染、两轮性能；`Reflection` 重烘焙反射（改变布局后需更新），`Tune` 按预算尝试 SSR 与探针取舍。`measure.py` 测量图像，`validate.py` 检查交付。

新功能通过 `--cut=...` 控制 grade、surface、wet、portal、probe、pollen、baked_reflection；cut 列表须包含需要保持关闭的 fog、ssil、gi。最终默认以 settings.json 为准，探针图集分辨率调整需重启工程。baked_reflection 是离线水面反射补充，和默认关闭的运行时 probe 分别控制。

石板重复、遗迹与传送门的整体造型、成熟树冠及植物排列自然度仍有明显差距。SSR 有屏幕边界限制，薄水膜不等同完整透明水体。未添加参考图中不存在的溪流／桥，未加入玩法单位。本轮没有下载或生成新模型，Meshy 新消耗 0，累计仍为 390/800。沿用资产来源见上一轮清单。

最终 GPU 验收日志与导入／headless 日志分别保存；后者仍包含本机根证书和编辑器用户设置权限警告，不将它们表述为已修复的引擎问题。
'''
(p/'report.md').write_text(report,encoding='utf-8')
print('REVIEW_BUILT',len(assets))
