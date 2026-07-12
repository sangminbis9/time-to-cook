extends GutTest
## 주문 관리 (PLAN.md §19.6, §29.4): 스폰 상한, 완료 원자성(중복 제출 차단).

const RECIPE: StringName = &"recipe.fried_dakgangjeong"

var book: OrderBook


func before_each() -> void:
	book = OrderBook.new()
	book.max_active = 3


func test_spawn_respects_cap() -> void:
	for i in range(3):
		assert_false(book.spawn(RECIPE, 0.0).is_empty())
	assert_true(book.spawn(RECIPE, 0.0).is_empty(), "상한 초과 스폰 거부")
	assert_eq(book.active.size(), 3)


func test_oids_unique_and_monotonic() -> void:
	var first: Dictionary = book.spawn(RECIPE, 0.0)
	var second: Dictionary = book.spawn(RECIPE, 1.0)
	assert_eq(int(first["oid"]), 1)
	assert_eq(int(second["oid"]), 2)


func test_complete_removes_one_atomically() -> void:
	book.spawn(RECIPE, 0.0)
	var done: Dictionary = book.complete_first(RECIPE)
	assert_false(done.is_empty())
	# 같은 레시피 재제출 — 활성 주문이 없으므로 실패 (중복 제출 차단의 핵심)
	assert_true(book.complete_first(RECIPE).is_empty(),
		"두 번째 제출은 매칭할 주문이 없어야 함")


func test_two_orders_two_submits() -> void:
	book.spawn(RECIPE, 0.0)
	book.spawn(RECIPE, 1.0)
	var first: Dictionary = book.complete_first(RECIPE)
	var second: Dictionary = book.complete_first(RECIPE)
	assert_eq(int(first["oid"]), 1, "먼저 생성된 주문부터 완료")
	assert_eq(int(second["oid"]), 2)
	assert_eq(book.active.size(), 0)


func test_unknown_recipe_no_match() -> void:
	book.spawn(RECIPE, 0.0)
	assert_true(book.complete_first(&"recipe.nonexistent").is_empty())
	assert_eq(book.active.size(), 1, "실패한 제출이 주문을 건드리면 안 됨")


func test_roundtrip_preserves_next_oid() -> void:
	book.spawn(RECIPE, 0.0)
	book.complete_first(RECIPE)
	var restored: OrderBook = OrderBook.from_dict(book.to_dict())
	assert_eq(restored.next_oid, 2, "복원 후 oid 충돌 없음")
	assert_eq(restored.max_active, 3)
	assert_eq(restored.active.size(), 0)
