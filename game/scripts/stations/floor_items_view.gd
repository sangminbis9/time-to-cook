class_name FloorItemsView
extends Node2D
## 바닥 아이템 렌더러. GameServer 미러 신호를 구독해 스프라이트를 생성/제거.

const TILE: int = 32

var _sprites: Dictionary = {}  ## Vector2i → Sprite2D


func _ready() -> void:
	GameServer.floor_item_placed.connect(_on_placed)
	GameServer.floor_item_removed.connect(_on_removed)
	GameServer.snapshot_applied.connect(_rebuild)
	_rebuild()


func _on_placed(tile: Vector2i, iid: int) -> void:
	_on_removed(tile)
	var item: ItemInstance = GameServer.get_item(iid)
	if item == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = item.get_def().texture
	sprite.position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0 + 6.0)
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = load("res://assets/sprites/fx/shadow_oval.png")
	shadow.position = Vector2(0, 7)
	shadow.scale = Vector2(0.6, 0.5)
	shadow.show_behind_parent = true
	sprite.add_child(shadow)
	add_child(sprite)
	_sprites[tile] = sprite


func _on_removed(tile: Vector2i) -> void:
	var sprite: Sprite2D = _sprites.get(tile)
	if sprite != null:
		sprite.queue_free()
		_sprites.erase(tile)


func _rebuild() -> void:
	for tile: Vector2i in _sprites.keys():
		var sprite: Sprite2D = _sprites[tile]
		sprite.queue_free()
	_sprites.clear()
	for tile: Vector2i in GameServer.grid.floor_items.keys():
		_on_placed(tile, GameServer.grid.item_at(tile))
