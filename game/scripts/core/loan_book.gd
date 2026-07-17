class_name LoanBook
extends RefCounted
## 대출 순수 로직 (PLAN.md §9). 상태 원본은 FranchiseState.loans(Array[Dictionary]).
## 대출 1건: {"lid": int, "product": String, "principal": int, "daily_rate": float,
##            "maturity_rate": float, "due_day": int, "overdue": bool}
##
## 일일 이자는 원금을 줄이지 않고, 만기일 정산에서 원금+만기 이자를 일괄 납부한다.
## 자금 부족 시 연체로 전환 — 이자 가산 + 신규 대출 제한 (§9 축소판).

## 상품표: 원금, 일일 이자율, 만기(일), 만기 이자율 (데이터 조정 가능)
const PRODUCTS: Dictionary = {
	"small": {"amount": 30000, "daily_rate": 0.015,
		"term_days": 10, "maturity_rate": 0.05, "label": "소액"},
	"medium": {"amount": 50000, "daily_rate": 0.02,
		"term_days": 15, "maturity_rate": 0.08, "label": "중액"},
	"large": {"amount": 100000, "daily_rate": 0.03,
		"term_days": 20, "maturity_rate": 0.12, "label": "거액"},
}
## 활성 대출 상한 (§9)
const MAX_ACTIVE: int = 3
## 연체 시 일일 이자 가산율 (§9 연체 비용 축소판)
const OVERDUE_EXTRA_RATE: float = 0.01


static func make_loan(lid: int, product: String, today: int) -> Dictionary:
	var row: Dictionary = PRODUCTS[product]
	return {
		"lid": lid,
		"product": product,
		"principal": int(row["amount"]),
		"daily_rate": float(row["daily_rate"]),
		"maturity_rate": float(row["maturity_rate"]),
		"due_day": today + int(row["term_days"]),
		"overdue": false,
	}


## 오늘 납부할 일일 이자 합계 — 원금은 줄지 않는다 (§9)
static func daily_interest(loans: Array) -> int:
	var total: int = 0
	for loan: Variant in loans:
		var row: Dictionary = loan
		var rate: float = float(row["daily_rate"])
		if bool(row.get("overdue", false)):
			rate += OVERDUE_EXTRA_RATE
		total += ceili(int(row["principal"]) * rate)
	return total


## 전액 상환액: 만기 전 중도 상환은 원금만(만기 이자 면제),
## 만기 도달 이후에는 원금 + 만기 이자 (§9 부분 상환 불가)
static func payoff(loan: Dictionary, today: int) -> int:
	var principal: int = int(loan["principal"])
	if today >= int(loan["due_day"]):
		return principal + ceili(principal * float(loan["maturity_rate"]))
	return principal


static func has_overdue(loans: Array) -> bool:
	for loan: Variant in loans:
		if bool((loan as Dictionary).get("overdue", false)):
			return true
	return false
