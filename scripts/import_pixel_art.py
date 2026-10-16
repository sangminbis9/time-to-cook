"""Slice image-generated overhead pixel atlases into Godot resources.

This script only imports authored raster art: alpha trim, nearest-neighbor sizing,
palette indexing and sheet packing. It does not draw game objects from geometry.
Rejected frontal concepts are retained in art_src; runtime uses overhead sources.
"""
from pathlib import Path
from PIL import Image, ImageOps
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art_src/jp_refresh'
TOP=SRC/'overhead'
OUT=ROOT/'game/rebuild/assets/jp'
OUT.mkdir(parents=True,exist_ok=True)
META={}

def open_im(name,overhead=False):
    return Image.open((TOP if overhead else SRC)/(name+'.png')).convert('RGBA')

def rows(im,count):
    a=np.asarray(im.getchannel('A'))
    if a.min()==255:return [(round(i*im.height/count),round((i+1)*im.height/count)) for i in range(count)]
    mask=(a>128).sum(axis=1)>max(12,im.width*.015)
    runs=[];start=None
    for i,on in enumerate(mask):
        if on and start is None:start=i
        if not on and start is not None:runs.append((start,i));start=None
    if start is not None:runs.append((start,len(mask)))
    # Merge tiny internal gaps in one sprite row, while retaining true gutters.
    while len(runs)>count:
        gaps=[runs[i+1][0]-runs[i][1] for i in range(len(runs)-1)]
        i=min(range(len(gaps)),key=gaps.__getitem__)
        runs[i:i+2]=[(runs[i][0],runs[i+1][1])]
    if len(runs)!=count:
        return [(round(i*im.height/count),round((i+1)*im.height/count)) for i in range(count)]
    boundaries=[0]+[round((runs[i][1]+runs[i+1][0])/2) for i in range(count-1)]+[im.height]
    return list(zip(boundaries,boundaries[1:]))

def cell(im,x,y,cols,row_bounds):
    y0,y1=row_bounds[y]
    strip=im.crop((0,y0,im.width,y1))
    # Generated atlases have real transparent gutters, not exact grid lines.
    # Find columns within each row so neighboring handles never leak in.
    columns=rows(strip.transpose(Image.Transpose.TRANSPOSE),cols)
    x0,x1=columns[x]
    return strip.crop((x0,0,x1,strip.height))

def clean(im):
    # Hard alpha removes generated antialiased fringes at the logical pixel grid.
    a=im.getchannel('A').point(lambda n:255 if n>=144 else 0)
    im.putalpha(a)
    bbox=a.getbbox()
    return im.crop(bbox) if bbox else im

