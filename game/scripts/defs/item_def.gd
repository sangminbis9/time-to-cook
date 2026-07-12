class_name ItemDef
extends Resource
## 아이템 정의. 안정 문자열 ID 기반 (예: item.raw_chicken).

@export var id: StringName
@export var display_name_ko: String = ""
@export var texture: Texture2D
## 냉장고 보관 가능 여부 (가열 시작 전 재료만 true — PLAN.md §17.2)
@export var fridge_storable: bool = false
## 제출대에 제출 가능한 완성 음식인지
@export var submittable: bool = false
