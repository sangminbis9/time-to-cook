#!/usr/bin/env python3
"""효과음 생성 (PLAN.md §34): 따뜻하고 작은 생활 소리 — 순수 stdlib WAV 합성.

사용: python3 tools/gen_sfx.py game/assets/audio
과격한 경고음 없이 부드러운 사인·저역 노이즈만 사용. 결정적(고정 시드).
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 22050


def silence(dur: float) -> list:
    return [0.0] * int(SR * dur)


def tone(freq: float, dur: float, amp: float, decay: float = 10.0,
         attack: float = 0.004) -> list:
    """지수 감쇠 사인 톤 — 부드러운 마림바/벨 느낌."""
    n = int(SR * dur)
    out = []
    atk = max(1, int(SR * attack))
    for i in range(n):
        t = i / SR
        e = math.exp(-decay * t) * (min(1.0, i / atk))
        out.append(amp * e * math.sin(2 * math.pi * freq * t))
    return out


def noise(dur: float, amp: float, lp: float = 0.2, seed: int = 7,
          fade_in: float = 0.02, fade_out: float = 0.08) -> list:
    """저역 통과 노이즈 — 지글·문 소리 질감."""
    rng = random.Random(seed)
    n = int(SR * dur)
    out = []
    prev = 0.0
    fi = max(1, int(SR * fade_in))
    fo = max(1, int(SR * fade_out))
    for i in range(n):
        prev += lp * (rng.uniform(-1.0, 1.0) - prev)
        e = min(1.0, i / fi) * min(1.0, (n - i) / fo)
        out.append(amp * e * prev)
    return out


def mix(*parts: tuple) -> list:
    """(샘플 배열, 시작 초) 목록을 겹쳐 합성."""
    total = max(int(SR * at) + len(buf) for buf, at in parts)
    out = [0.0] * total
    for buf, at in parts:
        base = int(SR * at)
        for i, v in enumerate(buf):
            out[base + i] += v
    return out


SOUNDS = {
    # 칼질: 나무 도마 '톡' — 짧은 노이즈 + 저음 두께
    "cut": lambda: mix((noise(0.05, 0.45, lp=0.35, seed=3, fade_out=0.03), 0.0),
                       (tone(190, 0.09, 0.4, decay=35.0), 0.0)),
    # 튀김 투입: 부드러운 지글
    "fry": lambda: mix((noise(0.45, 0.32, lp=0.55, seed=11, fade_in=0.04,
                              fade_out=0.2), 0.0)),
    # 주문 제출·매출: 딩동 (접시·계산대 §34)
    "submit": lambda: mix((tone(659, 0.2, 0.32), 0.0),
                          (tone(523, 0.3, 0.32), 0.14)),
    # 이벤트 해결·조리 완료: 따뜻한 벨
    "ding": lambda: mix((tone(880, 0.4, 0.28, decay=7.0), 0.0),
                        (tone(1760, 0.4, 0.1, decay=9.0), 0.0)),
    # 구매: 동전 틱틱
    "coin": lambda: mix((tone(1319, 0.06, 0.26, decay=30.0), 0.0),
                        (tone(1568, 0.1, 0.26, decay=25.0), 0.07)),
    # 냉장고 문: 낮은 툭 + 짧은 클릭
    "door": lambda: mix((tone(110, 0.13, 0.5, decay=28.0), 0.0),
                        (noise(0.03, 0.18, lp=0.4, seed=5, fade_out=0.02), 0.0)),
    # 실패: 짧고 부드럽게 (§34)
    "fail": lambda: mix((tone(311, 0.12, 0.26, decay=18.0), 0.0),
                        (tone(262, 0.18, 0.26, decay=14.0), 0.1)),
    # 영업 시작·마감 종
    "bell": lambda: mix((tone(523, 0.35, 0.26, decay=6.0), 0.0),
                        (tone(659, 0.35, 0.26, decay=6.0), 0.12),
                        (tone(784, 0.45, 0.26, decay=6.0), 0.24)),
    # 매장 이벤트 발생: 낮은 마림바 두 번 — 공포감 없이 (§34)
    "event": lambda: mix((tone(330, 0.18, 0.32, decay=12.0), 0.0),
                         (tone(294, 0.28, 0.32, decay=10.0), 0.22)),
    # 액티브 스킬: 짧은 상승 아르페지오
    "skill": lambda: mix((tone(523, 0.09, 0.26, decay=20.0), 0.0),
                         (tone(659, 0.09, 0.26, decay=20.0), 0.07),
                         (tone(784, 0.2, 0.26, decay=14.0), 0.14)),
}


def write_wav(path: Path, samples: list) -> None:
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        frames = bytearray()
        for v in samples:
            frames += struct.pack("<h", max(-32767, min(32767, int(v * 32767))))
        f.writeframes(bytes(frames))


def main() -> None:
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "game/assets/audio")
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, gen in SOUNDS.items():
        path = out_dir / f"{name}.wav"
        write_wav(path, gen())
        print(f"{path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
