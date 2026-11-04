from pathlib import Path
from PIL import Image
import numpy as np,json
p=Path(__file__).resolve().parent/'captures'
a=np.asarray(Image.open(p/'coverage_scene.png').convert('RGB'))
b=np.asarray(Image.open(p/'coverage_road.png').convert('RGB'))
green=(a[:,:,1]>180)&(a[:,:,0]<80)&(a[:,:,2]<80)
blue=(a[:,:,2]>180)&(a[:,:,0]<80)&(a[:,:,1]<80)
road=(b[:,:,0]>180)&(b[:,:,1]<80)&(b[:,:,2]<80)
h,w=green.shape;y,x=np.mgrid[:h,:w]
perimeter=(x<w*.15)|(x>w*.85)|(y<h*.18)|(y>h*.82)
regions={
 'perimeter':perimeter,
 'middle_belts':(x>w*.2)&(x<w*.8)&(y>h*.25)&(y<h*.75),
}
data={}
for name,mask in regions.items():
    denominator=np.count_nonzero((green|blue)&mask)
    data[name+'_plant_coverage']=np.count_nonzero(green&mask)/max(1,denominator)
data['road_plant_occlusion']=np.count_nonzero(green&road)/max(1,np.count_nonzero(road))
data['method']='Alpha-preserving unshaded category pass, peripheral 15% horizontal / 18% vertical bands; middle 20%-80% x,25%-75% y; vegetation vs exposed ground only. Props and road excluded from coverage denominator.'
data['targets']={'perimeter':[.70,.85],'middle_belts':[.65,.80],'max_road_occlusion':.10}
(p/'coverage.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(data))
