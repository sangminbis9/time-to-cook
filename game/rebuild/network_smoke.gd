extends SceneTree
const Session=preload("res://rebuild/session.gd")
var session
var mode: String
var age: float=0
var stage: int=0
var connected_tick: int=0
var initial_cash: int=0
var results: Array=[]
var finish_at: float=0.0

func _initialize() -> void:call_deferred("setup")
func setup() -> void:
	mode="host" if "--host" in OS.get_cmdline_user_args() else "guest"
	session=Session.new();session.name="Session";root.add_child(session)
	session.save_root="user://network_smoke"
	if mode=="host":
		session.start(0,1);session.world.state.cash=200000
		session.send("vehicle_buy",{"id":"used_hatchback"})
		session.send("buy_stock",{"ingredient":"chicken","qty":10})
		session.send("buy_stock",{"ingredient":"flour","qty":10})
		session.send("buy_stock",{"ingredient":"box","qty":10})
		initial_cash=session.world.state.cash
		if session.host()!=OK:finish(false,"host bind failed")
	else:
		session.token="network-smoke-identity-0123456789"
		if session.join("127.0.0.1",1)!=OK:finish(false,"client start failed")

func _process(delta: float) -> bool:
	age+=delta
	if age>35:finish(false,"scenario timeout at stage %d"%stage);return false
	if session==null or not session.connected:return false
	var w=session.world
	if w.state.is_empty():return false
	if mode=="host":
		if stage==0 and session.guest_peer!=0 and w.state.players.has("2"):
			var guest=w.player("2");guest.location="parking";guest.x=256;guest.y=260
			session.send("ready");stage=1
		elif stage==1 and w.state.phase=="business":
			connected_tick=w.state.tick;stage=2
		elif stage==2:
			# Advance the ordinary world at 20x for a bounded two-process scenario.
			for i in range(20):w.step()
			var car=w.state.stores.incheon.vehicles[0]
			if car.cargo.size()==2:stage=3
		elif stage==3:
			for i in range(20):w.step()
			if w.state.stores.incheon.stock.chicken==12:
				session.snapshot.rpc_id(session.guest_peer,session.public_state())
				finish_at=age+.6;stage=4
		elif stage==4 and age>finish_at:
			var expected=initial_cash-200-2*1350
			finish(w.state.cash==expected and w.state.tick>connected_tick+500,"guest drove and shopped while host clock advanced; cargo unloaded; repeated RPC charged once")
	else:
		var p=w.player("2")
		if p.is_empty():return false
		match stage:
			0:
				if w.state.phase=="prep":session.send("ready");stage=1
			1:
				if w.state.phase=="business":session.send("interact");stage=2
			2:
				if p.location=="road":session.send("input",{"x":1,"y":0});stage=3
			3:
				if p.location=="road" and p.x>2860:session.send("input",{"x":0,"y":0});session.send("interact");stage=4
			4:
				if p.location=="retail":session.send("input",{"x":0,"y":-1});stage=5
			5:
				if p.y<230:
					session.send("input",{"x":0,"y":0});session.send("retail_buy",{"ingredient":"chicken","qty":2})
					session.request.rpc_id(1,session.sequence,"retail_buy",{"ingredient":"chicken","qty":2})
					stage=6
			6:
				var car=w.vehicle(w.store_of(p),p.vehicle)
				if car.cargo.size()==2:session.send("input",{"x":0,"y":1});stage=7
			7:
				if p.y>300:session.send("input",{"x":0,"y":0});session.send("interact");stage=8
			8:
				if p.location=="road":session.send("input",{"x":-1,"y":0});stage=9
			9:
				if p.location=="road" and p.x<145:session.send("input",{"x":0,"y":0});session.send("interact");stage=10
			10:
				if p.location=="parking":session.send("interact");stage=11
			11:
				if w.store_of(p).stock.chicken==12:finish(true,"guest snapshot received unloaded cargo")
	return false

func finish(ok: bool,detail: String) -> void:
	var result={"mode":mode,"pass":ok,"detail":detail,"seconds":age}
	var f=FileAccess.open("res://../release/network-%s.json"%mode,FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print(JSON.stringify(result));quit(0 if ok else 1)
