extends RefCounted
var world_ref: WeakRef
var w:
	get:return world_ref.get_ref()

func _init(world) -> void:world_ref=weakref(world)

func tick_store(s: Dictionary,dt: float) -> void:
	for obj in s.objects:
		if obj.kind=="fryer" and obj.item!=null and s.event not in ["정전","튀김기 고장","화재"]:
			obj.item.heated=true;obj.item.heat+=dt;w.update_fried(obj.item)
	if w.state.phase=="business":
		s.spawn-=dt
		if s.spawn<=0:
			spawn_customer(s)
			var minute=540+float(w.state.tick)/20
			var peak=1.5 if minute>=720 and minute<840 else (1.65 if minute>=1080 and minute<1200 else (.65 if minute<720 else .8))
			var rep=clampf(1+.3*((.75*s.reputation+.25*w.state.brand-50)/50),.7,1.3)
			var econ=w.state.economies[s.id]
			var price_factor=1.0
			for recipe in s.menu:price_factor+=float(s.prices[recipe])/float(w.db.get_def("recipes",recipe).price)-1
			price_factor=maxf(.3,price_factor)
			var ad=1.0
			for entry in s.ads:ad+=float(entry.multiplier)
			s.spawn=w.rng.randf_range(19,29)*pow(price_factor,econ.sensitivity)/(peak*rep*econ.demand*minf(ad,1.8))
	for c in s.customers.duplicate():tick_customer(s,c,dt)
	for e in w.state.staff:
		if e.store==s.id and w.management.available(e):tick_employee(s,e,dt)
	s.event_cooldown-=dt
	if s.event_cooldown<=0:
		s.event_cooldown=150.0
		if s.event=="" and w.rng.randf()<.15:
			s.event=["화재","미끄러운 바닥","정전","누수","환기 고장","튀김기 고장","통로 막힘"][w.rng.randi_range(0,6)]
			var protection={"화재":"extinguisher","정전":"generator","누수":"drain","환기 고장":"vent"}.get(s.event,"")
			if protection!="" and s.objects.any(func(o):return o.kind==protection) and w.rng.randf()<.7:s.event=""
			if s.event!="":s.event_work=0;w.log_event(w.db.title("cities",s.id)+" · "+s.event+"! 정비 직원 또는 설비 앞 K로 대응하세요.")

func spawn_customer(s: Dictionary) -> void:
	if s.customers.size()>=18:return
	var takeout=w.rng.randf()<.35
	var recipe=s.menu[w.rng.randi_range(0,s.menu.size()-1)]
	var temperament=w.rng.randi_range(0,3)
	var patience=[1.2,.8,1.0,.9][temperament]
	var decor=s.objects.filter(func(o):return o.kind in ["plant","lamp"]).size()
	patience+=minf(.15,decor*.015+(.05 if "interior" in w.state.research else 0.0))
	var c={"id":w.uid("guest"),"type":"takeout" if takeout else "dine","state":"entering","recipe":recipe,"table":"","floor":0,"x":272.0,"y":352.0,"timer":40.0,"patience":patience,"temperament":temperament,"sprite":w.rng.randi_range(4,11),"price":0,"eat":w.rng.randf_range(20,50),"walk_timeout":0.0,"group":w.rng.randi_range(1,2),"order":""}
	s.customers.append(c)
	c.y=(int(s.get("height",13))-2)*32
	w.sound="bell"

func customer(s: Dictionary,id: String) -> Dictionary:
	for c in s.customers:
		if c.id==id:return c
	return {}

func tick_customer(s: Dictionary,c: Dictionary,dt: float) -> void:
	match c.state:
		"entering":
			if c.type=="takeout":c.state="counter_walk";c.timer=25*c.patience
			else:c.state="queue";c.timer=40*c.patience
		"queue":
			c.timer-=dt
			# Customers are iterated in arrival order, so assigning free tables is FIFO.
			for obj in s.objects:
				if obj.kind=="table" and obj.customer=="" and obj.dirty<=0:
					obj.customer=c.id;c.table=obj.id;c.floor=obj.floor;c.state="table_walk";c.walk_timeout=0.0
					if int(c.floor)>0:c.x=464.0;c.y=112.0
					break
			if c.state=="queue" and c.timer<=0:fail_customer(s,c,false)
		"table_walk":
			var table=w.object_by(s,c.table)
			if table.is_empty():c.state="queue";c.table="";return
			c.walk_timeout+=dt
			if w.walk_actor(s,c,w.seat_position(table),45,dt):c.state="waiting";c.timer=40*c.patience
			elif c.walk_timeout>25:fail_customer(s,c,false)
		"counter_walk":
			var counter=find_kind(s,"counter")
			if counter.is_empty():fail_customer(s,c,false);return
			c.walk_timeout+=dt
			if w.walk_actor(s,c,w.seat_position(counter),45,dt):c.state="waiting";c.timer=25*c.patience
			elif c.walk_timeout>25:fail_customer(s,c,false)
		"waiting":
			c.timer-=dt
			if c.type=="takeout" and s.objects.any(func(o):return o.kind=="kiosk"):accept(s,c)
			if c.timer<=0:fail_customer(s,c,false)
		"ordered":
			c.timer-=dt
			if c.timer<=0:fail_customer(s,c,true)
		"eating":
			c.eat-=dt
			if c.eat<=0:
				var table=w.object_by(s,c.table)
				if not table.is_empty():
					table.customer="";var roll=w.rng.randf();table.dirty=4.0 if roll<.45 else (8.0 if roll<.85 else 12.0)
				c.state="leaving";c.timer=20
		"leaving":
			c.timer-=dt
			if w.walk_actor(s,c,Vector2(272,(int(s.get("height",13))-2)*32),55,dt) or c.timer<=0:s.customers.erase(c)

