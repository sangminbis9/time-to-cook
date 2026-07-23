extends Control
## 새 세이브의 주인공을 선택하고 이름을 붙이는 캐릭터 생성 화면.
## 외형·전문 분야는 고유 캐릭터 프리셋이며 생성 후 해당 세이브에서 변경할 수 없다.

const CHARACTER_IDS: Array[StringName] = [
	&"char.mint",
	&"char.apricot",
	&"char.basil",
]

var _selected_id: StringName = &"char.mint"
var _choice_buttons: Dictionary = {}
var _name_input: LineEdit
var _create_button: Button
var _notice: Label


func _ready() -> void:
	theme = PixelUi.theme()
	if SceneRouter.pending_save_slot < 1 \
			or SceneRouter.pending_save_slot > SaveService.MAX_SLOTS:
		SceneRouter.to_save_select(&"new")
		return
	_build_ui()
	_refresh_selection()


func _build_ui() -> void:
	var backing: PanelContainer = PanelContainer.new()
	backing.set_anchors_preset(Control.PRESET_CENTER)
	backing.position = Vector2(-310, -175)
	backing.size = Vector2(620, 350)
	add_child(backing)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	backing.add_child(root)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "주인공 만들기 · 슬롯 %d" % SceneRouter.pending_save_slot
	root.add_child(title)

	var name_row: HBoxContainer = HBoxContainer.new()
	root.add_child(name_row)
	var name_label: Label = Label.new()
	name_label.text = "캐릭터 이름"
	name_row.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.max_length = 12
	_name_input.placeholder_text = "1~12자로 이름을 지어 주세요"
	_name_input.text_changed.connect(func(_text: String) -> void: _validate())
	name_row.add_child(_name_input)

	var cards: HBoxContainer = HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 5)
	root.add_child(cards)
	for id: StringName in CHARACTER_IDS:
		cards.add_child(_build_character_card(Defs.get_def(id) as CharacterDef))

	var footer: HBoxContainer = HBoxContainer.new()
	root.add_child(footer)
	var back: Button = Button.new()
	back.text = "← 슬롯 선택"
	back.pressed.connect(func() -> void: SceneRouter.to_save_select(&"new"))
	footer.add_child(back)
	_notice = Label.new()
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color("#a44b3f"))
	footer.add_child(_notice)
	_create_button = Button.new()
	_create_button.text = "이 캐릭터로 시작"
	_create_button.disabled = true
	_create_button.pressed.connect(_create_profile)
	footer.add_child(_create_button)


func _build_character_card(character: CharacterDef) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(196, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	var name: Label = Label.new()
	name.add_theme_font_size_override("font_size", 15)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_color", character.accent_color.darkened(0.3))
	name.text = character.display_name_ko
	column.add_child(name)

	var role: Label = Label.new()
	role.add_theme_font_size_override("font_size", 10)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.text = character.archetype_title_ko
	column.add_child(role)

	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 80)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = character.portrait
	column.add_child(portrait)

	column.add_child(_description(character.personality_ko, Color("#6d5843")))
	column.add_child(_description("패시브  " + character.passive_description_ko,
		character.accent_color.darkened(0.35)))
	column.add_child(_description("스킬  " + character.skill_description_ko,
		Color("#76528d")))
	column.add_child(_description(character.balance_note_ko, Color("#8c755c")))

	var choose: Button = Button.new()
	choose.text = "선택"
	var id: StringName = character.id
	choose.pressed.connect(func() -> void:
		_selected_id = id
		_refresh_selection())
	column.add_child(choose)
	_choice_buttons[id] = choose
	return panel


func _description(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	return label


func _refresh_selection() -> void:
	for id: StringName in CHARACTER_IDS:
		var button: Button = _choice_buttons[id] as Button
		var selected: bool = id == _selected_id
		button.disabled = selected
		button.text = "✓ 선택됨" if selected else "선택"
	_validate()


func _validate() -> void:
	if _create_button == null:
		return
	var valid: bool = SaveService.valid_profile_name(_name_input.text)
	_create_button.disabled = not valid
	_notice.text = "" if valid or _name_input.text.is_empty() \
		else "이름은 공백·제어문자 없이 1~12자로 입력해 주세요."


func _create_profile() -> void:
	if not SaveService.valid_profile_name(_name_input.text):
		_validate()
		return
	var slot: int = SceneRouter.pending_save_slot
	GameServer.reset()
	FranchiseState.begin_new_profile(String(_selected_id), _name_input.text)
	# 시작 도시 인천은 최초 시장 정보를 최고 수준으로 무료 제공 (§6.4).
	var incheon: CityDef = Defs.get_def(&"city.korea.incheon") as CityDef
	FranchiseState.market_info = {
		"city.korea.incheon": MarketReport.exact_report(incheon, 1),
	}
	SaveService.current_slot = slot
	if NetworkService.host() != OK:
		_notice.text = "호스트를 열 수 없습니다. 사용 중인 포트를 확인해 주세요."
		return
	SceneRouter.pending_new_save = true
	SceneRouter.pending_save_slot = 0
	SceneRouter.to_store()
