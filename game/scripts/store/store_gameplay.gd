extends Node2D
## 매장 플레이 씬. 레이아웃(ASCII)에서 타일·설비를 결정적으로 구축하고,
## 서버는 접속 피어마다 플레이어를 스폰한다.

const TILE: int = 32
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var layout: StoreLayout
## 로컬 플레이어가 마지막으로 본 도시 — 바뀌면 스폰 위치로 재배치 (독립 이동 §6)
var _seen_city: String = ""
## 정전(§23.1) 화면 어둡게 처리용 겸 기본 앰비언트
var _dimmer: CanvasModulate
## 평상시 앰비언트 — 살짝 낮춰 조명(PointLight2D)이 온기를 만들 여지를 준다
const AMBIENT: Color = Color(0.82, 0.79, 0.76)
## 천장 조명 (정전 시 소등)
var _lights: Array[PointLight2D] = []

@onready var _floor: TileMapLayer = $Floor
@onready var _walls: TileMapLayer = $Walls
@onready var _stations: Node2D = $World/Stations
@onready var _players: Node2D = $World/Players


func _ready() -> void:
	add_to_group("store_scene")  # 배치 모드 진입용 (매장 관리 UI에서 참조)
	GameServer.setup_store()
	layout = GameServer.layout
	_seen_city = GameServer.my_city()
	_build_tiles()
	_sync_station_views()
	_build_edit_mode()
	_dimmer = CanvasModulate.new()
	_dimmer.color = AMBIENT
	add_child(_dimmer)
	_build_lights()
	_build_vignette()
	GameServer.station_layout_changed.connect(_sync_station_views)
	GameServer.snapshot_applied.connect(_sync_station_views)
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
		var create_initial_save: bool = SceneRouter.pending_new_save
		SceneRouter.pending_new_save = false
		if SceneRouter.pending_load_slot > 0:
			var slot: int = SceneRouter.pending_load_slot
			SceneRouter.pending_load_slot = 0
			SaveService.load_game(slot)
		if GameServer.job_candidates.is_empty():
			GameServer.server_refresh_candidates()
		GameServer.server_ensure_peer(1)
		_spawn_player(1)
		if create_initial_save:
			# 캐릭터 프로필과 최초 매장 상태를 슬롯에 즉시 기록한다.
			SaveService.autosave()
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
	_floor.clear()
	_walls.clear()
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


## 설비 뷰를 내 매장의 현재 배치와 일치시킨다 (이동·구매·매장 전환 반영).
## 배치는 자주 바뀌지 않으므로 전체 재구축이 가장 단순하다.
func _sync_station_views() -> void:
	for child: Node in _stations.get_children():
		child.queue_free()
	var placements: Dictionary = GameServer.placements_view()
	for key: StringName in placements.keys():
		var entry: Dictionary = placements[key]
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


## 매장 이동(독립 이동) 반영: 내 도시가 바뀌면 도시 레이아웃으로 지형을
## 다시 그리고 스폰 위치로, 다른 도시의 플레이어는 숨긴다.
func _on_world_resync() -> void:
	var mine: String = GameServer.my_city()
	if mine != _seen_city:
		_seen_city = mine
		layout = GameServer.layout  # 도시별 레이아웃 (§6.6)
		_build_tiles()
		_rebuild_lights()
		var me: PlayerController = _players.get_node_or_null(
			str(multiplayer.get_unique_id())) as PlayerController
		if me != null:
			me.position = _spawn_pos(multiplayer.get_unique_id())
			me.refresh_camera_limits()
	_refresh_player_visibility()


func _refresh_player_visibility() -> void:
	var mine: String = GameServer.my_city()
	for child: Node in _players.get_children():
		(child as Node2D).visible = \
			GameServer.city_of_peer(int(String(child.name))) == mine


## 매장 크기가 바뀌면 조명 배치도 갱신
func _rebuild_lights() -> void:
	for light: PointLight2D in _lights:
		light.queue_free()
	_lights.clear()
	_build_lights()


## 천장 조명 — 매장 폭을 따라 따뜻한 광원을 고르게 배치
func _build_lights() -> void:
	var map_size: Vector2 = Vector2(layout.width, layout.height) * TILE
	var light_tex: Texture2D = load("res://assets/sprites/fx/light_radial.png")
	var spots: Array[Vector2] = [
		Vector2(map_size.x * 0.2, map_size.y * 0.3),
		Vector2(map_size.x * 0.5, map_size.y * 0.28),
		Vector2(map_size.x * 0.8, map_size.y * 0.3),
		Vector2(map_size.x * 0.32, map_size.y * 0.72),
		Vector2(map_size.x * 0.68, map_size.y * 0.72),
	]
	for spot: Vector2 in spots:
		var light: PointLight2D = PointLight2D.new()
		light.texture = light_tex
		light.color = Color(1.0, 0.92, 0.76)
		light.energy = 0.45
		light.texture_scale = 1.3
		light.position = spot
		add_child(light)
		_lights.append(light)