func accept(s: Dictionary,c: Dictionary) -> bool:
	if c.state!="waiting":return false
	c.state="ordered";c.order=w.uid("order");c.timer=float(w.db.get_def("recipes",c.recipe).deadline);c.price=int(s.prices[c.recipe]);w.sound="bell";return true

func serve(s: Dictionary,c: Dictionary,food: Dictionary) -> bool:
	if c.state!="ordered" or food.stage!=c.recipe or food.recipe!=c.recipe or c.timer<=0:return false
	c.state="eating" if c.type=="dine" else "leaving"
	if c.type=="takeout":c.timer=20
	w.state.cash+=int(c.price);s.revenue+=int(c.price);s.served+=1;w.state.career_sales+=1;s.reputation=minf(100,s.reputation+.5);w.state.brand=minf(100,w.state.brand+.08);w.state.rp+=1;w.sound="coin"
	return true

func fail_customer(s: Dictionary,c: Dictionary,ordered: bool) -> void:
	if c.state in ["leaving","eating"]:return
	if ordered:s.failed+=1
	else:s.lost+=1
	s.reputation=maxf(0,s.reputation-(1.3 if ordered else .3));w.state.brand=maxf(0,w.state.brand-(.15 if ordered else .03))
	var table=w.object_by(s,c.table)
	if not table.is_empty():table.customer=""
	c.state="leaving";c.timer=20;w.sound="fail"

func service(s: Dictionary,p: Dictionary,obj: Dictionary) -> bool:
	var candidates=[]
	if obj.kind=="table":
		var c=customer(s,obj.customer)
		if not c.is_empty():candidates.append(c)
	else:
		for c in s.customers:
			if c.type=="takeout" and c.state in ["waiting","ordered"]:candidates.append(c)
	var food=w.held(p)
	for c in candidates:
		if food!=null and serve(s,c,food):p.inventory[int(p.slot)]=null;p.xp+=1;return true
	for c in candidates:
		if accept(s,c):
			c.timer+=int(p.skills.service)*2
			return true
	w.feedback="K: 청소" if obj.kind=="table" and obj.dirty>0 else "접수할 손님이나 맞는 완성 요리가 필요합니다."
	return false

func find_kind(s: Dictionary,kind: String,free: bool=false) -> Dictionary:
	for obj in s.objects:
		if obj.kind==kind and (not free or (obj.lock=="" and obj.item==null)):return obj
	return {}

func adjacent(s: Dictionary,obj: Dictionary) -> Vector2:
	for point in w.approach_points(obj):
		if not w.solid(s,point,int(obj.floor)):return point
	return w.obj_pos(obj)+Vector2(0,32)

func assign(e: Dictionary,obj: Dictionary,task: String,exclusive: bool=false) -> bool:
	if obj.is_empty():return false
	if exclusive and obj.lock!="" and obj.lock!=e.id:return false
	if exclusive:obj.lock=e.id
	e.target=obj.id;e.task=task;e.progress=0.0;e.state="이동";return true

func done(e: Dictionary,obj: Dictionary) -> void:
	if not obj.is_empty() and obj.lock==e.id:obj.lock=""
	e.target="";e.task="";e.progress=0.0;e.state="대기"

