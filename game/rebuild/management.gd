extends RefCounted
var world_ref: WeakRef
var w:
	get:return world_ref.get_ref()

func _init(world) -> void:world_ref=weakref(world)

func command(peer: String, action: String, a: Dictionary) -> bool:
	var st=w.state
	var p=w.player(peer)
	var s=w.store_of(p)
	if action=="retail_buy":return retail_buy(p,a)
	if action=="visit":
		var destination=str(a.get("city",""))
		if not st.stores.has(destination) or p.location!="store":return false
		w.release_locks(peer);p.store=destination;p.floor=0;p.x=288.0;p.y=224.0;return true
	if action=="recipe_select":
		if str(a.get("recipe","")) not in s.menu:return false
		p.recipe=a.recipe;return true
	if st.phase!="prep":w.feedback="준비 단계에서 변경할 수 있습니다.";return false
	match action:
		"buy_stock":
			var ingredient=str(a.get("ingredient",""))
			var qty=clampi(int(a.get("qty",10)),1,999)
			if w.db.get_def("ingredients",ingredient).is_empty():return false
			if not w.pay(w.unit_price(s.id,ingredient)*qty,"도매 발주"):return false
			s.stock[ingredient]+=qty;w.sound="coin";return true
		"hire":return hire(s,str(a.get("job","")))
		"refresh":
			var job=str(a.get("job",""))
			if job not in w.JOBS:return false
			var count=int(st.refreshes.get(job,0))
			if count>40:w.feedback="자금 부족";return false
			var cost=2000*(1<<count)
			if not w.pay(cost,"재모집"):return false
			st.refreshes[job]=count+1;st.candidates[job]=candidate(job);return true
		"fire":
			var e=employee(str(a.get("id","")))
			if e.is_empty():return false
			var remaining=maxi(0,int(e.contract)-(int(st.day)-int(e.hired)))
			if not w.pay(roundi(remaining*e.wage*.5),"해고 위약금"):return false
			release_employee(e);st.staff.erase(e);return true
		"bonus":
			var e=employee(str(a.get("id","")))
			var tier=clampi(int(a.get("tier",1)),0,2)
			if e.is_empty() or st.day-int(e.last_bonus)<7:w.feedback="포상은 직원별 7일에 한 번 가능합니다.";return false
			if not w.pay(roundi(e.wage*[.5,1.0,2.0][tier]),"직원 포상"):return false
			e.last_bonus=st.day;e.reasons["포상"]=tier+1;return true
		"vacation":
			var e=employee(str(a.get("id","")))
			var old=int(a.get("from",0));var next=int(a.get("to",0));var today=(int(st.day)-1)%30+1
			if e.is_empty() or old not in e.leave or next in e.leave or next<today or next>30 or old<today:return false
			if not w.pay(int(e.wage),"휴가 변경"):return false
			e.leave.erase(old);e.leave.append(next);e.leave.sort();return true
		"transfer":
			var e=employee(str(a.get("id","")));var city=str(a.get("city",""))
			if e.is_empty() or not st.stores.has(city) or city==e.store:return false
			var cost=500 if w.db.get_def("cities",city).country==w.db.get_def("cities",e.store).country else 2500
			if not w.pay(cost,"직원 이동"):return false
			release_employee(e);e.store=city;e.x=288.0;e.y=176.0;e.floor=0;return true
		"vehicle_buy":
			var def=w.db.get_def("vehicles",str(a.get("id","")))
			if def.is_empty() or s.vehicles.size()>=int(s.parking):w.feedback="주차 공간이 부족합니다.";return false
			if not w.pay(int(def.price),"차량 구입"):return false
			s.vehicles.append({"id":w.uid("car"),"kind":def.id,"store":s.id,"driver":"","x":80.0,"y":208.0,"face":2,"velocity":0.0,"cargo":[]})
			w.log_event("%s 구입 · 뒷문을 통해 긴급 장보기를 할 수 있습니다."%def.name);return true
		"vehicle_sell":
			var car=w.vehicle(s,str(a.get("id","")))
			if car.is_empty() or car.driver!="":return false
			var proceeds=int(w.db.get_def("vehicles",car.kind).price*.6)
			st.cash+=proceeds;st.ledger["차량 매각"]=int(st.ledger.get("차량 매각",0))-proceeds;s.vehicles.erase(car);return true
		"vehicle_upgrade":
			var car=w.vehicle(s,str(a.get("id","")))
			if car.is_empty() or int(car.get("upgrade",0))>=3:return false
			var cost=roundi(w.db.get_def("vehicles",car.kind).price*.15*(1+int(car.get("upgrade",0))))
			if not w.pay(cost,"차량 개선"):return false
			car.upgrade=int(car.get("upgrade",0))+1;return true
		"insurance":
			if int(s.get("insured_day",0))==int(st.day):return false
			if not w.pay(1200,"영업일 보험"):return false
			s.insured_day=st.day;return true
		"research":
			var def=w.db.get_def("research",str(a.get("id","")))
			if def.is_empty() or def.id in st.research or st.rp<int(def.rp):w.feedback="연구 포인트가 부족하거나 이미 완료했습니다.";return false
			if def.prerequisite!="" and def.prerequisite not in st.research:w.feedback="선행 연구가 필요합니다.";return false
			if not w.pay(int(def.cost),"연구"):return false
			st.rp-=int(def.rp);st.research.append(def.id);w.log_event("연구 완료: "+def.name);return true
		"skill_upgrade":
			var kind=str(a.get("kind",""))
			if not p.skills.has(kind) or int(p.skills[kind])>=5:return false
			var level=int(p.skills[kind]);var points=3+level*2
			if st.rp<points or not w.pay(4000*(level+1),"캐릭터 연구"):return false
			st.rp-=points;p.skills[kind]+=1;return true
		"inventory_upgrade":
			var size=p.inventory.size();var cap=10 if int(p.character)==2 else 9
			if size>=cap or not w.pay(3000*(size-1),"가방 확장"):return false
			p.inventory.append(null);return true
		"price":
			var recipe=str(a.get("recipe",""))
			if not s.prices.has(recipe):return false
			s.prices[recipe]=clampi(int(a.get("price",2700)),500,12000);return true
		"menu":
			var recipe=str(a.get("recipe",""))
			if w.db.get_def("recipes",recipe).is_empty() or (recipe!="fried" and recipe not in st.research):return false
			if recipe in s.menu:
				if s.menu.size()==1:return false
				s.menu.erase(recipe)
			else:s.menu.append(recipe)
			return true
		"ad":
			var tier=clampi(int(a.get("tier",0)),0,3)
			if tier==3 and "marketing" not in st.research:return false
			if not w.pay([2000,5000,8000,15000][tier],"광고"):return false
			s.ads.append({"tier":tier,"until":int(st.day)+[2,4,4,6][tier],"multiplier":[.12,.22,.30,.42][tier]});return true
		"loan":
			var def=w.db.get_def("loans",str(a.get("id","")))
			if def.is_empty() or st.loans.size()>=3 or st.credit<40:return false
			if def.id=="global" and "overseas" not in st.research:return false
			var debt=0
			for loan in st.loans:debt+=int(loan.principal)
			if debt+int(def.principal)>100000+st.stores.size()*150000:return false
			st.loans.append({"id":w.uid("loan"),"kind":def.id,"principal":int(def.principal),"due":int(st.day)+int(def.term),"unpaid":0,"penalty":0})
			st.cash+=int(def.principal);st.ledger["대출 실행"]=int(st.ledger.get("대출 실행",0))-int(def.principal);return true
		"repay":
			for loan in st.loans:
				if loan.id==str(a.get("id","")):
					if not w.pay(loan_balance(loan),"대출 상환"):return false
					st.loans.erase(loan);return true
		"market":
			var city=str(a.get("city",""));var grade=clampi(int(a.get("grade",1)),1,3)
			if w.db.get_def("cities",city).is_empty():return false
			var safe=bool(a.get("safe",false));var old=st.markets.get(city,{})
			var cost=roundi([0,3000,7000,14000][grade]*(2 if safe else 1)*(1-.04*int(p.skills.market)))
			if grade>int(old.get("grade",0)):cost=maxi(0,cost-int(old.get("paid",0)))
			if not w.pay(cost,"시장 조사"):return false
			if not safe and w.rng.randf()<.12:w.log_event("정보상이 사라졌습니다. 사기 피해 %d원."%cost);return true
			market_scan(city,grade,"현지 식당 자문" if safe else "정보상",cost);return true
		"expand":
			var city=str(a.get("city",""));var def=w.db.get_def("cities",city)
			if def.is_empty() or st.stores.has(city) or st.day-int(st.closed.get(city,-99))<30:return false
			if def.country=="jp" and ("overseas" not in st.research or st.brand<55):w.feedback="일본 진출 연구와 브랜드 55점이 필요합니다.";return false
			if not w.pay(int(def.entry),"도시 진출"):return false
			st.stores[city]=w.make_store(city);w.log_event(def.name+" 매장을 열었습니다.");return true
		"close_store":
			if st.stores.size()<=1:return false
			for actor in st.players.values():
				if actor.store==s.id:return false
			# Requires explicit city selection; the occupied store can never vanish.
			return false
		"sell_store":
			var city=str(a.get("city",""))
			if not st.stores.has(city) or st.stores.size()<=1:return false
			for actor in st.players.values():
				if actor.store==city:w.feedback="두 플레이어가 다른 매장으로 이동한 뒤 폐점하세요.";return false
			var fallback=st.stores.keys().filter(func(id):return id!=city)[0]
			for e in st.staff:
				if e.store==city:release_employee(e);e.store=fallback
			if st.has("offline_guest") and st.offline_guest.store==city:
				st.offline_guest.store=fallback;st.offline_guest.location="store";st.offline_guest.floor=0;st.offline_guest.vehicle="";st.offline_guest.x=288.0;st.offline_guest.y=224.0
			var value=int(w.db.get_def("cities",city).entry*.5)
			for car in st.stores[city].vehicles:value+=int(w.db.get_def("vehicles",car.kind).price*.6)
			st.cash+=value;st.ledger["매장 매각"]=int(st.ledger.get("매장 매각",0))-value;st.closed[city]=st.day;st.stores.erase(city);return true
		"auto_order":
			if "auto_order" not in st.research:return false
			s.auto_order=clampi(int(a.get("qty",0)),0,100);return true
		"build":return build(p,a)
		"remove":return remove_object(p,str(a.get("id","")))
		"move_object":return move_object(p,a)
		"floor_style":
			if not w.pay(2000,"인테리어"):return false
			s.floor_style="kitchen" if s.floor_style=="floor" else "floor";return true
		"floor_add":
			if "floors" not in st.research or int(s.floors)>=int(w.db.get_def("cities",s.id).floors):return false
			if not w.pay(40000*int(s.floors),"층 확장"):return false
			for floor_id in range(int(s.floors)+1):
				var exists=false
				for obj in s.objects:
					if obj.kind=="stairs" and int(obj.floor)==floor_id:exists=true
				if not exists:s.objects.append(w.make_object("stairs",14,2,floor_id))
			s.floors+=1;return true
		"fridge_upgrade":
			var obj=w.object_by(s,str(a.get("id","")))
			if obj.is_empty() or obj.kind!="fridge" or obj.slots.size()>=9:return false
			if not w.pay(8000,"냉장고 확장"):return false
			obj.slots.append_array([null,null,null]);return true
		"priority":s.priority="queue" if s.priority=="deadline" else "deadline";return true
	return false

