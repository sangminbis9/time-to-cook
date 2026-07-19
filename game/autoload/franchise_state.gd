extends Node
## 프랜차이즈 공유 상태: 자금, 일차 누계, 캐릭터 선택 등.
## 서버가 소유하며 변경은 GameServer를 통해서만 일어난다. 클라이언트는 미러.

signal money_changed(money: int)

## 새 게임 시작 자금 (데이터 조정 가능한 기본값)
const STARTING_MONEY: int = 50000

var money: int = 0
## 캐릭터 배정 (§11.1): 슬롯("1"=호스트/"2"=게스트) → char_id(String).
## 비어 있으면 기본 배정(미트/살구). 준비 단계에서만 변경 가능, 중복 선택 불가.
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

## 정보상 로테이션 (§7.3): source_id(String) → {"alias": String, "gone_until": int}
## 사기 친 정보상은 잠적 후 다른 이름으로 재등장한다. 구조는 MarketReport 참조.
var broker_state: Dictionary = {}

## 동적 경제 (§8.1): city_id(String) → 수요 배율 (매일 드리프트)
var city_econ: Dictionary = {}

## 활성 경제 이벤트 (§8.1/§23.2, 공개 정보):
## city_id(String) → {"event_id": String, "days_left": int}
var city_events: Dictionary = {}

## 활성 광고 캠페인 (§8.3): city_id(String) → {"ad_id": String, "days_left": int}
var ad_campaigns: Dictionary = {}

## 캐릭터 영구 업그레이드 (§11.5): char_id(String) → 레벨. 환불·초기화 없음.
var char_upgrades: Dictionary = {}

## 캐릭터 정보 능력 (§7.2-③) 마지막 사용일: char_id(String) → day
var char_info_day: Dictionary = {}

## 완료한 연구 (§20): research_id(String) → true. 구매 즉시 적용, 되돌림 없음.
var research: Dictionary = {}
## 연구 포인트 (§20): 영업일 정산마다 1점 적립
var research_points: int = 0


func research_done(research_id: String) -> bool:
	return research.has(research_id)


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
		"broker_state": broker_state.duplicate(true),
		"city_econ": city_econ.duplicate(),
		"city_events": city_events.duplicate(true),
		"ad_campaigns": ad_campaigns.duplicate(true),
		"character_picks": character_picks.duplicate(),
		"char_upgrades": char_upgrades.duplicate(),
		"char_info_day": char_info_day.duplicate(),
		"research": research.duplicate(),
		"research_points": research_points,
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
	broker_state = data.get("broker_state", {})
	city_econ = data.get("city_econ", {})
	city_events = data.get("city_events", {})
	ad_campaigns = data.get("ad_campaigns", {})
	character_picks = data.get("character_picks", {})
	char_upgrades = data.get("char_upgrades", {})
	char_info_day = data.get("char_info_day", {})
	research = data.get("research", {})
	research_points = int(data.get("research_points", 0))
	set_money(int(data.get("money", 0)))
