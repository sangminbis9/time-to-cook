extends Node2D
## 매장 플레이 씬. 레이아웃(ASCII)에서 타일·설비를 결정적으로 구축하고,
## 서버는 접속 피어마다 플레이어를 스폰한다.

const TILE: int = 32
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var layout: StoreLayout
## 로컬 플레이어가 마지막으로 본 도시 — 바뀌면 스폰 위치로 재배치 (독립 이동 §6)
var _seen_city: String = ""
## 정전(§23.1) 화면 어둡게 처리용
var _dimmer: CanvasModulate

@onready var _floor: TileMapLayer = $Floor
@onready var _walls: TileMapLayer = $Walls
@onready var _stations: Node2D = $World/Stations
@onready var _players: Node2D = $World/Players


func _ready() -> void:
	layout = StoreLayout.incheon()
	GameServer.setup_store(layout)
	_seen_city = GameServer.my_city()
	_build_tiles()
	_build_stations()
	_dimmer = CanvasModulate.new()
	_dimmer.color = Color.WHITE
	add_child(_dimmer)
	GameServer.employee_changed.connect(_on_employee_changed)
	GameServer.snapshot_applied.connect(_sync_employee_views)
	GameServer.snapshot_applied.connect(_on_world_resync)
	GameServer.store_event_changed.connect(_refresh_event_fx)
	GameServer.snapshot_applied.connect(_refresh_event_fx)
	GameServer.peer_city_changed.connect(
		func(_peer: int) -> void: _refresh_player_visibility())
	_players.child_entered_tree.connect(
		func(_node: Node) -> void: _refresh_player_visibility.call_deferred())
	_sync_employee_views()
	if multiplayer.is_server():
		if SceneRouter.pending_load_slot > 0:
			var slot: int = SceneRouter.pending_load_slot
			SceneRouter.pending_load_slot = 0
			SaveService.load_game(slot)
		if GameServer.job_candidates.is_empty():
			GameServer.server_refresh_candidates()
		GameServer.server_ensure_peer(1)
		_spawn_player(1)
		# 이미 핸드셰이크를 마친 게스트 + 이후 준비되는 게스트
		for peer: int in GameServer.client_ready_peers.keys():
			_spawn_player(peer)
		GameServer.peer_became_ready.connect(_spawn_player)
		NetworkService.peer_left.connect(_on_peer_left)
	else:
		# 호스트 퇴장 시 세션 종료 → 타이틀로 (§4.2)
		NetworkService.session_ended.connect(func(reason: String) -> void:
			SceneRouter.to_title("호스트가 나갔습니다" \
				if reason == "host_left" else reason))
		# 씬 로드 완료를 서버에 알림 — 이후에야 스폰·스냅샷을 받는다
		GameServer.client_ready.rpc_id(1)


func _build_tiles() -> void:
	for tile: Vector2i in layout.walkable.keys():
		var source: int = 0 if (tile.x + tile.y) % 2 == 0 else 1
		_floor.set_cell(tile, source, Vector2i.ZERO)
	for tile: Vector2i in layout.stations.values().map(
			func(entry: Dictionary) -> Vector2i: return entry["tile"]):
		# 설비 발밑에도 바닥을 깐다
		_floor.set_cell(tile, 0, Vector2i.ZERO)
	for tile: Vector2i in layout.walls.keys():
		var below: Vector2i = tile + Vector2i(0, 1)
		var face: bool = layout.walkable.has(below) \
			or layout.station_tiles().has(below)
		_walls.set_cell(tile, 3 if face else 2, Vector2i.ZERO)


func _on_employee_changed(eid: int) -> void:
	var container: Node2D = $World/Employees
	if container.get_node_or_null(str(eid)) != null:
		return
	if not GameServer.employees.has(eid):
		return
	var view: EmployeeView = EmployeeView.new()
	view.name = str(eid)
	container.add_child(view)
	view.setup(eid)


## 스냅샷/매장 전환 후 직원 뷰를 현재 목록과 일치시킨다 (없는 직원 뷰 제거)
func _sync_employee_views() -> void:
	var container: Node2D = $World/Employees
	for child: Node in container.get_children():
		if not GameServer.employees.has(int(String(child.name))):
			child.queue_free()
	for eid: int in GameServer.employees.keys():
		_on_employee_changed(eid)


func _build_stations() -> void:
	for key: StringName in layout.stations.keys():
		var entry: Dictionary = layout.stations[key]
		var def: StationDef = Defs.get_def(entry["def_id"]) as StationDef
		var view: StationView = StationView.new()
		_stations.add_child(view)
		view.setup(key, def, entry["tile"])


func _on_peer_left(peer_id: int) -> void:
	var node: Node = _players.get_node_or_null(str(peer_id))
	if node != null:
		node.queue_free()


func _spawn_player(peer_id: int) -> void:
	if _players.get_node_or_null(str(peer_id)) != null:
		return
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.name = str(peer_id)
	player.position = _spawn_pos(peer_id)
	_players.add_child(player, true)
	_refresh_player_visibility()


func _spawn_pos(peer_id: int) -> Vector2:
	var order: int = 1 if peer_id == 1 else 2
	var spawn_tile: Vector2i = layout.spawn_tiles.get(order, Vector2i(9, 4))
	return Vector2(spawn_tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)


## 매장 이동(독립 이동) 반영: 내 도시가 바뀌면 스폰 위치로, 다른 도시의
## 플레이어는 숨긴다 (같은 씬 노드를 공유하되 각자 자기 매장만 그린다).
func _on_world_resync() -> void:
	var mine: String = GameServer.my_city()
	if mine != _seen_city:
		_seen_city = mine
		var me: Node2D = _players.get_node_or_null(
			str(multiplayer.get_unique_id())) as Node2D
		if me != null:
			me.position = _spawn_pos(multiplayer.get_unique_id())
	_refresh_player_visibility()


func _refresh_player_visibility() -> void:
	var mine: String = GameServer.my_city()
	for child: Node in _players.get_children():
		(child as Node2D).visible = \
			GameServer.city_of_peer(int(String(child.name))) == mine


## 정전이면 화면을 어둡게 (HUD는 CanvasLayer라 영향 없음)
func _refresh_event_fx() -> void:
	var blackout: bool = String(GameServer.current_store_event().get(
		"type", "")) == "blackout"
	_dimmer.color = Color(0.4, 0.4, 0.55) if blackout else Color.WHITE
