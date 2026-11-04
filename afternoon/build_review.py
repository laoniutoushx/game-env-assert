"""Validate actual artifacts and publish a local, self-contained visual review."""
from pathlib import Path
import json, re, hashlib
from PIL import Image

p = Path(__file__).resolve().parent
read = lambda f: json.loads((p / f).read_text(encoding='utf-8-sig'))
views = ['top', 'left', 'side', 'low_side', 'water', 'portal', 'plants']
validation = {'success': False, 'new_meshy_credits': 0, 'reference_similarity_verified': False}
for phase in ['Compare', 'Diagnostics', 'Final', 'Perf', 'Motion', 'Smoke']:
    manifest = read(f'last_{phase}.json')
    assert manifest['success'], phase
    for log in manifest['logs']:
        assert not re.search(r'SCRIPT ERROR|SHADER ERROR|ERROR:|RIDs? of type .* leaked', Path(log).read_text(encoding='utf-8-sig')), log
for preset in ['cinema', 'clear']:
    for view in views:
        file = p / 'captures' / f'{preset}_{view}.png'
        assert Image.open(file).size == (2560, 1440), file
        meta = read(f'captures/{preset}_{view}.json')
        assert meta['internal_scale'] == 1 and meta['lightmap_loaded'], meta
        assert meta['cinema'] == (preset == 'cinema')
        assert meta['scanned_replacements'] == 24
motion = read('captures/final_motion/poses.json')
assert len(motion) == 48
for i in range(48):
    assert Image.open(p / f'captures/final_motion/{i:03}.png').size == (2560, 1440)
    assert Image.open(p / f'captures/clear_motion/{i:03}.png').size == (2560, 1440)
assert read('captures/clear_motion/poses.json') == motion
assert 'run/main_scene="res://afternoon.tscn"' in (p.parent/'project.godot').read_text(encoding='utf-8-sig')
cache = read('assets/runtime_cache_audit.json')
assert len(cache)==215 and all(item['found'] for item in cache)
assert not any('/with_tangents/' in item['source'] or '/shrub_lod2/' in item['source'] for item in cache)
for diagnostic in ['nofog', 'nolightmap', 'agx']:
    assert Image.open(p/f'captures/{diagnostic}_top.png').size==(2560,1440)
perf = [read(f'captures/perf_{i}_benchmark.json') for i in [1, 2]]
for r in perf:
    assert r['samples'] == 600 and r['p95_ms'] <= 33.3 and r['internal_scale'] == 1 and r['lightmap_loaded']
smoke = read('captures/smoke.json')
assert smoke['presentation_toggle'] and smoke['portal_plant_intersections'] == 0
validation.update(success=True, performance=perf, smoke=smoke, lightmap=read('assets/bake.json'), motion_frames_per_preset=48, total_motion_frames=96, editor_teardown=read('editor_teardown.json'))
validation['source_sha256'] = {f: hashlib.sha256((p.parent/f).read_bytes()).hexdigest() for f in ['afternoon_scene.gd', 'afternoon/settings.json', 'afternoon/details.gd', 'afternoon/export_lighting.gd', 'afternoon/foliage.gdshader', 'afternoon/road.gdshader', 'afternoon/ground.gdshader', 'afternoon/water.gdshader', 'afternoon/fog.gdshader']}
for key in ['scene','data']:
    file = p.parent / validation['lightmap'][key].replace('res://','')
    validation[f'baked_{key}_sha256'] = hashlib.sha256(file.read_bytes()).hexdigest()
