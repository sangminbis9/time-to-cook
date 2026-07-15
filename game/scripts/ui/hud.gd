extends CanvasLayer
## 매장 HUD: 인벤토리 바(9칸, 잠긴 칸 표시), 실패 토스트, 날짜/자금.
## 전부 로컬 표현 — 상태 원본은 GameServer/FranchiseState 미러.

const SLOT_TEXTURE: Texture2D = preload("res://assets/sprites/ui_slot.png")
const FAIL_MESSAGES: Dictionary = {
	"inventory_full": "인벤토리가 가득 찼습니다",
	"no_drop_spot": "내려놓을 곳이 없습니다",
	"station_rejects_item": "이 아이템은 여기에 넣을 수 없습니다",
	"station_busy": "작업이 진행 중입니다",
	"not_submittable": "완성된 음식만 제출할 수 있습니다",
	"no_matching_order": "해당 메뉴의 주문이 없습니다",
	"out_of_stock": "재료가 떨어졌습니다",
	"fridge_in_use": "다른 사람이 냉장고를 쓰고 있습니다",
	"not_storable": "이 아이템은 냉장고에 넣을 수 없습니다",
	"employee_working": "직원이 작업 중입니다",
	"not_enough_money": "자금이 부족합니다",
	"loan_active": "이미 대출이 있습니다",
	"market_scammed": "정보상에게 사기를 당했습니다!",
	"station_on_fire": "불이 붙었습니다! J로 진압하세요",
	"invalid_spot": "그 자리에는 놓을 수 없습니다",
}
const TOAST_SECONDS: float = 2.0

var _slot_rects: Array[TextureRect] = []
var _item_icons: Array[TextureRect] = []
var _toast: Label
var _status: Label
var _orders_box: VBoxContainer
var _phase_hint: Label
var _settlement: PanelContainer
var _settlement_label: Label
var _toast_timer: float = 0.0


func _ready() -> void:
	_build_inventory_bar()
	_build_toast()
	_build_status()
	_build_orders_panel()
	_build_phase_hint()
	_build_event_banner()
	_build_settlement_panel()
	_build_prep_menu()
	GameServer.inventory_changed.connect(_on_inventory_changed)
	GameServer.item_updated.connect(func(_iid: int) -> void: _refresh_slots())
	GameServer.snapshot_applied.connect(_refresh_all)
	GameServer.fail_notified.connect(_on_fail)
	GameServer.orders_changed.connect(_refresh_orders)
	GameServer.ready_state_changed.connect(_refresh_phase_hint)
	GameServer.day_settled.connect(_on_day_settled)
	GameClock.phase_changed.connect(_on_phase_changed)
	GameServer.fridge_lock_changed.connect(_on_fridge_lock_changed)
	GameServer.store_event_changed.connect(_refresh_event_banner)
	_refresh_all()


func _process(delta: float) -> void:
	if _toast.visible:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast.visible = false
	if GameClock.phase == GameClock.Phase.SERVICE:
		_refresh_status()


func _refresh_all() -> void:
	_refresh_slots()
	_refresh_orders()
	_refresh_phase_hint()
	_refresh_status()
	_refresh_event_banner()


func _local_peer() -> int:
	return multiplayer.get_unique_id()


func _build_inventory_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "InventoryBar"
	bar.anchors_preset = Control.PRESET_CENTER_BOTTOM
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -190.0
	bar.offset_right = 190.0
	bar.offset_top = -48.0
	bar.offset_bottom = -6.0
	bar.add_theme_constant_override("separation", 2)
	add_child(bar)
	for i in range(InventoryState.SLOT_COUNT):
		var slot: TextureRect = TextureRect.new()
		slot.texture = SLOT_TEXTURE
		slot.custom_minimum_size = Vector2(40, 40)
		slot.stretch_mode = TextureRect.STRETCH_SCALE
		# 냉장고가 열려 있으면 바 클릭이 곧 인벤토리 쪽 상호작용 (§17.6)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx: int = i
		slot.gui_input.connect(func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click != null and click.pressed \
					and click.button_index == MOUSE_BUTTON_LEFT:
				_on_bar_slot_clicked(idx))
		bar.add_child(slot)
		var icon: TextureRect = TextureRect.new()
		icon.position = Vector2(4, 4)
		icon.size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		slot.add_child(icon)
		_slot_rects.append(slot)
		_item_icons.append(icon)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = -150.0
	_toast.offset_right = 150.0
	_toast.offset_top = -66.0
	_toast.offset_bottom = -50.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 11)
	_toast.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3))
	_toast.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.85))
	_toast.add_theme_constant_override("outline_size", 2)
	_toast.visible = false
	add_child(_toast)


