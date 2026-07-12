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


func to_title(notice: String = "") -> void:
	pending_notice = notice
	_change(TITLE)


func to_save_select() -> void:
	_change(SAVE_SELECT)


func to_character_select() -> void:
	_change(CHARACTER_SELECT)


func to_store() -> void:
	_change(STORE_GAMEPLAY)


func _change(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	assert(err == OK, "씬 전환 실패: %s" % path)
