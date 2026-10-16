extends Node2D
# Authored raster sprites share one overhead camera and a 32px world grid.
# City variants also apply to furniture placed by the player.
var session
var textures: Dictionary = {}
var art: Dictionary = {}
var font: Font = preload("res://assets/fonts/Galmuri11.ttf")
var camera: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var colorblind: bool = false
var build_kind: String = ""
var build_rotation: int = 0
var floor_layer: TileMapLayer
var floor_key: String = ""
const FLOORS = ["floor","kitchen","wall","floor_dark","tatami","wall_side"]
var palette = {"ink":Color("453d3c"),"cream":Color("fff0cc"),"mint":Color("a8c4a1"),"gold":Color("efc270"),"red":Color("cc7766")}

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	art=JSON.parse_string(FileAccess.get_file_as_string("res://rebuild/data/jp_art.json"))
	for asset_name in art.assets:textures[asset_name]=load("res://rebuild/assets/jp/%s.png"%asset_name)
	floor_layer=TileMapLayer.new();floor_layer.z_index=-1;floor_layer.tile_set=TileSet.new();floor_layer.tile_set.tile_size=Vector2i(32,32);add_child(floor_layer)
	for kind in FLOORS:
		var atlas=TileSetAtlasSource.new();atlas.texture=textures[kind];atlas.texture_region_size=Vector2i(32,32);atlas.create_tile(Vector2i.ZERO)
		floor_layer.tile_set.add_source(atlas,FLOORS.find(kind))

func _process(delta: float) -> void:elapsed+=delta;queue_redraw()

func tile(name: String,point: Vector2) -> void:
	if textures.has(name):draw_texture(textures[name],point.round())

func regional(kind: String,city: String) -> String:
	return art.cities.get(city,{}).get("props",{}).get(kind,kind)

func furnishing(kind: String,point: Vector2,city: String,rotation: int=0) -> void:
	var name=regional(kind,city)
	if not textures.has(name):return
	var anchor=art.assets[name].anchor;var offset=Vector2(anchor[0],anchor[1])
	if rotation!=0:
		draw_set_transform(point+Vector2(16,16)-camera,rotation*PI/2)
		tile(name,offset-Vector2(16,16));draw_set_transform(-camera)
	else:tile(name,point+offset)

func food(stage: String,point: Vector2) -> void:
	var name="food_"+stage
	if textures.has(name):draw_texture_rect(textures[name],Rect2(point.round(),Vector2(20,20)),false)

