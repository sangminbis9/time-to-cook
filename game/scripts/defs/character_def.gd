class_name CharacterDef
extends Resource
## 플레이어 캐릭터 정의 (PLAN.md §11). 능력은 캐릭터의 직접 행동에만 영향(§11.3).
## 슬라이스: 캐릭터 선택 씬 없이 피어별 자동 배정 (호스트=미트, 게스트=살구).

enum Specialty { PREP, TRANSPORT }

@export var id: StringName
@export var display_name_ko: String = ""
@export var specialty: Specialty = Specialty.PREP
## 배경 설정 (§11.2)
@export_multiline var backstory_ko: String = ""

## 패시브: 칼질(K) 1회당 진행 횟수
@export var cut_per_work: int = 1
## 패시브: 이동속도 배율
@export var move_speed_mult: float = 1.0

## 액티브 스킬 (§11.4): 고정 지속·수동 취소 불가·종료 후 쿨다운
@export var skill_name_ko: String = ""
@export var skill_duration: float = 8.0
@export var skill_cooldown: float = 20.0
## 액티브 중 칼질 1회당 추가 진행
@export var skill_cut_bonus: int = 0
## 액티브 중 이동속도 추가 배율
@export var skill_speed_mult: float = 1.0

## 영구 업그레이드 (§11.5): 레벨별 비용, 레벨당 스킬 지속 +초. 환불 없음.
@export var upgrade_costs: Array[int] = [20000, 40000]
@export var upgrade_duration_bonus: float = 3.0
