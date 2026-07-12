extends Node
## 호스트 권한 게임 서버 (PLAN.md §24).
##
## 패턴: 클라이언트가 의도 RPC(request_*)를 rpc_id(1)로 보내면
## 서버가 권한 상태로 검증하고, 통과 시 _apply_* RPC를 전원에게 브로드캐스트한다.
## request_*는 상태를 읽기만 하고, 모든 변이는 _apply_*에서만 일어난다
## (call_local 덕분에 호스트도 같은 경로로 정확히 한 번 변이).
##
## 모든 게임플레이 RPC는 이 autoload에만 둔다 — 피어 간 노드 경로 동일 보장.

## 미러 갱신 신호 (뷰 레이어 구독용; 서버·클라이언트 공통)
signal item_updated(iid: int)
signal floor_item_placed(tile: Vector2i, iid: int)
signal floor_item_removed(tile: Vector2i)
signal inventory_changed(peer_id: int)
signal station_changed(key: StringName)
signal orders_changed
signal order_completed(oid: int, revenue: int)
signal ready_state_changed
signal day_settled(summary: Dictionary)
signal fridge_changed
signal fridge_lock_changed(owner_peer: int)
signal employee_changed(eid: int)
signal stores_changed
signal market_info_changed
signal snapshot_applied
signal fail_notified(msg_key: String)
## 게스트의 씬 로드 완료(client_ready) 시 서버에서 발신
signal peer_became_ready(peer_id: int)

## 의도 검증 시 허용하는 대상 타일까지의 최대 체비쇼프 거리 (지연 보정 여유)
const MAX_REACH_TILES: int = 2

# ── 권한 상태 (서버 원본, 클라이언트 미러) ──────────────────────────
var items: Dictionary = {}          ## iid → ItemInstance
var grid: GridState = GridState.new()
var stations: Dictionary = {}       ## key(StringName) → StationState
var inventories: Dictionary = {}    ## peer_id → InventoryState
var next_iid: int = 1
## 씬 로드까지 마친 피어 집합 (스폰·스냅샷은 이 이후에만)
var client_ready_peers: Dictionary = {}
var orders: OrderBook = OrderBook.new()
## 오늘 남은 재료 수량. 준비 단계에서 수동 주문(§21.1), 마감 시 잔여분 폐기.
var ingredient_stock: int = 40
## 새 게임 1일차 온보딩용 기본 재고 (이후에는 매일 주문 필요)
var daily_stock: int = 40
## 재료 단가 (원; 도시 경제로 확장 가능 — §8)
var ingredient_unit_cost: int = 500
## 준비 완료한 피어 (준비·정산 단계에서 전원 완료 시 진행 §5.1)
var ready_peers: Dictionary = {}
## 오늘 누적 매출·폐기 수 (정산 표시용)
var revenue_today: int = 0
var disposed_today: int = 0

## 매장 냉장고 (수직 슬라이스: 소형 1대)
var fridge: FridgeState = FridgeState.create(&"fridge.small", 3)

## 직원 (PLAN.md §10). eid → EmployeeState. 서버가 FSM 구동.
var employees: Dictionary = {}
var next_eid: int = 1
## 직원이 점유한 설비: station_key → eid (§10.6 — 플레이어 개입 차단)
var station_employee: Dictionary = {}

## 주문 스폰 간격 (초; 데이터 조정 가능)
var order_interval_min: float = 8.0
var order_interval_max: float = 14.0
var _next_order_in: float = 0.0

var layout: StoreLayout


func _physics_process(delta: float) -> void:
	# 튀김기 조리 tick — 서버 권한, 영업 중에만 (준비·정산은 세계 정지)
	if not is_server() or GameClock.phase != GameClock.Phase.SERVICE:
		return
	_tick_order_spawner(delta)
	for eid: int in employees.keys():
		_tick_employee(employees[eid], delta)
	for key: StringName in stations.keys():
		var st: StationState = stations[key]
		if st.item_iid == 0:
			continue
		var def: StationDef = st.get_def()
		if def.kind != StationDef.Kind.FRYER:
			continue
		var item: ItemInstance = items.get(st.item_iid)
		if item == null:
			continue
		var before: CookStateMachine.State = CookStateMachine.state_for(
			item.cook_elapsed, def)
		item.cook_elapsed += delta
		var after: CookStateMachine.State = CookStateMachine.state_for(
			item.cook_elapsed, def)
		# 상태 경계에서만 브로드캐스트 (매 프레임 동기화 금지 §33)
		if before != after:
			_apply_item_data.rpc(item.to_dict())
			_apply_station_state.rpc(key, st.item_iid, after != CookStateMachine.State.BURNT)


func is_server() -> bool:
	return multiplayer.is_server()


## rpc 발신자 피어 ID (호스트 로컬 호출이면 1)
func _sender() -> int:
	var peer: int = multiplayer.get_remote_sender_id()
	return 1 if peer == 0 else peer


func get_item(iid: int) -> ItemInstance:
	return items.get(iid)


func inventory_of(peer_id: int) -> InventoryState:
	return inventories.get(peer_id)


func station(key: StringName) -> StationState:
	return stations.get(key)


# ── 서버 측 셋업 (매장 로드 시) ─────────────────────────────────────

## 모든 피어가 동일한 레이아웃을 로컬 적용 (지형은 결정적 — 동기화 불필요)
func setup_store(p_layout: StoreLayout) -> void:
	layout = p_layout
	grid = GridState.new()
	grid.walkable = p_layout.walkable.duplicate()
	grid.blocked = p_layout.station_tiles().duplicate()
	stations.clear()
	for key: StringName in p_layout.stations.keys():
		var entry: Dictionary = p_layout.stations[key]
		stations[key] = StationState.create(key, entry["def_id"])
	var fridge_def: RefrigeratorDef = Defs.get_def(&"fridge.small") as RefrigeratorDef
	fridge = FridgeState.create(fridge_def.id, fridge_def.slot_count)


## 세이브에서 복원됐지만 아직 접속하지 않은 게스트(2번 플레이어) 인벤토리
var pending_guest_inventory: Dictionary = {}


func _employee_dicts() -> Dictionary:
	var result: Dictionary = {}
	for eid: int in employees.keys():
		var emp: EmployeeState = employees[eid]
		result[str(eid)] = emp.to_dict()
	return result


## 서버 전용: 피어 인벤토리 보장. 세이브된 게스트 인벤토리가 있으면 인계.
func server_ensure_peer(peer_id: int) -> void:
	assert(is_server())
	if not inventories.has(peer_id):
		if peer_id != 1 and not pending_guest_inventory.is_empty():
			inventories[peer_id] = InventoryState.from_dict(pending_guest_inventory)
			pending_guest_inventory = {}
		else:
			inventories[peer_id] = InventoryState.new()
	_send_snapshot_to(peer_id)


## 서버 전용: 아이템 생성 후 바닥 배치. 실패 시 0.
func server_spawn_floor_item(def_id: StringName, tile: Vector2i) -> int:
	assert(is_server())
	if not grid.can_place_item(tile):
		return 0
	var iid: int = next_iid
	next_iid += 1
	var item: ItemInstance = ItemInstance.create(iid, def_id)
	_apply_item_data.rpc(item.to_dict())
	_apply_floor_place.rpc(tile, iid)
	return iid


# ── 의도 RPC (any_peer → 서버 검증) ────────────────────────────────

## 참가 핸드셰이크: 게스트가 매장 씬 로드를 마치면 호출.
## 이전에는 서버가 해당 피어에게 스폰·스냅샷을 보내지 않는다.
@rpc("any_peer", "call_local", "reliable")
func client_ready() -> void:
	if not is_server():
		return
	var peer: int = _sender()
	client_ready_peers[peer] = true
	server_ensure_peer(peer)
	peer_became_ready.emit(peer)

