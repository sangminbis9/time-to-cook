extends Node
## 버전 필드를 포함한 JSON 세이브. 호스트만 기록한다.
## 네트워크 전체 스냅샷과 동일한 직렬화 코드를 공유한다.
##
## P0 골격 — 스키마 조립은 P6에서 완성.

const SAVE_DIR: String = "user://saves"
const SAVE_VERSION: int = 2

## 현재 플레이 중인 슬롯. 0 = 자동 저장 비활성 (타이틀 화면 등).
var current_slot: int = 0


func save_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func write_save(slot: int, snapshot: Dictionary) -> Error:
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_err != OK:
		return dir_err
	var file: FileAccess = FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	snapshot["version"] = SAVE_VERSION
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	return OK


func read_save(slot: int) -> Dictionary:
	if not FileAccess.file_exists(save_path(slot)):
		return {}
	var file: FileAccess = FileAccess.open(save_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is not Dictionary:
		return {}
	return _migrate(json.data as Dictionary)


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(save_path(slot))


## 자동 저장 (§25 추천 시점에서 GameServer가 호출). 호스트만 기록.
func autosave() -> void:
	if current_slot <= 0 or not multiplayer.is_server():
		return
	var err: Error = write_save(current_slot, GameServer.build_save())
	if err != OK:
		push_warning("자동 저장 실패: %d" % err)


## 슬롯 불러오기 → GameServer에 적용. 성공 여부 반환.
func load_game(slot: int) -> bool:
	var data: Dictionary = read_save(slot)
	if data.is_empty():
		return false
	current_slot = slot
	GameServer.load_save(data)
	return true


func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	assert(version <= SAVE_VERSION, "세이브 버전이 게임보다 높음: %d" % version)
	# v1 → v2: 다매장 필드(franchise.stores / active_city) 추가.
	# v1 세이브는 단일 인천 매장이므로 FranchiseState.from_dict의 기본값
	# (stores={}, active_city=인천)으로 자동 승격된다 — 변환 불필요.
	return data
