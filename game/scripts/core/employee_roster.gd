class_name EmployeeRoster
extends RefCounted
## 직원 채용 시장 (PLAN.md §10.2~10.4). 순수 로직 — 단위 테스트 대상.
##
## 등급·능력치·특성은 채용 시점에 무작위로 고정된다 — 레벨업·교육 성장 없음 (§10.2).
## 후보는 매일 갱신되고, 고용하면 스탯 스냅샷이 EmployeeState에 저장된다.

## 등급표: 작업 간격 배율(낮을수록 빠름), 일급, 채용비, 최소 고용일 (§10.3)
const GRADES: Dictionary = {
	"D": {"work_mult": 1.6, "wage": 2200, "hire_cost": 3000, "min_days": 3},
	"C": {"work_mult": 1.35, "wage": 3000, "hire_cost": 5000, "min_days": 5},
	"B": {"work_mult": 1.1, "wage": 4000, "hire_cost": 8000, "min_days": 7},
	"A": {"work_mult": 0.9, "wage": 5500, "hire_cost": 12000, "min_days": 10},
	"S": {"work_mult": 0.7, "wage": 7500, "hire_cost": 20000, "min_days": 14},
}
const GRADE_WEIGHTS: Dictionary = {"D": 35, "C": 30, "B": 20, "A": 10, "S": 5}

## 특성 (§10.4 개인 특성이 이벤트 패턴에 영향): 채용 시 1개 고정
## vacation: 월 휴가일 범위 재정의, work: 작업 간격 배율, speed: 이동 속도 배율,
## sick_chance: 일일 질병(결근·조퇴) 확률 재정의 (§10.4)
const TRAITS: Dictionary = {
	"성실함": {"vacation_min": 2, "vacation_max": 3, "sick_chance": 0.01},
	"무난함": {},
	"재빠름": {"speed_mult": 1.3},
	"게으름": {"work_mult": 1.2},
	"병약함": {"vacation_min": 6, "vacation_max": 7, "sick_chance": 0.12},
}

## 특성 재정의가 없을 때의 기본 일일 질병 확률
const BASE_SICK_CHANCE: float = 0.03

## 채용 시장에 나오는 역할 (§10.1 — 후보 생성 시 무작위 고정, 직무 변경 불가)
const ROLES: Array[Dictionary] = [
	{"role": "prep", "def_id": "employee.prep.basic", "label": "전처리"},
	{"role": "cook", "def_id": "employee.cook.basic", "label": "조리"},
	{"role": "serve", "def_id": "employee.serve.basic", "label": "서빙"},
]

const SURNAMES: Array[String] = ["김", "이", "박", "최", "정", "한", "오", "윤", "장", "임"]
const GIVEN: Array[String] = [
	"하늘", "도윤", "서준", "지우", "민재", "소율", "세린", "재하", "은채", "시우",
]

## 기본 월 휴가일 범위 (§10.4: 매월 2~7일)
const VACATION_MIN: int = 3
const VACATION_MAX: int = 5
const VACATION_WINDOW_DAYS: int = 30
## 위약금: 남은 최소 근무일 × 일급의 절반 (§10.3)
const PENALTY_WAGE_RATIO: float = 0.5


static func random_grade(rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for grade: String in GRADE_WEIGHTS.keys():
		total += int(GRADE_WEIGHTS[grade])
	var roll: int = rng.randi_range(1, total)
	for grade: String in GRADE_WEIGHTS.keys():
		roll -= int(GRADE_WEIGHTS[grade])
		if roll <= 0:
			return grade
	return "D"


## 채용 후보 1명 생성 — 모든 수치가 이 시점에 고정된다.
static func generate_candidate(rng: RandomNumberGenerator,
		base_work_interval: float = 1.2, base_speed: float = 2.5) -> Dictionary:
	var grade: String = random_grade(rng)
	var grade_row: Dictionary = GRADES[grade]
	var trait_names: Array = TRAITS.keys()
	var trait_name: String = trait_names[rng.randi_range(0, trait_names.size() - 1)]
	var trait_row: Dictionary = TRAITS[trait_name]
	var work_mult: float = float(grade_row["work_mult"]) \
		* float(trait_row.get("work_mult", 1.0)) \
		* rng.randf_range(0.95, 1.05)
	var vac_min: int = int(trait_row.get("vacation_min", VACATION_MIN))
	var vac_max: int = int(trait_row.get("vacation_max", VACATION_MAX))
	var role_row: Dictionary = ROLES[rng.randi_range(0, ROLES.size() - 1)]
	return {
		"name": SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)]
			+ GIVEN[rng.randi_range(0, GIVEN.size() - 1)],
		"role": String(role_row["role"]),
		"def_id": String(role_row["def_id"]),
		"grade": grade,
		"trait": trait_name,
		"wage": int(grade_row["wage"]),
		"hire_cost": int(grade_row["hire_cost"]),
		"min_days": int(grade_row["min_days"]),
		"work_interval": snappedf(base_work_interval * work_mult, 0.01),
		"move_speed": snappedf(
			base_speed * float(trait_row.get("speed_mult", 1.0)), 0.01),
		"vacation_per_month": rng.randi_range(vac_min, vac_max),
		"sick_chance": float(trait_row.get("sick_chance", BASE_SICK_CHANCE)),
	}


static func generate_candidates(count: int,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(count):
		result.append(generate_candidate(rng))
	return result


## 향후 30일 창에서 휴가일을 무작위 지정 (§10.4).
## 날짜 이동·취소·매수 불가 — 굴린 결과가 그대로 확정된다.
static func roll_vacations(start_day: int, count: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for offset in range(VACATION_WINDOW_DAYS):
		pool.append(start_day + offset)
	# rng 기반 Fisher–Yates 셔플 (결정성 보장)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var days: Array[int] = []
	for i in range(mini(count, pool.size())):
		days.append(pool[i])
	days.sort()
	return days


## 최소 근무 기간 내 해고 위약금 (§10.3). 기간 경과 후에는 0.
static func fire_penalty(hired_day: int, min_days: int, wage: int,
		today: int) -> int:
	var worked: int = today - hired_day
	var remaining: int = min_days - worked
	if remaining <= 0:
		return 0
	return int(remaining * wage * PENALTY_WAGE_RATIO)
