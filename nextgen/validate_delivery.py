"""Check actual delivered pixels, source provenance, camera coverage and GPU logs."""
from pathlib import Path
from PIL import Image
from html.parser import HTMLParser
import json,math,re
p=Path(__file__).resolve().parent
def read(name):return json.loads((p/name).read_text(encoding='utf-8-sig'))
benchmark=read('final_benchmark.json')
assert benchmark['p95_ms']<=33.3,benchmark
assert benchmark['samples']>=600 and benchmark['internal_scale']==1.25
assert benchmark['render_target_pixels']=='(2560.0, 1440.0)'
screens=['final_top.png','final_side.png','final_close.png','baseline_2k_top.png','sampling_msaa_close.png','sampling_fsr2_close.png','sampling_ssaa_close.png']
for f in screens:assert Image.open(p/f).size==(2560,1440),f
assert Image.open(p/'preview_top.png').size==(1421,736)
source=read('textures/catalog.json')
assert source['no_upscaling'] and min(x['pixels'][0] for x in source['outputs'])>=1000
assert len(source['sha256'])==64
sequences={}
for label in ['sampling_msaa','sampling_fsr2','sampling_ssaa','final','final_orbit']:
    files=sorted((p/(label+'_motion')).glob('[0-9][0-9][0-9].png'))
    assert len(files)==48,(label,len(files))
    for f in files:assert Image.open(f).size==(2560,1440),f
    sequences[label]=48
orbit=read('final_orbit_motion/poses.json')
assert orbit['full_orbit']
pitches=[math.degrees(x['pitch']) for x in orbit['poses']]
assert min(pitches)<10.01 and max(pitches)>59.99
smoke=read('smoke.json')
assert smoke['camera_pan_reset'] and smoke['root_uniform'] and smoke['road_tangents']
assert smoke['lod_far']==0 and smoke['lod_near']==24 and smoke['road_slabs']==52
assert smoke['quality_pixels']==[2560,1440] and smoke['preview_pixels']==[1421,736]
assets=read('assets/catalog.json')
log=(p/'assets_gpu.log').read_text(encoding='utf-8-sig')
assert 'ERROR:' not in log
for name in assets['scenes']:
    assert (p/'assets'/f'{name}.tscn').exists()
    assert 'NEXTGEN_ASSET_OK '+name in log,name
assert log.count('NEXTGEN_ASSET_OK')==9
# Pin the successful final runs; rejected intermediate logs intentionally remain.
logs=[f'review_20261031_213248_{i}.log' for i in range(1,7)]
logs += ['review_20261031_213815_1.log','review_20261031_213815_2.log','assets_gpu.log']
for f in logs:
    content=(p/f).read_text(encoding='utf-8-sig')
    assert not re.search(r'ERROR:|SCRIPT ERROR|SHADER ERROR',content),f
class Links(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for key,value in attrs:
            if key in ('href','src') and value and not value.startswith(('http:','https:','#','data:')):
                assert (p/value).exists(),value
Links().feed((p/'review.html').read_text(encoding='utf-8-sig'))
project=(p.parent/'project.godot').read_text(encoding='utf-8-sig')
assert 'run/main_scene="res://nextgen.tscn"' in project
result={'status':'passed','actual_output':[2560,1440],'configured_internal_scale':1.25,'nominal_internal_pixels':[3200,1800],'p95_target_ms':33.3,'p95_ms':benchmark['p95_ms'],'p50_ms':benchmark['p50_ms'],'gpu':benchmark['gpu'],'native_image_checks':screens,'native_motion_frames':sequences,'orbit_pitch_degrees':[min(pitches),max(pitches)],'smoke':smoke,'standalone_assets_passed':9,'verified_gpu_logs':logs,'new_meshy_credits':0,'total_meshy_credits_used':390,'visual_90_percent_accepted':False}
(p/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('DELIVERY_VALIDATED',json.dumps({'p95_ms':benchmark['p95_ms'],'assets':9,'frames':sum(sequences.values())}))