(p/'assets/catalog.json').write_text(json.dumps({
    'runtime_scene':validation['lightmap']['scene'], 'lightmap':validation['lightmap']['data'],
    'reusable_source_models':['res://fern_02/fern_02_prepared.gltf','res://shrub_02/shrub_02_prepared.gltf'],
    'source_license':'Poly Haven CC0; prior manifests retained',
    'procedural_elements':{'builder':'res://afternoon/details.gd','engraved_slabs':[5,17,32,45],'puddle_host_slabs':[8,27,43],'water_surfaces':3},
    'materials':[f'res://afternoon/{s}.gdshader' for s in ['foliage','road','ground','water','fog']],
    'settings':'res://afternoon/settings.json','new_meshy_credits':0
},ensure_ascii=False,indent=2),encoding='utf-8')
(p / 'validation.json').write_text(json.dumps(validation, ensure_ascii=False, indent=2), encoding='utf-8')
labels = {'top':'主视角','left':'左侧','side':'右侧','low_side':'低角度','water':'水洼近景','portal':'门体近景','plants':'植物近景'}
options = '<option value="compare">Golden / Afternoon 同机位</option><option value="reference">参考图 / Afternoon</option>'
for preset, label in [('cinema','电影展示'),('clear','清晰检查')]:
    for view in views: options += f'<option value="{preset}_{view}.png">{label} · {labels[view]}</option>'
options += '<option value="motion">电影展示移动相机 · 48 帧</option><option value="clear_motion">清晰移动相机 · 48 帧</option>'
options += '<option value="nofog_top.png">诊断 · 关闭体积雾</option><option value="nolightmap_top.png">诊断 · 关闭烘焙间接光</option><option value="agx_top.png">诊断 · AgX 色调映射</option>'
html = '''<!doctype html><html lang="zh"><meta charset="utf-8"><title>AFTERNOON v1 实机验收</title>
<style>body{background:#141915;color:#e3e7df;font:16px/1.6 system-ui;margin:24px}h1{margin:0}a{color:#e9c77c}select,button,input{font:inherit}#pair{display:flex;gap:12px}figure{margin:0;flex:1;min-width:0}img{width:100%;display:block}figcaption{color:#c9b992}#single{max-width:100%}p{max-width:1100px}</style>
<h1>AFTERNOON v1 · 午后电影感渲染</h1><p>真实 Godot Forward+ 输出，原生 2560×1440、4×MSAA。F8 切换景深展示与清晰检查；右键旋转、WASD 平移、滚轮缩放、R 重置。</p>
<p>两轮移动测试 P95：PERF。静态间接光已烘焙；植物风动与日光阴影动态计算。参考图中的溪流、桥和炮塔不在本轮范围；仍有资产与构图差距，未认定达到 90%。</p>
<p><a href="report.md">实施与差距报告</a> · <a href="validation.json">验收数据</a> · <a href="assets/bake.json">光照烘焙</a></p>
<select id="view">OPTIONS</select> <button id="play">播放 / 暂停</button> <input id="frame" type="range" min="0" max="47" value="0"><span id="index"></span>
<div id="pair"><figure><figcaption id="captionA"></figcaption><img id="a"></figure><figure><figcaption>AFTERNOON · 实机</figcaption><img id="b"></figure></div><img id="single">
<script>
const v=document.querySelector('#view'),p=document.querySelector('#pair'),s=document.querySelector('#single'),a=document.querySelector('#a'),b=document.querySelector('#b'),f=document.querySelector('#frame');let playing=false;
function update(){let paired=['compare','reference'].includes(v.value);p.style.display=paired?'flex':'none';s.style.display=paired?'none':'block';if(paired){a.src=v.value==='compare'?'captures/baseline_top.png':'reference.png';b.src='captures/cinema_top.png';document.querySelector('#captionA').textContent=v.value==='compare'?'GOLDEN · 旧版同机位':'目标概念图（构图元素存在差异）';}else{s.src=['motion','clear_motion'].includes(v.value)?`captures/${v.value==='motion'?'final_motion':'clear_motion'}/${String(f.value).padStart(3,'0')}.png`:'captures/'+v.value;}document.querySelector('#index').textContent=f.value;}
v.onchange=update;f.oninput=()=>{if(!['motion','clear_motion'].includes(v.value))v.value='motion';update()};document.querySelector('#play').onclick=()=>{playing=!playing;if(!['motion','clear_motion'].includes(v.value))v.value='motion';update()};setInterval(()=>{if(playing){f.value=(Number(f.value)+1)%48;update()}},150);update();</script></html>'''
html=html.replace('OPTIONS',options).replace('PERF',' / '.join(f'{r["p95_ms"]:.3f} ms' for r in perf))
(p/'review.html').write_text(html,encoding='utf-8')
print('AFTERNOON_VALIDATED', [r['p95_ms'] for r in perf])
