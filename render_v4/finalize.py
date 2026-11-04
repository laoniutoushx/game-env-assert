from pathlib import Path
from hashlib import sha256
import json,shutil
root=Path(__file__).resolve().parents[1];out=root/'render_v4';cap=out/'captures'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
bake=read(out/'assets/bake.json')
assert bake['success'] and bake['users']==220
for path,digest in bake['source_sha256'].items():
    assert sha256((root/path).read_bytes()).hexdigest()==digest,('Stale bake',path)
views=['top','left','side','low_side','water','portal','plants']
for preset in ['clear','cinema']:
    for view in views:
        meta=read(cap/f'{preset}_{view}.json')
        assert meta['lightmap_loaded'] and not meta['preset_ray_density'] and meta['actual_sun'][0]['shadow_mode']==0
        assert meta['actual_sun'][0]['shadow_range']==60
        assert (cap/f'{preset}_{view}.png').stat().st_size>10000
for folder in ['final_motion','clear_motion']:
    assert len(list((cap/folder).glob('*.png')))==48
    poses=read(cap/folder/'poses.json')
    assert len(poses)==48
perf=[read(cap/f'perf_{i}_benchmark.json') for i in [1,2]]
assert all(x['samples']==600 and x['p95_ms']<=33.3 and x['internal_scale']==1 and x['render_gpu_p95_ms']>0.1 for x in perf)
smoke=read(cap/'smoke.json');assert smoke['lightmap_loaded'] and smoke['portal_plant_intersections']==0
report={'version':'RENDER V4','scope':'lighting, shadows, depth of field, real volumetric scattering','native_output':[2560,1440], 'fixed_images':14,'motion_frames':96,'static_baked_meshes':220,'p95_ms':[x['p95_ms'] for x in perf],'final_art_match_approved':False,'new_meshy_credits':0,'water_changes_this_round':False}
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
shutil.copyfile(Path('S:/远古遗迹符文防御之路.png'),out/'reference.png')
project=root/'project.godot';text=project.read_text(encoding='utf-8-sig')
assert 'run/main_scene="res://afternoon.tscn"' in text or 'run/main_scene="res://render_v4_live.tscn"' in text
text=text.replace('run/main_scene="res://afternoon.tscn"','run/main_scene="res://render_v4_live.tscn"')
project.write_text(text,encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
