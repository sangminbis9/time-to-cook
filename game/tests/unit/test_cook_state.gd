extends GutTest
## 튀김기 조리 상태머신 (PLAN.md §19.4–19.5, §32.2).

var fryer: StationDef


func before_each() -> void:
	fryer = Defs.get_def(&"station.fryer.basic") as StationDef


func _breaded(elapsed: float) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create(1, &"item.breaded_chicken")
	item.cook_elapsed = elapsed
	return item


func test_four_states_reachable() -> void:
	assert_eq(CookStateMachine.state_for(0.0, fryer), CookStateMachine.State.UNDERDONE)
	assert_eq(CookStateMachine.state_for(fryer.cook_seconds - 0.1, fryer),
		CookStateMachine.State.UNDERDONE)
	assert_eq(CookStateMachine.state_for(fryer.cook_seconds, fryer),
		CookStateMachine.State.NORMAL)
	assert_eq(CookStateMachine.state_for(
		fryer.cook_seconds + fryer.normal_window_seconds - 0.1, fryer),
		CookStateMachine.State.NORMAL)
	assert_eq(CookStateMachine.state_for(
		fryer.cook_seconds + fryer.normal_window_seconds, fryer),
		CookStateMachine.State.OVERCOOKED)
	assert_eq(CookStateMachine.state_for(fryer.burn_after_seconds, fryer),
		CookStateMachine.State.BURNT)


func test_takeout_underdone_keeps_item_and_progress() -> void:
	var item: ItemInstance = _breaded(3.0)
	var result: StringName = CookStateMachine.resolve_takeout(item, fryer)
	assert_eq(result, &"item.breaded_chicken", "덜 익음: 아이템 유지")
	assert_eq(item.cook_elapsed, 3.0, "진행도 유지 — 재투입 시 이어짐 (§19.5)")


func test_takeout_normal_transforms() -> void:
	var item: ItemInstance = _breaded(fryer.cook_seconds + 1.0)
	assert_eq(CookStateMachine.resolve_takeout(item, fryer), &"item.dakgangjeong")


func test_takeout_overcooked_is_burnt_output() -> void:
	var item: ItemInstance = _breaded(
		fryer.cook_seconds + fryer.normal_window_seconds + 0.5)
	assert_eq(CookStateMachine.resolve_takeout(item, fryer), &"item.burnt_food",
		"과조리: 복구 불가, 폐기 대상")


func test_takeout_burnt_is_burnt_output() -> void:
	var item: ItemInstance = _breaded(fryer.burn_after_seconds + 5.0)
	assert_eq(CookStateMachine.resolve_takeout(item, fryer), &"item.burnt_food")


func test_reinsert_resume_reaches_normal() -> void:
	# 4초 튀기고 꺼냈다가 다시 넣어 5초 더 → 정상 구간
	var item: ItemInstance = _breaded(4.0)
	assert_eq(CookStateMachine.resolve_takeout(item, fryer), &"item.breaded_chicken")
	item.cook_elapsed += 5.0
	assert_eq(CookStateMachine.resolve_takeout(item, fryer), &"item.dakgangjeong")


func test_fryer_timer_research_extends_normal() -> void:
	# 튀김기 타이머 연구 (§20 장비): NORMAL 창·탄 시점이 +3초 밀린다
	var at_edge: float = fryer.cook_seconds + fryer.normal_window_seconds + 1.0
	assert_eq(CookStateMachine.state_for(at_edge, fryer),
		CookStateMachine.State.OVERCOOKED, "연구 전: 과조리")
	FranchiseState.research[CookStateMachine.FRYER_TIMER_RESEARCH] = true
	assert_eq(CookStateMachine.state_for(at_edge, fryer),
		CookStateMachine.State.NORMAL, "연구 후: 아직 정상")
	assert_eq(CookStateMachine.state_for(fryer.burn_after_seconds, fryer),
		CookStateMachine.State.OVERCOOKED, "탄 시점도 함께 지연")
	FranchiseState.research.erase(CookStateMachine.FRYER_TIMER_RESEARCH)
