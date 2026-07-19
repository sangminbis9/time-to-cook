extends GutTest
## 도시 정의 데이터 (PLAN.md §6): 한국 8 + 일본 8, 필드 유효성.

const KOREA: Array[StringName] = [
	&"city.korea.seoul", &"city.korea.busan", &"city.korea.incheon",
	&"city.korea.daegu", &"city.korea.daejeon", &"city.korea.gwangju",
	&"city.korea.ulsan", &"city.korea.jeju",
]
const JAPAN: Array[StringName] = [
	&"city.japan.tokyo", &"city.japan.yokohama", &"city.japan.osaka",
	&"city.japan.nagoya", &"city.japan.sapporo", &"city.japan.fukuoka",
	&"city.japan.kyoto", &"city.japan.kobe",
]


func test_all_16_cities_exist() -> void:
	for id: StringName in KOREA + JAPAN:
		assert_true(Defs.has_def(id), "누락 도시: %s" % id)


func test_city_fields_sane() -> void:
	for id: StringName in KOREA + JAPAN:
		var city: CityDef = Defs.get_def(id) as CityDef
		assert_gt(city.rent_per_day, 0, "%s 임대료" % id)
		assert_gte(city.entry_cost, 0, "%s 개설비" % id)
		assert_gt(city.demand, 0.0, "%s 수요" % id)
		assert_ne(city.display_name_ko, "", "%s 한글명" % id)


func test_incheon_is_free_start() -> void:
	var incheon: CityDef = Defs.get_def(&"city.korea.incheon") as CityDef
	assert_eq(incheon.entry_cost, 0, "시작 도시 인천은 개설비 0 (§6.4)")


func test_country_split() -> void:
	for id: StringName in KOREA:
		assert_eq((Defs.get_def(id) as CityDef).country_id, &"country.korea")
	for id: StringName in JAPAN:
		assert_eq((Defs.get_def(id) as CityDef).country_id, &"country.japan")

func test_preferred_recipes_valid() -> void:
	# 지역 선호 메뉴 (§19.1): 지정된 도시의 선호 레시피는 실존해야 한다
	var found: int = 0
	for id: StringName in KOREA + JAPAN:
		var city: CityDef = Defs.get_def(id) as CityDef
		if city.preferred_recipe == &"":
			continue
		found += 1
		assert_true(Defs.get_def(city.preferred_recipe) is RecipeDef,
			"%s 선호 레시피 실존" % id)
	assert_gt(found, 0, "선호 메뉴 도시 존재")


func test_order_candidates_weighting() -> void:
	# 선호 메뉴가 판매 중이면 후보에 2번 — 미판매면 가중 없음
	var s: LiveStore = LiveStore.new()
	var seoul: CityDef = Defs.get_def(&"city.korea.seoul") as CityDef
	assert_eq(GameServer.order_candidates(s, seoul).size(), 1,
		"양념대 없음: 후라이드 1종만 (가중 없음)")
	s.placements["t1"] = {"def_id": &"station.spicy_table", "tile": Vector2i(2, 2)}
	var pool: Array[RecipeDef] = GameServer.order_candidates(s, seoul)
	assert_eq(pool.size(), 3, "매운맛 판매 중: 선호 중복 포함 3장")
	var spicy_count: int = 0
	for recipe: RecipeDef in pool:
		if recipe.id == &"recipe.spicy_dakgangjeong":
			spicy_count += 1
	assert_eq(spicy_count, 2, "선호 레시피 2배 가중")
