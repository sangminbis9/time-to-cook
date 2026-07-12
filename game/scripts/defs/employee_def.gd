class_name EmployeeDef
extends Resource
## 직원 아키타입 정의 (PLAN.md §10). 수직 슬라이스+1: 전처리 직원.
## 능력치는 채용 시 고정 — 레벨업·교육 성장 없음 (§10.2).

enum Role { PREP, COOK, SERVE, CASHIER, CLEAN, MAINTAIN, MANAGER }

@export var id: StringName
@export var display_name_ko: String = ""
@export var role: Role = Role.PREP
## 채용 비용 (원)
@export var hire_cost: int = 5000
## 일급 (원) — 매 영업일 정산 시 자동 지급 (§10.4)
@export var wage_per_day: int = 3000
## 칼질 등 작업 1회 간격 (초)
@export var work_interval: float = 1.2
## 이동 속도 (타일/초)
@export var move_speed: float = 2.5
