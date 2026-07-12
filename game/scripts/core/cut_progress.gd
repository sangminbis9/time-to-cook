class_name CutProgress
extends RefCounted
## 칼질 진행 (PLAN.md §19.3).
## 진행도는 아이템에 저장되어 중단 후 다른 플레이어가 이어서 할 수 있고,
## 두 플레이어가 동시에 칼질하면 모든 입력이 합산된다. 협력 페널티 없음.


## 칼질 1회 등록. 완성(필요 횟수 도달) 여부를 반환.
static func add_cut(item: ItemInstance, def: StationDef) -> bool:
	assert(def.required_cuts > 0, "required_cuts가 0인 설비에서 칼질: %s" % def.id)
	item.cuts_done += 1
	return item.cuts_done >= def.required_cuts


static func is_complete(item: ItemInstance, def: StationDef) -> bool:
	return item.cuts_done >= def.required_cuts


static func progress01(item: ItemInstance, def: StationDef) -> float:
	if def.required_cuts <= 0:
		return 0.0
	return clampf(float(item.cuts_done) / float(def.required_cuts), 0.0, 1.0)
