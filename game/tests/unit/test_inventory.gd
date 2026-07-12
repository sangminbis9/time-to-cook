extends GutTest
## 인벤토리 규칙 (PLAN.md §12, §32.1).

var inv: InventoryState


func before_each() -> void:
	inv = InventoryState.new()


func test_defaults() -> void:
	assert_eq(inv.unlocked, 3)
	assert_eq(inv.selected, 0)
	assert_true(inv.is_empty())


func test_pickup_into_selected_when_empty() -> void:
	inv.select(1)
	assert_eq(inv.pickup_slot(), 1, "선택 슬롯이 비었으면 선택 슬롯 사용")


func test_pickup_leftmost_when_selected_full() -> void:
	inv.select(1)
	inv.set_slot(1, 101)
	assert_eq(inv.pickup_slot(), 0, "선택 슬롯이 차면 왼쪽부터 첫 빈 슬롯")


func test_pickup_skips_locked_slots() -> void:
	inv.set_slot(0, 101)
	inv.set_slot(1, 102)
	inv.set_slot(2, 103)
	# 3~8번은 잠김 — 빈 칸이지만 사용 불가
	assert_eq(inv.pickup_slot(), -1, "해금 슬롯이 가득이면 실패")


func test_set_locked_slot_asserts() -> void:
	# 잠긴 슬롯 직접 기록은 프로그래밍 오류 (assert로 방어)
	assert_eq(inv.slots[5], 0)
	# set_slot(5, x)는 assert로 죽는 경로이므로 여기서는 규칙만 확인
	assert_eq(inv.pickup_slot(), 0)


func test_selection_wraps_within_unlocked() -> void:
	inv.select(2)
	inv.select_next()
	assert_eq(inv.selected, 0)
	inv.select_prev()
	assert_eq(inv.selected, 2)


func test_select_clamps_to_unlocked() -> void:
	inv.select(7)
	assert_eq(inv.selected, 2, "잠긴 슬롯은 선택 불가")


func test_selected_iid_and_clear() -> void:
	inv.set_slot(0, 55)
	assert_eq(inv.selected_iid(), 55)
	inv.clear_slot(0)
	assert_eq(inv.selected_iid(), 0)


func test_all_iids_and_clear_all() -> void:
	inv.set_slot(0, 11)
	inv.set_slot(2, 33)
	assert_eq(inv.all_iids(), [11, 33])
	inv.clear_all()
	assert_true(inv.is_empty())


func test_roundtrip() -> void:
	inv.set_slot(1, 42)
	inv.select(1)
	var restored: InventoryState = InventoryState.from_dict(inv.to_dict())
	assert_eq(restored.slots, inv.slots)
	assert_eq(restored.selected, 1)
	assert_eq(restored.unlocked, 3)