func _build_status() -> void:
	_status = Label.new()
	_status.name = "Status"
	_status.position = Vector2(6, 4)
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.35, 0.27, 0.2))
	_status.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.85))
	_status.add_theme_constant_override("outline_size", 2)
	add_child(_status)
	GameClock.phase_changed.connect(func(_p: GameClock.Phase) -> void: _refresh_status())
	GameClock.day_advanced.connect(func(_d: int) -> void: _refresh_status())
	FranchiseState.money_changed.connect(func(_m: int) -> void: _refresh_status())
	_refresh_status()


func _refresh_status() -> void:
	var phase_names: Dictionary = {
		GameClock.Phase.PREP: "준비",
		GameClock.Phase.SERVICE: "영업 중",
		GameClock.Phase.SETTLEMENT: "정산",
	}
	var city: CityDef = Defs.get_def(StringName(GameServer.my_city())) as CityDef
	var text: String = "%d일차  %s  %s  %d원" % [
		GameClock.day, city.display_name_ko if city != null else "",
		phase_names[GameClock.phase], FranchiseState.money]
	if GameClock.phase == GameClock.Phase.SERVICE:
		var remaining: int = maxi(0, ceili(GameClock.service_length
			- GameClock.service_elapsed))
		text += "  %d:%02d" % [remaining / 60, remaining % 60]
		text += "  재료 %d" % GameServer.ingredient_stock
	_status.text = text


func _build_orders_panel() -> void:
	_orders_box = VBoxContainer.new()
	_orders_box.name = "Orders"
	_orders_box.anchor_left = 1.0
	_orders_box.anchor_right = 1.0
	_orders_box.offset_left = -132.0
	_orders_box.offset_right = -6.0
	_orders_box.offset_top = 6.0
	_orders_box.add_theme_constant_override("separation", 2)
	add_child(_orders_box)


func _refresh_orders() -> void:
	for child: Node in _orders_box.get_children():
		child.queue_free()
	for order: Dictionary in GameServer.orders.active:
		var recipe: RecipeDef = Defs.get_def(
			StringName(String(order["recipe_id"]))) as RecipeDef
		var ticket: Label = Label.new()
		ticket.text = "주문 #%d  %s" % [int(order["oid"]), recipe.display_name_ko]
		ticket.add_theme_font_size_override("font_size", 11)
		ticket.add_theme_color_override("font_color", Color(0.35, 0.27, 0.2))
		ticket.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.85))
		ticket.add_theme_constant_override("outline_size", 2)
		_orders_box.add_child(ticket)


func _build_phase_hint() -> void:
	_phase_hint = Label.new()
	_phase_hint.name = "PhaseHint"
	_phase_hint.anchor_left = 0.5
	_phase_hint.anchor_right = 0.5
	_phase_hint.offset_left = -150.0
	_phase_hint.offset_right = 150.0
	_phase_hint.offset_top = 6.0
	_phase_hint.offset_bottom = 22.0
	_phase_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_hint.add_theme_font_size_override("font_size", 11)
	_phase_hint.add_theme_color_override("font_color", Color(0.35, 0.27, 0.2))
	_phase_hint.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.85))
	_phase_hint.add_theme_constant_override("outline_size", 2)
	add_child(_phase_hint)


