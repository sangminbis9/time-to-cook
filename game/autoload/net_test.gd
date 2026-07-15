extends Node
## 통합 테스트 드라이버. `--nettest=host|guest` 유저 플래그가 있을 때만 활성화.
## headless 인스턴스 2개가 localhost ENet으로 실제 게임 RPC를 수행하고
## 각자 미러 상태를 검증한 뒤 결과 JSON을 쓰고 종료한다.
##
## 사용: godot --headless -- --nettest=host --scenario=simultaneous_pickup \
##        --port=7777 --result=/tmp/host.json

const SETTLE_SECONDS: float = 1.0
const TIMEOUT_SECONDS: float = 60.0

var active: bool = false
var role: String = ""
var scenario: String = ""
var port: int = 7777
var address: String = "127.0.0.1"
var result_path: String = ""

var _guest_ready: bool = false
var _guest_done: bool = false
var _go_data: Dictionary = {}
var _checks: Array[Dictionary] = []
var _finished: bool = false
var _step: String = ""
var _steps_done: Dictionary = {}


func _ready() -> void:
	_parse_args()
	if not active:
		return
	get_tree().auto_accept_quit = true
	_run.call_deferred()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		var key: String = parts[0]
		var value: String = parts[1] if parts.size() > 1 else ""
		match key:
			"--nettest":
				role = value
				active = true
			"--scenario":
				scenario = value
			"--port":
				port = int(value)
			"--address":
				address = value
			"--result":
				result_path = value


func _run() -> void:
	var timeout: SceneTreeTimer = get_tree().create_timer(TIMEOUT_SECONDS)
	timeout.timeout.connect(func() -> void: _finish(false, "타임아웃"))

	if role == "host":
		var err: Error = NetworkService.host(port)
		if err != OK:
			_finish(false, "호스트 실패: %d" % err)
			return
	else:
		var err: Error = NetworkService.join(address, port)
		if err != OK:
			_finish(false, "참가 실패: %d" % err)
			return
		await NetworkService.session_started

	get_tree().change_scene_to_file(SceneRouter.STORE_GAMEPLAY)
	await get_tree().process_frame
	await get_tree().process_frame

	if role == "host":
		# 무작위 매장 이벤트 차단 — 시나리오 결정성 유지 (store_events는 수동 강제)
		GameServer.event_fire_chance = 0.0
		GameServer.event_blackout_chance = 0.0
		GameServer.event_burnt_fire_chance = 0.0

	match scenario:
		"simultaneous_pickup":
			await _scenario_simultaneous_pickup()
		"coop_cook_submit":
			await _scenario_coop_cook_submit()
		"day_loop":
			await _scenario_day_loop()
		"fridge":
			await _scenario_fridge()
		"host_quit":
			await _scenario_host_quit()
		"employee":
			await _scenario_employee()
		"economy":
			await _scenario_economy()
		"multi_store":
			await _scenario_multi_store()
		"independent_stores":
			await _scenario_independent_stores()
		"store_events":
			await _scenario_store_events()
		"station_edit":
			await _scenario_station_edit()
		"market":
			await _scenario_market()
		"dynamic_economy":
			await _scenario_dynamic_economy()
		"econ_events":
			await _scenario_econ_events()
		"employee_roster":
			await _scenario_employee_roster()
		"save_write":
			await _scenario_save_write()
		"save_load":
			await _scenario_save_load()
		"screenshot":
			await _scenario_screenshot()
		_:
			_finish(false, "알 수 없는 시나리오: %s" % scenario)


# ── 조율 RPC (테스트 전용 채널) ─────────────────────────────────────

@rpc("any_peer", "reliable")
func t_guest_ready() -> void:
	_guest_ready = true


@rpc("authority", "call_local", "reliable")
func t_go(data: Dictionary) -> void:
	_go_data = data


@rpc("any_peer", "reliable")
func t_guest_done() -> void:
	_guest_done = true


@rpc("authority", "call_local", "reliable")
func t_step(name: String) -> void:
	_step = name


@rpc("any_peer", "call_local", "reliable")
func t_step_done(name: String) -> void:
	_steps_done[name] = true


# ── 시나리오 ─────────────────────────────────────────────────────────

## 동시 줍기 (§16.5/§24.2): 한 아이템을 두 피어가 거의 동시에 주우면
## 정확히 한 명만 성공하고 복제가 없어야 한다.
func _scenario_simultaneous_pickup() -> void:
	var tile: Vector2i = Vector2i(9, 4)
	if role == "host":
		await _wait_until(func() -> bool: return _guest_ready)
		var iid: int = GameServer.server_spawn_floor_item(
			GameServer.my_city(), &"item.raw_chicken", tile)
		_check(iid != 0, "아이템 스폰 성공")
		await _sleep(0.2)
		t_go.rpc({"tile_x": tile.x, "tile_y": tile.y, "iid": iid})
	else:
		await _wait_until(func() -> bool:
			return GameServer.inventory_of(multiplayer.get_unique_id()) != null)
		t_guest_ready.rpc_id(1)
		await _wait_until(func() -> bool: return not _go_data.is_empty())

	var target: Vector2i = Vector2i(
		int(_go_data.get("tile_x", tile.x)), int(_go_data.get("tile_y", tile.y)))
	var iid: int = int(_go_data.get("iid", 0))
	# 양쪽이 같은 신호로 거의 동시에 줍기 시도 (서버 직렬 처리로 한쪽만 성공)
	GameServer.request_pickup.rpc_id(1, target, target + Vector2i(0, 1))
	await _sleep(SETTLE_SECONDS)

	var copies: int = _count_copies(iid)
	_check(copies == 1, "아이템 사본이 정확히 1개 (실제 %d)" % copies)
	_check(GameServer.grid.item_at(target) == 0, "바닥에서 제거됨")
	var holders: int = 0
	for peer: int in GameServer.inventories.keys():
		var inv: InventoryState = GameServer.inventories[peer]
		if inv.all_iids().has(iid):
			holders += 1
	_check(holders == 1, "보유자가 정확히 1명 (실제 %d)" % holders)

	await _teardown()


