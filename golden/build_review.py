from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,re,hashlib
p=Path(__file__).resolve().parent
def read(name):return json.loads((p/name).read_text(encoding='utf-8-sig'))
def rgb(name):return np.asarray(Image.open(p/'captures'/name).convert('RGB'))/255.
before=rgb('baseline_top.png');after=rgb('final_top.png')
ids=np.asarray(Image.open(p.parent/'radiance/captures/coverage_top_scene.png').convert('RGB'))
road=(ids[:,:,0]>180)&(ids[:,:,1]<80)&(ids[:,:,2]<80)
weights=np.array([.2126,.7152,.0722])
y0=before@weights;y1=after@weights
lit=road&(y0>=np.quantile(y0[road],.5))&(y1>=np.quantile(y1[road],.5))
ratio0=float(np.median(before[:,:,0][lit]/np.maximum(before[:,:,2][lit],.01)))
ratio1=float(np.median(after[:,:,0][lit]/np.maximum(after[:,:,2][lit],.01)))
white=float(np.mean(np.min(after,axis=2)>.98))
metrics={'method':'Same-camera visible road pixels, brighter half in both renders. Ratios are display-sRGB R/B and describe warmth, not reference-image similarity. Geometry and material textures unchanged.','sunlit_road_red_blue_before':ratio0,'sunlit_road_red_blue_after':ratio1,'warmth_ratio_gain':ratio1/ratio0-1,'sunlit_road_luma_ratio':float(np.median(y1[lit])/np.median(y0[lit])),'near_white_fraction':white}
(p/'measurements.json').write_text(json.dumps(metrics,indent=2),encoding='utf-8')
assert ratio1/ratio0>=1.1,metrics
assert white<.005 and metrics['sunlit_road_luma_ratio']>=.8,metrics
perf=[read(f'captures/perf_{i}_benchmark.json') for i in (1,2)]
checks={}
for round in ['Preview','Final','Perf']:
    m=read(f'last_{round}.json');assert m['success']
    for log in m['logs']:
        text=Path(log).read_text(encoding='utf-8-sig')
        assert not re.search(r'SCRIPT ERROR|SHADER ERROR|ERROR:|RIDs? of type .* leaked',text),log
    checks[round+'_logs']=len(m['logs'])
for r in perf:
    assert r['golden_sunlight'] and r['samples']==600 and r['p95_ms']<=33.3 and r['internal_scale']==1
checks['performance']=perf;checks['color_metrics']=metrics
for name in ['baseline_top','golden_top','final_top','final_left','final_side','final_low_side','final_water','final_portal']:
    assert Image.open(p/'captures'/f'{name}.png').size==(2560,1440)
assert len(list((p/'captures/final_motion').glob('*.png')))==48
smoke=read('captures/smoke.json');assert smoke['portal_plant_intersections']==0 and smoke['pollen_toggle']
checks['smoke']=smoke;checks['f7_toggle']='checked by Golden scene smoke before inherited input checks'
assert 'run/main_scene="res://golden.tscn"' in (p.parent/'project.godot').read_text(encoding='utf-8-sig')
checks['source_sha256']=hashlib.sha256((p.parent/'golden_scene.gd').read_bytes()).hexdigest();checks['success']=True
(p/'validation.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
old=(p.parent/'radiance/review.html').read_text(encoding='utf-8')
head=old[:old.index('<h1>')].replace('暖光与湿润材质 · Godot 验收','GOLDEN v1 · 金色日光验收')
ui=old[old.index('<label>视图'):old.index('<h2>')]
options=[('compare','上一轮 / 金色日光 · 同机位对比'),('baseline_top.png','上一轮 RADIANCE 照明'),('final_top.png','金色日光 · 主视角'),('final_left.png','左侧视'),('final_side.png','右侧视'),('final_low_side.png','低角度检查'),('final_water.png','水面近景'),('final_portal.png','出生门近景'),('motion','移动相机 48 帧')]
ui=re.sub(r'<select id="view">.*?</select>','<select id="view">'+''.join(f'<option value="{value}">{label}</option>' for value,label in options)+'</select>',ui,flags=re.S)
ui=ui.replace('F6 花粉','F6 花粉、F7 日光对照')
top=f'''<h1>GOLDEN v1 · 金色日光</h1><p>主光由 38° 改为 28° 入射，颜色 #FFC56D、能量 2.7。受光石板 R/B 暖色比提高 {metrics['warmth_ratio_gain']*100:.1f}%，通过真实主光改变受光颜色及阴影。原生 2K + 4×MSAA，两轮 P95 {perf[0]['p95_ms']:.3f} / {perf[1]['p95_ms']:.3f} ms。</p><p><b>正确工程：work/environment_ruins/project.godot，F5 运行默认 golden.tscn。</b>窗口标题应显示 GOLDEN v1，F7 切换上一轮照明。旧 scene.tscn 是早期版本，F6 在编辑器中会运行当前旧标签。</p><p><a href="report.md">本轮报告</a> · <a href="validation.json">验收数据</a> · <a href="../radiance/review.html">上一轮与 14 项资产</a> · <a href="../../../reference_pic/Gemini_Generated_Image_vu1s3vu1s3vu1s3v.jpg">概念图</a></p>'''
page=head+top+ui+old[old.index('<script>'):]
(p/'review.html').write_text(page,encoding='utf-8')
for href in re.findall(r'(?:href|src)="([^"]+)"',page):
    if not href.startswith(('http','#')):assert (p/href).exists() or href=='report.md',href
report=f'''# GOLDEN v1：版本识别与金色日光

已确认原编辑器路径正确，但打开的是早期 `scene.tscn` 标签。F6 会运行该旧场景；F5 才会运行项目默认场景。现在默认入口为 `golden.tscn`，窗口标题及场内提示标明 GOLDEN v1，旧 scene.tscn 标为 LEGACY。

本轮继承上一轮三维场景，仅调整真实主光颜色、能量与角度：`#FFE0AE / 1.6 / 38°` → `#FFC56D / 2.7 / 28°`。曝光、材质、植物布局、半分辨率 SSAO、SSR 及水面静态反射保持上一轮配置。没有用整屏黄色滤镜或景深掩盖细节。F7 可在同一相机位置实时切换两套照明。

固定机位受光道路的显示色 R/B 中位比由 {ratio0:.3f} 提至 {ratio1:.3f}，提高 {metrics['warmth_ratio_gain']*100:.1f}%；亮度比 {metrics['sunlit_road_luma_ratio']:.3f}，接近纯白像素 {white*100:.4f}%。该指标衡量暖色变化，不代表概念图还原度。

RTX 3060，原生 2560×1440、4×MSAA，连续两轮各 600 帧移动测试 P95 为 **{perf[0]['p95_ms']:.3f} / {perf[1]['p95_ms']:.3f} ms**。多视角、48 帧环绕、F7 往返和既有相机／画质／花粉输入检查通过；门体植物净空检查为 0 相交。GPU 日志无脚本、着色器或资源泄漏错误。

右键旋转、WASD 平移、滚轮缩放；F3 投影、F4 低角度、F5 风动、F6 花粉、F7 日光对照。注意编辑器中的 F6 是运行当前场景；上述按键需在游戏窗口内使用。

未增加模型或消耗 Meshy 积分。遗迹模型、石板重复、低角度遮挡及静态单点反射近似仍是已知差距，未认定达到 90% 还原度。上一轮资产与限制见 [RADIANCE 报告](../radiance/report.md)。
'''
(p/'report.md').write_text(report,encoding='utf-8')
print('GOLDEN_VALID',metrics,[r['p95_ms'] for r in perf])