@rpc("any_peer", "call_local", "reliable")
func request_pickup(tile: Vector2i, player_tile: Vector2i) -> void:
	if not is_server():
		return
	var peer: int = _sender()
	if not _in_reach(player_tile, tile):
		return
	var iid: int = grid.item_at(tile)
	if iid == 0:
		return  # 경쟁에서 짐 — 무음 무시 (§16.5)
	var inv: InventoryState = inventories.get(peer)
	if inv == null:
		return
	var slot: int = inv.pickup_slot()
	if slot == -1:
		notify_fail.rpc_id(peer, "inventory_full")
		return
	_apply_pickup.rpc(peer, tile, iid, slot)


@rpc("any_peer", "call_local", "reliable")
func request_drop(player_tile: Vector2i, facing: Vector2i) -> void:
	if not is_server():
		return
	var peer: int = _sender()
	var inv: InventoryState = inventories.get(peer)
	if inv == null:
		return
	var iid: int = inv.selected_iid()
	if iid == 0:
		return
	var spot: Vector2i = DropPlacement.find_spot(grid, player_tile, facing)
	if spot == Vector2i.MAX:
		notify_fail.rpc_id(peer, "no_drop_spot")
		return
	_apply_drop.rpc(peer, inv.selected, spot, iid)


## 선택 슬롯 변경 — 내용물은 서버 상태이므로 인덱스만 가볍게 동기화 (§24.3)
@rpc("any_peer", "call_local", "reliable")
func request_select_slot(index: int) -> void:
	if not is_server():
		return
	var peer: int = _sender()
	var inv: InventoryState = inventories.get(peer)
	if inv == null:
		return
	_apply_select_slot.rpc(peer, clampi(index, 0, inv.unlocked - 1))


## 설비 J 상호작용 (PLAN.md §15): 놓기/집기/스왑/제출/재료 지급.
@rpc("any_peer", "call_local", "reliable")
func request_station_interact(key: StringName, player_tile: Vector2i) -> void:
	if not is_server():
		return
	var peer: int = _sender()
	var st: StationState = stations.get(key)
	var inv: InventoryState = inventories.get(peer)
	if st == null or inv == null:
		return
	var entry: Dictionary = layout.stations.get(key, {})
	if not entry.is_empty() and not _in_reach(player_tile, entry["tile"]):
		return
	# 직원이 작업 중인 설비에는 개입 불가 (§10.6)
	if station_employee.has(key):
		notify_fail.rpc_id(peer, "employee_working")
		return
	var def: StationDef = st.get_def()
	match def.kind:
		StationDef.Kind.INGREDIENT_BOX:
			_handle_dispense(peer, inv, def)
		StationDef.Kind.SUBMIT:
			_handle_submit(peer, inv)
		StationDef.Kind.FRIDGE:
			# 단독 사용 잠금 (§17.5): 먼저 연 플레이어만
			if fridge.try_lock(peer):
				_apply_fridge_lock.rpc(peer)
			else:
				notify_fail.rpc_id(peer, "fridge_in_use")
		_:
			_handle_place_take_swap(peer, inv, st, def)


## 설비 K 작업 (PLAN.md §13.3, §19): 칼질·튀김옷.
@rpc("any_peer", "call_local", "reliable")
func request_station_work(key: StringName, player_tile: Vector2i) -> void:
	if not is_server():
		return
	var peer: int = _sender()
	var st: StationState = stations.get(key)
	if st == null or st.item_iid == 0:
		return
	var entry: Dictionary = layout.stations.get(key, {})
	if not entry.is_empty() and not _in_reach(player_tile, entry["tile"]):
		return
	# 직원 작업에는 플레이어가 합류할 수 없다 (§10.6, §19.3)
	if station_employee.has(key):
		notify_fail.rpc_id(peer, "employee_working")
		return
	var def: StationDef = st.get_def()
	var item: ItemInstance = items.get(st.item_iid)
	if item == null:
		return
	match def.kind:
		StationDef.Kind.CUTTING_BOARD:
			if not def.work_output.has(item.def_id):
				return  # 이미 손질 완료된 아이템
			item.cuts_done += 1
			if item.cuts_done >= def.required_cuts:
				item.def_id = StringName(String(def.work_output[item.def_id]))
			_apply_item_data.rpc(item.to_dict())
			_apply_station_state.rpc(key, st.item_iid, false)
		StationDef.Kind.BREADING_TABLE:
			if not def.work_output.has(item.def_id):
				return
			item.def_id = StringName(String(def.work_output[item.def_id]))
			_apply_item_data.rpc(item.to_dict())
			_apply_station_state.rpc(key, st.item_iid, false)
		_:
			pass  # 튀김기는 시간 조리 — K 작업 없음 (닭강정 레시피)


# ── 설비 처리 헬퍼 (서버 전용) ──────────────────────────────────────

func _handle_dispense(peer: int, inv: InventoryState, def: StationDef) -> void:
	if def.dispenses_item_id == StringName():
		return
	if ingredient_stock <= 0:
		notify_fail.rpc_id(peer, "out_of_stock")
		return
	var slot: int = inv.pickup_slot()
	if slot == -1:
		notify_fail.rpc_id(peer, "inventory_full")
		return
	var iid: int = next_iid
	next_iid += 1
	var item: ItemInstance = ItemInstance.create(iid, def.dispenses_item_id)
	_apply_item_data.rpc(item.to_dict())
	_apply_give.rpc(peer, slot, iid, ingredient_stock - 1)


func _handle_submit(peer: int, inv: InventoryState) -> void:
	var iid: int = inv.selected_iid()
	if iid == 0:
		return
	var item: ItemInstance = items.get(iid)
	if item == null:
		return
	if not item.get_def().submittable:
		notify_fail.rpc_id(peer, "not_submittable")
		return
	var recipe: RecipeDef = _recipe_for_output(item.def_id)
	if recipe == null:
		notify_fail.rpc_id(peer, "no_matching_order")
		return
	# 매칭 확인만 하고 실제 제거는 _apply_submit에서 (call_local 이중 적용 방지)
	if orders.count_for(recipe.id) == 0:
		notify_fail.rpc_id(peer, "no_matching_order")
		return
	var price: int = FranchiseState.price_of(recipe)  # 설정 가격 반영 (§8)
	_apply_submit.rpc(peer, inv.selected, iid, String(recipe.id),
		price, FranchiseState.money + price)


func _handle_place_take_swap(peer: int, inv: InventoryState,
		st: StationState, def: StationDef) -> void:
	var held_iid: int = inv.selected_iid()
	var station_iid: int = st.item_iid

	if station_iid == 0 and held_iid != 0:
		# 놓기 — 설비 허용 조건 검사 (§15.2)
		var held: ItemInstance = items.get(held_iid)
		if held == null:
			return
		if not def.accepts_item(held.def_id):
			notify_fail.rpc_id(peer, "station_rejects_item")
			return
		_apply_place.rpc(peer, inv.selected, st.key, held_iid,
			def.kind == StationDef.Kind.FRYER)
	elif station_iid != 0 and held_iid == 0:
		# 집기 — 튀김기는 꺼낼 때 상태에 따라 변환 (§19.5)
		var item: ItemInstance = items.get(station_iid)
		if item == null:
			return
		if def.kind == StationDef.Kind.FRYER:
			var result: StringName = CookStateMachine.resolve_takeout(item, def)
			if result != item.def_id:
				item.def_id = result
				item.cook_elapsed = 0.0
				item.cuts_done = 0
			_apply_item_data.rpc(item.to_dict())
		_apply_take.rpc(peer, inv.selected, st.key, station_iid)
	elif station_iid != 0 and held_iid != 0:
		_handle_swap(peer, inv, st, def, held_iid, station_iid)
	# 둘 다 비어 있음 → 아무 동작 없음 (§15.1)


