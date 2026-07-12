extends GutTest
## ASCII 매장 레이아웃 파서.


func test_incheon_layout_parses() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	assert_eq(layout.width, 20)
	assert_eq(layout.height, 11)
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


func test_unique_station_keys() -> void:
	var layout: StoreLayout = StoreLayout.incheon()
	# 같은 종류 설비 여러 개는 f_1, f_2처럼 고유 키를 가진다
	var fryers: int = 0
	for key: StringName in layout.stations.keys():
		var entry: Dictionary = layout.stations[key]
		if entry["def_id"] == &"station.fryer.basic":
			fryers += 1
	assert_eq(fryers, 2, "인천 매장 튀김기 2대")
