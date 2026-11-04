from pathlib import Path
from PIL import Image,ImageDraw
import json,re,hashlib
p=Path(__file__).resolve().parent
def read(name):return json.loads((p/name).read_text(encoding='utf-8-sig'))
checks={}
for round in ['Stages','Final','Coverage','Assets','Perf','Reflection']:
    m=read(f'last_{round}.json');assert m['success']
    if round=='Perf':assert len(m['performance'])==2
    for log in m['logs']:
        s=Path(log).read_text(encoding='utf-8-sig')
        assert not re.search(r'SCRIPT ERROR|SHADER ERROR|ERROR:|Error compiling shader|RIDs? of type .* leaked',s),log
    checks[round+'_clean_logs']=len(m['logs'])
perf=[read(f'captures/perf_{i}_benchmark.json') for i in [1,2]]
settings=read('settings.json')
for r in perf:
    assert r['samples']==600 and r['p95_ms']<=33.3 and r['internal_scale']==1.0
    assert r['output']=='(2560.0, 1440.0)' and r['projection']==0
    assert r['settings']==settings
checks['performance']=perf
m=read('captures/measurements.json')
for view,c in m['coverage'].items():
    if view!='low_side':assert c['road_plant_occlusion']<=.08,(view,c)
photometry=m['photometry']
assert .15<=photometry['persistent_shadow_gain']<=.30,photometry
assert photometry['road_to_adjacent_ground_ratio']>=1.10,photometry
assert photometry['near_white_fraction']<.005,photometry
checks['measurements']=m
for folder in ['final_motion','frozen_motion']:
    poses=read(f'captures/{folder}/poses.json');files=sorted((p/'captures'/folder).glob('*.png'))
    assert len(poses)==len(files)==48
    for f in files:assert Image.open(f).size==(2560,1440)
checks['matching_motion_poses']=read('captures/final_motion/poses.json')==read('captures/frozen_motion/poses.json')
assert checks['matching_motion_poses']
for name in ['baseline_top','light_top','ground_top','wet_top','final_top','final_left','final_side','final_low_side','final_water','final_portal']:
    assert Image.open(p/'captures'/f'{name}.png').size==(2560,1440)
assets=read('assets/catalog.json')['adopted_scenes'];assert len(assets)==14
for a in assets:
    assert (p/'assets'/a).exists()
    assert Image.open(p/'captures/assets'/f'{a}.png').size==(2560,1440)
checks['assets']=assets
smoke=read('captures/smoke.json')
assert smoke['portal_plant_intersections']==0 and smoke['pollen_toggle'] and smoke['wet_host_slabs']==3
checks['smoke']=smoke
assert (p/'assets/water_reflection.res').stat().st_size>500000
for i in range(6):assert Image.open(p/'captures/reflection_faces'/f'{i}.png').size==(256,256)
checks['baked_reflection_faces']=6
assert 'run/main_scene="res://radiance.tscn"' in (p.parent/'project.godot').read_text(encoding='utf-8-sig')
for href in re.findall(r'(?:href|src)="([^"]+)"',(p/'review.html').read_text(encoding='utf-8')):
    if not href.startswith(('http','#')) and href!='validation.json':assert (p/href).exists(),href
checks['source_sha256']={name:hashlib.sha256((p/name).read_bytes()).hexdigest() for name in ['../radiance_scene.gd','road.gdshader','ground.gdshader','foliage.gdshader','settings.json','assets/water_reflection.res']}
checks['success']=True
(p/'validation.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
items=['final_top.png','final_side.png','final_water.png','final_portal.png','final_motion/012.png','final_motion/036.png']
sheet=Image.new('RGB',(960,870),'#162019');d=ImageDraw.Draw(sheet)
for i,name in enumerate(items):
    im=Image.open(p/'captures'/name);im.thumbnail((480,270));x=(i%2)*480;y=(i//2)*290
    sheet.paste(im,(x,y));d.text((x+4,y+271),name,fill='white')
sheet.save(p/'captures/qa_contact.jpg')
print('RADIANCE_DELIVERY_VALID',photometry,[r['p95_ms'] for r in perf])
