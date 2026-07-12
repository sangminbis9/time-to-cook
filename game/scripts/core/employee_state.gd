class_name EmployeeState
extends RefCounted
## 직원 런타임 상태. 서버가 FSM을 구동하고 전이 시마다 전체 상태를 브로드캐스트한다.
## 직원이 설비에서 작업을 시작하면 플레이어는 개입할 수 없다 (PLAN.md §10.6).

enum Phase { IDLE, TO_BOX, TO_BOARD, CUTTING, TO_OUTPUT, WAIT_OUTPUT }

var eid: int = 0
var def_id: StringName
## 채용 시 고정되는 개인 스탯 (§10.2 — 성장·변경 없음)
var display_name: String = "직원"
var grade: String = "C"
var trait_name: String = "무난함"
var wage: int = 3000
var work_interval: float = 1.2
var move_speed: float = 2.5
var min_days: int = 0
var hired_day: int = 1
var vacation_per_month: int = 0
## 확정된 휴가일 (절대 일차, §10.4 — 이동·취소 불가)
var vacation_days: Array[int] = []
var vacation_rolled_until: int = 0
## 손에 든 아이템 (0 = 없음)
var carrying_iid: int = 0
var phase: Phase = Phase.IDLE
## 이동 표현용: 출발/도착 타일과 이동 시간
var tile_from: Vector2i
var tile_to: Vector2i
var move_duration: float = 0.0
## 서버 전용 타이머 (직렬화 불필요 — 로드 시 IDLE로 재시작)
var timer: float = 0.0


static func create(p_eid: int, p_def_id: StringName, spawn: Vector2i) -> EmployeeState:
	var emp: EmployeeState = EmployeeState.new()
	emp.eid = p_eid
	emp.def_id = p_def_id
	emp.tile_from = spawn
	emp.tile_to = spawn
	return emp


func get_def() -> EmployeeDef:
	return Defs.get_def(def_id) as EmployeeDef


## 채용 후보 스탯을 적용 (§10.2: 이 시점 이후 영구 고정)
func apply_candidate(candidate: Dictionary, today: int) -> void:
	display_name = String(candidate.get("name", "직원"))
	grade = String(candidate.get("grade", "C"))
	trait_name = String(candidate.get("trait", "무난함"))
	wage = int(candidate.get("wage", 3000))
	work_interval = float(candidate.get("work_interval", 1.2))
	move_speed = float(candidate.get("move_speed", 2.5))
	min_days = int(candidate.get("min_days", 0))
	vacation_per_month = int(candidate.get("vacation_per_month", 0))
	hired_day = today


func is_on_vacation(day: int) -> bool:
	return vacation_days.has(day)


func to_dict() -> Dictionary:
	return {
		"eid": eid,
		"def_id": String(def_id),
		"name": display_name,
		"grade": grade,
		"trait": trait_name,
		"wage": wage,
		"work_interval": work_interval,
		"move_speed": move_speed,
		"min_days": min_days,
		"hired_day": hired_day,
		"vacation_per_month": vacation_per_month,
		"vacation_days": vacation_days.duplicate(),
		"vacation_rolled_until": vacation_rolled_until,
		"carrying_iid": carrying_iid,
		"phase": phase,
		"from_x": tile_from.x, "from_y": tile_from.y,
		"to_x": tile_to.x, "to_y": tile_to.y,
		"move_duration": move_duration,
	}


static func from_dict(data: Dictionary) -> EmployeeState:
	var emp: EmployeeState = EmployeeState.new()
	emp.eid = int(data.get("eid", 0))
	emp.def_id = StringName(String(data.get("def_id", "")))
	emp.display_name = String(data.get("name", "직원"))
	emp.grade = String(data.get("grade", "C"))
	emp.trait_name = String(data.get("trait", "무난함"))
	emp.wage = int(data.get("wage", 3000))
	emp.work_interval = float(data.get("work_interval", 1.2))
	emp.move_speed = float(data.get("move_speed", 2.5))
	emp.min_days = int(data.get("min_days", 0))
	emp.hired_day = int(data.get("hired_day", 1))
	emp.vacation_per_month = int(data.get("vacation_per_month", 0))
	for day: Variant in (data.get("vacation_days", []) as Array):
		emp.vacation_days.append(int(day))
	emp.vacation_rolled_until = int(data.get("vacation_rolled_until", 0))
	emp.carrying_iid = int(data.get("carrying_iid", 0))
	emp.phase = (int(data.get("phase", Phase.IDLE)) as Phase)
	emp.tile_from = Vector2i(int(data.get("from_x", 0)), int(data.get("from_y", 0)))
	emp.tile_to = Vector2i(int(data.get("to_x", 0)), int(data.get("to_y", 0)))
	emp.move_duration = float(data.get("move_duration", 0.0))
	return emp
