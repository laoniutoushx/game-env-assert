from pathlib import Path
from hashlib import sha256
import json,time

project=Path(__file__).resolve().parents[1];out=project/'render_v5';captures=out/'captures'
release=project.parents[1]/'work/environment_releases/render_v4_accepted_20261103'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
locked=read(release/'manifest.json');changed=[]
print('VERIFY_LOCKED_BASELINE',len(locked),'files',flush=True)
for i,(relative,record) in enumerate(locked.items()):
    path=project/relative;digest=sha256()
    if not path.exists():changed.append(relative);continue
    with path.open('rb') as source:
        while data:=source.read(4*1024*1024):digest.update(data)
    if digest.hexdigest()!=record['sha256']:changed.append(relative)
    if i%300==0:print('BASELINE_CHECK_PROGRESS',i,flush=True)
assert not changed,changed
views=['top','left','side','low_side','water','portal','plants']
for preset in ['clear','cinema']:
    for view in views:
        metadata=read(captures/f'{preset}_{view}.json')
        assert metadata['variant']=='all' and metadata['lightmap_loaded'] and not metadata['preset_ray_density']
        assert (captures/f'{preset}_{view}.png').stat().st_size>10000
for preset in ['clear','cinema']:
    folder=captures/f'{preset}_motion'
    assert len(list(folder.glob('*.png')))==48 and len(read(folder/'poses.json'))==48
baseline=read(captures/'perf_baseline_benchmark.json')
perf=[read(captures/f'perf_{i}_benchmark.json') for i in [1,2]]
assert all(x['p95_ms']<=33.3 and x['samples']==600 and x['internal_scale']==1.0 and x['render_gpu_p95_ms']>0.1 for x in perf)
smoke=read(captures/'smoke.json');assert smoke['lightmap_loaded'] and smoke['portal_plant_intersections']==0
toggle=read(captures/'toggle_smoke.json');assert toggle['f9_baseline_restore'] and toggle['camera_unchanged'] and toggle['wind_toggle']
sources={}
for file in [project/'render_v5_scene.gd',project/'render_v5.tscn']+list(out.glob('*.gd'))+list(out.glob('*.gdshader')):
    sources[file.relative_to(project).as_posix()]=sha256(file.read_bytes()).hexdigest()
report={'version':'RENDER V5 candidate','baseline':'RENDER V4 accepted and locked','baseline_files_verified_unchanged':len(locked),'default_scene':'res://render_v4_live.tscn','candidate_scene':'res://render_v5.tscn','incremental_visual_changes':['foliage backlight response','tighter contact shading','height-distributed continuous air and far-scene fog sample allocation'],'output':[2560,1440],'fixed_views':14,'motion_frames':96,'paired_baseline_p95_ms':baseline['p95_ms'],'candidate_p95_ms':[x['p95_ms'] for x in perf],'candidate_gpu_p95_ms':[x['render_gpu_p95_ms'] for x in perf],'baseline_draw_calls_last':baseline['draw_calls_last'],'candidate_draw_calls_last':[x['draw_calls_last'] for x in perf],'new_models':0,'new_textures':0,'paid_credits':0,'water_changes':False,'baseline_bake_reused':True,'f9_restore':toggle,'source_sha256':sources}
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False),flush=True)
