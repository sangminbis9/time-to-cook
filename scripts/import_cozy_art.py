"""Import authored 3/4 pixel atlases without palette reduction or synthetic poses.

Only alpha cleanup, crop, nearest scaling and frame packing occur here. Original
source files and prompts remain in art_src/cozy_overhaul for re-import/review.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import json

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art_src/cozy_overhaul'
OUT=ROOT/'game/rebuild/assets/cozy'
OUT.mkdir(parents=True,exist_ok=True)
meta={'assets':{},'cities':{},'animation_rows':['down','left','right','up','carry','chop','cook','clean']}

def bands(im,count,axis=0):
    a=np.asarray(im.getchannel('A'))
    if axis==1:a=a.T
    mask=(a>160).sum(axis=1)>max(8,a.shape[1]*.012)
    runs=[];start=None
    for i,on in enumerate(mask):
        if on and start is None:start=i
        if not on and start is not None:runs.append((start,i));start=None
    if start is not None:runs.append((start,len(mask)))
    while len(runs)>count:
        k=min(range(len(runs)-1),key=lambda i:runs[i+1][0]-runs[i][1]);runs[k:k+2]=[(runs[k][0],runs[k+1][1])]
    if len(runs)!=count:return [(round(i*len(mask)/count),round((i+1)*len(mask)/count)) for i in range(count)]
    edges=[0]+[(runs[i][1]+runs[i+1][0])//2 for i in range(count-1)]+[len(mask)]
    return list(zip(edges,edges[1:]))

def cells(name,cols,rows):
    im=Image.open(SRC/(name+'.png')).convert('RGBA');out=[]
    reviewed=json.loads((SRC/'frame_bounds.json').read_text()) if (SRC/'frame_bounds.json').exists() else {}
    edges=reviewed.get(name)
    row_bounds=list(zip(edges,edges[1:])) if edges else bands(im,rows)
    for y0,y1 in row_bounds:
        strip=im.crop((0,y0,im.width,y1));line=[]
        for x0,x1 in bands(strip,cols,1):
            c=strip.crop((x0,0,x1,strip.height));c.putalpha(c.getchannel('A').point(lambda a:255 if a>=160 else 0))
            box=c.getbbox();line.append(c.crop(box) if box else c)
        out.append(line)
    return out

def fit(im,size,scale=None):
    scale=scale or min((size[0]-2)/im.width,(size[1]-2)/im.height)
    dims=(max(1,round(im.width*scale)),max(1,round(im.height*scale)))
    im=im.resize(dims,Image.Resampling.NEAREST)
    out=Image.new('RGBA',size);out.alpha_composite(im,((size[0]-im.width)//2,size[1]-im.height-1));return out

def save(name,im,foot=(1,1)):
    im.save(OUT/(name+'.png'));meta['assets'][name]={'size':list(im.size),'anchor':[foot[0]*16-im.width//2,foot[1]*32-im.height],'footprint':list(foot)}

interior=cells('interior',6,4)
specs=[('module',(32,40),(1,1)),('board',(32,40),(1,1)),('batter',(32,40),(1,1)),('fryer',(32,40),(1,1)),('plate',(32,40),(1,1)),('corner',(32,40),(1,1)),('stock',(64,64),(2,1)),('fridge',(32,64),(1,1)),('counter',(64,48),(2,1)),('table',(64,48),(2,1)),('chair',(24,32),(1,1)),('bench',(64,48),(2,1)),('window',(64,64),(2,1)),('door',(32,64),(1,1)),('shelf',(64,32),(2,1)),('wall_menu',(32,48),(1,1)),('plant',(32,48),(1,1)),('lamp',(24,48),(1,1)),('rug',(96,64),(3,2)),('wall_module',(64,64),(2,1)),('post',(16,64),(1,1)),('clock',(24,24),(1,1)),('barrel',(32,40),(1,1)),('sink',(32,40),(1,1))]
for i,(name,size,foot) in enumerate(specs):save(name,fit(interior[i//6][i%6],size),foot)

terrain=Image.open(SRC/'terrain.png').convert('RGBA')
terrain_names=['floor','floor_alt','floor_dark','kitchen','wall','wall_side','grass','paving','tatami','basalt','checker','birch','road','road_dash','water','soil']
for i,name in enumerate(terrain_names):
    x,y=i%4,i//4;im=terrain.crop((round(x*terrain.width/4),round(y*terrain.height/4),round((x+1)*terrain.width/4),round((y+1)*terrain.height/4))).resize((64,64),Image.Resampling.NEAREST)
    save(name,im)

for idx,name in enumerate(['hana','jun','bori','sora']):
    frames=cells(name,4,8);scale=43/float(np.median([c.height for row in frames[:4] for c in row]))
    sheet=Image.new('RGBA',(128,384))
    for y,row in enumerate(frames):
        for x,im in enumerate(row):sheet.alpha_composite(fit(im,(32,48),min(scale,30/im.width,46/im.height)),(x*32,y*48))
    save('person_'+str(idx),sheet)

if (SRC/'idle_interact.png').exists():
    atlas=cells('idle_interact',8,4)
    for idx in range(4):
        source=Image.open(OUT/f'person_{idx}.png');sheet=Image.new('RGBA',(128,480));sheet.alpha_composite(source)
        scale=43/float(np.median([im.height for im in atlas[idx]]))
        for col,im in enumerate(atlas[idx]):sheet.alpha_composite(fit(im,(32,48),min(scale,30/im.width,46/im.height)),((col%4)*32,(8+col//4)*48))
        save('person_'+str(idx),sheet)

groups={'regional_kr':['incheon','seoul','busan','jeju'],'regional_kr_b':['daegu','daejeon','gwangju','ulsan'],'regional_jp':['kyoto','kobe','osaka','sapporo'],'regional_jp_b':['tokyo','yokohama','nagoya','fukuoka']}
for source,cities in groups.items():
    if not (SRC/(source+'.png')).exists():continue
    atlas=cells(source,8,4)
    for y,city in enumerate(cities):
        props={}
        for x,(kind,size,foot) in enumerate([('table',(64,48),(2,1)),('table_vertical',(32,64),(1,2)),('chair',(24,32),(1,1)),('bench',(64,40),(2,1)),('counter',(64,48),(2,1)),('fridge',(32,64),(1,1)),('plant',(32,48),(1,1)),('lamp',(24,48),(1,1))]):
            key=city+'_'+kind;save(key,fit(atlas[y][x],size),foot);props['seating_bench' if kind=='bench' else kind]=key
        meta['cities'][city]={'props':props}

if (SRC/'guests.png').exists():
    atlas=cells('guests',8,8)
    for idx in range(2):
        frames=[row[idx*4:idx*4+4] for row in atlas];scale=min(30/max(c.width for row in frames for c in row),46/max(c.height for row in frames for c in row));sheet=Image.new('RGBA',(128,384))
        for y,row in enumerate(frames):
            for x,im in enumerate(row):sheet.alpha_composite(fit(im,(32,48),scale),(x*32,y*48))
        save('guest_'+str(idx),sheet)

if (SRC/'neighborhood.png').exists():
    atlas=cells('neighborhood',4,4)
    names=['house_cream','fishmonger','bakery','grocery_exterior','jeju_house','kyoto_house','kobe_house','restaurant_exterior','tree','cherry_tree','citrus_tree','garden','bikes','harbor','fountain','fence_garden']
    for i,name in enumerate(names):save(name,fit(atlas[i//4][i%4],(128,112) if i<8 else ((64,96) if i<11 else (64,48))))

if (SRC/'effects.png').exists():
    atlas=cells('effects',4,3)
    for i in range(4):save('steam_'+str(i),fit(atlas[0][i],(24,32)))
    for i,(name,size) in enumerate([('shadow',(28,10)),('shadow_wide',(64,12)),('lamp_light',(80,64)),('window_light',(96,112))]):save(name,fit(atlas[1][i],size))
    for i,name in enumerate(['sparkle','dust','leaves','glint']):save(name,fit(atlas[2][i],(24,24)))

if (SRC/'ui.png').exists():
    atlas=cells('ui',4,2)
    for i,name in enumerate(['ui_panel','ui_button','ui_hover','ui_pressed','ui_slot','ui_slot_selected','ui_ticket','ui_card']):
        # Exact rectangle including border: no letterbox padding in nine-slice skins.
        size=(64,32) if i in [1,2,3] else (64,64)
        save(name,atlas[i//4][i%4].resize(size,Image.Resampling.NEAREST))
    save('ui_hud',Image.open(OUT/'ui_card.png'));save('ui_disabled',Image.open(OUT/'ui_button.png'))

if (SRC/'vehicles.png').exists():
    atlas=cells('vehicles',4,5)
    for i in [0,1,3]:
        size=(56,56) if i<2 else (72,64);sheet=Image.new('RGBA',(size[0]*4,size[1]))
        for j,im in enumerate(atlas[i]):sheet.alpha_composite(fit(im,size),(j*size[0],0))
        save('car_'+str(i),sheet)
if (SRC/'vehicle_corrections.png').exists():
    atlas=cells('vehicle_corrections',4,2)
    for i,idx in enumerate([2,4]):
        sheet=Image.new('RGBA',(256,64))
        for j,im in enumerate(atlas[i]):sheet.alpha_composite(fit(im,(64,64)),(j*64,0))
        save('car_'+str(idx),sheet)
if (SRC/'architecture.png').exists():
    atlas=cells('architecture',4,4)
    names=['lowwall_kr','lowwall_jeju','lowwall_kyoto','lowwall_kobe','window_kr','window_jeju','window_kyoto','window_kobe','bench','corner','kitchen_shelf','entry_curtain','painting_kr','painting_jeju','painting_kyoto','painting_kobe']
    for i,name in enumerate(names):
        size=(64,40) if i<4 else ((64,64) if i<8 else ((64,48) if i==8 else ((32,40) if i==9 else ((32,64) if i==10 else ((64,32) if i==11 else (32,32))))))
        imported=atlas[i//4][i%4].resize(size,Image.Resampling.NEAREST) if i<4 else fit(atlas[i//4][i%4],size)
        save(name,imported,(2,1) if size[0]==64 else (1,1))

if (SRC/'grocery.png').exists():
    atlas=cells('grocery',4,2)
    for i,name in enumerate(['grocery_produce','grocery_meat','grocery_grain','grocery_sauce','grocery_boxes','grocery_drinks','checkout','grocery_sign']):save(name,fit(atlas[i//4][i%4],(64,64) if i!=7 else (96,40)),(2,1))

(ROOT/'game/rebuild/data/cozy_art.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Imported {len(meta["assets"])} authored assets, {len(meta["cities"])} regional collections; no palette quantization.')