func tick_employee(s: Dictionary,e: Dictionary,dt: float) -> void:
	e.break_clock+=dt
	if e.job=="청소" and e.task=="clean" and int(w.state.tick)>=int(e.get("clean_review",0)):
		e.clean_review=int(w.state.tick)+60
		var current=w.object_by(s,e.target)
		var urgent_queue=s.customers.any(func(c):return c.state=="queue" and c.timer<15)
		if urgent_queue and not current.is_empty():
			for candidate in s.objects:
				if candidate.kind=="table" and candidate.dirty>0 and candidate.id!=e.target and not w.state.staff.any(func(other):return other.id!=e.id and other.task=="clean" and other.target==candidate.id):
					if cleaning_estimate(s,e,current)-cleaning_estimate(s,e,candidate)>=8:
						done(e,current);assign(e,candidate,"clean");break
	if e.target=="":select_task(s,e)
	if e.target=="":e.state="대기";return
	var obj=w.object_by(s,e.target)
	if obj.is_empty():done(e,{});return
	if int(e.floor)!=int(obj.floor):e.floor=obj.floor;e.x=464.0;e.y=112.0
	var speed=65.0*e.speed*(.8 if "느림" in e.traits else 1.0)
	if not w.walk_actor(s,e,adjacent(s,obj),speed,dt):
		e.progress+=dt
		if e.progress>20:done(e,obj)
		return
	if e.state=="이동":e.progress=0.0
	e.state="작업";e.workload+=dt
	var rate=float(e.speed)*(1.1 if "청소달인" in e.traits and e.task=="clean" else 1.0)
	if ("정확한 계산" in e.traits and e.job=="계산") or ("접객달인" in e.traits and e.job=="서빙"):rate*=1.15
	e.progress+=dt*rate
	match e.task:
		"welfare":
			var def=w.db.get_def("welfare",obj.kind)
			if e.progress>=3 and s.customers.any(func(c):return c.state=="ordered" and c.timer<15):
				obj.used_by="";e.break_clock=0;done(e,obj);return
			if e.progress>=float(def.duration):
				if w.pay(int(def.usage),"복리후생 이용비"):e.used.append(obj.kind);e.reasons[obj.kind]=float(def.effect)
				e.break_clock=0.0;obj.used_by="";done(e,obj)
		"repair":
			s.event_work+=dt*rate*(1.3 if "침착한 정비사" in e.traits else 1.0)
			if s.event_work>=8 or s.event=="":s.event="";s.event_work=0;done(e,obj)
		"maintain":
			if e.progress>5:s.event_cooldown+=20;done(e,obj);e.break_clock=0
		"manage":
			if e.progress>2:
				var accepted=s.customers.filter(func(c):return c.state in ["ordered","waiting"])
				var queue_priority=s.priority=="queue" or ("위기대응가" in e.traits and s.customers.filter(func(c):return c.state=="queue").size()>=3)
				accepted.sort_custom(func(a,b):return a.timer-(60 if a.state==("waiting" if queue_priority else "ordered") else 0)<b.timer-(60 if b.state==("waiting" if queue_priority else "ordered") else 0))
				s.dispatch_order=accepted.map(func(c):return c.id)
				done(e,obj);e.break_clock=0
		"clean":
			obj.dirty=maxf(0,obj.dirty-dt*rate)
			if obj.dirty<=0:done(e,obj)
		"accept":
			if e.progress>=.8:
				for c in s.customers:
					if c.state=="waiting" and ((e.job=="계산" and c.type=="takeout") or (e.job=="서빙" and c.table==obj.id)):accept(s,c);break
				done(e,obj)
		"pickup_dish":
			if obj.item!=null and obj.item.stage in s.menu:e.item=obj.item;obj.item=null
			done(e,obj)
		"serve":
			if e.item!=null:
				for c in s.customers:
					if (c.table==obj.id or (c.type=="takeout" and obj.kind=="counter")) and serve(s,c,e.item):e.item=null;break
			done(e,obj)
		"raw":
			if s.stock.chicken>0 and e.item==null:s.stock.chicken-=1;e.item=w.item()
			done(e,obj)
		"cut":
			if obj.item==null and e.item!=null:obj.item=e.item;e.item=null
			if obj.item==null:done(e,obj);return
			obj.item.progress+=dt*rate*(1.1 if "전처리달인" in e.traits else 1.0)
			if obj.item.progress>=4:obj.item.stage="cut";obj.item.progress=0;e.item=obj.item;obj.item=null;done(e,obj)
		"batter":
			if e.item==null:done(e,obj);return
			if e.progress>=1 and s.stock.flour>0:s.stock.flour-=1;e.item.stage="prepared";e.item.cost+=w.unit_price(s.id,"flour");done(e,obj)
		"deposit":
			if obj.item==null:obj.item=e.item;e.item=null
			done(e,obj)
		"pickup_prepared":
			if obj.item!=null and obj.item.stage=="prepared":e.item=obj.item;obj.item=null
			done(e,obj)
		"fry":
			if obj.item==null and e.item!=null:
				obj.item=e.item;e.item=null;obj.item.heated=true
				obj.item.safe_bonus=3 if "정밀한 튀김손" in e.traits else 0
			if obj.item==null:done(e,obj);return
			if obj.item.stage=="normal":e.item=obj.item;obj.item=null;done(e,obj)
			elif obj.item.stage in ["burnt","overcooked"]:w.management.discard(s,obj.item);obj.item=null;done(e,obj)
		"plate":
			if e.item==null:done(e,obj);return
			if s.stock.box<=0:return
			var recipe=w.db.get_def("recipes",e.recipe)
			if recipe.sauce!="" and int(s.stock[recipe.sauce])<=0:e.recipe="fried";recipe=w.db.get_def("recipes","fried")
			if e.progress>=1:
				s.stock.box-=1;e.item.cost+=w.unit_price(s.id,"box")
				if recipe.sauce!="":s.stock[recipe.sauce]-=1;e.item.cost+=w.unit_price(s.id,recipe.sauce)
				e.item.stage=recipe.id;e.item.recipe=recipe.id;obj.item=e.item;e.item=null;done(e,obj)

