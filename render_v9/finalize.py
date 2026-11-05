from pathlib import Path
from hashlib import sha256
import json,subprocess
import numpy as np
from PIL import Image
from analyze import summarize,read

PROJECT=Path(__file__).resolve().parents[1];OUT=PROJECT/'render_v9';CAP=OUT/'captures'
assert not subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=PROJECT,text=True).strip(),'Existing tracked baseline changed'
assert 'run/main_scene="res://render_v4_live.tscn"' in (PROJECT/'project.godot').read_text(encoding='utf-8-sig')
summarize();temporal=read(OUT/'temporal_analysis.json')
comparison=temporal['comparisons']['combined_pan']
videos=read(OUT/'video_validation.json')
assert videos['decoded_frames']==4800 and len(videos['videos'])==10
assert comparison['temporal_reduction']>=.30,comparison
assert comparison['shadow_fraction_relative_change']<=.10,comparison
assert comparison['mean_luminance_relative_change']<=.05,comparison
for mode in ['baseline','combined']:
    for clip in ['static','wind','pan','lod','orbit']:
        name=f'{mode}_{clip}';folder=CAP/(name+'_sequence');meta=read(folder/'metadata.json')
        records=read(folder/'frames.json');count=300 if clip in ['static','wind'] else 600
        assert len(records)==meta['frames']==count and [x['frame'] for x in records]==list(range(count))
        assert len(list(folder.glob('[0-9][0-9][0-9][0-9].jpg')))==count and len(list((folder/'roi').glob('*.png')))==count
        assert meta['simulation_fps']==30 and not meta['taa'] and meta['msaa']==2
        assert meta['wind']==(clip in ['wind','orbit'])
        assert (CAP/(name+'_sequence.mp4')).stat().st_size>10000
        if mode=='combined':
            assert abs(meta['sun_angular_distance']-.3)<1e-4 and meta['shadow_filter']=='medium'
            assert meta['fixed_shadow_meshes']==0 and meta['filtered_textures']==2
        if clip=='orbit':assert all(.698<=x['pitch']<=1.222 for x in records)
        if mode=='combined' and clip=='pan':
            baseline=read(CAP/'baseline_pan_sequence/frames.json')
            assert all(a['lod_signature']==b['lod_signature'] for a,b in zip(records,baseline)),'Start/sustained LOD mismatch'
assert temporal['sequences']['combined_lod']['plant_lod_transitions']<temporal['sequences']['baseline_lod']['plant_lod_transitions']
for preset in ['clear','cinema']:
    for view in ['top','left','side','low_side','water','portal','plants']:
        data=read(CAP/f'{preset}_{view}.json')
        assert data['foliage_mode']=='combined' and data['internal_scale']==1
        assert data['dof_enabled']==(preset=='cinema') and data['lightmap_loaded'] and not data['preset_ray_density']
        with Image.open(CAP/f'{preset}_{view}.png') as im:assert im.size==(2560,1440)
baseline=read(CAP/'perf_baseline_benchmark.json');perf=[read(CAP/f'perf_{i}_benchmark.json') for i in [1,2]]
for data in perf:
    assert data['samples']==600 and data['p95_ms']<=33.3 and data['internal_scale']==1
    assert .1<data['render_gpu_p95_ms']<=baseline['render_gpu_p95_ms']+1
    assert data['foliage_mode']=='combined' and data['shadow_filter']=='medium'