func text(value: String,point: Vector2,size: int=10,color: Color=Color("453d3c")) -> void:
	draw_string(font,point.round()+Vector2(0,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("fff0cc"))
	draw_string(font,point.round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func person(actor: Dictionary,character: int,walking: bool=false) -> void:
	var point=Vector2(actor.x,actor.y)-Vector2(16,35)
	var frame=int(elapsed*7)%4 if walking else 0;var direction=int(actor.get("face",0))
	var tex=textures.get("person_%d"%character)
	if tex:draw_texture_rect_region(tex,Rect2(point.round(),Vector2(32,40)),Rect2(frame*32,direction*40,32,40))

func car_sprite(name: String,point: Vector2,direction: int) -> void:
	if textures.has(name):draw_texture_rect_region(textures[name],Rect2((point-Vector2(24,24)).round(),Vector2(48,48)),Rect2(direction*48,0,48,48))

func bar(point: Vector2,value: float,color: Color=Color("a8c4a1")) -> void:
	draw_rect(Rect2(point,Vector2(28,4)),palette.ink)
	draw_rect(Rect2(point+Vector2.ONE,Vector2(clampf(value,0,1)*26,2)),color)

func _draw() -> void:
	if session==null or session.world.state.is_empty() or not session.connected:return
	var w=session.world;var st=w.state;var p=st.players.get(session.local_id(),{})
	if p.is_empty():return
	var s=st.stores[p.store]
	if p.location=="road":camera=Vector2(clampf(p.x-320,0,2400),0)
	elif p.location=="store":camera=Vector2(clampf(p.x-320,-32,(int(s.get("width",18))-18)*32-32),clampf(p.y-218,-48,int(s.get("height",13))*32-300))
	elif p.location=="parking":camera=Vector2(-32,-16)
	else:camera=Vector2(-32,clampf(p.y-220,-16,88))
	camera=camera.round();floor_layer.visible=p.location=="store";floor_layer.position=-camera
	draw_set_transform(-camera)
	match p.location:
		"store":draw_store(w,s,p)
		"parking":draw_parking(w,s,p)
		"road":draw_road(w,s,p)
		"retail":draw_retail(w,s,p)
	draw_set_transform(Vector2.ZERO)

func draw_store(w,s: Dictionary,p: Dictionary) -> void:
	var width=int(s.get("width",18));var height=int(s.get("height",13))
	var dining=art.cities.get(s.id,{}).get("floor","floor") if s.floor_style=="floor" else "kitchen"
	var layout_key="%s:%s:%s"%[s.id,p.floor,s.floor_style]
	if floor_key!=layout_key:
		floor_key=layout_key;floor_layer.clear()
		for y in range(height):
			for x in range(width):
				var kind=dining if y>4 else "kitchen"
				if y==0 or y==height-1:kind="wall"
				elif x==0 or x==width-1:kind="wall_side"
				if y==height-1 and x in [7,8,9]:kind=dining
				floor_layer.set_cell(Vector2i(x,y),FLOORS.find(kind),Vector2i.ZERO)
	for y in range(-3,height+2):
		for x in [-2,-1,width,width+1]:tile("moss" if y%3 else "flowers",Vector2(x,y)*32)
	for x in [3,7,11]:tile("window",Vector2(x*32,0))
	tile("wall_menu",Vector2(13*32,0));tile("noren",Vector2(8*32,(height-1)*32-8))
	for y in [4,8]:
		furnishing("lamp",Vector2(0,y*32),s.id);furnishing("lamp",Vector2((width-1)*32,y*32),s.id)
	for obj in s.objects:
		if obj.kind=="table" and int(obj.floor)==int(p.floor):
			furnishing("chair",Vector2(obj.x*32-29,obj.y*32+2),s.id,1)
			furnishing("chair",Vector2(obj.x*32+29,obj.y*32+2),s.id,3)
	var things: Array=[]
	for obj in s.objects:
		if int(obj.floor)==int(p.floor):things.append({"y":obj.y*32+32,"type":"object","data":obj})
	for c in s.customers:
		if int(c.floor)==int(p.floor):things.append({"y":c.y,"type":"customer","data":c})
	for e in w.state.staff:
		if e.store==s.id and int(e.floor)==int(p.floor) and e.state not in ["휴가","병가","결근"]:things.append({"y":e.y,"type":"staff","data":e})
	for id in w.state.players:
		var actor=w.state.players[id]
		if actor.store==s.id and actor.location=="store" and int(actor.floor)==int(p.floor):things.append({"y":actor.y,"type":"player","data":actor,"id":id})
	for key in s.floor_items:
		var parts=key.split(":")
		if int(parts[0])==int(p.floor):food(s.floor_items[key].stage,Vector2(int(parts[1])*32+6,int(parts[2])*32+6))
	things.sort_custom(func(a,b):return a.y<b.y)
	for thing in things:
		var actor=thing.data
		match thing.type:
			"object":
				var point=Vector2(actor.x*32,actor.y*32)
				furnishing(actor.kind,point,s.id,int(actor.rotation))
				if actor.kind=="table" and actor.dirty>0:
					tile("dirty_heavy" if actor.dirty>8 else ("dirty_medium" if actor.dirty>4 else "dirty_light"),point+Vector2(4,4))
					bar(point+Vector2(2,30),1-actor.dirty/12,palette.red)
				if actor.item!=null:
					food(actor.item.stage,point+Vector2(6,0))
					if actor.kind=="fryer":
						bar(point+Vector2(2,30),actor.item.heat/23,palette.gold if actor.item.stage=="normal" else palette.red)
						if actor.item.heat>0:draw_texture(textures.steam,point+Vector2(4,-12-int(elapsed*5)%6),Color(1,1,1,.65))
					elif actor.item.stage=="raw":bar(point+Vector2(2,30),actor.item.progress/4)
				if actor.lock!="":tile("bell",point+Vector2(13,-12))
			"customer":
				person(actor,int(actor.sprite),actor.state in ["table_walk","counter_walk","leaving"])
				if actor.state in ["waiting","ordered"]:
					var point=Vector2(actor.x-14,actor.y-51)
					draw_texture_rect(textures.ui_bubble,Rect2(point,Vector2(29,18)),false)
					text("J" if actor.state=="waiting" else str(int(actor.timer)),point+Vector2(7,12),10,palette.red if actor.timer<20 else palette.ink)
				if actor.state=="eating":food(actor.recipe,Vector2(actor.x-10,actor.y-48))
			"staff":
				person(actor,int(actor.sprite),actor.state=="이동")
				text(actor.name,Vector2(actor.x-12,actor.y-38),9)
				if actor.item!=null:food(actor.item.stage,Vector2(actor.x+2,actor.y-27))
			"player":
				person(actor,int(actor.character),Vector2(actor.input[0],actor.input[1]).length_squared()>.1)
				draw_arc(Vector2(actor.x,actor.y+1),10,0,TAU,20,palette.gold if thing.id==session.local_id() else Color("7db9da"),1)
				var held=actor.inventory[int(actor.slot)]
				if held!=null:food(held.stage,Vector2(actor.x+2,actor.y-27))
	var target=w.target(p)
	if not target.is_empty():
		var point=Vector2(target.x*32,target.y*32)
		draw_rect(Rect2(point-Vector2.ONE,Vector2(34,34)),Color("36a8ef") if colorblind else palette.gold,false,1)
		text(w.STATION_NAMES.get(target.kind,w.db.title("welfare",target.kind)),point+Vector2(-4,-5),10)
	if s.event!="":
		tile("bell",Vector2(263,139));text(s.event+" · 설비 앞 K",Vector2(225,134),11)
	if build_kind!="":
		var mouse=get_global_mouse_position()+camera
		var point=Vector2(floor(mouse.x/32)*32,floor(mouse.y/32)*32)
		furnishing(build_kind,point,s.id,build_rotation);draw_rect(Rect2(point,Vector2(32,32)),palette.mint,false,2)

func draw_parking(w,s: Dictionary,p: Dictionary) -> void:
	for y in range(14):
		for x in range(-1,20):tile("grass" if x<2 or x>15 else "paving",Vector2(x,y)*32)
	for x in range(2,16,4):tile("rear_facade",Vector2(x*32,16))
	for x in range(2,16):tile("fence",Vector2(x*32,320))
	furnishing("door",Vector2(112,80),s.id);text("주방으로 J",Vector2(94,78),11)
	tile("tree",Vector2(8,116));tile("tree",Vector2(516,124));tile("vending",Vector2(472,88))
	for i in range(int(s.parking)):
		var point=Vector2(256+i*80,224)
		tile("parking",point-Vector2(16,16))
		if i<s.vehicles.size():
			var car=s.vehicles[i];var def=w.db.get_def("vehicles",car.kind)
			car_sprite(def.sprite,point,0)
			text("J 하역" if car.cargo.size()>0 else "J 탑승",point+Vector2(-18,-31),10)
			text("%d / %d"%[car.cargo.size(),w.cargo_capacity(car)],point+Vector2(-14,40),10)
	for actor in w.state.players.values():
		if actor.store==s.id and actor.location=="parking":person(actor,int(actor.character),Vector2(actor.input[0],actor.input[1]).length_squared()>.1)
	text("뒷마당 · "+w.db.title("cities",s.id),Vector2(224,330),12)

func draw_road(w,s: Dictionary,p: Dictionary) -> void:
	var first=maxi(0,int(camera.x/32)-1);var last=mini(96,first+23)
	for y in range(13):
		for x in range(first,last):
			var kind="road" if y in [5,6,7] else ("paving" if y in [3,4,8,9] else "grass")
			if y==6:kind="road_dash"
			tile(kind,Vector2(x,y)*32)
	for block in range(19):
		var x=block*160
		if x<camera.x-160 or x>camera.x+680:continue
		var name="house_wood" if block%2==0 else "house_plaster"
		if block==0:name="restaurant_exterior"
		elif block==18:name="grocery_exterior"
		tile(name,Vector2(x,0));tile("tree",Vector2(x+120,47));tile("utility_pole",Vector2(x+120,277))
		furnishing("plant",Vector2(x+16,287),s.id)
	text("← 식당 주차장 · J",Vector2(58,145),12)
	text(w.db.title("cities",s.id)+" · 동네 거리",Vector2(camera.x+240,309),12)
	text("동네 마트 → · J",Vector2(2798,145),12)
	for car in s.vehicles:
		if car.driver!="":car_sprite(w.db.get_def("vehicles",car.kind).sprite,Vector2(car.x,car.y),int(car.face))
	var traffic_x=fmod(float(w.state.tick)*1.25,2880)+64
	car_sprite("car_1",Vector2(traffic_x,180),2)

func draw_retail(w,s: Dictionary,p: Dictionary) -> void:
	for y in range(13):
		for x in range(18):tile("wall" if y<2 or x in [0,17] else "kitchen",Vector2(x,y)*32)
	for x in [3,7,11]:tile("window",Vector2(x*32,34))
	text("동네 마트  /  오늘의 긴급 장보기",Vector2(115,87),14)
	for i in range(8):
		var point=Vector2(80+(i%4)*112,128+int(i/4)*80)
		tile("produce_shelf" if i%2==0 else "pantry_shelf",point-Vector2(8,8))
		var ingredient=w.db.all("ingredients")[i]
		tile("ingredient_"+ingredient.id,point+Vector2(4,-2));text(ingredient.name,point+Vector2(-6,45),10)
	tile("checkout",Vector2(456,144));person({"x":480,"y":140},8)
	text("도매 대비 3배 · 차량에 적재",Vector2(140,286),12)
	tile("noren",Vector2(257,312));text("출구 · J 차량으로",Vector2(225,345),12)
	person(p,int(p.character),Vector2(p.input[0],p.input[1]).length_squared()>.1)

func screen_to_tile(point: Vector2) -> Vector2i:return Vector2i((point+camera)/32)
