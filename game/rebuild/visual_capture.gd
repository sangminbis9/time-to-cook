extends SceneTree
# Engine-rendered visual fixtures; never reads or writes a player's save.
var app
var output="res://../release/visual-refresh"
var failures: Array=[]
var captured: Array=[]

func _initialize() -> void:call_deferred("run")

func run() -> void:
	app=load("res://rebuild/main.tscn").instantiate();root.add_child(app)
	await process_frame
	await shot("title")
	app.session.save_root="user://visual_fixture"
	app.session.start(0,3);app.session.set_process(false)
	var w=app.session.world
	for kind in ["chicken","flour","box"]:w.state.stores.incheon.stock[kind]=30
	for job in ["전처리","조리","서빙","청소"]:
		app.session.send("hire",{"job":job})
		for employee in w.state.staff:employee.leave=[];employee.illness_count=1;employee.absence_count=1
	w.start_day()
	for i in range(1000):w.step()
	var p=w.player("1");p.x=288;p.y=170
	app.show_game();app.toast_time=0
	await shot("incheon_business")
	w.state.phase="prep"
	for city in w.db.all("cities"):
		if not w.state.stores.has(city.id):w.state.stores[city.id]=w.make_store(city.id)
		p.store=city.id;p.x=288;p.y=170;p.location="store"
		for kind in app.view.art.regional_props:
			var name=app.view.regional(kind,city.id)
			if not app.view.textures.has(name):failures.append("missing "+name)
			if not name.begins_with(city.id+"_"):failures.append("generic city furniture: "+name)
		await shot("city_"+city.id)
	p.store="incheon"
	app.open_panel("city");await shot("map");app.close_panel()
	app.city_detail("kyoto");await shot("city_preview");app.close_panel()
	app.open_panel("build");await shot("construction");app.close_panel()
	app.session.send("vehicle_buy",{"id":"used_hatchback"})
	app.toast_time=0
	p.location="parking";p.x=224;p.y=260
	await shot("parking")
	var car=w.state.stores.incheon.vehicles[0]
	p.vehicle=car.id;car.driver="1";p.location="road";p.x=440;p.y=224;car.x=p.x;car.y=p.y;car.face=2
	await shot("road")
	p.location="retail";p.x=288;p.y=270
	await shot("retail")
	var result={"status":"PASS" if failures.is_empty() else "FAIL","cities":16,"regional_assets_checked":128,"captured":captured,"failures":failures,"source":"Godot OpenGL viewport; deterministic isolated visual fixtures"}
	var f=FileAccess.open(output.path_join("results.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func shot(id: String) -> void:
	await process_frame;await process_frame
	if app.screen=="game":app.update_hud()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(id+".png"));captured.append(id)
