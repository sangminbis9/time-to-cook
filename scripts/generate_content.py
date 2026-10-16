"""Original deterministic 32px game artwork, audio and balance definitions."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, random, math, wave, struct
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/rebuild/assets'
DATA = ROOT / 'game/rebuild/data'
OUT.mkdir(parents=True, exist_ok=True)
DATA.mkdir(parents=True, exist_ok=True)
P = {'ink':'#5a4632','cream':'#f7efd9','mint':'#a8d8c9','wood':'#b98a5e','darkwood':'#886047','peach':'#efad88','gold':'#e9b45d','green':'#709775','blue':'#8db6c4','red':'#cc7766'}
random.seed(821)
def save(im,name): im.save(OUT / (name+'.png'))
def sprite():
    im=Image.new('RGBA',(32,32)); return im,ImageDraw.Draw(im)
def box(d,xy,c,outline=True): d.rectangle(xy,fill=P.get(c,c),outline=P['ink'] if outline else None)
for k in ['floor','kitchen','wall','grass','road','paving','water']:
    im,d=sprite(); bg={'floor':'wood','kitchen':'cream','wall':'cream','grass':'green','road':'#727e80','paving':'#c8c4b1','water':'blue'}[k]
    box(d,(0,0,31,31),bg,False)
    if k=='floor':
        for y in (0,8,16,24):
            d.line((0,y,31,y),fill='#a77953'); d.line(((y*3)%32,y,(y*3)%32,y+8),fill='#a77953')
        for _ in range(12):
            x,y=random.randrange(28),random.randrange(32); d.line((x,y,x+3,y),fill='#c79a6b')
    elif k=='kitchen':
        d.line((0,0,31,0),fill='#c5c5b0');d.line((0,0,0,31),fill='#c5c5b0');d.line((16,0,16,31),fill='#dfdaca');d.line((0,16,31,16),fill='#dfdaca')
    elif k=='wall':
        box(d,(0,22,31,31),'darkwood');d.line((0,20,31,20),fill=P['wood']);d.line((0,2,31,2),fill='#fff9e9')
    elif k=='grass':
        for _ in range(18):
            x,y=random.randrange(32),random.randrange(32);d.line((x,y,x+1,y-2),fill=random.choice(['#83a67a','#5c886b','#99b382']))
    elif k=='road':
        for _ in range(24): d.point((random.randrange(32),random.randrange(32)),fill='#7b8788')
    elif k=='paving':
        d.rectangle((1,1,30,30),outline='#a4ad9c');d.line((3,3,28,3),fill='#dcd9c3')
    elif k=='water':
        for y in (7,19,28):d.line((random.randrange(14),y,random.randrange(19,31),y),fill='#b2d4d4')
    save(im,k)
station_names=['stock','board','batter','fryer','plate','counter','fridge','table','bench','door','stairs','kiosk','plant','extinguisher','generator','vent','drain','locker','climate','lounge','meal','drink','toilet','arcade','shower','wall_block','lamp','chair','parking']
for k in station_names:
    im,d=sprite()
    if k in ['door','stairs']:
        box(d,(3,1,28,31),'darkwood');box(d,(6,3,25,31),'wood');box(d,(9,5,22,18),'mint');d.rectangle((22,22,23,24),fill=P['gold'])
        if k=='stairs':
            for y in range(8,30,5):box(d,(7,y,24,y+3),'cream')
    elif k=='plant':
        box(d,(10,20,22,29),'peach');d.ellipse((3,2,26,22),fill=P['green'],outline=P['ink']);d.ellipse((11,0,30,17),fill='#91b389',outline=P['ink']);d.line((17,12,17,24),fill=P['darkwood'],width=2)
    elif k=='table':
        box(d,(7,20,10,30),'darkwood');box(d,(23,20,26,30),'darkwood');box(d,(2,6,30,23),'wood');box(d,(3,5,29,19),'#d6ad78');d.line((5,7,27,7),fill='#ead1a4');box(d,(13,9,19,15),'cream');d.ellipse((15,9,18,12),fill=P['green'])
    elif k=='chair':
        box(d,(8,4,24,20),'wood');box(d,(7,17,25,26),'peach');box(d,(8,26,10,31),'darkwood');box(d,(22,26,24,31),'darkwood')
    else:
        box(d,(3,11,29,29),'darkwood');box(d,(2,5,30,23),'#c4c4af');box(d,(3,4,29,16),'mint');d.line((5,5,27,5),fill='#e0efdc');box(d,(6,20,14,27),'wood');box(d,(17,20,26,27),'wood')
        if k=='board':
            box(d,(7,6,25,14),'wood');d.polygon([(10,8),(22,9),(18,11),(10,10)],fill='#ebe9d5');box(d,(7,8,10,10),'darkwood')
        elif k=='batter':d.ellipse((8,5,24,15),fill=P['cream'],outline=P['ink']);d.ellipse((11,7,21,12),fill='#dcc5a0')
        elif k=='fryer':
            box(d,(5,5,26,16),'ink');box(d,(7,6,23,14),'gold');
            for x in range(8,24,4):d.line((x,7,x,13),fill='#b78547')
            box(d,(24,9,30,11),'darkwood');d.point((6,20),fill='#ed8b5d');d.point((9,20),fill=P['gold'])
        elif k=='plate':d.ellipse((8,5,24,15),fill=P['cream'],outline='#8ea79a');d.ellipse((11,7,21,12),outline='#d1c7b2')
        elif k=='stock':
            box(d,(4,4,28,16),'wood');
            for x in (8,17):d.ellipse((x,7,x+7,12),fill=P['peach'],outline=P['darkwood'])
        elif k=='fridge':
            box(d,(3,0,29,29),'#b4d3ce');box(d,(5,2,27,15),'#d6e7d9');box(d,(5,17,27,27),'#d6e7d9');box(d,(23,6,24,11),'ink')
        elif k=='counter':
            d.ellipse((9,6,20,13),fill=P['gold'],outline=P['ink']);box(d,(14,4,16,7),'gold')
        elif k=='kiosk' or k=='arcade':
            box(d,(7,1,25,24),'wood');box(d,(9,3,23,16),'ink');box(d,(11,5,21,12),'blue');d.ellipse((12,19,15,21),fill=P['red'])
        elif k=='extinguisher':box(d,(11,5,22,26),'red');box(d,(13,2,20,6),'ink');box(d,(13,12,20,18),'cream')
        elif k=='drink':box(d,(10,1,21,13),'blue');box(d,(8,12,24,27),'cream');box(d,(13,17,20,22),'ink')
        elif k=='lounge':box(d,(3,8,29,24),'peach');box(d,(2,14,7,26),'red');box(d,(25,14,30,26),'red')
        elif k=='meal':d.ellipse((7,6,24,17),fill=P['cream']);d.ellipse((12,8,20,13),fill=P['gold'])
        elif k=='locker':
            box(d,(4,0,28,29),'mint');
            for x in (6,17):
                box(d,(x,3,x+9,27),'#bddcc9');d.line((x+2,7,x+6,7),fill=P['ink']);d.point((x+7,17),fill=P['ink'])
        elif k=='climate':box(d,(2,4,30,16),'cream');d.line((5,12,27,12),fill=P['blue'])
        elif k=='toilet':d.ellipse((9,6,24,26),fill=P['cream'],outline=P['ink']);d.ellipse((12,11,21,21),fill=P['blue'])
        elif k=='shower':d.line((9,25,9,4,22,4,22,8),fill=P['blue'],width=3)
        elif k=='lamp':box(d,(14,11,17,28),'ink');d.polygon([(10,4),(22,4),(27,13),(5,13)],fill=P['gold'],outline=P['ink'])
    save(im,k)
im,d=sprite();box(d,(2,1,29,31),'darkwood');box(d,(5,4,26,30),'mint');box(d,(7,7,24,29),'#c4d4cb');d.line((16,7,16,29),fill=P['ink']);box(d,(11,2,20,5),'ink');d.point((15,3),fill=P['gold']);save(im,'elevator')
for char in range(12):
    sheet=Image.new('RGBA',(32*4,32*4));color=['#82b9a4','#d98d71','#7eabbc','#c6a35e','#a995bd','#bcad8b'][char%6]
    for direction in range(4):
        for frame in range(4):
            im,d=sprite();step=[0,1,0,-1][frame]
            d.ellipse((7,27,25,31),fill='#5a463240');box(d,(10,22,14,28+step),'ink');box(d,(19,22,23,28-step),'ink')
            box(d,(8,14,25,24),color);box(d,(12,16,21,23),'cream');box(d,(6,16,9,22),'peach');box(d,(25,16,27,22),'peach')
            box(d,(9,5,24,16),'peach');box(d,(8,3,25,8),'darkwood');box(d,(8,6,10,13),'darkwood')
            if char<4:
                box(d,(7,2,26,7),'cream');d.ellipse((8,0,17,6),fill=P['cream']);d.ellipse((16,0,25,6),fill=P['cream'])
            if direction!=3:
                eyes=[(12,11),(21,11)] if direction==0 else ([(11,11)] if direction==1 else [(22,11)])
                for x,y in eyes:d.rectangle((x,y,x+1,y+2),fill=P['ink'])
                d.line((16,15,19,15),fill='#bb775f')
            else:box(d,(9,7,24,14),'darkwood')
            sheet.paste(im,(frame*32,direction*32))
    save(sheet,'person_'+str(char))
for k,col in enumerate(['#91bba8','#e6c27b','#789fac','#cf9b81','#b8b0d0']):
    im,d=sprite();box(d,(3,7,6,24),'ink');box(d,(26,7,29,24),'ink');box(d,(6,2,26,29),col);box(d,(8,7,24,23),'ink');box(d,(9,8,23,13),'blue');box(d,(9,16,23,23),col);box(d,(9,24,23,26),'blue');box(d,(7,3,10,5),'cream');box(d,(22,3,25,5),'cream');box(d,(8,28,11,29),'red');box(d,(22,28,24,29),'red')
    sheet=Image.new('RGBA',(128,32))
    for direction,angle in enumerate([180,90,-90,0]):sheet.paste(im.rotate(angle),(direction*32,0))
    save(sheet,'car_'+str(k))
for stage in ['raw','cut','prepared','undercooked','normal','overcooked','burnt','fried','sweet','spicy','soy','garlic','teriyaki','jeju']:
    im,d=sprite(); cooked=stage in ['fried','sweet','spicy','soy','garlic','teriyaki','jeju'];
    if cooked:d.ellipse((4,13,28,28),fill=P['cream'],outline=P['ink']);d.ellipse((6,15,26,24),outline='#c4b69d')
    c={'raw':'#e6a28e','cut':'#e9b39a','prepared':'#ddc085','undercooked':'#dcc48f','normal':'#dfa649','overcooked':'#9e693c','burnt':'#574739','sweet':'#b97446','spicy':'#be6244','soy':'#986741','garlic':'#e3c080','teriyaki':'#ac7846','jeju':'#e1b754'}.get(stage,'#dfa649')
    for x,y in [(10,11),(17,9),(22,15),(14,18),(9,18)]:
        d.ellipse((x-4,y-3,x+4,y+4),fill=c,outline=P['darkwood']);d.line((x-2,y-1,x,y-2),fill='#f1d096')
    if cooked:
        for x,y in [(10,14),(18,19),(23,13)]:d.point((x,y),fill=P['green'])
    save(im,'food_'+stage)
# Original synthesized music and effects. No samples.
def wav(name,values,sr=22050):
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setparams((1,2,sr,0,'NONE','not compressed')); f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v))*18000)) for v in values))
for name,freq in [('click',650),('cut',180),('coin',980),('fry',90),('clean',320),('door',440),('engine',70),('bell',880),('fail',220),('skill',720)]:
    wav(name,[(math.sin(i/22050*freq*math.tau)+.25*math.sin(i/22050*freq*2*math.tau))*math.exp(-i/22050*19)*.4 for i in range(6600)])
for name,tempo in [('morning',.48),('business',.34)]:
    notes=[60,64,67,72,71,67,64,62,57,60,64,69,67,64,62,60,53,57,60,65,64,60,57,55,55,59,62,67,65,62,59,55]
    vals=[]
    for n in notes*4:
        hz=440*2**((n-69)/12)
        for i in range(int(22050*tempo)):
            t=i/22050; env=min(1,t/.008)*math.exp(-t*5)
            vals.append((math.sin(t*hz*math.tau)+.15*math.sin(t*hz*2*math.tau)+.28*math.sin(t*hz/2*math.tau))*.16*env)
    wav(name,vals)
def write(name,value): (DATA/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
cities=[]
for i,(id,name) in enumerate(zip(['incheon','seoul','busan','daegu','daejeon','gwangju','ulsan','jeju','tokyo','yokohama','osaka','nagoya','sapporo','fukuoka','kyoto','kobe'],['인천','서울','부산','대구','대전','광주','울산','제주','도쿄','요코하마','오사카','나고야','삿포로','후쿠오카','교토','고베'])):
    cities.append(dict(id=id,name=name,country='kr' if i<8 else 'jp',entry=0 if i==0 else [100000,180000,125000,95000,85000,80000,110000,145000,240000,195000,210000,175000,155000,165000,190000,175000][i],rent=[900,1800,1250,950,850,800,1000,1300,2400,1850,2100,1600,1400,1450,1750,1550][i],price=round(1+i*.025,3),demand=round(.8+(i%5)*.12,2),sensitivity=round(.7+(i%4)*.15,2),competition=.2+(i%3)*.12,spending=1+(i%4)*.1,risk=.02+(i%3)*.01,floors=3 if i in [1,8,10] else 2))
write('cities',cities)
write('vehicles',[dict(id=id,name=n,price=p,speed=s,capacity=c,trip=t,accel=5,brake=9,sprite='car_'+str(i)) for i,(id,n,p,s,c,t) in enumerate([('used_hatchback','중고 경차',32000,3.5,12,200),('compact','소형차',65000,5,16,300),('sedan','세단',110000,6.5,20,500),('van','소형 밴',145000,4.5,40,700),('sport_ev','고속 전기차',230000,8,16,450)])])
write('welfare',[dict(id=id,name=n,price=p,effect=e,fixed=f,usage=u,duration=d) for id,n,p,e,f,u,d in [('locker','개인 사물함',6000,.30,0,0,0),('climate','냉난방 설비',16000,.45,100,0,0),('lounge','휴게 공간',12000,.75,0,0,8),('meal','직원 식사 공간',24000,.90,0,150,12),('drink','음료대',5000,.30,0,40,3),('toilet','직원 전용 화장실',20000,.30,0,20,6),('arcade','오락 공간',36000,1.05,80,0,12),('shower','샤워실',30000,.60,0,60,10)]])
write('ingredients',[dict(id=id,name=n,cost=c) for id,n,c in [('chicken','생닭',450),('flour','튀김옷',100),('box','용기',50),('sauce','양념',150),('pepper','고추',120),('soy','간장',100),('garlic','마늘',130),('citrus','감귤',160)]])
write('recipes',[dict(id=id,name=n,price=p,deadline=t,sauce=s,unlock='' if i==0 else id,cut=4,fry=8,normal_end=15,burn=23) for i,(id,n,p,t,s) in enumerate([('fried','후라이드 닭강정',2700,95,''),('sweet','달콤한 양념',3200,105,'sauce'),('spicy','매운 양념',3400,110,'pepper'),('soy','간장 닭강정',3200,105,'soy'),('garlic','마늘 닭강정',3500,110,'garlic'),('teriyaki','테리야키',3900,115,'soy'),('jeju','제주 감귤',3800,110,'citrus')])])
research=[]
for id,n,cost,rp,pre in [('sweet','달콤한 양념',8000,4,''),('spicy','매운맛 연구',12000,6,'sweet'),('soy','간장 배합',10000,5,''),('garlic','마늘 풍미',15000,8,'soy'),('jeju','감귤 레시피',20000,10,'sweet'),('overseas','일본 진출',60000,25,'soy'),('teriyaki','테리야키 레시피',25000,12,'overseas'),('kiosk','키오스크',18000,8,''),('auto_order','자동 발주',25000,10,''),('supply','공급 계약 · 도매 5% 절약',32000,15,'auto_order'),('parking','주차 확장',16000,8,''),('floors','다층 매장',45000,20,'parking'),('logistics','글로벌 물류',80000,30,'overseas'),('equipment','튀김 안전창 확장',22000,10,''),('marketing','브랜드 캠페인',24000,10,''),('interior','고급 인테리어',16000,8,'')]: research.append(dict(id=id,name=n,cost=cost,rp=rp,prerequisite=pre))
write('research',research)
write('loans',[dict(id=id,name=n,principal=p,rate=r,term=t,maturity=.02) for id,n,p,r,t in [('working','운영자금',30000,.003,14),('equipment','설비투자',100000,.004,30),('global','해외진출',250000,.005,60)]])
write('grades',[dict(id=g,fee=f,wage=w,contract=c,rare=r,traits=tr) for g,f,w,c,r,tr in [('D',3000,700,7,.01,1),('C',6000,1200,10,.02,2),('B',12000,2000,14,.04,2),('A',24000,3300,21,.07,3),('S',48000,5000,30,.12,3)]])
write('balance',dict(tick=.05,business_seconds=720,closing_seconds=60,start_cash=90000,retail_multiplier=3,retail_floor=2.5,leave_min=2,leave_max=7,illness=.02,absence=.02,satisfaction_limit=3,queue_wait=40,dine_wait=40,takeout_wait=25,clean=[4,8,12],reputation_min=.7,reputation_max=1.3))
print('Generated original pixel art, audio, and definition catalogs.')
write('art_manifest',sorted(p.stem for p in OUT.glob('*.png')))
