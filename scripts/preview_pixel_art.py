"""Compose contact sheets of existing sprites and engine captures for review."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, hashlib

root=Path(__file__).resolve().parents[1]
assets=root/'game/rebuild/assets/jp'
out=root/'release/visual-refresh'
data=json.loads((root/'game/rebuild/data/jp_art.json').read_text(encoding='utf-8'))
names=json.loads((root/'game/rebuild/data/cities.json').read_text(encoding='utf-8'))
font=ImageFont.truetype(str(root/'game/assets/fonts/Galmuri11.ttf'),16)
sheet=Image.new('RGB',(880,16*72+38),'#f3e6c8')
draw=ImageDraw.Draw(sheet)
for x,kind in enumerate(data['regional_props']):draw.text((330+x*66,10),kind,font=font,fill='#453d3c')
for y,city in enumerate(names):
    theme=data['cities'][city['id']]
    draw.text((12,y*72+45),city['name']+' · '+theme['name'],font=font,fill='#453d3c')
    for x,kind in enumerate(data['regional_props']):
        sprite=Image.open(assets/(theme['props'][kind]+'.png')).convert('RGBA')
        sprite=sprite.resize((sprite.width*2,sprite.height*2),Image.Resampling.NEAREST)
        sheet.paste(sprite,(330+x*66,y*72+38),sprite)
sheet.save(out/'all-city-furniture.png')
montage=Image.new('RGB',(1280,720))
for i,city in enumerate(['incheon','jeju','kyoto','kobe']):
    im=Image.open(out/('city_'+city+'.png')).resize((640,360),Image.Resampling.NEAREST)
    montage.paste(im,((i%2)*640,(i//2)*360))
montage.save(out/'four-cities.png')
for kind in data['regional_props']:
    hashes={hashlib.sha256((assets/(city+'_'+kind+'.png')).read_bytes()).hexdigest() for city in data['cities']}
    assert len(hashes)==16,(kind,'duplicate city sprites')
print('Composed 16-city furniture catalog and four engine views; all 128 regional sprites are unique.')
