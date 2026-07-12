class_name OrderBook
extends RefCounted
## 활성 주문 관리 (PLAN.md §5, §19.6).
## 음식은 주문 ID에 귀속되지 않는다 — 같은 레시피의 어떤 활성 주문에도 제출 가능.
## 완료는 원자적 제거이므로 두 플레이어가 같은 주문을 중복 제출할 수 없다.

var active: Array[Dictionary] = []
var next_oid: int = 1
var max_active: int = 4


## 주문 추가. 상한 초과 시 null 대신 빈 Dictionary 반환.
func spawn(recipe_id: StringName, created_at: float) -> Dictionary:
	if active.size() >= max_active:
		return {}
	var order: Dictionary = {
		"oid": next_oid,
		"recipe_id": String(recipe_id),
		"created_at": created_at,
	}
	next_oid += 1
	active.append(order)
	return order


## 해당 레시피의 첫 활성 주문을 완료(제거)하고 반환. 없으면 빈 Dictionary.
func complete_first(recipe_id: StringName) -> Dictionary:
	for i in range(active.size()):
		if StringName(String(active[i]["recipe_id"])) == recipe_id:
			var order: Dictionary = active[i]
			active.remove_at(i)
			return order
	return {}


func count_for(recipe_id: StringName) -> int:
	var count: int = 0
	for order: Dictionary in active:
		if StringName(String(order["recipe_id"])) == recipe_id:
			count += 1
	return count


func clear() -> void:
	active.clear()


func to_dict() -> Dictionary:
	return {
		"active": active.duplicate(true),
		"next_oid": next_oid,
		"max_active": max_active,
	}


static func from_dict(data: Dictionary) -> OrderBook:
	var book: OrderBook = OrderBook.new()
	var raw: Array = data.get("active", [])
	for entry: Variant in raw:
		if entry is Dictionary:
			book.active.append(entry as Dictionary)
	book.next_oid = int(data.get("next_oid", 1))
	book.max_active = int(data.get("max_active", 4))
	return book