func retail_buy(p: Dictionary,a: Dictionary) -> bool:
	if p.location!="retail" or w.state.phase not in ["business","closing"] or p.y>250:w.feedback="마트 안 진열대에 다가가 구매하세요.";return false
	var s=w.store_of(p);var car=w.vehicle(s,p.vehicle)
	var ingredient=str(a.get("ingredient",""));var qty=clampi(int(a.get("qty",1)),1,100)
	if car.is_empty() or not s.retail.has(ingredient):return false
	var def=w.db.get_def("vehicles",car.kind)
	if car.cargo.size()+qty>w.cargo_capacity(car):w.feedback="차량 적재 한도를 초과합니다.";return false
	if int(s.retail[ingredient])<qty:w.feedback="오늘 마트 재고가 부족합니다.";return false
	var price=w.unit_price(s.id,ingredient,true)
	if not w.pay(price*qty,"긴급 소매 구매"):return false
	s.retail[ingredient]-=qty
	for i in range(qty):car.cargo.append({"id":w.uid("cargo"),"ingredient":ingredient,"cost":price})
	w.sound="coin";w.feedback="차량에 적재했습니다. 귀환 후 하역해야 사용할 수 있습니다.";return true

func employee(id: String) -> Dictionary:
	for e in w.state.staff:
		if e.id==id:return e
	return {}

