class_name InventoryState
extends RefCounted
## 마인크래프트식 슬롯 인벤토리 (PLAN.md §12).
## 슬롯당 아이템 1개(iid), 중첩 없음. 0 = 빈 슬롯.
## 기본 3칸 해금, 최대 9칸. 잠긴 슬롯도 UI에 항상 표시된다.

const SLOT_COUNT: int = 9
const DEFAULT_UNLOCKED: int = 3

var slots: Array[int] = []
var unlocked: int = DEFAULT_UNLOCKED
var selected: int = 0


func _init() -> void:
	slots.resize(SLOT_COUNT)
	slots.fill(0)


## §12.4 줍기 규칙: 선택 슬롯이 비었으면 선택 슬롯,
## 아니면 왼쪽부터 첫 빈 해금 슬롯. 없으면 -1 (실패).
func pickup_slot() -> int:
	if selected < unlocked and slots[selected] == 0:
		return selected
	for i in range(unlocked):
		if slots[i] == 0:
			return i
	return -1


func selected_iid() -> int:
	if selected >= unlocked:
		return 0
	return slots[selected]


func set_slot(index: int, iid: int) -> void:
	assert(index >= 0 and index < unlocked, "잠긴/잘못된 슬롯: %d" % index)
	slots[index] = iid


func clear_slot(index: int) -> void:
	slots[index] = 0


func select(index: int) -> void:
	selected = clampi(index, 0, unlocked - 1)


func select_next() -> void:
	select((selected + 1) % unlocked)


func select_prev() -> void:
	select((selected - 1 + unlocked) % unlocked)


func is_empty() -> bool:
	for i in range(SLOT_COUNT):
		if slots[i] != 0:
			return false
	return true


## 보유 중인 모든 iid (마감 폐기 등에 사용)
func all_iids() -> Array[int]:
	var result: Array[int] = []
	for i in range(SLOT_COUNT):
		if slots[i] != 0:
			result.append(slots[i])
	return result


func clear_all() -> void:
	slots.fill(0)


func to_dict() -> Dictionary:
	return {
		"slots": slots.duplicate(),
		"unlocked": unlocked,
		"selected": selected,
	}


static func from_dict(data: Dictionary) -> InventoryState:
	var inv: InventoryState = InventoryState.new()
	var raw_slots: Array = data.get("slots", [])
	for i in range(mini(raw_slots.size(), SLOT_COUNT)):
		inv.slots[i] = int(raw_slots[i])
	inv.unlocked = clampi(int(data.get("unlocked", DEFAULT_UNLOCKED)), 1, SLOT_COUNT)
	inv.selected = clampi(int(data.get("selected", 0)), 0, inv.unlocked - 1)
	return inv
