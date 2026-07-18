extends GutTest
## 매장 이벤트 데이터 정합 (PLAN.md §23.1/§23.4): 이벤트 → 예방 설비 매핑 무결성.


func test_every_event_has_purchasable_prevention() -> void:
	# §23.4 "이벤트는 반드시 대응 수단이 있어야" — 예방 설비도 전 이벤트 커버
	for etype: String in GameServer.PREVENTION_BLOCKS.keys():
		var pid: String = String(GameServer.PREVENTION_BLOCKS[etype])
		assert_true(GameServer.PREVENTION_PRICES.has(pid),
			"%s 차단 설비 %s는 구매 가능" % [etype, pid])


func test_new_event_types_registered() -> void:
	for etype: String in ["vent", "breakdown"]:
		assert_true(GameServer.PREVENTION_BLOCKS.has(etype), "%s 예방 매핑" % etype)
