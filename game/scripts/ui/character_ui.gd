class_name CharacterUi
extends PanelContainer
## 캐릭터 팝업 (준비 단계 전용): 저장된 프로필·특성 + 영구 업그레이드 구매 (§11).
## HUD 우측 상단 [캐릭터] 버튼으로 연다.

var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("modal_ui")
	theme = PixelUi.theme()
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -150.0
	offset_right = 150.0
	offset_top = -150.0
	offset_bottom = 150.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(PopupTitle.build(self, "캐릭터  (Esc: 닫기)"))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	root.add_child(_rows)

	GameServer.ready_state_changed.connect(_refresh)
	GameServer.character_changed.connect(_refresh)
	FranchiseState.money_changed.connect(func(_m: int) -> void: _refresh())
	GameClock.phase_changed.connect(func(phase: GameClock.Phase) -> void:
		if phase != GameClock.Phase.PREP:
			queue_free())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	var peer: int = multiplayer.get_unique_id()
	var c: CharacterDef = GameServer.character_of(peer)
	var level: int = FranchiseState.char_upgrade_level(String(c.id))
	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = c.portrait
	_rows.add_child(portrait)
	_add_line("%s · %s — 전문: %s" % [
		GameServer.character_name_of(peer), c.display_name_ko, _specialty_ko(c)])
	_add_line(c.personality_ko)
	_add_line(c.backstory_ko)
	if c.cut_per_work > 1:
		_add_line("패시브: 칼질 1회당 %d회 진행" % c.cut_per_work)
	if c.move_speed_mult > 1.0:
		_add_line("패시브: 이동속도 +%d%%" % int((c.move_speed_mult - 1.0) * 100))
	if c.submit_bonus_mult > 1.0:
		_add_line("패시브: 본인 제출 매출 +%d%%" % int(
			roundf((c.submit_bonus_mult - 1.0) * 100)))
	var duration: float = c.skill_duration + c.upgrade_duration_bonus * level
	_add_line("스킬(L): %s — %.0f초 지속 · 쿨다운 %.0f초" % [
		c.skill_name_ko, duration, c.skill_cooldown])
	if c.info_source != &"":
		_add_line("능력: %s — 도시 지도에서 시장 정보 무료 획득 (%d일마다)" % [
			c.info_name_ko, c.info_cooldown_days])
	if level < c.upgrade_costs.size():
		var cost: int = c.upgrade_costs[level]
		var buy: Button = Button.new()
		buy.add_theme_font_size_override("font_size", 11)
		buy.text = "업그레이드 %d단계 (%d원) — 스킬 지속 +%.0f초" % [
			level + 1, cost, c.upgrade_duration_bonus]
		buy.disabled = FranchiseState.money < cost
		buy.pressed.connect(func() -> void:
			GameServer.request_buy_char_upgrade.rpc_id(1))
		_rows.add_child(buy)
	else:
		_add_line("업그레이드 완료 (%d/%d)" % [level, c.upgrade_costs.size()])
	# 호스트 캐릭터는 세이브 생성 후 고정. 게스트만 중복되지 않는 캐릭터로 변경 가능.
	if peer == 1:
		_add_line("이 캐릭터는 현재 세이브에 귀속되어 변경할 수 없습니다.")
		return
	_add_line("── 게스트 캐릭터 선택 ──")
	var my_slot: String = "2"
	var other_slot: String = "2" if my_slot == "1" else "1"
	var other_id: String = String(FranchiseState.character_picks.get(
		other_slot, GameServer.DEFAULT_PICKS[other_slot]))
	for def_id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(def_id)
		if not (def is CharacterDef):
			continue
		var cand: CharacterDef = def as CharacterDef
		var pick: Button = Button.new()
		pick.add_theme_font_size_override("font_size", 11)
		pick.text = "%s (%s)" % [cand.display_name_ko, _specialty_ko(cand)]
		if cand.id == c.id:
			pick.text += " — 사용 중"
			pick.disabled = true
		elif String(cand.id) == other_id:
			pick.text += " — 상대 사용 중"
			pick.disabled = true
		var cand_id: StringName = cand.id
		pick.pressed.connect(func() -> void:
			GameServer.request_select_character.rpc_id(1, cand_id))
		_rows.add_child(pick)


func _specialty_ko(c: CharacterDef) -> String:
	match c.specialty:
		CharacterDef.Specialty.PREP:
			return "전처리"
		CharacterDef.Specialty.TRANSPORT:
			return "이동·운반"
		_:
			return "서비스"


func _add_line(text: String) -> void:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_rows.add_child(label)
