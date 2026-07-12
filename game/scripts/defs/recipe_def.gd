class_name RecipeDef
extends Resource
## 레시피 정의 (예: recipe.fried_dakgangjeong).
## 음식은 특정 주문에 귀속되지 않고 레시피로 매칭된다 (PLAN.md §19.6).

@export var id: StringName
@export var display_name_ko: String = ""
## 이 레시피의 완성 아이템
@export var output_item_id: StringName
## 기본 판매가 (원)
@export var base_price: int = 0
