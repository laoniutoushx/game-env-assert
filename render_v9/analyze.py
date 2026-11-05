from pathlib import Path
import json,subprocess
import numpy as np
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parent
CAP=ROOT/'captures'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))

def canonical(image,record):
    points=np.array(record['quad'],float)-np.array(record['roi_origin'],float)
    dest=[(0,0),(255,0),(255,95),(0,95)]
    matrix=[];target=[]
    for (u,v),(x,y) in zip(dest,points):
        matrix.extend([[u,v,1,0,0,0,-u*x,-v*x],[0,0,0,u,v,1,-u*y,-v*y]])
        target.extend([x,y])
    coeff=np.linalg.solve(np.array(matrix),np.array(target))
    return np.asarray(image.convert('RGB').transform((256,96),Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BILINEAR),dtype=np.float32)

def analyze(folder):
    meta=read(folder/'metadata.json');records=read(folder/'frames.json')
    arrays=[]
    for record in records:
        with Image.open(folder/'roi'/f"{record['frame']:04d}.png") as image:arrays.append(canonical(image,record))
    data=np.stack(arrays);luma=data@np.array([.2126,.7152,.0722],dtype=np.float32)
    # No optical-flow estimate or JPEG is used for this metric: native PNG samples, known camera/road plane.
    d2=np.abs(luma[2:]-2*luma[1:-1]+luma[:-2])
    shadow_mask_path=CAP/'shadow_metric_mask.npy'
    mask=np.load(shadow_mask_path) if shadow_mask_path.exists() else np.ones(luma.shape[1:],dtype=bool)
    changed=sum(a['lod_signature']!=b['lod_signature'] for a,b in zip(records,records[1:]))
    plants=sum(a['lod_signature'][15:]!=b['lod_signature'][15:] for a,b in zip(records,records[1:]))
    result={'frames':len(records),'simulation_fps':30,'mode':meta['foliage_mode'],'clip':meta['clip'],'angle':meta['sun_angular_distance'],'taa':meta['taa'],'msaa':meta['msaa'],'p95_temporal_second_difference_8bit':float(np.percentile(d2,95)),'mean_temporal_second_difference_8bit':float(d2.mean()),'mean_luminance':float(luma.mean()),'lod_transitions':changed,'plant_lod_transitions':plants}
    result['shadow_filter']=meta.get('shadow_filter','medium');result['shadow_atlas']=meta.get('shadow_atlas',4096)
    mean=luma.mean(axis=0)
    result['p95_leaf_shadow_temporal_second_difference_8bit']=float(np.percentile(d2[:,mask],95))
    result['shadow_metric_mask_pixels']=int(mask.sum())
    np.save(folder/'registered_mean.npy',mean)
    Image.fromarray(np.clip(data.mean(axis=0),0,255).astype('uint8')).resize((768,288)).save(folder/'registered_mean.png')
    (folder/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result

def encode(folder):
    ffmpeg=next((ROOT/'tools').rglob('ffmpeg*.exe'))
    output=folder.with_suffix('.mp4')
    subprocess.run([str(ffmpeg),'-hide_banner','-loglevel','error','-y','-framerate','30','-i',str(folder/'%04d.jpg'),'-c:v','libx264','-threads','2','-preset','veryfast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(output)],check=True)
    # Compact all-frame visual index complements playback, without replacing the contiguous video.
    records=read(folder/'frames.json');selected=np.linspace(0,len(records)-1,48).round().astype(int)
    sheet=Image.new('RGB',(1920,1600),(20,24,26));draw=ImageDraw.Draw(sheet)
    for i,frame in enumerate(selected):
        with Image.open(folder/f'{frame:04d}.jpg') as image:
            image.thumbnail((320,180));sheet.paste(image,((i%6)*320,(i//6)*200))
        draw.text(((i%6)*320+4,(i//6)*200+181),str(frame),fill='white')
    sheet.save(folder/'contact.jpg',quality=92)

def summarize():
    results={}
    for folder in sorted(CAP.glob('*_sequence')):
        if not (folder/'metadata.json').exists():continue
        result=read(folder/'analysis.json') if (folder/'analysis.json').exists() else analyze(folder)
        meta=read(folder/'metadata.json')
        result['capture_observed_fps']=meta.get('capture_observed_fps',meta.get('fixed_fps'))
        results[folder.name.removesuffix('_sequence')]=result
    pairs={}
    for prefix in ['diag','angle','combined','trial']:
        basekey='diag_baseline' if prefix in ['diag','angle'] else 'baseline_pan'
        if basekey not in results:continue
        baseline=results[basekey];basefolder=CAP/(basekey+'_sequence')
        b=np.load(basefolder/'registered_mean.npy');threshold=np.median(b)*.7
        coverage=float((b<threshold).mean())
        for key,value in results.items():
            if not key.startswith(prefix+'_') or (prefix=='combined' and key!='combined_pan'):continue
            if value['clip']!='pan':continue
            a=np.load(CAP/(key+'_sequence')/'registered_mean.npy')
            pairs[key]={'temporal_reduction':1-value['p95_leaf_shadow_temporal_second_difference_8bit']/max(baseline['p95_leaf_shadow_temporal_second_difference_8bit'],1e-6),'whole_roi_temporal_reduction':1-value['p95_temporal_second_difference_8bit']/max(baseline['p95_temporal_second_difference_8bit'],1e-6),'baseline_shadow_fraction':coverage,'shadow_fraction':float((a<threshold).mean()),'shadow_fraction_relative_change':float(abs((a<threshold).mean()-coverage)/max(coverage,.001)),'mean_luminance_relative_change':float(abs(a.mean()-b.mean())/max(b.mean(),.001))}
    result={'sequences':results,'comparisons':pairs,'metric':'Native PNG road-plane reprojection; P95 absolute temporal second difference in 8-bit luminance. Quantitative flicker gate uses frozen-wind pan only.'}
    (ROOT/'temporal_analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('folders',nargs='*');parser.add_argument('--encode',action='store_true');args=parser.parse_args()
    for name in args.folders:
        folder=CAP/name
        if (folder/'metadata.json').exists():
            analyze(folder)
            if args.encode:encode(folder)
    summarize()
