extends Node
signal changed
signal message(text: String)
signal effect(name: String)
const World = preload("res://rebuild/world.gd")
var world = World.new()
var sequence: int = 0
var accumulator: float = 0.0
var network_clock: float = 0.0
var online: bool = false
var connected: bool = false
var guest_peer: int = 0
var local_character: int = 1
var token: String = ""
var active_slot: int = 1
var autosave_phase: String = ""
var join_address: String = ""
var pending_panel_sequence: int = 0
var save_root: String = "user://franchise_v2"

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func():message.emit("접속 실패 · 주소, UDP 7777과 방화벽을 확인하세요."))
	multiplayer.server_disconnected.connect(func():online=false;connected=false;message.emit("호스트 연결이 종료되었습니다. 게스트의 세계 시간은 정지합니다."))
	if FileAccess.file_exists("user://guest_identity.txt"):token=FileAccess.get_file_as_string("user://guest_identity.txt")
	else:
		token=Crypto.new().generate_random_bytes(24).hex_encode()
		var f=FileAccess.open("user://guest_identity.txt",FileAccess.WRITE)
		if f:f.store_string(token)

func authority() -> bool:return not online or multiplayer.is_server()
func local_id() -> String:return "2" if online and not multiplayer.is_server() else "1"

func start(character: int, slot: int) -> void:
	stop_network();connected=true;active_slot=slot;world.new_game(character);sequence=0;autosave_phase="";changed.emit()

func host() -> Error:
	if world.state.is_empty():return ERR_UNCONFIGURED
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_server(7777,1)
	if error!=OK:return error
	multiplayer.multiplayer_peer=peer;online=true;connected=true;message.emit("협동 호스트 · UDP 7777 / 같은 네트워크 또는 포트포워딩 필요");return OK

func join(address: String,character: int) -> Error:
	stop_network();local_character=character;join_address=address
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_client(address,7777)
	if error!=OK:return error
	multiplayer.multiplayer_peer=peer;online=true;connected=false;return OK

func stop_network() -> void:
	if multiplayer.multiplayer_peer:multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();online=false;guest_peer=0

func _connected() -> void:register.rpc_id(1,token,local_character)

@rpc("any_peer","call_remote","reliable")
func register(identity: String,character: int) -> void:
	if not multiplayer.is_server() or world.state.is_empty():return
	var sender=multiplayer.get_remote_sender_id()
	if guest_peer!=0 and guest_peer!=sender:return
	if identity.length()<20 or identity.length()>80:return
	var st=world.state
	if st.guest_token!="" and st.guest_token!=identity:
		rejected.rpc_id(sender,"이 세이브는 기존 협동 파트너에게 연결되어 있습니다.");return
	if st.guest_token=="":
		if character<0 or character>3 or character==int(st.players["1"].character):
			rejected.rpc_id(sender,"호스트와 다른 캐릭터를 선택하세요.");return
		st.guest_token=identity;st.guest_character=character
		st.players["2"]=world.make_player(character)
	elif st.has("offline_guest"):
		st.players["2"]=st.offline_guest;st.erase("offline_guest")
	guest_peer=sender
	snapshot.rpc_id(sender,public_state())
	message.emit("두 번째 요리사가 참가했습니다.")

@rpc("authority","call_remote","reliable")
func rejected(reason: String) -> void:
	message.emit(reason);stop_network();connected=false

func _disconnected(id: int) -> void:
	if not multiplayer.is_server() or id!=guest_peer:return
	world.release_locks("2")
	if world.state.players.has("2"):
		var p=world.state.players["2"]
		p.input=[0,0];p.working=false
		world.state.offline_guest=p
		world.state.players.erase("2")
	guest_peer=0;world.state.ready.erase("2");message.emit("협동 파트너가 나갔습니다. 캐릭터는 재접속 시 복원됩니다.")

func send(action: String,args: Dictionary={}) -> bool:
	sequence+=1
	if online and not multiplayer.is_server():
		if not connected:return false
		if action not in ["input","slot"]:pending_panel_sequence=sequence
		request.rpc_id(1,sequence,action,args);return true
	return execute("1",sequence,action,args)

@rpc("any_peer","call_remote","reliable")
func request(counter: int,action: String,args: Dictionary) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=guest_peer:return
	if args.size()>10 or counter<0:return
	execute("2",counter,action,args)

func execute(peer: String,counter: int,action: String,args: Dictionary) -> bool:
	if action=="ready" and world.state.phase=="prep":save(active_slot,true)
	var accepted=world.command(peer,counter,action,args)
	if world.feedback!="":
		if peer=="1":message.emit(world.feedback)
		elif guest_peer!=0:notice.rpc_id(guest_peer,world.feedback)
	if world.sound!="":effect.emit(world.sound)
	if accepted and action not in ["input","slot","fridge","interact","drop"]:
		changed.emit()
		if action not in ["ready","skill","close_fridge","recipe_select","retail_buy"]:save(active_slot)
	return accepted

