extends GutTest
## ASCII 매장 레이아웃 파서.


func test_incheon_layout_parses() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	assert_eq(layout.width, 13)
	assert_eq(layout.height, 9)
	assert_eq(layout.spawn_tiles.size(), 2, "플레이어 스폰 2개")


func test_incheon_has_all_slice_stations() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	var def_ids: Array[StringName] = []
	for key: StringName in layout.stations.keys():
		var entry: Dictionary = layout.stations[key]
		def_ids.append(entry["def_id"])
	for required: StringName in [
		&"station.counter", &"station.cutting_board", &"station.breading_table",
		&"station.fryer.basic", &"station.submit", &"station.ingredient_box",
		&"station.fridge.small",
	]:
		assert_true(def_ids.has(required), "누락 설비: %s" % required)


func test_station_defs_exist() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	for key: StringName in layout.stations.keys():
		var entry: Dictionary = layout.stations[key]
		assert_true(Defs.has_def(entry["def_id"]))


func test_station_tiles_not_walkable() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	for tile: Vector2i in layout.station_tiles().keys():
		assert_false(layout.is_walkable(tile), "설비 타일은 이동 불가")


func test_spawn_tiles_walkable() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	for order: int in layout.spawn_tiles.keys():
		assert_true(layout.is_walkable(layout.spawn_tiles[order]))


func test_for_city_tiers_by_entry_cost() -> void:
	# 도시별 템플릿 (§6.6): 개설비 싼 도시=소형, 비싼 대도시=대형, 그 외=표준
	assert_eq(StoreLayout.for_city("city.korea.incheon").width, 13, "인천 표준")
	assert_eq(StoreLayout.for_city("city.korea.busan").width, 13, "부산 표준")
	assert_eq(StoreLayout.for_city("city.korea.gwangju").width, 12,
		"광주(개설비 5만) 소형")
	assert_eq(StoreLayout.for_city("city.korea.seoul").width, 15,
		"서울(개설비 12만) 대형")
	assert_eq(StoreLayout.for_city("").width, 13, "미지정은 표준 폴백")


func test_all_templates_share_station_keys() -> void:
	# 직원 고정 경로(d_2·c_4·b_2·c_3 등)가 어느 매장에서든 유효해야 한다
	var standard: Array = StoreLayout.incheon().stations.keys()
	standard.sort()
	for rows: Array[String] in [
		StoreLayout.COMPACT_SMALL, StoreLayout.WIDE_LARGE,
	]:
		var layout: StoreLayout = StoreLayout.parse(rows)
		var keys: Array = layout.stations.keys()
		keys.sort()
		assert_eq(keys, standard, "템플릿 간 설비 키 집합 동일")
		assert_eq(layout.spawn_tiles.size(), 2, "플레이어 스폰 2개")
		assert_true(layout.is_walkable(Vector2i(2, 2)),
			"직원 스폰 칸(2,2)은 어느 템플릿에서도 바닥")


func test_unique_station_keys() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	# 같은 종류 설비 여러 개는 f_1, f_2처럼 고유 키를 가진다
	var fryers: int = 0
	for key: StringName in layout.stations.keys():
		var entry: Dictionary = layout.stations[key]
		if entry["def_id"] == &"station.fryer.basic":
			fryers += 1
	assert_eq(fryers, 2, "인천 매장 튀김기 2대")