func candidate(job: String) -> Dictionary:
	var roll=w.rng.randf();var tier=0
	if roll>.97:tier=4
	elif roll>.85:tier=3
	elif roll>.65:tier=2
	elif roll>.35:tier=1
	var grade=w.db.all("grades")[tier]
	var ability=w.rng.randf_range(.8,1.2)
	var traits=[]
	var common=["건강함","불성실함","친절함","느림","정리정돈","차분함","깔끔함","사교적"]
	var count=int(grade.traits)
	if tier in [1,3]:count=w.rng.randi_range(count-1,count)
	if w.rng.randf()<grade.rare:traits.append(["전처리달인","정밀한 튀김손","접객달인","정확한 계산","청소달인","침착한 정비사","위기대응가"][w.JOBS.find(job)])
	while traits.size()<count:
		var trait_name=common[w.rng.randi_range(0,common.size()-1)]
		if trait_name not in traits:traits.append(trait_name)
	return {"id":w.uid("staff"),"name":["하늘","민서","유진","서준","지우","다온","하루","수빈","나래","유나","도윤","소라"][w.rng.randi_range(0,11)],"job":job,"grade":grade.id,"fee":int(grade.fee),"wage":roundi(grade.wage*ability),"contract":int(grade.contract),"speed":ability*(1+tier*.12),"traits":traits,"satisfaction":w.rng.randf_range(65,85),"sprite":w.rng.randi_range(4,11)}

