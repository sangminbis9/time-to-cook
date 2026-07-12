class_name InteractionSelector
extends RefCounted
## 상호작용 대상 선택 (PLAN.md §14). 순수 로컬 — 네트워크 동기화 없음.
## 우선순위: 1) 바라보는 방향 타일 2) 전방 대각 타일 3) 발밑 4) 나머지 인접 타일.

enum TargetType { NONE, STATION, FLOOR_ITEM }


## 반환: {"type": TargetType, "tile": Vector2i, "station_key": StringName}
static func pick(player_tile: Vector2i, facing: Vector2i) -> Dictionary:
	for tile: Vector2i in _candidate_tiles(player_tile, facing):
		var key: StringName = _station_at(tile)
		if key != StringName():
			return {"type": TargetType.STATION, "tile": tile, "station_key": key}
		if GameServer.grid.item_at(tile) != 0:
			return {"type": TargetType.FLOOR_ITEM, "tile": tile,
				"station_key": StringName()}
	return {"type": TargetType.NONE, "tile": Vector2i.MAX,
		"station_key": StringName()}


static func _candidate_tiles(player_tile: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var side: Vector2i = Vector2i(-facing.y, facing.x)
	var result: Array[Vector2i] = [
		player_tile + facing,          # 정면
		player_tile + facing + side,   # 전방 대각
		player_tile + facing - side,
		player_tile,                   # 발밑 (바닥 아이템)
		player_tile + side,            # 좌우
		player_tile - side,
	]
	return result


static func _station_at(tile: Vector2i) -> StringName:
	if GameServer.layout == null:
		return StringName()
	return GameServer.layout.station_at(tile)