## 2인 협력 조리·제출 (§29.1): 게스트가 재료 수령·칼질 절반,
## 호스트가 칼질 마무리·튀김옷·튀김·제출. 매출과 주문 상태를 양쪽에서 검증.
func _scenario_coop_cook_submit() -> void:
	# 설비 키: 레이아웃 행 우선 파싱 순서 (i_1, d_1, b_1, f_1, x_1)
	var near_box: Vector2i = Vector2i(1, 2)
	var near_board: Vector2i = Vector2i(3, 2)
	var near_bread: Vector2i = Vector2i(6, 2)
	var near_fryer: Vector2i = Vector2i(9, 2)
	var near_submit: Vector2i = Vector2i(9, 6)
	var board: StationDef = Defs.get_def(&"station.cutting_board") as StationDef
	var fryer_def: StationDef = Defs.get_def(&"station.fryer.basic") as StationDef

	if role == "host":
		await _wait_until(func() -> bool: return _guest_ready)
		# 자동 주문 스포너 격리 — 이 시나리오는 수동 주문 1건만 검증
		GameServer.order_interval_min = 9999.0
		GameServer.order_interval_max = 9999.0
		(GameServer.live[GameServer.my_city()] as LiveStore).next_order_in = 9999.0
		GameClock.set_phase(GameClock.Phase.SERVICE)
		var order: Dictionary = GameServer.server_spawn_order(
			GameServer.my_city(), &"recipe.fried_dakgangjeong")
		_check(not order.is_empty(), "주문 생성")
		t_step.rpc("guest_cook")
		await _wait_until(func() -> bool: return _steps_done.has("guest_cook"))

		# 게스트가 칼질 3회를 했다 — 호스트가 이어서 마무리 (§19.3 협력)
		var remaining: int = board.required_cuts - 3
		for i in range(remaining):
			GameServer.request_station_work.rpc_id(1, &"d_1", near_board)
		await _sleep(0.3)
		var board_st: StationState = GameServer.station(&"d_1")
		var cut_item: ItemInstance = GameServer.get_item(board_st.item_iid)
		_check(cut_item != null and cut_item.def_id == &"item.cut_chicken",
			"칼질 협력 완성 → 손질된 닭")

		# 집기 → 튀김옷 → 튀김
		GameServer.request_station_interact.rpc_id(1, &"d_1", near_board)
		GameServer.request_station_interact.rpc_id(1, &"b_1", near_bread)
		GameServer.request_station_work.rpc_id(1, &"b_1", near_bread)
		GameServer.request_station_interact.rpc_id(1, &"b_1", near_bread)
		GameServer.request_station_interact.rpc_id(1, &"f_1", near_fryer)
		await _sleep(0.3)
		var fryer_st: StationState = GameServer.station(&"f_1")
		_check(fryer_st.item_iid != 0, "튀김기 투입")

		# 정상 구간까지 대기 (덜 익음에 미리 꺼내 재투입 검증 포함)
		await _sleep(2.0)
		GameServer.request_station_interact.rpc_id(1, &"f_1", near_fryer)  # 덜 익음 꺼내기
		await _sleep(0.2)
		var early: ItemInstance = _held_item(1)
		_check(early != null and early.def_id == &"item.breaded_chicken"
			and early.cook_elapsed > 0.0, "덜 익음: 진행도 유지한 채 꺼냄")
		GameServer.request_station_interact.rpc_id(1, &"f_1", near_fryer)  # 재투입
		await _wait_until(func() -> bool:
			var st: StationState = GameServer.station(&"f_1")
			if st == null or st.item_iid == 0:
				return false
			var it: ItemInstance = GameServer.get_item(st.item_iid)
			return it != null and CookStateMachine.state_for(
				it.cook_elapsed, fryer_def) == CookStateMachine.State.NORMAL)
		GameServer.request_station_interact.rpc_id(1, &"f_1", near_fryer)  # 꺼내기
		await _sleep(0.3)
		var dish: ItemInstance = _held_item(1)
		_check(dish != null and dish.def_id == &"item.dakgangjeong",
			"정상 구간 꺼내기 → 닭강정")

		# 제출 → 매출
		GameServer.request_station_interact.rpc_id(1, &"x_1", near_submit)
		await _sleep(0.3)
		_check(FranchiseState.money == 3000, "매출 3000원 반영 (실제 %d)"
			% FranchiseState.money)
		_check(GameServer.orders.active.is_empty(), "주문 완료됨")
		# 같은 접시 재제출 불가 (아이템 소멸) + 주문 없음
		GameServer.request_station_interact.rpc_id(1, &"x_1", near_submit)
		await _sleep(0.2)
		_check(FranchiseState.money == 3000, "중복 제출로 매출 증가 없음")
		t_step.rpc("verify")
		await _teardown()
	else:
		await _wait_until(func() -> bool:
			return GameServer.inventory_of(multiplayer.get_unique_id()) != null)
		t_guest_ready.rpc_id(1)
		await _wait_until(func() -> bool: return _step == "guest_cook")
		# 재료 수령 → 도마 배치 → 칼질 3회
		GameServer.request_station_interact.rpc_id(1, &"i_1", near_box)
		await _sleep(0.3)
		var raw: ItemInstance = _held_item(multiplayer.get_unique_id())
		_check(raw != null and raw.def_id == &"item.raw_chicken", "재료 수령")
		GameServer.request_station_interact.rpc_id(1, &"d_1", near_board)
		for i in range(3):
			GameServer.request_station_work.rpc_id(1, &"d_1", near_board)
		await _sleep(0.3)
		t_step_done.rpc_id(1, "guest_cook")
		await _wait_until(func() -> bool: return _step == "verify")
		await _sleep(0.5)
		_check(FranchiseState.money == 3000, "게스트 미러: 매출 3000원 (실제 %d)"
			% FranchiseState.money)
		_check(GameServer.orders.active.is_empty(), "게스트 미러: 주문 완료")
		var fryer_st: StationState = GameServer.station(&"f_1")
		_check(fryer_st != null and fryer_st.item_iid == 0, "게스트 미러: 튀김기 비움")
		await _teardown()


## 하루 루프 2회 (§5, §18, §29.4): 준비→(전원 R)→영업→시간 종료→마감 폐기→
## 정산→(전원 R)→다음 날. 인벤토리 아이템이 폐기되는지 확인.
func _scenario_day_loop() -> void:
	if role == "host":
		await _wait_until(func() -> bool: return _guest_ready)
		GameClock.service_length = 3.0  # 테스트용 초단축 영업
		FranchiseState.set_money(50000)
		for cycle in range(2):
			var day_before: int = GameClock.day
			# 2일차부터는 재고가 0 — 준비 단계에서 주문 (§21.1)
			if GameServer.ingredient_stock < 1:
				GameServer.request_buy_stock.rpc_id(1, 10)
				await _sleep(0.2)
			# 폐기 대상 아이템 하나 수령
			GameServer.request_station_interact.rpc_id(1, &"i_1", Vector2i(1, 2))
			await _sleep(0.2)
			_check(_held_item(1) != null, "%d일차: 재료 수령" % day_before)
			# 전원 준비 완료 → 영업 시작
			t_step.rpc("ready_%d" % cycle)
			GameServer.request_ready_toggle.rpc_id(1)
			await _wait_until(func() -> bool:
				return GameClock.phase == GameClock.Phase.SERVICE)
			_check(true, "%d일차: 영업 시작 (전원 준비)" % day_before)
			# 영업 종료 대기 → 정산
			await _wait_until(func() -> bool:
				return GameClock.phase == GameClock.Phase.SETTLEMENT)
			_check(_held_item(1) == null, "%d일차: 마감 폐기 — 인벤토리 비움" % day_before)
			_check(GameServer.items.is_empty(), "%d일차: 아이템 레지스트리 비움" % day_before)
			_check(GameServer.disposed_today >= 1, "%d일차: 폐기 집계" % day_before)
			# 전원 다음 날 → 준비 단계
			t_step.rpc("next_%d" % cycle)
			GameServer.request_ready_toggle.rpc_id(1)
			await _wait_until(func() -> bool:
				return GameClock.day == day_before + 1 \
					and GameClock.phase == GameClock.Phase.PREP)
			_check(GameServer.ingredient_stock == 0,
				"%d일차 시작: 잔여 재료 폐기됨 (주문 필요)" % (day_before + 1))
		_check(GameClock.day == 3, "2회 루프 후 3일차")
		t_step.rpc("verify")
		await _teardown()
	else:
		await _wait_until(func() -> bool:
			return GameServer.inventory_of(multiplayer.get_unique_id()) != null)
		t_guest_ready.rpc_id(1)
		for cycle in range(2):
			await _wait_until(func() -> bool: return _step == "ready_%d" % cycle)
			GameServer.request_ready_toggle.rpc_id(1)
			await _wait_until(func() -> bool: return _step == "next_%d" % cycle)
			GameServer.request_ready_toggle.rpc_id(1)
		await _wait_until(func() -> bool: return _step == "verify")
		await _sleep(0.5)
		_check(GameClock.day == 3, "게스트 미러: 3일차 (실제 %d)" % GameClock.day)
		_check(GameClock.phase == GameClock.Phase.PREP, "게스트 미러: 준비 단계")
		_check(GameServer.items.is_empty(), "게스트 미러: 아이템 폐기 반영")
		await _teardown()


