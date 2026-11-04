from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter
p=Path(__file__).resolve().parent/'textures'
p.mkdir(exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/times.ttf',240)
for name in ['MEMORIA','TEMPVS','ORIGO','SAXVM']:
    image=Image.new('L',(2048,2048))
    draw=ImageDraw.Draw(image)
    box=draw.textbbox((0,0),name,font=font)
    draw.text(((2048-(box[2]-box[0]))/2,800),name,font=font,fill=235,stroke_width=1)
    image=image.filter(ImageFilter.GaussianBlur(.8))
    image.save(p/f'rune_{name.lower()}.png')
print('RUNE_HEIGHT_MAPS_READY')
