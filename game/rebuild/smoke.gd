extends SceneTree
const World=preload("res://rebuild/world.gd")
const Session=preload("res://rebuild/session.gd")
var failures: Array=[]
var checks: int=0
var seq: int=0
var w

func _initialize() -> void:call_deferred("run")
func check(condition: bool,name: String) -> void:
	checks+=1
	if not condition:failures.append(name);printerr("FAIL: "+name)
func cmd(action: String,args: Dictionary={}) -> bool:
	seq+=1;return w.command("1",seq,action,args)
func at(kind: String) -> Dictionary:
	var p=w.player("1");var obj=w.simulation.find_kind(w.store_of(p),kind)
	var point=w.simulation.adjacent(w.store_of(p),obj);p.x=point.x;p.y=point.y;p.face=3;p.floor=obj.floor
	return obj
func ticks(count: int) -> void:
	for i in range(count):w.step()

func run() -> void:
	w=World.new();w.new_game(0,821)
	var s=w.state.stores.incheon;var p=w.player("1")
	check(w.state.cash==90000 and s.vehicles.is_empty(),"initial cash and no free vehicle")
	check(w.db.all("cities").size()==16 and w.db.all("welfare").size()==8,"complete city and welfare catalogs")
	var facilities=0
	for def in w.db.all("welfare"):facilities+=int(def.price)
	check(facilities==149000,"confirmed welfare prices")
	check(cmd("buy_stock",{"ingredient":"chicken","qty":10}),"wholesale chicken")
	cmd("buy_stock",{"ingredient":"flour","qty":10});cmd("buy_stock",{"ingredient":"box","qty":10})
	var cash=w.state.cash
	check(not w.command("1",seq,"buy_stock",{"ingredient":"chicken","qty":10}) and w.state.cash==cash,"repeated command id cannot charge twice")
	check(cmd("vehicle_buy",{"id":"used_hatchback"}),"vehicle purchase")
	check(cmd("ready"),"start regular day")
	check(not cmd("buy_stock",{"ingredient":"chicken","qty":1}),"wholesale blocked during business")
	at("stock");check(cmd("interact") and s.stock.chicken==9,"stock withdrawal exactly once")
	at("board");cmd("interact");p.working=true;ticks(72);p.working=false;cmd("interact")
	check(w.held(p)!=null and w.held(p).stage=="cut","manual cutting with persistent progress")
	at("batter");cmd("interact");p.working=true;ticks(1);p.working=false;cmd("interact")
	check(w.held(p).stage=="prepared" and s.stock.flour==9,"batter consumes real inventory")
	at("fryer");cmd("interact");ticks(170);cmd("interact")
	check(w.held(p).stage=="normal","frying normal timing window")
	var fridge=at("fridge");cmd("interact")
	check(not cmd("fridge",{"slot":0}),"heated food refrigerator rejection")
	cmd("close_fridge")
	at("plate");cmd("interact");p.working=true;ticks(1);p.working=false;cmd("interact")
	check(w.held(p).stage=="fried" and s.stock.box==9,"plated recipe and packaging consumption")
	# Spawn a real visitor and run its walking FSM into the restaurant.
	s.customers.clear()
	for obj in s.objects:obj.customer=""
	w.simulation.spawn_customer(s);var c=s.customers[0];c.type="dine";c.recipe="fried"
	ticks(200)
	check(c.state=="waiting","customer enters and reaches table")
	var table=w.object_by(s,c.table);p.x=w.obj_pos(table).x;p.y=w.obj_pos(table).y+32;p.face=3
	cmd("interact");check(c.state=="ordered","table order accepted")
	var before=w.state.cash;cmd("interact")
	check(c.state=="eating" and w.state.cash==before+2700 and w.held(p)==null,"atomic serving pays once")
	cmd("interact");check(w.state.cash==before+2700,"duplicate serving cannot pay twice")
	c.eat=.1;ticks(3);check(table.dirty>0,"dining creates dirty table")
	var dirt=table.dirty;p.working=true;ticks(20);p.working=false;check(table.dirty<dirt,"manual cleaning progresses")
	w.state.players["2"]=w.make_player(1);var p2=w.player("2");p2.x=p.x;p2.y=p.y;p2.face=3;table.dirty=8;p.working=true;p2.working=true;ticks(80);p.working=false;p2.working=false
	check(table.dirty<.01,"two-player cleaning linear contribution")
	w.state.players.erase("2")
	at("stock");cmd("interact");at("fridge");cmd("interact");cmd("fridge",{"slot":0});cmd("close_fridge")
	check(fridge.slots[0]!=null,"unheated food retained in refrigerator")
	at("door");check(cmd("interact") and p.location=="parking","back door exit")
	p.x=256;p.y=260;check(cmd("interact") and p.location=="road","enter purchased vehicle")
	var car=s.vehicles[0];var old_tick=w.state.tick;var stock_before=s.stock.chicken
	cmd("input",{"x":1,"y":0});ticks(540);cmd("input",{"x":0,"y":0})
	check(car.x>2860 and w.state.tick>old_tick+500,"real driving and business time advances")
	cmd("interact");p.y=200
	before=w.state.cash
	check(cmd("retail_buy",{"ingredient":"chicken","qty":5}),"retail purchase into cargo")
	check(w.state.cash==before-5*w.unit_price(s.id,"chicken")*3 and s.stock.chicken==stock_before,"retail 3x and no instant stock")
	check(not cmd("retail_buy",{"ingredient":"chicken","qty":20}),"capacity enforced")
	p.y=310;cmd("interact");cmd("input",{"x":-1,"y":0});ticks(540);cmd("input",{"x":0,"y":0});cmd("interact");cmd("interact")
	check(p.location=="parking" and car.cargo.is_empty() and s.stock.chicken==stock_before+5,"return and unload real cargo")
	p.x=128;p.y=132;cmd("interact");check(p.location=="store","return to kitchen")
	w.state.tick=14399;ticks(1);check(w.state.phase=="closing","21:00 stops admissions")
	w.state.tick=15599;ticks(1);check(w.state.phase=="settlement" and fridge.slots[0]!=null and s.stock.chicken==0,"22:00 settlement waste and refrigeration")
	cmd("next_day");check(w.state.phase=="prep" and w.state.day==2,"next day")
	w.state.cash=500000
	check(cmd("hire",{"job":"청소"}),"hire staff")
	var e=w.state.staff[-1];check(e.traits.size()>=1 and e.leave.size()>=2 and e.leave.size()<=7,"traits and leave schedule")
	check(cmd("bonus",{"id":e.id,"tier":2}) and not cmd("bonus",{"id":e.id,"tier":0}),"bonus cooldown")
	var previous=e.satisfaction;w.management.settle();check(absf(e.satisfaction-previous)<=3.001,"satisfaction daily cap")
	w.management.next_day();check(cmd("loan",{"id":"working"}),"bank loan")
	w.state.rp=100;check(cmd("research",{"id":"soy"}) and cmd("research",{"id":"overseas"}),"research prerequisites")
	w.state.brand=60;check(cmd("expand",{"city":"tokyo"}),"Japan expansion")
	check(not cmd("build",{"kind":"wall_block","x":15,"y":2}),"exit-blocking construction rejected")
	check(cmd("vehicle_upgrade",{"id":s.vehicles[0].id}) and w.cargo_capacity(s.vehicles[0])==14,"vehicle upgrade affects cargo capacity")
	check(cmd("insurance") and not cmd("insurance"),"daily insurance purchase is unique")
	check(cmd("research",{"id":"parking"}) and cmd("research",{"id":"floors"}) and cmd("floor_add"),"floor expansion research and construction")
	# The new two-tile dining table occupies (15,9); use the clear eastern aisle.
	check(cmd("build",{"kind":"elevator","x":15,"y":7}) and s.objects.filter(func(o):return o.kind=="elevator").size()==2,"elevator connects both floors")
	var session=Session.new();session.name="Session";root.add_child(session);session.set_process(false);session.world=w;session.connected=true;session.save_root="user://smoke_saves"
	check(session.save(1),"atomic versioned save")
	var expected=JSON.stringify(w.state.stores);var expected_cash=w.state.cash
	check(session.load_slot(1) and session.world.state.stores==JSON.parse_string(expected) and session.world.state.cash==expected_cash,"load restores state")
	var result={"checks":checks,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}
	var f=FileAccess.open("res://../release/smoke-results.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