## 냉장고 (§17): 단독 잠금, 보관 이동, 마감 생존, 연결 해제 시 잠금 회수.
func _scenario_fridge() -> void:
	var near_fridge: Vector2i = Vector2i(12, 2)
	if role == "host":
		await _wait_until(func() -> bool: return _guest_ready)
		GameClock.service_length = 3.0
		# 재료 수령 → 냉장고 열기 → 슬롯 0으로 이동
		GameServer.request_station_interact.rpc_id(1, &"i_1", Vector2i(1, 2))
		await _sleep(0.2)
		var raw_iid: int = GameServer.inventory_of(1).selected_iid()
		_check(raw_iid != 0, "재료 수령")
		GameServer.request_station_interact.rpc_id(1, &"r_1", near_fridge)
		await _sleep(0.2)
		_check(GameServer.fridge.lock_owner == 1, "호스트가 냉장고 잠금 획득")
		# 게스트가 열기 시도 → 거부 확인
		t_step.rpc("guest_try_open")
		await _wait_until(func() -> bool: return _steps_done.has("guest_try_open"))
		_check(GameServer.fridge.lock_owner == 1, "경합 중에도 잠금 유지")
		# 보관 이동 + 닫기
		GameServer.request_fridge_move.rpc_id(
			1, 1, GameServer.inventory_of(1).selected, 0, 0)
		await _sleep(0.2)
		_check(GameServer.fridge.slots[0] == raw_iid, "냉장고 슬롯 0 보관")
		GameServer.request_fridge_close.rpc_id(1)
		await _sleep(0.2)
		_check(GameServer.fridge.lock_owner == 0, "닫기 후 잠금 해제")
		# 하루 마감 — 냉장고만 생존 (§18)
		t_step.rpc("day_cycle")
		GameServer.request_ready_toggle.rpc_id(1)
		await _wait_until(func() -> bool:
			return GameClock.phase == GameClock.Phase.SETTLEMENT)
		_check(GameServer.fridge.slots[0] == raw_iid, "마감 후 냉장고 아이템 생존")
		_check(GameServer.items.has(raw_iid), "생존 아이템 레지스트리 유지")
		# 게스트: 냉장고 열고 연결 종료 → 잠금 자동 회수 (§17.5)
		t_step.rpc("guest_lock_and_leave")
		await _wait_until(func() -> bool:
			return multiplayer.get_peers().is_empty())
		await _sleep(0.5)
		_check(GameServer.fridge.lock_owner == 0, "연결 종료 시 잠금 회수")
		_finish(_all_passed(), "")
	else:
		await _wait_until(func() -> bool:
			return GameServer.inventory_of(multiplayer.get_unique_id()) != null)
		t_guest_ready.rpc_id(1)
		await _wait_until(func() -> bool: return _step == "guest_try_open")
		GameServer.request_station_interact.rpc_id(1, &"r_1", near_fridge)
		await _sleep(0.3)
		_check(GameServer.fridge.lock_owner == 1, "게스트 미러: 열기 거부, 잠금 1")
		t_step_done.rpc_id(1, "guest_try_open")
		await _wait_until(func() -> bool: return _step == "day_cycle")
		GameServer.request_ready_toggle.rpc_id(1)
		await _wait_until(func() -> bool:
			return GameClock.phase == GameClock.Phase.SETTLEMENT)
		_check(GameServer.fridge.slots[0] != 0, "게스트 미러: 냉장고 생존")
		await _wait_until(func() -> bool: return _step == "guest_lock_and_leave")
		GameServer.request_station_interact.rpc_id(1, &"r_1", near_fridge)
		await _sleep(0.3)
		_check(GameServer.fridge.lock_owner == multiplayer.get_unique_id(),
			"게스트가 잠금 획득")
		# 결과 기록 후 즉시 연결 종료 — 호스트가 잠금 회수를 검증
		_finish(_all_passed(), "")


## 호스트 종료 → 게스트 세션 정리·타이틀 복귀 (§4.2, §29.4).
func _scenario_host_quit() -> void:
	if role == "host":
		await _wait_until(func() -> bool: return _guest_ready)
		t_step.rpc("host_leaving")
		await _sleep(0.3)
		NetworkService.leave()  # 정상 종료 — 게스트에게 즉시 통지
		_check(true, "호스트 정상 종료")
		_finish(_all_passed(), "")
	else:
		await _wait_until(func() -> bool:
			return GameServer.inventory_of(multiplayer.get_unique_id()) != null)
		t_guest_ready.rpc_id(1)
		await _wait_until(func() -> bool: return _step == "host_leaving")
		await _wait_until(func() -> bool:
			return not NetworkService.is_session_active)
		_check(true, "세션 종료 감지")
		await _sleep(0.5)
		var scene: Node = get_tree().current_scene
		_check(scene != null and scene.name == "Title",
			"타이틀 복귀 (실제: %s)" % (scene.name if scene != null else "없음"))
		_check(SceneRouter.pending_notice == "" \
			or get_tree().current_scene.name == "Title", "세션 정리 완료")
		_finish(_all_passed(), "")


