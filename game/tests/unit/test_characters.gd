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
	var specialties: Dictionary = {}
	for c: CharacterDef in chars:
		assert_false(names.has(c.display_name_ko), "%s: 이름 중복 없음" % c.id)
		names[c.display_name_ko] = true
		specialties[c.specialty] = true
		assert_ne(c.skill_name_ko, "", "%s: 스킬 이름" % c.id)
		assert_gt(c.upgrade_costs.size(), 0, "%s: 업그레이드 트리" % c.id)
		assert_not_null(c.portrait, "%s: 선택 화면 초상화" % c.id)
		assert_ne(c.archetype_title_ko, "", "%s: 역할 제목" % c.id)
		assert_ne(c.personality_ko, "", "%s: 성격" % c.id)
		assert_ne(c.passive_description_ko, "", "%s: 패시브 설명" % c.id)
		assert_ne(c.skill_description_ko, "", "%s: 스킬 설명" % c.id)
		assert_ne(c.balance_note_ko, "", "%s: 트레이드오프 설명" % c.id)
	assert_eq(specialties.size(), 3, "전처리·운반·서비스 전문이 모두 존재")


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


func test_balanced_role_limits() -> void:
	var mint: CharacterDef = Defs.get_def(&"char.mint") as CharacterDef
	var apricot: CharacterDef = Defs.get_def(&"char.apricot") as CharacterDef
	var basil: CharacterDef = Defs.get_def(&"char.basil") as CharacterDef
	assert_eq(mint.cut_per_work, 2, "전처리 패시브는 기본의 2배")
	assert_between(apricot.move_speed_mult, 1.1, 1.2, "이동 패시브는 10~20%")
	assert_between(basil.submit_bonus_mult, 1.03, 1.08, "서비스 패시브는 3~8%")
	assert_lte(basil.submit_bonus_mult * basil.skill_submit_mult, 1.35,
		"서비스 액티브 포함 매출 배율 상한")
	assert_eq(mint.move_speed_mult, 1.0, "미트는 이동 보너스 없음")
	assert_eq(apricot.submit_bonus_mult, 1.0, "살구는 매출 보너스 없음")
	assert_eq(basil.cut_per_work, 1, "바질은 칼질 보너스 없음")


func test_created_profile_roundtrip() -> void:
	FranchiseState.begin_new_profile("char.basil", "초록별")
	var saved: Dictionary = FranchiseState.to_dict()
	FranchiseState.begin_new_profile("char.mint", "임시")
	FranchiseState.from_dict(saved)
	assert_eq(String(FranchiseState.character_picks["1"]), "char.basil")
	assert_eq(String(FranchiseState.character_names["1"]), "초록별")
	assert_ne(String(FranchiseState.character_picks["2"]), "char.basil",
		"게스트 기본 캐릭터는 호스트와 중복되지 않음")
	FranchiseState.reset()
