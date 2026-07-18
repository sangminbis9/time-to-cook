extends GutTest
## 시장 정보 로직 (PLAN.md §7.5–7.6).

var city: CityDef
var cheap: MarketSourceDef
var pro: MarketSourceDef
var advisor: MarketSourceDef
var rng: RandomNumberGenerator


func before_each() -> void:
	city = Defs.get_def(&"city.korea.busan") as CityDef
	cheap = Defs.get_def(&"market.broker.cheap") as MarketSourceDef
	pro = Defs.get_def(&"market.broker.pro") as MarketSourceDef
	advisor = Defs.get_def(&"market.advisor.local") as MarketSourceDef
	rng = RandomNumberGenerator.new()
	rng.seed = 42


func test_source_traits() -> void:
	assert_eq(advisor.scam_chance, 0.0, "자문은 사기 확률 0 (§7.4)")
	assert_eq(advisor.accuracy_error, 0.0, "자문은 정확")
	assert_gt(advisor.price, pro.price, "자문이 더 비쌈")
	assert_gt(cheap.scam_chance, 0.0, "암시장은 사기 위험 존재")


func test_tier_fields() -> void:
	assert_false(MarketReport.build_values(city, cheap, rng)
		.has("price_sensitivity"), "1등급: 수요만")
	var t2: Dictionary = MarketReport.build_values(city, pro, rng)
	assert_true(t2.has("price_sensitivity") and not t2.has("competition"))
	assert_true(MarketReport.build_values(city, advisor, rng)
		.has("competition"), "3등급: 전체 항목")


func test_advisor_exact_values() -> void:
	var values: Dictionary = MarketReport.build_values(city, advisor, rng)
	assert_eq(float(values["demand"]), city.demand)
	assert_eq(float(values["competition"]), city.competition)


func test_noise_bounded() -> void:
	for i in range(30):
		var values: Dictionary = MarketReport.build_values(city, cheap, rng)
		var reported: float = float(values["demand"])
		assert_between(reported, city.demand * 0.79, city.demand * 1.21,
			"오차율 ±20% 이내")


func test_upgrade_discount() -> void:
	# 1등급 3000원 성공 구매 → 3등급 구매 시 15000-3000=12000 (§7.6)
	var report: Dictionary = MarketReport.make_report(city, cheap, rng, 1, {}, 3000)
	assert_eq(int(report["paid_total"]), 3000)
	assert_eq(MarketReport.price_for(advisor, report), 12000)


func test_renewal_same_tier_full_price() -> void:
	var report: Dictionary = MarketReport.make_report(city, advisor, rng, 1, {}, 15000)
	assert_eq(MarketReport.price_for(advisor, report), advisor.price,
		"같은 등급 갱신은 정가")


func test_free_info_not_discounted() -> void:
	# 인천 무료 정보는 paid_total 0 — 할인에 포함 안 됨 (§6.4/§7.6)
	var free: Dictionary = MarketReport.exact_report(city, 1)
	assert_eq(int(free["paid_total"]), 0)
	assert_eq(MarketReport.price_for(advisor, free), advisor.price)


func test_char_ability_free_report_keeps_paid_total() -> void:
	# 캐릭터 능력 무료 획득 (§7.2-③): paid_now 0 — 기존 실지불 누적은 보존,
	# 새로 낸 돈이 없으니 할인 재원도 늘지 않는다 (§7.6)
	var paid: Dictionary = MarketReport.make_report(city, cheap, rng, 1, {}, 3000)
	var free: Dictionary = MarketReport.make_report(city, pro, rng, 3, paid, 0)
	assert_eq(int(free["paid_total"]), 3000, "실지불 누적 보존")
	assert_eq(int(free["tier"]), 2, "능력 경로 등급으로 갱신")
	assert_eq(MarketReport.price_for(advisor, free), advisor.price - 3000,
		"할인은 실지불분만")


func test_paid_total_accumulates() -> void:
	var first: Dictionary = MarketReport.make_report(city, cheap, rng, 1, {}, 3000)
	var second: Dictionary = MarketReport.make_report(city, pro, rng, 2, first, 5000)
	assert_eq(int(second["paid_total"]), 8000, "실지불 성공 누적")


func test_scam_vanish_rotation() -> void:
	# 사기 친 정보상은 2~4일 잠적 후 다른 이름으로 재등장 (§7.3)
	for i in range(30):
		var row: Dictionary = MarketReport.scam_vanish("뒷골목 정보상", 5, rng)
		assert_between(int(row["gone_until"]), 5 + MarketReport.GONE_DAYS_MIN,
			5 + MarketReport.GONE_DAYS_MAX)
		assert_ne(String(row["alias"]), "뒷골목 정보상", "이름이 반드시 바뀐다")
		assert_true(MarketReport.BROKER_ALIASES.has(String(row["alias"])))


func test_broker_gone_window() -> void:
	var state: Dictionary = {"market.broker.cheap": {
		"alias": "떠돌이 소식통", "gone_until": 8}}
	assert_true(MarketReport.broker_gone(state, "market.broker.cheap", 7),
		"잠적 중 거래 불가")
	assert_false(MarketReport.broker_gone(state, "market.broker.cheap", 8),
		"잠적 종료 후 재등장")
	assert_false(MarketReport.broker_gone({}, "market.broker.cheap", 7),
		"사기 이력 없으면 항상 가능")


func test_broker_name_alias() -> void:
	assert_eq(MarketReport.broker_name({}, cheap), cheap.display_name_ko,
		"이력 없으면 원래 이름")
	var state: Dictionary = {String(cheap.id): {
		"alias": "부둣가 중개인", "gone_until": 3}}
	assert_eq(MarketReport.broker_name(state, cheap), "부둣가 중개인",
		"사기 후에는 바뀐 이름 (§7.3)")


func test_recheck_badge() -> void:
	var fresh: Dictionary = MarketReport.exact_report(city, 10)
	assert_false(MarketReport.needs_recheck(fresh, city, 10 + city.recheck_days))
	assert_true(MarketReport.needs_recheck(fresh, city, 11 + city.recheck_days))
	var info: Dictionary = {
		"city.korea.busan": MarketReport.exact_report(city, 1),
		# 미조사 도시는 배지에 포함되지 않는다 (§7.1) — 없는 키가 그 증거
	}
	assert_eq(MarketReport.recheck_count(info, 1 + city.recheck_days + 1), 1)
	assert_eq(MarketReport.recheck_count({}, 99), 0, "미조사만 있으면 0")