## 직원 (§10, 솔로): 고용 → 자동 전처리(재료함→도마→칼질→출력) →
## 작업 독점(플레이어 개입 차단) → 정산 급여 차감.
func _scenario_employee() -> void:
	FranchiseState.set_money(50000)
	GameClock.service_length = 25.0
	_inject_and_hire_basic()
	await _sleep(0.2)
	_check(GameServer.employees.size() == 1, "직원 고용")
	_check(FranchiseState.money == 45000, "고용비 차감 (실제 %d)"
		% FranchiseState.money)
	# 영업 시작 → 직원이 스스로 일한다
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SERVICE)
	# 직원이 도마를 점유할 때까지 대기 → 플레이어 개입 차단 확인 (§10.6)
	await _wait_until(func() -> bool:
		return GameServer.station_employee.has(GameServer.EMP_BOARD_KEY))
	_check(true, "직원이 도마 점유")
	await _wait_until(func() -> bool:
		var st: StationState = GameServer.station(GameServer.EMP_BOARD_KEY)
		return st != null and st.item_iid != 0)
	var board: StationState = GameServer.station(GameServer.EMP_BOARD_KEY)
	var working_iid: int = board.item_iid
	GameServer.request_station_interact.rpc_id(
		1, GameServer.EMP_BOARD_KEY, Vector2i(4, 2))
	GameServer.request_station_work.rpc_id(
		1, GameServer.EMP_BOARD_KEY, Vector2i(4, 2))
	await _sleep(0.2)
	_check(board.item_iid == working_iid, "플레이어 개입 차단 — 아이템 유지")
	# 출력 작업대에 손질된 닭이 놓일 때까지
	await _wait_until(func() -> bool:
		var out: StationState = GameServer.station(GameServer.EMP_OUTPUT_KEY)
		if out == null or out.item_iid == 0:
			return false
		var item: ItemInstance = GameServer.get_item(out.item_iid)
		return item != null and item.def_id == &"item.cut_chicken")
	_check(true, "직원이 손질된 닭 생산 → 출력 작업대")
	# 정산 급여
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	_check(FranchiseState.money == 40000,
		"정산 급여+임대료 차감 45000-3000-2000 (실제 %d)" % FranchiseState.money)
	_check(GameServer.station_employee.is_empty(), "마감 후 점유 해제")
	_finish(_all_passed(), "")


## 경영 (§8/§9/§21, 솔로): 대출 → 가격 인상 → 재료 주문 → 판매(설정가 반영)
## → 정산 이자 자동 납부 → 다음 날 전액 상환.
func _scenario_economy() -> void:
	FranchiseState.set_money(10000)
	GameClock.service_length = 25.0
	# 가격 인상(수용률 0.67)으로 스폰이 간헐 스킵됨 — 짧은 간격으로 재시도 보장
	GameServer.order_interval_min = 1.0
	GameServer.order_interval_max = 2.0
	# 대출 + 가격 4000원 + 재료 10개 주문
	GameServer.request_take_loan.rpc_id(1)
	await _sleep(0.2)
	_check(FranchiseState.money == 60000, "대출 실행 (실제 %d)" % FranchiseState.money)
	_check(FranchiseState.loan_principal == 50000, "대출 원금 기록")
	GameServer.request_take_loan.rpc_id(1)
	await _sleep(0.2)
	_check(FranchiseState.money == 60000, "중복 대출 거부")
	GameServer.request_set_price.rpc_id(1, &"recipe.fried_dakgangjeong", 4000)
	GameServer.request_buy_stock.rpc_id(1, 10)
	await _sleep(0.2)
	_check(FranchiseState.money == 55000, "재료 10개 구매 (실제 %d)"
		% FranchiseState.money)
	_check(GameServer.ingredient_stock == GameServer.daily_stock + 10, "재고 증가")
	# 영업: 닭강정 1개 조리·판매 — 설정 가격 반영
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SERVICE)
	GameServer.request_station_interact.rpc_id(1, &"i_1", Vector2i(1, 2))
	GameServer.request_station_interact.rpc_id(1, &"d_1", Vector2i(3, 2))
	for i in range(6):
		GameServer.request_station_work.rpc_id(1, &"d_1", Vector2i(3, 2))
	GameServer.request_station_interact.rpc_id(1, &"d_1", Vector2i(3, 2))
	GameServer.request_station_interact.rpc_id(1, &"b_1", Vector2i(6, 2))
	GameServer.request_station_work.rpc_id(1, &"b_1", Vector2i(6, 2))
	GameServer.request_station_interact.rpc_id(1, &"b_1", Vector2i(6, 2))
	GameServer.request_station_interact.rpc_id(1, &"f_1", Vector2i(9, 2))
	var fryer_def: StationDef = Defs.get_def(&"station.fryer.basic") as StationDef
	await _wait_until(func() -> bool:
		var st: StationState = GameServer.station(&"f_1")
		if st == null or st.item_iid == 0:
			return false
		var it: ItemInstance = GameServer.get_item(st.item_iid)
		return it != null and CookStateMachine.state_for(
			it.cook_elapsed, fryer_def) == CookStateMachine.State.NORMAL)
	GameServer.request_station_interact.rpc_id(1, &"f_1", Vector2i(9, 2))
	# 활성 주문 대기 (자동 스포너) 후 제출
	await _wait_until(func() -> bool: return not GameServer.orders.active.is_empty())
	GameServer.request_station_interact.rpc_id(1, &"x_1", Vector2i(9, 6))
	await _sleep(0.3)
	_check(FranchiseState.money == 59000,
		"설정가 4000원 매출 반영 (실제 %d)" % FranchiseState.money)
	# 정산: 이자 1000원 자동 납부
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	_check(FranchiseState.money == 56000,
		"이자 1000+임대료 2000 납부 (실제 %d)" % FranchiseState.money)
	# 다음 날 전액 상환
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.PREP)
	GameServer.request_repay_loan.rpc_id(1)
	await _sleep(0.2)
	_check(FranchiseState.loan_principal == 0, "전액 상환")
	_check(FranchiseState.money == 6000, "상환 후 자금 (실제 %d)"
		% FranchiseState.money)
	_finish(_all_passed(), "")


