extends Node2D
# Scene-backed restaurant renderer. Positions are feet/contact baselines;
# simulation owns the 32px footprints and never depends on image dimensions.
var host
var ground: TileMapLayer
var architecture: Node2D
var furniture: Node2D
var actors: Dictionary={}
var props: Dictionary={}
var frame_cache: Dictionary={}
var key=""
const MATERIALS=["floor","floor_alt","floor_dark","kitchen","wall","wall_side","grass","paving","tatami","basalt","checker","birch","soil"]

func _ready() -> void:
	ground=TileMapLayer.new();ground.tile_set=TileSet.new();ground.tile_set.tile_size=Vector2i(32,32);add_child(ground)
	for kind in MATERIALS:
		var source=TileSetAtlasSource.new();source.texture=host.textures[kind];source.texture_region_size=Vector2i(32,32)
		for y in range(2):
			for x in range(2):source.create_tile(Vector2i(x,y))
		ground.tile_set.add_source(source,MATERIALS.find(kind))
	architecture=Node2D.new();add_child(architecture)
	furniture=Node2D.new();furniture.y_sort_enabled=true;add_child(furniture)

func sprite(asset: String,point: Vector2,parent: Node,centered: bool=false) -> Sprite2D:
	var node=Sprite2D.new();node.texture=host.textures.get(asset);node.centered=centered;node.position=point.round();parent.add_child(node);return node

func anchored(asset: String,foot: Vector2,parent: Node) -> Sprite2D:
	var node=sprite(asset,foot,parent)
	if node.texture:node.offset=Vector2(-node.texture.get_width()/2,-node.texture.get_height())
	return node

func shadow(foot: Vector2,wide: bool=false) -> void:
	var name="shadow_wide" if wide else "shadow"
	if host.textures.has(name):
		var node=sprite(name,foot,architecture,true);node.modulate.a=.32

func rebuild(w,s,p) -> void:
	for node in architecture.get_children():node.queue_free()
	for node in furniture.get_children():node.queue_free()
	actors.clear();props.clear();ground.clear()
	var layout=host.layouts[s.id];var width=int(s.width);var height=int(s.height)
	var family=s.id if s.id in ["jeju","kyoto","kobe"] else "kr"
	var dining=layout.dining_floor if s.floor_style=="floor" else "kitchen"
	for y in range(-1,height+1):
		for x in range(-1,width+1):
			var material="grass" if x<0 or x>=width or y<0 or y>=height else dining
			if material=="floor" and posmod(int(x/2)*7+int(y/2)*3,5)==0:material="floor_alt"
			if x>=1 and x<width-1 and y>=1 and y<height-1:
				for zone in layout.kitchen:
					if Rect2(zone[0],zone[1],zone[2],zone[3]).has_point(Vector2(x,y)):material="kitchen"
			if x in [0,width-1]:material="wall_side"
			if y==0:material="wall"
			if y==height-1:material="paving"
			ground.set_cell(Vector2i(x,y),MATERIALS.find(material),Vector2i(posmod(x,2),posmod(y,2)))
	# Authored wall faces, timber corners, windows and shelves establish height.
	for x in range(0,width,2):sprite("wall_module",Vector2(x*32,-24),architecture)
	for x in layout.windows:
		sprite("window_"+family if host.textures.has("window_"+family) else "window",Vector2(x*32,-20),architecture)
		if host.textures.has("window_light"):
			var light=sprite("window_light",Vector2(x*32+8,40),architecture);light.modulate.a=.18
	sprite("shelf",Vector2(32,2),architecture);sprite("clock",Vector2(13*32+2,-5),architecture)
	if host.textures.has("painting_"+family):sprite("painting_"+family,Vector2(10*32,1),architecture)
	for y in [1,5,9]:
		sprite("post",Vector2(0,y*32-32),architecture);sprite("post",Vector2((width-1)*32+16,y*32-32),architecture)
	if host.textures.has("lowwall_"+family):
		for x in [0,2,4,10,12,14,16]:sprite("lowwall_"+family,Vector2(x*32,(height-1)*32-8),architecture)
	# Entry runner and alcove rugs are below all feet and table legs.
	sprite("rug",Vector2(7*32,(height-2)*32-8),architecture)
	if host.textures.has("entry_curtain"):sprite("entry_curtain",Vector2(7*32+16,(height-1)*32-9),architecture)
	for obj in s.objects:
		if int(obj.floor)!=int(p.floor):continue
		var rect=w.object_rect(obj);var foot=Vector2(rect.get_center().x,rect.end.y)
		if obj.kind=="table":
			if layout.rug:sprite("rug",rect.position+Vector2(-16,-8),architecture)
			# A seated guest is in front of the chair back; its foot anchor must sort
			# after that chair even though the chair's legs extend slightly forward.
			var chair=anchored(host.regional("chair",s.id),w.seat_position(obj)-Vector2(0,1),furniture);chair.offset.y+=7
			if w.object_size(obj).x>1:
				var second=anchored(host.regional("chair",s.id),w.seat_position(obj)+Vector2(32,-1),furniture);second.offset.y+=7
		shadow(foot-Vector2(0,4),w.object_size(obj).x>1)
		var group=Node2D.new();group.position=foot;furniture.add_child(group)
		var kind="table_vertical" if obj.kind=="table" and w.object_size(obj).y>1 else obj.kind
		var art=anchored(obj.get("art",host.regional(kind,s.id)),Vector2.ZERO,group)
		# Old saves retain their one-tile physical layout and fit their original slots.
		if not obj.has("footprint") and art.texture and art.texture.get_width()>40:art.scale.x=.5
		var item=sprite("food_raw",Vector2(-10,-34),group);item.visible=false
		var dirt=sprite("dirty_light",Vector2(-10,-24),group);dirt.visible=false
		var steam=sprite("steam",Vector2(-12,-54),group);steam.visible=false
		props[obj.id]={"node":group,"item":item,"dirt":dirt,"steam":steam}
	for xy in [Vector2(16,176),Vector2(width*32-16,240)]:
		anchored(host.regional("lamp",s.id),xy,furniture)
		if host.textures.has("lamp_light"):
			var light=sprite("lamp_light",xy-Vector2(0,20),architecture,true);light.modulate.a=.25

