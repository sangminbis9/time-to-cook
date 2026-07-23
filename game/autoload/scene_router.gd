extends Node
## 씬 전환 단일 창구. 씬 경로 문자열 하드코딩을 이 파일 하나로 한정한다.

const TITLE: String = "res://scenes/title.tscn"
const SAVE_SELECT: String = "res://scenes/save_select.tscn"
const CHARACTER_SELECT: String = "res://scenes/character_select.tscn"
const STORE_GAMEPLAY: String = "res://scenes/store/store_gameplay.tscn"

## 타이틀로 돌아갈 때 표시할 안내 (예: "호스트가 나갔습니다")
var pending_notice: String = ""
## 매장 씬이 setup_store 후 적용할 세이브 슬롯 (0 = 없음)
var pending_load_slot: int = 0
## 세이브 선택 화면 동작: "new" 또는 "continue".
var save_select_mode: StringName = &"continue"
## 캐릭터 생성 화면이 사용할 슬롯.
var pending_save_slot: int = 0
## 새 캐릭터 생성 직후 첫 매장 초기화가 끝나면 즉시 저장한다.
var pending_new_save: bool = false


func to_title(notice: String = "") -> void:
	pending_notice = notice
	_change(TITLE)


func to_save_select(mode: StringName = &"continue") -> void:
	save_select_mode = mode
	_change(SAVE_SELECT)


func to_character_select(slot: int) -> void:
	pending_save_slot = slot
	_change(CHARACTER_SELECT)


func to_store() -> void:
	_change(STORE_GAMEPLAY)


func _change(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	assert(err == OK, "씬 전환 실패: %s" % path)
