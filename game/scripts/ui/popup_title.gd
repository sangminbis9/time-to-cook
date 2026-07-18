class_name PopupTitle
extends RefCounted
## 준비 단계 팝업 6종(매장/직원/경영/캐릭터/연구/지도) 공용 제목 행:
## 라벨 + 우측 상단 닫기(X) 버튼. Esc 입력과 별개의 종료 진입점.

static func build(popup: Control, text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var close: Button = Button.new()
	close.text = "×"
	close.add_theme_font_size_override("font_size", 13)
	close.custom_minimum_size = Vector2(20, 20)
	close.pressed.connect(popup.queue_free)
	row.add_child(close)
	return row
