extends RefCounted

const Catalog = preload("res://rebuild/catalog.gd")
const Management = preload("res://rebuild/management.gd")
const Simulation = preload("res://rebuild/simulation.gd")
var db = Catalog.new()
var state: Dictionary = {}
var rng = RandomNumberGenerator.new()
var management
var simulation
var feedback: String = ""
var sound: String = ""
const JOBS = ["전처리", "조리", "서빙", "계산", "청소", "정비", "매니저"]
const STATION_NAMES = {"stock":"재료함", "board":"도마", "batter":"튀김옷", "fryer":"튀김기", "plate":"담기 / 양념", "counter":"포장 계산대", "fridge":"냉장고", "table":"식탁", "bench":"작업대", "door":"뒷문", "stairs":"계단", "kiosk":"키오스크", "plant":"화분", "extinguisher":"소화기", "generator":"발전기", "vent":"환기", "drain":"배수", "wall_block":"벽", "lamp":"조명", "chair":"의자", "parking":"주차 확장", "elevator":"엘리베이터"}

func _init() -> void:
	management = Management.new(self)
	simulation = Simulation.new(self)

func uid(prefix: String) -> String:
	state.serial += 1
	return "%s_%d" % [prefix, state.serial]

func new_game(character: int = 0, seed_value: int = 821) -> void:
	rng.seed = seed_value
	state = {"version":2, "serial":0, "seed":seed_value, "rng":"", "day":1, "tick":0, "phase":"prep", "cash":90000, "brand":60.0, "rp":0, "credit":100, "research":[], "loans":[], "stores":{}, "players":{}, "staff":[], "candidates":{}, "refreshes":{}, "markets":{}, "economies":{}, "closed":{}, "logs":[], "transactions":{}, "ledger":{}, "summary":{}, "ready":{}, "tutorial":0, "career_sales":0, "guest_character":-1, "guest_token":"", "achievements":[]}
	for city in db.all("cities"):
		state.economies[city.id] = {"price":city.price, "demand":city.demand, "event":"평온한 날", "competition":city.competition, "sensitivity":city.sensitivity, "spending":city.spending}
	state.stores.incheon = make_store("incheon")
	state.players["1"] = make_player(character)
	state.markets.incheon = {"day":1, "grade":3, "paid":0, "source":"무료 창업 보고서", "data":state.economies.incheon.duplicate(true)}
	management.refresh_candidates()
	log_event("인천에 첫 매장을 열었습니다. 재료 발주 후 영업을 시작하세요.")

func make_player(character: int) -> Dictionary:
	var inventory: Array = []
	inventory.resize(4 if character == 2 else 3)
	inventory.fill(null)
	return {"character":character, "store":state.stores.keys()[0] if not state.stores.is_empty() else "incheon", "floor":0, "location":"store", "x":288.0, "y":224.0, "face":0, "inventory":inventory, "slot":0, "vehicle":"", "skill_until":0, "cooldown":0, "skills":{"prep":0,"cook":0,"service":0,"move":0,"clean":0,"market":0}, "input":[0.0,0.0], "working":false, "fridge":"", "xp":0, "recipe":"fried"}

func make_store(city: String) -> Dictionary:
	var s = {"id":city,"reputation":65.0,"stock":{},"retail":{},"objects":[],"floor_items":{},"customers":[],"vehicles":[],"floors":1,"parking":1,"spawn":12.0,"event":"","event_work":0.0,"event_cooldown":150.0,"prices":{},"menu":["fried"],"ads":[],"auto_order":0,"served":0,"failed":0,"lost":0,"revenue":0,"waste":0,"waste_cost":0,"floor_style":"floor","priority":"deadline"}
	for ing in db.all("ingredients"):
		s.stock[ing.id] = 0
		s.retail[ing.id] = 30
	for recipe in db.all("recipes"):
		s.prices[recipe.id] = int(recipe.price)
	var layouts=JSON.parse_string(FileAccess.get_file_as_string("res://rebuild/data/restaurant_layouts.json"))
	var layout=layouts[city]
	s.width=layout.width;s.height=layout.height;s.style=layout.style;s.layout_version=3
	for spec in layout.objects:
		var obj=make_object(spec[0],spec[1],spec[2],0)
		if spec.size()>3:obj.footprint=spec[3]
		if spec.size()>4:obj.art=spec[4].replace("{city}",city)
		s.objects.append(obj)
	return s