func refresh_candidates() -> void:
	w.state.candidates={};w.state.refreshes={}
	for job in w.JOBS:w.state.candidates[job]=candidate(job)

func hire(s: Dictionary,job: String) -> bool:
	var e=w.state.candidates.get(job,{})
	if e.is_empty() or not w.pay(int(e.fee),"채용"):return false
	e=e.duplicate(true)
	e.merge({"store":s.id,"hired":w.state.day,"leave":[],"month":int((int(w.state.day)-1)/30),"illness_count":0,"absence_count":0,"sick_until":0,"absent":0,"last_bonus":-7,"reasons":{},"relationships":{},"requests":["청결","drink"],"used":[],"x":288.0,"y":176.0,"floor":0,"state":"대기","target":"","task":"","progress":0.0,"item":null,"recipe":"fried","workload":0.0,"break_clock":0.0,"last_delta":0.0,"last_reasons":{}})
	month_schedule(e)
	w.state.staff.append(e);w.state.candidates.erase(job)
	w.log_event("%s 채용 · %s / 특성: %s"%[e.name,e.job,", ".join(e.traits)]);return true

func month_schedule(e: Dictionary) -> void:
	e.leave=[];e.illness_count=0;e.absence_count=0;e.month=int((int(w.state.day)-1)/30)
	var count=w.rng.randi_range(2,7)
	while e.leave.size()<count:
		var day=w.rng.randi_range(1,30)
		if day not in e.leave:e.leave.append(day)
	e.leave.sort()

