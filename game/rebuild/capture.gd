extends SceneTree
var app
var output: String
func _initialize() -> void:call_deferred("run")

func run() -> void:
	app=load("res://rebuild/main.tscn").instantiate();root.add_child(app)
	output=ProjectSettings.globalize_path("res://../release/screenshots")
	await process_frame
	await shot("title")
	app.session.save_root="user://capture_scenes"
	app.session.start(0,1)
	for ingredient in ["chicken","flour","box"]:app.session.send("buy_stock",{"ingredient":ingredient,"qty":20})
	app.session.send("vehicle_buy",{"id":"used_hatchback"})
	for job in ["전처리","조리","서빙"]:
		app.session.send("hire",{"job":job})
		for e in app.session.world.state.staff:e.leave=[];e.illness_count=1;e.absence_count=1
	app.session.send("ready")
	for i in range(1000):app.session.world.step()
	app.show_game();app.tutorial_step=5
	await shot("kitchen")
	app.open_panel("city");await shot("franchise_map");app.close_panel()
	app.open_panel("staff");await shot("staff_management");app.close_panel()
	var p=app.session.world.player("1")
	p.x=496;p.y=80;p.face=3;app.session.send("interact")
	p.x=256;p.y=260;app.session.send("interact")
	app.session.send("input",{"x":1,"y":0})
	for i in range(250):app.session.world.step()
	await shot("emergency_drive")
	app.session.send("input",{"x":1,"y":0})
	for i in range(300):app.session.world.step()
	app.session.send("input",{"x":0,"y":0});app.session.send("interact")
	app.session.send("input",{"x":0,"y":-1})
	for i in range(25):app.session.world.step()
	app.session.send("input",{"x":0,"y":0});app.open_panel("retail")
	await shot("grocery_shopping")
	print("Captured title and five in-engine game screens.")
	quit()

func shot(name: String) -> void:
	await process_frame
	await process_frame
	await create_timer(.1).timeout
	app.update_hud()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
