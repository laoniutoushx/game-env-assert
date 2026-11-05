from pathlib import Path
from hashlib import sha256
import json, subprocess
from PIL import Image, ImageDraw
import numpy as np

project=Path(__file__).resolve().parents[1]
out=project/'render_v6'; captures=out/'captures'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
# The Git baseline includes the intentional repository documentation update after V4 locking.
# No previously tracked file may change during V6; runtime additionally validates the baked-source fingerprint.
changed=subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=project,text=True).splitlines()
assert not changed, changed
assert 'run/main_scene="res://render_v4_live.tscn"' in (project/'project.godot').read_text(encoding='utf-8-sig')
probe=read(captures/'probe.json'); assert all(x['valid'] for x in probe['surfaces'])
fixture=read(captures/'normal_fixture.json'); assert fixture['selected_backface_rule']==1
diagnostics={}
reference_pose=read(captures/'diagnostic_baseline_top.json')
reference=np.asarray(Image.open(captures/'diagnostic_baseline_top.png')).astype(float)
for mode in ['off_material_ao','off_ssao','off_ssil','off_shadows']:
    meta=read(captures/f'diagnostic_{mode}_top.json')
    assert all(meta[k]==reference_pose[k] for k in ['pitch','yaw','width']),mode
    diagnostics[mode]=float(np.abs(np.asarray(Image.open(captures/f'diagnostic_{mode}_top.png')).astype(float)-reference).mean())
for preset in ['clear','cinema']:
    for view in ['top','left','side','low_side','water','portal','plants']:
        metadata=read(captures/f'{preset}_{view}.json')
        assert metadata['repair']=='combined' and metadata['lightmap_loaded'] and not metadata['preset_ray_density']
        assert metadata['internal_scale']==1.0
        assert metadata['dof_enabled']==(preset=='cinema')
        with Image.open(captures/f'{preset}_{view}.png') as im: assert im.size==(2560,1440)
    folder=captures/f'{preset}_motion'; poses=read(folder/'poses.json')
    assert len(list(folder.glob('*.png')))==48 and len(poses)==48
    assert all(39.9<=np.degrees(x['pitch'])<=70.1 for x in poses)
    sheet=Image.new('RGB',(320*6,200*8),(20,24,26)); draw=ImageDraw.Draw(sheet)
    for i,file in enumerate(sorted(folder.glob('*.png'))):
        with Image.open(file) as frame:
            frame.thumbnail((320,180));sheet.paste(frame,((i%6)*320,(i//6)*200))
        draw.text(((i%6)*320+5,(i//6)*200+181),f'{i:02d}',fill='white')
    sheet.save(captures/f'{preset}_motion_sheet.jpg',quality=92)
baseline=read(captures/'perf_baseline_benchmark.json')
perf=[read(captures/f'perf_{i}_benchmark.json') for i in [1,2]]
for result in perf:
    assert result['p95_ms']<=33.3 and result['samples']==600 and result['internal_scale']==1.0
    assert 0.1<result['render_gpu_p95_ms']<=baseline['render_gpu_p95_ms']+1.0
smoke=read(captures/'smoke.json'); toggle=read(captures/'toggle_smoke.json')
assert smoke['lightmap_loaded'] and smoke['portal_plant_intersections']==0
assert toggle['f9_baseline_restore'] and toggle['wind_toggle'] and toggle['camera_unchanged']
sources={p.relative_to(project).as_posix():sha256(p.read_bytes()).hexdigest() for p in [project/'render_v6_scene.gd',project/'render_v6.tscn']+list(out.glob('*.gd'))+list(out.glob('*.gdshader'))}
report={'version':'RENDER V6 candidate','baseline':'V5 all / default locked V4 unchanged','tracked_baseline_unchanged':True,'fixed_views':14,'motion_frames':96,'normal_strength':0.2,'backface_rule':1,'tangent_surfaces_verified':len(probe['surfaces']),'shadow_proxy_upgrades':2,'source_ao_strength':0.5,'diagnostic_image_mad_8bit':diagnostics,'baseline_p95_ms':baseline['p95_ms'],'baseline_gpu_p95_ms':baseline['render_gpu_p95_ms'],'candidate_p95_ms':[x['p95_ms'] for x in perf],'candidate_gpu_p95_ms':[x['render_gpu_p95_ms'] for x in perf],'f9':toggle,'source_sha256':sources,'new_models':0,'new_textures':0,'water_changes':False,'paid_credits':0}
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
rows=[('V5 同视角','case_baseline_top'),('V6 仅叶片修复','case_normal_top'),('V6 仅树影修复','case_shadow_top'),('V6 组合','case_combined_top'),('法线 0.20','normal_0.2_top'),('法线 0.35','normal_0.35_top')]
rows += [('诊断 '+mode,'diagnostic_'+mode+'_top') for mode in ['baseline','off_material_ao','off_ssao','off_ssil','off_shadows']]
rows += [(preset+' / '+view,preset+'_'+view) for preset in ['clear','cinema'] for view in ['top','left','side','low_side','water','portal','plants']]
html='<!doctype html><meta charset="utf-8"><title>V6 实机验收</title><style>body{background:#151819;color:#ddd;font:16px system-ui;margin:28px}main{display:grid;grid-template-columns:1fr 1fr;gap:20px}img{width:100%}a{color:#aef}figure{margin:0}figcaption{padding:8px}</style><h1>V6：叶片法线与关键树影</h1><p>原生 2560×1440 / MSAA4 / Forward+。固定曝光、相机、太阳与连续体积雾。点图查看原尺寸。</p><p>法线强度 0.20；两棵树的投影代理升级到中模；材质 AO 保持 0.50。默认仍为锁定 V4。</p><main>'
for title,stem in rows: html+=f'<figure><a href="captures/{stem}.png"><img loading="lazy" src="captures/{stem}.png"></a><figcaption>{title}</figcaption></figure>'
html+='</main><p>移动记录：<a href="captures/clear_motion/poses.json">清晰模式 48 帧</a> / <a href="captures/cinema_motion/poses.json">景深模式 48 帧</a>。完整指标见 validation.json。</p>'
html+='<img src="captures/clear_motion_sheet.jpg"><img src="captures/cinema_motion_sheet.jpg">'
(out/'review.html').write_text(html,encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
