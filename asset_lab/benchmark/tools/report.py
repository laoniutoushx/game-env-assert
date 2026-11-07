"""Assemble a local review document from actual Godot capture evidence."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
out=Path(__file__).resolve().parents[1]
r=out/'reports'
data=json.loads((r/'validation.json').read_text(encoding='utf-8'))
perf=data['performance']
stats=json.loads((r/'lods.json').read_text())
sheet=Image.new('RGB',(1152,2160),'#eeeeea');draw=ImageDraw.Draw(sheet)
for light in range(3):
    for camera in range(3):
        row=light*3+camera
        for style in range(3):
            path=r/f'style{style}_light{light}_camera{camera}.png'
            with Image.open(path) as im:tile=im.convert('RGB').resize((384,216))
            sheet.paste(tile,(style*384,row*240+24))
            draw.text((style*384+8,row*240+5),f'Style {style+1} | Light {light+1} | Camera {camera+1}',fill='black')
sheet.save(r/'contact_sheet.jpg',quality=95)
styles=['写实 PBR','风格化 PBR','俯视卡通']
figures=''.join(f'<figure><img src="reports/style{s}_light0_camera0.png"><figcaption>{styles[s]}</figcaption></figure>' for s in range(3))
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>阔叶树标杆 · 实机验收</title><style>
body{background:#ece9df;color:#25352a;max-width:1400px;margin:32px auto;font:16px/1.65 system-ui;padding:0 24px}h1{font-size:32px}section{margin:32px 0}article,.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}figure{margin:0;background:#fff;padding:8px;border-radius:8px}img,video{width:100%;display:block}figcaption{padding:8px}select{font:inherit;padding:6px;margin:8px}a{color:#31683b}.note{background:#fff9d9;padding:16px;border-left:4px solid #a48c3a}table{border-collapse:collapse}td,th{padding:8px 16px;border-bottom:1px solid #bcbfb5;text-align:left}@media(max-width:800px){article,.grid{grid-template-columns:1fr}}</style>
<h1>阔叶树标杆 · Godot 实机验收</h1><p>2026-11-07 · Godot 4.7.2 Forward+ / Vulkan · RTX 3060 · 2560×1440 · MSAA 4×</p>
<p class="note"><b>状态：WIP，可继续人工编辑。</b>结构、外部材质和切换检查通过，尚未达到概念图的成熟树冠与笔触质量。初始制作使用离线 Blender 辅助组装、可编辑节点烘焙，不宣称手工建模录像或真正手绘。</p>
<section><h2>同一几何，三种风格</h2><article>FIGURES</article></section>
<section><h2>原参考与新标杆</h2><div class="grid"><figure><img src="reports/original_polyhaven_reference.png"><figcaption>原 Poly Haven 参考，保留原风格材质</figcaption></figure><figure><img src="reports/style1_light0_camera0.png"><figcaption>新树：真实单叶、空间叶团与独立 PBR 材质</figcaption></figure><figure><img src="reports/style1_light0_camera1.png"><figcaption>新树：斜俯视</figcaption></figure></div></section>
<section><h2>27 组固定对照</h2><label>风格<select id="style"><option value="0">写实</option><option value="1" selected>风格化 PBR</option><option value="2">卡通</option></select></label><label>光照<select id="light"><option value="0">午后</option><option value="1">中性</option><option value="2">阴天</option></select></label><label>相机<select id="camera"><option value="0">整体</option><option value="1">俯视</option><option value="2">近景</option></select></label><img id="preview" src="reports/style1_light0_camera0.png"><p><a href="reports/contact_sheet.jpg">查看 27 图联系表</a></p></section>
<section><h2>连续环绕与轻风</h2><video controls preload="metadata" src="reports/orbit.mp4"></video><p>240 个连续引擎渲染帧，前半静态、后半轻风；按30FPS编码。风动使用实际引擎时间。视频播放帧率不是游戏性能。</p></section>
<section><h2>几何 LOD</h2><article>LODS</article><p>LOD2保留真实三维叶团，未用billboard。自动距离14m/28m，±8%滞回；仍可能观察到轮廓变化，正式游戏需按屏幕覆盖重新校准。</p></section>
<section><h2>灯光能量验证</h2><article>ENERGIES</article><p>关闭太阳后只保留环境补光；没有用自发光维持固定亮面。</p></section>
<section><h2>技术记录与剩余差距</h2><p>PERF</p><p>通过：9个风格/LOD组合的真实材质与纹理引用；15个旧参考组合加载；27组固定图；快捷键、复位、反复切换节点数量、LOD滞回。详见 <a href="reports/validation.json">原始记录</a>。</p><ul><li>树冠饱满度、自然枝干衔接及树皮UV过渡仍需人工艺术精修。</li><li>手绘风格目前使用节点烘焙底色，尚无真正的Krita手绘源稿。</li><li>36个表面保留独立叶团，便于教学；正式大量植树前还需评估合批、实例化与遮挡开销。</li><li>未对整张图给相似度百分比，也未用预算合格替代艺术验收。</li></ul><p>制作过程中的桌面工具不可用；Godot日志有系统证书访问提示，早期冷缓存还出现shader缓存写入提示。最终渲染与资源检查正常，未将这些环境提示伪称材质编译成功的证据。</p></section>
<p><a href="制作与跟做.md">人工跟做教程</a> · <a href="source/broadleaf_editable.blend">Blender 工程</a></p>
<script>for(const el of document.querySelectorAll('select'))el.addEventListener('change',()=>{document.querySelector('#preview').src=`reports/style${document.querySelector('#style').value}_light${document.querySelector('#light').value}_camera${document.querySelector('#camera').value}.png`;});</script></html>'''
lods=''.join(f'<figure><img src="reports/lod_{i}.png"><figcaption>LOD{i} · {stats[f"lod{i}"]:,} tris</figcaption></figure>' for i in range(3))
energies=''.join(f'<figure><img src="reports/sun_energy_{e:.1f}.png"><figcaption>Sun Energy {e:.1f}</figcaption></figure>' for e in [0.,.5,1.5])
html=html.replace('FIGURES',figures).replace('LODS',lods).replace('ENERGIES',energies).replace('PERF',f'单树180帧独立采样：帧间隔P95 {perf["wall_p95_ms"]:.3f}ms，GPU P95 {perf["gpu_p95_ms"]:.3f}ms。采样段无截图读回/编码，不代表完整游戏性能。')
(out/'review.html').write_text(html,encoding='utf-8')
(r/'FINAL.md').write_text(f'''# 本轮验收记录

完成：主干复用与局部修形，空间树冠重构，三风格外部材质，三套Inspector可编辑灯光，显式三维LOD，原生Blender工程，人工操作教程。

当前几何：{stats}。30个叶团、360片16三角面弯曲叶；LOD2是三维体积叶团。源工程24MB左右，打包六张贴图及两张场景。

测试：27组固定截图，15个旧参考组合，9个新组合外部材质/贴图/顶点色检查，240帧连续环绕，180帧无截图性能采样。快捷键、Home、重复切换及7组LOD滞回检查均通过。原始数值见validation.json。

实测：2560×1440，MSAA4，RTX3060，GPU P95 {perf['gpu_p95_ms']:.3f}ms，帧间隔P95 {perf['wall_p95_ms']:.3f}ms。仅单树验收台。

修复：无Sky却选择SKY补光导致暗面黑；旧风格关闭补光与灯光归一化的限制由新标杆PBR体系替代；真实Mesh表面显式外部tres；对象命名与导出稳定；关闭新模型自动简化LOD；LOD2删叶过稀的方案已替换；原15个风格场景重复几何约536MiB改为约24KiB的源引用。

制作说明：桌面自动化运行时无法启动，采用Blender离线辅助组装和节点烘焙。没有冒充手工制作或Krita笔触；没有使用付费生成。运行预览不执行模型构建工具。

艺术结论：WIP。树冠自然度、枝干连接、树皮过渡与真正手绘笔触仍有差距，不宣称达到概念图80%/90%或商业成品。LOD滞回通过不代表切换绝对不可见。36个可编辑表面尚未面向大场景合批。

范围：asset_lab。原工程默认入口继续由既有项目配置控制。灰模阶段提交bf839d9；本记录随最终资源提交。
''',encoding='utf-8')
print('Review page and contact sheet written; validation snapshots:',len(data['snapshots']))
