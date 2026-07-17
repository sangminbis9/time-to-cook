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


# ── 정보상 재등장 로테이션 (§7.3) ──────────────────────────────────
## 사기 발생 시 정보상은 며칠 잠적한 뒤 다른 이름으로 다시 등장한다.
## 특성(가격·정확도·사기 확률)은 영구 고정 — 이름만 바뀐다 (§7.3).
##
## 상태 형식: source_id(String) → {"alias": String, "gone_until": int}

const BROKER_ALIASES: Array[String] = [
	"뒷골목 정보상", "골목 어귀 장사꾼", "떠돌이 소식통", "부둣가 중개인",
	"시장통 귀동냥꾼", "밤거리 브로커", "얼굴 없는 제보자", "간판 없는 사무소",
]
const GONE_DAYS_MIN: int = 2
const GONE_DAYS_MAX: int = 4


## 사기 직후의 새 상태 행: 잠적 기간 + 재등장 시 쓸 새 이름(현재 이름과 다르게).
static func scam_vanish(current_name: String, today: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var alias: String = current_name
	while alias == current_name:
		alias = BROKER_ALIASES[rng.randi_range(0, BROKER_ALIASES.size() - 1)]
	return {
		"alias": alias,
		"gone_until": today + rng.randi_range(GONE_DAYS_MIN, GONE_DAYS_MAX),
	}


## 잠적 중 여부 — 잠적 중에는 거래할 수 없다.
static func broker_gone(state: Dictionary, source_id: String, today: int) -> bool:
	if not state.has(source_id):
		return false
	return today < int((state[source_id] as Dictionary).get("gone_until", 0))


## 현재 표시 이름 — 사기 이력이 있으면 바뀐 이름 (§7.3 "다른 이름으로 재등장")
static func broker_name(state: Dictionary, source: MarketSourceDef) -> String:
	if not state.has(String(source.id)):
		return source.display_name_ko
	return String((state[String(source.id)] as Dictionary).get(
		"alias", source.display_name_ko))
