class_name CityMapUi
extends PanelContainer
## 도시 지도 (PLAN.md §6, 준비 단계 전용).
## 도시 카드 목록: 공개 정보(개설 비용·임대료 §7.1)와 개설/이동 버튼.
## 아트 도입 전에는 카드 리스트로 표현한다.

var _rows: VBoxContainer
var _detail: VBoxContainer
var _selected_city: String = ""


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -150.0
	offset_right = 150.0
	offset_top = -140.0
	offset_bottom = 140.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var title: Label = Label.new()
	title.text = "도시 지도  (Esc: 닫기)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	root.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_rows)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 2)
	root.add_child(_detail)

	GameServer.stores_changed.connect(_refresh)
	GameServer.market_info_changed.connect(_refresh)
	GameServer.snapshot_applied.connect(_refresh)
	FranchiseState.money_changed.connect(func(_m: int) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


func _city_defs() -> Array[CityDef]:
	var result: Array[CityDef] = []
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is CityDef:
			result.append(def as CityDef)
	result.sort_custom(func(a: CityDef, b: CityDef) -> bool:
		if a.country_id != b.country_id:
			return String(a.country_id) < String(b.country_id)
		return a.entry_cost < b.entry_cost)
	return result


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	var country_names: Dictionary = {
		"country.korea": "대한민국", "country.japan": "일본",
	}
	var last_country: StringName = StringName()
	for city: CityDef in _city_defs():
		if city.country_id != last_country:
			last_country = city.country_id
			var header: Label = Label.new()
			header.text = "── %s ──" % String(country_names.get(
				String(city.country_id), String(city.country_id)))
			header.add_theme_font_size_override("font_size", 11)
			_rows.add_child(header)
		_rows.add_child(_make_row(city))
	_refresh_detail()


func _make_row(city: CityDef) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var city_id: String = String(city.id)
	var active: bool = city_id == GameServer.my_city()
	var opened: bool = GameServer.store_is_open(city_id)
	var partner_here: bool = false
	for peer: int in GameServer.peer_city.keys():
		if peer != multiplayer.get_unique_id() \
				and String(GameServer.peer_city[peer]) == city_id:
			partner_here = true

	var info: Label = Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 11)
	var rent_today: int = GameServer.current_rent(city_id)
	if active:
		info.text = "%s  [현재 매장]  임대료 %d/일" % [
			city.display_name_ko, rent_today]
	elif opened:
		info.text = "%s  [영업 중]  임대료 %d/일" % [
			city.display_name_ko, rent_today]
	else:
		info.text = "%s  개설 %d원 · 임대료 %d/일" % [
			city.display_name_ko, city.entry_cost, rent_today]
	if partner_here:
		info.text += "  [동료]"
	# 경제 이벤트는 공개 정보 (§7.1) — 시장 조사 없이 표시
	var event: Dictionary = FranchiseState.city_events.get(city_id, {})
	if not event.is_empty():
		var event_id: StringName = StringName(String(event.get("event_id", "")))
		if Defs.has_def(event_id):
			var event_def: EconEventDef = Defs.get_def(event_id) as EconEventDef
			info.text += "  ⚡%s(%d일)" % [
				event_def.display_name_ko, int(event.get("days_left", 0))]
	row.add_child(info)

	var market_button: Button = Button.new()
	market_button.text = "시장"
	market_button.add_theme_font_size_override("font_size", 11)
	market_button.pressed.connect(func() -> void:
		_selected_city = city_id
		_refresh_detail())
	row.add_child(market_button)

	if not active:
		var button: Button = Button.new()
		button.add_theme_font_size_override("font_size", 11)
		if opened:
			button.text = "이동"
			button.pressed.connect(func() -> void:
				GameServer.request_travel.rpc_id(1, city_id))
		else:
			button.text = "개설"
			button.disabled = FranchiseState.money < city.entry_cost
			button.pressed.connect(func() -> void:
				GameServer.request_open_store.rpc_id(1, city_id))
		row.add_child(button)
	return row


## 선택 도시의 시장 정보 상세 (§7.1 공개 정보 외 항목은 조사로만)
func _refresh_detail() -> void:
	for child: Node in _detail.get_children():
		child.queue_free()
	if _selected_city == "" or not Defs.has_def(StringName(_selected_city)):
		return
	var city: CityDef = Defs.get_def(StringName(_selected_city)) as CityDef
	var report: Dictionary = FranchiseState.market_info.get(_selected_city, {})

	var info: Label = Label.new()
	info.add_theme_font_size_override("font_size", 11)
	if report.is_empty():
		info.text = "%s — ⚠ 시장 정보 미확보" % city.display_name_ko
	else:
		var values: Dictionary = report.get("values", {})
		var parts: PackedStringArray = PackedStringArray()
		parts.append("수요 %.2f" % float(values.get("demand", 0.0)))
		if values.has("price_sensitivity"):
			parts.append("가격 민감도 %.2f" % float(values["price_sensitivity"]))
		if values.has("competition"):
			parts.append("경쟁도 %.2f" % float(values["competition"]))
		var age: int = GameClock.day - int(report.get("day", 0))
		var age_text: String = "확인 후 %d일 경과" % age
		if MarketReport.needs_recheck(report, city, GameClock.day):
			age_text += " · 재조사 권장"
		info.text = "%s — %d등급 정보 · %s\n%s" % [
			city.display_name_ko, int(report.get("tier", 0)), age_text,
			" · ".join(parts)]
	_detail.add_child(info)

	var buy_row: HBoxContainer = HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 2)
	_detail.add_child(buy_row)
	for source_id: StringName in [
		&"market.broker.cheap", &"market.broker.pro", &"market.advisor.local"
	]:
		var source: MarketSourceDef = Defs.get_def(source_id) as MarketSourceDef
		var price: int = MarketReport.price_for(source, report)
		var button: Button = Button.new()
		button.add_theme_font_size_override("font_size", 11)
		button.text = "%s %d원" % [source.display_name_ko, price]
		if source.scam_chance > 0.0:
			button.tooltip_text = "사기 위험 %d%%" % int(source.scam_chance * 100)
		button.disabled = FranchiseState.money < price
		var sid: String = String(source_id)
		button.pressed.connect(func() -> void:
			GameServer.request_buy_market_info.rpc_id(1, _selected_city, sid))
		buy_row.add_child(button)