toggle=read(CAP/'toggle_smoke.json');smoke=read(CAP/'smoke.json')
assert all(toggle[x] for x in ['f9_baseline_restore','camera_unchanged','wind_toggle','mipmaps','lod_hysteresis'])
assert toggle['restored_mean_abs_8bit']<=1.5 and smoke['portal_plant_intersections']==0 and smoke['lightmap_loaded']
files=[PROJECT/'render_v9_scene.gd',PROJECT/'render_v9.tscn']+list(OUT.glob('*.gd'))+list(OUT.glob('*.gdshader'))
report={'version':'RENDER V9 candidate','parent_commit':'36bba45','tracked_baselines_unchanged':True,'default_scene':'res://render_v4_live.tscn','changes':['shared runtime mipmaps for 2 previously unmipped foliage textures; normal mip renormalization','leaf-only normal variance roughness limiting, 0.60 floor, 15% backlight gain','0.3 degree sun with original Medium filter, 4096 32-bit atlas and safe bias','8% plant LOD hysteresis with baseline-matched initialization'],'continuous_frames':4800,'fixed_views':14,'sparse_motion_frames':96,'temporal_pan':comparison,'baseline_p95_ms':baseline['p95_ms'],'candidate_p95_ms':[x['p95_ms'] for x in perf],'baseline_gpu_p95_ms':baseline['render_gpu_p95_ms'],'candidate_gpu_p95_ms':[x['render_gpu_p95_ms'] for x in perf],'candidate_draw_calls':[x['draw_calls_last'] for x in perf],'f9':toggle,'rejected_high_filter_trials':{'baseline':read(CAP/'high_filter_baseline.json')['p95_ms'],'p95_ms':[read(CAP/f'high_filter_perf_{i}.json')['p95_ms'] for i in [1,2]],'reason':'Exceeded both total-frame and incremental GPU budgets'},'rejected_lod_initialization':'First candidate captured builder LOD0 instead of matching V8; retained under bad_lod_combined_*; excluded from acceptance.','rejected_045':'0.45-degree candidate passed the short diagnostic but improved the long 600-frame pan only 20.5%; retained as rejected045_combined_*.','metric_limits':'Fixed plant-shadow mask: diagnostic no-plant-shadow minus V8 temporal mean >5/255, 1555 pixels on registered road plane. Not a whole-scene perceptual or concept-similarity score. Videos fixed-step 30Hz; performance measured separately without capture.','source_textures_modified':False,'source_models_modified':False,'water_changes':False,'paid_credits':0,'source_sha256':{p.relative_to(PROJECT).as_posix():sha256(p.read_bytes()).hexdigest() for p in files}}
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
html='''<!doctype html><meta charset="utf-8"><title>V9 叶片闪烁验收</title><style>body{background:#151819;color:#ddd;font:16px system-ui;margin:28px}main,.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}img,video{width:100%}figure{margin:0 0 20px}figcaption{padding:8px}button{padding:8px 16px;margin:8px 0}a{color:#aef}</style><h1>V9：叶影稳定性与叶片受光</h1><p>原生 2560×1440 / MSAA4 / TAA 关闭。以下为连续引擎帧按固定 30Hz 记录的视频；实际性能另测，不用视频文件播放帧率代表游戏帧率。</p>'''
html+=f"<p>受测叶影区域 P95 时间二阶差分降低 {comparison['temporal_reduction']*100:.1f}%；阴影覆盖变化 {comparison['shadow_fraction_relative_change']*100:.1f}%。指标仅代表固定路面影区，不代表全场景。</p>"
for clip in ['pan','wind','static','lod','orbit']:
    html+=f'<h2>{clip}</h2><button onclick="playPair(\'{clip}\')">同步从头播放 V8 / V9</button><div class="pair" id="{clip}">'
    for mode in ['baseline','combined']:
        stem=f'{mode}_{clip}_sequence';html+=f'<figure><video controls muted playsinline preload="metadata" poster="captures/{stem}/0000.jpg" src="captures/{stem}.mp4"></video><figcaption>{"V8" if mode=="baseline" else "V9"} / {clip}</figcaption></figure>'
    html+='</div>'
html+='<h2>同机位与叶片粗糙度对照</h2><main>'
for stem in ['case_baseline_top','case_combined_top','close_baseline_top','close_combined_top','floor_0.55_top','floor_0.60_top','floor_0.65_top']:
    html+=f'<figure><a href="captures/{stem}.png"><img loading="lazy" src="captures/{stem}.png"></a><figcaption>{stem}</figcaption></figure>'
html+='</main><p>mipmap 缺失已修复，但它不是所测路面黑影的主因。关闭植物投影改善此影区；关闭叶片高光、法线和 SSAO/SSIL 几乎不改变该影区指标。更高滤波有稳定性收益但超预算；0.9°、1.2° 和 8K 阴影贴图在本测试中未改善。保留真实阴影，不靠关阴影或全屏模糊达标。剩余细叶亚像素采样仍可能有残余闪烁。</p><p>逐项隔离与完整调参见 temporal_analysis.json；性能及还原检查见 validation.json。默认入口仍为锁定 V4。</p><script>function playPair(id){document.querySelectorAll("#"+id+" video").forEach(v=>{v.pause();v.currentTime=0;v.play()})}</script>'
(OUT/'review.html').write_text(html,encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