## 다매장 (§6, 솔로): 부산 개설 → 매장별 상태 분리 → 오프라인 자동화 매출·
## 임대료 정산 → 인천 복귀 시 상태 복원.
func _scenario_multi_store() -> void:
	FranchiseState.set_money(200000)
	GameClock.service_length = 3.0
	# 인천에 직원 고용 + 냉장고에 재료 보관 (분리 확인용 상태 만들기)
	_inject_and_hire_basic()
	GameServer.request_station_interact.rpc_id(1, &"i_1", Vector2i(1, 2))
	await _sleep(0.2)
	GameServer.request_station_interact.rpc_id(1, &"r_1", Vector2i(12, 2))
	await _sleep(0.2)
	GameServer.request_fridge_move.rpc_id(
		1, 1, GameServer.inventory_of(1).selected, 0, 0)
	GameServer.request_fridge_close.rpc_id(1)
	await _sleep(0.2)
	var incheon_fridge_iid: int = GameServer.fridge.slots[0]
	_check(incheon_fridge_iid != 0, "인천 냉장고 보관")
	_check(FranchiseState.money == 195000, "고용비 차감 (실제 %d)"
		% FranchiseState.money)
	# 부산 개설 (80000) → 이동
	GameServer.request_open_store.rpc_id(1, "city.korea.busan")
	await _sleep(0.2)
	_check(FranchiseState.money == 115000, "부산 개설비 차감 (실제 %d)"
		% FranchiseState.money)
	GameServer.request_travel.rpc_id(1, "city.korea.busan")
	await _sleep(0.3)
	_check(GameServer.my_city() == "city.korea.busan", "부산으로 이동")
	_check(GameServer.fridge.slots[0] == 0, "부산 냉장고는 비어 있음 (상태 분리)")
	_check(GameServer.employees.is_empty(), "부산에 직원 없음 (상태 분리)")
	_check(GameServer.ingredient_stock == 0, "부산 신규 매장 재고 0")
	# 부산에서 하루 진행 — 인천 직원의 자동화 매출 + 양쪽 임대료
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	# 기대: 오프라인 유효수요 = 1.5×1.0÷(0.5+0.5×0.8) = 1.667 → 1명×1333원
	# 115000 + 1333 - 급여 3000 - 임대료(2000+3000)
	_check(FranchiseState.money == 115000 + 1333 - 3000 - 5000,
		"정산: 자동화 매출(유효 수요)+임대료+원격 급여 (실제 %d)" % FranchiseState.money)
	# 인천 복귀 → 상태 복원
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.PREP)
	GameServer.request_travel.rpc_id(1, "city.korea.incheon")
	await _sleep(0.3)
	_check(GameServer.my_city() == "city.korea.incheon", "인천 복귀")
	_check(GameServer.fridge.slots[0] == incheon_fridge_iid,
		"인천 냉장고 아이템 복원")
	_check(GameServer.employees.size() == 1, "인천 직원 복원")
	_finish(_all_passed(), "")


## 독립 매장 이동 (§6, 2인): 게스트만 부산으로 이동 → 두 매장 동시 라이브·
## 상태 격리(주문·바닥 아이템) → 정산은 양쪽 임대료 합산 → 복귀 시 재합류.
func _scenario_independent_stores() -> void:
	const BUSAN: String = "city.korea.busan"
	const INCHEON: String = "city.korea.incheon"
	if role == "host":
		await _wait_until(func() -> bool: return _guest_ready)
		var guest: int = multiplayer.get_peers()[0]
		FranchiseState.set_money(200000)
		GameClock.service_length = 3.0
		GameServer.request_open_store.rpc_id(1, BUSAN)
		await _sleep(0.2)
		_check(FranchiseState.money == 120000, "부산 개설비 차감 (실제 %d)"
			% FranchiseState.money)
		# 게스트만 부산으로 — 호스트는 인천에 남는다
		t_step.rpc("travel")
		await _wait_until(func() -> bool:
			return GameServer.city_of_peer(guest) == BUSAN)
		_check(GameServer.my_city() == INCHEON, "호스트는 인천 유지")
		_check(GameServer.live.size() == 2, "라이브 매장 2개 (실제 %d)"
			% GameServer.live.size())
		_check(not FranchiseState.stores.has(BUSAN), "부산은 오프라인 번들에서 빠짐")
		# 매장 상태 격리: 인천 바닥 아이템·부산 주문이 서로 새지 않아야 한다
		var iid: int = GameServer.server_spawn_floor_item(
			INCHEON, &"item.raw_chicken", Vector2i(9, 4))
		_check(iid != 0, "인천 바닥 아이템 스폰")
		var order: Dictionary = GameServer.server_spawn_order(
			BUSAN, &"recipe.fried_dakgangjeong")
		_check(not order.is_empty(), "부산 주문 생성")
		await _sleep(0.3)
		_check(GameServer.orders.active.is_empty(), "호스트(인천) 주문 목록 비어 있음")
		_check(GameServer.grid.item_at(Vector2i(9, 4)) == iid, "인천 바닥 아이템 존재")
		t_step.rpc("verify_busan")
		await _wait_until(func() -> bool: return _steps_done.has("verify_busan"))
		# 하루 진행: 두 매장 모두 라이브 → 자동화 매출 없음, 임대료는 양쪽 합산
		t_step.rpc("ready_day")
		GameServer.request_ready_toggle.rpc_id(1)
		await _wait_until(func() -> bool:
			return GameClock.phase == GameClock.Phase.SETTLEMENT)
		# 120000 - 임대료(인천 2000 + 부산 3000)
		_check(FranchiseState.money == 115000,
			"정산: 양쪽 임대료 합산 (실제 %d)" % FranchiseState.money)
		t_step.rpc("next_day")
		GameServer.request_ready_toggle.rpc_id(1)
		await _wait_until(func() -> bool:
			return GameClock.phase == GameClock.Phase.PREP)
		# 게스트 복귀 → 부산은 오프라인 번들로
		t_step.rpc("come_back")
		await _wait_until(func() -> bool:
			return GameServer.city_of_peer(guest) == INCHEON)
		_check(GameServer.live.size() == 1, "라이브 매장 1개로 복귀")
		_check(FranchiseState.stores.has(BUSAN), "부산 오프라인 번들 보관")
		t_step.rpc("verify_home")
		await _teardown()
	else:
		await _wait_until(func() -> bool:
			return GameServer.inventory_of(multiplayer.get_unique_id()) != null)
		t_guest_ready.rpc_id(1)
		await _wait_until(func() -> bool: return _step == "travel")
		GameServer.request_travel.rpc_id(1, BUSAN)
		await _wait_until(func() -> bool: return GameServer.my_city() == BUSAN)
		await _wait_until(func() -> bool: return _step == "verify_busan")
		await _sleep(0.3)
		_check(GameServer.orders.active.size() == 1, "게스트(부산) 주문 1건 보임")
		_check(GameServer.grid.floor_items.is_empty(),
			"게스트(부산) 바닥은 비어 있음 (인천 아이템 미노출)")
		_check(GameServer.fridge.slots[0] == 0, "부산 신규 매장 냉장고 비어 있음")
		_check(GameServer.ingredient_stock == 0, "부산 신규 매장 재고 0")
		t_step_done.rpc("verify_busan")
		await _wait_until(func() -> bool: return _step == "ready_day")
		GameServer.request_ready_toggle.rpc_id(1)
		await _wait_until(func() -> bool: return _step == "next_day")
		GameServer.request_ready_toggle.rpc_id(1)
		await _wait_until(func() -> bool: return _step == "come_back")
		GameServer.request_travel.rpc_id(1, INCHEON)
		await _wait_until(func() -> bool: return GameServer.my_city() == INCHEON)
		await _wait_until(func() -> bool: return _step == "verify_home")
		await _sleep(0.3)
		_check(GameServer.my_city() == INCHEON, "게스트 인천 복귀")
		await _teardown()


