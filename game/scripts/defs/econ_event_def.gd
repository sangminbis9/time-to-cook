class_name EconEventDef
extends Resource
## 도시 경제 이벤트 정의 (PLAN.md §8.1 급격 변화, §23.2).
## 이벤트는 공개 정보다 — 시장 조사 없이도 보인다 (§7.1).

@export var id: StringName
@export var display_name_ko: String = ""
## 지속 중 수요 배율 (호황 1.4, 불황 0.6 …)
@export var demand_factor: float = 1.0
## 지속 중 재료 단가 배율 (공급 충격 1.6 …)
@export var ingredient_cost_factor: float = 1.0
## 지속 일수
@export var duration_days: int = 3
## 발생 가중치 (다른 이벤트 대비 상대 확률)
@export var weight: float = 1.0
