#!/usr/bin/env python3
"""1차 납품 타일 보정 — 타일 사이가 벌어져 보이는 문제 해결.

원본(art_src)의 바깥 액자 테두리가 다운스케일에 섞여 타일 가장자리가 어두워지고,
바닥 원본은 널빤지가 10줄이라 32px에서 뭉개졌다. 보정:
- tile_floor_wood: 액자 안쪽에서 널빤지 이음선(어두운 행) 3줄 구간을 검출해 크롭
  → 이음선이 타일 경계에 정확히 걸려 이어 붙여도 무늬가 연속됨
- tile_floor_wood_alt: 본 타일의 좌우 미러 (체커 배치 시 같은 질감으로 이어짐)
- tile_wall_face / tile_wall_top: 좌우 테두리만 잘라내고 세로는 그대로

사용: python3 tools/fix_tiles.py  (art_src/ → game/assets/sprites/)
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import downscale, read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_src")
OUT = os.path.join(ROOT, "game", "assets", "sprites")
FRAME = 40  # 원본 바깥 액자 테두리 두께(px, 여유 포함)


def _row_luma(w: int, px: bytearray, y: int, x0: int, x1: int) -> float:
    s = 0
    for x in range(x0, x1):
        p = (y * w + x) * 4
        s += px[p] * 3 + px[p + 1] * 6 + px[p + 2]
    return s / (x1 - x0)


def find_seam_starts(w: int, h: int, px: bytearray) -> list[int]:
    """액자 안쪽에서 널빤지 이음선(어두운 행 무리)의 시작 행들을 찾는다."""
    y0, y1 = FRAME, h - FRAME
    lum = [_row_luma(w, px, y, FRAME, w - FRAME) for y in range(y0, y1)]
    mean = sum(lum) / len(lum)
    var = sum((v - mean) ** 2 for v in lum) / len(lum)
    thresh = mean - 1.2 * var**0.5
    starts: list[int] = []
    in_run = False
    for i, v in enumerate(lum):
        if v < thresh and not in_run:
            starts.append(y0 + i)
            in_run = True
        elif v >= thresh:
            in_run = False
    return starts


def mirror(w: int, h: int, px: bytearray) -> bytearray:
    out = bytearray(len(px))
    for y in range(h):
        for x in range(w):
            s = (y * w + x) * 4
            d = (y * w + (w - 1 - x)) * 4
            out[d : d + 4] = px[s : s + 4]
    return out


def main() -> int:
    # 바닥: 이음선 3칸 구간 크롭
    w, h, px = read_png(os.path.join(SRC, "tile_floor_wood.png"))
    seams = find_seam_starts(w, h, px)
    if len(seams) < 4:
        print(f"이음선 {len(seams)}개뿐 — 검출 실패")
        return 1
    # 3칸 구간 중 길이가 가장 균형 잡힌(중앙값에 가까운) 구간 선택
    spans = [(seams[i + 3] - seams[i], i) for i in range(len(seams) - 3)]
    target = sorted(s for s, _ in spans)[len(spans) // 2]
    _, best = min(spans, key=lambda t: abs(t[0] - target))
    y0, y1 = seams[best], seams[best + 3]
    floor = downscale(w, h, px, (FRAME, y0, w - FRAME, y1), 32, 32, force_opaque=True)
    write_png(os.path.join(OUT, "tile_floor_wood.png"), 32, 32, floor)
    print(f"OK tile_floor_wood (이음선 {len(seams)}개, 크롭 y{y0}..{y1})")

    write_png(os.path.join(OUT, "tile_floor_wood_alt.png"), 32, 32, mirror(32, 32, floor))
    print("OK tile_floor_wood_alt (미러)")

    # 벽: 좌우 테두리 제거
    for name in ("tile_wall_face.png", "tile_wall_top.png"):
        w, h, px = read_png(os.path.join(SRC, name))
        tile = downscale(w, h, px, (FRAME, 0, w - FRAME, h), 32, 32, force_opaque=True)
        write_png(os.path.join(OUT, name), 32, 32, tile)
        print(f"OK {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
