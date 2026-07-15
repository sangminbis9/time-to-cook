#!/usr/bin/env python3
"""시각 효과(FX) 텍스처 생성기 (의존성 없음).

그림자·조명·비네트 등 절차 생성 가능한 연출 텍스처를
game/assets/sprites/fx/ 에 PNG로 출력한다.

사용법: python3 tools/gen_fx_art.py
"""
from __future__ import annotations

import math
import os
import struct
import zlib

OUT_DIR = os.path.join(
    os.path.dirname(__file__), "..", "game", "assets", "sprites", "fx")


def write_png(path: str, width: int, height: int,
              pixels: list[list[tuple]]) -> None:
    raw = b"".join(
        b"\x00" + b"".join(bytes(px) for px in row) for row in pixels
    )

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)


def shadow_oval(width: int = 32, height: int = 12,
                max_alpha: int = 150) -> list[list[tuple]]:
    """엔티티 발밑 그림자 — 가장자리로 부드럽게 사라지는 타원."""
    cx, cy = (width - 1) / 2.0, (height - 1) / 2.0
    rx, ry = width / 2.0, height / 2.0
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            a = max(0.0, 1.0 - d) ** 1.5
            row.append((0, 0, 0, int(a * max_alpha)))
        rows.append(row)
    return rows


def light_radial(size: int = 256) -> list[list[tuple]]:
    """PointLight2D용 방사형 그라데이션 (중심 흰색 → 가장자리 투명)."""
    c = (size - 1) / 2.0
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            a = max(0.0, 1.0 - d) ** 2.0
            v = int(a * 255)
            row.append((255, 255, 255, v))
        rows.append(row)
    return rows


def vignette(width: int = 320, height: int = 180,
             max_alpha: int = 150) -> list[list[tuple]]:
    """화면 가장자리를 어둡게 — 중심 투명, 모서리에서 최대."""
    cx, cy = (width - 1) / 2.0, (height - 1) / 2.0
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            d = math.hypot((x - cx) / cx, (y - cy) / cy) / math.sqrt(2.0)
            t = min(1.0, max(0.0, (d - 0.55) / 0.45))
            a = (t * t * (3 - 2 * t)) * max_alpha  # smoothstep
            row.append((0, 0, 0, int(a)))
        rows.append(row)
    return rows


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    write_png(os.path.join(OUT_DIR, "shadow_oval.png"), 32, 12, shadow_oval())
    write_png(os.path.join(OUT_DIR, "light_radial.png"), 256, 256,
              light_radial())
    write_png(os.path.join(OUT_DIR, "vignette.png"), 320, 180, vignette())
    print("FX 텍스처 3종 생성 완료 →", os.path.normpath(OUT_DIR))


if __name__ == "__main__":
    main()