## 매장 이벤트 (§23.1/§23.3, 솔로): 화재(아이템 소실·주문 정지·J 연타 진압),
## 정전(조리 정지·차단기 복구 후 재개).
func _scenario_store_events() -> void:
	const CITY: String = "city.korea.incheon"
	var near_fryer: Vector2i = Vector2i(9, 2)
	var near_fridge: Vector2i = Vector2i(12, 2)
	GameClock.service_length = 60.0
	GameServer.order_interval_min = 0.1
	GameServer.order_interval_max = 0.2
	GameClock.set_phase(GameClock.Phase.SERVICE)
	_check(GameServer.current_store_event().is_empty(), "초기: 이벤트 없음")

	# ── 화재: 튀김기 아이템 소실 + 주문 정지 + J 연타 진압
	var iid: int = GameServer.next_iid
	GameServer.next_iid += 1
	var item: ItemInstance = ItemInstance.create(iid, &"item.breaded_chicken")
	GameServer.items[iid] = item
	var fryer: StationState = GameServer.station(&"f_2")
	fryer.item_iid = iid
	fryer.work_in_progress = true
	GameServer.server_start_store_event(CITY, "fire", &"f_2")
	await _sleep(0.6)
	_check(String(GameServer.current_store_event().get("type", "")) == "fire",
		"화재 시작")
	_check(GameServer.get_item(iid) == null, "화재로 튀김기 아이템 소실")
	_check(fryer.item_iid == 0, "튀김기 비워짐")
	_check(GameServer.orders.active.is_empty(), "화재 중 주문 정지")
	# 불붙은 설비에 J = 진압 (놓기/집기 대신 인터셉트)
	GameServer.request_station_interact.rpc_id(1, &"f_2", near_fryer)
	await _sleep(0.2)
	_check(String(GameServer.current_store_event().get("type", "")) == "fire"
		and int(GameServer.current_store_event().get("hits", 0)) == 1,
		"진압 1회 누적")
	GameServer.request_station_interact.rpc_id(1, &"f_2", near_fryer)
	await _sleep(0.2)
	GameServer.request_station_interact.rpc_id(1, &"f_2", near_fryer)
	await _sleep(0.3)
	_check(GameServer.current_store_event().is_empty(), "3회 진압으로 화재 해제")
	await _sleep(0.6)
	_check(not GameServer.orders.active.is_empty(), "진압 후 주문 재개")

	# ── 정전: 조리 정지 + 차단기(냉장고 J) 복구 후 재개
	var iid2: int = GameServer.next_iid
	GameServer.next_iid += 1
	var item2: ItemInstance = ItemInstance.create(iid2, &"item.breaded_chicken")
	GameServer.items[iid2] = item2
	var fryer1: StationState = GameServer.station(&"f_1")
	fryer1.item_iid = iid2
	fryer1.work_in_progress = true
	GameServer.server_start_store_event(CITY, "blackout")
	await _sleep(0.6)
	_check(String(GameServer.current_store_event().get("type", "")) == "blackout",
		"정전 시작")
	_check(item2.cook_elapsed == 0.0, "정전: 조리 정지 (실제 %.2f)"
		% item2.cook_elapsed)
	GameServer.request_station_interact.rpc_id(1, &"r_1", near_fridge)
	await _sleep(0.2)
	_check(GameServer.current_store_event().is_empty(), "차단기 복구로 정전 해제")
	_check(GameServer.fridge.lock_owner == 0, "복구 시 냉장고 UI 미개방")
	await _sleep(0.6)
	_check(item2.cook_elapsed > 0.0, "복구 후 조리 재개")
	_finish(_all_passed(), "")


## 설비 배치 (§15, 솔로): 이동 → 점유/스폰 칸 거부 → 구매 → 자금 부족 거부 →
## 스냅샷 직렬화 왕복으로 배치 보존 확인.
func _scenario_station_edit() -> void:
	FranchiseState.set_money(20000)
	_check(GameServer.station_key_at(Vector2i(1, 1)) == &"c_1", "초기 배치 c_1")
	# 이동: 작업대 c_1 (1,1) → (5,4)
	GameServer.request_move_station.rpc_id(1, &"c_1", Vector2i(5, 4))
	await _sleep(0.2)
	_check(GameServer.station_key_at(Vector2i(5, 4)) == &"c_1", "이동 반영")
	_check(GameServer.station_key_at(Vector2i(1, 1)) == StringName(), "원래 칸 비움")
	_check(GameServer.grid.can_place_item(Vector2i(1, 1)), "빈 칸에 아이템 배치 가능")
	_check(not GameServer.grid.can_place_item(Vector2i(5, 4)), "새 칸은 차단")
	# 점유 칸·스폰 칸으로는 이동 불가
	GameServer.request_move_station.rpc_id(1, &"d_1", Vector2i(5, 4))
	await _sleep(0.2)
	_check(GameServer.station_tile(&"d_1") == Vector2i(2, 1), "점유 칸 이동 거부")
	GameServer.request_move_station.rpc_id(1, &"d_1", Vector2i(8, 5))
	await _sleep(0.2)
	_check(GameServer.station_tile(&"d_1") == Vector2i(2, 1), "스폰 칸 이동 거부")
	# 구매: 튀김기 12000원 → u_1 키로 배치
	GameServer.request_buy_station.rpc_id(1, &"station.fryer.basic", Vector2i(6, 4))
	await _sleep(0.2)
	_check(FranchiseState.money == 8000, "구매비 차감 (실제 %d)" % FranchiseState.money)
	_check(GameServer.station_key_at(Vector2i(6, 4)) == &"u_1", "구매 설비 배치")
	var bought: StationState = GameServer.station(&"u_1")
	_check(bought != null
		and bought.get_def().kind == StationDef.Kind.FRYER, "설비 상태 생성")
	# 자금 부족 → 구매 거부
	GameServer.request_buy_station.rpc_id(1, &"station.fryer.basic", Vector2i(7, 4))
	await _sleep(0.2)
	_check(GameServer.station_key_at(Vector2i(7, 4)) == StringName(),
		"자금 부족 구매 거부")
	# 직렬화 왕복: 스냅샷 재적용 후에도 배치·구매 설비 유지 (세이브 경로와 동일)
	GameServer.apply_snapshot_local(GameServer.build_snapshot())
	await _sleep(0.1)
	_check(GameServer.station_key_at(Vector2i(5, 4)) == &"c_1", "왕복 후 이동 유지")
	_check(GameServer.station_key_at(Vector2i(6, 4)) == &"u_1", "왕복 후 구매 유지")
	# 관리 팝업·배치 모드 스모크: 생성·갱신 경로 런타임 오류 없는지
	for popup: Control in [StoreEditUi.new(), StaffUi.new(), ManageUi.new()]:
		get_tree().root.add_child(popup)
		await _sleep(0.1)
		popup.queue_free()
		await _sleep(0.05)
	var scene: Node = get_tree().get_first_node_in_group("store_scene")
	_check(scene != null, "매장 씬 그룹 등록")
	scene.begin_move_station(&"c_1")
	scene.begin_buy_station(&"station.counter")
	await _sleep(0.2)
	_check(true, "관리 팝업·배치 모드 스모크")
	_finish(_all_passed(), "")


