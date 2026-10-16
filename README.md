# Time to Cook

Godot 4.7 stable / GDScript로 새로 구현한 한국어 2D 식당 프랜차이즈 게임입니다. 현재 저장소의 `game/rebuild/`가 실행되는 구현입니다. `PLAN.md`는 보존된 설계 사양이며, 이전 폴더의 코드는 실행과 내보내기에서 제외되어 있습니다.

## 실행

Windows 검토 빌드: `release/windows/TimeToCook.exe`. 같은 폴더의 `TimeToCook.pck`가 필요합니다.

소스 실행:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run.ps1
```

또는 Godot 4.7에서 `game/project.godot`를 열어 F6/F5로 실행하세요. 이 저장소의 로컬 실행 스크립트는 테스트 저장을 `.tools/rebuild-user/` 아래로 분리합니다. 일반 배포판의 저장 위치는 `%APPDATA%/Godot/app_userdata/Time to Cook/franchise_v2/`입니다. 이전 게임의 저장 파일은 자동 변환하거나 덮어쓰지 않습니다.

## 첫 영업

1. 새 게임 → 빈 저장 슬롯 → 캐릭터를 선택합니다.
2. `경영 M` → `발주`에서 생닭·튀김옷·용기를 각 10개 정도 구입합니다.
3. 준비 완료 후 WASD로 이동합니다. 재료함 앞 J로 생닭을 집고, 도마 앞 J로 배치합니다.
4. K를 눌러 칼질 → J 회수 → 튀김옷 작업대 J/K/J → 튀김기 J, 8초 뒤 황금색일 때 J 회수 → 담기 설비 J/K/J.
5. 손님이 앉은 식탁 또는 포장 계산대에서 J로 주문을 받고, 맞는 완성 음식을 들고 J로 서빙합니다. 식사가 끝난 식탁은 K로 청소합니다.
6. 숫자 1–9와 0(10번째 칸), 휠로 가방 슬롯 선택. Q로 내려놓기, L 능력, Tab 담을 레시피 선택, Esc 닫기. 냉장고 슬롯 클릭은 교환, Shift+클릭은 빈 가방 칸으로 이동입니다.
7. 21시 신규 방문이 끝나고, 22시 정산 후 다음 날을 준비합니다. 일반 재고와 음식은 폐기되므로 냉장고에 가열 전 재료를 보관하세요.

차량은 준비 중 구매해야 합니다. 영업 중 뒷문 J → 차량 J → 도로에서 오른쪽으로 운전 → 마트 주차 구역 J → 진열대 가까이 이동 후 B → 구매 → 출구 J → 왼쪽으로 귀환 → 주차장 J → 차량 앞 J 하역. 소매가는 도매의 3배이며, 귀환 전에는 매장 재고가 아닙니다.

온라인: 게임 안 `경영 → 기록 → 협동 호스트 열기`. 친구는 타이틀의 온라인 협동 참가에서 다른 캐릭터와 호스트 IP를 선택합니다. UDP 7777 직접 연결이며 외부 인터넷은 포트포워딩이 필요할 수 있습니다. 공용 세이브와 자금은 호스트 소유입니다.

## 제작과 검토

- 구현 범위, 증거와 제한: [docs/REBUILD_REVIEW.md](docs/REBUILD_REVIEW.md)
- Windows 빌드: `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`
- 짧은 도메인 확인: `powershell -ExecutionPolicy Bypass -File scripts/run.ps1 -Smoke`
- 공식 Godot 4.7 Windows 템플릿을 `.tools/export-templates/`에 두면 제공 프리셋으로 다시 내보낼 수 있습니다.
- 현재 도트 원화·프롬프트: [art_src/cozy_overhaul/README.md](art_src/cozy_overhaul/README.md). `scripts/import_cozy_art.py`로 반영하며 Python, Pillow, NumPy가 필요합니다. `jp_refresh`는 이전 아트와 보조 리소스입니다. `generate_content.py`는 이전 기초 리소스/오디오/밸런스 생성기이며 새 아트에 사용하지 않습니다.
- 스토어 이미지 변형: `scripts/package_art.py`, 한국어 원문 카탈로그: `scripts/localization_catalog.py`.
- Steam 검토 자료: [release/STEAM_RELEASE.md](release/STEAM_RELEASE.md), [상점 설명 초안](release/STORE_DESCRIPTION_KO.md), `release/steam_art/`, `release/screenshots/`.

이 결과는 사람의 검토를 위한 빌드입니다. 장기 밸런스·모든 PC 환경·외부 WAN QA나 Steam 승인이 완료되었다고 주장하지 않습니다. 간소화되거나 아직 없는 세부 기능은 검토 문서에 명시했습니다.

## 3/4 도트 아트 개편

가구 상판과 앞면, 캐릭터의 얼굴과 몸이 보이는 직교 3/4 시점으로 개편했습니다. 인천의 연결된 L자 주방과 작업 섬, 제주의 현무암·귤 가구, 교토의 격자·다다미, 고베의 버건디 부스를 포함한 16개 도시 배치를 제공합니다. 새 매장은 새 배치를 사용하며 기존 저장의 가구 위치는 유지합니다.

레스토랑은 `TileMapLayer` 바닥과 `Sprite2D` 건축·가구, `AnimatedSprite2D` 인물로 구성합니다. 발 위치를 기준으로 Y 정렬하며 두 칸 식탁·작업대의 설치 검사와 경로 계산도 실제 크기를 사용합니다. 캐릭터는 방향별 걷기, 운반, 칼질, 조리, 청소, 대기, 상호작용 프레임을 사용합니다. 작은 HUD와 그림 카드 메뉴, 다양한 거리 건물·차량·마트 진열대도 반영했습니다.

원화와 생성 기록: [art_src/cozy_overhaul/README.md](art_src/cozy_overhaul/README.md). 재임포트는 `python scripts/import_cozy_art.py`입니다. 강제 색상 수 축소와 복제 프레임 생성을 하지 않습니다. 실제 Godot 화면과 변경 설명은 [release/cozy-overhaul/REVIEW.md](release/cozy-overhaul/REVIEW.md)에 있습니다.
