class_name LiveStore
extends RefCounted
## 라이브 매장 하나의 귀속 상태 (PLAN.md §6 — 독립 매장 이동).
## 서버는 플레이어가 있는 도시마다 하나씩 들고, 클라이언트는 전부 미러링한다.
## 로직은 GameServer에 있다 — 이 클래스는 상태 묶음과 직렬화만 담당.

var grid: GridState = GridState.new()
var stations: Dictionary = {}          ## key(StringName) → StationState
## 설비 배치: key(StringName) → {"def_id": StringName, "tile": Vector2i}.
## 레이아웃 템플릿에서 시작하되 준비 단계 이동·구매로 매장별로 달라진다 (§15).
var placements: Dictionary = {}
## 구매 설비 키(u_n) 발급 카운터
var next_buy_n: int = 1
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
## 누수/미끄러움: {"type": "leak"|"slippery", "station": String, "hits": int}
var event: Dictionary = {}
## 보유한 예방 설비 (§23.4): id → true. 매장 귀속, 되팔기 없음.
var preventions: Dictionary = {}


## 레이아웃 템플릿에서 새 매장 구축 (모든 매장 동일 레이아웃 — 슬라이스 단순화)
static func create(layout: StoreLayout) -> LiveStore:
	var store: LiveStore = LiveStore.new()
	store.grid.walkable = layout.walkable.duplicate()
	store._install_placements(layout.stations.duplicate(true))
	var fridge_def: RefrigeratorDef = Defs.get_def(&"fridge.small") as RefrigeratorDef
	store.fridge = FridgeState.create(fridge_def.id, fridge_def.slot_count)
	return store


## 배치 맵으로 설비 상태·차단 타일을 재구축 (기존 설비 상태는 버려진다)
func _install_placements(p_placements: Dictionary) -> void:
	placements = p_placements
	stations.clear()
	grid.blocked.clear()
	for key: StringName in placements.keys():
		var entry: Dictionary = placements[key]
		stations[key] = StationState.create(key, entry["def_id"])
		grid.blocked[entry["tile"]] = true


func station_tile(key: StringName) -> Vector2i:
	var entry: Dictionary = placements.get(key, {})
	return entry["tile"] if not entry.is_empty() else Vector2i.MAX


func station_key_at(tile: Vector2i) -> StringName:
	for key: StringName in placements.keys():
		var entry: Dictionary = placements[key]
		if entry["tile"] == tile:
			return key
	return StringName()


## 매장 귀속 상태 직렬화 (스냅샷·세이브·오프라인 번들 공통).
## 아이템 본체는 포함하지 않는다 — 스냅샷의 전역 레지스트리가 원본.
func to_dict() -> Dictionary:
	var station_dicts: Dictionary = {}
	for key: StringName in stations.keys():
		station_dicts[String(key)] = (stations[key] as StationState).to_dict()
	var emp_dicts: Dictionary = {}
	for eid: int in employees.keys():
		emp_dicts[str(eid)] = (employees[eid] as EmployeeState).to_dict()
	var place_dicts: Dictionary = {}
	for key: StringName in placements.keys():
		var entry: Dictionary = placements[key]
		var tile: Vector2i = entry["tile"]
		place_dicts[String(key)] = {
			"def_id": String(entry["def_id"]),
			"tile": "%d,%d" % [tile.x, tile.y],  # JSON 호환
		}
	return {
		"grid": grid.to_dict(),
		"placements": place_dicts,
		"next_buy_n": next_buy_n,
		"stations": station_dicts,
		"fridge": fridge.to_dict(),
		"fridge_lock": fridge.lock_owner,
		"employees": emp_dicts,
		"stock": ingredient_stock,
		"orders": orders.to_dict(),
		"revenue_today": revenue_today,
		"event": event.duplicate(true),
		"preventions": preventions.keys(),
	}


## 직렬화 복원. v2 오프라인 번들(orders/fridge_lock 없음)도 그대로 수용하고,
## placements가 없는 구버전 데이터는 레이아웃 템플릿 배치를 유지한다.
static func from_dict(data: Dictionary, layout: StoreLayout) -> LiveStore:
	var store: LiveStore = LiveStore.create(layout)
	if data.has("placements"):
		var parsed: Dictionary = {}
		var place_dicts: Dictionary = data["placements"]
		for key: String in place_dicts.keys():
			var entry: Dictionary = place_dicts[key]
			var parts: PackedStringArray = String(entry.get("tile", "")).split(",")
			if parts.size() != 2:
				continue
			parsed[StringName(key)] = {
				"def_id": StringName(String(entry.get("def_id", ""))),
				"tile": Vector2i(int(parts[0]), int(parts[1])),
			}
		store._install_placements(parsed)
	store.next_buy_n = int(data.get("next_buy_n", 1))
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
	for id: Variant in (data.get("preventions", []) as Array):
		store.preventions[String(id)] = true
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
