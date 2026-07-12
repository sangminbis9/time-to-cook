class_name StationState
extends RefCounted
## 설비 하나의 런타임 상태. 서버 권한 원본, 클라이언트는 미러.
## key는 매장 내 배치 고유 ID (예: &"fryer_1"), def_id는 설비 정의 ID.

var key: StringName
var def_id: StringName
## 설비 위에 놓인 아이템 (0 = 없음)
var item_iid: int = 0
## 이 설비에서 진행 중인 작업이 있는지 (튀김기: 아이템이 있으면 항상 조리 중)
## 직원 점유(P8)도 이 플래그 계열로 확장한다.
var work_in_progress: bool = false


static func create(p_key: StringName, p_def_id: StringName) -> StationState:
	var st: StationState = StationState.new()
	st.key = p_key
	st.def_id = p_def_id
	return st


func get_def() -> StationDef:
	return Defs.get_def(def_id) as StationDef


func is_empty() -> bool:
	return item_iid == 0


func to_dict() -> Dictionary:
	return {
		"key": String(key),
		"def_id": String(def_id),
		"item_iid": item_iid,
		"work_in_progress": work_in_progress,
	}


static func from_dict(data: Dictionary) -> StationState:
	var st: StationState = StationState.new()
	st.key = StringName(String(data.get("key", "")))
	st.def_id = StringName(String(data.get("def_id", "")))
	st.item_iid = int(data.get("item_iid", 0))
	st.work_in_progress = bool(data.get("work_in_progress", false))
	return st
