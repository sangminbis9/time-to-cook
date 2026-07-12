class_name CityEconomy
extends RefCounted
## 동적 경제 (PLAN.md §8.1). 순수 함수 — 단위 테스트 대상.
##
## 도시 정의(CityDef)는 불변이고, 런타임 변동은 도시별 수요 배율(demand_mult)로
## 표현한다. 배율은 매일 점진적으로 드리프트하며 세이브에 저장된다.
## 시장 정보(§7)는 획득 시점의 배율이 반영된 스냅샷이므로,
## 시간이 지나면 현실과 어긋난다 — 재조사(§7.5)의 실질적 이유.

## 하루 드리프트 폭 (±)
const DRIFT_RANGE: float = 0.05
const MULT_MIN: float = 0.6
const MULT_MAX: float = 1.6
## 저가 전략이 받는 최대 수요 보너스
const ACCEPTANCE_MAX: float = 1.25


static func demand_mult(econ: Dictionary, city_id: String) -> float:
	return float(econ.get(city_id, 1.0))


## 매일 새 날 진입 시 전 도시 배율을 점진 드리프트 (§8.1 "일반 변화는 점진적")
static func drifted(econ: Dictionary, city_ids: Array[String],
		rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = {}
	for city_id: String in city_ids:
		var mult: float = demand_mult(econ, city_id)
		mult *= 1.0 + rng.randf_range(-DRIFT_RANGE, DRIFT_RANGE)
		result[city_id] = clampf(mult, MULT_MIN, MULT_MAX)
	return result


## 유효 수요: 정의 수요 × 변동 배율 × 이벤트 배율 ÷ 경쟁 감쇠 (§6.6, §8.1)
static func effective_demand(city: CityDef, mult: float,
		event_demand: float = 1.0) -> float:
	return city.demand * mult * event_demand / (0.5 + 0.5 * city.competition)


# ── 급격 경제 이벤트 (§8.1 후반, §23.2) ─────────────────────────────

## 하루 이벤트 발생 확률 (도시당)
const EVENT_DAILY_CHANCE: float = 0.08

## 활성 이벤트 상태: city_id → {"event_id": String, "days_left": int}


## 새 날 진입 시 이벤트 진행: 지속 일수 감소·만료, 무이벤트 도시에 확률 발생.
## chance를 인자로 받아 테스트에서 결정적으로 제어할 수 있다.
static func tick_events(events: Dictionary, city_ids: Array[String],
		rng: RandomNumberGenerator,
		chance: float = EVENT_DAILY_CHANCE) -> Dictionary:
	var result: Dictionary = {}
	var defs: Array[EconEventDef] = _event_defs()
	for city_id: String in city_ids:
		if events.has(city_id):
			var active: Dictionary = events[city_id]
			var days_left: int = int(active.get("days_left", 0)) - 1
			if days_left > 0:
				result[city_id] = {
					"event_id": active["event_id"], "days_left": days_left,
				}
			continue  # 만료 다음 날은 발생 없음 (연속 방지)
		if defs.is_empty() or rng.randf() >= chance:
			continue
		var picked: EconEventDef = _pick_weighted(defs, rng)
		result[city_id] = {
			"event_id": String(picked.id), "days_left": picked.duration_days,
		}
	return result


## 도시의 활성 이벤트 수요 배율 (없으면 1.0)
static func event_demand_factor(events: Dictionary, city_id: String) -> float:
	var def: EconEventDef = _active_event_def(events, city_id)
	return def.demand_factor if def != null else 1.0


## 도시의 활성 이벤트 재료비 배율 (없으면 1.0)
static func event_cost_factor(events: Dictionary, city_id: String) -> float:
	var def: EconEventDef = _active_event_def(events, city_id)
	return def.ingredient_cost_factor if def != null else 1.0


static func _active_event_def(events: Dictionary, city_id: String) -> EconEventDef:
	if not events.has(city_id):
		return null
	var event_id: StringName = StringName(String(
		(events[city_id] as Dictionary).get("event_id", "")))
	if not Defs.has_def(event_id):
		return null
	return Defs.get_def(event_id) as EconEventDef


static func _event_defs() -> Array[EconEventDef]:
	var result: Array[EconEventDef] = []
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is EconEventDef:
			result.append(def as EconEventDef)
	return result


static func _pick_weighted(defs: Array[EconEventDef],
		rng: RandomNumberGenerator) -> EconEventDef:
	var total: float = 0.0
	for def: EconEventDef in defs:
		total += def.weight
	var roll: float = rng.randf() * total
	for def: EconEventDef in defs:
		roll -= def.weight
		if roll <= 0.0:
			return def
	return defs[defs.size() - 1]


## 가격 수용률 (§6.6 가격 민감도): 기본가 대비 인상분만큼 손님이 줄고,
## 소폭 할인은 보너스(상한 1.25). 0이면 주문이 오지 않는다.
static func acceptance(price: int, base_price: int, sensitivity: float) -> float:
	var delta: float = float(price - base_price) / maxf(1.0, float(base_price))
	return clampf(1.0 - sensitivity * delta, 0.0, ACCEPTANCE_MAX)
