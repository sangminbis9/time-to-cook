extends GutTest
## 캐릭터 정의·서비스 보너스 (PLAN.md §11).


func _all_characters() -> Array[CharacterDef]:
	var result: Array[CharacterDef] = []
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is CharacterDef:
			result.append(def as CharacterDef)
	return result


func test_three_characters() -> void:
	var chars: Array[CharacterDef] = _all_characters()
	assert_gte(chars.size(), 3, "캐릭터 3종 이상")
	var names: Dictionary = {}
	for c: CharacterDef in chars:
		assert_false(names.has(c.display_name_ko), "%s: 이름 중복 없음" % c.id)
		names[c.display_name_ko] = true
		assert_ne(c.skill_name_ko, "", "%s: 스킬 이름" % c.id)
		assert_gt(c.upgrade_costs.size(), 0, "%s: 업그레이드 트리" % c.id)


func test_default_picks_valid() -> void:
	for slot: String in GameServer.DEFAULT_PICKS.keys():
		var id: StringName = StringName(String(GameServer.DEFAULT_PICKS[slot]))
		assert_true(Defs.get_def(id) is CharacterDef, "기본 배정 %s 존재" % id)


func test_service_bonus_math() -> void:
	# 바질(서비스 전문): 제출 매출 ×1.05 — 스킬 비활성(준비 단계) 기준
	var basil: CharacterDef = Defs.get_def(&"char.basil") as CharacterDef
	assert_not_null(basil, "바질 존재")
	assert_gt(basil.submit_bonus_mult, 1.0, "제출 패시브 존재")
	assert_gt(basil.skill_submit_mult, 1.0, "제출 스킬 배율 존재")
	FranchiseState.character_picks["1"] = "char.basil"
	assert_eq(GameServer._with_service_bonus(1, 1000), 1050, "1000원 → 1050원")
	FranchiseState.character_picks.clear()
	# 기본 미트는 배율 1.0 — 가격 불변
	assert_eq(GameServer._with_service_bonus(1, 1000), 1000, "미트: 보정 없음")
