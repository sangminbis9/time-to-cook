class_name ResearchUi
extends PanelContainer
## 연구 팝업 (준비 단계 전용, §20): 전체 트리 처음부터 공개,
## 공용 자금 + 연구 포인트로 구매, 즉시 적용. HUD [연구] 버튼으로 연다.

const CATEGORY_LABELS: Dictionary = {
	ResearchDef.Category.FOOD: "음식",
	ResearchDef.Category.COOKING: "조리 기술",
	ResearchDef.Category.EQUIPMENT: "장비",
	ResearchDef.Category.OPERATION: "운영",
	ResearchDef.Category.LOGISTICS: "물류",
	ResearchDef.Category.MARKETING: "마케팅",
}

var _rows: VBoxContainer
var _points: Label


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -150.0
	offset_right = 150.0
	offset_top = -110.0
	offset_bottom = 110.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(PopupTitle.build(self, "연구  (Esc: 닫기)"))
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", 11)
	root.add_child(_points)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	root.add_child(_rows)

	GameServer.research_changed.connect(_refresh)
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
	_points.text = "연구 포인트: %d (영업일마다 +1)" % FranchiseState.research_points
	for def: ResearchDef in _all_research():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_rows.add_child(row)
		var info: Label = Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 11)
		info.text = "[%s] %s" % [CATEGORY_LABELS[def.category], def.display_name_ko]
		info.tooltip_text = def.desc_ko
		row.add_child(info)
		if FranchiseState.research_done(String(def.id)):
			var done: Label = Label.new()
			done.add_theme_font_size_override("font_size", 11)
			done.text = "완료"
			row.add_child(done)
			continue
		var buy: Button = Button.new()
		buy.add_theme_font_size_override("font_size", 11)
		buy.text = "%d원 + %dRP" % [def.cost_money, def.cost_points]
		var missing: Array[String] = _missing_prereqs(def)
		if not missing.is_empty():
			buy.text = "선행: %s" % ", ".join(missing)
			buy.disabled = true
		else:
			buy.disabled = FranchiseState.money < def.cost_money \
				or FranchiseState.research_points < def.cost_points
		var rid: String = String(def.id)
		buy.pressed.connect(func() -> void:
			GameServer.request_buy_research.rpc_id(1, rid))
		row.add_child(buy)


func _missing_prereqs(def: ResearchDef) -> Array[String]:
	var missing: Array[String] = []
	for pre: StringName in def.prereq:
		if not FranchiseState.research_done(String(pre)):
			missing.append((Defs.get_def(pre) as ResearchDef).display_name_ko)
	return missing


func _all_research() -> Array[ResearchDef]:
	var result: Array[ResearchDef] = []
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is ResearchDef:
			result.append(def as ResearchDef)
	result.sort_custom(func(a: ResearchDef, b: ResearchDef) -> bool:
		return a.category < b.category \
			or (a.category == b.category and String(a.id) < String(b.id)))
	return result
