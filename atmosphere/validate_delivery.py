from pathlib import Path
from PIL import Image,ImageDraw
import json,re
p=Path(__file__).resolve().parent
def read(f):return json.loads((p/f).read_text(encoding='utf-8-sig'))
checks={}
for round in ['Final','Smoke','Slice','Coverage']:
    m=read(f'last_{round}.json');assert m['success']
    for log in m['logs']:
        s=Path(log).read_text(encoding='utf-8-sig')
        assert not re.search(r'SCRIPT ERROR|SHADER ERROR|ERROR:|Error compiling shader',s),log
    checks[round+'_logs']=len(m['logs'])
perf=read('captures/final_benchmark.json')
assert perf['p95_ms']<=33.3 and perf['samples']==600 and perf['internal_scale']==1 and perf['projection']==0
assert read('settings.json')['cut']==perf['cut']
checks['final_benchmark']=perf
c=read('captures/coverage.json')
assert .7<=c['perimeter_plant_coverage']<=.85
assert .65<=c['middle_belts_plant_coverage']<=.8
assert c['road_plant_occlusion']<=.1
checks['coverage']=c
for folder in ['final_motion','frozen_motion']:
    poses=read(f'captures/{folder}/poses.json');files=sorted((p/'captures'/folder).glob('*.png'))
    assert len(poses)==len(files)==48
    for f in files:assert Image.open(f).size==(2560,1440)
    checks[folder+'_frames']=len(files)
assert read('captures/final_motion/poses.json')==read('captures/frozen_motion/poses.json')
assets=read('assets/catalog.json')['adopted_scenes'];assert len(assets)==12
for a in assets:
    assert (p/'assets'/a).is_file()
    im=Image.open(p/'captures/assets'/f'{a}.png');assert im.size==(2560,1440)
checks['rendered_assets']=assets
for f in ['baseline_top','final_top','final_side','final_close','final_ortho_top','slice_base_slice','slice_layout_slice','slice_surface_slice','slice_final_slice']:
    assert Image.open(p/'captures'/f'{f}.png').size==(2560,1440)
for lod in ['high','mid','low']:
    import struct
    data=(p/'assets'/f'tree_{lod}_geometry.glb').read_bytes()
    length=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+length])
    assert not g.get('images') and not g.get('textures')
    for mesh in g['meshes']:
        for prim in mesh['primitives']:
            assert 'TANGENT' in prim['attributes'] and 'TEXCOORD_1' not in prim['attributes']
checks['tree_geometry_uv_tangents']=True
for name in ['branch','leaves','trunk']:
    for kind in ['base','normal','orm']:
        f=next((p/'textures').glob(f'tree_{name}_{kind}.*'))
        assert Image.open(f).size==(4096,4096)
        s=Path(str(f)+'.import').read_text()
        assert 'compress/mode=2' in s and 'mipmaps/generate=true' in s
checks['shared_4k_compressed_mipmaps']=True
assert 'run/main_scene="res://atmosphere.tscn"' in (p.parent/'project.godot').read_text(encoding='utf-8-sig')
assert read('source_catalog.json')['md5_verified']
assert not (p/'bootstrap.py').exists()
# Local static page destinations; dynamic motion URLs checked above.
page=(p/'review.html').read_text(encoding='utf-8')
for href in re.findall(r'(?:href|src)="([^"]+)"',page):
    if not href.startswith(('http','#')) and href!='validation.json':assert (p/href).exists(),href
checks['review_links']=True
checks['success']=True
(p/'comparison.json').write_text(json.dumps({'coverage':c,'selected_performance':perf,'previous_full_resolution_ao_repeat':read('captures/density_benchmark.json'),'note':'The full-resolution AO repeat marginally exceeded budget; final uses half-resolution SSAO. Coverage is a layout metric, not conceptual image similarity.'},ensure_ascii=False,indent=2),encoding='utf-8')
(p/'validation.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
# QA contact sheet, generated from actual renders rather than synthetic previews.
items=[p/'captures/final_side.png',p/'captures/final_close.png']+[p/'captures/final_motion'/f'{i:03}.png' for i in [0,12,24,36]]
sheet=Image.new('RGB',(960,3*290),'#162019');d=ImageDraw.Draw(sheet)
for i,f in enumerate(items):
    im=Image.open(f);im.thumbnail((480,270));x=(i%2)*480;y=(i//2)*290
    sheet.paste(im,(x,y));d.text((x+4,y+271),f.parent.name+'/'+f.name,fill='white')
sheet.save(p/'captures/qa_contact.jpg')
print('DELIVERY_VALID',checks['coverage'],checks['final_benchmark']['p95_ms'])
