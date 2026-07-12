class_name RefrigeratorDef
extends Resource
## 냉장고 정의 (예: fridge.small). 비쌀수록 슬롯이 많다 (PLAN.md §17.3).

@export var id: StringName
@export var display_name_ko: String = ""
@export var slot_count: int = 3
@export var price: int = 0
