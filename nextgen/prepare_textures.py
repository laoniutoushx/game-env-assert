"""Extract true source pixels, without upscaling, with provenance and import settings."""
from pathlib import Path
import hashlib,json,zipfile
from PIL import Image,ImageEnhance
Image.MAX_IMAGE_PIXELS=300_000_000
p=Path(__file__).resolve().parent
regions=[(20,15,220,220),(835,15,1015,220),(1570,15,1770,210),(25,535,225,760),(270,560,445,750),(850,535,1050,745),(1110,545,1300,750),(1780,535,1980,745)]
outputs=[]
for channel in ['Color','NormalGL','Roughness','Displacement']:
    src=p/'source'/f'Tiles130_12K-PNG_{channel}.png'
    if not src.exists():
        if channel=='Displacement':continue
        raise FileNotFoundError(src)
    im=Image.open(src)
    # Reference rectangles were measured in the 2K atlas; preserve their pixel density.
    factor=im.width/2048
    for i,r in enumerate(regions):
        box=tuple(round(x*factor) for x in r)
        crop=im.crop(box)
        if channel=='Color':
            crop=ImageEnhance.Color(crop).enhance(.25)
            crop=ImageEnhance.Brightness(crop).enhance(1.22)
        out=p/'textures'/f'slab_{i}_{channel}.png'
        crop.save(out)
        normal=1 if channel=='NormalGL' else 0
        importer=Path(str(out)+'.import')
        # Never erase Godot's generated remap/cache path on subsequent preparation.
        if not importer.exists():
            importer.write_text(f'[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="res://nextgen/textures/{out.name}"\n\n[params]\ncompress/mode=0\ncompress/normal_map={normal}\nmipmaps/generate=true\nroughness/mode=0\nprocess/fix_alpha_border=true\n',encoding='utf-8')
        outputs.append({'path':out.name,'pixels':crop.size,'source_rectangle':box,'channel':channel})
# Keep original ground colour, compress only its fine colour contrast (not a blur).
ground=Image.open(p.parent/'textures/ground_muted.jpg').convert('RGB')
ground=ImageEnhance.Contrast(ground).enhance(.68)
ground.save(p/'textures/ground_balanced.png')
archive=p/'source/Tiles130_12K-PNG.zip'
digest=hashlib.sha256()
with archive.open('rb') as stream:
    for chunk in iter(lambda:stream.read(8*1024*1024),b''):digest.update(chunk)
metadata={'source':'https://ambientcg.com/view?id=Tiles130','license':'CC0','source_archive':archive.name,'sha256':digest.hexdigest(),'no_upscaling':True,'outputs':outputs,'new_meshy_credits':0}
(p/'textures/catalog.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
print('PREPARED_TEXTURES',len(outputs),outputs[0]['pixels'])
