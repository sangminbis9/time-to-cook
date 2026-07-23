extends Control
## 캐릭터 프로필 기반 3슬롯 저장 화면.

var _notice: Label


func _ready() -> void:
	theme = PixelUi.theme()
	_build_ui()


func _build_ui() -> void:
	var backing: PanelContainer = PanelContainer.new()
	backing.set_anchors_preset(Control.PRESET_CENTER)
	backing.position = Vector2(-220, -150)
	backing.size = Vector2(440, 300)
	add_child(backing)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	backing.add_child(root)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "새 캐릭터 만들기" \
		if SceneRouter.save_select_mode == &"new" else "캐릭터 이어하기"
	root.add_child(title)

	var hint: Label = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "각 슬롯은 캐릭터·이름·성장 상태를 독립적으로 저장합니다."
	root.add_child(hint)

	for slot: int in range(1, SaveService.MAX_SLOTS + 1):
		root.add_child(_build_slot_row(slot))

	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color("#a44b3f"))
	root.add_child(_notice)

	var back: Button = Button.new()
	back.text = "← 타이틀로"
	back.pressed.connect(func() -> void: SceneRouter.to_title())
	root.add_child(back)


func _build_slot_row(slot: int) -> Control:
	var summary: Dictionary = SaveService.slot_summary(slot)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(54, 54)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var heading: Label = Label.new()
	heading.add_theme_font_size_override("font_size", 13)
	info.add_child(heading)
	var detail: Label = Label.new()
	detail.add_theme_font_size_override("font_size", 10)
	info.add_child(detail)

	var action: Button = Button.new()
	action.custom_minimum_size = Vector2(94, 0)
	row.add_child(action)

	if summary.is_empty():
		heading.text = "슬롯 %d — 빈 슬롯" % slot
		detail.text = "새로운 캐릭터를 기다리고 있어요."
		action.text = "캐릭터 생성"
		action.disabled = SceneRouter.save_select_mode != &"new"
		action.pressed.connect(func() -> void: SceneRouter.to_character_select(slot))
		return panel

	var char_id: StringName = StringName(String(summary["character_id"]))
	var character: CharacterDef = Defs.get_def(char_id) as CharacterDef
	portrait.texture = character.portrait
	var profile_name: String = String(summary["profile_name"])
	if profile_name.is_empty():
		profile_name = character.display_name_ko
	heading.text = "슬롯 %d — %s" % [slot, profile_name]
	detail.text = "%s · %d일차 · %d원" % [
		character.archetype_title_ko,
		int(summary["day"]),
		int(summary["money"]),
	]
	if SceneRouter.save_select_mode == &"new":
		action.text = "덮어쓰기"
		action.pressed.connect(func() -> void: _confirm_overwrite(slot, profile_name))
	else:
		action.text = "이어하기"
		action.pressed.connect(func() -> void: _continue_slot(slot))
	return panel


func _confirm_overwrite(slot: int, profile_name: String) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.theme = PixelUi.theme()
	dialog.title = "슬롯 덮어쓰기"
	dialog.dialog_text = "'%s'의 기존 진행은 새 캐릭터를 확정할 때 교체됩니다." % profile_name
	dialog.ok_button_text = "새 캐릭터 만들기"
	dialog.cancel_button_text = "취소"
	dialog.confirmed.connect(func() -> void: SceneRouter.to_character_select(slot))
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 130))


func _continue_slot(slot: int) -> void:
	GameServer.reset()
	if NetworkService.host() != OK:
		_notice.text = "호스트를 열 수 없습니다. 사용 중인 포트를 확인해 주세요."
		return
	SaveService.current_slot = slot
	SceneRouter.pending_load_slot = slot
	SceneRouter.to_store()
