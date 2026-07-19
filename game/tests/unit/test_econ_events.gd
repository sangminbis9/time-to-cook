extends GutTest
## 급격 경제 이벤트 (PLAN.md §8.1 후반, §23.2).

const CITIES: Array[String] = ["city.korea.incheon", "city.korea.busan"]

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 11


func test_event_defs_loaded() -> void:
	for id: StringName in [
		&"event.boom", &"event.recession",
		&"event.tourism_surge", &"event.supply_shock",
		&"event.storm", &"event.snow", &"event.heatwave", &"event.earthquake",
	]:
		assert_true(Defs.has_def(id), "누락 이벤트: %s" % id)


func test_chance_one_starts_events() -> void:
	var events: Dictionary = CityEconomy.tick_events({}, CITIES, rng, 1.0)
	assert_eq(events.size(), 2, "확률 100%면 전 도시 발생")
	for city_id: String in CITIES:
		var event_id: StringName = StringName(String(events[city_id]["event_id"]))
		assert_true(Defs.has_def(event_id))
		assert_gt(int(events[city_id]["days_left"]), 0)


func test_chance_zero_starts_nothing() -> void:
	assert_true(CityEconomy.tick_events({}, CITIES, rng, 0.0).is_empty())


func test_countdown_and_expiry() -> void:
	var events: Dictionary = {
		"city.korea.incheon": {"event_id": "event.boom", "days_left": 2},
	}
	events = CityEconomy.tick_events(events, CITIES, rng, 0.0)
	assert_eq(int(events["city.korea.incheon"]["days_left"]), 1, "지속 감소")
	events = CityEconomy.tick_events(events, CITIES, rng, 0.0)
	assert_false(events.has("city.korea.incheon"), "만료 시 제거")


func test_no_restart_on_expiry_day() -> void:
	# 만료되는 날에는 새 이벤트가 바로 발생하지 않는다 (연속 방지)
	var events: Dictionary = {
		"city.korea.incheon": {"event_id": "event.boom", "days_left": 1},
	}
	events = CityEconomy.tick_events(events, ["city.korea.incheon"], rng, 1.0)
	assert_false(events.has("city.korea.incheon"))


func test_demand_and_cost_factors() -> void:
	var boom: Dictionary = {
		"city.korea.busan": {"event_id": "event.boom", "days_left": 2},
	}
	assert_eq(CityEconomy.event_demand_factor(boom, "city.korea.busan"), 1.4)
	assert_eq(CityEconomy.event_cost_factor(boom, "city.korea.busan"), 1.0)
	var shock: Dictionary = {
		"city.korea.busan": {"event_id": "event.supply_shock", "days_left": 1},
	}
	assert_eq(CityEconomy.event_demand_factor(shock, "city.korea.busan"), 1.0)
	assert_eq(CityEconomy.event_cost_factor(shock, "city.korea.busan"), 1.6)
	assert_eq(CityEconomy.event_demand_factor({}, "city.korea.busan"), 1.0,
		"무이벤트 = 배율 1")


func test_effective_demand_with_event() -> void:
	var incheon: CityDef = Defs.get_def(&"city.korea.incheon") as CityDef
	var base: float = CityEconomy.effective_demand(incheon, 1.0)
	assert_almost_eq(CityEconomy.effective_demand(incheon, 1.0, 1.8),
		base * 1.8, 0.001, "관광 급증은 유효 수요 1.8배")