func attendance() -> void:
	var day=int(w.state.day);var date=(day-1)%30+1
	for e in w.state.staff:
		e.used=[];e.workload=0.0;e.break_clock=0.0;e.state="대기"
		if date in e.leave:e.state="휴가";continue
		if day<int(e.sick_until):e.state="병가";continue
		var illness=.02*(.5 if "건강함" in e.traits else 1.0) if int(e.illness_count)==0 else 0.0
		var absence=.02*(1.5 if "불성실함" in e.traits else 1.0) if int(e.absence_count)==0 else 0.0
		var roll=w.rng.randf()
		if roll<illness:
			e.illness_count+=1;e.sick_until=day+w.rng.randi_range(1,3);e.state="병가";w.log_event("%s 병가 · %d일 복귀 예정"%[e.name,e.sick_until])
		elif roll<illness+absence:
			e.absence_count+=1;e.absent=day;e.state="결근";w.log_event(e.name+" 개인 사정으로 오늘 결근합니다.")

func available(e: Dictionary) -> bool:
	return e.state not in ["휴가","병가","결근"]

func release_employee(e: Dictionary) -> void:
	for s in w.state.stores.values():
		for obj in s.objects:
			if obj.lock==e.id:obj.lock=""
			if obj.used_by==e.id:obj.used_by=""
	e.target="";e.task="";e.progress=0.0;e.item=null

func loan_balance(loan: Dictionary) -> int:
	var def=w.db.get_def("loans",loan.kind)
	return int(loan.principal)+roundi(loan.principal*def.maturity)+int(loan.unpaid)+int(loan.penalty)

func market_scan(city: String,grade: int,source: String,cost: int) -> void:
	var data=w.state.economies[city].duplicate(true)
	var old=w.state.markets.get(city,{})
	for key in ["demand","sensitivity","competition","spending"]:
		data[key]*=w.rng.randf_range(1-(.12 if grade==1 else .04),1+(.12 if grade==1 else .04)) if grade<3 else 1.0
	w.state.markets[city]={"day":w.state.day,"grade":grade,"paid":int(old.get("paid",0))+cost,"source":source,"data":data}
	w.log_event(w.db.title("cities",city)+" 시장 보고서를 갱신했습니다.")

func build_cost(kind: String) -> int:
	var welfare=w.db.get_def("welfare",kind)
	if not welfare.is_empty():return int(welfare.price)
	return {"board":2500,"batter":3000,"fryer":9000,"plate":3000,"counter":4000,"fridge":7000,"table":3500,"bench":1500,"plant":1500,"kiosk":10000,"wall_block":500,"lamp":1200,"chair":500,"extinguisher":3000,"generator":12000,"vent":8000,"drain":6000,"parking":18000,"elevator":26000}.get(kind,-1)

func placement_valid(s: Dictionary,obj: Dictionary,ignore: String="") -> bool:
	if obj.x<1 or obj.x>int(s.get("width",18))-2 or obj.y<2 or obj.y>int(s.get("height",13))-3:return false
	if Vector2(obj.x,obj.y).distance_to(Vector2(15,2))<2:return false
	for other in s.objects:
		if other.id!=ignore and int(other.floor)==int(obj.floor) and int(other.x)==int(obj.x) and int(other.y)==int(obj.y):return false
	var shadow=s.duplicate(true)
	if ignore!="":shadow.objects=shadow.objects.filter(func(o):return o.id!=ignore)
	shadow.objects.append(obj)
	# Flood fill from front entrance. Every appliance must retain a reachable work tile.
	var start=Vector2i(8,int(s.get("height",13))-2)
	var frontier=[start];var visited={start:true}
	while not frontier.is_empty():
		var current=frontier.pop_front()
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next=current+delta
			if next.x<1 or next.x>int(s.get("width",18))-2 or next.y<1 or next.y>int(s.get("height",13))-2 or visited.has(next):continue
			if w.solid(shadow,Vector2(next)*32+Vector2(16,16),obj.floor):continue
			visited[next]=true;frontier.append(next)
	if not visited.has(Vector2i(15,2)):return false
	for other in shadow.objects:
		if int(other.floor)!=int(obj.floor) or other.kind in ["wall_block","plant","lamp","chair"]:continue
		var reachable=false
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if visited.has(Vector2i(other.x,other.y)+delta):reachable=true
		if not reachable:return false
	return true

