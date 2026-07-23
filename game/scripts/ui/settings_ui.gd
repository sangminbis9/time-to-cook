class_name SettingsUi
extends PanelContainer
## 설정 팝업 (§35): 효과음·배경음 볼륨 분리 조절. user://settings.cfg에 저장.

var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("modal_ui")
	theme = PixelUi.theme()
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -130.0
	offset_right = 130.0
	offset_top = -60.0
	offset_bottom = 60.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(PopupTitle.build(self, "설정  (Esc: 닫기)"))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	root.add_child(_rows)
	_add_slider("효과음", "SFX")
	_add_slider("배경음", "Music")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


func _add_slider(label_text: String, bus_name: String) -> void:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.text = label_text
	_rows.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SoundFx.get_volume(bus_name)
	slider.custom_minimum_size = Vector2(220, 16)
	slider.value_changed.connect(func(value: float) -> void:
		SoundFx.set_volume(bus_name, value))
	_rows.add_child(slider)