func make_object(kind: String, x: int, y: int, floor_id: int) -> Dictionary:
	return {"id":uid("obj"),"kind":kind,"x":x,"y":y,"floor":floor_id,"rotation":0,"footprint":[2,1] if kind in ["table","counter","stock","bench"] else [1,1],"item":null,"lock":"","progress":0.0,"dirty":0.0,"customer":"","slots":[null,null,null],"open_by":"","used_by":""}

func item(stage: String = "raw") -> Dictionary:
	return {"id":uid("food"),"stage":stage,"progress":0.0,"heat":0.0,"heated":false,"recipe":"fried","cost":unit_price("incheon","chicken")}

func unit_price(city: String, ingredient: String, retail: bool = false) -> int:
	var factor = 3.0 if retail else (0.95 if "supply" in state.research else 1.0)
	if not retail and "logistics" in state.research:factor*=.95
	# Retail always refers to today's wholesale unit price.
	if retail:
		return int(ceil(unit_price(city, ingredient) * 3.0))
	return int(ceil(db.get_def("ingredients",ingredient).cost * state.economies[city].price * factor))

func log_event(message: String) -> void:
	state.logs.push_front("%d일 · %s" % [state.day,message])
	if state.logs.size() > 80: state.logs.resize(80)
	feedback = message

func pay(amount: int, category: String) -> bool:
	if amount < 0 or state.cash < amount:
		feedback = "공용 자금이 부족합니다."
		return false
	state.cash -= amount
	state.ledger[category] = int(state.ledger.get(category,0)) + amount
	return true

func player(peer: String) -> Dictionary:
	return state.players.get(peer,{})

func store_of(p: Dictionary) -> Dictionary:
	return state.stores[p.store]

func object_by(s: Dictionary, id: String) -> Dictionary:
	for obj in s.objects:
		if obj.id == id: return obj
	return {}

func pos(a: Dictionary) -> Vector2:
	return Vector2(a.x,a.y)

func obj_pos(a: Dictionary) -> Vector2:
	return object_rect(a).get_center()

func object_size(a: Dictionary) -> Vector2:
	var size=a.get("footprint",[1,1])
	return Vector2(size[1],size[0]) if a.kind=="table" and int(a.get("rotation",0))%2==1 else Vector2(size[0],size[1])

func object_rect(a: Dictionary) -> Rect2:
	return Rect2(Vector2(a.x,a.y)*32,object_size(a)*32)

func approach_points(a: Dictionary) -> Array:
	var rect=object_rect(a);var points=[]
	for x in range(int(a.x),int(a.x+object_size(a).x)):
		points.append(Vector2(x*32+16,rect.end.y+16))
		points.append(Vector2(x*32+16,rect.position.y-16))
	for y in range(int(a.y),int(a.y+object_size(a).y)):
		points.append(Vector2(rect.position.x-16,y*32+16));points.append(Vector2(rect.end.x+16,y*32+16))
	return points

func seat_position(a: Dictionary) -> Vector2:
	var rect=object_rect(a)
	return Vector2(rect.position.x+16,rect.end.y+16)

func facing(p: Dictionary) -> Vector2:
	return [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][int(p.face)]

func target(p: Dictionary) -> Dictionary:
	if p.location != "store": return {}
	var best = {}
	var score = 999.0
	for obj in store_of(p).objects:
		if int(obj.floor) != int(p.floor): continue
		var delta = obj_pos(obj)-pos(p)
		var distance = delta.length()
		if distance > 52+maxf(0,object_size(obj).x-1)*12: continue
		var value = distance - 22.0 * facing(p).dot(delta.normalized())
		if value < score:
			score = value
			best = obj
	return best

func empty_slot(p: Dictionary) -> int:
	if p.inventory[int(p.slot)] == null: return int(p.slot)
	return p.inventory.find(null)

func held(p: Dictionary):
	return p.inventory[int(p.slot)]

