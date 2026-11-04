from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json
p=Path(__file__).resolve().parent
box=(1350,650,1850,1000)
names=['sampling_msaa','probe_color','probe_normals','probe_ao','probe_shadows']
canvas=Image.new('RGB',(500*len(names),380),'#151a17')
draw=ImageDraw.Draw(canvas)
stats={}
for i,name in enumerate(names):
    im=Image.open(p/(name+'_close.png')).convert('RGB').crop(box)
    canvas.paste(im,(i*500,30))
    draw.text((i*500+10,10),name,fill='white')
    a=np.array(im).astype(float)/255
    stats[name]={'mean_neighbor_difference':float(np.abs(a[1:]-a[:-1]).mean()),'note':'Diagnostic ROI variation, not a universal image quality score'}
canvas.save(p/'probe_ground_100pct.png')
(p/'probe_roi.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
