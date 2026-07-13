# Time to Cook — 추가 생성 필요 에셋 (ChatGPT 프롬프트 포함)

1차 납품분 25종 중 24종은 `tools/import_art.py` 파이프라인으로 게임에 반영 완료.
아래는 **미납품·사용 불가·품질 미달**로 재생성이 필요한 것들이다.

## 생성 시 주의 (1차 납품에서 배운 것)

- **이미지 하나에 에셋 하나만.** 두 에셋을 비교 배치하거나 파일명 라벨 텍스트를
  그려 넣으면 사용 불가 (1차 `player_employee.png`가 이걸로 탈락).
- 배경은 **투명 또는 체커보드 무늬**로. 회색 그라데이션·스포트라이트 배경 금지
  (자동 제거가 어려움).
- 고해상도 출력은 괜찮다 — 내 파이프라인이 네이티브 해상도로 다운스케일한다.
  단, **또렷한 픽셀 격자**가 있는 진짜 픽셀아트 스타일이어야 한다.
  붓 터치·사실적 질감·연기 이펙트가 섞인 반실사풍은 뭉개진다 (1차 `item_burnt_food.png`).
- 생성 후 이미지에 글자·워터마크·여러 변형 시안이 없는지 확인하고 전달.

프롬프트는 그대로 복사해 쓰면 된다. 파일명만 지켜서 저장.

---

## 1. `station_submit.png` — 제출대 (필수, 1차 미납품)

게임 내 유일한 민트색 상판 설비. 다른 나무 작업대와 한눈에 구분돼야 한다.

> Cozy warm pixel art in Stardew Valley interior style, top-down 3/4 view, a single
> restaurant order pick-up counter: wooden cabinet body with a MINT GREEN painted
> countertop, a small golden-yellow call bell sitting on top, and a tiny order ticket
> slip. Clean 1px dark brown (#5A4632) outline, 2-3 shade cel coloring, cream and wood
> tone palette with mint green (#A8D8C9) accent. One object only, centered, transparent
> background, no text, no labels, no floor shadow gradient — just a small hard pixel
> shadow at the base. Square image.

## 2. `player_employee.png` — 직원 캐릭터 시트 (필수, 1차 사용 불가)

1차 납품분은 두 시트를 한 장에 비교 배치 + 파일명 텍스트가 박혀 있어 탈락.
**한 장에 이 캐릭터 하나의 8프레임만** 담아야 한다.

> A pixel art character sprite sheet in Stardew Valley style, ONE single chibi character
> repeated in 8 walking frames arranged in ONE horizontal row, evenly spaced on a
> transparent background. The character: a cute cafe employee with a GRAY kerchief/bandana
> on the head, white shirt, and GRAY apron, brown shoes, SD proportions (head is about
> 60% of body height). Frame order left to right: (1) facing DOWN standing, (2) facing
> DOWN mid-step, (3) facing UP standing showing back of head, (4) facing UP mid-step,
> (5) facing LEFT standing in side profile, (6) facing LEFT mid-step, (7) facing LEFT
> standing (same as 5), (8) facing LEFT mid-step (same as 6). All side-view frames face
> LEFT only. Clean 1px dark brown outline, 2-3 shade cel coloring, small hard pixel
> shadow under the feet. No text, no labels, no extra characters, no background scenery.

(옆모습은 왼쪽만 있으면 된다 — 오른쪽은 내가 미러링한다. 7·8번이 5·6번과 같아도 무방.)

## 3. `tile_floor_wood.png` — 원목 마루 타일 (선택)

1차 납품분은 널빤지가 10줄이라 뭉개졌으나 `tools/fix_tiles.py`가 이음선 3줄 구간을
잘라내 보정 적용 완료 — 현재 상태로도 쓸 만하다. 전용 타일로 교체하고 싶을 때만 생성.
**한 타일에 널빤지 2~3줄**의 큼직한 스케일이어야 한다.

> A single seamless pixel art floor tile of warm honey-brown wooden planks, Stardew
> Valley interior style, viewed straight from above. IMPORTANT: only 2 or 3 large
> horizontal planks fill the entire tile — big chunky plank scale, NOT many thin planks.
> Each plank is a flat warm wood color (#B98A5E) with 2-3 subtle darker grain lines and
> a dark brown (#96683F) 1px seam between planks. The pattern must tile seamlessly:
> plank seams run fully edge to edge horizontally, and the top edge continues the bottom
> edge. Flat colors, no lighting gradient, no vignette, square image, fills the whole
> canvas with no border or margin.

## 4. `tile_floor_wood_alt.png` — 마루 변형 타일 (선택, 위와 세트 — 현재는 본 타일 미러로 합성 중)

> The same seamless pixel art wooden plank floor tile as before (2-3 large horizontal
> honey-brown planks, Stardew Valley style, flat top-down view, dark seams, seamless
> edges), but a subtle variation: the vertical joints between plank ends are offset to
> different positions, and one plank has a small darker knot. Same palette (#B98A5E
> base, #96683F seams), same plank scale and thickness so the two tiles can be placed
> in a checkerboard without visible pattern breaks. Square image, fills the whole
> canvas, no border.

## 5. `tile_wall_top.png` — 벽 상단 캡 타일 (선택, 현재 톤이 밝아 벽 정면과 구분 약함)

> A single seamless pixel art tile of a dark wooden wall cap viewed straight from above
> — the flat top surface of an interior wall, Stardew Valley style. Rich DARK brown wood
> (#6B4A2F base, #5A4632 seams), 2 wide planks running horizontally with subtle grain,
> clearly darker than a cream wallpaper. Flat colors, seamless left-right and top-bottom,
> square image filling the whole canvas, no border, no lighting gradient.

## 6. `item_burnt_food.png` — 탄 음식 (선택, 현재 반실사풍을 후처리해 임시 사용 중)

> Cute pixel art icon of four burnt chicken pieces in Stardew Valley item style: chunky
> dark charcoal-brown pieces (#3A2A20 to #1E1614) with a few tiny ember-orange pixels,
> and one or two small gray pixel smoke puffs above. Clean 1px darkest-brown outline,
> 2-3 shade cel coloring, flat colors, single centered icon on a transparent background,
> no text, square image. Simple and readable at very small size.

## 7. `decor_rug.png` — 러그 (선택, 1차 미납품)

> A pixel art round rug for a cozy cafe interior, Stardew Valley style, viewed straight
> from above: soft mint green (#A8D8C9) oval rug with a cream (#F7EFD9) border band and
> simple stitch marks, flat 2-3 shade cel coloring, 1px darker outline. Single object
> centered on a transparent background, no text, square image.

---

## 납품 방법

파일명 그대로 전달해 주면 `python3 tools/import_art.py <폴더> game/assets/sprites`로
반영한다. 원본은 `art_src/`에 보관된다.