func give(p: Dictionary, food: Dictionary) -> bool:
	var slot = empty_slot(p)
	if slot < 0:
		feedback = "인벤토리가 가득 찼습니다."
		return false
	p.inventory[slot] = food
	return true

func solid(s: Dictionary, point: Vector2, floor_id: int) -> bool:
	if point.x < 40 or point.x > (int(s.get("width",18))-1)*32-8 or point.y < 43 or point.y > (int(s.get("height",13))-1)*32-20: return true
	for obj in s.objects:
		if int(obj.floor)!=floor_id or obj.kind in ["door","stairs","lamp","parking"]:continue
		if object_rect(obj).grow_individual(3,-2,3,-2).has_point(point):return true
	return false

func route(s: Dictionary, from: Vector2, destination: Vector2, floor_id: int = 0) -> Array:
	var start = Vector2i(from/32)
	var goal = Vector2i(destination/32)
	var frontier = [start]
	var came = {start:start}
	while not frontier.is_empty():
		var cell = frontier.pop_front()
		if cell == goal:break
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next = cell+delta
			if next.x<1 or next.x>int(s.get("width",18))-2 or next.y<1 or next.y>int(s.get("height",13))-2 or came.has(next):continue
			if solid(s,Vector2(next)*32+Vector2(16,16),floor_id) and next!=goal:continue
			came[next]=cell
			frontier.append(next)
	if not came.has(goal):return []
	var result: Array = [destination]
	var cursor = goal
	while cursor!=start:
		cursor=came[cursor]
		result.push_front(Vector2(cursor)*32+Vector2(16,16))
	return result

func walk_actor(s: Dictionary, actor: Dictionary, destination: Vector2, speed: float, dt: float) -> bool:
	if pos(actor).distance_to(destination)<3:return true
	var path = route(s,pos(actor),destination,int(actor.get("floor",0)))
	if path.is_empty():return false
	var next = path[1] if path.size()>1 else destination
	var v = pos(actor).move_toward(next,speed*dt)
	var direction=v-pos(actor)
	actor.face=(2 if direction.x>0 else 1) if abs(direction.x)>abs(direction.y) else (0 if direction.y>0 else 3)
	actor.x=v.x;actor.y=v.y
	return v.distance_to(destination)<3

func command(peer: String, sequence: int, action: String, args: Dictionary = {}) -> bool:
	feedback="";sound=""
	if state.is_empty() or not state.players.has(peer):return false
	var last=int(state.transactions.get(peer,0))
	if sequence<=last:return false
	state.transactions[peer]=sequence
	var p=player(peer)
	match action:
		"input":
			p.input=[clampf(float(args.get("x",0)),-1,1),clampf(float(args.get("y",0)),-1,1)]
			p.working=bool(args.get("work",false))
			return true
		"slot":
			p.slot=clampi(int(args.get("slot",0)),0,p.inventory.size()-1)
			return true
		"interact":return interact(peer)
		"drop":return drop(p)
		"fridge":return fridge_transfer(peer,int(args.get("slot",0)),bool(args.get("fast",false)))
		"close_fridge":
			release_locks(peer)
			return true
		"ready":
			if state.phase!="prep":return false
			state.ready[peer]=not state.ready.get(peer,false)
			for id in state.players:
				if not state.ready.get(id,false):return true
			start_day()
			return true
		"next_day":
			if state.phase!="settlement" or peer!="1":return false
			management.next_day()
			return true
		"skill":
			if state.tick<int(p.cooldown) or state.phase not in ["business","closing"]:return false
			p.cooldown=int(state.tick)+1200;p.skill_until=int(state.tick)+200
			if int(p.character)==3:management.market_scan(p.store,1,"능력 조사",0)
			sound="skill";return true
		_:return management.command(peer,action,args)

func release_locks(peer: String) -> void:
	for s in state.stores.values():
		for obj in s.objects:
			if obj.open_by==peer:obj.open_by=""
	if state.players.has(peer):state.players[peer].fridge=""

func start_day() -> void:
	state.phase="business";state.tick=0;state.ready={}
	management.attendance()
	log_event("09:00 영업 시작! 주문을 접수하고 요리를 준비하세요.")

