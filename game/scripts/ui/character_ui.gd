class_name CharacterUi
extends PanelContainer
## 캐릭터 팝업 (준비 단계 전용): 내 캐릭터 정보 + 영구 업그레이드 구매 (§11).
## HUD 우측 상단 [캐릭터] 버튼으로 연다.

var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -150.0
	offset_right = 150.0
	offset_top = -80.0
	offset_bottom = 80.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var title: Label = Label.new()
	title.text = "캐릭터  (Esc: 닫기)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	root.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	root.add_child(_rows)

	GameServer.ready_state_changed.connect(_refresh)
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
	var c: CharacterDef = GameServer.character_of(multiplayer.get_unique_id())
	var level: int = FranchiseState.char_upgrade_level(String(c.id))
	var specialty: String = "전처리" \
		if c.specialty == CharacterDef.Specialty.PREP else "이동·운반"
	_add_line("%s — 전문: %s" % [c.display_name_ko, specialty])
	_add_line(c.backstory_ko)
	if c.cut_per_work > 1:
		_add_line("패시브: 칼질 1회당 %d회 진행" % c.cut_per_work)
	if c.move_speed_mult > 1.0:
		_add_line("패시브: 이동속도 +%d%%" % int((c.move_speed_mult - 1.0) * 100))
	var duration: float = c.skill_duration + c.upgrade_duration_bonus * level
	_add_line("스킬(L): %s — %.0f초 지속 · 쿨다운 %.0f초" % [
		c.skill_name_ko, duration, c.skill_cooldown])
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


func _add_line(text: String) -> void:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_rows.add_child(label)