func select_task(s: Dictionary,e: Dictionary) -> void:
	# Urgent service precedes breaks; every job still has access to welfare visits.
	var urgent=s.customers.any(func(c):return c.state=="ordered" and c.timer<25)
	if e.break_clock>100 and not urgent and e.item==null:
		for obj in s.objects:
			var def=w.db.get_def("welfare",obj.kind)
			if not def.is_empty() and def.duration>0 and obj.kind not in e.used and obj.used_by=="":
				obj.used_by=e.id;assign(e,obj,"welfare");return
	match e.job:
		"청소":
			var candidates=s.objects.filter(func(o):return o.kind=="table" and o.dirty>0)
			candidates.sort_custom(func(a,b):return cleaning_estimate(s,e,a)<cleaning_estimate(s,e,b))
			for obj in candidates:
				if not w.state.staff.any(func(other):return other.id!=e.id and other.task=="clean" and other.target==obj.id):assign(e,obj,"clean");return
		"정비":
			if s.event!="":assign(e,find_kind(s,"fryer"),"repair")
			elif e.break_clock>50:assign(e,find_kind(s,"fryer"),"maintain")
		"매니저":
			if e.break_clock>12:assign(e,find_kind(s,"counter"),"manage")
		"서빙", "계산":
			var mode="dine" if e.job=="서빙" else "takeout"
			var service_customers=s.customers.duplicate()
			if s.has("dispatch_order"):
				service_customers.sort_custom(func(a,b):return dispatch_rank(s,a.id)<dispatch_rank(s,b.id))
			for c in service_customers:
				if c.type!=mode:continue
				var destination=w.object_by(s,c.table) if mode=="dine" else find_kind(s,"counter")
				if c.state=="ordered" and e.item!=null and e.item.recipe==c.recipe:assign(e,destination,"serve");return
				if c.state=="waiting" and e.item==null:assign(e,destination,"accept");return
				if c.state=="ordered" and e.item==null:
					for obj in s.objects:
						if obj.item!=null and obj.item.stage==c.recipe and obj.lock=="":assign(e,obj,"pickup_dish",true);return
			if e.item!=null:
				var bench=find_kind(s,"bench",true)
				if not bench.is_empty():assign(e,bench,"deposit",true)
		"전처리":
			if e.item==null:
				var prepared=0
				for obj in s.objects:
					if obj.item!=null:prepared+=1
				if prepared<4 and s.stock.chicken>0 and s.stock.flour>0:assign(e,find_kind(s,"stock"),"raw")
			elif e.item.stage=="raw":assign(e,find_kind(s,"board",true),"cut",true)
			elif e.item.stage=="cut":assign(e,find_kind(s,"batter",true),"batter",true)
			elif e.item.stage=="prepared":
				var bench=find_kind(s,"bench",true)
				if bench.is_empty():bench=find_kind(s,"batter",true)
				assign(e,bench,"deposit",true)
		"조리":
			if e.item==null:
				for obj in s.objects:
					if obj.item!=null and obj.item.stage=="prepared" and obj.lock=="":assign(e,obj,"pickup_prepared",true);return
			elif e.item.stage=="prepared":
				e.recipe="fried"
				for c in s.customers:
					if c.state=="ordered":e.recipe=c.recipe;break
				assign(e,find_kind(s,"fryer",true),"fry",true)
			elif e.item.stage=="normal":assign(e,find_kind(s,"plate",true),"plate",true)
			else:assign(e,find_kind(s,"bench",true),"deposit",true)

func cleaning_estimate(s: Dictionary,e: Dictionary,obj: Dictionary) -> float:
	var contribution=float(e.speed)
	for p in w.state.players.values():
		if p.store==s.id and p.location=="store" and p.working:
			var selected=w.target(p)
			if not selected.is_empty() and selected.id==obj.id:contribution+=1+.08*int(p.skills.clean)
	return w.pos(e).distance_to(w.obj_pos(obj))/(65*float(e.speed))+float(obj.dirty)/contribution

func dispatch_rank(s: Dictionary,id: String) -> int:
	var index=s.dispatch_order.find(id)
	return index if index>=0 else 999
