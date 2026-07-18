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


func test_logistics_and_cooking_have_nodes() -> void:
	# 물류·조리 기술 카테고리 채움 (P32 — 장비 카테고리는 아직 빈 슬라이스)
	var seen: Dictionary = {}
	for def: ResearchDef in _all_research():
		seen[def.category] = true
	assert_true(seen.has(ResearchDef.Category.LOGISTICS), "물류 노드 존재")
	assert_true(seen.has(ResearchDef.Category.COOKING), "조리 기술 노드 존재")
