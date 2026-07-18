extends GutTest
## 양념 변형 데이터 정합 (PLAN.md §19.1): 양념대 → 레시피 매핑 무결성.


func test_table_output_matches_recipe() -> void:
	for table_id: StringName in GameServer.SAUCE_TABLE_RECIPES.keys():
		var table: StationDef = Defs.get_def(table_id) as StationDef
		var recipe: RecipeDef = Defs.get_def(
			GameServer.SAUCE_TABLE_RECIPES[table_id]) as RecipeDef
		assert_not_null(table, "%s 존재" % table_id)
		assert_not_null(recipe)
		assert_eq(StringName(table.work_output.get(&"item.dakgangjeong", &"")),
			recipe.output_item_id,
			"%s: 변환 출력이 레시피 출력과 일치" % table_id)
		var item: ItemDef = Defs.get_def(recipe.output_item_id) as ItemDef
		assert_true(item.submittable, "%s: 출력은 제출 가능" % recipe.output_item_id)
		assert_true(GameServer.STATION_PRICES.has(table_id), "구매 목록 포함")
		assert_true(GameServer.STATION_RESEARCH.has(table_id), "연구 게이트 존재")


func test_variant_prereq_is_sauce_base() -> void:
	# 변형 양념은 기본 양념 연구가 선행 (§19.1 "이후 연구로 추가")
	for rid: StringName in [&"research.spicy_sauce", &"research.soy_sauce"]:
		var def: ResearchDef = Defs.get_def(rid) as ResearchDef
		assert_true(def.prereq.has(&"research.sauce_base"), "%s 선행" % rid)
