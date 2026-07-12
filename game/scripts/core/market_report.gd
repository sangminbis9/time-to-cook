class_name MarketReport
extends RefCounted
## 시장 정보 스냅샷 로직 (PLAN.md §7.5–7.6). 순수 함수 — 단위 테스트 대상.
##
## 보고서 형식: {"tier": int, "day": int, "paid_total": int,
##   "values": {"demand": float, "price_sensitivity": float?, "competition": float?}}
## 도시별 가장 최근 성공 기록 하나만 유지하고, 값은 획득 당시의 스냅샷이다.


## 구매 가격 (§7.6): 현재보다 상위 등급 구매 시 이전 실지불 누적액 차감.
## 같은/하위 등급 재구매(갱신)는 정가. 무료 획득분은 paid_total에 없어 자동 제외.
static func price_for(source: MarketSourceDef, current: Dictionary) -> int:
	if current.is_empty():
		return source.price
	if source.tier > int(current.get("tier", 0)):
		return maxi(0, source.price - int(current.get("paid_total", 0)))
	return source.price


## 등급별 공개 항목을 오차 적용해 스냅샷으로 만든다.
## demand_mult: 획득 시점의 동적 경제 배율 (§8.1) — 수요만 변동한다.
static func build_values(city: CityDef, source: MarketSourceDef,
		rng: RandomNumberGenerator, demand_mult: float = 1.0) -> Dictionary:
	var values: Dictionary = {
		"demand": _noisy(city.demand * demand_mult, source.accuracy_error, rng),
	}
	if source.tier >= 2:
		values["price_sensitivity"] = _noisy(
			city.price_sensitivity, source.accuracy_error, rng)
	if source.tier >= 3:
		values["competition"] = _noisy(city.competition, source.accuracy_error, rng)
	return values


static func make_report(city: CityDef, source: MarketSourceDef,
		rng: RandomNumberGenerator, today: int, current: Dictionary,
		paid_now: int, demand_mult: float = 1.0) -> Dictionary:
	return {
		"tier": source.tier,
		"day": today,
		"paid_total": int(current.get("paid_total", 0)) + paid_now,
		"values": build_values(city, source, rng, demand_mult),
	}


## 정확한 최고 등급 보고서 — 인천 최초 무료 정보 (§6.4).
## 무료이므로 paid_total에 포함하지 않는다 (§7.6).
static func exact_report(city: CityDef, today: int) -> Dictionary:
	return {
		"tier": 3,
		"day": today,
		"paid_total": 0,
		"values": {
			"demand": city.demand,
			"price_sensitivity": city.price_sensitivity,
			"competition": city.competition,
		},
	}


## 추천 재조사 기간 초과 여부 (§7.5)
static func needs_recheck(report: Dictionary, city: CityDef, today: int) -> bool:
	return today - int(report.get("day", 0)) > city.recheck_days


## 재조사 권장 도시 수 — 준비 화면 알림 배지 (§7.5).
## 미조사 도시는 포함하지 않는다 (§7.1).
static func recheck_count(market_info: Dictionary, today: int) -> int:
	var count: int = 0
	for city_id: String in market_info.keys():
		if not Defs.has_def(StringName(city_id)):
			continue
		var city: CityDef = Defs.get_def(StringName(city_id)) as CityDef
		if needs_recheck(market_info[city_id], city, today):
			count += 1
	return count


static func _noisy(value: float, error: float, rng: RandomNumberGenerator) -> float:
	if error <= 0.0:
		return value
	return snappedf(value * (1.0 + rng.randf_range(-error, error)), 0.01)
