#!/usr/bin/env python3
"""Fail if source art uses colors outside the local VINIK24 palette."""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, UnidentifiedImageError


def parse_hex(value: str) -> tuple[int, int, int]:
    text = value.strip()
    if not text.startswith("#") or len(text) != 7:
        raise ValueError(f"expected #rrggbb, got {value!r}")
    return (int(text[1:3], 16), int(text[3:5], 16), int(text[5:7], 16))


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return "#%02x%02x%02x" % rgb


def default_palette_path() -> Path:
    return Path(__file__).resolve().with_name("vinik24.json")


def load_palette(path: Path | None = None) -> set[tuple[int, int, int]]:
    palette_path = path or default_palette_path()
    data = json.loads(palette_path.read_text(encoding="utf-8"))
    raw_colors = data["colors"] if isinstance(data, dict) else data
    return {parse_hex(str(color)) for color in raw_colors}


def audit_image(path: Path, palette: set[tuple[int, int, int]], max_samples: int) -> tuple[int, int, list[tuple[str, int]]]:
    try:
        image = Image.open(path).convert("RGBA")
    except FileNotFoundError:
        raise ValueError(f"{path}: file not found") from None
    except UnidentifiedImageError as exc:
        raise ValueError(f"{path}: not a readable image") from exc

    off_palette: Counter[tuple[int, int, int]] = Counter()
    visible = 0
    raw = image.tobytes()
    for index in range(0, len(raw), 4):
        red, green, blue, alpha = raw[index : index + 4]
        if alpha == 0:
            continue
        visible += 1
        rgb = (red, green, blue)
        if rgb not in palette:
            off_palette[rgb] += 1

    samples = [(rgb_to_hex(rgb), count) for rgb, count in off_palette.most_common(max_samples)]
    return visible, sum(off_palette.values()), samples


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--palette", type=Path, default=default_palette_path())
    parser.add_argument("--max-samples", type=int, default=12)
    args = parser.parse_args()

    try:
        palette = load_palette(args.palette)
    except Exception as exc:
        print(f"palette load failed: {exc}", file=sys.stderr)
        return 2

    failed = False
    for image_path in args.images:
        try:
            visible, off_count, samples = audit_image(image_path, palette, args.max_samples)
        except ValueError as exc:
            print(exc, file=sys.stderr)
            failed = True
            continue

        if off_count:
            failed = True
            sample_text = ", ".join(f"{hex_value} x{count}" for hex_value, count in samples)
            print(f"{image_path}: FAIL {off_count}/{visible} visible pixels off palette ({sample_text})")
        else:
            print(f"{image_path}: OK {visible} visible pixels, 0 off palette")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
