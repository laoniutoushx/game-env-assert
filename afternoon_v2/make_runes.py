"""Procedural chisel height fields from vector strokes, shared by mesh and shader."""
from pathlib import Path
import numpy as np
from PIL import Image

out=Path(__file__).resolve().parent/'textures';out.mkdir(exist_ok=True)
glyphs=[[(.2,.1,.2,.9),(.2,.1,.8,.4),(.8,.4,.2,.6)],
[(.2,.9,.5,.1),(.5,.1,.8,.9),(.35,.55,.65,.55)],
[(.2,.1,.2,.9),(.2,.2,.8,.6),(.8,.1,.8,.9)],
[(.5,.1,.5,.9),(.2,.3,.5,.1),(.8,.3,.5,.1)],
[(.2,.1,.8,.1),(.8,.1,.2,.9),(.2,.9,.8,.9)],
[(.2,.1,.2,.9),(.2,.1,.8,.5),(.8,.5,.2,.9)],
[(.2,.5,.8,.5),(.5,.1,.5,.9),(.2,.1,.8,.9)],
[(.2,.1,.8,.5),(.8,.5,.2,.9),(.5,.3,.5,.7)]]
u,v=np.meshgrid((np.arange(512)+.5)/512,(np.arange(512)+.5)/512)
for variant in range(4):
    depth=np.zeros((512,512),dtype=np.float32)
    for row in range(2):
        for col in range(6):
            for x0,y0,x1,y1 in glyphs[(col+row*3+variant*2)%len(glyphs)]:
                x0=.13+col*.124+x0*.09;x1=.13+col*.124+x1*.09
                y0=.13+row*.38+y0*.28;y1=.13+row*.38+y1*.28
                dx,dy=x1-x0,y1-y0
                t=np.clip(((u-x0)*dx+(v-y0)*dy)/(dx*dx+dy*dy),0,1)
                distance=np.sqrt((u-x0-t*dx)**2+(v-y0-t*dy)**2)
                stroke=np.clip((.012-distance)/.006,0,1)
                depth=np.maximum(depth,stroke*stroke*(3-2*stroke))
    Image.fromarray((depth*255).astype('uint8')).save(out/f'rune_{variant}.png')
print('Generated four two-row vector rune height fields.')