func _handle_swap(peer: int, inv: InventoryState, st: StationState,
		def: StationDef, held_iid: int, station_iid: int) -> void:
	var held: ItemInstance = items.get(held_iid)
	var station_item: ItemInstance = items.get(station_iid)
	if held == null or station_item == null:
		return
	# 작업 진행 중 스왑 금지 (§15.2)
	if _work_in_progress(st, def, station_item):
		notify_fail.rpc_id(peer, "station_busy")
		return
	# 새로 들어갈 아이템이 허용 조건을 통과해야 — 실패 시 전체 취소 (§15.2)
	if not def.accepts_item(held.def_id):
		notify_fail.rpc_id(peer, "station_rejects_item")
		return
	if def.kind == StationDef.Kind.FRYER:
		var result: StringName = CookStateMachine.resolve_takeout(station_item, def)
		if result != station_item.def_id:
			station_item.def_id = result
			station_item.cook_elapsed = 0.0
			station_item.cuts_done = 0
		_apply_item_data.rpc(station_item.to_dict())
	_apply_swap.rpc(peer, inv.selected, st.key, held_iid, station_iid,
		def.kind == StationDef.Kind.FRYER)


## 작업 진행 중 판정: 도마는 손질 미완, 튀김기는 덜 익음 단계.
func _work_in_progress(_st: StationState, def: StationDef,
		item: ItemInstance) -> bool:
	match def.kind:
		StationDef.Kind.CUTTING_BOARD:
			return def.work_output.has(item.def_id) and item.cuts_done > 0
		StationDef.Kind.FRYER:
			return CookStateMachine.state_for(item.cook_elapsed, def) \
				== CookStateMachine.State.UNDERDONE and item.cook_elapsed > 0.0
		_:
			return false


func _recipe_for_output(item_def_id: StringName) -> RecipeDef:
	for id: StringName in Defs.all_ids():
		var def: Resource = Defs.get_def(id)
		if def is RecipeDef and (def as RecipeDef).output_item_id == item_def_id:
			return def as RecipeDef
	return null


## 서버 전용: 주문 생성 (P4 스포너·테스트에서 사용)
func server_spawn_order(recipe_id: StringName) -> Dictionary:
	assert(is_server())
	var order: Dictionary = orders.spawn(recipe_id, GameClock.service_elapsed)
	if not order.is_empty():
		_apply_order_spawned.rpc(order)
	return order


func _tick_order_spawner(delta: float) -> void:
	_next_order_in -= delta
	if _next_order_in > 0.0:
		return
	# 동적 경제 (§8.1): 유효 수요가 높을수록 주문이 잦다
	var city: CityDef = Defs.get_def(StringName(FranchiseState.active_city)) as CityDef
	var mult: float = CityEconomy.demand_mult(
		FranchiseState.city_econ, FranchiseState.active_city)
	var event_factor: float = CityEconomy.event_demand_factor(
		FranchiseState.city_events, FranchiseState.active_city)
	var eff: float = maxf(0.3, CityEconomy.effective_demand(city, mult, event_factor))
	_next_order_in = randf_range(order_interval_min, order_interval_max) / eff
	if orders.active.size() >= orders.max_active:
		return
	# 가격 민감도 (§6.6): 인상분만큼 손님이 발길을 돌린다
	var recipe: RecipeDef = Defs.get_def(&"recipe.fried_dakgangjeong") as RecipeDef
	var accept: float = CityEconomy.acceptance(
		FranchiseState.price_of(recipe), recipe.base_price, city.price_sensitivity)
	if market_rng.randf() >= accept:
		return
	server_spawn_order(recipe.id)


# ── 도시·다매장 (PLAN.md §6) ────────────────────────────────────────
## 단순화(문서화): 모든 매장이 인천 레이아웃 템플릿을 공유하고,
## 두 플레이어는 준비 단계에 함께 이동한다. 독립 이동·도시별 레이아웃은 이후 단계.
## 오프라인 매장의 잔여 재고는 마감 폐기 대상에서 제외 (추상화).

## 자동화 매장 통계 매출: 직원 1명 × 수요 1.0당 하루 매출 (§5.2, 데이터 조정 가능)
const OFFLINE_REVENUE_PER_STAFF: int = 800


## 개설된 모든 도시 ID (활성 매장 포함)
func opened_city_ids() -> Array[String]:
	var result: Array[String] = []
	for city_id: String in FranchiseState.stores.keys():
		result.append(city_id)
	if not result.has(FranchiseState.active_city):
		result.append(FranchiseState.active_city)
	return result


## 매장 개설 (§6.5: 도시당 1개, 준비 단계)
@rpc("any_peer", "call_local", "reliable")
func request_open_store(city_id: String) -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	var peer: int = _sender()
	if not Defs.has_def(StringName(city_id)):
		return
	if FranchiseState.is_store_open(city_id):
		return
	var city: CityDef = Defs.get_def(StringName(city_id)) as CityDef
	if FranchiseState.money < city.entry_cost:
		notify_fail.rpc_id(peer, "not_enough_money")
		return
	_apply_open_store.rpc(city_id, FranchiseState.money - city.entry_cost)


@rpc("authority", "call_local", "reliable")
func _apply_open_store(city_id: String, new_money: int) -> void:
	FranchiseState.stores[city_id] = {}  # 빈 번들 = 신규 매장
	FranchiseState.set_money(new_money)
	stores_changed.emit()


## 매장 이동 (준비 단계): 현재 매장 상태를 번들로 보관하고 대상 매장을 로드.
@rpc("any_peer", "call_local", "reliable")
func request_switch_store(city_id: String) -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	if city_id == FranchiseState.active_city:
		return
	if not FranchiseState.is_store_open(city_id):
		return
	# 현재 매장 → 번들 보관, 매장 귀속 아이템은 레지스트리에서 분리
	var old_bundle: Dictionary = _build_store_bundle()
	FranchiseState.stores[FranchiseState.active_city] = old_bundle
	for key: String in (old_bundle.get("items", {}) as Dictionary).keys():
		items.erase(int(key))
	# 대상 매장 로드 (없으면 새 템플릿)
	var bundle: Dictionary = FranchiseState.stores.get(city_id, {})
	FranchiseState.active_city = city_id
	FranchiseState.stores.erase(city_id)  # 활성 매장은 라이브 상태가 원본
	_load_store_bundle(bundle)
	# 전원 동기화 — 세이브와 동일 직렬화기 재사용
	_apply_snapshot.rpc(build_snapshot())
	stores_changed.emit()


## 매장 귀속 상태(바닥·설비·냉장고·직원과 그 아이템들)를 번들로 직렬화.
## 플레이어 인벤토리는 포함하지 않는다 — 아이템은 플레이어와 함께 이동한다.
func _build_store_bundle() -> Dictionary:
	var store_iids: Dictionary = {}
	for tile: Vector2i in grid.floor_items.keys():
		store_iids[grid.item_at(tile)] = true
	for key: StringName in stations.keys():
		var st: StationState = stations[key]
		if st.item_iid != 0:
			store_iids[st.item_iid] = true
	for iid: int in fridge.slots:
		if iid != 0:
			store_iids[iid] = true
	for eid: int in employees.keys():
		var emp: EmployeeState = employees[eid]
		if emp.carrying_iid != 0:
			store_iids[emp.carrying_iid] = true
	var item_dicts: Dictionary = {}
	for iid: int in store_iids.keys():
		var item: ItemInstance = items.get(iid)
		if item != null:
			item_dicts[str(iid)] = item.to_dict()
	var station_dicts: Dictionary = {}
	for key: StringName in stations.keys():
		var st: StationState = stations[key]
		station_dicts[String(key)] = st.to_dict()
	return {
		"items": item_dicts,
		"grid": grid.to_dict(),
		"stations": station_dicts,
		"fridge": fridge.to_dict(),
		"employees": _employee_dicts(),
		"stock": ingredient_stock,
	}