def fit(im,size,colors=48,pad=1):
    im=clean(im)
    available=(size[0]-pad*2,size[1]-pad*2)
    factor=min(available[0]/im.width,available[1]/im.height)
    im=im.resize((max(1,round(im.width*factor)),max(1,round(im.height*factor))),Image.Resampling.NEAREST)
    a=im.getchannel('A')
    im=im.convert('RGB').quantize(colors=colors,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE).convert('RGBA')
    im.putalpha(a)
    canvas=Image.new('RGBA',size)
    canvas.alpha_composite(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
    return canvas

def save(name,im,anchor=None):
    im.save(OUT/(name+'.png'))
    META[name]={'size':list(im.size),'anchor':anchor or [0,0]}

props=['stock','board','batter','fryer','plate','counter','fridge','table','bench','door','stairs','kiosk','plant','extinguisher','generator','vent','drain','locker','climate','lounge','meal','drink','toilet','arcade','shower','wall_block','lamp','chair','parking','elevator','window','noren','crockery','lantern','rug','wall_menu']
im=open_im('furniture',True); bands=rows(im,6)
for i,name in enumerate(props):
    size=(32,32)
    if name=='window':size=(64,32)
    elif name=='rug':size=(64,24)
    elif name in ['chair','lamp','extinguisher','drain','lantern']:size=(24,28)
    save(name,fit(cell(im,i%6,i//6,6,bands),size),[(32-size[0])//2,32-size[1]])

terrain=['floor','kitchen','wall','grass','road','paving','water','floor_dark','tatami','moss','gravel','roof_red','road_dash','wall_side','flowers','roof_dark']
im=open_im('terrain')
for i,name in enumerate(terrain):
    c=im.crop((round(i%4*im.width/4),round(i//4*im.height/4),round((i%4+1)*im.width/4),round((i//4+1)*im.height/4)))
    c=c.resize((32,32),Image.Resampling.NEAREST)
    save(name,c)

regional={
    'kr_a':['incheon','seoul','busan','daegu'],
    'kr_b':['daejeon','gwangju','ulsan','jeju'],
    'jp_a':['tokyo','yokohama','osaka','nagoya'],
    'jp_b':['sapporo','fukuoka','kyoto','kobe']}
regional_props=['table','chair','bench','counter','fridge','door','plant','lamp']
themes={
 'incheon':('개항장 목재와 황동','floor_dark'), 'seoul':('현대 한옥과 백색 린넨','floor'),
 'busan':('항구의 푸른 목재와 로프','floor'), 'daegu':('보자기 직물과 자주색 목재','floor_dark'),
 'daejeon':('꿀빛 오크와 민트 레트로','floor'), 'gwangju':('대나무 공예와 청자','floor'),
 'ulsan':('리벳 철제와 재생 목재','floor_dark'), 'jeju':('현무암·라탄·감귤','floor'),
 'tokyo':('에도 남색과 밤나무','floor_dark'), 'yokohama':('항구 양관과 녹색 유리','floor_dark'),
 'osaka':('쇼와 빨간 비닐과 크롬','floor_dark'), 'nagoya':('금빛 장식과 올리브 직물','floor'),
 'sapporo':('자작나무와 울 쿠션','floor'), 'fukuoka':('하카타 직조와 야타이 삼나무','floor'),
 'kyoto':('마치야·라탄·와시','tatami'), 'kobe':('티크·버건디 가죽·황동','floor_dark')}
for source,cities in regional.items():
    im=open_im(source,True);bands=rows(im,4)
    for y,city in enumerate(cities):
        for x,kind in enumerate(regional_props):
            size=(24,28) if kind in ['chair','lamp'] else (32,32)
            save(city+'_'+kind,fit(cell(im,x,y,8,bands),size),[(32-size[0])//2,32-size[1]])

exterior_names=['restaurant_exterior','grocery_exterior','house_wood','house_plaster','rear_facade','produce_shelf','pantry_shelf','checkout','tree','utility_pole','fence','vending']
im=open_im('exteriors',True);bands=rows(im,3)
for i,name in enumerate(exterior_names):
    size=(128,112) if i<4 else ((128,80) if i==4 else ((48,48) if i in [5,6,7,11] else ((64,64) if i==8 else (48,48))))
    save(name,fit(cell(im,i%4,i//4,4,bands),size,64))

food_names=['food_raw','food_cut','food_prepared','food_undercooked','food_normal','food_overcooked','food_burnt','food_fried','food_sweet','food_spicy','food_soy','food_garlic','food_teriyaki','food_jeju','ingredient_flour','ingredient_box','ingredient_sauce','ingredient_pepper','ingredient_soy','ingredient_garlic','ingredient_citrus','rice','tea','scallions','dirty_light','dirty_medium','dirty_heavy','steam','bell','coin','basket','clean_cloth']
im=open_im('food');bands=rows(im,4)
for i,name in enumerate(food_names):save(name,fit(cell(im,i%8,i//8,8,bands),(24,24),40))
save('ingredient_chicken',Image.open(OUT/'food_raw.png'))

# Directional sheets use a stable foot baseline; authored pose plus a 1px gait
# shift gives a restrained four-frame walk without redrawing anatomy in code.
for source,count,offset in [('heroes',4,0),('npcs',8,4)]:
    im=open_im(source,True);bands=rows(im,4)
    for character in range(count):
        sheet=Image.new('RGBA',(128,160))
        for direction in range(4):
            pose=fit(cell(im,character,direction,count,bands),(30,37),48)
            for frame in range(4):
                frame_im=Image.new('RGBA',(32,40))
                frame_im.alpha_composite(pose,(1,1+[0,1,0,-1][frame]))
                sheet.alpha_composite(frame_im,(frame*32,direction*40))
        save('person_'+str(character+offset),sheet)

im=open_im('cars',True);bands=rows(im,4)
for car in range(5):
    sheet=Image.new('RGBA',(192,48))
    for direction in range(4):
        pose=fit(cell(im,car,direction,5,bands),(48,48),48,2)
        sheet.alpha_composite(pose,(direction*48,0))
    save('car_'+str(car),sheet)

ui_names=['ui_panel','ui_panel_indigo','ui_button','ui_hover','ui_pressed','ui_disabled','ui_ticket','ui_hud','ui_slot','ui_slot_selected','ui_bubble','ui_banner','ui_coin','ui_clock','ui_research','ui_flower']
im=open_im('ui');bands=rows(im,4)
for i,name in enumerate(ui_names):
    size=(64,64)
    if i in [2,3,4,5,7,10,11]:size=(64,32)
    if i>=12:size=(24,24)
    save(name,fit(cell(im,i%4,i//4,4,bands),size,48,0))

title=ImageOps.fit(open_im('title'),(640,360),method=Image.Resampling.NEAREST)
save('title',title)
map_im=open_im('map').resize((550,210),Image.Resampling.NEAREST)
save('country_map',map_im)
data={'version':1,'source':'image_gen original overhead atlases','logical_tile':32,'camera':'overhead 70-75 degrees; cars 90 degrees','assets':META,'regional_props':regional_props,'cities':{city:{'name':name,'floor':floor,'props':{kind:city+'_'+kind for kind in regional_props}} for city,(name,floor) in themes.items()}}
(ROOT/'game/rebuild/data/jp_art.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(SRC/'IMPORT_MANIFEST.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print('Imported',len(META),'authored pixel resources and',len(themes),'city furniture sets.')
