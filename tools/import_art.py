#!/usr/bin/env python3
"""AI 생성 고해상도 도트 에셋 → 게임 네이티브 해상도 변환 파이프라인.

- 순수 파이썬 PNG 디코드/인코드 (Pillow 없는 환경)
- 가짜 체커보드·그라데이션 배경 제거: 테두리에서 플러드필
  (테두리 대표색 팔레트 근접 OR 인접 픽셀과의 점진 변화 추종)
- 블록 중앙값 다운스케일 (알파는 다수결, 0/255 양자화)
- 캐릭터 시트: 세로 투영으로 프레임 분리 → 32×32 8프레임(아래·위·왼·오 각 2) 조립

사용: python3 tools/import_art.py <원본_폴더> <출력_폴더>
"""
from __future__ import annotations

import os
import struct
import sys
import zlib
from collections import deque

# ── PNG 입출력 ───────────────────────────────────────────────


def read_png(path: str) -> tuple[int, int, bytearray]:
    """RGBA 평탄 bytearray로 디코드한다."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: PNG 아님")
    pos = 8
    idat = b""
    w = h = 0
    ctype = -1
    palette = b""
    trns = b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos : pos + 4])[0]
        tag = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + ln]
        pos += 12 + ln
        if tag == b"IHDR":
            w, h, bit, ctype, _comp, _filt, inter = struct.unpack(">IIBBBBB", chunk)
            if bit != 8 or inter != 0:
                raise ValueError(f"{path}: 지원 안 함 (bit={bit}, interlace={inter})")
        elif tag == b"PLTE":
            palette = chunk
        elif tag == b"tRNS":
            trns = chunk
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    raw = zlib.decompress(idat)
    nch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = w * nch
    px = bytearray(w * h * 4)
    prev = bytearray(stride)
    rp = 0
    for y in range(h):
        f = raw[rp]
        rp += 1
        line = bytearray(raw[rp : rp + stride])
        rp += stride
        if f == 1:
            for i in range(nch, stride):
                line[i] = (line[i] + line[i - nch]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                b = prev[i]
                c = prev[i - nch] if i >= nch else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        o = y * w * 4
        if ctype == 6:
            px[o : o + w * 4] = line
        elif ctype == 2:
            for x in range(w):
                px[o + x * 4 : o + x * 4 + 3] = line[x * 3 : x * 3 + 3]
                px[o + x * 4 + 3] = 255
        elif ctype == 0:
            for x in range(w):
                g = line[x]
                px[o + x * 4 : o + x * 4 + 4] = bytes((g, g, g, 255))
        elif ctype == 4:
            for x in range(w):
                g = line[x * 2]
                px[o + x * 4 : o + x * 4 + 4] = bytes((g, g, g, line[x * 2 + 1]))
        elif ctype == 3:
            for x in range(w):
                idx = line[x]
                px[o + x * 4 : o + x * 4 + 3] = palette[idx * 3 : idx * 3 + 3]
                px[o + x * 4 + 3] = trns[idx] if idx < len(trns) else 255
        prev = line
    return w, h, px


def write_png(path: str, w: int, h: int, px: bytearray) -> None:
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += px[y * w * 4 : (y + 1) * w * 4]

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(png)


# ── 배경 제거 ────────────────────────────────────────────────


def remove_background(w: int, h: int, px: bytearray) -> None:
    """진짜 알파가 있으면 0/255 양자화만, 없으면 테두리 플러드필로 배경 제거."""
    has_alpha = False
    for i in range(3, len(px), 4):
        if px[i] < 250:
            has_alpha = True
            break
    if has_alpha:
        for i in range(3, len(px), 4):
            px[i] = 0 if px[i] < 128 else 255
        return

    # 테두리 대표색 팔레트 (양자화 /16)
    seeds: set[tuple[int, int, int]] = set()
    border: list[int] = []
    for x in range(w):
        border.append(x)
        border.append((h - 1) * w + x)
    for y in range(h):
        border.append(y * w)
        border.append(y * w + w - 1)
    for p in border:
        seeds.add((px[p * 4] >> 4, px[p * 4 + 1] >> 4, px[p * 4 + 2] >> 4))

    def near_seed(p: int) -> bool:
        q = (px[p * 4] >> 4, px[p * 4 + 1] >> 4, px[p * 4 + 2] >> 4)
        for s in seeds:
            if abs(q[0] - s[0]) <= 1 and abs(q[1] - s[1]) <= 1 and abs(q[2] - s[2]) <= 1:
                return True
        return False

    visited = bytearray(w * h)
    queue: deque[int] = deque()
    for p in border:
        if not visited[p]:
            visited[p] = 1
            queue.append(p)
    while queue:
        p = queue.popleft()
        py, pxx = divmod(p, w)
        for n in (p - 1, p + 1, p - w, p + w):
            if n < 0 or n >= w * h or visited[n]:
                continue
            ny, nx = divmod(n, w)
            if abs(ny - py) + abs(nx - pxx) != 1:
                continue  # 행 경계 넘김 방지
            # 점진 변화(그라데이션·글로) 추종 또는 대표색 근접(체커보드)
            step = max(
                abs(px[n * 4] - px[p * 4]),
                abs(px[n * 4 + 1] - px[p * 4 + 1]),
                abs(px[n * 4 + 2] - px[p * 4 + 2]),
            )
            if step <= 12 or near_seed(n):
                visited[n] = 1
                queue.append(n)
    for p in range(w * h):
        px[p * 4 + 3] = 0 if visited[p] else 255


# ── 다운스케일 ───────────────────────────────────────────────


def _median(vals: list[int]) -> int:
    vals.sort()
    return vals[len(vals) // 2]


def downscale(
    w: int,
    h: int,
    px: bytearray,
    bbox: tuple[int, int, int, int],
    tw: int,
    th: int,
    force_opaque: bool = False,
) -> bytearray:
    """bbox 영역을 tw×th로 블록 중앙값 다운스케일한다."""
    x0, y0, x1, y1 = bbox
    bw, bh = x1 - x0, y1 - y0
    out = bytearray(tw * th * 4)
    for oy in range(th):
        sy0 = y0 + bh * oy // th
        sy1 = max(sy0 + 1, y0 + bh * (oy + 1) // th)
        for ox in range(tw):
            sx0 = x0 + bw * ox // tw
            sx1 = max(sx0 + 1, x0 + bw * (ox + 1) // tw)
            # 가장자리 번짐을 줄이기 위해 중앙 60%만 표집
            mx = (sx1 - sx0) // 5
            my = (sy1 - sy0) // 5
            cx0, cx1 = sx0 + mx, max(sx0 + mx + 1, sx1 - mx)
            cy0, cy1 = sy0 + my, max(sy0 + my + 1, sy1 - my)
            rs: list[int] = []
            gs: list[int] = []
            bs: list[int] = []
            total = 0
            opaque = 0
            for sy in range(cy0, cy1):
                row = sy * w
                for sx in range(cx0, cx1):
                    total += 1
                    p = (row + sx) * 4
                    if px[p + 3] >= 128:
                        opaque += 1
                        rs.append(px[p])
                        gs.append(px[p + 1])
                        bs.append(px[p + 2])
            o = (oy * tw + ox) * 4
            if force_opaque or (opaque * 2 >= total and opaque > 0):
                out[o] = _median(rs) if rs else 0
                out[o + 1] = _median(gs) if gs else 0
                out[o + 2] = _median(bs) if bs else 0
                out[o + 3] = 255
            else:
                out[o + 3] = 0
    return out


def content_bbox(w: int, h: int, px: bytearray) -> tuple[int, int, int, int]:
    x0, y0, x1, y1 = w, h, 0, 0
    for y in range(h):
        row = y * w
        for x in range(w):
            if px[(row + x) * 4 + 3] >= 128:
                if x < x0:
                    x0 = x
                if x > x1:
                    x1 = x
                if y < y0:
                    y0 = y
                if y > y1:
                    y1 = y
    if x0 > x1:
        raise ValueError("내용 없음 (전부 투명)")
    return x0, y0, x1 + 1, y1 + 1


def paste(dst: bytearray, dw: int, src: bytearray, sw: int, sh: int, ox: int, oy: int) -> None:
    for y in range(sh):
        for x in range(sw):
            s = (y * sw + x) * 4
            if src[s + 3] >= 128:
                d = ((oy + y) * dw + (ox + x)) * 4
                dst[d : d + 4] = src[s : s + 4]


def fit_sprite(
    w: int, h: int, px: bytearray, tw: int, th: int, anchor: str = "center", pad: int = 1
) -> bytearray:
    """배경 제거된 이미지의 내용을 tw×th 안에 비율 유지로 맞춘다.

    anchor "fill_bottom": 가로를 tw에 정확히 채우고 바닥에 붙인다
    (설비처럼 옆 타일과 이어져야 하는 오브젝트용 — 틈 방지).
    """
    bbox = content_bbox(w, h, px)
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    if anchor == "fill_bottom":
        # 옆 타일과 이어지도록 가로를 정확히 채운다 (세로는 필요 시 살짝 압축)
        ow = tw
        oh = min(th, max(1, round(bh * tw / bw)))
    else:
        scale = min((tw - pad * 2) / bw, (th - pad * 2) / bh)
        ow = max(1, round(bw * scale))
        oh = max(1, round(bh * scale))
    small = downscale(w, h, px, bbox, ow, oh)
    out = bytearray(tw * th * 4)
    ox = (tw - ow) // 2
    if anchor == "center":
        oy = (th - oh) // 2
    elif anchor == "fill_bottom":
        oy = th - oh
    else:
        oy = th - pad - oh
    paste(out, tw, small, ow, oh, ox, oy)
    return out


# ── 캐릭터 시트 ──────────────────────────────────────────────


def split_figures(w: int, h: int, px: bytearray) -> list[tuple[int, int, int, int]]:
    """세로 투영으로 프레임 bbox 목록을 얻는다."""
    col = [0] * w
    for y in range(h):
        row = y * w
        for x in range(w):
            if px[(row + x) * 4 + 3] >= 128:
                col[x] += 1
    groups: list[tuple[int, int]] = []
    in_run = False
    start = 0
    gap = 0
    for x in range(w):
        if col[x] > 0:
            if not in_run:
                in_run = True
                start = x
            gap = 0
        elif in_run:
            gap += 1
            if gap >= 8:
                groups.append((start, x - gap + 1))
                in_run = False
    if in_run:
        groups.append((start, w))
    groups = [g for g in groups if g[1] - g[0] >= 20]
    boxes = []
    for gx0, gx1 in groups:
        y0, y1 = h, 0
        for y in range(h):
            row = y * w
            for x in range(gx0, gx1):
                if px[(row + x) * 4 + 3] >= 128:
                    if y < y0:
                        y0 = y
                    if y > y1:
                        y1 = y
                    break
            else:
                continue
        boxes.append((gx0, y0, gx1, y1 + 1))
    return boxes


def _facing_left(w: int, px: bytearray, bbox: tuple[int, int, int, int]) -> bool:
    """머리 영역 피부색 중심으로 옆모습 방향 판정."""
    x0, y0, x1, y1 = bbox
    head_y1 = y0 + (y1 - y0) * 2 // 5
    sx = n = 0
    for y in range(y0, head_y1):
        row = y * w
        for x in range(x0, x1):
            p = (row + x) * 4
            r, g, b, a = px[p], px[p + 1], px[p + 2], px[p + 3]
            if a >= 128 and r > 200 and 140 < g < 225 and 110 < b < 205 and r > g > b:
                sx += x
                n += 1
    if n == 0:
        return True
    return sx / n < (x0 + x1) / 2


def _flip(src: bytearray, sw: int, sh: int) -> bytearray:
    out = bytearray(sw * sh * 4)
    for y in range(sh):
        for x in range(sw):
            s = (y * sw + x) * 4
            d = (y * sw + (sw - 1 - x)) * 4
            out[d : d + 4] = src[s : s + 4]
    return out


def process_sheet(w: int, h: int, px: bytearray) -> bytearray:
    """다양한 배치의 시트를 256×32 (아래01·위01·왼01·오01) 시트로 재조립한다."""
    boxes = split_figures(w, h, px)
    if len(boxes) == 9:
        boxes.pop(4)  # 정면/측면 사이 중복 프레임 제거
    if len(boxes) != 8:
        raise ValueError(f"프레임 수 {len(boxes)} (8 필요)")
    max_h = max(b[3] - b[1] for b in boxes)
    scale = 30.0 / max_h
    frames: list[bytearray] = []
    sizes: list[tuple[int, int]] = []
    for b in boxes:
        bw, bh = b[2] - b[0], b[3] - b[1]
        ow = max(1, round(bw * scale))
        oh = max(1, round(bh * scale))
        frames.append(downscale(w, h, px, b, ow, oh))
        sizes.append((ow, oh))
    # 측면 프레임(4~7): 첫 두 개를 왼쪽 기준으로 정규화, 나머지는 미러
    left0, left1 = frames[4], frames[5]
    ls0, ls1 = sizes[4], sizes[5]
    if not _facing_left(w, px, boxes[4]):
        left0 = _flip(left0, *ls0)
        left1 = _flip(left1, *ls1)
    order = [
        (frames[0], sizes[0]),
        (frames[1], sizes[1]),
        (frames[2], sizes[2]),
        (frames[3], sizes[3]),
        (left0, ls0),
        (left1, ls1),
        (_flip(left0, *ls0), ls0),
        (_flip(left1, *ls1), ls1),
    ]
    sheet = bytearray(256 * 32 * 4)
    for i, (frame, (fw, fh)) in enumerate(order):
        ox = i * 32 + (32 - fw) // 2
        oy = 31 - fh
        paste(sheet, 256, frame, fw, fh, ox, oy)
    return sheet


# ── 파일별 규격 ──────────────────────────────────────────────

# (종류, 목표w, 목표h, 앵커)
SPECS: dict[str, tuple[str, int, int, str]] = {
    "tile_floor_wood.png": ("tile", 32, 32, ""),
    "tile_floor_wood_alt.png": ("tile", 32, 32, ""),
    "tile_wall_face.png": ("tile", 32, 32, ""),
    "tile_wall_top.png": ("tile", 32, 32, ""),
    "station_counter.png": ("sprite", 32, 32, "fill_bottom"),
    "station_cutting_board.png": ("sprite", 32, 32, "fill_bottom"),
    "station_breading_table.png": ("sprite", 32, 32, "fill_bottom"),
    "station_sauce_table.png": ("sprite", 32, 32, "fill_bottom"),
    "station_spicy_table.png": ("sprite", 32, 32, "fill_bottom"),
    "station_soy_table.png": ("sprite", 32, 32, "fill_bottom"),
    "station_garlic_table.png": ("sprite", 32, 32, "fill_bottom"),
    "station_fryer.png": ("sprite", 32, 32, "fill_bottom"),
    "station_fridge.png": ("sprite", 32, 32, "bottom"),  # 단독 배치 — 비율 유지
    "station_ingredient_box.png": ("sprite", 32, 32, "fill_bottom"),
    "station_submit.png": ("sprite", 32, 32, "fill_bottom"),
    "item_raw_chicken.png": ("sprite", 16, 16, "center"),
    "item_cut_chicken.png": ("sprite", 16, 16, "center"),
    "item_breaded_chicken.png": ("sprite", 16, 16, "center"),
    "item_dakgangjeong.png": ("sprite", 16, 16, "center"),
    "item_sweet_dakgangjeong.png": ("sprite", 16, 16, "center"),
    "item_spicy_dakgangjeong.png": ("sprite", 16, 16, "center"),
    "item_soy_dakgangjeong.png": ("sprite", 16, 16, "center"),
    "item_garlic_dakgangjeong.png": ("sprite", 16, 16, "center"),
    "item_burnt_food.png": ("sprite", 16, 16, "center"),
    "ui_slot.png": ("sprite", 20, 20, "center"),
    "ui_panel.png": ("stretch", 24, 24, ""),
    "ui_button.png": ("stretch", 48, 16, ""),
    "ui_icon_store.png": ("sprite", 16, 16, "center"),
    "ui_icon_staff.png": ("sprite", 16, 16, "center"),
    "ui_icon_manage.png": ("sprite", 16, 16, "center"),
    "ui_icon_character.png": ("sprite", 16, 16, "center"),
    "ui_icon_research.png": ("sprite", 16, 16, "center"),
    "ui_icon_map.png": ("sprite", 16, 16, "center"),
    "ui_icon_settings.png": ("sprite", 16, 16, "center"),
    "ui_icon_close.png": ("sprite", 12, 12, "center"),
    "character_portrait_mint.png": ("sprite", 80, 80, "center"),
    "character_portrait_apricot.png": ("sprite", 80, 80, "center"),
    "character_portrait_basil.png": ("sprite", 80, 80, "center"),
    "title_background.png": ("tile", 640, 360, ""),
    "decor_plant.png": ("sprite", 32, 32, "bottom"),
    "decor_lamp.png": ("sprite", 32, 32, "center"),
    "decor_menu_board.png": ("sprite", 32, 32, "center"),
    "decor_table.png": ("sprite", 32, 32, "bottom"),
    "decor_chair.png": ("sprite", 32, 32, "bottom"),
    "decor_rug.png": ("sprite", 32, 32, "center"),
    "player_mint.png": ("sheet", 256, 32, ""),
    "player_apricot.png": ("sheet", 256, 32, ""),
    "player_basil.png": ("sheet", 256, 32, ""),
    "player_employee.png": ("sheet", 256, 32, ""),
}


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    only = os.environ.get("ONLY", "")
    failed = []
    for name, (kind, tw, th, anchor) in SPECS.items():
        src = os.path.join(src_dir, name)
        if not os.path.exists(src) or (only and name not in only):
            continue
        try:
            w, h, px = read_png(src)
            if kind == "tile":
                out = downscale(w, h, px, (0, 0, w, h), tw, th, force_opaque=True)
            elif kind == "sheet":
                remove_background(w, h, px)
                out = process_sheet(w, h, px)
            elif kind == "stretch":
                remove_background(w, h, px)
                out = downscale(w, h, px, content_bbox(w, h, px), tw, th)
            else:
                remove_background(w, h, px)
                out = fit_sprite(w, h, px, tw, th, anchor)
            write_png(os.path.join(out_dir, name), tw, th, out)
            print(f"OK   {name} → {tw}×{th}")
        except Exception as exc:  # noqa: BLE001 — 파일별 계속 진행
            failed.append(name)
            print(f"FAIL {name}: {exc}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
