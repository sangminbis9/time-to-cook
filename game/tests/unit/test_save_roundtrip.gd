extends GutTest
## 세이브 JSON 라운드트립 (PLAN.md §25, §32.5).
## 스냅샷 → JSON 파일 → 복원이 동일 상태를 만드는지 검증.

const TEST_SLOT: int = 99


func after_each() -> void:
	var path: String = SaveService.save_path(TEST_SLOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _build_snapshot() -> Dictionary:
	var inv: InventoryState = InventoryState.new()
	inv.set_slot(0, 3)
	inv.select(0)
	var fridge: FridgeState = FridgeState.create(&"fridge.small", 3)
	fridge.slots[0] = 7
	var grid: GridState = GridState.new()
	grid.walkable[Vector2i(1, 1)] = true
	grid.place(Vector2i(1, 1), 5)
	var book: OrderBook = OrderBook.new()
	book.spawn(&"recipe.fried_dakgangjeong", 12.5)
	var item: ItemInstance = ItemInstance.create(3, &"item.raw_chicken")
	item.cuts_done = 2
	return {
		"day": 4,
		"money": 15300,
		"next_iid": 8,
		"inventory": inv.to_dict(),
		"fridge": fridge.to_dict(),
		"grid": grid.to_dict(),
		"orders": book.to_dict(),
		"items": {"3": item.to_dict()},
	}


func test_write_read_identical() -> void:
	var snap: Dictionary = _build_snapshot()
	assert_eq(SaveService.write_save(TEST_SLOT, snap), OK)
	var loaded: Dictionary = SaveService.read_save(TEST_SLOT)
	assert_false(loaded.is_empty())
	assert_eq(int(loaded["version"]), SaveService.SAVE_VERSION)
	assert_eq(int(loaded["day"]), 4)
	assert_eq(int(loaded["money"]), 15300)
	assert_eq(int(loaded["next_iid"]), 8)

	var inv: InventoryState = InventoryState.from_dict(loaded["inventory"])
	assert_eq(inv.slots[0], 3)
	var fridge: FridgeState = FridgeState.from_dict(loaded["fridge"])
	assert_eq(fridge.slots[0], 7)
	var grid: GridState = GridState.new()
	grid.load_items(loaded["grid"])
	assert_eq(grid.item_at(Vector2i(1, 1)), 5)
	var book: OrderBook = OrderBook.from_dict(loaded["orders"])
	assert_eq(book.active.size(), 1)
	assert_eq(book.next_oid, 2)

	var items: Dictionary = loaded["items"]
	var item: ItemInstance = ItemInstance.from_dict(items["3"])
	assert_eq(item.iid, 3)
	assert_eq(item.def_id, &"item.raw_chicken")
	assert_eq(item.cuts_done, 2)


## v2(단일 활성 매장, 최상위 평면 필드) → v3(stores/peer_city) 마이그레이션
func test_migrate_v2_to_v3() -> void:
	var v2: Dictionary = {
		"version": 2,
		"next_iid": 5,
		"grid": {"floor_items": {"1,1": 3}},
		"stations": {},
		"fridge": {"def_id": "fridge.small", "slots": [7, 0, 0]},
		"employees": {},
		"ingredient_stock": 12,
		"orders": {"active": [], "next_oid": 4, "max_active": 4},
		"franchise": {"money": 1000, "active_city": "city.korea.busan"},
	}
	DirAccess.make_dir_recursive_absolute(SaveService.SAVE_DIR)
	var file: FileAccess = FileAccess.open(
		SaveService.save_path(TEST_SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(v2))
	file.close()
	var loaded: Dictionary = SaveService.read_save(TEST_SLOT)
	assert_true(loaded.has("stores"), "stores로 감싸짐")
	var store: Dictionary = (loaded["stores"] as Dictionary).get(
		"city.korea.busan", {})
	assert_eq(int(store.get("stock", 0)), 12)
	assert_eq(int(((store.get("fridge", {}) as Dictionary).get(
		"slots", []) as Array)[0]), 7)
	var pc: Dictionary = loaded.get("peer_city", {})
	assert_eq(String(pc.get("1", "")), "city.korea.busan")
	assert_eq(String(pc.get("2", "")), "city.korea.busan")


func test_missing_save_returns_empty() -> void:
	assert_true(SaveService.read_save(98).is_empty())


func test_corrupt_save_returns_empty() -> void:
	DirAccess.make_dir_recursive_absolute(SaveService.SAVE_DIR)
	var file: FileAccess = FileAccess.open(SaveService.save_path(TEST_SLOT), FileAccess.WRITE)
	file.store_string("이건 JSON이 아님 {{{")
	file.close()
	assert_true(SaveService.read_save(TEST_SLOT).is_empty())


func test_v3_profile_migration() -> void:
	var v3: Dictionary = {
		"version": 3,
		"franchise": {
			"money": 25000,
			"character_picks": {"1": "char.basil"},
		},
		"clock": {"day": 7},
	}
	DirAccess.make_dir_recursive_absolute(SaveService.SAVE_DIR)
	var file: FileAccess = FileAccess.open(
		SaveService.save_path(TEST_SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(v3))
	file.close()
	var loaded: Dictionary = SaveService.read_save(TEST_SLOT)
	assert_eq(int(loaded["version"]), SaveService.SAVE_VERSION)
	var franchise: Dictionary = loaded["franchise"]
	assert_true(franchise.has("character_names"), "v4 프로필 이름 필드 추가")
	var summary: Dictionary = SaveService.slot_summary(TEST_SLOT)
	assert_eq(String(summary["character_id"]), "char.basil")
	assert_eq(int(summary["day"]), 7)


func test_profile_name_validation() -> void:
	assert_true(SaveService.valid_profile_name("초록별"))
	assert_true(SaveService.valid_profile_name("Mint 2"))
	assert_false(SaveService.valid_profile_name("   "))
	assert_false(SaveService.valid_profile_name("1234567890123"))
	assert_false(SaveService.valid_profile_name("나\n쁜이름"))
