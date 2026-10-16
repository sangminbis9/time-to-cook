extends Node2D
# Authored 3/4 assets, nearest filtering, physical foot anchors, scene Y sorting.
var session
var textures: Dictionary={}
var art: Dictionary={}
var layouts: Dictionary={}
var font: Font=preload("res://assets/fonts/Galmuri11.ttf")
var camera=Vector2.ZERO
var elapsed=0.0
var interaction_until=0.0
var colorblind=false
var build_kind=""
var build_rotation=0
var restaurant
var palette={"ink":Color("453d3c"),"cream":Color("fff0cc"),"mint":Color("a8c4a1"),"gold":Color("efc270"),"red":Color("cc7766")}
const TERRAIN=["floor","floor_alt","floor_dark","kitchen","wall","wall_side","grass","paving","tatami","basalt","checker","birch","soil","road","road_dash","water"]

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	art=JSON.parse_string(FileAccess.get_file_as_string("res://rebuild/data/jp_art.json"))
	for asset in art.assets:textures[asset]=load("res://rebuild/assets/jp/%s.png"%asset)
	var cozy=JSON.parse_string(FileAccess.get_file_as_string("res://rebuild/data/cozy_art.json"))
	for asset in cozy.assets:
		textures[asset]=load("res://rebuild/assets/cozy/%s.png"%asset);art.assets[asset]=cozy.assets[asset]
	for city in cozy.cities:
		art.cities[city].props.merge(cozy.cities[city].props,true)
		art.cities[city].props.door="door"
		art.cities[city].props.bench="bench"
	layouts=JSON.parse_string(FileAccess.get_file_as_string("res://rebuild/data/restaurant_layouts.json"))
	restaurant=preload("res://rebuild/cozy_scene.gd").new();restaurant.host=self;add_child(restaurant)
	var overlay=Node2D.new();overlay.z_index=10;add_child(overlay);overlay.draw.connect(func():draw_context(overlay))
	set_meta("overlay",overlay)

func _process(delta: float) -> void:
	elapsed+=delta
	restaurant.visible=false
	if session!=null and session.connected and not session.world.state.is_empty():
		var w=session.world;var p=w.player(session.local_id())
		if not p.is_empty():
			var s=w.store_of(p)
			if p.location=="store":
				camera=Vector2((float(s.width)*32-800)/2,-28)
				restaurant.visible=true;restaurant.position=-camera;restaurant.update_world(w,s,p)
			elif p.location=="road":camera=Vector2(clampf(p.x-400,0,2240),-40)
			else:camera=Vector2(-112,-24)
	get_meta("overlay").queue_redraw();queue_redraw()

func regional(kind: String,city: String) -> String:
	return art.cities.get(city,{}).get("props",{}).get(kind,kind)

func tile(name: String,point: Vector2) -> void:
	if not textures.has(name):return
	if name in TERRAIN:
		var source=Vector2(posmod(int(point.x/32),2)*32,posmod(int(point.y/32),2)*32)
		draw_texture_rect_region(textures[name],Rect2(point.round(),Vector2(32,32)),Rect2(source,Vector2(32,32)))
	else:draw_texture(textures[name],point.round())

func furnishing(kind: String,point: Vector2,city: String,rotation: int=0) -> void:
	var name=regional("table_vertical" if kind=="table" and rotation%2==1 else kind,city)
	if textures.has(name):
		var anchor=art.assets[name].anchor;tile(name,point+Vector2(anchor[0],anchor[1]))

func food(stage: String,point: Vector2) -> void:
	var name="food_"+stage
	if textures.has(name):draw_texture_rect(textures[name],Rect2(point.round(),Vector2(20,20)),false)

