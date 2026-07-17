class_name StoreLayout
extends RefCounted
## ASCII 텍스트로 기술하는 매장 레이아웃.
## 씬의 TileMapLayer와 GameServer의 그리드를 같은 원본에서 만들어
## 서버·클라이언트 간 지형 불일치를 원천 차단한다.
##
## 기호:
##   # 벽   . 바닥   1/2 플레이어 스폰(바닥)
##   C 일반 작업대  D 도마  B 튀김옷 작업대  F 튀김기
##   X 제출대  I 재료 보관함  R 냉장고

const SYMBOL_TO_STATION: Dictionary = {
	"C": &"station.counter",
	"D": &"station.cutting_board",
	"B": &"station.breading_table",
	"F": &"station.fryer.basic",
	"X": &"station.submit",
	"I": &"station.ingredient_box",
	"R": &"station.fridge.small",
}

## 인천 시작 매장 (13×9) — PLAN.md §29.1
## 양옆 벽은 아트 준비 전이라 생략 — 이동은 walkable 경계가 막는다.
const INCHEON_SMALL: Array[String] = [
	"#############",
	"ICDDCBBCFFC.R",
	".............",
	"....1........",
	".............",
	"........2....",
	".............",
	"........XX...",
	"#############",
]

var width: int = 0
var height: int = 0
## Vector2i → true (바닥; 이동·아이템 배치 가능)
var walkable: Dictionary = {}
## Vector2i → true (벽)
var walls: Dictionary = {}
## 배치 키(StringName) → {"def_id": StringName, "tile": Vector2i}
var stations: Dictionary = {}
## 플레이어 순번(1, 2) → 스폰 타일
var spawn_tiles: Dictionary = {}


static func parse(rows: Array[String]) -> StoreLayout:
	var layout: StoreLayout = StoreLayout.new()
	layout.height = rows.size()
	var counts: Dictionary = {}
	for y in range(rows.size()):
		var row: String = rows[y]
		layout.width = maxi(layout.width, row.length())
		for x in range(row.length()):
			var tile: Vector2i = Vector2i(x, y)
			var symbol: String = row[x]
			match symbol:
				"#":
					layout.walls[tile] = true
				".":
					layout.walkable[tile] = true
				"1", "2":
					layout.walkable[tile] = true
					layout.spawn_tiles[int(symbol)] = tile
				_:
					if SYMBOL_TO_STATION.has(symbol):
						var def_id: StringName = SYMBOL_TO_STATION[symbol]
						var n: int = int(counts.get(symbol, 0)) + 1
						counts[symbol] = n
						var key: StringName = StringName("%s_%d" % [symbol.to_lower(), n])
						layout.stations[key] = {"def_id": def_id, "tile": tile}
						# 설비 발밑도 바닥 — 설비를 옮기면 걷고 놓을 수 있어야 한다
						layout.walkable[tile] = true
	return layout


## 소형 매장 (12×8) — 개설비가 싼 도시. 설비 구성(키 집합)은 표준과 동일.
const COMPACT_SMALL: Array[String] = [
	"############",
	"ICDDCBBCFFCR",
	"............",
	"...1........",
	"............",
	".......2....",
	"......XX....",
	"############",
]

## 대형 매장 (15×10) — 개설비가 비싼 대도시. 설비 사이 여유 공간.
const WIDE_LARGE: Array[String] = [
	"###############",
	"IC.DDC.BBC.FFCR",
	"...............",
	".....1.........",
	"...............",
	"...............",
	".........2.....",
	"...............",
	".........XX....",
	"###############",
]

## 개설비 기준 매장 규모 (원)
const COMPACT_MAX_ENTRY: int = 60000
const WIDE_MIN_ENTRY: int = 90000


static func incheon() -> StoreLayout:
	return parse(INCHEON_SMALL)


## 도시별 매장 템플릿 (§6.6 슬라이스): 개설비가 싼 도시 = 소형(12×8),
## 비싼 대도시 = 대형(15×10), 그 외(인천·부산 등) = 표준(13×9).
## 설비 키 집합은 세 템플릿이 동일 — 직원 고정 경로(d_2·c_4·b_2·c_3)가 항상 유효.
static func for_city(city_id: String) -> StoreLayout:
	var id: StringName = StringName(city_id)
	if city_id == "" or not Defs.has_def(id):
		return incheon()
	var city: CityDef = Defs.get_def(id) as CityDef
	if city == null:
		return incheon()
	if city.entry_cost >= WIDE_MIN_ENTRY:
		return parse(WIDE_LARGE)
	if city.entry_cost > 0 and city.entry_cost <= COMPACT_MAX_ENTRY:
		return parse(COMPACT_SMALL)
	return incheon()


var _station_tiles_cache: Dictionary = {}


## 설비가 점유한 타일 집합 (바닥 아이템 배치·이동 불가)
func station_tiles() -> Dictionary:
	if _station_tiles_cache.is_empty() and not stations.is_empty():
		for key: StringName in stations.keys():
			var entry: Dictionary = stations[key]
			_station_tiles_cache[entry["tile"]] = true
	return _station_tiles_cache


func station_at(tile: Vector2i) -> StringName:
	for key: StringName in stations.keys():
		var entry: Dictionary = stations[key]
		if entry["tile"] == tile:
			return key
	return StringName()


## 플레이어 이동 가능 여부 (바닥이고 설비가 없어야 함)
func is_walkable(tile: Vector2i) -> bool:
	return walkable.has(tile) and not station_tiles().has(tile)
