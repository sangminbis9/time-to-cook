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


## 재직 직원이 없으면 오늘의 채용 후보를, 있으면 현황·해고를 보여준다.
func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	if GameServer.employees.is_empty():
		for i in range(GameServer.job_candidates.size()):
			var c: Dictionary = GameServer.job_candidates[i]
			var button: Button = Button.new()
			button.add_theme_font_size_override("font_size", 11)
			button.text = "고용 %s (%s급·%s) %d원 · 일급 %d" % [
				String(c["name"]), String(c["grade"]), String(c["trait"]),
				int(c["hire_cost"]), int(c["wage"])]
			button.disabled = FranchiseState.money < int(c["hire_cost"])
			var idx: int = i
			button.pressed.connect(func() -> void:
				GameServer.request_hire_candidate.rpc_id(1, idx))
			_rows.add_child(button)
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
		else:
			for day: int in emp.vacation_days:
				if day > GameClock.day:
					status = " · 휴가 %d일 후" % (day - GameClock.day)
					break
		label.text = "%s (%s급·%s) 일급 %d%s" % [
			emp.display_name, emp.grade, emp.trait_name, emp.wage, status]
		row.add_child(label)
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
