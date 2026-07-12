#!/usr/bin/env python3
"""Time to Cook 플레이스홀더 도트 아트 생성기 (의존성 없음).

PLAN.md §3 팔레트(크림/나무/민트/하늘/살구)를 따르는 32×32 타일·설비·캐릭터와
16×16 아이템 스프라이트를 game/assets/sprites/ 에 PNG로 출력한다.
최종 아트로 교체될 때까지의 임시 규격 자산이다.

사용법: python3 tools/gen_placeholder_art.py
"""
from __future__ import annotations

import os
import struct
import zlib

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sprites")

# ── 팔레트 (PLAN.md §3.1) ────────────────────────────────────────────
CREAM = (0xF7, 0xEF, 0xD9, 255)
CREAM_SH = (0xEA, 0xD9, 0xB8, 255)
WOOD = (0xB9, 0x8A, 0x5E, 255)
WOOD_DK = (0x96, 0x68, 0x3F, 255)
LBROWN = (0xD9, 0xB4, 0x8F, 255)
MINT = (0xA8, 0xD8, 0xC9, 255)
MINT_DK = (0x7F, 0xBF, 0xA8, 255)
SKY = (0xA3, 0xCD, 0xE8, 255)
APRICOT = (0xF5, 0xC6, 0xA5, 255)
APRICOT_DK = (0xE8, 0xA1, 0x64, 255)
OUTLINE = (0x5A, 0x46, 0x32, 255)
PINK = (0xF2, 0xB8, 0xB0, 255)
PINK_DK = (0xDE, 0x90, 0x88, 255)
GOLD = (0xE8, 0xA3, 0x4C, 255)
GOLD_DK = (0xC9, 0x7F, 0x2E, 255)
BURNT = (0x6B, 0x56, 0x42, 255)
BURNT_DK = (0x4A, 0x3A, 0x2C, 255)
WHITE = (0xFF, 0xFF, 0xFF, 255)
FLOUR = (0xF3, 0xEA, 0xD5, 255)
STEEL = (0xC8, 0xC4, 0xB8, 255)
STEEL_DK = (0x9A, 0x96, 0x8A, 255)
RED = (0xD9, 0x7B, 0x6C, 255)
SKIN = (0xF6, 0xD9, 0xBC, 255)
HAIR_BROWN = (0x7A, 0x59, 0x3C, 255)
HAIR_DARK = (0x4E, 0x3B, 0x2E, 255)
YELLOW = (0xF2, 0xD3, 0x6E, 255)
CLEAR = (0, 0, 0, 0)


def write_png(path: str, width: int, height: int, pixels: list[list[tuple]]) -> None:
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

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


class Canvas:
    def __init__(self, w: int, h: int, bg: tuple = CLEAR):
        self.w, self.h = w, h
        self.px = [[bg for _ in range(w)] for _ in range(h)]

    def set(self, x: int, y: int, c: tuple) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def rect(self, x: int, y: int, w: int, h: int, c: tuple) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def outline(self, x: int, y: int, w: int, h: int, c: tuple) -> None:
        for xx in range(x, x + w):
            self.set(xx, y, c)
            self.set(xx, y + h - 1, c)
        for yy in range(y, y + h):
            self.set(x, yy, c)
            self.set(x + w - 1, yy, c)

    def disc(self, cx: int, cy: int, r: int, c: tuple) -> None:
        for yy in range(cy - r, cy + r + 1):
            for xx in range(cx - r, cx + r + 1):
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r:
                    self.set(xx, yy, c)

    def hline(self, x: int, y: int, w: int, c: tuple) -> None:
        for xx in range(x, x + w):
            self.set(xx, y, c)

    def vline(self, x: int, y: int, h: int, c: tuple) -> None:
        for yy in range(y, y + h):
            self.set(x, yy, c)

    def save(self, name: str) -> None:
        write_png(os.path.join(OUT_DIR, name), self.w, self.h, self.px)
        print("  ", name)


