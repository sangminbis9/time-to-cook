class_name ManageUi
extends PanelContainer
## 경영 팝업 (준비 단계 전용): 재료 주문·메뉴 가격·대출.
## HUD 우측 상단 [경영] 버튼으로 연다.

var _stock_button: Button
## recipe_id(String) → 가격 Label — 메뉴별 가격 행 (§19.1)
var _price_labels: Dictionary = {}
## 대출 목록·상품 버튼 (§9 — 활성 3건, 만기·연체 표시)
var _loan_box: VBoxContainer
## 광고 캠페인 (§8.3 — 도시당 동시 1건)
var _ad_box: VBoxContainer


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -130.0
	offset_right = 130.0
	offset_top = -125.0
	offset_bottom = 125.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(PopupTitle.build(self, "경영  (Esc: 닫기)"))

	_stock_button = Button.new()
	_stock_button.add_theme_font_size_override("font_size", 11)
	_stock_button.pressed.connect(func() -> void:
		GameServer.request_buy_stock.rpc_id(1, 10))
	root.add_child(_stock_button)

	for recipe: RecipeDef in _all_recipes():
		var price_row: HBoxContainer = HBoxContainer.new()
		price_row.add_theme_constant_override("separation", 2)
		root.add_child(price_row)
		var minus: Button = Button.new()
		minus.text = "-"
		minus.add_theme_font_size_override("font_size", 11)
		var minus_id: StringName = recipe.id
		minus.pressed.connect(func() -> void: _change_price(minus_id, -500))
		price_row.add_child(minus)
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 11)
		_price_labels[String(recipe.id)] = label
		price_row.add_child(label)
		var plus: Button = Button.new()
		plus.text = "+"
		plus.add_theme_font_size_override("font_size", 11)
		var plus_id: StringName = recipe.id
		plus.pressed.connect(func() -> void: _change_price(plus_id, 500))
		price_row.add_child(plus)

	_loan_box = VBoxContainer.new()
	_loan_box.add_theme_constant_override("separation", 2)
	root.add_child(_loan_box)

	_ad_box = VBoxContainer.new()
	_ad_box.add_theme_constant_override("separation", 2)
	root.add_child(_ad_box)

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


## 등록된 전체 레시피 (id 순 정렬 — 표시 순서 안정화)
func _all_recipes() -> Array[RecipeDef]:
	var recipes: Array[RecipeDef] = []
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is RecipeDef:
			recipes.append(def as RecipeDef)
	recipes.sort_custom(func(a: RecipeDef, b: RecipeDef) -> bool:
		return String(a.id) < String(b.id))
	return recipes


func _change_price(recipe_id: StringName, delta: int) -> void:
	var recipe: RecipeDef = Defs.get_def(recipe_id) as RecipeDef
	GameServer.request_set_price.rpc_id(1, recipe.id,
		FranchiseState.price_of(recipe) + delta)


func _refresh() -> void:
	var unit_cost: int = GameServer.effective_ingredient_cost()
	_stock_button.text = "재료 10개 주문 (%d원) · 보유 %d" % [
		10 * unit_cost, GameServer.ingredient_stock]
	if unit_cost > GameServer.ingredient_unit_cost:
		_stock_button.text += " ⚠공급 충격"
	for recipe: RecipeDef in _all_recipes():
		var label: Label = _price_labels.get(String(recipe.id))
		if label != null:
			label.text = "%s %d원" % [
				recipe.display_name_ko, FranchiseState.price_of(recipe)]
	_refresh_loans()
	_refresh_ads()


## 이 도시의 광고: 진행 중이면 남은 일수, 아니면 상품 버튼 (§8.3)
func _refresh_ads() -> void:
	for child: Node in _ad_box.get_children():
		child.queue_free()
	var city_id: String = GameServer.my_city()
	if FranchiseState.ad_campaigns.has(city_id):
		var active: Dictionary = FranchiseState.ad_campaigns[city_id]
		var product: Dictionary = CityEconomy.AD_PRODUCTS.get(
			String(active.get("ad_id", "")), {})
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 11)
		label.text = "광고 진행 중: %s · %d일 남음" % [
			String(product.get("label", "?")), int(active.get("days_left", 0))]
		_ad_box.add_child(label)
		return
	for ad_id: String in CityEconomy.AD_PRODUCTS.keys():
		var product: Dictionary = CityEconomy.AD_PRODUCTS[ad_id]
		var buy: Button = Button.new()
		buy.add_theme_font_size_override("font_size", 11)
		buy.text = "광고: %s %d원 (%d일 · 수요 ×%.1f)" % [
			String(product["label"]), int(product["cost"]),
			int(product["days"]), float(product["demand_factor"])]
		buy.disabled = FranchiseState.money < int(product["cost"])
		var buy_id: String = ad_id
		buy.pressed.connect(func() -> void:
			GameServer.request_buy_ad.rpc_id(1, buy_id))
		_ad_box.add_child(buy)


## 활성 대출(상환 버튼·만기·연체) + 신규 대출 상품 버튼 (§9)
func _refresh_loans() -> void:
	for child: Node in _loan_box.get_children():
		child.queue_free()
	for loan: Variant in FranchiseState.loans:
		var data: Dictionary = loan
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		var product: Dictionary = LoanBook.PRODUCTS.get(
			String(data["product"]), {})
		var status: String = "⚠연체" if bool(data.get("overdue", false)) \
			else "만기 %d일 후" % maxi(0, int(data["due_day"]) - GameClock.day)
		label.text = "%s대출 %d원 · %s" % [
			String(product.get("label", "?")), int(data["principal"]), status]
		row.add_child(label)
		var repay: Button = Button.new()
		repay.add_theme_font_size_override("font_size", 11)
		var amount: int = LoanBook.payoff(data, GameClock.day)
		repay.text = "상환 %d원" % amount
		repay.disabled = FranchiseState.money < amount
		var lid: int = int(data["lid"])
		repay.pressed.connect(func() -> void:
			GameServer.request_repay_loan.rpc_id(1, lid))
		row.add_child(repay)
		_loan_box.add_child(row)
	if FranchiseState.loans.size() >= LoanBook.MAX_ACTIVE \
			or LoanBook.has_overdue(FranchiseState.loans):
		return
	for product_id: String in ["small", "medium", "large"]:
		var row: Dictionary = LoanBook.PRODUCTS[product_id]
		var take: Button = Button.new()
		take.add_theme_font_size_override("font_size", 11)
		take.text = "%s대출 +%d원 (일 %.1f%% · %d일 만기 이자 %d%%)" % [
			String(row["label"]), int(row["amount"]),
			float(row["daily_rate"]) * 100.0, int(row["term_days"]),
			int(float(row["maturity_rate"]) * 100.0)]
		var pid: String = product_id
		take.pressed.connect(func() -> void:
			GameServer.request_take_loan.rpc_id(1, pid))
		_loan_box.add_child(take)
