class_name StaffUi
extends PanelContainer
## 직원 팝업 (준비 단계 전용): 채용 후보 또는 재직 직원 현황·해고 (§10.2~10.4).
## HUD 우측 상단 [직원] 버튼으로 연다.

var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("modal_ui")
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -160.0
	offset_right = 160.0
	offset_top = -80.0
	offset_bottom = 80.0

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var title: Label = Label.new()
	title.text = "직원  (Esc: 닫기)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	root.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	root.add_child(_rows)

	GameServer.ready_state_changed.connect(_refresh)
	GameServer.employee_changed.connect(func(_eid: int) -> void: _refresh())
	FranchiseState.money_changed.connect(func(_m: int) -> void: _refresh())
	GameClock.phase_changed.connect(func(phase: GameClock.Phase) -> void:
		if phase != GameClock.Phase.PREP:
			queue_free())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


const ROLE_LABELS: Dictionary = {
	"prep": "전처리", "cook": "조리", "serve": "서빙",
	"cashier": "계산", "clean": "청소", "maintain": "정비", "manager": "매니저",
}

## 재배치 대상 선택 중인 직원 (0 = 일반 목록 표시, §10.5)
var _transfer_eid: int = 0


## 재직 직원 현황·해고·재배치 + 오늘의 채용 후보 (역할별 1명 — 중복 역할은 비활성).
func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	if _transfer_eid != 0:
		_refresh_transfer()
		return
	for eid: int in GameServer.employees.keys():
		var emp: EmployeeState = GameServer.employees[eid]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 11)
		var status: String = ""
		if emp.is_on_vacation(GameClock.day):
			status = " · 오늘 휴가"
		elif emp.sick_day == GameClock.day:
			status = " · 오늘 병가"
		elif emp.leave_early_day == GameClock.day:
			status = " · 오늘 조퇴"
		else:
			for day: int in emp.vacation_days:
				if day > GameClock.day:
					status = " · 휴가 %d일 후" % (day - GameClock.day)
					break
		label.text = "[%s] %s (%s급·%s) 일급 %d%s" % [
			emp.get_def().display_name_ko, emp.display_name,
			emp.grade, emp.trait_name, emp.wage, status]
		row.add_child(label)
		if GameServer.opened_city_ids().size() > 1:
			var move: Button = Button.new()
			move.add_theme_font_size_override("font_size", 11)
			move.text = "재배치"
			var move_eid: int = eid
			move.pressed.connect(func() -> void:
				_transfer_eid = move_eid
				_refresh())
			row.add_child(move)
		var fire: Button = Button.new()
		fire.add_theme_font_size_override("font_size", 11)
		var penalty: int = EmployeeRoster.fire_penalty(
			emp.hired_day, emp.min_days, emp.wage, GameClock.day)
		fire.text = "해고" if penalty == 0 else "해고 (위약금 %d)" % penalty
		var fire_eid: int = eid
		fire.pressed.connect(func() -> void:
			GameServer.request_fire_employee.rpc_id(1, fire_eid))
		row.add_child(fire)
		_rows.add_child(row)
	for i in range(GameServer.job_candidates.size()):
		var c: Dictionary = GameServer.job_candidates[i]
		var role: String = String(c.get("role", "prep"))
		var button: Button = Button.new()
		button.add_theme_font_size_override("font_size", 11)
		button.text = "고용 [%s] %s (%s급·%s) %d원 · 일급 %d" % [
			String(ROLE_LABELS.get(role, role)), String(c["name"]),
			String(c["grade"]), String(c["trait"]),
			int(c["hire_cost"]), int(c["wage"])]
		button.disabled = FranchiseState.money < int(c["hire_cost"]) \
			or GameServer.employees.size() >= GameServer.MAX_EMPLOYEES_PER_STORE
		var idx: int = i
		button.pressed.connect(func() -> void:
			GameServer.request_hire_candidate.rpc_id(1, idx))
		_rows.add_child(button)


## 재배치 대상 매장 선택 (§10.5): 개설 매장 중 현재 도시 제외, 운송 비용 표시.
func _refresh_transfer() -> void:
	var emp: EmployeeState = GameServer.employees.get(_transfer_eid)
	if emp == null:
		_transfer_eid = 0
		_refresh()
		return
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 11)
	title.text = "%s 재배치 — 대상 매장 선택" % emp.display_name
	_rows.add_child(title)
	var my_city: String = GameServer.my_city()
	for city_id: String in GameServer.opened_city_ids():
		if city_id == my_city:
			continue
		var city: CityDef = Defs.get_def(StringName(city_id)) as CityDef
		var cost: int = GameServer.transfer_cost(my_city, city_id)
		var button: Button = Button.new()
		button.add_theme_font_size_override("font_size", 11)
		button.text = "%s (운송 %d원)" % [city.display_name_ko, cost]
		button.disabled = FranchiseState.money < cost
		var target: String = city_id
		var eid: int = _transfer_eid
		button.pressed.connect(func() -> void:
			GameServer.request_transfer_employee.rpc_id(1, eid, target)
			_transfer_eid = 0)
		_rows.add_child(button)
	var back: Button = Button.new()
	back.add_theme_font_size_override("font_size", 11)
	back.text = "뒤로"
	back.pressed.connect(func() -> void:
		_transfer_eid = 0
		_refresh())
	_rows.add_child(back)


