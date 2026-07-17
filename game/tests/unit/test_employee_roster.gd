extends GutTest
## 직원 채용 시장 (PLAN.md §10.2~10.4).

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 5


func test_grade_table_monotonic() -> void:
	# 등급이 좋을수록 빠르고(work_mult↓) 비싸다(wage·hire_cost·min_days↑)
	var order: Array[String] = ["D", "C", "B", "A", "S"]
	for i in range(order.size() - 1):
		var low: Dictionary = EmployeeRoster.GRADES[order[i]]
		var high: Dictionary = EmployeeRoster.GRADES[order[i + 1]]
		assert_gt(float(low["work_mult"]), float(high["work_mult"]))
		assert_lt(int(low["wage"]), int(high["wage"]))
		assert_lt(int(low["hire_cost"]), int(high["hire_cost"]))
		assert_lt(int(low["min_days"]), int(high["min_days"]))


func test_candidate_fields_valid() -> void:
	for i in range(50):
		var c: Dictionary = EmployeeRoster.generate_candidate(rng)
		assert_true(EmployeeRoster.GRADES.has(String(c["grade"])))
		assert_true(EmployeeRoster.TRAITS.has(String(c["trait"])))
		assert_gt(float(c["work_interval"]), 0.0)
		assert_between(int(c["vacation_per_month"]), 2, 7,
			"월 휴가 2~7일 (§10.4)")
		assert_ne(String(c["name"]), "")


func test_candidate_role_fixed() -> void:
	# 후보 생성 시 역할이 무작위 고정되고, def_id가 역할과 일치한다 (§10.1)
	var seen_roles: Dictionary = {}
	for i in range(50):
		var c: Dictionary = EmployeeRoster.generate_candidate(rng)
		var matched: bool = false
		for row: Dictionary in EmployeeRoster.ROLES:
			if String(row["role"]) == String(c["role"]):
				assert_eq(String(c["def_id"]), String(row["def_id"]),
					"역할과 정의 ID 일치")
				matched = true
		assert_true(matched, "알려진 역할만 배출")
		seen_roles[String(c["role"])] = true
	assert_eq(seen_roles.size(), EmployeeRoster.ROLES.size(),
		"50회 표본에 세 역할 모두 등장")


func test_candidate_sick_chance_from_trait() -> void:
	# 질병 확률은 특성이 결정 (§10.4): 병약함 > 기본 > 성실함
	assert_eq(float((EmployeeRoster.TRAITS["병약함"] as Dictionary)["sick_chance"]),
		0.12)
	assert_eq(float((EmployeeRoster.TRAITS["성실함"] as Dictionary)["sick_chance"]),
		0.01)
	for i in range(30):
		var c: Dictionary = EmployeeRoster.generate_candidate(rng)
		var trait_row: Dictionary = EmployeeRoster.TRAITS[String(c["trait"])]
		var expected: float = float(trait_row.get(
			"sick_chance", EmployeeRoster.BASE_SICK_CHANCE))
		assert_eq(float(c["sick_chance"]), expected, "특성과 질병 확률 일치")


func test_lazy_trait_slows_work() -> void:
	# 게으름 특성은 작업 간격 +20% — 같은 등급 기준으로 확인
	var lazy_row: Dictionary = EmployeeRoster.TRAITS["게으름"]
	assert_eq(float(lazy_row["work_mult"]), 1.2)
	var sick: Dictionary = EmployeeRoster.TRAITS["병약함"]
	assert_gte(int(sick["vacation_min"]), 6, "병약함은 휴가 많음")
	var diligent: Dictionary = EmployeeRoster.TRAITS["성실함"]
	assert_lte(int(diligent["vacation_max"]), 3, "성실함은 휴가 적음")


func test_vacation_roll_window_and_uniqueness() -> void:
	var days: Array[int] = EmployeeRoster.roll_vacations(10, 5, rng)
	assert_eq(days.size(), 5)
	var seen: Dictionary = {}
	for day: int in days:
		assert_between(day, 10, 10 + EmployeeRoster.VACATION_WINDOW_DAYS - 1)
		assert_false(seen.has(day), "휴가일 중복 없음")
		seen[day] = true
	# 정렬 확인
	for i in range(days.size() - 1):
		assert_lt(days[i], days[i + 1])


func test_fire_penalty() -> void:
	# B급(min 7일, 일급 4000): 1일 근무 후 해고 → 6일 × 2000 = 12000
	assert_eq(EmployeeRoster.fire_penalty(1, 7, 4000, 2), 12000)
	# 기간 경과 후에는 위약금 없음
	assert_eq(EmployeeRoster.fire_penalty(1, 7, 4000, 8), 0)
	assert_eq(EmployeeRoster.fire_penalty(1, 0, 4000, 1), 0, "min_days 0")


func test_grade_distribution_weighted() -> void:
	var counts: Dictionary = {}
	for i in range(500):
		var grade: String = EmployeeRoster.random_grade(rng)
		counts[grade] = int(counts.get(grade, 0)) + 1
	assert_gt(int(counts.get("D", 0)), int(counts.get("S", 0)),
		"D가 S보다 흔함")


func test_state_roundtrip_with_stats() -> void:
	var emp: EmployeeState = EmployeeState.create(3, &"employee.prep.basic",
		Vector2i(2, 2))
	emp.apply_candidate({
		"name": "김하늘", "grade": "A", "trait": "재빠름", "wage": 5500,
		"hire_cost": 12000, "min_days": 10, "work_interval": 1.05,
		"move_speed": 3.25, "vacation_per_month": 4,
	}, 7)
	emp.vacation_days = [9, 15]
	var restored: EmployeeState = EmployeeState.from_dict(emp.to_dict())
	assert_eq(restored.display_name, "김하늘")
	assert_eq(restored.grade, "A")
	assert_eq(restored.wage, 5500)
	assert_eq(restored.hired_day, 7)
	assert_eq(restored.vacation_days, [9, 15] as Array[int])
	assert_true(restored.is_on_vacation(15))
	assert_false(restored.is_on_vacation(10))