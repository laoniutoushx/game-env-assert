from pathlib import Path
from PIL import Image
import numpy as np,json
p=Path(__file__).resolve().parent/'captures'
def rgb(name):return np.asarray(Image.open(p/name).convert('RGB'))
def masks(tag):
    a=rgb(tag+'_scene.png');b=rgb(tag+'_road.png')
    green=(a[:,:,1]>180)&(a[:,:,0]<80)&(a[:,:,2]<80)
    blue=(a[:,:,2]>180)&(a[:,:,0]<80)&(a[:,:,1]<80)
    red=(a[:,:,0]>180)&(a[:,:,1]<80)&(a[:,:,2]<80)
    road=(b[:,:,0]>180)&(b[:,:,1]<80)&(b[:,:,2]<80)
    return green,blue,red,road
coverage={}
for view in ['top','left','side','low_side']:
    green,blue,red,road=masks('coverage_'+view)
    h,w=green.shape;y,x=np.mgrid[:h,:w]
    bands={'perimeter':(x<w*.15)|(x>w*.85)|(y<h*.18)|(y>h*.82),'middle_belts':(x>w*.2)&(x<w*.8)&(y>h*.25)&(y<h*.75)}
    r={key+'_plant_coverage':float(np.count_nonzero(green&mask)/max(1,np.count_nonzero((green|blue)&mask))) for key,mask in bands.items()}
    r['road_plant_occlusion']=float(np.count_nonzero(green&road)/max(1,np.count_nonzero(road)))
    coverage[view]=r
before=rgb('baseline_top.png')/255.;after=rgb('final_top.png')/255.
def luminance(a):
    linear=np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4)
    return linear@np.array([.2126,.7152,.0722])
a=luminance(before);b=luminance(after)
g0,b0,r0,_=masks('baseline_ids');g1,b1,r1,_=masks('coverage_top')
valid=(b0|r0)&(b1|r1)
baseline_dark=valid&(a<=np.quantile(a[valid],.25))
baseline_dark_gain=float(np.median(b[baseline_dark])/np.median(a[baseline_dark])-1)
sun0=luminance(rgb('baseline_ids_sun.png')/255.)
sun1=luminance(rgb('coverage_top_sun.png')/255.)
shadow=valid&(sun0<.015)&(sun1<.015)
assert np.count_nonzero(shadow)>1000,'Insufficient persistent shadow pixels'
gain=float(np.median(b[shadow])/np.median(a[shadow])-1)
# Bare ground directly adjacent to roads: 6-30 pixels away from visible road,
# excluding plants/props, using the final classification image.
from PIL import ImageFilter
expanded=np.asarray(Image.fromarray(np.uint8(r1)*255).filter(ImageFilter.MaxFilter(61)))>0
near=np.asarray(Image.fromarray(np.uint8(r1)*255).filter(ImageFilter.MaxFilter(13)))>0
adjacent=expanded&~near&b1
road_luma=float(np.median(b[r1]));ground_luma=float(np.median(b[adjacent]))
clipped=float(np.mean(np.min(after,axis=2)>=.98))
data={'coverage':coverage,'photometry':{'persistent_shadow_gain':gain,'persistent_shadow_pixels':int(np.count_nonzero(shadow)),'baseline_dark_quartile_gain_including_changed_shadows':baseline_dark_gain,'road_linear_luminance_median':road_luma,'adjacent_ground_linear_luminance_median':ground_luma,'road_to_adjacent_ground_ratio':road_luma/ground_luma,'near_white_fraction':clipped},'method':'Linear luminance from sRGB PNG. Persistent-shadow ROI: same pixels classified as ground/road in both images, direct-only gray surface luminance below 0.015 in both passes. The baseline-dark-quartile metric is retained separately because moving plants changes shadow coverage. Adjacent ground lies 6-30 pixels from the visible road. Coverage uses alpha-preserving unshaded IDs; not image similarity.'}
(p/'measurements.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(data))
if '--gate' in __import__('sys').argv:
    for view in ['top','left','side']:
        assert coverage[view]['road_plant_occlusion']<=.08,(view,coverage[view])
    assert .15<=gain<=.30,('dark_roi_gain',gain)
    assert road_luma/ground_luma>=1.1
    assert clipped<.005
