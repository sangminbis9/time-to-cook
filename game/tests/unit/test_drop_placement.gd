extends GutTest
## Q 내려놓기 배치 우선순위 (PLAN.md §16.2, §32.1).

var grid: GridState


func before_each() -> void:
	grid = GridState.new()
	# 5×5 바닥
	for y in range(5):
		for x in range(5):
			grid.walkable[Vector2i(x, y)] = true


func test_priority_front_first() -> void:
	var spot: Vector2i = DropPlacement.find_spot(grid, Vector2i(2, 2), Vector2i(1, 0))
	assert_eq(spot, Vector2i(3, 2), "1순위: 바라보는 앞 칸")


func test_priority_own_tile_second() -> void:
	grid.floor_items[Vector2i(3, 2)] = 99
	var spot: Vector2i = DropPlacement.find_spot(grid, Vector2i(2, 2), Vector2i(1, 0))
	assert_eq(spot, Vector2i(2, 2), "2순위: 서 있는 칸")


func test_priority_3x3_third() -> void:
	grid.floor_items[Vector2i(3, 2)] = 99
	grid.floor_items[Vector2i(2, 2)] = 98
	var spot: Vector2i = DropPlacement.find_spot(grid, Vector2i(2, 2), Vector2i(1, 0))
	assert_eq(spot, Vector2i(1, 1), "3순위: 3×3 행 우선 첫 유효 칸")


func test_blocked_and_wall_excluded() -> void:
	grid.blocked[Vector2i(3, 2)] = true          # 설비
	grid.walkable.erase(Vector2i(2, 2))          # 벽/불가 타일
	var spot: Vector2i = DropPlacement.find_spot(grid, Vector2i(2, 2), Vector2i(1, 0))
	assert_eq(spot, Vector2i(1, 1))


func test_all_blocked_fails() -> void:
	for y in range(5):
		for x in range(5):
			grid.blocked[Vector2i(x, y)] = true
	var spot: Vector2i = DropPlacement.find_spot(grid, Vector2i(2, 2), Vector2i(1, 0))
	assert_eq(spot, Vector2i.MAX, "모든 후보 실패 시 아이템은 인벤토리 유지")


func test_one_item_per_tile() -> void:
	assert_true(grid.place(Vector2i(1, 1), 10))
	assert_false(grid.place(Vector2i(1, 1), 11), "같은 칸 중첩 불가")
	assert_eq(grid.item_at(Vector2i(1, 1)), 10)


func test_grid_items_roundtrip() -> void:
	grid.place(Vector2i(1, 1), 10)
	grid.place(Vector2i(4, 0), 20)
	var restored: GridState = GridState.new()
	restored.load_items(grid.to_dict())
	assert_eq(restored.item_at(Vector2i(1, 1)), 10)
	assert_eq(restored.item_at(Vector2i(4, 0)), 20)
	assert_eq(restored.floor_items.size(), 2)
