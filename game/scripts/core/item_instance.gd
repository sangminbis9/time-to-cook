class_name ItemInstance
extends RefCounted
## 런타임 아이템 인스턴스. 서버 발급 iid로 식별되는 순수 데이터.
## 조리·칼질 진행도는 아이템에 귀속된다 — 다른 플레이어가 이어서 작업 가능 (PLAN.md §19.3).

var iid: int = 0
var def_id: StringName
## 누적 칼질 횟수
var cuts_done: int = 0
## 튀김기 누적 조리 시간(초). 덜 익은 채 꺼내도 유지된다 (§19.5).
var cook_elapsed: float = 0.0


static func create(p_iid: int, p_def_id: StringName) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.iid = p_iid
	item.def_id = p_def_id
	return item


func get_def() -> ItemDef:
	return Defs.get_def(def_id) as ItemDef


func to_dict() -> Dictionary:
	return {
		"iid": iid,
		"def_id": String(def_id),
		"cuts_done": cuts_done,
		"cook_elapsed": cook_elapsed,
	}


static func from_dict(data: Dictionary) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.iid = int(data.get("iid", 0))
	item.def_id = StringName(String(data.get("def_id", "")))
	item.cuts_done = int(data.get("cuts_done", 0))
	item.cook_elapsed = float(data.get("cook_elapsed", 0.0))
	return item