## 번들을 활성 매장 라이브 상태로 로드 (빈 번들 = 새 매장 템플릿)
func _load_store_bundle(bundle: Dictionary) -> void:
	# 지형·설비를 템플릿에서 재구축 (모든 매장 동일 레이아웃)
	var inv_backup: Dictionary = inventories
	setup_store(layout)
	inventories = inv_backup
	var item_dicts: Dictionary = bundle.get("items", {})
	for key: String in item_dicts.keys():
		var item: ItemInstance = ItemInstance.from_dict(item_dicts[key])
		items[item.iid] = item
	grid.load_items(bundle.get("grid", {}))
	var station_dicts: Dictionary = bundle.get("stations", {})
	for key: String in station_dicts.keys():
		var st: StationState = StationState.from_dict(station_dicts[key])
		if stations.has(st.key):
			stations[st.key] = st
	if bundle.has("fridge"):
		fridge = FridgeState.from_dict(bundle["fridge"])
	employees.clear()
	station_employee.clear()
	var emp_dicts: Dictionary = bundle.get("employees", {})
	for key: String in emp_dicts.keys():
		var emp: EmployeeState = EmployeeState.from_dict(emp_dicts[key])
		employees[emp.eid] = emp
	ingredient_stock = int(bundle.get("stock", 0))


func _bundle_staff_count(bundle: Dictionary) -> int:
	return (bundle.get("employees", {}) as Dictionary).size()


func _bundle_wages(bundle: Dictionary) -> int:
	var total: int = 0
	var emp_dicts: Dictionary = bundle.get("employees", {})
	for key: String in emp_dicts.keys():
		total += int((emp_dicts[key] as Dictionary).get("wage", 0))
	return total


# ── 시장 정보 (PLAN.md §7) ──────────────────────────────────────────

## 사기 판정용 서버 RNG (테스트에서 시드 고정 가능)
var market_rng: RandomNumberGenerator = RandomNumberGenerator.new()


## 시장 정보 구매 (준비 단계). 사기 시 전액 손실·정보 미획득·기존 정보 유지 (§7.3).
@rpc("any_peer", "call_local", "reliable")
func request_buy_market_info(city_id: String, source_id: String) -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	var peer: int = _sender()
	if not Defs.has_def(StringName(city_id)) or not Defs.has_def(StringName(source_id)):
		return
	var city: CityDef = Defs.get_def(StringName(city_id)) as CityDef
	var source: MarketSourceDef = Defs.get_def(StringName(source_id)) as MarketSourceDef
	var current: Dictionary = FranchiseState.market_info.get(city_id, {})
	var price: int = MarketReport.price_for(source, current)
	if FranchiseState.money < price:
		notify_fail.rpc_id(peer, "not_enough_money")
		return
	if market_rng.randf() < source.scam_chance:
		# 사기: 지불액 전액 손실, 환불·추적 없음 (§7.3)
		_apply_market_scam.rpc(FranchiseState.money - price)
		notify_fail.rpc_id(peer, "market_scammed")
		return
	# 보고서에는 현재 변동 배율이 반영된다 — 오래된 정보는 현실과 어긋남 (§7.5)
	var report: Dictionary = MarketReport.make_report(
		city, source, market_rng, GameClock.day, current, price,
		CityEconomy.demand_mult(FranchiseState.city_econ, city_id))
	_apply_market_info.rpc(city_id, report, FranchiseState.money - price)


@rpc("authority", "call_local", "reliable")
func _apply_market_scam(new_money: int) -> void:
	FranchiseState.set_money(new_money)
	market_info_changed.emit()


@rpc("authority", "call_local", "reliable")
func _apply_market_info(city_id: String, report: Dictionary, new_money: int) -> void:
	FranchiseState.market_info[city_id] = report
	FranchiseState.set_money(new_money)
	market_info_changed.emit()


# ── 경영: 재료 주문·가격·대출 (PLAN.md §8, §9, §21) ─────────────────

## 현재 매장의 유효 재료 단가 — 공급 충격 이벤트 반영 (§8.1)
func effective_ingredient_cost() -> int:
	return int(ingredient_unit_cost * CityEconomy.event_cost_factor(
		FranchiseState.city_events, FranchiseState.active_city))


## 준비 단계 재료 주문 — 즉시 구매, 마감 시 잔여분 폐기 (§21.1)
@rpc("any_peer", "call_local", "reliable")
func request_buy_stock(qty: int) -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	var peer: int = _sender()
	qty = clampi(qty, 1, 99)
	var cost: int = qty * effective_ingredient_cost()
	if FranchiseState.money < cost:
		notify_fail.rpc_id(peer, "not_enough_money")
		return
	_apply_economy.rpc({
		"stock": ingredient_stock + qty,
		"money": FranchiseState.money - cost,
	})


## 메뉴 가격 설정 (준비 단계, §5.1)
@rpc("any_peer", "call_local", "reliable")
func request_set_price(recipe_id: StringName, price: int) -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	if not Defs.has_def(recipe_id):
		return
	_apply_economy.rpc({
		"price_recipe": String(recipe_id),
		"price_value": clampi(price, 500, 20000),
	})


## 대출 (§9 축소판: 1건, 원금 50000, 일일 이자 2% 자동 납부, 전액 중도 상환)
const LOAN_AMOUNT: int = 50000

@rpc("any_peer", "call_local", "reliable")
func request_take_loan() -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	var peer: int = _sender()
	if FranchiseState.loan_principal > 0:
		notify_fail.rpc_id(peer, "loan_active")
		return
	_apply_economy.rpc({
		"money": FranchiseState.money + LOAN_AMOUNT,
		"loan": LOAN_AMOUNT,
	})


@rpc("any_peer", "call_local", "reliable")
func request_repay_loan() -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	var peer: int = _sender()
	var principal: int = FranchiseState.loan_principal
	if principal <= 0:
		return
	if FranchiseState.money < principal:
		notify_fail.rpc_id(peer, "not_enough_money")
		return
	_apply_economy.rpc({
		"money": FranchiseState.money - principal,
		"loan": 0,
	})


## 경영 상태 일괄 반영 (재고/자금/가격/대출 — 존재하는 키만 적용)
@rpc("authority", "call_local", "reliable")
func _apply_economy(data: Dictionary) -> void:
	if data.has("stock"):
		ingredient_stock = int(data["stock"])
	if data.has("price_recipe"):
		FranchiseState.menu_prices[String(data["price_recipe"])] = \
			int(data["price_value"])
	if data.has("loan"):
		FranchiseState.loan_principal = int(data["loan"])
	if data.has("money"):
		FranchiseState.set_money(int(data["money"]))
	ready_state_changed.emit()  # 준비 패널 리프레시 겸용


# ── 직원 (PLAN.md §10) ──────────────────────────────────────────────

## 전처리 직원 작업 경로: 재료 보관함 → 전용 도마(d_2) → 출력 작업대(c_4)
const EMP_BOARD_KEY: StringName = &"d_2"
const EMP_OUTPUT_KEY: StringName = &"c_4"
const EMP_BOX_KEY: StringName = &"i_1"
const EMP_SPAWN_TILE: Vector2i = Vector2i(2, 2)

## 오늘의 채용 후보 (매일 갱신, §10.2 무작위 고정 스탯)
var job_candidates: Array[Dictionary] = []
const CANDIDATES_PER_DAY: int = 3


## 서버 전용: 채용 후보 갱신·브로드캐스트
func server_refresh_candidates() -> void:
	assert(is_server())
	_apply_candidates.rpc(EmployeeRoster.generate_candidates(
		CANDIDATES_PER_DAY, market_rng))


