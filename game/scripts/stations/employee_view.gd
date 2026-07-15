class_name EmployeeView
extends Node2D
## 직원 렌더러. 서버가 전이 시점마다 보내는 상태(출발/도착 타일, 이동 시간)를
## 로컬에서 보간해 그린다 — 매 프레임 위치 동기화 없음.

const TILE: int = 32

var eid: int = 0

var _sprite: Sprite2D
var _item_sprite: Sprite2D
var _move_elapsed: float = 0.0
var _last_from: Vector2i
var _last_to: Vector2i


func setup(p_eid: int) -> void:
	eid = p_eid
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/player_mint.png")
	_sprite.hframes = 8
	_sprite.modulate = Color(0.85, 0.85, 0.95)  # 직원 구분 톤
	_sprite.position = Vector2(0, -8)  # 확대해도 발 위치 유지
	_sprite.scale = Vector2(1.5, 1.5)
	add_child(_sprite)
	_item_sprite = Sprite2D.new()
	_item_sprite.position = Vector2(0, -34)
	_item_sprite.visible = false
	add_child(_item_sprite)
	GameServer.employee_changed.connect(_on_changed)
	_on_changed(eid)


func _on_changed(changed_eid: int) -> void:
	if changed_eid != eid:
		return
	var emp: EmployeeState = GameServer.employees.get(eid)
	if emp == null:
		queue_free()
		return
	if emp.tile_from != _last_from or emp.tile_to != _last_to:
		_last_from = emp.tile_from
		_last_to = emp.tile_to
		_move_elapsed = 0.0
	var item: ItemInstance = GameServer.get_item(emp.carrying_iid)
	_item_sprite.visible = item != null
	if item != null:
		_item_sprite.texture = item.get_def().texture


func _process(delta: float) -> void:
	var emp: EmployeeState = GameServer.employees.get(eid)
	if emp == null:
		return
	var from: Vector2 = Vector2(emp.tile_from * TILE) + Vector2(16, 16)
	var to: Vector2 = Vector2(emp.tile_to * TILE) + Vector2(16, 16)
	if emp.move_duration <= 0.0 or from == to:
		position = to
	else:
		if GameClock.phase == GameClock.Phase.SERVICE:
			_move_elapsed = minf(_move_elapsed + delta, emp.move_duration)
		position = from.lerp(to, _move_elapsed / emp.move_duration)
	# 이동 방향 프레임 (간단히: 이동 중 아래 보기 걷기, 정지 시 정면)
	var moving: bool = position.distance_to(to) > 0.5
	_sprite.frame = (int(Time.get_ticks_msec() / 200.0) % 2) if moving else 0
