#!/usr/bin/env python3
"""Contrast and CVD checks for WU canon review proofs."""
from __future__ import annotations

import argparse
import itertools
import math
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

from palette_audit import default_palette_path, load_palette, parse_hex, rgb_to_hex


BANDS = {
    "foothill": ["#f49e4c", "#df7126", "#ee9c24", "#f8c83c", "#4e8339", "#2c4a2e", "#c6b7be", "#faf6f6"],
    "mid": ["#c6b7be", "#96b2c5", "#565a75", "#577399", "#20394f", "#ab5236"],
    "high": ["#20394f", "#255674", "#577399", "#96b2c5", "#6b3e75", "#905ea9", "#a884f3", "#565a75"],
    "gate": ["#0f0f1b", "#3b1725", "#74233c", "#73172d", "#565a75", "#20394f", "#bf2652"],
}

DEFAULT_CVD_SETS = {
    "schools": {
        "Bear iron": "#96b2c5",
        "Ox thunder": "#a1d2e0",
        "Crane soft": "#f8c83c",
        "Swallow wind": "#255674",
        "Snake venom": "#4e8339",
        "Eagle sword": "#ee9c24",
    },
    "rarity": {
        "common": "#96b2c5",
        "rare": "#a1d2e0",
        "epic": "#a884f3",
        "legendary": "#f8c83c",
    },
    "threat": {
        "perilous": "#b4202a",
        "parryable": "#f8c83c",
        "deflect": "#faf6f6",
        "posture": "#ee9c24",
        "hp": "#b4202a",
        "heal": "#4e8339",
    },
}

PROTANOPIA = (
    (0.56667, 0.43333, 0.0),
    (0.55833, 0.44167, 0.0),
    (0.0, 0.24167, 0.75833),
)
DEUTERANOPIA = (
    (0.625, 0.375, 0.0),
    (0.7, 0.3, 0.0),
    (0.0, 0.3, 0.7),
)


def luminance(rgb: tuple[int, int, int]) -> float:
    def channel(value: int) -> float:
        v = value / 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

    red, green, blue = rgb
    return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)


def palette_ranks(palette: set[tuple[int, int, int]]) -> dict[tuple[int, int, int], int]:
    ordered = sorted(palette, key=luminance)
    return {color: index for index, color in enumerate(ordered)}


def nearest_palette_color(rgb: tuple[int, int, int], palette: set[tuple[int, int, int]]) -> tuple[int, int, int]:
    return min(palette, key=lambda color: sum((a - b) ** 2 for a, b in zip(rgb, color)))


def edge_colors(path: Path) -> Counter[tuple[int, int, int]]:
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    colors: Counter[tuple[int, int, int]] = Counter()
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            is_edge = x == 0 or y == 0 or x == width - 1 or y == height - 1
            if not is_edge:
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if pixels[nx, ny][3] == 0:
                        is_edge = True
                        break
            if is_edge:
                colors[(red, green, blue)] += 1
    return colors


def audit_contrast(path: Path, band: str, palette: set[tuple[int, int, int]], min_steps: int) -> bool:
    ranks = palette_ranks(palette)
    band_colors = [parse_hex(color) for color in BANDS[band]]
    colors = edge_colors(path)
    if not colors:
        print(f"{path}: FAIL no visible edge pixels")
        return False

    closest: tuple[int, tuple[int, int, int], tuple[int, int, int], int] | None = None
    failed = False
    for color, count in colors.items():
        ranked_color = nearest_palette_color(color, palette)
        for band_color in band_colors:
            steps = abs(ranks[ranked_color] - ranks[band_color])
            candidate = (steps, ranked_color, band_color, count)
            if closest is None or candidate[0] < closest[0]:
                closest = candidate
            if steps < min_steps:
                failed = True

    assert closest is not None
    verdict = "FAIL" if failed else "OK"
    print(
        f"{path}: {verdict} band={band} min_steps={min_steps} "
        f"closest={rgb_to_hex(closest[1])}->{rgb_to_hex(closest[2])} steps={closest[0]} count={closest[3]}"
    )
    return not failed


def simulate(rgb: tuple[int, int, int], matrix: tuple[tuple[float, float, float], ...]) -> tuple[int, int, int]:
    values = []
    for row in matrix:
        value = row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2]
        values.append(max(0, min(255, round(value))))
    return (values[0], values[1], values[2])


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def parse_named_colors(values: list[str]) -> dict[str, tuple[int, int, int]]:
    colors: dict[str, tuple[int, int, int]] = {}
    for index, value in enumerate(values, start=1):
        if "=" in value:
            label, color = value.split("=", 1)
        else:
            label, color = f"color_{index}", value
        colors[label] = parse_hex(color)
    return colors


def audit_cvd_set(name: str, colors: dict[str, tuple[int, int, int]], threshold: float) -> bool:
    ok = True
    for mode, matrix in (("protan", PROTANOPIA), ("deutan", DEUTERANOPIA)):
        transformed = {label: simulate(color, matrix) for label, color in colors.items()}
        closest: tuple[float, str, str] | None = None
        for left, right in itertools.combinations(sorted(transformed), 2):
            dist = distance(transformed[left], transformed[right])
            if closest is None or dist < closest[0]:
                closest = (dist, left, right)
            if dist < threshold and colors[left] != colors[right]:
                ok = False
        if closest is None:
            print(f"{name} {mode}: SKIP fewer than two colors")
        else:
            verdict = "OK" if closest[0] >= threshold else "WARN"
            print(f"{name} {mode}: {verdict} closest={closest[1]} vs {closest[2]} distance={closest[0]:.1f}")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contrast", type=Path, help="Silhouette/runtime proof image to check against a band")
    parser.add_argument("--band", choices=sorted(BANDS))
    parser.add_argument("--min-steps", type=int, default=2)
    parser.add_argument("--palette", type=Path, default=default_palette_path())
    parser.add_argument(
        "--cvd",
        nargs="*",
        metavar="LABEL=#RRGGBB",
        help="Run protan/deutan checks. With no colors, audits built-in school, rarity, and threat sets.",
    )
    parser.add_argument("--cvd-threshold", type=float, default=18.0)
    args = parser.parse_args()

    if args.contrast is None and args.cvd is None:
        parser.error("provide --contrast, --cvd, or both")
    if args.contrast is not None and not args.band:
        parser.error("--contrast requires --band")

    palette = load_palette(args.palette)
    ok = True
    if args.contrast is not None:
        ok = audit_contrast(args.contrast, args.band, palette, args.min_steps) and ok
    if args.cvd is not None:
        if args.cvd:
            ok = audit_cvd_set("custom", parse_named_colors(args.cvd), args.cvd_threshold) and ok
        else:
            for set_name, raw_colors in DEFAULT_CVD_SETS.items():
                colors = {label: parse_hex(hex_value) for label, hex_value in raw_colors.items()}
                ok = audit_cvd_set(set_name, colors, args.cvd_threshold) and ok

    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(exc, file=sys.stderr)
        raise SystemExit(2)
