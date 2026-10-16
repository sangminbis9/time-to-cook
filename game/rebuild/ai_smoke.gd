extends SceneTree
const World=preload("res://rebuild/world.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var w=World.new();w.new_game(0,821);w.state.cash=500000
	var s=w.state.stores.incheon
	for ingredient in ["chicken","flour","box"]:s.stock[ingredient]=60
	for job in w.JOBS:
		w.management.hire(s,job)
		w.state.staff[-1].leave=[]
		w.state.staff[-1].illness_count=1;w.state.staff[-1].absence_count=1
	s.objects.append(w.make_object("drink",14,7,0))
	w.start_day()
	# Exercise automation while the owner is physically away at the parking lot.
	w.player("1").location="parking"
	for i in range(6000):w.step()
	var used=0
	for e in w.state.staff:
		if "drink" in e.used:used+=1
	var result={"served":s.served,"failed":s.failed,"revenue":s.revenue,"staff":w.state.staff.size(),"welfare_visitors":used,"status":"PASS" if s.served>0 and used>0 and s.stock.chicken<60 else "FAIL"}
	var f=FileAccess.open("res://../release/ai-results.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print(JSON.stringify(result))
	quit(0 if result.status=="PASS" else 1)