func step(dt: float = .05) -> void:
	if state.is_empty():return
	if state.phase in ["business","closing"]:
		state.tick+=1
		if int(state.tick)==14400:
			state.phase="closing";log_event("21:00 신규 주문 종료 · 외출 중이라면 돌아오세요.")
		if int(state.tick)==15000:log_event("21:30 마감까지 30분! 차량 화물을 하역하세요.")
		if int(state.tick)>=15600:
			management.settle()
			return
	for peer in state.players:
		var p=state.players[peer]
		move_player(p,dt)
		if p.fridge!="":
			var fridge=object_by(store_of(p),p.fridge)
			if fridge.is_empty() or p.location!="store" or pos(p).distance_to(obj_pos(fridge))>64:release_locks(peer)
		if p.working and p.location=="store":work(p,dt)
	if state.phase in ["business","closing"]:
		for s in state.stores.values():
			var occupied=state.players.values().any(func(p):return p.store==s.id and p.location=="store")
			s.batch_time=float(s.get("batch_time",0))+dt
			var interval=.05 if occupied else .5
			if s.batch_time>=interval-.00001:
				var elapsed=float(s.batch_time);s.batch_time=0.0
				simulation.tick_store(s,elapsed)

func move_player(p: Dictionary, dt: float) -> void:
	if state.phase=="settlement":return
	var input=Vector2(p.input[0],p.input[1]).limit_length()
	if input.length_squared()<.01:
		if p.location=="road" and p.vehicle!="":
			var stopped_car=vehicle(store_of(p),p.vehicle)
			if not stopped_car.is_empty():stopped_car.velocity=move_toward(float(stopped_car.velocity),0,288*dt)
		return
	p.face=(2 if input.x>0 else 1) if abs(input.x)>abs(input.y) else (0 if input.y>0 else 3)
	if p.location=="road" and p.vehicle!="":
		var car=vehicle(store_of(p),p.vehicle)
		if car.is_empty():return
		var definition=db.get_def("vehicles",car.kind)
		var speed=definition.speed*32
		speed*=1+.05*int(car.get("upgrade",0))
		var traffic=Vector2(fmod(float(state.tick)*1.25,2880)+64,180)
		if pos(car).distance_to(traffic)<27:speed*=.35
		if "폭설" in state.economies[p.store].event or "태풍" in state.economies[p.store].event:speed*=.65
		car.velocity=move_toward(float(car.velocity),speed,float(definition.accel)*32*dt)
		var next=pos(car)+input*car.velocity*dt
		# A continuous 90-tile road, with sidewalks and gentle traffic slow zones.
		next.x=clampf(next.x,64,2944);next.y=clampf(next.y,164,248)
		car.x=next.x;car.y=next.y;car.face=p.face;p.x=next.x;p.y=next.y
	else:
		var speed=90.0*(1+.05*int(p.skills.move))
		if p.location=="store" and store_of(p).event in ["미끄러운 바닥","누수"]:speed*=.75
		if int(p.character)==2:speed*=1.1
		if int(p.skill_until)>int(state.tick) and int(p.character)==2:speed*=1.5
		var next=pos(p)+input*speed*dt
		if p.location=="store":
			var s=store_of(p)
			if not solid(s,Vector2(next.x,p.y),int(p.floor)):p.x=next.x
			if not solid(s,Vector2(p.x,next.y),int(p.floor)):p.y=next.y
		else:
			p.x=clampf(next.x,40,536);p.y=clampf(next.y,80,352)

func vehicle(s: Dictionary,id: String) -> Dictionary:
	for car in s.vehicles:
		if car.id==id:return car
	return {}

