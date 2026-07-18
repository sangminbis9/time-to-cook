class_name ResearchDef
extends Resource
## 연구 노드 정의 (PLAN.md §20). 전체 트리 처음부터 공개,
## 공용 자금 + 연구 포인트로 구매, 즉시 적용, 선행 조건 존재.

enum Category { FOOD, COOKING, EQUIPMENT, OPERATION, LOGISTICS, MARKETING }

@export var id: StringName
@export var display_name_ko: String = ""
@export var category: Category = Category.OPERATION
## 해금 내용 설명 (트리에 항상 공개)
@export_multiline var desc_ko: String = ""
@export var cost_money: int = 10000
@export var cost_points: int = 1
## 선행 연구 id — 전부 보유해야 구매 가능
@export var prereq: Array[StringName] = []