# ── 타일 ─────────────────────────────────────────────────────────────
def tile_floor(alt: bool) -> Canvas:
    c = Canvas(32, 32, LBROWN)
    # 나무 판자 결
    for row in range(4):
        y = row * 8
        c.hline(0, y, 32, WOOD)
        offset = 16 if (row % 2 == 0) != alt else 0
        c.vline(offset, y + 1, 7, WOOD)
        # 은은한 나뭇결 점
        c.set((offset + 7) % 32, y + 3, WOOD)
        c.set((offset + 24) % 32, y + 5, WOOD)
    return c


def tile_wall_face() -> Canvas:
    # 스타듀식 실내 벽 정면 (크림 벽지 + 하단 목재 걸레받이)
    c = Canvas(32, 32, CREAM)
    for y in range(0, 24, 6):
        c.hline(0, y, 32, CREAM_SH)
    for x in range(0, 32, 8):
        c.vline(x, 0, 24, CREAM_SH)
    c.rect(0, 24, 32, 8, WOOD)
    c.hline(0, 24, 32, WOOD_DK)
    c.hline(0, 31, 32, WOOD_DK)
    return c


def tile_wall_top() -> Canvas:
    c = Canvas(32, 32, WOOD_DK)
    c.rect(1, 1, 30, 30, WOOD)
    c.outline(0, 0, 32, 32, OUTLINE)
    return c


# ── 설비 공통: 카운터 몸체 ───────────────────────────────────────────
def counter_base() -> Canvas:
    c = Canvas(32, 32)
    c.rect(1, 4, 30, 24, WOOD)          # 몸체
    c.rect(1, 4, 30, 10, LBROWN)        # 상판
    c.hline(1, 13, 30, WOOD_DK)         # 상판 모서리
    c.rect(1, 24, 30, 4, WOOD_DK)       # 하단 그림자
    c.outline(0, 3, 32, 26, OUTLINE)
    return c


def station_counter() -> Canvas:
    return counter_base()


def station_cutting_board() -> Canvas:
    c = counter_base()
    c.rect(6, 6, 20, 8, CREAM)          # 도마
    c.outline(6, 6, 20, 8, WOOD_DK)
    c.rect(21, 8, 6, 2, STEEL)          # 칼날
    c.rect(25, 7, 3, 4, HAIR_DARK)      # 손잡이
    return c


def station_breading_table() -> Canvas:
    c = counter_base()
    c.disc(15, 10, 6, CREAM_SH)         # 볼
    c.disc(15, 9, 5, FLOUR)             # 튀김가루
    c.outline(9, 5, 13, 10, WOOD_DK)
    c.set(13, 8, WHITE)
    c.set(17, 9, WHITE)
    return c


def station_fryer() -> Canvas:
    c = Canvas(32, 32)
    c.rect(1, 3, 30, 26, STEEL)
    c.rect(3, 6, 26, 12, STEEL_DK)      # 기름조
    c.rect(4, 7, 24, 10, GOLD)          # 기름
    c.hline(4, 7, 24, GOLD_DK)
    # 바스켓 손잡이
    c.rect(12, 2, 8, 3, HAIR_DARK)
    c.rect(1, 22, 30, 7, STEEL_DK)      # 하단부
    c.disc(8, 25, 2, RED)               # 다이얼
    c.disc(16, 25, 2, MINT_DK)
    c.outline(0, 2, 32, 28, OUTLINE)
    return c


def station_submit() -> Canvas:
    c = counter_base()
    c.rect(1, 4, 30, 10, MINT)          # 민트 상판 = 제출대 구분
    c.hline(1, 13, 30, MINT_DK)
    c.disc(16, 9, 4, YELLOW)            # 종
    c.rect(15, 4, 3, 2, GOLD_DK)
    c.outline(0, 3, 32, 26, OUTLINE)
    return c


