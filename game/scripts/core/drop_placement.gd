class_name DropPlacement
extends RefCounted
## Q 내려놓기 배치 우선순위 (PLAN.md §16.2).
## 1) 바라보는 방향 바로 앞 한 칸
## 2) 플레이어가 서 있는 바로 밑 칸
## 3) 플레이어 중심 3×3 범위의 다른 유효 칸 (행 우선 결정적 순서)
## 모든 후보가 막히면 실패 — 아이템은 인벤토리에 유지.


static func candidates(player_tile: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var front: Vector2i = player_tile + facing
	result.append(front)
	result.append(player_tile)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tile: Vector2i = player_tile + Vector2i(dx, dy)
			if tile == front or tile == player_tile:
				continue
			result.append(tile)
	return result


## grid에서 배치 가능한 첫 후보를 반환. 없으면 Vector2i.MAX.
static func find_spot(grid: GridState, player_tile: Vector2i, facing: Vector2i) -> Vector2i:
	for tile: Vector2i in candidates(player_tile, facing):
		if grid.can_place_item(tile):
			return tile
	return Vector2i.MAX
