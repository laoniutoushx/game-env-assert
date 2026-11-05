from pathlib import Path
from hashlib import sha256
import json,subprocess
from PIL import Image,ImageDraw

project=Path(__file__).resolve().parents[1];out=project/'render_v7';captures=out/'captures'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
assert not subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=project,text=True).strip()
assert 'run/main_scene="res://render_v4_live.tscn"' in (project/'project.godot').read_text(encoding='utf-8-sig')
base=read(captures/'perf_baseline_benchmark.json');perf=[read(captures/f'perf_{i}_benchmark.json') for i in [1,2]]
assert not base['canopy_enabled'] and base['lightmap_loaded']
for data in perf:
    assert data['samples']==600 and data['p95_ms']<=33.3 and data['internal_scale']==1
    assert data['render_gpu_p95_ms']<=base['render_gpu_p95_ms']+1.0
    assert data['canopy_enabled'] and data['crown_meshes']==45
for preset in ['clear','cinema']:
    for view in ['top','left','side','low_side','water','portal','plants']:
        data=read(captures/f'{preset}_{view}.json')
        assert data['canopy_enabled'] and data['canopy_strength']==0.25
        assert data['dof_enabled']==(preset=='cinema') and data['lightmap_loaded'] and not data['preset_ray_density']
        with Image.open(captures/f'{preset}_{view}.png') as im:assert im.size==(2560,1440)
    folder=captures/f'{preset}_motion';poses=read(folder/'poses.json');assert len(poses)==48
    frames=sorted(folder.glob('*.png'));assert len(frames)==48
    assert all(0.698<=x['pitch']<=1.222 for x in poses)
    sheet=Image.new('RGB',(1920,1600),(20,24,26));draw=ImageDraw.Draw(sheet)
    for i,file in enumerate(frames):
        with Image.open(file) as frame:
            frame.thumbnail((320,180));sheet.paste(frame,((i%6)*320,(i//6)*200))
        draw.text(((i%6)*320+4,(i//6)*200+181),str(i),fill='white')
    sheet.save(captures/f'{preset}_motion_sheet.jpg',quality=92)
toggle=read(captures/'toggle_smoke.json');smoke=read(captures/'smoke.json')
assert toggle['f9_baseline_restore'] and toggle['camera_unchanged'] and toggle['wind_toggle'] and smoke['lightmap_loaded']
attempts=[]
for attempt in [1,2]:
    baseline_file=captures/f'attempt{attempt}_baseline.json'
    if baseline_file.exists():
        old_base=read(baseline_file);old_perf=[read(captures/f'attempt{attempt}_perf_{i}.json') for i in [1,2]]
        attempts.append({'attempt':attempt,'shader':'before removal of disabled canopy-opening code','baseline_p95_ms':old_base['p95_ms'],'baseline_gpu_p95_ms':old_base['render_gpu_p95_ms'],'candidate_p95_ms':[x['p95_ms'] for x in old_perf],'candidate_gpu_p95_ms':[x['render_gpu_p95_ms'] for x in old_perf],'absolute_budget_pass':all(x['p95_ms']<=33.3 for x in old_perf)})
report={'version':'RENDER V7 candidate','parent_commit':'ba38227','default_scene':'res://render_v4_live.tscn','tracked_baselines_unchanged':True,'canopy_strength':0.25,'tree_lod_leaf_meshes':45,'new_models':0,'new_textures':0,'shadow_geometry_changed':False,'sun_and_air_unchanged':True,'disabled_canopy_opening_code_removed':True,'fixed_views':14,'motion_frames':96,'baseline_p95_ms':base['p95_ms'],'candidate_p95_ms':[x['p95_ms'] for x in perf],'baseline_gpu_p95_ms':base['render_gpu_p95_ms'],'candidate_gpu_p95_ms':[x['render_gpu_p95_ms'] for x in perf],'baseline_draw_calls':base['draw_calls_last'],'candidate_draw_calls':[x['draw_calls_last'] for x in perf],'previous_attempts':attempts,'f9':toggle,'source_sha256':{p.relative_to(project).as_posix():sha256(p.read_bytes()).hexdigest() for p in [project/'render_v7_scene.gd',project/'render_v7.tscn']+list(out.glob('*.gd'))+list(out.glob('*.gdshader'))}}
report['performance_absolute_budget_pass']=all(x['p95_ms']<=33.3 for x in perf)
report['performance_margin_ms']=[33.3-x['p95_ms'] for x in perf]
report['performance_note']='Small remaining margin; prior over-budget attempts retained. Concurrent Godot editor observed; timing differences do not establish a stable speedup.'
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
html='<!doctype html><meta charset="utf-8"><title>V7 树冠受光对照</title><style>body{background:#151819;color:#ddd;font:16px system-ui;margin:28px}main{display:grid;grid-template-columns:1fr 1fr;gap:20px}img{width:100%}figure{margin:0}figcaption{padding:8px}a{color:#aef}</style><h1>V7：树冠受光连续性</h1><p>仅调整树冠光照法线及其切线基底，真实叶片轮廓、投影、太阳和体积空气保持不变。选择 0.25。</p><main>'
for strength in ['0','0.25','0.45']:
    for kind in ['case','slice']:
        stem=f'{kind}_{strength}_top';html+=f'<figure><a href="captures/{stem}.png"><img src="captures/{stem}.png"></a><figcaption>{kind} / 强度 {strength}</figcaption></figure>'
for preset in ['clear','cinema']:
    for view in ['top','left','side','low_side','water','portal','plants']:
        stem=f'{preset}_{view}';html+=f'<figure><a href="captures/{stem}.png"><img loading="lazy" src="captures/{stem}.png"></a><figcaption>{stem}</figcaption></figure>'
html+='</main><img src="captures/clear_motion_sheet.jpg"><img src="captures/cinema_motion_sheet.jpg">'
(out/'review.html').write_text(html,encoding='utf-8');print(json.dumps(report,ensure_ascii=False,indent=2))
