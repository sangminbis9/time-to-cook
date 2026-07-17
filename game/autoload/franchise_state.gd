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
## 대출 (§9): 활성 최대 3건, 개별 원금·이자·만기. 구조는 LoanBook 참조.
var loans: Array = []
var next_lid: int = 1

## 오프라인 매장 번들 (§6): city_id(String) → 매장 번들
## {items, grid, stations, fridge, employees, stock 등 — GameServer가 관리}
## 플레이어가 있는 매장은 GameServer.live가 원본이며 여기서 빠진다.
var stores: Dictionary = {}

## 시장 정보 (§7.5): city_id(String) → 최근 성공 보고서 스냅샷
var market_info: Dictionary = {}

## 동적 경제 (§8.1): city_id(String) → 수요 배율 (매일 드리프트)
var city_econ: Dictionary = {}

## 활성 경제 이벤트 (§8.1/§23.2, 공개 정보):
## city_id(String) → {"event_id": String, "days_left": int}
var city_events: Dictionary = {}

## 활성 광고 캠페인 (§8.3): city_id(String) → {"ad_id": String, "days_left": int}
var ad_campaigns: Dictionary = {}

## 캐릭터 영구 업그레이드 (§11.5): char_id(String) → 레벨. 환불·초기화 없음.
var char_upgrades: Dictionary = {}


func char_upgrade_level(char_id: String) -> int:
	return int(char_upgrades.get(char_id, 0))


func set_money(value: int) -> void:
	money = value
	money_changed.emit(money)


func add_money(delta: int) -> void:
	set_money(money + delta)


func price_of(recipe: RecipeDef) -> int:
	return int(menu_prices.get(String(recipe.id), recipe.base_price))


func daily_interest() -> int:
	return LoanBook.daily_interest(loans)


func to_dict() -> Dictionary:
	return {
		"money": money,
		"menu_prices": menu_prices.duplicate(),
		"loans": loans.duplicate(true),
		"next_lid": next_lid,
		"stores": stores.duplicate(true),
		"market_info": market_info.duplicate(true),
		"city_econ": city_econ.duplicate(),
		"city_events": city_events.duplicate(true),
		"ad_campaigns": ad_campaigns.duplicate(true),
		"char_upgrades": char_upgrades.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	menu_prices = data.get("menu_prices", {})
	loans = data.get("loans", [])
	next_lid = int(data.get("next_lid", 1))
	# 구버전 세이브 마이그레이션: 단일 대출 → 중액 상품 1건 (만기 없음 처리)
	if loans.is_empty() and int(data.get("loan_principal", 0)) > 0:
		loans = [{
			"lid": 1, "product": "medium",
			"principal": int(data["loan_principal"]),
			"daily_rate": float(data.get("loan_daily_rate", 0.02)),
			"maturity_rate": 0.08, "due_day": 9999, "overdue": false,
		}]
		next_lid = 2
	stores = data.get("stores", {})
	market_info = data.get("market_info", {})
	city_econ = data.get("city_econ", {})
	city_events = data.get("city_events", {})
	ad_campaigns = data.get("ad_campaigns", {})
	char_upgrades = data.get("char_upgrades", {})
	set_money(int(data.get("money", 0)))