func build(p: Dictionary,a: Dictionary) -> bool:
	var s=w.store_of(p);var kind=str(a.get("kind",""));var cost=build_cost(kind)
	if cost<0:return false
	if kind=="kiosk" and "kiosk" not in w.state.research:return false
	if kind=="elevator":
		if "floors" not in w.state.research or s.floors<2:return false
		var lifts=[]
		for floor_id in range(int(s.floors)):
			var lift=w.make_object(kind,int(a.get("x",0)),int(a.get("y",0)),floor_id)
			if not placement_valid(s,lift):w.feedback="모든 층에 엘리베이터 통로가 필요합니다.";return false
			lifts.append(lift)
		if not w.pay(cost,"엘리베이터"):return false
		s.objects.append_array(lifts);return true
	if kind=="parking":
		if "parking" not in w.state.research or int(s.parking)>=3:return false
		if not w.pay(cost,"건설"):return false
		s.parking+=1;return true
	var obj=w.make_object(kind,int(a.get("x",0)),int(a.get("y",0)),int(p.floor))
	obj.rotation=clampi(int(a.get("rotation",0)),0,3)
	if not placement_valid(s,obj):w.feedback="통로·출입구·설비 접근을 막는 배치는 불가합니다.";return false
	if not w.pay(cost,"건설"):return false
	s.objects.append(obj);w.sound="coin";return true

func remove_object(p: Dictionary,id: String) -> bool:
	var s=w.store_of(p);var obj=w.object_by(s,id)
	if obj.is_empty() or obj.kind in ["door","stairs","stock"] or obj.lock!="" or obj.open_by!="" or obj.item!=null:return false
	if obj.kind=="fridge" and obj.slots.any(func(v):return v!=null):return false
	if obj.customer!="":return false
	s.objects.erase(obj);w.state.cash+=maxi(0,roundi(build_cost(obj.kind)*.4));return true

func move_object(p: Dictionary,a: Dictionary) -> bool:
	var s=w.store_of(p);var obj=w.object_by(s,str(a.get("id","")))
	if obj.is_empty() or obj.kind in ["door","stairs","stock"] or obj.lock!="" or obj.open_by!="":return false
	var proposed=obj.duplicate(true);proposed.x=int(a.get("x",0));proposed.y=int(a.get("y",0));proposed.rotation=int(a.get("rotation",obj.rotation))%4
	if not placement_valid(s,proposed,obj.id):w.feedback="이 위치는 통로를 막습니다.";return false
	obj.x=proposed.x;obj.y=proposed.y;obj.rotation=proposed.rotation;return true

