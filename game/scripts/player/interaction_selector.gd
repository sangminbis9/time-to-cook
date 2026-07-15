class_name InteractionSelector
extends RefCounted
## 상호작용 대상 선택 (PLAN.md §14). 순수 로컬 — 네트워크 동기화 없음.
## 플레이어 주변 3×3 타일 중 가장 가까운 대상을 고르고,
## 거리가 같으면 바라보는 방향 타일을 우선한다.

enum TargetType { NONE, STATION, FLOOR_ITEM }

const TILE: int = 32
## 이 오차(픽셀) 이내면 같은 거리로 보고 바라보는 타일을 우선
const TIE_EPSILON: float = 1.0


## 반환: {"type": TargetType, "tile": Vector2i, "station_key": StringName}
static func pick(player_pos: Vector2, facing: Vector2i) -> Dictionary:
	var player_tile: Vector2i = Vector2i(
		floori(player_pos.x / TILE), floori(player_pos.y / TILE))
	var facing_tile: Vector2i = player_tile + facing
	var best: Dictionary = {"type": TargetType.NONE, "tile": Vector2i.MAX,
		"station_key": StringName()}
	var best_dist: float = INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tile: Vector2i = player_tile + Vector2i(dx, dy)
			var target: Dictionary = _target_at(tile)
			if target["type"] == TargetType.NONE:
				continue
			var center: Vector2 = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
			var dist: float = player_pos.distance_to(center)
			var better: bool = dist < best_dist - TIE_EPSILON \
				or (dist <= best_dist + TIE_EPSILON and tile == facing_tile)
			if better:
				best = target
				best_dist = dist
	return best


static func _target_at(tile: Vector2i) -> Dictionary:
	var key: StringName = GameServer.station_key_at(tile)
	if key != StringName():
		return {"type": TargetType.STATION, "tile": tile, "station_key": key}
	if GameServer.grid.item_at(tile) != 0:
		return {"type": TargetType.FLOOR_ITEM, "tile": tile,
			"station_key": StringName()}
	return {"type": TargetType.NONE, "tile": Vector2i.MAX,
		"station_key": StringName()}
