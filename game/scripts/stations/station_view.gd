class_name StationView
extends Node2D
## 설비 렌더러. 상태는 GameServer 미러가 원본 — 이 노드는 순수 표현.
## 설비 스프라이트 + 위에 놓인 아이템 + 진행 바를 그린다.

const TILE: int = 32

var station_key: StringName

var _def: StationDef
var _sprite: Sprite2D
var _item_sprite: Sprite2D
var _progress: TextureProgressBar
var _glow: PointLight2D


func setup(key: StringName, def: StationDef, tile: Vector2i) -> void:
	station_key = key
	_def = def
	position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = load("res://assets/sprites/fx/shadow_oval.png")
	shadow.position = Vector2(0, 15)
	shadow.scale = Vector2(1.5, 1.1)
	add_child(shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = def.texture
	add_child(_sprite)

	if def.kind == StationDef.Kind.FRYER:
		# 조리 설비의 은은한 온기 (정전 시 소등)
		_glow = PointLight2D.new()
		_glow.texture = load("res://assets/sprites/fx/light_radial.png")
		_glow.color = Color(1.0, 0.78, 0.5)
		_glow.energy = 0.5
		_glow.texture_scale = 0.35
		_glow.position = Vector2(0, -4)
		add_child(_glow)

	_item_sprite = Sprite2D.new()
	_item_sprite.position = Vector2(0, -6)
	_item_sprite.visible = false
	add_child(_item_sprite)

	_progress = TextureProgressBar.new()
	_progress.custom_minimum_size = Vector2(24, 4)
	_progress.position = Vector2(-12, -22)
	_progress.size = Vector2(24, 4)
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.nine_patch_stretch = true
	_progress.visible = false
	add_child(_progress)

	GameServer.station_changed.connect(_on_station_changed)
	GameServer.item_updated.connect(func(_iid: int) -> void: _refresh())
	GameServer.snapshot_applied.connect(_refresh)
	GameServer.store_event_changed.connect(_refresh)
	_refresh()


func _on_station_changed(key: StringName) -> void:
	if key == station_key:
		_refresh()


## 클라이언트 표시용 보간 조리 시간 — 서버는 상태 경계에서만 동기화하므로
## 그 사이에는 로컬 시계로 진행을 추정한다 (§24 설계)
var _render_elapsed: float = 0.0
var _render_iid: int = 0


func _process(delta: float) -> void:
	if _def == null or _def.kind != StationDef.Kind.FRYER:
		return
	var st: StationState = GameServer.station(station_key)
	if st != null and st.item_iid != 0:
		var item: ItemInstance = GameServer.get_item(st.item_iid)
		if item != null:
			if st.item_iid != _render_iid:
				# 새 아이템 — 보간 시계 재시작 (재투입 시 이어짐 포함)
				_render_iid = st.item_iid
				_render_elapsed = item.cook_elapsed
			elif GameClock.phase == GameClock.Phase.SERVICE \
					and String(GameServer.current_store_event().get(
						"type", "")) != "blackout":
				# 서버 동기화 값이 더 크면 스냅, 아니면 로컬 진행 (정전 중 정지)
				_render_elapsed = maxf(_render_elapsed + delta, item.cook_elapsed)
	else:
		_render_iid = 0
	_update_fryer_bar()


func _refresh() -> void:
	# 이벤트 대상 설비 표시 (§23.1): 화재=붉게, 누수=푸르게, 미끄러움=청록
	var event: Dictionary = GameServer.current_store_event()
	var etype: String = String(event.get("type", ""))
	var is_target: bool = String(event.get("station", "")) == String(station_key)
	if is_target and etype == "fire":
		_sprite.modulate = Color(1.7, 0.65, 0.45)
	elif is_target and etype == "leak":
		_sprite.modulate = Color(0.6, 0.8, 1.6)
	elif is_target and etype == "slippery":
		_sprite.modulate = Color(0.7, 1.3, 1.1)
	else:
		_sprite.modulate = Color.WHITE
	if _glow != null:
		_glow.enabled = String(event.get("type", "")) != "blackout"
	var st: StationState = GameServer.station(station_key)
	if st == null or st.is_empty():
		_item_sprite.visible = false
		_progress.visible = false
		return
	var item: ItemInstance = GameServer.get_item(st.item_iid)
	if item == null:
		_item_sprite.visible = false
		return
	_item_sprite.texture = item.get_def().texture
	_item_sprite.visible = true
	if _def.kind == StationDef.Kind.CUTTING_BOARD and _def.required_cuts > 0:
		_progress.value = CutProgress.progress01(item, _def)
		_progress.visible = _progress.value < 1.0


func _update_fryer_bar() -> void:
	var st: StationState = GameServer.station(station_key)
	if st == null or st.is_empty():
		_progress.visible = false
		_render_elapsed = 0.0
		return
	var item: ItemInstance = GameServer.get_item(st.item_iid)
	if item == null:
		_progress.visible = false
		return
	_progress.visible = true
	_progress.value = clampf(_render_elapsed / _def.burn_after_seconds, 0.0, 1.0)
	var state: CookStateMachine.State = CookStateMachine.state_for(
		_render_elapsed, _def)
	match state:
		CookStateMachine.State.UNDERDONE:
			_progress.modulate = Color(0.64, 0.8, 0.91)   # 하늘색
		CookStateMachine.State.NORMAL:
			_progress.modulate = Color(0.5, 0.75, 0.62)   # 민트
		CookStateMachine.State.OVERCOOKED:
			_progress.modulate = Color(0.91, 0.64, 0.4)   # 살구
		CookStateMachine.State.BURNT:
			_progress.modulate = Color(0.42, 0.34, 0.26)  # 탄색
