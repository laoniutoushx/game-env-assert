"""Reproducible local geometry/UV/material audit, no network or paid calls."""
import io,json,sys,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT))
from pipeline.glb import GLB
PROJECT=ROOT/'work/environment_ruins'

def view(g,index):
    a=g.doc['accessors'][index];v=g.doc['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
    size=np.dtype(dtype).itemsize
    return np.ndarray((a['count'],n),dtype=dtype,buffer=g.binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',size*n),size))

def inspect(path):
    g=GLB(path);p=g.doc['meshes'][0]['primitives'][0]
    uv=view(g,p['attributes']['TEXCOORD_0']);index=view(g,p['indices']).reshape(-1,3)
    total=0;bad=0
    for start in range(0,len(index),100000):
        t=uv[index[start:start+100000]];e=t[:,1]-t[:,0];f=t[:,2]-t[:,0]
        area=np.abs(e[:,0]*f[:,1]-e[:,1]*f[:,0])/2
        total+=float(area.sum());bad+=int((area<1e-10).sum())
    maps={};m=g.doc['materials'][0]
    for label,texture_id in [('normal',m['normalTexture']['index']),('albedo',m['pbrMetallicRoughness']['baseColorTexture']['index']),('roughmetal',m['pbrMetallicRoughness']['metallicRoughnessTexture']['index'])]:
        content=g.image_bytes(g.doc['images'][g.doc['textures'][texture_id]['source']])
        image=Image.open(io.BytesIO(content)).convert('RGB');a=np.asarray(image)[::4,::4].astype(float)/255
        maps[label]={'size':image.size,'sha256':hashlib.sha256(content).hexdigest(),'mean':a.mean((0,1)).tolist(),'std':a.std((0,1)).tolist()}
    return {'path':str(path.relative_to(PROJECT)),'triangles':len(index),'attributes':list(p['attributes']),'uv_triangle_area_sum':total,'uv_degenerate_pct':bad/len(index)*100,'maps':maps}

names=['pilot_tree','tree_lod1','pilot_shrub','shrub_lod1','shrub_lod2','fern','fern_lod2','flowers_lod2','grass_lod2','stone_plain']
result={'note':'UV triangle area sum is not atlas occupancy and cannot prove absence of overlaps; full-resolution image sampling, not downscaled-image variance.','assets':[inspect(PROJECT/'meshy_assets'/(n+'.glb')) for n in names]}
for name in ['fern_repaired','shrub_repaired','stone_plain_reuv']:
    path=PROJECT/'quality_assets'/(name+'.glb')
    if path.exists():result['assets'].append(inspect(path))
(PROJECT/'quality_round/asset_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('AUDIT_SAVED',len(result['assets']))
