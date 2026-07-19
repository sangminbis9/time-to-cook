# Time to Cook — 힐링 도트 협동 요리 프랜차이즈 타이쿤

탑다운 2D 픽셀 아트, 온라인 2인 협동 요리 게임. Godot 4.7 (GDScript).
전체 기획은 [PLAN.md](PLAN.md), 현재 구현 상태는 [docs/STATUS.md](docs/STATUS.md) 참조.

## 플레이 방법 (Windows)

1. [Godot 4.7-stable Windows 에디터](https://godotengine.org/download/windows/)를 설치한다
   (**정확히 4.7-stable** — 다른 버전은 임포트 캐시가 충돌한다).
2. `D:\Coding\time-to-cook\game\project.godot`을 연다.
3. F5로 실행. **새 게임** → 인천 매장에서 시작.
4. 2인 협동: 한 PC에서 두 번 실행하거나(에디터 F5 + 내보낸 빌드),
   친구가 **참가하기**에 호스트 IP를 입력한다 (기본 포트 7777).

### 조작

| 키 | 동작 |
|---|---|
| WASD | 이동 |
| 마우스 좌클릭 | 상호작용 (집기/놓기/스왑/제출/냉장고) |
| 마우스 우클릭 | 조리 (칼질/튀김옷) |
| Q | 선택 슬롯 아이템 내려놓기 |
| 1–3 / 마우스 휠 | 인벤토리 슬롯 선택 |
| R | 준비 완료 / 다음 날 시작 |
| L | 캐릭터 액티브 스킬 |
| Esc | 냉장고·팝업 닫기 |

### 첫 메뉴: 후라이드 닭강정

재료 보관함(생닭) → 도마에서 우클릭×6 칼질 → 튀김옷 작업대에서 우클릭 →
튀김기 투입 → **정상 구간**(진행 바 민트색)에 꺼내기 → 제출대에 좌클릭.
너무 오래 두면 과조리(살구색)·탄 상태(갈색)가 되어 폐기해야 한다.

## 개발 (WSL/Linux)

```bash
# Godot Linux 바이너리 (최초 1회)
mkdir -p ~/godot && cd ~/godot
wget https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip Godot_v4.7-stable_linux.x86_64.zip && ln -s Godot_v4.7-stable_linux.x86_64 godot

# 에셋 임포트 (Windows 에디터가 닫혀 있을 때만)
~/godot/godot --headless --path game --import

# 단위 테스트 (GUT)
~/godot/godot --headless --path game -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -ginclude_subdirs -gexit

# 통합 테스트 (headless 인스턴스 2개, localhost ENet)
bash game/tests/integration/run_net_tests.sh          # 전체
bash game/tests/integration/run_net_tests.sh fridge   # 개별

# 플레이스홀더 아트 재생성
python3 tools/gen_placeholder_art.py
```

## 구조

```
game/
├── autoload/    Defs(정의 레지스트리) GameClock(위상 시계) NetworkService(ENet)
│                GameServer(호스트 권한 상태+모든 게임플레이 RPC)
│                FranchiseState SaveService SceneRouter NetTest(테스트 드라이버)
├── scripts/
│   ├── core/    노드 무관 순수 로직 (인벤토리·조리 상태머신·주문·그리드…)
│   ├── defs/    Resource 정의 클래스 (ItemDef·StationDef·RecipeDef…)
│   ├── player/  이동·대상 선택 (로컬 권한)
│   ├── stations/ui/store/  뷰 레이어 (상태는 전부 GameServer 미러)
├── data/        .tres 정의 데이터 — 수치 조정은 여기서
└── tests/       unit/ (GUT) + integration/ (2-인스턴스 시나리오)
```

**네트워크 원칙**: 클라이언트는 의도 RPC(`request_*`)를 서버(피어 1)에 보내고,
서버가 검증 후 `_apply_*`를 전원에 브로드캐스트한다. 모든 변이는 `_apply_*`에서만.
싱글플레이도 로컬 ENet 서버로 동일 경로를 쓴다.

**주의 (WSL↔Windows 공유)**: `.godot/`은 커밋 금지(자동 재생성),
Windows 에디터가 열려 있는 동안 WSL에서 `--import` 금지,
세이브(`user://`)는 OS별로 분리된다.