## 시장 정보 (§7, 솔로): 구매 → 업그레이드 할인 → 사기(전액 손실·기존 정보 유지).
func _scenario_market() -> void:
	FranchiseState.set_money(50000)
	var cheap: MarketSourceDef = Defs.get_def(&"market.broker.cheap") as MarketSourceDef
	# 결정적 테스트를 위해 사기 확률 제어 (정의 특성은 게임에선 영구 고정 §7.3)
	cheap.scam_chance = 0.0
	_check(FranchiseState.market_info.is_empty(), "초기: 시장 정보 미확보")
	# 1등급 구매 (3000)
	GameServer.request_buy_market_info.rpc_id(
		1, "city.korea.busan", "market.broker.cheap")
	await _sleep(0.2)
	_check(FranchiseState.money == 47000, "1등급 구매 (실제 %d)" % FranchiseState.money)
	var report: Dictionary = FranchiseState.market_info.get("city.korea.busan", {})
	_check(int(report.get("tier", 0)) == 1, "1등급 기록")
	_check((report.get("values", {}) as Dictionary).has("demand")
		and not (report.get("values", {}) as Dictionary).has("competition"),
		"1등급은 수요만 공개")
	# 3등급 자문 업그레이드: 15000 - 3000 = 12000 할인 (§7.6)
	GameServer.request_buy_market_info.rpc_id(
		1, "city.korea.busan", "market.advisor.local")
	await _sleep(0.2)
	_check(FranchiseState.money == 35000,
		"업그레이드 할인 12000원 (실제 %d)" % FranchiseState.money)
	report = FranchiseState.market_info.get("city.korea.busan", {})
	var busan: CityDef = Defs.get_def(&"city.korea.busan") as CityDef
	_check(float((report.get("values", {}) as Dictionary).get("competition", 0.0)) \
		== busan.competition, "자문은 정확한 값 (§7.4)")
	_check(int(report.get("paid_total", 0)) == 15000, "실지불 누적 3000+12000")
	# 사기: 확률 100%로 강제 → 전액 손실, 정보 미획득, 기존 정보 유지 (§7.3)
	cheap.scam_chance = 1.0
	GameServer.request_buy_market_info.rpc_id(
		1, "city.korea.daegu", "market.broker.cheap")
	await _sleep(0.2)
	_check(FranchiseState.money == 32000, "사기: 지불액 전액 손실")
	_check(not FranchiseState.market_info.has("city.korea.daegu"), "사기: 정보 미획득")
	_check(FranchiseState.market_info.has("city.korea.busan"), "사기: 기존 정보 유지")
	cheap.scam_chance = 0.15
	_finish(_all_passed(), "")


## 동적 경제 (§8.1, 솔로): 기본가에서는 주문이 발생하고, 과도한 인상(수용률 0)
## 에서는 주문이 오지 않으며, 다음 날 도시 수요 배율이 드리프트한다.
func _scenario_dynamic_economy() -> void:
	FranchiseState.set_money(50000)
	GameClock.service_length = 6.0
	GameServer.order_interval_min = 0.5
	GameServer.order_interval_max = 0.8
	# 1일차: 기본가 → 주문 발생
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	var spawned_day1: int = GameServer.orders.next_oid - 1
	_check(spawned_day1 >= 1, "기본가: 주문 발생 (%d건)" % spawned_day1)
	# 다음 날 → 경제 드리프트 확인
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.PREP)
	var mult: float = CityEconomy.demand_mult(
		FranchiseState.city_econ, "city.korea.incheon")
	_check(FranchiseState.city_econ.has("city.korea.incheon"),
		"일일 드리프트: 인천 배율 기록")
	_check(mult >= CityEconomy.MULT_MIN and mult <= CityEconomy.MULT_MAX,
		"배율 범위 내 (%.3f)" % mult)
	# 2일차: 가격 20000 → 수용률 0 → 주문 없음 (§6.6 가격 민감도)
	GameServer.request_set_price.rpc_id(1, &"recipe.fried_dakgangjeong", 20000)
	await _sleep(0.2)
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	var spawned_day2: int = GameServer.orders.next_oid - 1 - spawned_day1
	_check(spawned_day2 == 0, "폭리 가격: 주문 0건 (실제 %d건)" % spawned_day2)
	_finish(_all_passed(), "")


## 경제 이벤트 (§8.1/§23.2, 솔로): 공급 충격 중 재료비 1.6배 → 하루 뒤 만료.
func _scenario_econ_events() -> void:
	FranchiseState.set_money(50000)
	GameClock.service_length = 3.0
	# 공급 충격 강제 발생 (서버 상태 직접 설정 — 솔로)
	FranchiseState.city_events = {
		"city.korea.incheon": {"event_id": "event.supply_shock", "days_left": 1},
	}
	_check(GameServer.effective_ingredient_cost() == 800,
		"공급 충격: 재료 단가 500→800")
	GameServer.request_buy_stock.rpc_id(1, 10)
	await _sleep(0.2)
	_check(FranchiseState.money == 42000,
		"충격 단가로 구매 8000원 (실제 %d)" % FranchiseState.money)
	# 하루 진행 → 이벤트 만료
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.PREP)
	_check(not FranchiseState.city_events.has("city.korea.incheon"),
		"다음 날 이벤트 만료")
	_check(GameServer.effective_ingredient_cost() == 500, "단가 정상 복귀")
	_finish(_all_passed(), "")


## 세이브 쓰기 (솔로): 냉장고에 재료 보관 → 하루 마감 → 다음 날 자동 저장.
## 이후 save_load가 별도 프로세스에서 복원을 검증한다 (§29.4).
func _scenario_save_write() -> void:
	var path: String = SaveService.save_path(1)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	SaveService.current_slot = 1
	FranchiseState.set_money(50000)
	GameClock.service_length = 3.0
	# 재료 수령 → 냉장고 보관
	GameServer.request_station_interact.rpc_id(1, &"i_1", Vector2i(1, 2))
	await _sleep(0.2)
	GameServer.request_station_interact.rpc_id(1, &"r_1", Vector2i(12, 2))
	await _sleep(0.2)
	GameServer.request_fridge_move.rpc_id(
		1, 1, GameServer.inventory_of(1).selected, 0, 0)
	GameServer.request_fridge_close.rpc_id(1)
	await _sleep(0.2)
	_check(GameServer.fridge.slots[0] != 0, "냉장고 보관")
	# 혼자 하루 진행 (§5.1 혼자 시작 가능)
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool: return GameClock.day == 2)
	await _sleep(0.3)
	_check(SaveService.has_save(1), "세이브 파일 생성 (자동 저장)")
	_finish(_all_passed(), "")