def station_fridge() -> Canvas:
    c = Canvas(32, 32)
    c.rect(3, 1, 26, 30, MINT)
    c.rect(3, 1, 26, 12, SKY)           # 냉동칸 문
    c.hline(3, 13, 26, MINT_DK)
    c.rect(24, 5, 2, 5, STEEL_DK)       # 손잡이
    c.rect(24, 17, 2, 7, STEEL_DK)
    c.outline(2, 0, 28, 32, OUTLINE)
    return c


def station_ingredient_box() -> Canvas:
    c = Canvas(32, 32)
    c.rect(2, 8, 28, 20, WOOD)
    c.rect(4, 10, 24, 16, WOOD_DK)
    c.rect(4, 10, 24, 4, LBROWN)        # 상자 안쪽
    # 안에 든 생닭들
    c.disc(11, 18, 4, PINK)
    c.disc(21, 19, 4, PINK)
    c.set(10, 16, PINK_DK)
    c.set(20, 17, PINK_DK)
    c.outline(1, 7, 30, 22, OUTLINE)
    return c


# ── 아이템 (16×16) ───────────────────────────────────────────────────
def item_raw_chicken() -> Canvas:
    c = Canvas(16, 16)
    c.disc(8, 9, 5, PINK)
    c.disc(6, 7, 2, PINK)
    c.disc(11, 6, 2, PINK)
    c.set(5, 10, PINK_DK)
    c.set(9, 11, PINK_DK)
    c.set(10, 8, PINK_DK)
    c.outline(3, 4, 11, 11, CLEAR)      # (윤곽 없음 — 부드럽게)
    return c


def item_cut_chicken() -> Canvas:
    c = Canvas(16, 16)
    for cx, cy in ((4, 5), (11, 5), (5, 11), (11, 11)):
        c.disc(cx, cy, 2, PINK)
        c.set(cx, cy + 1, PINK_DK)
    return c


def item_breaded_chicken() -> Canvas:
    c = Canvas(16, 16)
    for cx, cy in ((4, 5), (11, 5), (5, 11), (11, 11)):
        c.disc(cx, cy, 2, FLOUR)
        c.set(cx - 1, cy, CREAM_SH)
        c.set(cx + 1, cy + 1, CREAM_SH)
    return c


def item_dakgangjeong() -> Canvas:
    c = Canvas(16, 16)
    for cx, cy in ((4, 5), (11, 5), (5, 11), (11, 11)):
        c.disc(cx, cy, 2, GOLD)
        c.set(cx, cy - 1, GOLD_DK)
        c.set(cx + 1, cy + 1, GOLD_DK)
    c.set(8, 8, RED)                    # 소스 포인트
    return c


def item_burnt_food() -> Canvas:
    c = Canvas(16, 16)
    for cx, cy in ((4, 5), (11, 5), (5, 11), (11, 11)):
        c.disc(cx, cy, 2, BURNT)
        c.set(cx, cy, BURNT_DK)
    c.set(8, 3, STEEL_DK)               # 연기
    c.set(9, 2, STEEL_DK)
    return c


# ── 플레이어 시트 (4방향 × 2프레임, 32×32 프레임, 가로 배열) ─────────
def player_sheet(apron: tuple, apron_dk: tuple, hair: tuple) -> Canvas:
    sheet = Canvas(32 * 8, 32)
    # 프레임 순서: down0 down1 up0 up1 left0 left1 right0 right1
    for i, (facing, step) in enumerate(
        [(d, s) for d in ("down", "up", "left", "right") for s in (0, 1)]
    ):
        ox = i * 32
        _draw_player(sheet, ox, facing, step, apron, apron_dk, hair)
    return sheet


