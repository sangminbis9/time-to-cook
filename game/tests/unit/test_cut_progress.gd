extends GutTest
## 칼질 진행 (PLAN.md §19.3): 진행도는 아이템 귀속, 입력 합산, 이어서 가능.

var board: StationDef


func before_each() -> void:
	board = Defs.get_def(&"station.cutting_board") as StationDef


func test_accumulates_to_completion() -> void:
	var item: ItemInstance = ItemInstance.create(1, &"item.raw_chicken")
	for i in range(board.required_cuts - 1):
		assert_false(CutProgress.add_cut(item, board), "%d번째는 미완" % (i + 1))
	assert_true(CutProgress.add_cut(item, board), "필요 횟수 도달 시 완성")


func test_two_players_inputs_sum() -> void:
	# 플레이어 구분 없이 add_cut 호출이 합산된다 — 협력 페널티 없음
	var item: ItemInstance = ItemInstance.create(1, &"item.raw_chicken")
	CutProgress.add_cut(item, board)  # P1
	CutProgress.add_cut(item, board)  # P2
	CutProgress.add_cut(item, board)  # P1
	assert_eq(item.cuts_done, 3)


func test_progress_persists_on_item() -> void:
	var item: ItemInstance = ItemInstance.create(1, &"item.raw_chicken")
	CutProgress.add_cut(item, board)
	CutProgress.add_cut(item, board)
	# 아이템을 옮겼다가 다시 도마에 놓아도 (직렬화 왕복) 진행도 유지
	var moved: ItemInstance = ItemInstance.from_dict(item.to_dict())
	assert_eq(moved.cuts_done, 2)
	assert_false(CutProgress.is_complete(moved, board))


func test_progress01() -> void:
	var item: ItemInstance = ItemInstance.create(1, &"item.raw_chicken")
	assert_eq(CutProgress.progress01(item, board), 0.0)
	for i in range(board.required_cuts):
		CutProgress.add_cut(item, board)
	assert_eq(CutProgress.progress01(item, board), 1.0)