## 후보 채용 (준비 단계, §5.1). 스탯은 후보 생성 시점에 이미 고정 (§10.2).
@rpc("any_peer", "call_local", "reliable")
func request_hire_candidate(index: int) -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	var peer: int = _sender()
	if index < 0 or index >= job_candidates.size():
		return
	if not employees.is_empty():
		return  # 슬라이스: 매장당 직원 1명 상한
	var candidate: Dictionary = job_candidates[index]
	var cost: int = int(candidate.get("hire_cost", 0))
	if FranchiseState.money < cost:
		notify_fail.rpc_id(peer, "not_enough_money")
		return
	var emp: EmployeeState = EmployeeState.create(
		next_eid, &"employee.prep.basic", EMP_SPAWN_TILE)
	next_eid += 1
	emp.apply_candidate(candidate, GameClock.day)
	# 향후 30일 휴가 확정 (§10.4 — 준비 단계에서 사전 확인 가능)
	emp.vacation_days = EmployeeRoster.roll_vacations(
		GameClock.day + 1, emp.vacation_per_month, market_rng)
	emp.vacation_rolled_until = GameClock.day + EmployeeRoster.VACATION_WINDOW_DAYS
	var remaining: Array[Dictionary] = job_candidates.duplicate()
	remaining.remove_at(index)
	_apply_candidates.rpc(remaining)
	_apply_employee_state.rpc(emp.to_dict(), FranchiseState.money - cost)


## 해고 (준비 단계). 최소 근무 기간 내에는 위약금 지불 필수 (§10.3).
@rpc("any_peer", "call_local", "reliable")
func request_fire_employee(eid: int) -> void:
	if not is_server() or GameClock.phase != GameClock.Phase.PREP:
		return
	var peer: int = _sender()
	var emp: EmployeeState = employees.get(eid)
	if emp == null:
		return
	var penalty: int = EmployeeRoster.fire_penalty(
		emp.hired_day, emp.min_days, emp.wage, GameClock.day)
	if FranchiseState.money < penalty:
		notify_fail.rpc_id(peer, "not_enough_money")
		return
	_apply_fire.rpc(eid, FranchiseState.money - penalty)


@rpc("authority", "call_local", "reliable")
func _apply_candidates(candidates: Array) -> void:
	job_candidates.clear()
	for entry: Variant in candidates:
		if entry is Dictionary:
			job_candidates.append(entry as Dictionary)
	ready_state_changed.emit()  # 준비 패널 리프레시


@rpc("authority", "call_local", "reliable")
func _apply_fire(eid: int, new_money: int) -> void:
	var emp: EmployeeState = employees.get(eid)
	if emp != null and emp.carrying_iid != 0:
		items.erase(emp.carrying_iid)
	if int(station_employee.get(EMP_BOARD_KEY, 0)) == eid:
		station_employee.erase(EMP_BOARD_KEY)
	employees.erase(eid)
	FranchiseState.set_money(new_money)
	employee_changed.emit(eid)


func _work_tile_of(station_key: StringName) -> Vector2i:
	var entry: Dictionary = layout.stations.get(station_key, {})
	if entry.is_empty():
		return EMP_SPAWN_TILE
	return (entry["tile"] as Vector2i) + Vector2i(0, 1)


func _employee_go(emp: EmployeeState, phase: EmployeeState.Phase,
		target: Vector2i) -> void:
	emp.tile_from = emp.tile_to
	emp.tile_to = target
	var dist: float = Vector2(target - emp.tile_from).length()
	emp.move_duration = dist / maxf(0.5, emp.move_speed)
	emp.timer = emp.move_duration
	emp.phase = phase
	_apply_employee_state.rpc(emp.to_dict(), FranchiseState.money)


func _tick_employee(emp: EmployeeState, delta: float) -> void:
	emp.timer -= delta
	match emp.phase:
		EmployeeState.Phase.IDLE:
			# 휴가일에는 출근하지 않는다 — 급여는 정산에서 계속 지급 (§10.4)
			if emp.is_on_vacation(GameClock.day):
				return
			var board: StationState = stations.get(EMP_BOARD_KEY)
			if board != null and board.is_empty() \
					and not station_employee.has(EMP_BOARD_KEY) \
					and ingredient_stock > 0 and emp.carrying_iid == 0:
				# 도마를 즉시 예약 — 이동 중에도 플레이어 개입 차단 (§10.6)
				station_employee[EMP_BOARD_KEY] = emp.eid
				_employee_go(emp, EmployeeState.Phase.TO_BOX,
					_work_tile_of(EMP_BOX_KEY))
		EmployeeState.Phase.TO_BOX:
			if emp.timer > 0.0:
				return
			if ingredient_stock <= 0:
				station_employee.erase(EMP_BOARD_KEY)
				emp.phase = EmployeeState.Phase.IDLE
				_apply_employee_state.rpc(emp.to_dict(), FranchiseState.money)
				return
			var iid: int = next_iid
			next_iid += 1
			var box: StationDef = Defs.get_def(&"station.ingredient_box") as StationDef
			var item: ItemInstance = ItemInstance.create(iid, box.dispenses_item_id)
			items[item.iid] = item
			ingredient_stock -= 1
			_apply_item_data.rpc(item.to_dict())
			_apply_stock.rpc(ingredient_stock)
			emp.carrying_iid = iid
			_employee_go(emp, EmployeeState.Phase.TO_BOARD,
				_work_tile_of(EMP_BOARD_KEY))
		EmployeeState.Phase.TO_BOARD:
			if emp.timer > 0.0:
				return
			var board: StationState = stations.get(EMP_BOARD_KEY)
			board.item_iid = emp.carrying_iid
			board.work_in_progress = true
			emp.carrying_iid = 0
			emp.phase = EmployeeState.Phase.CUTTING
			emp.timer = emp.work_interval
			_apply_station_state.rpc(EMP_BOARD_KEY, board.item_iid, true)
			_apply_employee_state.rpc(emp.to_dict(), FranchiseState.money)
		EmployeeState.Phase.CUTTING:
			if emp.timer > 0.0:
				return
			emp.timer = emp.work_interval
			var board: StationState = stations.get(EMP_BOARD_KEY)
			var board_def: StationDef = board.get_def()
			var item: ItemInstance = items.get(board.item_iid)
			if item == null or not board_def.work_output.has(item.def_id):
				# 비정상 상태 — 정리 후 복귀
				station_employee.erase(EMP_BOARD_KEY)
				emp.phase = EmployeeState.Phase.IDLE
				_apply_employee_state.rpc(emp.to_dict(), FranchiseState.money)
				return
			item.cuts_done += 1
			if item.cuts_done >= board_def.required_cuts:
				item.def_id = StringName(String(board_def.work_output[item.def_id]))
				emp.carrying_iid = item.iid
				board.item_iid = 0
				board.work_in_progress = false
				station_employee.erase(EMP_BOARD_KEY)
				_apply_item_data.rpc(item.to_dict())
				_apply_station_state.rpc(EMP_BOARD_KEY, 0, false)
				_employee_go(emp, EmployeeState.Phase.TO_OUTPUT,
					_work_tile_of(EMP_OUTPUT_KEY))
			else:
				_apply_item_data.rpc(item.to_dict())
				_apply_station_state.rpc(EMP_BOARD_KEY, board.item_iid, true)
		EmployeeState.Phase.TO_OUTPUT, EmployeeState.Phase.WAIT_OUTPUT:
			if emp.timer > 0.0:
				return
			var out: StationState = stations.get(EMP_OUTPUT_KEY)
			if out != null and out.is_empty() \
					and not station_employee.has(EMP_OUTPUT_KEY):
				out.item_iid = emp.carrying_iid
				emp.carrying_iid = 0
				emp.phase = EmployeeState.Phase.IDLE
				_apply_station_state.rpc(EMP_OUTPUT_KEY, out.item_iid, false)
				_apply_employee_state.rpc(emp.to_dict(), FranchiseState.money)
			else:
				emp.phase = EmployeeState.Phase.WAIT_OUTPUT
				emp.timer = 0.5


