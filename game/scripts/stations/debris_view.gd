class_name DebrisView
extends Node2D
## 통로 막힘(§23.1) 잔해 렌더러: 이벤트 타일에 잔해 더미를 표시한다.

const TILE: int = 32

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/item_burnt_food.png")
	_sprite.modulate = Color(0.55, 0.5, 0.45)
	_sprite.scale = Vector2(1.4, 1.4)
	_sprite.visible = false
	add_child(_sprite)
	GameServer.store_event_changed.connect(_refresh)
	GameServer.snapshot_applied.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var event: Dictionary = GameServer.current_store_event()
	if String(event.get("type", "")) != "debris":
		_sprite.visible = false
		return
	var tile: Vector2i = event.get("tile", Vector2i.MAX)
	_sprite.position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	_sprite.visible = true
