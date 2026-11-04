"""Regenerate the route shoulder mask from nextgen/road.gd's route and curb width."""
from pathlib import Path
import numpy as np
from PIL import Image
n=1024
z,x=np.mgrid[-20:20:complex(n),-20:20:complex(n)]
x=x/.85;z=z/1.2
d=np.full_like(x,100)
for a,b,row in [(-8.48,8.8,-3.4),(-8.48,8.32,0),(-8.96,8.32,3.4)]:
    d=np.minimum(d,np.hypot(x-np.clip(x,a,b),z-row))
d=np.minimum(d,np.where(x< -8.48,np.abs(np.hypot(x+8.48,z+1.7)-1.7),100))
d=np.minimum(d,np.where(x>8.32,np.abs(np.hypot(x-8.32,z-1.7)-1.7),100))
Image.fromarray(np.uint8(np.clip((d-.7)/3,0,1)*255)).save(Path(__file__).resolve().parent/'textures/road_distance.png')
