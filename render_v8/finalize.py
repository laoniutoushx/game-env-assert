from pathlib import Path
from hashlib import sha256
import json,subprocess
import numpy as np
from PIL import Image,ImageDraw

project=Path(__file__).resolve().parents[1];out=project/'render_v8';captures=out/'captures'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
assert not subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=project,text=True).strip()
assert 'run/main_scene="res://render_v4_live.tscn"' in (project/'project.godot').read_text(encoding='utf-8-sig')
base=read(captures/'perf_baseline_benchmark.json');perf=[read(captures/f'perf_{i}_benchmark.json') for i in [1,2]]
assert base['shadow_profile']=='baseline' and base['lightmap_loaded']
for data in perf:
    assert data['samples']==600 and data['p95_ms']<=33.3 and data['internal_scale']==1
    assert 0.1<data['render_gpu_p95_ms']<=base['render_gpu_p95_ms']+1.0
    assert data['shadow_profile']=='fine' and abs(data['shadow_normal_bias']-0.7)<0.0001
    assert abs(data['shadow_bias']-0.025)<0.0001 and abs(data['sun_angular_distance']-0.6)<0.0001
comparison={}
for kind in ['case','close','slice']:
    a=read(captures/f'{kind}_baseline_top.json');b=read(captures/f'{kind}_fine_top.json')
    assert all(a[k]==b[k] for k in ['pitch','yaw','width','actual_environment','actual_sun'])
    assert abs(b['shadow_normal_bias']-0.7)<0.0001 and abs(b['shadow_bias']-0.025)<0.0001
    x=np.asarray(Image.open(captures/f'{kind}_baseline_top.png')).astype(float)
    y=np.asarray(Image.open(captures/f'{kind}_fine_top.png')).astype(float)
    comparison[kind]=float(np.abs(x-y).mean())
for preset in ['clear','cinema']:
    for view in ['top','left','side','low_side','water','portal','plants']:
        data=read(captures/f'{preset}_{view}.json')
        assert data['shadow_profile']=='fine' and data['internal_scale']==1
        assert data['dof_enabled']==(preset=='cinema') and data['lightmap_loaded'] and not data['preset_ray_density']
        assert data['actual_sun'][0]['shadow_range']==60 and data['actual_sun'][0]['energy']==base['actual_sun'][0]['energy']
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
assert smoke['portal_plant_intersections']==0
sources=[project/'render_v8_scene.gd',project/'render_v8.tscn']+list(out.glob('*.gd'))
report={'version':'RENDER V8 candidate','parent_commit':'7e55067','tracked_baselines_unchanged':True,'default_scene':'res://render_v4_live.tscn','selected_change':{'sun_angular_distance':[1.2,0.6]},'preserved_shadow_bias':0.025,'preserved_shadow_normal_bias':0.7,'rejected_change':{'normal_bias':0.35,'bias':0.015,'reason':'Visible diagonal self-shadow acne on slabs and rocks'},'fixed_views':14,'motion_frames':96,'native_output':[2560,1440],'image_mad_8bit':comparison,'baseline_p95_ms':base['p95_ms'],'candidate_p95_ms':[x['p95_ms'] for x in perf],'baseline_gpu_p95_ms':base['render_gpu_p95_ms'],'candidate_gpu_p95_ms':[x['render_gpu_p95_ms'] for x in perf],'candidate_draw_calls':[x['draw_calls_last'] for x in perf],'f9':toggle,'new_models':0,'new_textures':0,'water_changes':False,'baseline_bake_reused':True,'source_sha256':{p.relative_to(project).as_posix():sha256(p.read_bytes()).hexdigest() for p in sources}}
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
html='<!doctype html><meta charset="utf-8"><title>V8 阴影验收</title><style>body{background:#151819;color:#ddd;font:16px system-ui;margin:28px}main{display:grid;grid-template-columns:1fr 1fr;gap:20px}img{width:100%}figure{margin:0}figcaption{padding:8px}a{color:#aef}</style><h1>V8：阴影半影细节</h1><p>太阳角直径 1.2° → 0.6°；保持 V7 安全偏移、光照方向、能量、曝光、体积雾与景深。原生 2K / MSAA4。</p><main>'
for kind in ['case','close','slice']:
    for profile in ['baseline','fine']:
        stem=f'{kind}_{profile}_top';html+=f'<figure><a href="captures/{stem}.png"><img src="captures/{stem}.png"></a><figcaption>{kind} / {profile}</figcaption></figure>'
html+='</main><h2>已否决：小偏移产生条纹</h2><a href="captures/close_contact_top.png"><img src="captures/close_contact_top.png"></a><main>'
for preset in ['clear','cinema']:
    for view in ['top','left','side','low_side','water','portal','plants']:
        stem=f'{preset}_{view}';html+=f'<figure><a href="captures/{stem}.png"><img loading="lazy" src="captures/{stem}.png"></a><figcaption>{stem}</figcaption></figure>'
html+='</main><img src="captures/clear_motion_sheet.jpg"><img src="captures/cinema_motion_sheet.jpg">'
(out/'review.html').write_text(html,encoding='utf-8');print(json.dumps(report,ensure_ascii=False,indent=2))
