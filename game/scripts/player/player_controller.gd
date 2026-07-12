class_name PlayerController
extends Node2D
## 플레이어 캐릭터. 이동·입력은 소유 피어 로컬 권한,
## 위치/방향/프레임만 MultiplayerSynchronizer로 복제된다.
## 게임플레이 상호작용은 전부 GameServer 의도 RPC로 보낸다.

const TILE: int = 32
const SPEED: float = 96.0
const ANIM_STEP_SECONDS: float = 0.18
## 발 판정 박스 모서리 (스프라이트 중심 기준)
const FOOT_CORNERS: Array[Vector2] = [
	Vector2(-6, 4), Vector2(6, 4), Vector2(-6, 14), Vector2(6, 14),
]
const DIR_INDEX: Dictionary = {
	Vector2i(0, 1): 0, Vector2i(0, -1): 1,
	Vector2i(-1, 0): 2, Vector2i(1, 0): 3,
}

## 동기화 대상 (SceneReplicationConfig에서 참조)
var facing: Vector2i = Vector2i(0, 1)
var anim_frame: int = 0

var _step: int = 0
var _step_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _camera: Camera2D = $Camera
@onready var _prompt: Label = $Prompt
@onready var _highlight: Sprite2D = $Highlight


func _enter_tree() -> void:
	# 노드 이름 = 소유 피어 ID (스포너 규약)
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	_camera.enabled = is_multiplayer_authority()
	_prompt.visible = false
	_highlight.visible = false
	if peer_id() != 1:
		_sprite.texture = load("res://assets/sprites/player_apricot.png")


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and not _modal_open():
		_process_movement(delta)
		_process_targeting()
	_sprite.frame = anim_frame


## 냉장고 등 모달 UI가 열려 있으면 이동·조리 입력 제한 (§17.4 — 로컬만)
func _modal_open() -> bool:
	return get_tree().get_first_node_in_group("modal_ui") != null


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or _modal_open():
		return
	if event.is_action_pressed("interact"):
		_on_interact()
	elif event.is_action_pressed("cook"):
		_on_cook()
	elif event.is_action_pressed("drop"):
		GameServer.request_drop.rpc_id(1, tile_pos(), facing)
	elif event.is_action_pressed("ready_toggle"):
		GameServer.request_ready_toggle.rpc_id(1)
	elif event.is_action_pressed("slot_1"):
		GameServer.request_select_slot.rpc_id(1, 0)
	elif event.is_action_pressed("slot_2"):
		GameServer.request_select_slot.rpc_id(1, 1)
	elif event.is_action_pressed("slot_3"):
		GameServer.request_select_slot.rpc_id(1, 2)
	elif event.is_action_pressed("slot_next"):
		var inv: InventoryState = GameServer.inventory_of(peer_id())
		if inv != null:
			GameServer.request_select_slot.rpc_id(1, (inv.selected + 1) % inv.unlocked)
	elif event.is_action_pressed("slot_prev"):
		var inv: InventoryState = GameServer.inventory_of(peer_id())
		if inv != null:
			GameServer.request_select_slot.rpc_id(1,
				(inv.selected - 1 + inv.unlocked) % inv.unlocked)


func peer_id() -> int:
	return str(name).to_int()


func tile_pos() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


# ── 이동 (그리드 충돌; 물리 엔진 미사용) ────────────────────────────

func _process_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		var motion: Vector2 = input_dir.normalized() * SPEED * delta
		_try_move(Vector2(motion.x, 0))
		_try_move(Vector2(0, motion.y))
		_update_facing(input_dir)
		_step_timer += delta
		if _step_timer >= ANIM_STEP_SECONDS:
			_step_timer = 0.0
			_step = 1 - _step
	else:
		_step = 0
		_step_timer = 0.0
	anim_frame = DIR_INDEX[facing] * 2 + _step


func _try_move(motion: Vector2) -> void:
	var target: Vector2 = position + motion
	if _can_stand(target):
		position = target


func _can_stand(pos: Vector2) -> bool:
	for corner: Vector2 in FOOT_CORNERS:
		var world: Vector2 = pos + corner
		var tile: Vector2i = Vector2i(floori(world.x / TILE), floori(world.y / TILE))
		if not GameServer.grid.walkable.has(tile):
			return false
		if GameServer.grid.blocked.has(tile):
			return false
	return true


func _update_facing(input_dir: Vector2) -> void:
	if absf(input_dir.x) >= absf(input_dir.y):
		facing = Vector2i(1, 0) if input_dir.x > 0 else Vector2i(-1, 0)
	else:
		facing = Vector2i(0, 1) if input_dir.y > 0 else Vector2i(0, -1)


# ── 대상 선택·하이라이트·안내 (로컬 전용, §14/§24.3) ────────────────

func _process_targeting() -> void:
	var target: Dictionary = InteractionSelector.pick(tile_pos(), facing)
	var target_type: InteractionSelector.TargetType = target["type"]
	if target_type == InteractionSelector.TargetType.NONE:
		_highlight.visible = false
		_prompt.visible = false
		return
	var tile: Vector2i = target["tile"]
	_highlight.visible = true
	_highlight.global_position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	_prompt.visible = true
	_prompt.text = _prompt_for(target)


## §14.2: 우선순위 높은 행동 하나만. 세부 문구 없이 고정 안내.
func _prompt_for(target: Dictionary) -> String:
	var target_type: InteractionSelector.TargetType = target["type"]
	if target_type == InteractionSelector.TargetType.FLOOR_ITEM:
		return "J: 상호작용"
	var st: StationState = GameServer.station(target["station_key"])
	if st == null or st.is_empty():
		return "J: 상호작용"
	var def: StationDef = st.get_def()
	var item: ItemInstance = GameServer.get_item(st.item_iid)
	if item != null:
		if def.kind == StationDef.Kind.CUTTING_BOARD \
				and not CutProgress.is_complete(item, def):
			return "K: 조리"
		if def.kind == StationDef.Kind.BREADING_TABLE \
				and def.work_output.has(item.def_id):
			return "K: 조리"
	return "J: 상호작용"


func _on_interact() -> void:
	var target: Dictionary = InteractionSelector.pick(tile_pos(), facing)
	var target_type: InteractionSelector.TargetType = target["type"]
	match target_type:
		InteractionSelector.TargetType.FLOOR_ITEM:
			GameServer.request_pickup.rpc_id(1, target["tile"], tile_pos())
		InteractionSelector.TargetType.STATION:
			GameServer.request_station_interact.rpc_id(
				1, target["station_key"], tile_pos())
		_:
			pass


func _on_cook() -> void:
	var target: Dictionary = InteractionSelector.pick(tile_pos(), facing)
	var target_type: InteractionSelector.TargetType = target["type"]
	if target_type == InteractionSelector.TargetType.STATION:
		GameServer.request_station_work.rpc_id(1, target["station_key"], tile_pos())