func _refresh_phase_hint() -> void:
	match GameClock.phase:
		GameClock.Phase.PREP:
			var me_ready: bool = GameServer.ready_peers.has(_local_peer())
			_phase_hint.text = "준비 완료 (%d/%d)  대기 중..." % [
				GameServer.ready_peers.size(), _connected_count()] \
				if me_ready else "R: 준비 완료하고 영업 시작"
			_phase_hint.visible = true
		GameClock.Phase.SETTLEMENT:
			var me_ready: bool = GameServer.ready_peers.has(_local_peer())
			_phase_hint.text = "다음 날 대기 중... (%d/%d)" % [
				GameServer.ready_peers.size(), _connected_count()] \
				if me_ready else "R: 다음 날 시작"
			_phase_hint.visible = true
		_:
			_phase_hint.visible = false


func _connected_count() -> int:
	return 1 + multiplayer.get_peers().size()


## 매장 이벤트 배너 (§23.1 — 진행 중 내내 표시)
var _event_banner: Label


func _build_event_banner() -> void:
	_event_banner = Label.new()
	_event_banner.name = "EventBanner"
	_event_banner.anchor_left = 0.5
	_event_banner.anchor_right = 0.5
	_event_banner.offset_left = -160.0
	_event_banner.offset_right = 160.0
	_event_banner.offset_top = 22.0
	_event_banner.offset_bottom = 38.0
	_event_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_banner.add_theme_font_size_override("font_size", 11)
	_event_banner.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
	_event_banner.add_theme_color_override(
		"font_outline_color", Color(0.97, 0.94, 0.85))
	_event_banner.add_theme_constant_override("outline_size", 2)
	_event_banner.visible = false
	add_child(_event_banner)


func _refresh_event_banner() -> void:
	if _event_banner == null:
		return
	var event: Dictionary = GameServer.current_store_event()
	match String(event.get("type", "")):
		"fire":
			_event_banner.text = "⚠ 화재 발생! 불붙은 튀김기에 J 연타 (%d/%d)" % [
				int(event.get("hits", 0)), GameServer.EXTINGUISH_HITS]
			_event_banner.visible = true
		"blackout":
			_event_banner.text = "⚠ 정전! 냉장고 옆 차단기를 J로 복구하세요"
			_event_banner.visible = true
		_:
			_event_banner.visible = false


func _build_settlement_panel() -> void:
	_settlement = PanelContainer.new()
	_settlement.name = "Settlement"
	_settlement.anchor_left = 0.5
	_settlement.anchor_right = 0.5
	_settlement.anchor_top = 0.5
	_settlement.anchor_bottom = 0.5
	_settlement.offset_left = -110.0
	_settlement.offset_right = 110.0
	_settlement.offset_top = -60.0
	_settlement.offset_bottom = 60.0
	_settlement.visible = false
	add_child(_settlement)
	_settlement_label = Label.new()
	_settlement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settlement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settlement_label.add_theme_font_size_override("font_size", 11)
	_settlement.add_child(_settlement_label)


func _on_day_settled(summary: Dictionary) -> void:
	var text: String = "%d일차 마감\n\n매출  %d원" % [
		int(summary.get("day", GameClock.day)), int(summary.get("revenue", 0))]
	if int(summary.get("offline_revenue", 0)) > 0:
		text += "\n타 매장 매출  +%d원" % int(summary["offline_revenue"])
	if int(summary.get("wages", 0)) > 0:
		text += "\n급여  -%d원" % int(summary["wages"])
	if int(summary.get("rent", 0)) > 0:
		text += "\n임대료  -%d원" % int(summary["rent"])
	if int(summary.get("interest", 0)) > 0:
		text += "\n대출 이자  -%d원" % int(summary["interest"])
	text += "\n폐기  %d개" % int(summary.get("disposed", 0))
	if int(summary.get("stock_wasted", 0)) > 0:
		text += "\n잔여 재료 폐기  %d개" % int(summary["stock_wasted"])
	text += "\n\nR: 다음 날 시작"
	_settlement_label.text = text
	_settlement.visible = true


## 준비 단계 우측 상단 주제 버튼 — 세부 조작은 팝업에서 (매장/직원/경영/지도)
var _prep_menu: VBoxContainer
var _map_button: Button