func interact(peer: String) -> bool:
	var p=player(peer)
	var s=store_of(p)
	if p.location!="store":return outdoor_interact(peer)
	var key="%d:%d:%d" % [p.floor,int(p.x/32),int(p.y/32)]
	var front=pos(p)+facing(p)*24
	var front_key="%d:%d:%d" % [p.floor,int(front.x/32),int(front.y/32)]
	for candidate in [front_key,key]:
		if s.floor_items.has(candidate) and give(p,s.floor_items[candidate]):
			s.floor_items.erase(candidate);sound="click";return true
	var obj=target(p)
	if obj.is_empty():return false
	if obj.lock!="":feedback="직원이 작업 중입니다.";return false
	var food=held(p)
	match obj.kind:
		"door":
			if state.phase!="business":feedback="외출은 09:00~21:00에 가능합니다.";return false
			release_locks(peer);p.location="parking";p.x=128.0;p.y=256.0;sound="door";return true
		"stairs", "elevator":
			p.floor=(int(p.floor)+1)%int(s.floors);p.x=464.0;p.y=112.0;return true
		"stock":
			if int(s.stock.chicken)<=0:feedback="생닭 품절 · 준비 중 발주 / 영업 중 차량 장보기";return false
			if give(p,item()):s.stock.chicken-=1;sound="click";return true
		"fridge":
			if obj.open_by!="" and obj.open_by!=peer:feedback="다른 요리사가 냉장고를 사용 중입니다.";return false
			obj.open_by=peer;p.fridge=obj.id;sound="door";return true
		"table", "counter", "kiosk":return simulation.service(s,p,obj)
		"extinguisher", "generator", "vent", "drain":
			if s.event!="":s.event_work+=5;feedback="대응 작업 중 · K로 계속 정비";return true
		"plant", "lamp", "chair", "wall_block":return false
		_:
			if not db.get_def("welfare",obj.kind).is_empty():return false
			if food!=null and not accepts(obj.kind,food):feedback="이 단계의 음식은 이 설비에 놓을 수 없습니다.";return false
			if obj.kind=="fryer" and obj.item!=null:
				update_fried(obj.item)
			var stored=obj.item
			if food==null and stored!=null:
				if give(p,stored):obj.item=null;sound="click";return true
			else:
				obj.item=food;p.inventory[int(p.slot)]=stored
				if obj.kind=="fryer" and food!=null:
					food.heated=true
					food.safe_bonus=int(p.skills.cook)+(2 if int(p.character)==1 else 0)+(3 if int(p.character)==1 and int(p.skill_until)>int(state.tick) else 0)
				sound="click";return true
	return false

func accepts(kind: String, food: Dictionary) -> bool:
	match kind:
		"board":return food.stage in ["raw","cut"]
		"batter":return food.stage in ["cut","prepared"]
		"fryer":return food.stage in ["prepared","undercooked"]
		"plate":return food.stage in ["normal","fried","sweet","spicy","soy","garlic","teriyaki","jeju"]
		"bench":return true
	return false

func update_fried(food: Dictionary) -> void:
	var safe=(19 if "equipment" in state.research else 15)+int(food.get("safe_bonus",0))
	safe=mini(22,safe)
	food.stage="burnt" if food.heat>=23 else ("overcooked" if food.heat>=safe else ("normal" if food.heat>=8 else "undercooked"))

func work(p: Dictionary, dt: float) -> void:
	var obj=target(p)
	if obj.is_empty():return
	var s=store_of(p)
	var active=1.5 if int(p.skill_until)>int(state.tick) else 1.0
	if obj.kind=="table" and float(obj.dirty)>0:
		obj.dirty=maxf(0,float(obj.dirty)-dt*(1+.08*int(p.skills.clean))*active)
		sound="clean"
		return
	if obj.kind in ["extinguisher","generator","vent","drain","fryer"] and s.event!="":
		s.event_work+=dt*active
		if s.event_work>=8:s.event="";s.event_work=0;log_event("매장 설비를 복구했습니다.")
		return
	if obj.lock!="" or obj.item==null:return
	var food=obj.item
	if obj.kind=="board" and food.stage=="raw":
		food.progress+=dt*active*(1+.1*int(p.skills.prep))*(1.15 if int(p.character)==0 else 1.0)
		if food.progress>=4:food.stage="cut";food.progress=0;sound="cut"
	elif obj.kind=="batter" and food.stage=="cut":
		if int(s.stock.flour)<=0:feedback="튀김옷 재고가 없습니다.";return
		s.stock.flour-=1;food.cost+=unit_price(s.id,"flour");food.stage="prepared";sound="cut"
	elif obj.kind=="plate" and food.stage=="normal":
		var recipe=db.get_def("recipes",p.recipe)
		if int(s.stock.box)<=0:feedback="용기 재고가 없습니다.";return
		if recipe.sauce!="" and int(s.stock[recipe.sauce])<=0:feedback="양념 재고가 없습니다.";return
		s.stock.box-=1;food.cost+=unit_price(s.id,"box")
		if recipe.sauce!="":s.stock[recipe.sauce]-=1;food.cost+=unit_price(s.id,recipe.sauce)
		food.stage=p.recipe;food.recipe=p.recipe;sound="bell"

