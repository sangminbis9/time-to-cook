class_name GridState
extends RefCounted
## 매장 그리드의 바닥 아이템 점유 상태 (PLAN.md §16).
## 걷기 가능 타일과 차단 타일은 매장 씬이 로드될 때 주입된다.
## 바닥 타일 하나당 아이템 1개.

## Vector2i → true. 아이템을 놓을 수 있는 바닥 타일.
var walkable: Dictionary = {}
## Vector2i → true. 설비·가구가 점유한 타일 (바닥이라도 배치 불가).
var blocked: Dictionary = {}
## Vector2i → iid. 바닥에 놓인 아이템.
var floor_items: Dictionary = {}


func can_place_item(tile: Vector2i) -> bool:
	return walkable.has(tile) and not blocked.has(tile) and not floor_items.has(tile)


func place(tile: Vector2i, iid: int) -> bool:
	if not can_place_item(tile):
		return false
	floor_items[tile] = iid
	return true


func item_at(tile: Vector2i) -> int:
	return int(floor_items.get(tile, 0))


func remove(tile: Vector2i) -> int:
	var iid: int = item_at(tile)
	floor_items.erase(tile)
	return iid


func clear_items() -> Array[int]:
	var iids: Array[int] = []
	for tile: Vector2i in floor_items.keys():
		iids.append(int(floor_items[tile]))
	floor_items.clear()
	return iids


func to_dict() -> Dictionary:
	# 타일 키는 JSON 호환을 위해 "x,y" 문자열로 저장.
	var items: Dictionary = {}
	for tile: Vector2i in floor_items.keys():
		items["%d,%d" % [tile.x, tile.y]] = int(floor_items[tile])
	return {"floor_items": items}


func load_items(data: Dictionary) -> void:
	floor_items.clear()
	var items: Dictionary = data.get("floor_items", {})
	for key: String in items.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue
		var tile: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		floor_items[tile] = int(items[key])
