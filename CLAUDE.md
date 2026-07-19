# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Godot 4.7-stable + GDScript 2인 협동 요리 프랜차이즈 타이쿤. 기획 명세는 `PLAN.md`(§ 번호로 참조),
구현 현황·의도적 단순화 목록은 `docs/STATUS.md`(P 번호). 기능을 추가하면 STATUS.md의
완료 테이블·다음 단계·단순화 절을 함께 갱신한다. 문서·주석·커밋 메시지는 한국어.

## 명령어

Godot Linux 바이너리는 `~/godot/godot` (설치법은 README.md). Windows 에디터와 정확히 같은 4.7-stable.

```bash
# 에셋 임포트 — 새 .tres, class_name 스크립트, PNG/WAV 추가·변경 후 필수.
# Windows 에디터가 열려 있는 동안에는 실행 금지 (임포트 캐시 충돌).
~/godot/godot --headless --path game --import

# 단위 테스트 (GUT) — 전체
~/godot/godot --headless --path game -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -ginclude_subdirs -gexit
# 단일 파일: -gdir 대신 -gtest=res://tests/unit/test_orders.gd

# 통합 테스트 (headless 2인스턴스 ENet — 시나리오는 net_test.gd + run_net_tests.sh 양쪽에 등록)
bash game/tests/integration/run_net_tests.sh              # 전체 (2분 이상 소요)
bash game/tests/integration/run_net_tests.sh fridge logistics   # 개별

# 렌더링 육안 검수 (WSLg 디스플레이 필요) — <경로>.png 저장
DISPLAY=:0 ~/godot/godot --path game --rendering-driver opengl3 -- \
  --nettest=host --scenario=screenshot --result=<경로>

# 아트·사운드 플레이스홀더 재생성 (pip/Pillow 없음 — 순수 stdlib)
python3 tools/gen_placeholder_art.py
python3 tools/gen_sfx.py game/assets/audio
```

`project.godot`에서 `untyped_declaration=2` — 타입 미지정은 에러다. 모든 선언에 정적 타입 필수
(`for key: StringName in ...` 포함).

## 아키텍처

### 네트워크: request → 검증 → apply

모든 게임플레이 RPC는 `game/autoload/game_server.gd` 한 파일에 있다. 클라이언트는 의도 RPC
`request_*`를 `rpc_id(1, ...)`로 서버(피어 1)에 보내고, 서버가 검증한 뒤
`_apply_*`(`@rpc("authority", "call_local")`)를 전원에 브로드캐스트한다. **상태 변이는 `_apply_*`
안에서만** — 서버 검증 코드에서 직접 상태를 바꾸면 게스트 미러가 깨진다. 싱글플레이도 로컬
ENet 서버로 같은 경로를 탄다. 실패 통보는 `notify_fail.rpc_id(peer, "키")` → HUD의
`FAIL_MESSAGES`에 한글 문구 등록.

### 다매장: LiveStore와 프록시

`GameServer.live: {city_id → LiveStore}`가 플레이어가 있는 매장들의 원본(그리드·설비·냉장고·
주문·직원·재고·이벤트), `peer_city: {peer → city_id}`가 소속. 매장 스코프 `_apply_*`는 city_id
인자로 라우팅하고, 뷰 신호(`station_changed` 등)는 **내 매장 것만** emit한다. 뷰·UI는
`GameServer.grid/stations/fridge/orders/...` 읽기 전용 프록시(내 매장)로 접근. 플레이어가 없는
매장은 `FranchiseState.stores`의 오프라인 번들(무사고·통계 매출 추상화). 설비 좌표의 원본은
layout이 아니라 매장별 `placements`다.

### 일일 루프와 정산

`GameClock.phase`: PREP(구매·배치·연구·채용— 대부분의 request가 PREP 전용) → SERVICE(주문
스폰·조리·이벤트) → SETTLEMENT. 정산은 `on_service_time_over`가 summary Dictionary를 만들어
`_apply_settlement.rpc`(재고 0 리셋·이벤트 해제·스킬 리셋), 다음 날은 `_advance_to_next_day` →
`_apply_new_day.rpc`. 세이브/스냅샷은 같은 직렬화기를 공유한다(`build_snapshot`/`apply_snapshot_local`)
— 새 상태 필드는 to_dict/from_dict에 기본값과 함께 추가해야 구버전 세이브가 살아남는다.

### 데이터 주도 정의

`game/data/*.tres` + `scripts/defs/*Def` 클래스를 `Defs` 레지스트리가 스캔한다. 콘텐츠 추가는
대부분 .tres 추가 + `game_server.gd`의 게이트 상수 등록으로 끝난다:
`STATION_PRICES`(구매가), `STATION_RESEARCH`/`PREVENTION_RESEARCH` 등(연구 게이트),
`SAUCE_TABLE_RECIPES`(양념대→레시피 — 판매 메뉴·스포너·가격 UI 자동 연동),
`PREVENTION_PRICES`/`PREVENTION_BLOCKS`(이벤트 예방). 연구 효과는 사용 지점에서
`FranchiseState.research_done()`을 검사하는 lazy 게이트가 관례다.

### 직원과 이벤트의 불변식

- 직원 설비 점유는 `s.station_employee`를 직접 set/erase하지 말 것 — 위상(phase)에서
  `_reserved_keys`로 유도·재구축된다.
- 매장 이벤트는 `s.event` Dictionary 하나(매장당 동시 1건). 발생은
  `server_start_store_event`, 대응은 상호작용(좌클릭) 연타 → `_server_event_hit`(플레이어와 청소·정비 직원
  `_tick_fixer`가 같은 경로). 이벤트 중 주문 스폰 정지. 정산이 `s.event = {}`로 직접 지우므로
  이벤트가 부수 상태(grid 등)를 건드리면 안 된다 — 통로 막힘(debris)이 grid.blocked 대신
  이동 판정에서 이벤트를 참조하는 이유.

### 테스트 결정성 (net_test.gd)

`NetTest`가 모든 `event_*_chance`를 0으로 고정하고 시나리오가 명시적으로 이벤트를 일으킨다 —
새 확률 변수를 추가하면 여기도 0으로 고정할 것. 주문 통제는 `order_interval_min/max = 9999.0`으로
하되, **영업 시작 직후 첫 주문 1건은 무조건 자동 스폰**되므로 개수 검증 시 감안한다.
정확한 금액 검증이 있는 시나리오에 직원을 추가할 때 계산(cashier) 역할은 매출 ×1.05로 값을
깨뜨린다 — 청소(clean)가 안전하다.

## 함정

- GDScript 람다는 지역 변수를 **값 캡처**한다 — 시그널 콜백에서 바깥 변수에 재할당해도 반영
  안 됨. `var captured: Array[Dictionary] = [{}]` 배열 참조로 우회.
- 이 저장소의 훅: `grep` 차단(`rg` 사용), `rm -rf` 차단, 전경 `sleep` 차단.
- 전체 통합 테스트는 120초를 넘으므로 백그라운드로 실행하고 완료 후 로그를 확인한다.
- `TileSetAtlasSource`는 `texture_region_size` 기본이 16×16 — 32×32 타일이면 반드시 명시.
- 이 WSL 환경은 오디오 드라이버가 없다(dummy) — 사운드 검수는 Windows 에디터에서.
- `.godot/`은 커밋하지 않는다(자동 재생성). 세이브(`user://`)는 OS별 분리.
