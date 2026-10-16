extends SceneTree
# A small visual fixture set, using the real scene and renderer; no save writes.
var app
var output="res://../release/cozy-overhaul"
var failures=[]

func _initialize() -> void:call_deferred("run")

func run() -> void:
	app=load("res://rebuild/main.tscn").instantiate();root.add_child(app);await process_frame
	app.session.save_root="user://cozy_fixture";app.session.start(0,3);app.session.set_process(false)
	var w=app.session.world;var p=w.player("1")
	for city in w.db.all("cities"):
		if not w.state.stores.has(city.id):w.state.stores[city.id]=w.make_store(city.id)
		var s=w.state.stores[city.id]
		if w.solid(s,Vector2(288,224),0) or w.solid(s,Vector2(288,208),0):failures.append(city.id+": blocked spawn")
		for obj in s.objects:
			if obj.kind in ["plant","lamp","door","extinguisher"]:continue
			var reachable=false
			for point in w.approach_points(obj):
				if not w.solid(s,point,0) and not w.route(s,Vector2(272,352),point).is_empty():reachable=true;break
			if not reachable:failures.append(city.id+":"+obj.kind+" unreachable")
		for obj in s.objects:
			for other in s.objects:
				if obj.id<other.id and w.object_rect(obj).intersects(w.object_rect(other)):failures.append(city.id+": overlapping furniture")
	for city in ["incheon","jeju","kyoto","kobe"]:
		p.store=city;p.x=288;p.y=224;p.location="store"
		var s=w.store_of(p);s.stock.chicken=30;s.stock.flour=30;s.stock.box=30
		w.state.cash=300000;w.state.phase="prep"
		w.management.refresh_candidates()
		for job in ["전처리","조리","서빙"]:
			w.management.command("1","hire",{"job":job})
		for e in w.state.staff:e.leave=[];e.illness_count=1;e.absence_count=1
		w.start_day()
		# Arrivals still use the real FSM; seed a few parties for a busy-room visual.
		for i in range(3):w.simulation.spawn_customer(s)
		for i in range(650):w.step()
		app.show_game();app.toast_time=0
		await shot(city)
		w.state.phase="prep"
	p.store="incheon";app.open_panel("staff");await shot("staff");app.close_panel()
	app.open_panel("cars");await shot("cars");app.close_panel()
	w.state.cash=300000;w.management.command("1","vehicle_buy",{"id":"used_hatchback"})
	p.location="road";p.x=520;p.y=224
	var car=w.store_of(p).vehicles[0];car.driver="1";car.x=p.x;car.y=p.y;car.face=2;p.vehicle=car.id
	await shot("neighborhood")
	p.location="retail";p.x=288;p.y=270;await shot("grocery")
	var result={"layout_accessibility":failures,"source":"Godot OpenGL viewport","screenshots":["incheon","jeju","kyoto","kobe","staff","cars","neighborhood","grocery"]}
	var file=FileAccess.open(output.path_join("results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func shot(id: String) -> void:
	await process_frame;await process_frame;app.update_hud();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(id+".png"))