# ── 냉장고 (PLAN.md §17) ────────────────────────────────────────────

## 냉장고 UI 종료 — 소유자만 해제 가능. 연결 종료 시 on_peer_left가 처리.
@rpc("any_peer", "call_local", "reliable")
func request_fridge_close() -> void:
	if not is_server():
		return
	var peer: int = _sender()
	if fridge.lock_owner == peer:
		_apply_fridge_lock.rpc(0)


## 슬롯 이동/교환 (§17.6). zone: 0=냉장고, 1=인벤토리.
## 커밋된 이동만 서버에 반영 — 커서 들기는 클라이언트 로컬이므로
## UI 종료 롤백(§17.7)이 자동으로 복제 안전하다.
@rpc("any_peer", "call_local", "reliable")
func request_fridge_move(from_zone: int, from_slot: int,
		to_zone: int, to_slot: int) -> void:
	if not is_server():
		return
	var peer: int = _sender()
	if fridge.lock_owner != peer:
		return
	var inv: InventoryState = inventories.get(peer)
	if inv == null:
		return
	if not _fridge_slot_valid(from_zone, from_slot, inv) \
			or not _fridge_slot_valid(to_zone, to_slot, inv):
		return
	var from_iid: int = _fridge_zone_get(from_zone, from_slot, inv)
	var to_iid: int = _fridge_zone_get(to_zone, to_slot, inv)
	if from_iid == 0:
		return
	# 교환 결과 냉장고에 들어갈 아이템은 보관 조건 검사 (§17.6)
	if to_zone == 0 and from_zone != 0:
		var entering: ItemInstance = items.get(from_iid)
		if entering == null or not FridgeState.can_store(entering):
			notify_fail.rpc_id(peer, "not_storable")
			return
	if from_zone == 0 and to_zone != 0 and to_iid != 0:
		# 교환으로 냉장고에 들어가는 반대편 아이템도 검사
		var entering_back: ItemInstance = items.get(to_iid)
		if entering_back == null or not FridgeState.can_store(entering_back):
			notify_fail.rpc_id(peer, "not_storable")
			return
	_apply_fridge_move.rpc(peer, from_zone, from_slot, to_zone, to_slot)


func _fridge_slot_valid(zone: int, slot: int, inv: InventoryState) -> bool:
	if zone == 0:
		return slot >= 0 and slot < fridge.slots.size()
	return slot >= 0 and slot < inv.unlocked


func _fridge_zone_get(zone: int, slot: int, inv: InventoryState) -> int:
	return fridge.slots[slot] if zone == 0 else inv.slots[slot]


# ── 하루 루프 (PLAN.md §5) ──────────────────────────────────────────

## R 키: 준비 단계에서는 영업 시작 준비, 정산 단계에서는 다음 날 진행.
## 접속 중인 전원이 완료해야 진행 (혼자면 즉시 §5.1).
@rpc("any_peer", "call_local", "reliable")
func request_ready_toggle() -> void:
	if not is_server():
		return
	if GameClock.phase == GameClock.Phase.SERVICE:
		return
	var peer: int = _sender()
	var now_ready: bool = not ready_peers.has(peer)
	_apply_ready_state.rpc(peer, now_ready)
	if _all_ready():
		if GameClock.phase == GameClock.Phase.PREP:
			_start_service()
		else:
			_advance_to_next_day()


func _all_ready() -> bool:
	var connected: Array[int] = [1]
	for peer: int in multiplayer.get_peers():
		if client_ready_peers.has(peer):
			connected.append(peer)
	for peer: int in connected:
		if not ready_peers.has(peer):
			return false
	return true


func _start_service() -> void:
	assert(is_server())
	SaveService.autosave()  # 영업 시작 전 (§25)
	_next_order_in = randf_range(2.0, 5.0)
	_apply_service_start.rpc()
	GameClock.set_phase(GameClock.Phase.SERVICE)


## GameClock이 영업 시간 종료 시 호출 (서버 전용): 마감 폐기 + 정산 (§18).
func on_service_time_over() -> void:
	assert(is_server())
	var disposed: int = _count_disposable()
	var wages: int = 0
	for eid: int in employees.keys():
		var emp: EmployeeState = employees[eid]
		wages += emp.wage
	var interest: int = FranchiseState.daily_interest()  # 일일 이자 자동 납부 (§9)
	# 오프라인 매장: 자동화 통계 매출 + 직원 급여 (§5.2)
	var offline_revenue: int = 0
	for city_id: String in FranchiseState.stores.keys():
		var bundle: Dictionary = FranchiseState.stores[city_id]
		var city: CityDef = Defs.get_def(StringName(city_id)) as CityDef
		var eff: float = CityEconomy.effective_demand(city,
			CityEconomy.demand_mult(FranchiseState.city_econ, city_id),
			CityEconomy.event_demand_factor(FranchiseState.city_events, city_id))
		offline_revenue += int(_bundle_staff_count(bundle) * eff
			* OFFLINE_REVENUE_PER_STAFF)
		wages += _bundle_wages(bundle)
	# 전 매장 임대료 (§6.6)
	var rent: int = 0
	for city_id: String in opened_city_ids():
		rent += (Defs.get_def(StringName(city_id)) as CityDef).rent_per_day
	GameClock.set_phase(GameClock.Phase.SETTLEMENT)
	_apply_settlement.rpc({
		"disposed": disposed,
		"stock_wasted": ingredient_stock,
		"revenue": revenue_today,
		"offline_revenue": offline_revenue,
		"wages": wages,
		"interest": interest,
		"rent": rent,
		"new_money": FranchiseState.money + offline_revenue - wages - interest - rent,
		"day": GameClock.day,
	})
	SaveService.autosave()  # 마감 정산 후 (§25)


## 마감 폐기 대상 수량: 바닥 + 설비 + 인벤토리 (냉장고 제외 §18)
func _count_disposable() -> int:
	var count: int = grid.floor_items.size()
	for key: StringName in stations.keys():
		var st: StationState = stations[key]
		if st.item_iid != 0:
			count += 1
	for peer: int in inventories.keys():
		var inv: InventoryState = inventories[peer]
		count += inv.all_iids().size()
	for eid: int in employees.keys():
		var emp: EmployeeState = employees[eid]
		if emp.carrying_iid != 0:
			count += 1
	return count


func _advance_to_next_day() -> void:
	assert(is_server())
	# 도시 경제 일일 드리프트 (§8.1)
	var city_ids: Array[String] = []
	for id: StringName in Defs.all_ids():
		if Defs.get_def(id) is CityDef:
			city_ids.append(String(id))
	var econ: Dictionary = CityEconomy.drifted(
		FranchiseState.city_econ, city_ids, market_rng)
	# 급격 경제 이벤트 진행·발생 (§8.1)
	var events: Dictionary = CityEconomy.tick_events(
		FranchiseState.city_events, city_ids, market_rng)
	# 무료 재고 보충 없음 — 준비 단계에서 주문해야 한다 (§21.1)
	_apply_new_day.rpc(0, econ, events)
	GameClock.advance_day()
	# 채용 후보 매일 갱신 + 직원 휴가 창 연장 (§10.2/§10.4)
	server_refresh_candidates()
	for eid: int in employees.keys():
		var emp: EmployeeState = employees[eid]
		if GameClock.day + int(EmployeeRoster.VACATION_WINDOW_DAYS / 2.0) \
				> emp.vacation_rolled_until:
			emp.vacation_days = EmployeeRoster.roll_vacations(
				GameClock.day + 1, emp.vacation_per_month, market_rng)
			emp.vacation_rolled_until = GameClock.day \
				+ EmployeeRoster.VACATION_WINDOW_DAYS
			_apply_employee_state.rpc(emp.to_dict(), FranchiseState.money)
	SaveService.autosave()  # 준비 단계 진입 (§25)