## 세이브 로드 (솔로, 새 프로세스): 저장된 날·냉장고·재고가 복원되는지.
func _scenario_save_load() -> void:
	_check(SaveService.has_save(1), "세이브 파일 존재")
	var loaded: bool = SaveService.load_game(1)
	_check(loaded, "로드 성공")
	await _sleep(0.2)
	_check(GameClock.day == 2, "2일차 복원 (실제 %d일차)" % GameClock.day)
	_check(GameClock.phase == GameClock.Phase.PREP, "준비 단계 복원")
	var fridge_iid: int = GameServer.fridge.slots[0]
	_check(fridge_iid != 0, "냉장고 슬롯 복원")
	var item: ItemInstance = GameServer.get_item(fridge_iid)
	_check(item != null and item.def_id == &"item.raw_chicken",
		"냉장고 아이템 정의 복원")
	_check(GameServer.ingredient_stock == 0, "재고 복원 (마감 폐기 후 0)")
	_check(FranchiseState.money == 48000, "자금 복원 (50000-임대료 2000)")
	var inv: InventoryState = GameServer.inventory_of(1)
	_check(inv != null and inv.is_empty(), "호스트 인벤토리 복원 (비어 있음)")
	_check(GameServer.next_iid > fridge_iid, "iid 카운터 복원 — 충돌 없음")
	_finish(_all_passed(), "")


## 직원 확장 (§10.2~10.4, 솔로): 후보 채용 → 휴가일 결근(급여는 지급) →
## 최소 근무 기간 내 해고 위약금.
func _scenario_employee_roster() -> void:
	FranchiseState.set_money(100000)
	GameClock.service_length = 3.0
	# B급 후보 주입 (min 7일, 일급 4000, 채용비 8000) — 오늘 휴가로 설정
	GameServer.job_candidates = [{
		"name": "박서준", "grade": "B", "trait": "무난함",
		"wage": 4000, "hire_cost": 8000, "min_days": 7,
		"work_interval": 1.1, "move_speed": 2.5, "vacation_per_month": 3,
	}]
	GameServer.request_hire_candidate.rpc_id(1, 0)
	await _sleep(0.2)
	_check(GameServer.employees.size() == 1, "후보 채용")
	_check(FranchiseState.money == 92000, "채용비 8000 차감 (실제 %d)"
		% FranchiseState.money)
	_check(GameServer.job_candidates.is_empty(), "채용된 후보는 목록에서 제거")
	var eid: int = GameServer.employees.keys()[0]
	var emp: EmployeeState = GameServer.employees[eid]
	_check(emp.vacation_days.size() == 3, "30일 휴가 3일 사전 확정 (§10.4)")
	# 오늘을 휴가일로 강제 → 영업 중 결근 확인
	emp.vacation_days = [GameClock.day]
	GameServer.request_buy_stock.rpc_id(1, 5)
	await _sleep(0.2)
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SERVICE)
	await _sleep(1.5)
	_check(GameServer.station_employee.is_empty(), "휴가일: 출근 안 함")
	_check(GameServer.employees[eid].carrying_iid == 0, "휴가일: 작업 없음")
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.SETTLEMENT)
	# 92000 - 재료 2500 - 급여 4000(휴가 중에도 지급 §10.4) - 임대료 2000
	_check(FranchiseState.money == 92000 - 2500 - 4000 - 2000,
		"휴가 중에도 급여 지급 (실제 %d)" % FranchiseState.money)
	# 다음 날: 1일 근무 후 해고 → 위약금 6일 × 2000 = 12000 (§10.3)
	GameServer.request_ready_toggle.rpc_id(1)
	await _wait_until(func() -> bool:
		return GameClock.phase == GameClock.Phase.PREP)
	var before_fire: int = FranchiseState.money
	GameServer.request_fire_employee.rpc_id(1, eid)
	await _sleep(0.2)
	_check(GameServer.employees.is_empty(), "해고 완료")
	_check(FranchiseState.money == before_fire - 12000,
		"위약금 12000 차감 (실제 %d)" % FranchiseState.money)
	_check(GameServer.job_candidates.size() == 3, "다음 날 후보 3명 갱신")
	_finish(_all_passed(), "")


## 테스트용 고정 스탯 후보 주입 + 즉시 채용 (기존 시나리오의 결정성 유지)
func _inject_and_hire_basic() -> void:
	GameServer.job_candidates = [{
		"name": "테스트직원", "grade": "D", "trait": "무난함",
		"wage": 3000, "hire_cost": 5000, "min_days": 0,
		"work_interval": 1.2, "move_speed": 2.5, "vacation_per_month": 0,
	}]
	GameServer.request_hire_candidate.rpc_id(1, 0)


func _held_item(peer: int) -> ItemInstance:
	var inv: InventoryState = GameServer.inventory_of(peer)
	if inv == null:
		return null
	return GameServer.get_item(inv.selected_iid())


# ── 공용 헬퍼 ────────────────────────────────────────────────────────

func _count_copies(iid: int) -> int:
	var count: int = 0
	for tile: Vector2i in GameServer.grid.floor_items.keys():
		if GameServer.grid.item_at(tile) == iid:
			count += 1
	for peer: int in GameServer.inventories.keys():
		var inv: InventoryState = GameServer.inventories[peer]
		for held: int in inv.all_iids():
			if held == iid:
				count += 1
	for st_key: StringName in GameServer.stations.keys():
		var st: StationState = GameServer.stations[st_key]
		if st.item_iid == iid:
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	_checks.append({"pass": condition, "label": label})
	print("[nettest:%s] %s — %s" % [role, "PASS" if condition else "FAIL", label])


func _teardown() -> void:
	if role == "guest":
		t_guest_done.rpc_id(1)
		await _sleep(0.3)
		_finish(_all_passed(), "")
	else:
		await _wait_until(func() -> bool: return _guest_done)
		_finish(_all_passed(), "")


func _all_passed() -> bool:
	if _checks.is_empty():
		return false
	for check: Dictionary in _checks:
		if not bool(check["pass"]):
			return false
	return true


## 렌더링 확인용 (headless 불가 — 화면 필요): 매장을 그린 뒤 뷰포트를
## `<result_path>.png`로 저장한다. 타일·스프라이트 아트 검수에 사용.
func _scenario_screenshot() -> void:
	for i in range(30):
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(result_path + ".png")
	_finish(err == OK, "" if err == OK else "저장 실패: %d" % err)


func _finish(passed: bool, error: String) -> void:
	if _finished:
		return
	_finished = true
	if result_path != "":
		var file: FileAccess = FileAccess.open(result_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({
				"role": role,
				"scenario": scenario,
				"pass": passed,
				"error": error,
				"checks": _checks,
			}, "\t"))
			file.close()
	get_tree().quit(0 if passed else 1)


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_until(predicate: Callable) -> void:
	while not bool(predicate.call()):
		await get_tree().process_frame