@rpc("authority","call_remote","reliable")
func notice(text: String) -> void:message.emit(text)

func public_state() -> Dictionary:
	var s=world.state.duplicate(true)
	for city in s.stores:
		s.stores[city].retail_prices={}
		for ingredient in world.db.all("ingredients"):
			s.stores[city].retail_prices[ingredient.id]=world.unit_price(city,ingredient.id,true)
	s.erase("guest_token")
	for c in s.candidates.values():c.erase("traits");c.erase("satisfaction")
	# Unpurchased market variables stay host-only; UI uses report snapshots.
	s.erase("economies")
	return s

@rpc("authority","call_remote","reliable")
func snapshot(value: Dictionary) -> void:
	world.state=value
	if not connected:
		connected=true;sequence=int(value.transactions.get("2",0));changed.emit()
	elif pending_panel_sequence>0 and int(value.transactions.get("2",0))>=pending_panel_sequence:
		pending_panel_sequence=0;changed.emit()

func _process(delta: float) -> void:
	if world.state.is_empty() or not connected:return
	if authority():
		accumulator+=minf(delta,.25)
		while accumulator>=.05:world.step();accumulator-=.05
		if world.sound!="":effect.emit(world.sound);world.sound=""
		if autosave_phase!=world.state.phase:
			autosave_phase=world.state.phase
			if autosave_phase in ["prep","settlement"]:save(active_slot)
			changed.emit()
		if online and guest_peer!=0:
			network_clock+=delta
			if network_clock>=.15:network_clock=0;snapshot.rpc_id(guest_peer,public_state())

func save(slot: int,backup_only: bool=false) -> bool:
	if not authority() or world.state.is_empty():return false
	DirAccess.make_dir_recursive_absolute(save_root)
	var data=world.state.duplicate(true)
	data.rng=str(world.rng.state)
	var payload=JSON.stringify(data)
	var envelope=JSON.stringify({"format":2,"hash":payload.sha256_text(),"payload":payload})
	var path="%s/slot_%d%s.json"%[save_root,slot,"_before_day" if backup_only else ""]
	var temp=path+".tmp"
	var f=FileAccess.open(temp,FileAccess.WRITE)
	if f==null:message.emit("저장 실패: 파일을 열 수 없습니다.");return false
	f.store_string(envelope);f.flush();f.close()
	if read_save(temp).is_empty():return false
	if FileAccess.file_exists(path):
		var old=path+".bak"
		if FileAccess.file_exists(old):DirAccess.remove_absolute(old)
		if DirAccess.rename_absolute(path,old)!=OK:return false
	if DirAccess.rename_absolute(temp,path)!=OK:message.emit("저장 교체 실패 · 백업은 보존되었습니다.");return false
	return true

func read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not envelope is Dictionary:return {}
	var data
	if envelope.get("format",0)==2:
		if not envelope.get("payload","") is String:return {}
		if envelope.payload.sha256_text()!=envelope.get("hash",""):return {}
		data=JSON.parse_string(envelope.payload)
	elif envelope.get("version",0)==1:
		data=envelope;data.version=2;data.guest_token="";data.guest_character=-1;data.transactions={}
	else:return {}
	if not data is Dictionary or int(data.get("version",0))!=2:return {}
	for key in ["players","stores","cash","day","phase","staff","research","serial","economies"]:
		if not data.has(key):return {}
	if not data.players is Dictionary or not data.stores is Dictionary or data.stores.is_empty():return {}
	return data

func delete_slot(slot: int) -> bool:
	if slot<1 or slot>3 or (online and not multiplayer.is_server()):return false
	for suffix in [".json",".json.bak",".json.tmp","_before_day.json","_before_day.json.bak"]:
		var path="%s/slot_%d%s"%[save_root,slot,suffix]
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:return false
	return true

func load_slot(slot: int) -> bool:
	var path="%s/slot_%d.json"%[save_root,slot]
	var data=read_save(path)
	if data.is_empty():data=read_save(path+".bak")
	if data.is_empty():message.emit("유효한 새 버전 저장 파일이 없습니다.");return false
	stop_network();world.state=data;world.rng.state=int(data.rng);active_slot=slot;connected=true
	for peer in data.players:
		world.release_locks(peer);data.players[peer].input=[0,0];data.players[peer].working=false
	if data.players.has("2"):data.offline_guest=data.players["2"];data.players.erase("2")
	sequence=int(data.transactions.get("1",0));autosave_phase="";changed.emit();return true