# ── 브로드캐스트 RPC (서버 → 전원; 유일한 변이 지점) ────────────────

@rpc("authority", "call_local", "reliable")
func _apply_item_data(data: Dictionary) -> void:
	var item: ItemInstance = ItemInstance.from_dict(data)
	items[item.iid] = item
	if not is_server():
		next_iid = maxi(next_iid, item.iid + 1)
	item_updated.emit(item.iid)


@rpc("authority", "call_local", "reliable")
func _apply_floor_place(tile: Vector2i, iid: int) -> void:
	grid.floor_items[tile] = iid
	floor_item_placed.emit(tile, iid)


@rpc("authority", "call_local", "reliable")
func _apply_pickup(peer: int, tile: Vector2i, iid: int, slot: int) -> void:
	grid.floor_items.erase(tile)
	var inv: InventoryState = inventories.get(peer)
	if inv == null:
		inv = InventoryState.new()
		inventories[peer] = inv
	inv.slots[slot] = iid
	floor_item_removed.emit(tile)
	inventory_changed.emit(peer)


@rpc("authority", "call_local", "reliable")
func _apply_drop(peer: int, slot: int, tile: Vector2i, iid: int) -> void:
	var inv: InventoryState = inventories.get(peer)
	if inv != null:
		inv.slots[slot] = 0
	grid.floor_items[tile] = iid
	floor_item_placed.emit(tile, iid)
	inventory_changed.emit(peer)


@rpc("authority", "call_local", "reliable")
func _apply_select_slot(peer: int, index: int) -> void:
	var inv: InventoryState = inventories.get(peer)
	if inv == null:
		return
	inv.selected = index
	inventory_changed.emit(peer)


## 재료 보관함 지급: 인벤토리에 직접 + 재고 갱신
@rpc("authority", "call_local", "reliable")
func _apply_give(peer: int, slot: int, iid: int, new_stock: int) -> void:
	var inv: InventoryState = inventories.get(peer)
	if inv != null:
		inv.slots[slot] = iid
	ingredient_stock = new_stock
	inventory_changed.emit(peer)


@rpc("authority", "call_local", "reliable")
func _apply_place(peer: int, slot: int, key: StringName, iid: int,
		starts_work: bool) -> void:
	var inv: InventoryState = inventories.get(peer)
	if inv != null:
		inv.slots[slot] = 0
	var st: StationState = stations.get(key)
	if st != null:
		st.item_iid = iid
		st.work_in_progress = starts_work
	inventory_changed.emit(peer)
	station_changed.emit(key)


@rpc("authority", "call_local", "reliable")
func _apply_take(peer: int, slot: int, key: StringName, iid: int) -> void:
	var st: StationState = stations.get(key)
	if st != null:
		st.item_iid = 0
		st.work_in_progress = false
	var inv: InventoryState = inventories.get(peer)
	if inv != null:
		inv.slots[slot] = iid
	inventory_changed.emit(peer)
	station_changed.emit(key)


@rpc("authority", "call_local", "reliable")
func _apply_swap(peer: int, slot: int, key: StringName,
		held_iid: int, station_iid: int, starts_work: bool) -> void:
	var inv: InventoryState = inventories.get(peer)
	if inv != null:
		inv.slots[slot] = station_iid
	var st: StationState = stations.get(key)
	if st != null:
		st.item_iid = held_iid
		st.work_in_progress = starts_work
	inventory_changed.emit(peer)
	station_changed.emit(key)


## 설비 상태만 갱신 (작업 완료·조리 경계 알림)
@rpc("authority", "call_local", "reliable")
func _apply_station_state(key: StringName, iid: int, work_in_progress: bool) -> void:
	var st: StationState = stations.get(key)
	if st != null:
		st.item_iid = iid
		st.work_in_progress = work_in_progress
	station_changed.emit(key)


## 제출: 아이템 소멸 + 주문 원자 완료 + 매출 반영
@rpc("authority", "call_local", "reliable")
func _apply_submit(peer: int, slot: int, iid: int, recipe_id: String,
		revenue: int, new_money: int) -> void:
	var inv: InventoryState = inventories.get(peer)
	if inv != null:
		inv.slots[slot] = 0
	items.erase(iid)
	var order: Dictionary = orders.complete_first(StringName(recipe_id))
	revenue_today += revenue
	FranchiseState.set_money(new_money)
	inventory_changed.emit(peer)
	orders_changed.emit()
	order_completed.emit(int(order.get("oid", 0)), revenue)


@rpc("authority", "call_local", "reliable")
func _apply_order_spawned(order: Dictionary) -> void:
	if not is_server():
		# 서버는 server_spawn_order에서 이미 추가함
		orders.active.append(order)
		orders.next_oid = maxi(orders.next_oid, int(order["oid"]) + 1)
	orders_changed.emit()


@rpc("authority", "call_local", "reliable")
func _apply_stock(new_stock: int) -> void:
	ingredient_stock = new_stock


## 직원 상태 전이 + 자금(고용비 차감 등) 브로드캐스트.
## 설비 점유 맵은 직원 위상에서 결정적으로 유도한다 (§10.6).
@rpc("authority", "call_local", "reliable")
func _apply_employee_state(data: Dictionary, new_money: int) -> void:
	var emp: EmployeeState = EmployeeState.from_dict(data)
	# 서버는 자신의 FSM 인스턴스를 유지 (타이머 보존) — 값만 덮지 않는다
	if not is_server() or not employees.has(emp.eid):
		employees[emp.eid] = emp
	var occupying: bool = emp.phase in [
		EmployeeState.Phase.TO_BOX,
		EmployeeState.Phase.TO_BOARD,
		EmployeeState.Phase.CUTTING,
	]
	if occupying:
		station_employee[EMP_BOARD_KEY] = emp.eid
	elif int(station_employee.get(EMP_BOARD_KEY, 0)) == emp.eid:
		station_employee.erase(EMP_BOARD_KEY)
	if FranchiseState.money != new_money:
		FranchiseState.set_money(new_money)
	employee_changed.emit(emp.eid)


@rpc("authority", "call_local", "reliable")
func _apply_fridge_lock(owner_peer: int) -> void:
	fridge.lock_owner = owner_peer
	fridge_lock_changed.emit(owner_peer)


@rpc("authority", "call_local", "reliable")
func _apply_fridge_move(peer: int, from_zone: int, from_slot: int,
		to_zone: int, to_slot: int) -> void:
	var inv: InventoryState = inventories.get(peer)
	if inv == null:
		return
	var from_iid: int = _fridge_zone_get(from_zone, from_slot, inv)
	var to_iid: int = _fridge_zone_get(to_zone, to_slot, inv)
	if from_zone == 0:
		fridge.slots[from_slot] = to_iid
	else:
		inv.slots[from_slot] = to_iid
	if to_zone == 0:
		fridge.slots[to_slot] = from_iid
	else:
		inv.slots[to_slot] = from_iid
	fridge_changed.emit()
	inventory_changed.emit(peer)


@rpc("authority", "call_local", "reliable")
func _apply_ready_state(peer: int, ready: bool) -> void:
	if ready:
		ready_peers[peer] = true
	else:
		ready_peers.erase(peer)
	ready_state_changed.emit()


@rpc("authority", "call_local", "reliable")
func _apply_service_start() -> void:
	ready_peers.clear()
	revenue_today = 0
	ready_state_changed.emit()


