class_name CharacterDef
extends Resource
## 플레이어 캐릭터 정의 (PLAN.md §11). 능력은 캐릭터의 직접 행동에만 영향(§11.3).

enum Specialty { PREP, TRANSPORT, SERVICE }

@export var id: StringName
@export var display_name_ko: String = ""
@export var specialty: Specialty = Specialty.PREP
@export var portrait: Texture2D
@export var accent_color: Color = Color.WHITE
@export var archetype_title_ko: String = ""
@export_multiline var personality_ko: String = ""
## 배경 설정 (§11.2)
@export_multiline var backstory_ko: String = ""
## 선택 화면에 그대로 노출하는 역할·트레이드오프 설명.
@export_multiline var passive_description_ko: String = ""
@export_multiline var skill_description_ko: String = ""
@export_multiline var balance_note_ko: String = ""

## 패시브: 칼질(K) 1회당 진행 횟수
@export var cut_per_work: int = 1
## 패시브: 이동속도 배율
@export var move_speed_mult: float = 1.0
## 패시브: 본인이 제출한 주문의 매출 배율 (§11.3 직접 행동)
@export var submit_bonus_mult: float = 1.0

## 액티브 스킬 (§11.4): 고정 지속·수동 취소 불가·종료 후 쿨다운
@export var skill_name_ko: String = ""
@export var skill_duration: float = 8.0
@export var skill_cooldown: float = 20.0
## 액티브 중 칼질 1회당 추가 진행
@export var skill_cut_bonus: int = 0
## 액티브 중 이동속도 추가 배율
@export var skill_speed_mult: float = 1.0
## 액티브 중 본인 제출 매출 추가 배율
@export var skill_submit_mult: float = 1.0

## 영구 업그레이드 (§11.5): 레벨별 비용, 레벨당 스킬 지속 +초. 환불 없음.
@export var upgrade_costs: Array[int] = [20000, 40000]
@export var upgrade_duration_bonus: float = 3.0

## 시장 정보 무료 획득 능력 (§7.2-③): 빈 값이면 능력 없음.
## 지정 시 해당 정보 경로 수준의 보고서를 무료로 얻는다 — 사기 없음,
## paid_total에 포함하지 않아 상위 등급 할인에도 반영되지 않는다 (§7.6).
@export var info_source: StringName = &""
@export var info_name_ko: String = ""
@export var info_cooldown_days: int = 3