func fridge_transfer(peer: String,index: int,fast: bool=false) -> bool:
	var p=player(peer)
	var obj=object_by(store_of(p),p.fridge)
	if obj.is_empty() or obj.open_by!=peer or index<0 or index>=obj.slots.size() or pos(p).distance_to(obj_pos(obj))>64:return false
	var inventory_slot=int(p.slot)
	if fast and obj.slots[index]!=null:
		inventory_slot=p.inventory.find(null)
		if inventory_slot<0:feedback="빈 가방 칸이 없습니다.";return false
	var food=p.inventory[inventory_slot]
	if food!=null and (food.heated or food.stage not in ["raw","cut","prepared"]):feedback="가열 전 재료만 보관할 수 있습니다.";return false
	var old=obj.slots[index]
	obj.slots[index]=food;p.inventory[inventory_slot]=old;sound="click"
	return true

func drop(p: Dictionary) -> bool:
	if p.location!="store" or held(p)==null:return false
	var s=store_of(p)
	var tiles=[Vector2i((pos(p)+facing(p)*32)/32),Vector2i(pos(p)/32)]
	for y in range(-1,2):
		for x in range(-1,2):tiles.append(Vector2i(pos(p)/32)+Vector2i(x,y))
	for tile in tiles:
		var key="%d:%d:%d" % [p.floor,tile.x,tile.y]
		if not s.floor_items.has(key) and not solid(s,Vector2(tile)*32+Vector2(16,16),p.floor):
			s.floor_items[key]=held(p);p.inventory[int(p.slot)]=null;return true
	return false

func cargo_capacity(car: Dictionary) -> int:
	return int(db.get_def("vehicles",car.kind).capacity)+2*int(car.get("upgrade",0))

func outdoor_interact(peer: String) -> bool:
	var p=player(peer)
	var s=store_of(p)
	match p.location:
		"parking":
			if pos(p).distance_to(Vector2(128,112))<60:
				p.location="store";p.x=496.0;p.y=96.0;return true
			for i in range(s.vehicles.size()):
				var car=s.vehicles[i]
				if pos(p).distance_to(Vector2(256+i*80,224))>60:continue
				if car.driver!="" and car.driver!=peer:feedback="다른 요리사가 운전 중입니다.";return false
				if car.cargo.size()>0:
					for cargo in car.cargo:s.stock[cargo.ingredient]+=1
					car.cargo.clear();log_event("차량 화물을 매장 재고에 하역했습니다.");return true
				if state.phase!="business":feedback="21시 이후 신규 출발은 불가합니다.";return false
				if not pay(int(db.get_def("vehicles",car.kind).trip),"차량 운행비"):return false
				car.driver=peer;car.x=80.0;car.y=208.0;car.velocity=0.0;p.vehicle=car.id;p.location="road";p.x=car.x;p.y=car.y;sound="engine";return true
			feedback="뒷문은 위쪽 · 보유 차량에 다가가 J"
		"road":
			var car=vehicle(s,p.vehicle)
			if car.is_empty():return false
			if car.x>2860:
				p.location="retail";p.x=288.0;p.y=304.0;car.velocity=0.0;sound="door";return true
			if car.x<145:
				car.driver="";car.velocity=0.0;p.location="parking";p.x=256.0+s.vehicles.find(car)*80;p.y=272.0;p.vehicle="";sound="door";return true
			feedback="마트 또는 식당 주차 구역에서 J로 하차하세요."
		"retail":
			if p.y>280:
				var car=vehicle(s,p.vehicle)
				p.location="road";p.x=car.x;p.y=car.y;return true
			feedback="상품 진열대 근처에서 장보기 패널로 수량을 선택하세요."
	return false