func settle() -> void:
	var st=w.state
	st.phase="settlement"
	var wages=0;var revenue=0;var waste=0;var failures=0;var served=0
	for s in st.stores.values():
		for customer in s.customers:
			if customer.state not in ["eating","leaving"]:w.simulation.fail_customer(s,customer,customer.state=="ordered")
		s.customers.clear()
		for obj in s.objects:
			if obj.item!=null:discard(s,obj.item);obj.item=null
			obj.lock="";obj.open_by="";obj.used_by="";obj.customer=""
		for food in s.floor_items.values():discard(s,food)
		s.floor_items.clear()
		for ingredient in s.stock:
			s.waste+=int(s.stock[ingredient]);s.waste_cost+=int(s.stock[ingredient])*w.unit_price(s.id,ingredient);s.stock[ingredient]=0
		for car in s.vehicles:
			for cargo in car.cargo:s.waste+=1;s.waste_cost+=int(cargo.cost)
			car.cargo.clear();car.driver="";car.x=80.0;car.y=208.0;car.velocity=0.0
		charge_due(int(w.db.get_def("cities",s.id).rent),"임대료")
		if s.event!="":
			var damage=3000 if s.event in ["화재","정전","튀김기 고장"] else 1000
			charge_due(damage,"미복구 사고 손해")
			if int(s.get("insured_day",0))==int(st.day):
				var coverage=roundi(damage*.7);st.cash+=coverage;st.ledger["보험금 수령"]=int(st.ledger.get("보험금 수령",0))-coverage
		var kinds=[]
		for obj in s.objects:
			if obj.kind not in kinds:kinds.append(obj.kind)
		for kind in kinds:
			var def=w.db.get_def("welfare",kind)
			if not def.is_empty():charge_due(int(def.fixed),"복리후생 고정비")
		revenue+=int(s.revenue);failures+=int(s.failed);served+=int(s.served);waste+=int(s.waste)
	var all_players=st.players.values()
	if st.has("offline_guest"):all_players.append(st.offline_guest)
	for p in all_players:
		var s=w.store_of(p)
		for food in p.inventory:
			if food!=null:discard(s,food);waste+=1
		p.inventory.fill(null);p.location="store";p.floor=0;p.x=288.0;p.y=224.0;p.vehicle="";p.fridge="";p.input=[0.0,0.0];p.working=false;p.cooldown=0;p.skill_until=0
	for e in st.staff.duplicate():
		if e.item!=null:discard(st.stores[e.store],e.item)
		charge_due(int(e.wage),"직원 일급");wages+=int(e.wage)
		var s=st.stores[e.store]
		var kinds=[]
		for obj in s.objects:
			if obj.kind not in kinds:kinds.append(obj.kind)
		for kind in ["locker","climate"]:
			if kind in kinds:e.reasons[kind]=w.db.get_def("welfare",kind).effect
		e.reasons["업무량"]=-1.0 if e.workload>600 else .25
		e.reasons["청결"]=-.5 if s.objects.any(func(o):return o.kind=="table" and o.dirty>0) else .25
		if "drink" not in kinds:e.reasons["음료대 요구"]=-.25
		if s.event!="":e.reasons["설비 사고"]=-1
		var partners=st.staff.filter(func(other):return other.id!=e.id and other.store==e.store)
		if not partners.is_empty():
			var other=partners[w.rng.randi_range(0,partners.size()-1)]
			var change=w.rng.randi_range(-6,8)+(2 if "사교적" in e.traits else 0)
			e.relationships[other.id]=clampi(int(e.relationships.get(other.id,0))+change,-100,100)
			e.reasons["동료 관계"]=float(e.relationships[other.id])*.006
		var delta=0.0
		for v in e.reasons.values():delta+=float(v)
		e.last_delta=clampf(delta,-3,3);e.satisfaction=clampf(e.satisfaction+e.last_delta,0,100);e.last_reasons=e.reasons.duplicate();e.reasons={}
		release_employee(e)
		if e.satisfaction<=30:w.log_event("%s 만족도 %.1f · 근무 환경을 개선하세요."%[e.name,e.satisfaction])
		if w.rng.randf()<quit_chance(e.satisfaction):st.staff.erase(e);w.log_event(e.name+" 직원이 자진 퇴사했습니다.")
	for loan in st.loans.duplicate():
		var def=w.db.get_def("loans",loan.kind);var interest=roundi(loan.principal*def.rate)
		if not w.pay(interest,"대출 일일 이자"):loan.unpaid+=interest
		if int(st.day)>=int(loan.due):
			if w.pay(loan_balance(loan),"대출 만기 상환"):st.loans.erase(loan)
			else:loan.penalty+=roundi(loan.principal*.01);st.credit=maxi(0,int(st.credit)-5);w.log_event("대출 만기 연체 · 전액 상환 또는 자산 매각이 필요합니다.")
	var expense=0
	for v in st.ledger.values():expense+=int(v)
	st.summary={"revenue":revenue,"expense":expense,"profit":revenue-expense,"wages":wages,"served":served,"failed":failures,"waste":waste,"ledger":st.ledger.duplicate(true)}
	st.rp+=2+int(served/5)
	if st.career_sales>=10 and "첫 10그릇" not in st.achievements:st.achievements.append("첫 10그릇")
	if st.stores.size()>=3 and "세 도시의 식탁" not in st.achievements:st.achievements.append("세 도시의 식탁")
	if st.stores.keys().any(func(city):return w.db.get_def("cities",city).country=="jp") and "바다 건너 식탁" not in st.achievements:st.achievements.append("바다 건너 식탁")
	if st.stores.size()==16 and "열여섯 도시의 요리사" not in st.achievements:
		st.achievements.append("열여섯 도시의 요리사");w.log_event("축하합니다! 한국과 일본의 모든 도시에 식탁을 열었습니다. 이제 나만의 프랜차이즈를 계속 가꾸세요.")
	w.log_event("하루 정산 · 매출 %d원 / 지출 %d원"%[revenue,expense])

