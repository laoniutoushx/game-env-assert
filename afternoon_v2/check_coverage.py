from pathlib import Path
import json
import numpy as np
from PIL import Image
p=Path(__file__).resolve().parent
result={}
for view,limit in [('top',.01),('left',.03),('side',.03),('low_side',.05)]:
    full=np.array(Image.open(p/f'captures/coverage_{view}_full.png').convert('RGB'))
    road=np.array(Image.open(p/f'captures/coverage_{view}_road.png').convert('RGB'))
    mask=(road[:,:,0]>200)&(road[:,:,1]<40)&(road[:,:,2]<40)
    green=(full[:,:,1]>200)&(full[:,:,0]<40)&(full[:,:,2]<40)
    assert mask.sum()>10000, view
    ratio=float((mask&green).sum()/mask.sum())
    result[view]={'foliage_on_road':ratio,'limit':limit,'passed':ratio<=limit}
(p/'coverage.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
assert all(r['passed'] for r in result.values()),result