## 화면 가장자리를 살짝 어둡게 — HUD(레이어 1)보다 아래에 그린다
func _build_vignette() -> void:
	var vignette_layer: CanvasLayer = CanvasLayer.new()
	vignette_layer.layer = 0
	add_child(vignette_layer)
	var rect: TextureRect = TextureRect.new()
	rect.texture = load("res://assets/sprites/fx/vignette.png")
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_layer.add_child(rect)


## 정전이면 화면을 어둡게 + 조명 소등 (HUD는 CanvasLayer라 영향 없음)
func _refresh_event_fx() -> void:
	var blackout: bool = String(GameServer.current_store_event().get(
		"type", "")) == "blackout"
	_dimmer.color = Color(0.4, 0.4, 0.55) if blackout else AMBIENT
	for light: PointLight2D in _lights:
		light.enabled = not blackout


# ── 설비 배치 모드 (§15 — 준비 단계, 매장 관리 UI에서 진입) ─────────
## 마우스로 대상 타일을 고른다. 좌클릭 배치, Esc/우클릭 취소.

var _edit_move_key: StringName = StringName()  # 이동 대상 (빈 값이면 구매)
var _edit_buy_def: StringName = StringName()   # 구매 대상 def_id
var _edit_cursor: Sprite2D
var _edit_hint: Label


func _build_edit_mode() -> void:
	_edit_cursor = Sprite2D.new()
	_edit_cursor.texture = load("res://assets/sprites/highlight_ring.png")
	_edit_cursor.visible = false
	add_child(_edit_cursor)
	var hint_layer: CanvasLayer = CanvasLayer.new()
	add_child(hint_layer)
	_edit_hint = Label.new()
	_edit_hint.anchor_left = 0.5
	_edit_hint.anchor_right = 0.5
	_edit_hint.offset_left = -160.0
	_edit_hint.offset_right = 160.0
	_edit_hint.offset_top = 40.0
	_edit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit_hint.add_theme_font_size_override("font_size", 11)
	_edit_hint.add_theme_color_override("font_color", Color(0.35, 0.27, 0.2))
	_edit_hint.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.85))
	_edit_hint.add_theme_constant_override("outline_size", 2)
	_edit_hint.visible = false
	hint_layer.add_child(_edit_hint)


func edit_active() -> bool:
	return _edit_move_key != StringName() or _edit_buy_def != StringName()


func begin_move_station(key: StringName) -> void:
	_edit_move_key = key
	_edit_buy_def = StringName()
	var def: StationDef = Defs.get_def(
		GameServer.placements_view()[key]["def_id"]) as StationDef
	_start_edit("%s 이동 — 클릭: 배치 · Esc: 취소" % def.display_name_ko)


func begin_buy_station(def_id: StringName) -> void:
	_edit_buy_def = def_id
	_edit_move_key = StringName()
	var def: StationDef = Defs.get_def(def_id) as StationDef
	_start_edit("%s 구매 — 클릭: 배치 · Esc: 취소" % def.display_name_ko)


func _start_edit(hint: String) -> void:
	_edit_hint.text = hint
	_edit_hint.visible = true
	_edit_cursor.visible = true


func _cancel_edit() -> void:
	_edit_move_key = StringName()
	_edit_buy_def = StringName()
	_edit_cursor.visible = false
	_edit_hint.visible = false


func _process(_delta: float) -> void:
	if not edit_active():
		return
	if GameClock.phase != GameClock.Phase.PREP:
		_cancel_edit()
		return
	var tile: Vector2i = _mouse_tile()
	_edit_cursor.position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	_edit_cursor.modulate = Color(0.5, 1.0, 0.5) \
		if GameServer.grid.can_place_item(tile) else Color(1.0, 0.45, 0.45)


func _mouse_tile() -> Vector2i:
	var pos: Vector2 = get_global_mouse_position()
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func _unhandled_input(event: InputEvent) -> void:
	if not edit_active():
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_edit()
		get_viewport().set_input_as_handled()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_edit()
	elif click.button_index == MOUSE_BUTTON_LEFT:
		var tile: Vector2i = _mouse_tile()
		if _edit_move_key != StringName():
			GameServer.request_move_station.rpc_id(1, _edit_move_key, tile)
		else:
			GameServer.request_buy_station.rpc_id(1, _edit_buy_def, tile)
		_cancel_edit()
	get_viewport().set_input_as_handled()
