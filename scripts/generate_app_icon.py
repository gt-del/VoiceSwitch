#!/usr/bin/env python3
import math
import struct
import zlib
from pathlib import Path


REPO_DIR = Path(__file__).resolve().parents[1]
ICONSET_DIR = REPO_DIR / "Assets" / "AppIcon.iconset"


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        start = y * stride
        raw.extend(pixels[start:start + stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def rounded_rect_alpha(x: float, y: float, left: float, top: float, right: float, bottom: float, radius: float) -> float:
    cx = min(max(x, left + radius), right - radius)
    cy = min(max(y, top + radius), bottom - radius)
    distance = math.hypot(x - cx, y - cy)
    return 1.0 if distance <= radius else max(0.0, 1.0 - (distance - radius))


def render_icon(size: int) -> bytes:
    pixels = bytearray(size * size * 4)
    center = size / 2.0

    bg_top = (233, 241, 250)
    bg_bottom = (166, 198, 214)
    chip = (32, 91, 120)
    chip_light = (80, 147, 178)
    accent = (244, 171, 95)
    accent_deep = (214, 112, 56)
    white = (247, 248, 245)

    for y in range(size):
        t = y / max(size - 1, 1)
        br = lerp(bg_top[0], bg_bottom[0], t)
        bg = lerp(bg_top[1], bg_bottom[1], t)
        bb = lerp(bg_top[2], bg_bottom[2], t)
        for x in range(size):
            dx = (x - center) / size
            dy = (y - center) / size
            radial = max(0.0, 1.0 - math.hypot(dx * 1.2, dy * 1.1) * 1.8)
            r = min(255, round(br + 22 * radial))
            g = min(255, round(bg + 18 * radial))
            b = min(255, round(bb + 12 * radial))
            idx = (y * size + x) * 4
            pixels[idx:idx + 4] = bytes((r, g, b, 255))

    # Outer plate
    plate_margin = size * 0.12
    plate_radius = size * 0.18
    for y in range(size):
        for x in range(size):
            alpha = rounded_rect_alpha(
                x + 0.5, y + 0.5,
                plate_margin, plate_margin,
                size - plate_margin, size - plate_margin,
                plate_radius
            )
            if alpha <= 0:
                continue
            idx = (y * size + x) * 4
            base = pixels[idx:idx + 4]
            overlay = tuple(
                min(255, round(c * 0.55 + d * 0.45))
                for c, d in zip(base[:3], chip_light)
            )
            pixels[idx:idx + 4] = bytes((*overlay, 255))

    # Speech capsule
    bubble_left = size * 0.19
    bubble_top = size * 0.22
    bubble_right = size * 0.81
    bubble_bottom = size * 0.58
    bubble_radius = size * 0.16
    for y in range(size):
        for x in range(size):
            alpha = rounded_rect_alpha(
                x + 0.5, y + 0.5,
                bubble_left, bubble_top,
                bubble_right, bubble_bottom,
                bubble_radius
            )
            if alpha <= 0:
                continue
            idx = (y * size + x) * 4
            base = pixels[idx:idx + 4]
            mix = tuple(round(base[i] * (1 - alpha) + white[i] * alpha) for i in range(3))
            pixels[idx:idx + 4] = bytes((*mix, 255))

    # Tail
    tail_points = (
        (size * 0.42, size * 0.58),
        (size * 0.52, size * 0.58),
        (size * 0.38, size * 0.74),
    )
    x1, y1 = tail_points[0]
    x2, y2 = tail_points[1]
    x3, y3 = tail_points[2]
    for y in range(size):
        for x in range(size):
            px = x + 0.5
            py = y + 0.5
            det = ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3))
            if det == 0:
                continue
            a = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / det
            b = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / det
            c = 1 - a - b
            if a >= 0 and b >= 0 and c >= 0:
                idx = (y * size + x) * 4
                pixels[idx:idx + 4] = bytes((*white, 255))

    # Voice bars
    bar_width = size * 0.055
    gap = size * 0.037
    heights = (0.18, 0.28, 0.22)
    start_x = center - (bar_width * 1.5 + gap)
    for i, height in enumerate(heights):
        left = start_x + i * (bar_width + gap)
        right = left + bar_width
        top = size * 0.30 + (size * 0.20 - size * height) / 2
        bottom = top + size * height
        radius = bar_width / 2
        for y in range(size):
            for x in range(size):
                alpha = rounded_rect_alpha(x + 0.5, y + 0.5, left, top, right, bottom, radius)
                if alpha <= 0:
                    continue
                idx = (y * size + x) * 4
                color = accent if i != 1 else accent_deep
                mix = tuple(round(pixels[idx + j] * (1 - alpha) + color[j] * alpha) for j in range(3))
                pixels[idx:idx + 4] = bytes((*mix, 255))

    # Keyboard rail
    rail_left = size * 0.22
    rail_top = size * 0.70
    rail_right = size * 0.78
    rail_bottom = size * 0.80
    rail_radius = size * 0.05
    for y in range(size):
        for x in range(size):
            alpha = rounded_rect_alpha(
                x + 0.5, y + 0.5,
                rail_left, rail_top,
                rail_right, rail_bottom,
                rail_radius
            )
            if alpha <= 0:
                continue
            idx = (y * size + x) * 4
            mix = tuple(round(pixels[idx + j] * (1 - alpha) + chip[j] * alpha) for j in range(3))
            pixels[idx:idx + 4] = bytes((*mix, 255))

    # Keycaps
    key_w = size * 0.075
    key_h = size * 0.032
    key_radius = size * 0.016
    key_y = size * 0.735
    key_positions = [size * 0.28, size * 0.39, size * 0.50, size * 0.61]
    for left in key_positions:
        for y in range(size):
            for x in range(size):
                alpha = rounded_rect_alpha(
                    x + 0.5, y + 0.5,
                    left, key_y,
                    left + key_w, key_y + key_h,
                    key_radius
                )
                if alpha <= 0:
                    continue
                idx = (y * size + x) * 4
                mix = tuple(round(pixels[idx + j] * (1 - alpha) + white[j] * alpha) for j in range(3))
                pixels[idx:idx + 4] = bytes((*mix, 255))

    return bytes(pixels)


def main() -> None:
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in sizes.items():
        write_png(ICONSET_DIR / name, size, size, render_icon(size))


if __name__ == "__main__":
    main()
