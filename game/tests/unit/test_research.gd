extends GutTest
## 연구 트리 정의 무결성 (PLAN.md §20).


func _all_research() -> Array[ResearchDef]:
	var result: Array[ResearchDef] = []
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is ResearchDef:
			result.append(def as ResearchDef)
	return result


func test_tree_present() -> void:
	assert_gt(_all_research().size(), 0, "연구 트리 존재")


func test_costs_positive() -> void:
	for def: ResearchDef in _all_research():
		assert_gt(def.cost_money, 0, "%s: 자금 비용" % def.id)
		assert_gt(def.cost_points, 0, "%s: 포인트 비용 (§20 공용 자금+포인트)" % def.id)
		assert_ne(def.display_name_ko, "", "%s: 표시 이름" % def.id)


func test_prereqs_exist_and_acyclic() -> void:
	# 선행 id가 실제 연구 정의를 가리키고, 순환이 없다 (§20 선행 조건)
	for def: ResearchDef in _all_research():
		for pre: StringName in def.prereq:
			assert_true(Defs.has_def(pre), "%s → %s 존재" % [def.id, pre])
			assert_true(Defs.get_def(pre) is ResearchDef,
				"%s: 선행은 연구 정의" % def.id)
		var visited: Dictionary = {}
		var stack: Array[StringName] = [def.id]
		while not stack.is_empty():
			var cur: StringName = stack.pop_back()
			assert_false(visited.has(cur) and cur == def.id and visited.size() > 0,
				"순환 없음")
			if visited.has(cur):
				continue
			visited[cur] = true
			var cur_def: ResearchDef = Defs.get_def(cur) as ResearchDef
			for pre: StringName in cur_def.prereq:
				assert_ne(pre, def.id, "%s: 자기 자신으로 순환 금지" % def.id)
				stack.append(pre)


func test_gate_targets_exist() -> void:
	# 게이트가 가리키는 연구·대상 정의가 실제로 존재한다
	for def_id: StringName in GameServer.STATION_RESEARCH.keys():
		assert_true(Defs.has_def(def_id))
		assert_true(Defs.has_def(StringName(
			String(GameServer.STATION_RESEARCH[def_id]))))
	assert_true(Defs.has_def(StringName(GameServer.PREVENTION_RESEARCH)))
	for ad_id: String in GameServer.AD_RESEARCH.keys():
		assert_true(CityEconomy.AD_PRODUCTS.has(ad_id), "광고 상품 존재")
		assert_true(Defs.has_def(StringName(String(GameServer.AD_RESEARCH[ad_id]))))
	for prefix: String in GameServer.COUNTRY_RESEARCH.keys():
		assert_true(Defs.has_def(StringName(
			String(GameServer.COUNTRY_RESEARCH[prefix]))))
	for rid: String in [GameServer.SUPPLIER_RESEARCH,
			GameServer.AUTO_ORDER_RESEARCH, GameServer.KNIFE_RESEARCH]:
		assert_true(Defs.has_def(StringName(rid)), "%s 정의 존재" % rid)


func test_every_category_has_nodes() -> void:
	# §20 카테고리 6종 전부 노드 보유 (P32 물류·조리, P36 장비로 완성)
	var seen: Dictionary = {}
	for def: ResearchDef in _all_research():
		seen[def.category] = true
	for category: ResearchDef.Category in ResearchDef.Category.values():
		assert_true(seen.has(category), "카테고리 %d 노드 존재" % category)


func test_fridge_plus_expands_new_store() -> void:
	# 냉장고 증설 (§20 장비): 연구 후 신규 매장은 +2칸으로 시작
	var base: int = LiveStore.create(GameServer.layout).fridge.slots.size()
	FranchiseState.research[GameServer.FRIDGE_RESEARCH] = true
	var expanded: int = LiveStore.create(GameServer.layout).fridge.slots.size()
	FranchiseState.research.erase(GameServer.FRIDGE_RESEARCH)
	assert_eq(expanded, base + GameServer.FRIDGE_BONUS_SLOTS, "슬롯 +2")


func test_logistics_cost_effects() -> void:
	# 물류 확장 (§21.2): 물류센터=한국만 -50, 글로벌=일본까지, 운송비=반값
	var kr: String = "city.korea.incheon"
	var jp: String = "city.japan.osaka"
	FranchiseState.research[GameServer.SUPPLIER_RESEARCH] = true
	assert_eq(GameServer.effective_ingredient_cost(kr), 400, "공급업체 단가")
	FranchiseState.research[GameServer.LOGI_CENTER_RESEARCH] = true
	assert_eq(GameServer.effective_ingredient_cost(kr), 350, "물류센터: 한국 -50")
	assert_eq(GameServer.effective_ingredient_cost(jp), 400, "물류센터: 일본 미적용")
	FranchiseState.research[GameServer.LOGI_GLOBAL_RESEARCH] = true
	assert_eq(GameServer.effective_ingredient_cost(jp), 350, "글로벌: 일본도 -50")
	assert_eq(GameServer.transfer_cost(kr, jp), 8000, "해외 재배치 기본")
	FranchiseState.research[GameServer.TRANSPORT_RESEARCH] = true
	assert_eq(GameServer.transfer_cost(kr, jp), 4000, "운송비 최적화: 반값")
	assert_eq(GameServer.transfer_cost(kr, "city.korea.seoul"), 1500, "국내도 반값")
	for rid: String in [GameServer.SUPPLIER_RESEARCH, GameServer.LOGI_CENTER_RESEARCH,
			GameServer.LOGI_GLOBAL_RESEARCH, GameServer.TRANSPORT_RESEARCH]:
		FranchiseState.research.erase(rid)
