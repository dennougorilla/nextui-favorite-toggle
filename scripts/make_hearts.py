#!/usr/bin/env python3
"""Draws the pixel-art hearts shown when toggling a favorite (pak/res/heart_*.png)."""

import struct
import zlib
from pathlib import Path

SCALE = 16
SPRITE = [
    "..KKK...KKK..",
    ".KRRRK.KRRRK.",
    "KRWWRRKRRRRDK",
    "KRWRRRRRRRRDK",
    "KRRRRRRRRRRDK",
    ".KRRRRRRRRDK.",
    "..KRRRRRRDK..",
    "...KRRRRDK...",
    "....KRRDK....",
    ".....KDK.....",
    "......K......",
]


def broken_sprite() -> list:
    """The heart split along a zigzag, the right half moved two pixels over so the crack shows as a gap."""
    crack = [6, 6, 7, 7, 6, 5, 5, 6, 7, 7, 7]  # first column of the right half, per row
    cells = {}
    for y, line in enumerate(SPRITE):
        for x, c in enumerate(line):
            if c != ".":
                right = x >= crack[y]
                cells[(x + 2, y) if right else (x, y)] = right
    w, h = len(SPRITE[0]) + 2, len(SPRITE)
    rows = []
    for y in range(h):
        row = ""
        for x in range(w):
            if (x, y) not in cells:
                row += "."
                continue
            half = cells[(x, y)]
            edge = any(cells.get((x + dx, y + dy)) != half for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                row += "K"
            elif not half and 1 <= x <= 2 and 1 <= y <= 3 and (x, y) != (2, 3):
                row += "L"
            elif half and cells.get((x + 2, y)) is not True:
                row += "D"
            else:
                row += "G"
        rows.append(row)
    return rows


BROKEN_SPRITE = broken_sprite()

FULL = {"K": (40, 8, 16, 255), "R": (232, 48, 64, 255), "D": (168, 24, 48, 255), "W": (255, 240, 240, 255)}
EMPTY = {"K": (200, 200, 200, 255), "R": (56, 56, 56, 255), "D": (40, 40, 40, 255), "W": (72, 72, 72, 255)}
BROKEN = {"K": (200, 200, 200, 255), "G": (120, 120, 120, 255), "D": (84, 84, 84, 255), "L": (170, 170, 170, 255)}


def png(path: Path, palette: dict, sprite: list = SPRITE) -> None:
    w, h = len(sprite[0]) * SCALE, len(sprite) * SCALE
    rows = []
    for line in sprite:
        row = b"".join(bytes(palette.get(c, (0, 0, 0, 0))) * SCALE for c in line)
        rows.extend([b"\x00" + row] * SCALE)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


res = Path(__file__).resolve().parent.parent / "pak" / "res"
png(res / "heart_full.png", FULL)
png(res / "heart_empty.png", EMPTY)
png(res / "heart_broken.png", BROKEN, BROKEN_SPRITE)
