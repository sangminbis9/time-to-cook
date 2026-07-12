class_name FridgeState
extends RefCounted
## 냉장고 런타임 상태 (PLAN.md §17).
## 슬롯당 아이템 1개, 스택 없음. 한 번에 한 플레이어만 사용 (lock_owner).
## 마감 폐기에서 유일하게 생존하는 저장 공간.

var def_id: StringName
var slots: Array[int] = []
## 사용 중인 피어 ID. 0 = 비어 있음.
var lock_owner: int = 0


static func create(p_def_id: StringName, slot_count: int) -> FridgeState:
	var fridge: FridgeState = FridgeState.new()
	fridge.def_id = p_def_id
	fridge.slots.resize(slot_count)
	fridge.slots.fill(0)
	return fridge


## 보관 조건 (§17.2): 가열 조리를 시작하지 않은 재료만.
## ItemDef.fridge_storable 데이터로 판정하되, 조리 진행이 붙은 아이템은 거부.
static func can_store(item: ItemInstance) -> bool:
	if item.cook_elapsed > 0.0:
		return false
	return item.get_def().fridge_storable


func try_lock(peer_id: int) -> bool:
	if lock_owner != 0 and lock_owner != peer_id:
		return false
	lock_owner = peer_id
	return true


func unlock(peer_id: int) -> void:
	if lock_owner == peer_id:
		lock_owner = 0


func first_free_slot() -> int:
	for i in range(slots.size()):
		if slots[i] == 0:
			return i
	return -1


func to_dict() -> Dictionary:
	return {
		"def_id": String(def_id),
		"slots": slots.duplicate(),
	}


static func from_dict(data: Dictionary) -> FridgeState:
	var fridge: FridgeState = FridgeState.new()
	fridge.def_id = StringName(String(data.get("def_id", "")))
	var raw: Array = data.get("slots", [])
	for value: Variant in raw:
		fridge.slots.append(int(value))
	return fridge
