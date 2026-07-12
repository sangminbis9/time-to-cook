extends Node
## 프랜차이즈 공유 상태: 자금, 일차 누계, 캐릭터 선택 등.
## 서버가 소유하며 변경은 GameServer를 통해서만 일어난다. 클라이언트는 미러.

signal money_changed(money: int)

## 새 게임 시작 자금 (데이터 조정 가능한 기본값)
const STARTING_MONEY: int = 50000

var money: int = 0
## peer_id → 캐릭터 ID (수직 슬라이스에서는 자리만 확보)
var character_picks: Dictionary = {}
## 메뉴 판매가 설정 (§8): recipe_id(String) → 원. 없으면 기본가.
var menu_prices: Dictionary = {}
## 대출 (§9 축소판: 활성 1건, 일일 이자 자동 납부, 전액 중도 상환)
var loan_principal: int = 0
var loan_daily_rate: float = 0.02

## 개설된 매장들 (§6): city_id(String) → 매장 번들
## {items, grid, stations, fridge, employees, next stock 등 — GameServer가 관리}
## 활성 매장의 번들은 전환·저장 시점에만 갱신된다.
var stores: Dictionary = {}
## 현재 플레이어들이 있는 매장의 도시 ID
var active_city: String = "city.korea.incheon"

## 시장 정보 (§7.5): city_id(String) → 최근 성공 보고서 스냅샷
var market_info: Dictionary = {}

## 동적 경제 (§8.1): city_id(String) → 수요 배율 (매일 드리프트)
var city_econ: Dictionary = {}

## 활성 경제 이벤트 (§8.1/§23.2, 공개 정보):
## city_id(String) → {"event_id": String, "days_left": int}
var city_events: Dictionary = {}


func set_money(value: int) -> void:
	money = value
	money_changed.emit(money)


func add_money(delta: int) -> void:
	set_money(money + delta)


func price_of(recipe: RecipeDef) -> int:
	return int(menu_prices.get(String(recipe.id), recipe.base_price))


func daily_interest() -> int:
	if loan_principal <= 0:
		return 0
	return ceili(loan_principal * loan_daily_rate)


func is_store_open(city_id: String) -> bool:
	return stores.has(city_id) or city_id == active_city


func to_dict() -> Dictionary:
	return {
		"money": money,
		"menu_prices": menu_prices.duplicate(),
		"loan_principal": loan_principal,
		"loan_daily_rate": loan_daily_rate,
		"stores": stores.duplicate(true),
		"active_city": active_city,
		"market_info": market_info.duplicate(true),
		"city_econ": city_econ.duplicate(),
		"city_events": city_events.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	menu_prices = data.get("menu_prices", {})
	loan_principal = int(data.get("loan_principal", 0))
	loan_daily_rate = float(data.get("loan_daily_rate", 0.02))
	stores = data.get("stores", {})
	active_city = String(data.get("active_city", "city.korea.incheon"))
	market_info = data.get("market_info", {})
	city_econ = data.get("city_econ", {})
	city_events = data.get("city_events", {})
	set_money(int(data.get("money", 0)))
