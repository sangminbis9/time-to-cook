class_name ManageUi
extends PanelContainer
## 경영 팝업 (준비 단계 전용): 재료 주문·메뉴 가격·대출.
## HUD 우측 상단 [경영] 버튼으로 연다.

var _stock_button: Button
var _price_label: Label
var _loan_button: Button


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -130.0
	offset_right = 130.0
	offset_top = -70.0
	offset_bottom = 70.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var title: Label = Label.new()
	title.text = "경영  (Esc: 닫기)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	root.add_child(title)

	_stock_button = Button.new()
	_stock_button.add_theme_font_size_override("font_size", 11)
	_stock_button.pressed.connect(func() -> void:
		GameServer.request_buy_stock.rpc_id(1, 10))
	root.add_child(_stock_button)

	var price_row: HBoxContainer = HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 2)
	root.add_child(price_row)
	var minus: Button = Button.new()
	minus.text = "-"
	minus.add_theme_font_size_override("font_size", 11)
	minus.pressed.connect(func() -> void: _change_price(-500))
	price_row.add_child(minus)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 11)
	price_row.add_child(_price_label)
	var plus: Button = Button.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 11)
	plus.pressed.connect(func() -> void: _change_price(500))
	price_row.add_child(plus)

	_loan_button = Button.new()
	_loan_button.add_theme_font_size_override("font_size", 11)
	_loan_button.pressed.connect(_on_loan_pressed)
	root.add_child(_loan_button)

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


func _change_price(delta: int) -> void:
	var recipe: RecipeDef = Defs.get_def(&"recipe.fried_dakgangjeong") as RecipeDef
	GameServer.request_set_price.rpc_id(1, recipe.id,
		FranchiseState.price_of(recipe) + delta)


func _on_loan_pressed() -> void:
	if FranchiseState.loan_principal > 0:
		GameServer.request_repay_loan.rpc_id(1)
	else:
		GameServer.request_take_loan.rpc_id(1)


func _refresh() -> void:
	var unit_cost: int = GameServer.effective_ingredient_cost()
	_stock_button.text = "재료 10개 주문 (%d원) · 보유 %d" % [
		10 * unit_cost, GameServer.ingredient_stock]
	if unit_cost > GameServer.ingredient_unit_cost:
		_stock_button.text += " ⚠공급 충격"
	var recipe: RecipeDef = Defs.get_def(&"recipe.fried_dakgangjeong") as RecipeDef
	_price_label.text = "닭강정 %d원" % FranchiseState.price_of(recipe)
	if FranchiseState.loan_principal > 0:
		_loan_button.text = "대출 전액 상환 (%d원)" % FranchiseState.loan_principal
	else:
		_loan_button.text = "대출 받기 (+%d원, 일 이자 %d%%)" % [
			GameServer.LOAN_AMOUNT, int(FranchiseState.loan_daily_rate * 100)]
