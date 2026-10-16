"""Steam size variants, branding and license packaging for human review."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import json, shutil
root=Path(__file__).resolve().parents[1]
assets=root/'game/rebuild/assets/jp'
out=root/'release/steam_art';out.mkdir(exist_ok=True,parents=True)
fontpath=root/'game/assets/fonts/Galmuri11-Bold.ttf'
# The title artwork is original generated project artwork. Produce size variants
# for distribution, preserving the unmodified source alongside the project.
art=Image.open(assets/'title.png').convert('RGB')
spec={'header_capsule':(920,430),'small_capsule':(462,174),'main_capsule':(1232,706),'vertical_capsule':(748,896),'library_capsule':(600,900),'library_hero':(3840,1240),'page_background':(1438,810)}
for name,(width,height) in spec.items():
    if height>width:
        im=ImageOps.fit(art,(width,height),method=Image.Resampling.NEAREST,centering=(.82,.5))
        overlay=Image.new('RGBA',(width,height),(0,0,0,0));d=ImageDraw.Draw(overlay)
        d.rectangle((0,0,width,int(height*.27)),fill=(247,239,217,230));im=Image.alpha_composite(im.convert('RGBA'),overlay)
        size=int(width*.13);x=int(width*.07);y=int(height*.04)
    else:
        im=ImageOps.fit(art,(width,height),method=Image.Resampling.NEAREST,centering=(.5,.5)).convert('RGBA')
        size=int(height*.14);x=int(width*.05);y=int(height*.16)
    if name not in ['library_hero','page_background']:
        d=ImageDraw.Draw(im);font=ImageFont.truetype(str(fontpath),size)
        d.multiline_text((x,y),'TIME TO\nCOOK',font=font,fill='#fff0cc',spacing=int(size*.1),stroke_width=max(1,int(size*.03)),stroke_fill='#222e42')
    im.save(out/(name+'.png'))
logo=Image.new('RGBA',(1280,720));d=ImageDraw.Draw(logo);font=ImageFont.truetype(str(fontpath),176);d.multiline_text((70,125),'TIME TO\nCOOK',font=font,fill='#f7efd9',spacing=20,stroke_width=8,stroke_fill='#5a4632');logo.save(out/'library_logo.png')
icon=Image.new('RGBA',(256,256),'#a8d8c9');food=Image.open(assets/'food_fried.png').resize((224,224),Image.Resampling.NEAREST);icon.alpha_composite(food,(16,16));icon.save(assets/'game.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)]);icon.save(out/'shortcut_icon.png');icon.convert('RGB').resize((184,184),Image.Resampling.NEAREST).save(out/'app_icon.jpg')
license_dir=root/'release/LICENSES';license_dir.mkdir(exist_ok=True)
shutil.copyfile(root/'game/assets/fonts/LICENSE.txt',license_dir/'Galmuri-OFL.txt')
(out/'manifest.json').write_text(json.dumps({'dimensions':spec,'source':'game/rebuild/assets/jp/title.png','source_tool':'OpenAI built-in image_gen','prompt':'Original Japanese life-sim pixel art title scene, coastal restaurant at dusk, warm paper lanterns, indigo noren, two young chefs, sage hatchback, detailed red roof and foliage, dark quiet left sky for menu typography, no text, no copied game assets.','prompt_set':'art_src/jp_refresh/PROMPTS.md','requirements_source':'https://partner.steamgames.com/doc/store/assets','review_required':True},ensure_ascii=False,indent=2),encoding='utf-8')
print('Steam artwork variants, icon and font license packaged.')
