extends GutTest
## 대출 순수 로직 (PLAN.md §9).


func test_make_loan_uses_product_table() -> void:
	var loan: Dictionary = LoanBook.make_loan(7, "small", 5)
	assert_eq(int(loan["lid"]), 7)
	assert_eq(int(loan["principal"]), 30000)
	assert_eq(int(loan["due_day"]), 15, "만기 = 오늘 + term_days")
	assert_false(bool(loan["overdue"]))


func test_daily_interest_sums_and_overdue_surcharge() -> void:
	var a: Dictionary = LoanBook.make_loan(1, "small", 1)   # 30000 × 1.5% = 450
	var b: Dictionary = LoanBook.make_loan(2, "medium", 1)  # 50000 × 2% = 1000
	assert_eq(LoanBook.daily_interest([a, b]), 1450)
	b["overdue"] = true  # +1% 가산 → 50000 × 3% = 1500
	assert_eq(LoanBook.daily_interest([a, b]), 1950)
	assert_eq(LoanBook.daily_interest([]), 0)


func test_payoff_before_and_after_due() -> void:
	var loan: Dictionary = LoanBook.make_loan(1, "medium", 1)  # 만기 16일차
	assert_eq(LoanBook.payoff(loan, 10), 50000, "만기 전 중도 상환은 원금만")
	assert_eq(LoanBook.payoff(loan, 16), 54000, "만기 후 = 원금 + 만기 이자 8%")


func test_has_overdue() -> void:
	var a: Dictionary = LoanBook.make_loan(1, "small", 1)
	assert_false(LoanBook.has_overdue([a]))
	a["overdue"] = true
	assert_true(LoanBook.has_overdue([a]))


func test_grade_monotonic() -> void:
	# 거액일수록 이자율·만기 이자율이 높다 (리스크 반영)
	var small: Dictionary = LoanBook.PRODUCTS["small"]
	var medium: Dictionary = LoanBook.PRODUCTS["medium"]
	var large: Dictionary = LoanBook.PRODUCTS["large"]
	assert_lt(float(small["daily_rate"]), float(medium["daily_rate"]))
	assert_lt(float(medium["daily_rate"]), float(large["daily_rate"]))
	assert_lt(int(small["amount"]), int(medium["amount"]))
	assert_lt(int(medium["amount"]), int(large["amount"]))
