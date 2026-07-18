class_name StoreEditUi
extends PanelContainer
## 매장 관리 팝업 (준비 단계 전용): 설비 이동·구매 (§15).
## 이동/구매를 고르면 팝업을 닫고 매장 씬의 클릭 배치 모드로 넘어간다.

const PREVENTION_LABELS: Dictionary = {
	"sprinkler": "스프링클러 (화재 예방)",
	"generator": "발전기 (정전 예방)",
	"drainage": "배수 시설 (누수 예방)",
	"antislip": "미끄럼 방지 바닥",
	"vent": "환기 시설 (환기 고장 예방)",
	"maintenance": "유지보수 계약 (장비 고장 예방)",
}

var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -150.0
	offset_right = 150.0
	offset_top = -120.0
	offset_bottom = 120.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(PopupTitle.build(self, "매장 관리  (Esc: 닫기)"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_rows)

	GameServer.station_layout_changed.connect(_refresh)
	GameServer.ready_state_changed.connect(_refresh)  # 예방 설비 구매 반영
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
	_add_header("── 내 설비 (이동) ──")
	var placements: Dictionary = GameServer.placements_view()
	var keys: Array = placements.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for key: StringName in keys:
		var entry: Dictionary = placements[key]
		var def: StationDef = Defs.get_def(entry["def_id"]) as StationDef
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.text = def.display_name_ko
		row.add_child(label)
		var move: Button = Button.new()
		move.text = "이동"
		move.add_theme_font_size_override("font_size", 11)
		var move_key: StringName = key
		move.pressed.connect(func() -> void: _begin("move", move_key, StringName()))
		row.add_child(move)
		_rows.add_child(row)
	_add_header("── 설비 구매 ──")
	for def_id: StringName in GameServer.STATION_PRICES.keys():
		var def: StationDef = Defs.get_def(def_id) as StationDef
		var price: int = int(GameServer.STATION_PRICES[def_id])
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.text = "%s  %d원" % [def.display_name_ko, price]
		row.add_child(label)
		var buy: Button = Button.new()
		buy.text = "구매"
		buy.add_theme_font_size_override("font_size", 11)
		buy.disabled = FranchiseState.money < price
		var buy_def: StringName = def_id
		buy.pressed.connect(func() -> void: _begin("buy", StringName(), buy_def))
		row.add_child(buy)
		_rows.add_child(row)
	_add_header("── 예방 설비 (§23.4) ──")
	var owned: Dictionary = GameServer.preventions_view()
	for id: String in GameServer.PREVENTION_PRICES.keys():
		var price: int = int(GameServer.PREVENTION_PRICES[id])
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.text = "%s  %d원" % [String(PREVENTION_LABELS.get(id, id)), price]
		row.add_child(label)
		if owned.has(id):
			var badge: Label = Label.new()
			badge.add_theme_font_size_override("font_size", 11)
			badge.text = "보유"
			row.add_child(badge)
		else:
			var buy: Button = Button.new()
			buy.text = "구매"
			buy.add_theme_font_size_override("font_size", 11)
			buy.disabled = FranchiseState.money < price
			var buy_id: String = id
			buy.pressed.connect(func() -> void:
				GameServer.request_buy_prevention.rpc_id(1, buy_id))
			row.add_child(buy)
		_rows.add_child(row)
	# 보험 (§23.4): 가입·해지 자유, 일일 보험료·이벤트당 보상
	var ins_row: HBoxContainer = HBoxContainer.new()
	ins_row.add_theme_constant_override("separation", 4)
	var ins_label: Label = Label.new()
	ins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ins_label.add_theme_font_size_override("font_size", 11)
	ins_label.text = "보험  일 %d원 · 이벤트당 보상 %d원" % [
		GameServer.INSURANCE_DAILY_FEE, GameServer.INSURANCE_PAYOUT_PER_EVENT]
	ins_row.add_child(ins_label)
	var ins_button: Button = Button.new()
	ins_button.add_theme_font_size_override("font_size", 11)
	ins_button.text = "해지" \
		if owned.has(GameServer.INSURANCE_KEY) else "가입"
	ins_button.pressed.connect(func() -> void:
		GameServer.request_toggle_insurance.rpc_id(1))
	ins_row.add_child(ins_button)
	_rows.add_child(ins_row)


func _add_header(text: String) -> void:
	var header: Label = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 11)
	_rows.add_child(header)


## 팝업을 닫고 매장 씬의 클릭 배치 모드로 진입
func _begin(mode: String, key: StringName, def_id: StringName) -> void:
	var scene: Node = get_tree().get_first_node_in_group("store_scene")
	if scene != null:
		if mode == "move":
			scene.begin_move_station(key)
		else:
			scene.begin_buy_station(def_id)
	queue_free()
