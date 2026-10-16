extends SceneTree
var app
var failures: Array=[]
var panels: Array=[]

func _initialize() -> void:call_deferred("run")

func run() -> void:
	app=load("res://rebuild/main.tscn").instantiate();root.add_child(app)
	await process_frame
	app.session.save_root="user://cozy_ui_smoke_%d"%Time.get_ticks_usec()
	app.show_saves(true)
	await process_frame
	var button=find_button(app.ui,"새로 시작")
	if button==null:failures.append("new save button")
	else:button.pressed.emit()
	await process_frame
	button=find_button(app.ui,"하나 · 전처리 15% 빠름")
	if button==null:failures.append("character button")
	else:button.pressed.emit()
	await process_frame
	if app.screen!="game":failures.append("new game transition")
	for id in ["stock","staff","cars","research","build","city","finance","menu","skills","log","settings","credits","help"]:
		app.open_panel(id)
		await process_frame
		await process_frame
		panels.append(id)
		var viewport=Vector2(800,450)
		if app.panel.position.x+app.panel.size.x>viewport.x or app.panel.position.y+app.panel.size.y>viewport.y:failures.append("panel overflow: %s %s"%[id,app.panel.size])
		if id in ["stock","staff","city"]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../release/ui-%s.png"%id)
	app.close_panel()
	# Dispatch actual input events through Godot's input route.
	var p=app.session.world.player("1");var start=p.x
	var input=InputEventKey.new();input.physical_keycode=KEY_D;input.pressed=true;Input.parse_input_event(input)
	await create_timer(.5).timeout
	input=InputEventKey.new();input.physical_keycode=KEY_D;input.pressed=false;Input.parse_input_event(input)
	await process_frame
	if p.x<=start:failures.append("WASD movement input")
	app.show_title()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../release/title.png")
	var result={"panels":panels,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}
	var f=FileAccess.open("res://../release/ui-results.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func find_button(node: Node,text: String):
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null:return found
	return null
