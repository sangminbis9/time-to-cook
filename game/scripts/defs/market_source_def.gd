class_name MarketSourceDef
extends Resource
## 시장 정보 획득 경로 정의 (PLAN.md §7.2–7.4).
## 정보상의 특성(가격·정확도·사기 확률)은 영구 고정 — 반복 거래로 변하지 않는다 (§7.3).

enum Kind { BROKER, ADVISOR }

@export var id: StringName
@export var display_name_ko: String = ""
@export var kind: Kind = Kind.BROKER
## 제공 정보 등급 (1=기본, 2=상세, 3=최고). 등급이 높을수록 항목이 많다.
@export var tier: int = 1
@export var price: int = 3000
## 사기 확률 (0.0~1.0). 자문은 0 (§7.4).
@export var scam_chance: float = 0.0
## 수치 오차율 (±). 0 = 정확.
@export var accuracy_error: float = 0.0