func discard(s: Dictionary,food: Dictionary) -> void:
	s.waste+=1;s.waste_cost+=int(food.get("cost",0))

func charge_due(amount: int,category: String) -> void:
	# Mandatory debts remain visible; optional purchases never overdraw shared cash.
	w.state.cash-=amount;w.state.ledger[category]=int(w.state.ledger.get(category,0))+amount

func quit_chance(value: float) -> float:
	if value>20:return 0
	if value>=10:return .05+(20-value)*.02
	return .25+(10-value)*.01

func next_day() -> void:
	var st=w.state
	st.day+=1;st.tick=0;st.phase="prep";st.ready={};st.ledger={}
	if (int(st.day)-1)%7==0:refresh_candidates()
	for e in st.staff:
		if int((int(st.day)-1)/30)!=int(e.month):month_schedule(e)
		if int(e.sick_until)<=int(st.day):e.state="대기"
	for city in st.economies:
		var econ=st.economies[city];var base=w.db.get_def("cities",city)
		econ.price=clampf(econ.price*w.rng.randf_range(.98,1.025),base.price*.75,base.price*1.65)
		econ.demand=clampf(econ.demand*w.rng.randf_range(.96,1.04),.5,1.6);econ.event="평온한 날"
		if w.rng.randf()<.16:
			econ.event=["관광객 급증","불황","공급 충격","폭설","폭염","태풍","지진","지역 축제"][w.rng.randi_range(0,7)]
			if econ.event in ["관광객 급증","지역 축제"]:econ.demand=minf(1.8,econ.demand*1.2)
			if econ.event=="불황":econ.demand=maxf(.4,econ.demand*.8)
			if econ.event=="공급 충격":econ.price*=1.15
	for s in st.stores.values():
		s.served=0;s.failed=0;s.lost=0;s.revenue=0;s.waste=0;s.waste_cost=0;s.spawn=12.0;s.event_cooldown=150.0
		s.ads=s.ads.filter(func(ad):return int(ad.until)>=int(st.day))
		for ingredient in s.retail:s.retail[ingredient]=30
		if s.auto_order>0:
			for ingredient in ["chicken","flour","box"]:
				var qty=maxi(0,int(s.auto_order)-int(s.stock[ingredient]))
				if qty>0 and w.pay(qty*w.unit_price(s.id,ingredient),"자동 발주"):s.stock[ingredient]+=qty
	w.log_event("새로운 하루 · %d일 준비"%st.day)
