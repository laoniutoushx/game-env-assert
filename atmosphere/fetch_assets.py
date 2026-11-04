"""Fetch official CC0 sources; verify manifest MD5 before creating runtime variants."""
from pathlib import Path
import json,urllib.request,hashlib,shutil
p=Path(__file__).resolve().parent
source=p/'source';source.mkdir(parents=True,exist_ok=True)
(source/'.gdignore').write_text('')
def get(url,dest,md5=None):
    dest.parent.mkdir(parents=True,exist_ok=True)
    if not dest.exists() or (md5 and hashlib.md5(dest.read_bytes()).hexdigest()!=md5):
        req=urllib.request.Request(url,headers={'User-Agent':'GodotEnvironmentStudy/1.0'})
        with urllib.request.urlopen(req,timeout=180) as response,dest.open('wb') as stream:shutil.copyfileobj(response,stream)
    if md5:assert hashlib.md5(dest.read_bytes()).hexdigest()==md5,str(dest)
    print('VERIFIED',dest.name,flush=True)
tree_manifest=json.loads((p.parent/'tree_small_02/source_manifest.json').read_text())
tree=tree_manifest['gltf']['4k']['gltf']
treefolder=source/'tree'
get(tree['url'],treefolder/'tree_small_02_4k.gltf',tree['md5'])
for name,item in tree['include'].items():
    local=p.parent/'tree_small_02'/name
    target=treefolder/name
    if local.exists() and hashlib.md5(local.read_bytes()).hexdigest()==item['md5']:
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(local,target)
    else:get(item['url'],target,item['md5'])
alpha=tree_manifest['leaves_alpha']['4k']['png']
get(alpha['url'],treefolder/'textures/leaves_alpha.png',alpha['md5'])
from PIL import Image
gltf=json.loads((treefolder/'tree_small_02_4k.gltf').read_text())
rgba=Image.open(treefolder/gltf['images'][4]['uri']).convert('RGBA')
rgba.putalpha(Image.open(treefolder/'textures/leaves_alpha.png').convert('L'))
rgba.save(treefolder/'textures/leaves_rgba.png')
gltf['images'][4]['uri']='textures/leaves_rgba.png'
gltf['images'][4]['mimeType']='image/png'
gltf['materials'][1]['alphaMode']='MASK';gltf['materials'][1]['alphaCutoff']=0.45
(treefolder/'tree_prepared.gltf').write_text(json.dumps(gltf),encoding='utf-8')
url='https://api.polyhaven.com/files/forrest_ground_01'
get(url,source/'ground_manifest.json')
ground=json.loads((source/'ground_manifest.json').read_text())
for key in ['diff','nor_gl','rough','ao']:
    item=ground[{'diff':'Diffuse','rough':'Rough','ao':'AO'}.get(key,key)]['4k']['png']
    get(item['url'],source/'ground'/f'{key}.png',item['md5'])
# Runtime resources are kept apart from excluded source files.
runtime=p/'textures';runtime.mkdir(exist_ok=True)
for key in ['diff','nor_gl','rough','ao']:shutil.copyfile(source/'ground'/f'{key}.png',runtime/f'forest_{key}.png')
(p/'source_catalog.json').write_text(json.dumps({'tree':'https://polyhaven.com/a/tree_small_02','ground':'https://polyhaven.com/a/forrest_ground_01','license':'CC0','md5_verified':True,'new_meshy_credits':0},indent=2),encoding='utf-8')