def _draw_player(c: Canvas, ox: int, facing: str, step: int,
                 apron: tuple, apron_dk: tuple, hair: tuple) -> None:
    x0 = ox + 10          # 몸 좌측 (12px 폭 몸통)
    # 다리 (걷기 프레임이면 벌림)
    leg_y = 26
    if step == 0:
        c.rect(x0 + 2, leg_y, 3, 4, HAIR_DARK)
        c.rect(x0 + 7, leg_y, 3, 4, HAIR_DARK)
    else:
        c.rect(x0 + 1, leg_y, 3, 4, HAIR_DARK)
        c.rect(x0 + 8, leg_y, 3, 4, HAIR_DARK)
    # 몸통 + 앞치마
    c.rect(x0, 16, 12, 10, WHITE)
    c.rect(x0 + 1, 18, 10, 8, apron)
    c.hline(x0 + 1, 18, 10, apron_dk)
    # 팔
    c.rect(x0 - 1, 17, 2, 6, WHITE)
    c.rect(x0 + 11, 17, 2, 6, WHITE)
    # 머리 (10px 반지름 SD 헤드)
    hx, hy = ox + 16, 9
    c.disc(hx, hy, 7, SKIN)
    # 머리카락 & 얼굴 방향
    if facing == "down":
        c.rect(hx - 7, hy - 7, 15, 5, hair)
        c.set(hx - 3, hy + 1, OUTLINE)   # 눈
        c.set(hx + 3, hy + 1, OUTLINE)
        c.set(hx, hy + 4, PINK_DK)       # 입
    elif facing == "up":
        c.rect(hx - 7, hy - 7, 15, 10, hair)
    elif facing == "left":
        c.rect(hx - 7, hy - 7, 15, 5, hair)
        c.rect(hx + 3, hy - 4, 5, 5, hair)
        c.set(hx - 4, hy + 1, OUTLINE)
    else:  # right
        c.rect(hx - 7, hy - 7, 15, 5, hair)
        c.rect(hx - 7, hy - 4, 5, 5, hair)
        c.set(hx + 4, hy + 1, OUTLINE)


# ── UI ───────────────────────────────────────────────────────────────
def ui_panel() -> Canvas:
    # 9-patch용 크림 패널 (테두리 4px)
    c = Canvas(24, 24, CREAM)
    c.outline(0, 0, 24, 24, OUTLINE)
    c.outline(1, 1, 22, 22, WOOD)
    c.outline(2, 2, 20, 20, WOOD_DK)
    c.rect(3, 3, 18, 18, CREAM)
    return c


def ui_slot() -> Canvas:
    c = Canvas(20, 20, CREAM_SH)
    c.outline(0, 0, 20, 20, WOOD_DK)
    c.rect(1, 1, 18, 1, WOOD)
    return c


def highlight_ring() -> Canvas:
    # 선택 대상 외곽선 (타일 위에 얹는 얇은 링, 하늘색)
    c = Canvas(32, 32)
    c.outline(0, 0, 32, 32, SKY)
    c.outline(1, 1, 30, 30, SKY)
    return c


SPRITES = {
    "tile_floor_wood.png": lambda: tile_floor(False),
    "tile_floor_wood_alt.png": lambda: tile_floor(True),
    "tile_wall_face.png": tile_wall_face,
    "tile_wall_top.png": tile_wall_top,
    "station_counter.png": station_counter,
    "station_cutting_board.png": station_cutting_board,
    "station_breading_table.png": station_breading_table,
    "station_fryer.png": station_fryer,
    "station_submit.png": station_submit,
    "station_fridge.png": station_fridge,
    "station_ingredient_box.png": station_ingredient_box,
    "item_raw_chicken.png": item_raw_chicken,
    "item_cut_chicken.png": item_cut_chicken,
    "item_breaded_chicken.png": item_breaded_chicken,
    "item_dakgangjeong.png": item_dakgangjeong,
    "item_burnt_food.png": item_burnt_food,
    "player_mint.png": lambda: player_sheet(MINT, MINT_DK, HAIR_BROWN),
    "player_apricot.png": lambda: player_sheet(APRICOT, APRICOT_DK, HAIR_DARK),
    "ui_panel.png": ui_panel,
    "ui_slot.png": ui_slot,
    "highlight_ring.png": highlight_ring,
}


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    print("생성 중: %s" % os.path.abspath(OUT_DIR))
    for name, fn in SPRITES.items():
        fn().save(name)
    print("완료: %d개 스프라이트" % len(SPRITES))


if __name__ == "__main__":
    main()
