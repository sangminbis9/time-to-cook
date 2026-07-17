extends GutTest
## 동적 경제 (PLAN.md §8.1).

var incheon: CityDef
var rng: RandomNumberGenerator


func before_each() -> void:
	incheon = Defs.get_def(&"city.korea.incheon") as CityDef
	rng = RandomNumberGenerator.new()
	rng.seed = 7


func test_acceptance_base_price_full() -> void:
	assert_eq(CityEconomy.acceptance(3000, 3000, 1.0), 1.0)


func test_acceptance_drops_with_price() -> void:
	# 민감도 1.0에서 +33% 인상 → 수용률 0.667
	assert_almost_eq(CityEconomy.acceptance(4000, 3000, 1.0), 0.667, 0.01)
	# 폭리는 0 — 주문이 오지 않는다
	assert_eq(CityEconomy.acceptance(20000, 3000, 1.0), 0.0)


func test_acceptance_discount_bonus_capped() -> void:
	assert_gt(CityEconomy.acceptance(2500, 3000, 1.0), 1.0, "할인은 보너스")
	assert_eq(CityEconomy.acceptance(500, 3000, 3.0), CityEconomy.ACCEPTANCE_MAX,
		"보너스 상한")


func test_sensitivity_scales_penalty() -> void:
	var low: float = CityEconomy.acceptance(4000, 3000, 0.5)
	var high: float = CityEconomy.acceptance(4000, 3000, 1.5)
	assert_gt(low, high, "민감한 도시일수록 인상 페널티 큼")


func test_effective_demand() -> void:
	# 인천: 1.5 × 1.0 ÷ (0.5 + 0.5×0.8) = 1.667
	assert_almost_eq(CityEconomy.effective_demand(incheon, 1.0), 1.667, 0.01)
	# 배율이 유효 수요를 비례 변화
	assert_almost_eq(CityEconomy.effective_demand(incheon, 0.6), 1.0, 0.01)


func test_competition_dampens() -> void:
	var seoul: CityDef = Defs.get_def(&"city.korea.seoul") as CityDef
	# 서울: 수요 3.0이지만 경쟁 2.0 → 유효 2.0
	assert_almost_eq(CityEconomy.effective_demand(seoul, 1.0), 2.0, 0.01)


func test_drift_bounds_and_coverage() -> void:
	var ids: Array[String] = ["city.korea.incheon", "city.korea.seoul"]
	var econ: Dictionary = {}
	for day in range(200):
		econ = CityEconomy.drifted(econ, ids, rng)
		for city_id: String in ids:
			var mult: float = float(econ[city_id])
			assert_between(mult, CityEconomy.MULT_MIN, CityEconomy.MULT_MAX)
	assert_eq(econ.size(), 2, "모든 도시 배율 생성")


func test_default_mult_is_one() -> void:
	assert_eq(CityEconomy.demand_mult({}, "city.korea.busan"), 1.0)


func test_report_reflects_mult() -> void:
	var advisor: MarketSourceDef = Defs.get_def(&"market.advisor.local") as MarketSourceDef
	var values: Dictionary = MarketReport.build_values(incheon, advisor, rng, 1.2)
	assert_almost_eq(float(values["demand"]), incheon.demand * 1.2, 0.001,
		"보고서 수요에 변동 배율 반영 (§7.5 스냅샷)")


func test_ad_tick_and_expiry() -> void:
	# 광고 (§8.3): 매일 잔여 일수 감소, 0이 되면 만료
	var ads: Dictionary = {"city.korea.incheon": {"ad_id": "flyer", "days_left": 2}}
	ads = CityEconomy.tick_ads(ads)
	assert_eq(int((ads["city.korea.incheon"] as Dictionary)["days_left"]), 1)
	ads = CityEconomy.tick_ads(ads)
	assert_false(ads.has("city.korea.incheon"), "만료 후 제거")


func test_ad_demand_factor() -> void:
	var ads: Dictionary = {"city.korea.incheon": {"ad_id": "local_tv", "days_left": 5}}
	assert_almost_eq(
		CityEconomy.ad_demand_factor(ads, "city.korea.incheon"), 1.6, 0.001)
	assert_eq(CityEconomy.ad_demand_factor(ads, "city.korea.seoul"), 1.0,
		"광고는 집행 도시에만 적용")
	assert_eq(CityEconomy.ad_demand_factor({}, "city.korea.incheon"), 1.0)