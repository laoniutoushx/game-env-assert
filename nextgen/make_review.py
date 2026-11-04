from pathlib import Path
from PIL import Image,ImageDraw
import json
p=Path(__file__).resolve().parent
labels=['msaa','fsr2','ssaa']
boxes={'leaves':(700,20,1300,420),'stone':(550,260,1150,660)}
for name,box in boxes.items():
    canvas=Image.new('RGB',(600*3,430),'#171c19')
    d=ImageDraw.Draw(canvas)
    for i,label in enumerate(labels):
        src=p/f'sampling_{label}_close.png'
        if src.exists():canvas.paste(Image.open(src).crop(box),(600*i,30))
        d.text((600*i+15,8),label+' : native 100% crop',fill='white')
    canvas.save(p/f'aa_{name}_100pct.png')
for label in labels+['final']:
    folder=p/(f'sampling_{label}_motion' if label!='final' else 'final_motion')
    files=sorted(folder.glob('*.png'))
    if not files:continue
    output=p/f'{label}_motion.webp'
    if output.exists() and output.stat().st_mtime>=max(f.stat().st_mtime for f in files):continue
    # Preview uses explicit resizing; untouched full-size frames remain accessible.
    frames=[]
    for f in files:
        im=Image.open(f).convert('RGB')
        im.thumbnail((1280,720))
        frames.append(im)
    frames[0].save(output,save_all=True,append_images=frames[1:],duration=70,loop=0,quality=80,method=3)
summary={}
for label in labels+['final']:
    f=p/(f'sampling_{label}_benchmark.json' if label!='final' else 'final_benchmark.json')
    if f.exists():summary[label]=json.loads(f.read_text())
(p/'comparison.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print('REVIEW_ARTIFACTS_READY',list(summary))