func _build_prep_menu() -> void:
	_prep_menu = VBoxContainer.new()
	_prep_menu.name = "PrepMenu"
	_prep_menu.anchor_left = 1.0
	_prep_menu.anchor_right = 1.0
	_prep_menu.offset_left = -116.0
	_prep_menu.offset_right = -6.0
	_prep_menu.offset_top = 6.0
	_prep_menu.add_theme_constant_override("separation", 4)
	add_child(_prep_menu)
	_menu_button("매장", func() -> void: _open_popup(StoreEditUi.new()))
	_menu_button("직원", func() -> void: _open_popup(StaffUi.new()))
	_menu_button("경영", func() -> void: _open_popup(ManageUi.new()))
	_map_button = _menu_button("지도", func() -> void: _open_popup(CityMapUi.new()))
	GameServer.market_info_changed.connect(_refresh_prep_menu)
	GameServer.ready_state_changed.connect(_refresh_prep_menu)
	_refresh_prep_menu()


func _menu_button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size = Vector2(110, 28)
	button.pressed.connect(handler)
	_prep_menu.add_child(button)
	return button


func _open_popup(popup: Control) -> void:
	if get_tree().get_first_node_in_group("modal_ui") != null:
		popup.queue_free()
		return
	add_child(popup)


func _refresh_prep_menu() -> void:
	_prep_menu.visible = GameClock.phase == GameClock.Phase.PREP
	# 재조사 권장 도시 수 배지 (§7.5)
	var recheck: int = MarketReport.recheck_count(
		FranchiseState.market_info, GameClock.day)
	_map_button.text = "지도" if recheck == 0 else "지도 (재조사 %d)" % recheck


func _on_phase_changed(phase: GameClock.Phase) -> void:
	if phase != GameClock.Phase.SETTLEMENT:
		_settlement.visible = false
	_refresh_phase_hint()
	_refresh_status()
	_refresh_prep_menu()


func _on_inventory_changed(peer_id: int) -> void:
	if peer_id == _local_peer():
		_refresh_slots()


func _refresh_slots() -> void:
	if not is_inside_tree():
		return  # 냉장고 UI의 tree_exited가 씬 해체 중에도 올 수 있다
	var inv: InventoryState = GameServer.inventory_of(_local_peer())
	if inv == null:
		return
	var fridge_ui: FridgeUi = _open_fridge_ui()
	for i in range(InventoryState.SLOT_COUNT):
		var locked: bool = i >= inv.unlocked
		var tint: Color = Color(0.55, 0.5, 0.45) if locked else (
			Color(1.35, 1.25, 0.9) if i == inv.selected else Color.WHITE)
		if fridge_ui != null and fridge_ui.cursor_inv_slot() == i:
			tint.a = 0.5  # 냉장고 커서에 들려 있는 원본 슬롯
		_slot_rects[i].modulate = tint
		var iid: int = inv.slots[i]
		if iid != 0 and GameServer.get_item(iid) != null:
			_item_icons[i].texture = GameServer.get_item(iid).get_def().texture
			_item_icons[i].visible = true
		else:
			_item_icons[i].visible = false


func _open_fridge_ui() -> FridgeUi:
	return get_tree().get_first_node_in_group("fridge_ui") as FridgeUi


## 하단 바 클릭: 냉장고가 열려 있을 때만 의미가 있다 (§17.6)
func _on_bar_slot_clicked(slot: int) -> void:
	var fridge_ui: FridgeUi = _open_fridge_ui()
	if fridge_ui != null:
		fridge_ui.on_inventory_slot_clicked(slot)


## 냉장고 사용권을 얻은 로컬 플레이어에게 UI를 연다 (§17.4)
func _on_fridge_lock_changed(owner_peer: int) -> void:
	if owner_peer != _local_peer():
		return
	if get_tree().get_first_node_in_group("modal_ui") != null:
		return
	var ui: FridgeUi = FridgeUi.new()
	ui.cursor_changed.connect(_refresh_slots)
	ui.tree_exited.connect(_refresh_slots)
	add_child(ui)


func _on_fail(msg_key: String) -> void:
	_toast.text = String(FAIL_MESSAGES.get(msg_key, msg_key))
	_toast.visible = true
	_toast_timer = TOAST_SECONDS
