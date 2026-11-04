"""Keep one shared texture set; strip embedded images from geometry-only GLBs."""
import json,struct,sys,shutil,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[3]))
from pipeline.glb import GLB
p=Path(__file__).resolve().parent
src=p/'source/tree/textures';dest=p/'textures'
for kind,prefix in [('branch','tree_small_02_branch'),('leaves','tree_small_02_leaves'),('trunk','tree_small_02')]:
    for channel,suffix in [('base','diff'),('normal','nor_gl'),('orm','arm')]:
        file=src/('leaves_rgba.png' if kind=='leaves' and channel=='base' else f'{prefix}_{suffix}_4k.jpg')
        out=dest/(f'tree_{kind}_{channel}'+file.suffix)
        shutil.copyfile(file,out)
for lod in ['high','mid','low']:
    model=GLB(p/'assets'/f'tree_{lod}.glb')
    for i,mat in enumerate(model.doc['materials']):
        model.doc['materials'][i]={'name':mat.get('name','material'),'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.9},'doubleSided':True}
    for field in ['images','textures','samplers']:model.doc.pop(field,None)
    raw=json.dumps(model.doc,separators=(',',':')).encode();raw+=b' '*((-len(raw))%4)
    binary=model.binary;binary+=b'\0'*((-len(binary))%4)
    output=struct.pack('<4sII',b'glTF',2,12+8+len(raw)+8+len(binary))+struct.pack('<II',len(raw),0x4e4f534a)+raw+struct.pack('<II',len(binary),0x004e4942)+binary
    (p/'assets'/f'tree_{lod}_geometry.glb').write_bytes(output)
# Explicit VRAM compression + mipmaps for all newly introduced runtime maps.
for file in dest.iterdir():
    if file.suffix.lower() not in ['.png','.jpg']:continue
    importer=Path(str(file)+'.import')
    if importer.exists():
        text=importer.read_text(encoding='utf-8-sig')
        for key,value in [('compress/mode','2'),('mipmaps/generate','true'),('compress/normal_map','1' if 'normal' in file.name or 'nor_gl' in file.name else '0')]:
            text=re.sub(re.escape(key)+r'=.*',key+'='+value,text)
    else:
        normal=1 if 'normal' in file.name or 'nor_gl' in file.name else 0
        text=f'[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="res://atmosphere/textures/{file.name}"\n\n[params]\ncompress/mode=2\ncompress/normal_map={normal}\nmipmaps/generate=true\n'
    importer.write_text(text,encoding='utf-8')
print('SHARED_TREE_MAPS_READY, geometry-only GLBs have no embedded texture references')
