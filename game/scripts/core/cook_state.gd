class_name CookStateMachine
extends RefCounted
## 튀김기 조리 상태 판정 (PLAN.md §19.4–19.5).
## 상태는 아이템의 누적 조리 시간(cook_elapsed)과 설비 정의로부터 순수하게 유도된다.
## (Unity 프로토타입 CookableItem의 경과/유예 설계를 개념 이식)

enum State { UNDERDONE, NORMAL, OVERCOOKED, BURNT }


static func state_for(elapsed: float, def: StationDef) -> State:
	if elapsed < def.cook_seconds:
		return State.UNDERDONE
	if elapsed < def.cook_seconds + def.normal_window_seconds:
		return State.NORMAL
	if elapsed < def.burn_after_seconds:
		return State.OVERCOOKED
	return State.BURNT


## 꺼낼 때의 결과 아이템 def_id.
## 덜 익음 → 그대로 (진행도 유지, 재투입 가능)
## 정상   → work_output 변환 (완성)
## 과조리/탄 → burnt_output (폐기 대상)
static func resolve_takeout(item: ItemInstance, def: StationDef) -> StringName:
	var state: State = state_for(item.cook_elapsed, def)
	match state:
		State.UNDERDONE:
			return item.def_id
		State.NORMAL:
			var out: Variant = def.work_output.get(item.def_id)
			assert(out != null, "튀김기 work_output에 %s 없음" % item.def_id)
			return StringName(String(out))
		_:
			return def.burnt_output_id
