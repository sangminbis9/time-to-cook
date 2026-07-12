class_name StationDef
extends Resource
## 설비 정의 (예: station.fryer.basic).
## 허용 아이템·작업 변환·조리 타임라인을 데이터로 기술한다.

enum Kind {
	COUNTER,          ## 일반 작업대: 아이템 1개, 제한 없는 놓기/집기/스왑
	CUTTING_BOARD,    ## 도마: K 반복으로 칼질
	BREADING_TABLE,   ## 튀김옷 작업대: K 한 번
	FRYER,            ## 튀김기: 시간 경과 조리
	SUBMIT,           ## 제출대: 완성 음식 제출
	INGREDIENT_BOX,   ## 재료 보관함: 재료 지급
	FRIDGE,           ## 냉장고 (전용 UI, P5)
}

@export var id: StringName
@export var display_name_ko: String = ""
@export var kind: Kind = Kind.COUNTER
@export var texture: Texture2D

## 놓을 수 있는 아이템 ID 목록. 비어 있으면 모든 아이템 허용 (일반 작업대).
@export var accepts: Array[StringName] = []

## 작업(K) 완료 시 변환: 입력 아이템 ID → 출력 아이템 ID
@export var work_output: Dictionary = {}

## 도마: 완성까지 필요한 칼질 횟수 (두 플레이어 입력 합산)
@export var required_cuts: int = 0

## 튀김기 타임라인 (초): 0~cook=덜익음, ~+normal_window=정상, ~burn_after=과조리, 이후=탄
@export var cook_seconds: float = 0.0
@export var normal_window_seconds: float = 0.0
@export var burn_after_seconds: float = 0.0
## 과조리/탄 상태로 꺼냈을 때 되는 아이템
@export var burnt_output_id: StringName

## 재료 보관함이 지급하는 아이템
@export var dispenses_item_id: StringName


func accepts_item(item_def_id: StringName) -> bool:
	if accepts.is_empty():
		return true
	return accepts.has(item_def_id)
