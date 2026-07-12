extends Node
## 정의 데이터 레지스트리.
## res://data/ 아래의 모든 .tres 정의 리소스를 로드해 안정 문자열 ID로 인덱싱한다.
## 중복 ID나 잘못된 리소스는 즉시 실패시킨다 (에디터 검증 도구 역할, PLAN.md §31).

const DATA_ROOT: String = "res://data"

var _by_id: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	_by_id.clear()
	_scan_dir(DATA_ROOT)


func get_def(id: StringName) -> Resource:
	var def: Resource = _by_id.get(id)
	assert(def != null, "정의 ID를 찾을 수 없음: %s" % id)
	return def


func has_def(id: StringName) -> bool:
	return _by_id.has(id)


func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: StringName in _by_id.keys():
		ids.append(key)
	return ids


func _scan_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full)
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			_register(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _register(res_path: String) -> void:
	var res: Resource = load(res_path)
	assert(res != null, "정의 리소스 로드 실패: %s" % res_path)
	var id_variant: Variant = res.get("id")
	assert(id_variant != null and String(id_variant) != "",
		"정의 리소스에 id가 없음: %s" % res_path)
	var id: StringName = StringName(String(id_variant))
	assert(not _by_id.has(id), "중복 정의 ID: %s (%s)" % [id, res_path])
	_by_id[id] = res
