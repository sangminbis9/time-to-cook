class_name FridgeUi
extends PanelContainer
## 냉장고 UI (PLAN.md §17.6–17.7). 마인크래프트식 클릭-커서 조작.
##
## 커서에 든 아이템은 클라이언트 로컬 상태다 — 서버에는 커밋된 이동
## (request_fridge_move)만 반영되므로, UI를 닫을 때 커서 아이템은
## 원래 슬롯으로 자동 복귀한다 (분실·복제 원천 차단).
## 열려 있는 동안 "modal_ui" 그룹에 등록되어 로컬 플레이어 입력을 막는다.

const SLOT_TEXTURE: Texture2D = preload("res://assets/sprites/ui_slot.png")
const ZONE_FRIDGE: int = 0
const ZONE_INV: int = 1

var _fridge_buttons: Array[TextureButton] = []
var _inv_buttons: Array[TextureButton] = []
## 커서 상태 (로컬 전용): 원본 위치만 기억 — 아이템은 서버 상태 그대로
var _cursor_zone: int = -1
var _cursor_slot: int = -1
var _cursor_icon: TextureRect


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -120.0
	offset_right = 120.0
	offset_top = -80.0
	offset_bottom = 80.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	root.add_child(_make_title("냉장고"))
	root.add_child(_make_grid(GameServer.fridge.slots.size(),
		_fridge_buttons, ZONE_FRIDGE))
	root.add_child(_make_title("인벤토리"))
	root.add_child(_make_grid(InventoryState.SLOT_COUNT, _inv_buttons, ZONE_INV))

	var hint: Label = Label.new()
	hint.text = "클릭: 이동/교환   Shift+클릭: 빠른 이동   Esc: 닫기"
	hint.add_theme_font_size_override("font_size", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	_cursor_icon = TextureRect.new()
	_cursor_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_cursor_icon.top_level = true
	_cursor_icon.visible = false
	_cursor_icon.z_index = 100
	add_child(_cursor_icon)

	GameServer.fridge_changed.connect(_refresh)
	GameServer.inventory_changed.connect(func(_p: int) -> void: _refresh())
	GameServer.fridge_lock_changed.connect(_on_lock_changed)
	_refresh()


func _make_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	return label


func _make_grid(count: int, into: Array[TextureButton], zone: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for i in range(count):
		var button: TextureButton = TextureButton.new()
		button.texture_normal = SLOT_TEXTURE
		button.custom_minimum_size = Vector2(20, 20)
		button.pressed.connect(_on_slot_clicked.bind(zone, i))
		var icon: TextureRect = TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.position = Vector2(2, 2)
		icon.visible = false
		button.add_child(icon)
		row.add_child(button)
		into.append(button)
	return row


func _process(_delta: float) -> void:
	if _cursor_icon.visible:
		_cursor_icon.global_position = get_global_mouse_position() + Vector2(4, 4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") \
			or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _local_inv() -> InventoryState:
	return GameServer.inventory_of(multiplayer.get_unique_id())


func _slot_iid(zone: int, slot: int) -> int:
	if zone == ZONE_FRIDGE:
		return GameServer.fridge.slots[slot]
	var inv: InventoryState = _local_inv()
	return inv.slots[slot] if inv != null else 0


func _on_slot_clicked(zone: int, slot: int) -> void:
	var inv: InventoryState = _local_inv()
	if inv == null:
		return
	if zone == ZONE_INV and slot >= inv.unlocked:
		return  # 잠긴 슬롯
	if Input.is_key_pressed(KEY_SHIFT):
		_quick_move(zone, slot, inv)
		return
	if _cursor_zone == -1:
		# 커서에 들기 (로컬)
		if _slot_iid(zone, slot) == 0:
			return
		_cursor_zone = zone
		_cursor_slot = slot
		_update_cursor()
	else:
		# 커밋: 원본 → 클릭 슬롯 (빈 슬롯=이동, 찬 슬롯=교환 §17.6)
		if not (zone == _cursor_zone and slot == _cursor_slot):
			GameServer.request_fridge_move.rpc_id(
				1, _cursor_zone, _cursor_slot, zone, slot)
		_clear_cursor()


## Shift+클릭: 반대편의 가장 왼쪽 유효한 빈 슬롯으로 (§17.6)
func _quick_move(zone: int, slot: int, inv: InventoryState) -> void:
	if _slot_iid(zone, slot) == 0:
		return
	var to_zone: int = ZONE_INV if zone == ZONE_FRIDGE else ZONE_FRIDGE
	var to_slot: int = -1
	if to_zone == ZONE_FRIDGE:
		to_slot = GameServer.fridge.first_free_slot()
	else:
		for i in range(inv.unlocked):
			if inv.slots[i] == 0:
				to_slot = i
				break
	if to_slot == -1:
		return
	GameServer.request_fridge_move.rpc_id(1, zone, slot, to_zone, to_slot)
	_clear_cursor()


func _update_cursor() -> void:
	var iid: int = _slot_iid(_cursor_zone, _cursor_slot)
	var item: ItemInstance = GameServer.get_item(iid)
	if item == null:
		_clear_cursor()
		return
	_cursor_icon.texture = item.get_def().texture
	_cursor_icon.visible = true
	_refresh()


func _clear_cursor() -> void:
	# §17.7: 커서 아이템은 원래 슬롯으로 복귀 — 서버 상태를 바꾼 적이
	# 없으므로 표시만 지우면 된다.
	_cursor_zone = -1
	_cursor_slot = -1
	_cursor_icon.visible = false
	_refresh()


func _refresh() -> void:
	for i in range(_fridge_buttons.size()):
		_paint_slot(_fridge_buttons[i], ZONE_FRIDGE, i)
	var inv: InventoryState = _local_inv()
	for i in range(_inv_buttons.size()):
		_paint_slot(_inv_buttons[i], ZONE_INV, i)
		if inv != null and i >= inv.unlocked:
			_inv_buttons[i].modulate = Color(0.55, 0.5, 0.45)


func _paint_slot(button: TextureButton, zone: int, slot: int) -> void:
	button.modulate = Color.WHITE
	var icon: TextureRect = button.get_child(0) as TextureRect
	var iid: int = _slot_iid(zone, slot)
	if zone == _cursor_zone and slot == _cursor_slot:
		# 커서에 든 원본 슬롯은 반투명 표시
		button.modulate = Color(1, 1, 1, 0.5)
	if iid != 0 and GameServer.get_item(iid) != null:
		icon.texture = GameServer.get_item(iid).get_def().texture
		icon.visible = true
	else:
		icon.visible = false


func _on_lock_changed(owner_peer: int) -> void:
	# 서버가 잠금을 회수했으면 (연결 문제 등) 닫는다
	if owner_peer != multiplayer.get_unique_id():
		queue_free()


func close() -> void:
	GameServer.request_fridge_close.rpc_id(1)
	queue_free()
