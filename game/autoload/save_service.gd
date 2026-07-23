extends Node
## 버전 필드를 포함한 JSON 세이브. 호스트만 기록한다.
## 네트워크 전체 스냅샷과 동일한 직렬화 코드를 공유한다.
##
## P0 골격 — 스키마 조립은 P6에서 완성.

const SAVE_DIR: String = "user://saves"
const SAVE_VERSION: int = 4
const MAX_SLOTS: int = 3

## 현재 플레이 중인 슬롯. 0 = 자동 저장 비활성 (타이틀 화면 등).
var current_slot: int = 0


func save_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func write_save(slot: int, snapshot: Dictionary) -> Error:
	# UI는 1~MAX_SLOTS만 사용하지만 테스트·마이그레이션 도구의 격리 슬롯은 허용한다.
	if slot < 1:
		return ERR_INVALID_PARAMETER
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


func any_save() -> bool:
	for slot: int in range(1, MAX_SLOTS + 1):
		if has_save(slot):
			return true
	return false


## 슬롯 선택 화면에서 전체 런타임 상태를 만들지 않고 표시할 최소 메타데이터.
func slot_summary(slot: int) -> Dictionary:
	var data: Dictionary = read_save(slot)
	if data.is_empty():
		return {}
	var franchise: Dictionary = data.get("franchise", {})
	var picks: Dictionary = franchise.get("character_picks", {})
	var names: Dictionary = franchise.get("character_names", {})
	var clock: Dictionary = data.get("clock", {})
	return {
		"slot": slot,
		"character_id": String(picks.get("1", "char.mint")),
		"profile_name": String(names.get("1", "")).strip_edges(),
		"day": int(clock.get("day", 1)),
		"money": int(franchise.get("money", 0)),
	}


func valid_profile_name(profile_name: String) -> bool:
	var clean: String = profile_name.strip_edges()
	if clean.is_empty() or clean.length() > 12:
		return false
	for index: int in range(clean.length()):
		var code: int = clean.unicode_at(index)
		if code < 32 or code == 127:
			return false
	return true


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
	# v1 → v2: 다매장 필드(franchise.stores) 추가 — 기본값 자동 승격, 변환 불필요.
	# v2 → v3 (독립 매장 이동): 최상위에 평평하게 있던 활성 매장 상태를
	# stores[활성 도시]로 감싸고, 플레이어별 현재 도시(peer_city)를 추가한다.
	if version <= 2 and not data.has("stores"):
		var franchise: Dictionary = data.get("franchise", {})
		var city: String = String(franchise.get(
			"active_city", GameServer.START_CITY))
		data["stores"] = {city: {
			"grid": data.get("grid", {}),
			"stations": data.get("stations", {}),
			"fridge": data.get("fridge", {}),
			"fridge_lock": 0,
			"employees": data.get("employees", {}),
			"stock": data.get("ingredient_stock", 0),
			"orders": data.get("orders", {}),
			"revenue_today": 0,
		}}
		data["peer_city"] = {"1": city, "2": city}
	# v3 → v4: 캐릭터 생성 프로필 이름. 구세이브는 캐릭터 고유 이름으로 표시한다.
	if version <= 3:
		var franchise: Dictionary = data.get("franchise", {})
		if not franchise.has("character_names"):
			franchise["character_names"] = {}
		data["franchise"] = franchise
	data["version"] = SAVE_VERSION
	return data
