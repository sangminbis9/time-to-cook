extends GutTest
## 냉장고 보관 규칙과 잠금 (PLAN.md §17.2, §17.5, §32.1).

var fridge: FridgeState


func before_each() -> void:
	fridge = FridgeState.create(&"fridge.small", 3)


func test_storable_raw_ingredients() -> void:
	for id: StringName in [
		&"item.raw_chicken", &"item.cut_chicken", &"item.breaded_chicken"
	]:
		var item: ItemInstance = ItemInstance.create(1, id)
		assert_true(FridgeState.can_store(item), "%s는 보관 가능해야 함" % id)


func test_cooked_food_not_storable() -> void:
	for id: StringName in [&"item.dakgangjeong", &"item.burnt_food"]:
		var item: ItemInstance = ItemInstance.create(1, id)
		assert_false(FridgeState.can_store(item), "%s는 보관 불가" % id)


func test_heated_ingredient_not_storable() -> void:
	# 튀김옷 재료라도 가열이 시작됐으면(덜 익은 채 꺼냄) 보관 불가 (§17.2)
	var item: ItemInstance = ItemInstance.create(1, &"item.breaded_chicken")
	item.cook_elapsed = 2.0
	assert_false(FridgeState.can_store(item), "가열 시작한 재료는 보관 불가")


func test_lock_single_user() -> void:
	assert_true(fridge.try_lock(1), "먼저 연 플레이어가 사용권 획득")
	assert_false(fridge.try_lock(2), "다른 플레이어는 열 수 없음")
	assert_true(fridge.try_lock(1), "소유자 재요청은 허용")


func test_unlock_only_by_owner() -> void:
	fridge.try_lock(1)
	fridge.unlock(2)
	assert_eq(fridge.lock_owner, 1, "비소유자 해제 무시")
	fridge.unlock(1)
	assert_eq(fridge.lock_owner, 0)
	assert_true(fridge.try_lock(2), "해제 후 다른 플레이어 사용 가능")


func test_first_free_slot() -> void:
	assert_eq(fridge.first_free_slot(), 0)
	fridge.slots[0] = 10
	fridge.slots[1] = 11
	assert_eq(fridge.first_free_slot(), 2)
	fridge.slots[2] = 12
	assert_eq(fridge.first_free_slot(), -1)


func test_roundtrip() -> void:
	fridge.slots[1] = 77
	var restored: FridgeState = FridgeState.from_dict(fridge.to_dict())
	assert_eq(restored.slots, fridge.slots)
	assert_eq(restored.def_id, &"fridge.small")
	assert_eq(restored.lock_owner, 0, "잠금은 런타임 상태 — 저장하지 않음")