func frames_for(asset: String) -> SpriteFrames:
	if frame_cache.has(asset):return frame_cache[asset]
	var frames=SpriteFrames.new();frames.remove_animation("default")
	var tex=host.textures[asset]
	for row in range(int(tex.get_height()/48)):
		var anim=str(row);frames.add_animation(anim);frames.set_animation_speed(anim,2 if row==8 or (asset.begins_with("guest") and row in [4,5]) else (7 if row<5 else 5))
		for col in range(4):
			var frame=AtlasTexture.new();frame.atlas=tex;frame.region=Rect2(col*32,row*48,32,48);frames.add_frame(anim,frame)
	frame_cache[asset]=frames;return frames

func person(id: String,actor: Dictionary,asset: String,row: int,moving: bool,seen: Dictionary) -> void:
	seen[id]=true
	if not actors.has(id):
		var node=AnimatedSprite2D.new();node.centered=false;node.offset=Vector2(-16,-44);node.sprite_frames=frames_for(asset);furniture.add_child(node);actors[id]=node
		if host.textures.has("shadow"):
			var contact=sprite("shadow",Vector2(0,1),node,true);contact.z_index=-1;contact.modulate.a=.3
		var held=sprite("food_raw",Vector2(1,-23),node);held.name="HeldFood";held.scale=Vector2(.65,.65);held.visible=false
	var node=actors[id];node.position=Vector2(actor.x,actor.y).round();node.visible=true
	var held=node.get_node("HeldFood");held.visible=false
	var item=actor.get("item",null)
	if actor.has("inventory"):item=actor.inventory[int(actor.slot)]
	if item!=null:held.texture=host.textures.get("food_"+item.stage);held.visible=true
	if node.sprite_frames!=frames_for(asset):node.sprite_frames=frames_for(asset)
	if node.animation!=str(row):node.play(str(row))
	if moving:node.play()
	else:node.pause();node.frame=1

func update_world(w,s,p) -> void:
	var signature="%s:%s:%s:%s"%[s.id,p.floor,s.floor_style,JSON.stringify(s.objects.map(func(o):return [o.id,o.x,o.y,o.rotation,o.floor]))]
	if key!=signature:key=signature;rebuild(w,s,p)
	var phase=float(w.state.tick)/12000.0
	modulate=Color(1,1,1).lerp(Color(1,.91,.81),clampf(phase-.5,0,.25))
	for obj in s.objects:
		if not props.has(obj.id):continue
		var node=props[obj.id];node.item.visible=obj.item!=null;node.dirt.visible=obj.dirty>0;node.steam.visible=obj.kind=="fryer" and obj.item!=null and obj.item.heat>0
		if obj.item!=null:node.item.texture=host.textures.get("food_"+obj.item.stage)
		if node.dirt.visible:node.dirt.texture=host.textures["dirty_heavy" if obj.dirty>8 else ("dirty_medium" if obj.dirty>4 else "dirty_light")]
		if node.steam.visible:
			if host.textures.has("steam_0"):node.steam.texture=host.textures["steam_%d"%(int(host.elapsed*5)%4)]
			node.steam.position.y=-50-int(host.elapsed*5)%6;node.steam.modulate.a=.7
	var seen={}
	for c in s.customers:
		if int(c.floor)!=int(p.floor):continue
		var row=int(c.get("face",0));var active=c.state in ["table_walk","counter_walk","leaving","entering"]
		if c.state=="eating":row=6;active=true
		elif c.state in ["waiting","ordered"]:row=5 if c.type!="takeout" else 4;active=true
		var asset="guest_%d"%(int(c.sprite)%2)
		if not host.textures.has(asset):asset="person_%d"%(int(c.sprite)%4);row=mini(row,3)
		person(c.id,c,asset,row,active,seen)
	for e in w.state.staff:
		if e.store!=s.id or int(e.floor)!=int(p.floor) or e.state in ["휴가","병가","결근"]:continue
		var row=int(e.get("face",0));var active=e.state in ["이동","작업"]
		if e.state=="대기" and row==0 and host.textures["person_%d"%(int(e.sprite)%4)].get_height()>=480:row=8;active=true
		if e.item!=null and row==0:row=4
		if e.state=="작업":row=7 if e.task=="clean" else (5 if e.task=="cut" else 6)
		person(e.id,e,"person_%d"%(int(e.sprite)%4),row,active,seen)
	for id in w.state.players:
		var actor=w.state.players[id]
		if actor.store!=s.id or actor.location!="store" or int(actor.floor)!=int(p.floor):continue
		var moving=Vector2(actor.input[0],actor.input[1]).length_squared()>.1;var row=int(actor.face)
		if not moving and row==0 and host.textures["person_%d"%int(actor.character)].get_height()>=480:row=8;moving=true
		if w.held(actor)!=null and row==0:row=4
		if actor.working:
			var target=w.target(actor)
			if not target.is_empty():row=7 if target.kind=="table" else (5 if target.kind=="board" else 6);moving=true
		if id==host.session.local_id() and host.elapsed<host.interaction_until and host.textures["person_%d"%int(actor.character)].get_height()>=480:row=9;moving=true
		person("player_"+id,actor,"person_%d"%int(actor.character),row,moving,seen)
	for id in actors:
		if not seen.has(id):actors[id].visible=false
