class_name CityDef
extends Resource
## 도시 정의 (예: city.korea.incheon). 수직 슬라이스는 인천만 사용.
## 경제·수요 필드는 P9~P10에서 확장.

@export var id: StringName
@export var display_name_ko: String = ""
@export var country_id: StringName
@export var rent_per_day: int = 0
## 매장 개설 비용 (시작 도시 인천은 0)
@export var entry_cost: int = 0
## 수요 계수 — 자동화 매장 통계 매출과 향후 주문 빈도에 반영 (§6.6)
@export var demand: float = 1.0
## 숨김 값 (§6.6): 시장 조사로만 확인 가능
@export var price_sensitivity: float = 1.0
@export var competition: float = 1.0
## 추천 재조사 주기 (일, §7.5)
@export var recheck_days: int = 7
