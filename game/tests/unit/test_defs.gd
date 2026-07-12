extends GutTest
## 정의 데이터 무결성: 필수 ID 존재, 파이프라인 참조 유효성.

const EXPECTED_IDS: Array[StringName] = [
	&"item.raw_chicken",
	&"item.cut_chicken",
	&"item.breaded_chicken",
	&"item.dakgangjeong",
	&"item.burnt_food",
	&"station.counter",
	&"station.cutting_board",
	&"station.breading_table",
	&"station.fryer.basic",
	&"station.submit",
	&"station.ingredient_box",
	&"station.fridge.small",
	&"recipe.fried_dakgangjeong",
	&"fridge.small",
	&"city.korea.incheon",
]


func test_all_expected_ids_loaded() -> void:
	for id: StringName in EXPECTED_IDS:
		assert_true(Defs.has_def(id), "누락된 정의: %s" % id)


func test_station_references_valid() -> void:
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is not StationDef:
			continue
		var station: StationDef = def as StationDef
		for accepted: StringName in station.accepts:
			assert_true(Defs.has_def(accepted),
				"%s accepts에 없는 아이템: %s" % [id, accepted])
		for input_id: Variant in station.work_output.keys():
			var output_id: Variant = station.work_output[input_id]
			assert_true(Defs.has_def(StringName(String(input_id))),
				"%s work_output 입력이 없는 아이템: %s" % [id, input_id])
			assert_true(Defs.has_def(StringName(String(output_id))),
				"%s work_output 출력이 없는 아이템: %s" % [id, output_id])
		if station.burnt_output_id != StringName():
			assert_true(Defs.has_def(station.burnt_output_id))
		if station.dispenses_item_id != StringName():
			assert_true(Defs.has_def(station.dispenses_item_id))


func test_recipe_output_exists_and_submittable() -> void:
	var recipe: RecipeDef = Defs.get_def(&"recipe.fried_dakgangjeong") as RecipeDef
	assert_true(Defs.has_def(recipe.output_item_id))
	var output: ItemDef = Defs.get_def(recipe.output_item_id) as ItemDef
	assert_true(output.submittable, "레시피 완성품은 제출 가능해야 함")
	assert_gt(recipe.base_price, 0)


func test_fryer_timeline_sane() -> void:
	var fryer: StationDef = Defs.get_def(&"station.fryer.basic") as StationDef
	assert_gt(fryer.cook_seconds, 0.0)
	assert_gt(fryer.normal_window_seconds, 0.0)
	assert_gt(fryer.burn_after_seconds,
		fryer.cook_seconds + fryer.normal_window_seconds,
		"타는 시점은 정상 창 이후여야 함")
