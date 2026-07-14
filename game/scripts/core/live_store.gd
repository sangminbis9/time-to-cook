class_name LiveStore
extends RefCounted
## 라이브 매장 하나의 귀속 상태 (PLAN.md §6 — 독립 매장 이동).
## 서버는 플레이어가 있는 도시마다 하나씩 들고, 클라이언트는 전부 미러링한다.
## 로직은 GameServer에 있다 — 이 클래스는 상태 묶음과 직렬화만 담당.

var grid: GridState = GridState.new()
var stations: Dictionary = {}          ## key(StringName) → StationState
## 직원이 점유한 설비: station_key → eid (§10.6 — 플레이어 개입 차단)
var station_employee: Dictionary = {}
var fridge: FridgeState = FridgeState.create(&"fridge.small", 3)
var orders: OrderBook = OrderBook.new()
var employees: Dictionary = {}         ## eid → EmployeeState
## 오늘 남은 재료 수량. 새 게임 1일차만 온보딩용 기본값 (§21.1)
var ingredient_stock: int = 40
var revenue_today: int = 0
## 주문 스포너 잔여 시간 (서버 전용 런타임)
var next_order_in: float = 0.0
## 진행 중인 매장 이벤트 (§23.1). {} = 없음.
## 화재: {"type": "fire", "station": String, "hits": int, ["destroy_iid": int]}
## 정전: {"type": "blackout"}
var event: Dictionary = {}


## 레이아웃 템플릿에서 새 매장 구축 (모든 매장 동일 레이아웃 — 슬라이스 단순화)
static func create(layout: StoreLayout) -> LiveStore:
	var store: LiveStore = LiveStore.new()
	store.grid.walkable = layout.walkable.duplicate()
	store.grid.blocked = layout.station_tiles().duplicate()
	for key: StringName in layout.stations.keys():
		var entry: Dictionary = layout.stations[key]
		store.stations[key] = StationState.create(key, entry["def_id"])
	var fridge_def: RefrigeratorDef = Defs.get_def(&"fridge.small") as RefrigeratorDef
	store.fridge = FridgeState.create(fridge_def.id, fridge_def.slot_count)
	return store


## 매장 귀속 상태 직렬화 (스냅샷·세이브·오프라인 번들 공통).
## 아이템 본체는 포함하지 않는다 — 스냅샷의 전역 레지스트리가 원본.
func to_dict() -> Dictionary:
	var station_dicts: Dictionary = {}
	for key: StringName in stations.keys():
		station_dicts[String(key)] = (stations[key] as StationState).to_dict()
	var emp_dicts: Dictionary = {}
	for eid: int in employees.keys():
		emp_dicts[str(eid)] = (employees[eid] as EmployeeState).to_dict()
	return {
		"grid": grid.to_dict(),
		"stations": station_dicts,
		"fridge": fridge.to_dict(),
		"fridge_lock": fridge.lock_owner,
		"employees": emp_dicts,
		"stock": ingredient_stock,
		"orders": orders.to_dict(),
		"revenue_today": revenue_today,
		"event": event.duplicate(true),
	}


## 직렬화 복원. v2 오프라인 번들(orders/fridge_lock 없음)도 그대로 수용한다.
static func from_dict(data: Dictionary, layout: StoreLayout) -> LiveStore:
	var store: LiveStore = LiveStore.create(layout)
	store.grid.load_items(data.get("grid", {}))
	var station_dicts: Dictionary = data.get("stations", {})
	for key: String in station_dicts.keys():
		var st: StationState = StationState.from_dict(station_dicts[key])
		if store.stations.has(st.key):
			store.stations[st.key] = st
	if data.has("fridge"):
		store.fridge = FridgeState.from_dict(data["fridge"])
		store.fridge.lock_owner = int(data.get("fridge_lock", 0))
	var emp_dicts: Dictionary = data.get("employees", {})
	for key: String in emp_dicts.keys():
		var emp: EmployeeState = EmployeeState.from_dict(emp_dicts[key])
		store.employees[emp.eid] = emp
	store.ingredient_stock = int(data.get("stock", 0))
	if data.has("orders"):
		store.orders = OrderBook.from_dict(data["orders"])
	store.revenue_today = int(data.get("revenue_today", 0))
	store.event = data.get("event", {})
	return store


## 이 매장에 귀속된 아이템 iid 집합 (바닥·설비·냉장고·직원 소지).
## 플레이어 인벤토리는 제외 — 아이템은 플레이어와 함께 이동한다.
func store_item_iids() -> Dictionary:
	var iids: Dictionary = {}
	for tile: Vector2i in grid.floor_items.keys():
		iids[grid.item_at(tile)] = true
	for key: StringName in stations.keys():
		var st: StationState = stations[key]
		if st.item_iid != 0:
			iids[st.item_iid] = true
	for iid: int in fridge.slots:
		if iid != 0:
			iids[iid] = true
	for eid: int in employees.keys():
		var emp: EmployeeState = employees[eid]
		if emp.carrying_iid != 0:
			iids[emp.carrying_iid] = true
	return iids