## 마감 폐기 (§18): 바닥·설비·인벤토리의 모든 아이템 소멸.
## 냉장고 내부만 생존 (P5에서 냉장고 슬롯은 여기서 건드리지 않음).
@rpc("authority", "call_local", "reliable")
func _apply_settlement(summary: Dictionary) -> void:
	for iid: int in grid.clear_items():
		items.erase(iid)
	for key: StringName in stations.keys():
		var st: StationState = stations[key]
		if st.item_iid != 0:
			items.erase(st.item_iid)
			st.item_iid = 0
			st.work_in_progress = false
	for peer: int in inventories.keys():
		var inv: InventoryState = inventories[peer]
		for iid: int in inv.all_iids():
			items.erase(iid)
		inv.clear_all()
	# 직원이 들고 있던 아이템도 폐기, 작업 상태 초기화 (§18)
	for eid: int in employees.keys():
		var emp: EmployeeState = employees[eid]
		if emp.carrying_iid != 0:
			items.erase(emp.carrying_iid)
			emp.carrying_iid = 0
		emp.phase = EmployeeState.Phase.IDLE
		emp.timer = 0.0
		employee_changed.emit(eid)
	station_employee.clear()
	orders.clear()
	ready_peers.clear()
	ingredient_stock = 0  # 잔여 재료 폐기 (§21.1 과다 주문 위험)
	disposed_today = int(summary.get("disposed", 0))
	if summary.has("new_money"):
		FranchiseState.set_money(int(summary["new_money"]))
	orders_changed.emit()
	ready_state_changed.emit()
	snapshot_applied.emit()  # 뷰 전체 리프레시
	day_settled.emit(summary)


@rpc("authority", "call_local", "reliable")
func _apply_new_day(stock: int, econ: Dictionary, events: Dictionary) -> void:
	ingredient_stock = stock
	FranchiseState.city_econ = econ
	FranchiseState.city_events = events
	ready_peers.clear()
	disposed_today = 0
	revenue_today = 0
	ready_state_changed.emit()
	snapshot_applied.emit()


## 실패 안내 — 해당 피어에게만 (§15.3)
@rpc("authority", "call_local", "reliable")
func notify_fail(msg_key: String) -> void:
	fail_notified.emit(msg_key)


# ── 스냅샷 (후발 참가·로드 동기화; 세이브와 동일 직렬화) ────────────

func build_snapshot() -> Dictionary:
	var item_dicts: Dictionary = {}
	for iid: int in items.keys():
		var item: ItemInstance = items[iid]
		item_dicts[str(iid)] = item.to_dict()
	var inv_dicts: Dictionary = {}
	for peer: int in inventories.keys():
		var inv: InventoryState = inventories[peer]
		inv_dicts[str(peer)] = inv.to_dict()
	var station_dicts: Dictionary = {}
	for key: StringName in stations.keys():
		var st: StationState = stations[key]
		station_dicts[String(key)] = st.to_dict()
	return {
		"next_iid": next_iid,
		"items": item_dicts,
		"grid": grid.to_dict(),
		"inventories": inv_dicts,
		"stations": station_dicts,
		"orders": orders.to_dict(),
		"fridge": fridge.to_dict(),
		"fridge_lock": fridge.lock_owner,
		"employees": _employee_dicts(),
		"next_eid": next_eid,
		"ingredient_stock": ingredient_stock,
		"clock": GameClock.to_dict(),
		"franchise": FranchiseState.to_dict(),
	}


## 세이브용 스냅샷: 인벤토리 키를 피어 ID 대신 플레이어 순번("1"/"2")으로
## 정규화한다 — 게스트 피어 ID는 세션마다 무작위이므로 (PLAN.md §25).
func build_save() -> Dictionary:
	var snap: Dictionary = build_snapshot()
	var normalized: Dictionary = {}
	var inv_dicts: Dictionary = snap.get("inventories", {})
	for key: String in inv_dicts.keys():
		if int(key) == 1:
			normalized["1"] = inv_dicts[key]
		elif not normalized.has("2"):
			normalized["2"] = inv_dicts[key]
	if not normalized.has("2") and not pending_guest_inventory.is_empty():
		# 게스트가 접속한 적 없어도 이전 세이브의 2번 인벤토리는 유지
		normalized["2"] = pending_guest_inventory
	snap["inventories"] = normalized
	snap["fridge_lock"] = 0  # 잠금은 런타임 상태
	return snap


## 서버 전용: 세이브 데이터 복원. setup_store 이후에 호출해야 한다.
func load_save(data: Dictionary) -> void:
	assert(is_server())
	var inv_dicts: Dictionary = data.get("inventories", {})
	pending_guest_inventory = inv_dicts.get("2", {})
	var remapped: Dictionary = data.duplicate()
	remapped["inventories"] = {"1": inv_dicts.get("1", {})}
	apply_snapshot_local(remapped)
	# 접속 중인 게스트에게 전체 스냅샷 재전송
	for peer: int in client_ready_peers.keys():
		server_ensure_peer(peer)


func _send_snapshot_to(peer_id: int) -> void:
	assert(is_server())
	if peer_id == 1:
		return  # 호스트는 원본 그 자체
	_apply_snapshot.rpc_id(peer_id, build_snapshot())


@rpc("authority", "call_local", "reliable")
func _apply_snapshot(snap: Dictionary) -> void:
	apply_snapshot_local(snap)


func apply_snapshot_local(snap: Dictionary) -> void:
	next_iid = int(snap.get("next_iid", 1))
	items.clear()
	var item_dicts: Dictionary = snap.get("items", {})
	for key: String in item_dicts.keys():
		var item: ItemInstance = ItemInstance.from_dict(item_dicts[key])
		items[item.iid] = item
	grid.load_items(snap.get("grid", {}))
	inventories.clear()
	var inv_dicts: Dictionary = snap.get("inventories", {})
	for key: String in inv_dicts.keys():
		inventories[int(key)] = InventoryState.from_dict(inv_dicts[key])
	var station_dicts: Dictionary = snap.get("stations", {})
	for key: String in station_dicts.keys():
		var st: StationState = StationState.from_dict(station_dicts[key])
		if stations.has(st.key):
			stations[st.key] = st
	orders = OrderBook.from_dict(snap.get("orders", {}))
	employees.clear()
	station_employee.clear()
	var emp_dicts: Dictionary = snap.get("employees", {})
	for key: String in emp_dicts.keys():
		var emp: EmployeeState = EmployeeState.from_dict(emp_dicts[key])
		employees[emp.eid] = emp
		employee_changed.emit(emp.eid)
	next_eid = int(snap.get("next_eid", 1))
	if snap.has("fridge"):
		fridge = FridgeState.from_dict(snap.get("fridge", {}))
		fridge.lock_owner = int(snap.get("fridge_lock", 0))
	ingredient_stock = int(snap.get("ingredient_stock", 40))
	fridge_changed.emit()
	GameClock.from_dict(snap.get("clock", {}))
	FranchiseState.from_dict(snap.get("franchise", {}))
	orders_changed.emit()
	snapshot_applied.emit()


# ── 수명 관리 ────────────────────────────────────────────────────────

## NetworkService가 피어 이탈 시 호출 (서버 전용).
func on_peer_left(peer_id: int) -> void:
	client_ready_peers.erase(peer_id)
	# 냉장고 사용권 자동 해제 (§17.5)
	if fridge.lock_owner == peer_id:
		_apply_fridge_lock.rpc(0)
	# 이탈 피어의 준비 상태 제거 — 남은 인원 기준으로 재판정
	if ready_peers.has(peer_id):
		_apply_ready_state.rpc(peer_id, false)


func reset() -> void:
	items.clear()
	grid = GridState.new()
	stations.clear()
	inventories.clear()
	next_iid = 1
	layout = null


func _in_reach(player_tile: Vector2i, target: Vector2i) -> bool:
	var d: Vector2i = (target - player_tile).abs()
	return maxi(d.x, d.y) <= MAX_REACH_TILES