func text(value: String,point: Vector2,size: int=10,color: Color=Color("453d3c")) -> void:
	draw_string(font,point.round()+Vector2(0,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("fff0cc"))
	draw_string(font,point.round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func person(actor: Dictionary,character: int,walking: bool=false) -> void:
	var point=Vector2(actor.x,actor.y)-Vector2(16,44)
	var frame=int(elapsed*7)%4 if walking else 1;var direction=int(actor.get("face",0))
	var tex=textures.get("person_%d"%(character%4))
	if tex:draw_texture_rect_region(tex,Rect2(point.round(),Vector2(32,48)),Rect2(frame*32,direction*48,32,48))

func car_sprite(name: String,point: Vector2,direction: int) -> void:
	if textures.has(name):
		var tex=textures[name];var size=Vector2(tex.get_width()/4,tex.get_height())
		draw_texture_rect_region(tex,Rect2((point-size/2).round(),size),Rect2(Vector2(direction*size.x,0),size))

func bar(point: Vector2,value: float,color: Color=Color("a8c4a1")) -> void:
	draw_rect(Rect2(point,Vector2(28,3)),palette.ink)
	draw_rect(Rect2(point+Vector2.ONE,Vector2(clampf(value,0,1)*26,1)),color)

func _draw() -> void:
	if session==null or session.world.state.is_empty() or not session.connected:return
	var w=session.world;var p=w.player(session.local_id())
	if p.is_empty():return
	var s=w.store_of(p)
	draw_set_transform(-camera)
	match p.location:
		"parking":draw_parking(w,s,p)
		"road":draw_road(w,s,p)
		"retail":draw_retail(w,s,p)
	draw_set_transform(Vector2.ZERO)

func draw_context(canvas: CanvasItem) -> void:
	if session==null or not session.connected or session.world.state.is_empty():return
	var w=session.world;var p=w.player(session.local_id())
	if p.is_empty() or p.location!="store":return
	var s=w.store_of(p)
	var target=w.target(p)
	if not target.is_empty():
		var point=Vector2(p.x,p.y)-camera+Vector2(-28,18)
		canvas.draw_string_outline(font,point,"J "+w.STATION_NAMES.get(target.kind,"사용"),HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,palette.ink)
		canvas.draw_string(font,point,"J "+w.STATION_NAMES.get(target.kind,"사용"),HORIZONTAL_ALIGNMENT_LEFT,-1,10,palette.cream)
		if p.working:canvas.draw_string(font,point+Vector2(0,12),"K · 작업 중",HORIZONTAL_ALIGNMENT_LEFT,-1,10,palette.gold)
	for obj in s.objects:
		if int(obj.floor)!=int(p.floor):continue
		if obj.item!=null and obj.kind=="fryer":
			var point=w.obj_pos(obj)-camera+Vector2(-14,18)
			canvas.draw_rect(Rect2(point,Vector2(28,3)),palette.ink)
			canvas.draw_rect(Rect2(point,Vector2(clampf(obj.item.heat/23,0,1)*28,2)),palette.gold)
	for c in s.customers:
		if int(c.floor)==int(p.floor) and c.state in ["waiting","ordered"]:
			var point=Vector2(c.x,c.y)-camera+Vector2(-6,-48)
			canvas.draw_string_outline(font,point,"J" if c.state=="waiting" else str(int(c.timer)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,palette.ink)
			canvas.draw_string(font,point,"J" if c.state=="waiting" else str(int(c.timer)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,palette.gold)
	for item_key in s.floor_items:
		var parts=item_key.split(":")
		if int(parts[0])==int(p.floor):
			var tex=textures.get("food_"+s.floor_items[item_key].stage)
			if tex:canvas.draw_texture(tex,Vector2(int(parts[1])*32+4,int(parts[2])*32+4)-camera)
	if build_kind!="":
		var cell=screen_to_tile(get_global_mouse_position());var name=regional("table_vertical" if build_kind=="table" and build_rotation%2 else build_kind,s.id)
		if textures.has(name):
			var anchor=art.assets[name].anchor;canvas.draw_texture(textures[name],Vector2(cell)*32-camera+Vector2(anchor[0],anchor[1]),Color(1,1,1,.65))

func draw_parking(w,s: Dictionary,p: Dictionary) -> void:
	for y in range(14):
		for x in range(-1,20):tile("grass" if x<2 or x>15 else "paving",Vector2(x,y)*32)
	tile("rear_facade",Vector2(64,16))
	if textures.has("garden"):tile("garden",Vector2(250,74));tile("bikes",Vector2(344,92));tile("citrus_tree",Vector2(360,8))
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
	var first=maxi(0,int(camera.x/32)-1);var last=mini(96,first+27)
	for y in range(13):
		for x in range(first,last):
			var kind="road" if y in [5,6,7] else ("paving" if y in [3,4,8,9] else "grass")
			if y==6:kind="road_dash"
			tile(kind,Vector2(x,y)*32)
	for block in range(19):
		var x=block*160
		if x<camera.x-160 or x>camera.x+820:continue
		var options=["house_cream","fishmonger","bakery","restaurant_exterior"]
		if w.db.get_def("cities",s.id).country=="jp":options=["kyoto_house","house_cream","bakery","kobe_house"]
		if s.id=="jeju":options=["jeju_house","fishmonger","jeju_house","bakery"]
		elif s.id=="kyoto":options=["kyoto_house","restaurant_exterior","house_cream","bakery"]
		elif s.id=="kobe":options=["kobe_house","house_cream","bakery","fishmonger"]
		var name=options[block%options.size()] if textures.has("house_cream") else "house_wood"
		if block==0:name="restaurant_exterior"
		elif block==18:name="grocery_exterior"
		if block%7==5 and textures.has("fountain"):tile("fountain",Vector2(x+24,72));tile("garden",Vector2(x+80,55))
		else:tile(name,Vector2(x,0))
		if block%3==1 and textures.has("garden"):tile("garden",Vector2(x+12,280));tile("bikes",Vector2(x+92,280))
		else:tile("cherry_tree" if block%3==2 and textures.has("cherry_tree") else "tree",Vector2(x+112,40))
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
	for x in [3,11]:tile("window",Vector2(x*32,8))
	if textures.has("grocery_sign"):tile("grocery_sign",Vector2(240,16))
	text("동네 마트 · B 장보기",Vector2(210,84),12)
	var fixtures=[]
	for i in range(8):
		var point=Vector2(80+(i%4)*112,128+int(i/4)*80)
		var kind=["grocery_meat","grocery_grain","grocery_boxes","grocery_sauce","grocery_produce","grocery_sauce","grocery_produce","grocery_produce"][i]
		fixtures.append({"y":point.y+32,"kind":kind,"point":point-Vector2(16,32),"ingredient":i})
	fixtures.append({"y":p.y,"kind":"person","point":Vector2.ZERO,"ingredient":-1})
	fixtures.sort_custom(func(a,b):return a.y<b.y)
	for fixture in fixtures:
		if fixture.kind=="person":person(p,int(p.character),Vector2(p.input[0],p.input[1]).length_squared()>.1);continue
		tile(fixture.kind,fixture.point)
		var i=int(fixture.ingredient);var point=fixture.point
		var ingredient=w.db.all("ingredients")[i]
		if i in [6,7]:tile("ingredient_"+ingredient.id,point+Vector2(20,16))
		text(ingredient.name,point+Vector2(15,72),10)
	person({"x":480,"y":176},1);tile("checkout",Vector2(456,144))
	text("도매 대비 3배 · 차량에 적재",Vector2(140,286),12)
	tile("noren",Vector2(257,312));text("출구 · J 차량으로",Vector2(225,345),12)

func screen_to_tile(point: Vector2) -> Vector2i:return Vector2i((point+camera)/32)
