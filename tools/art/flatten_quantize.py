#!/usr/bin/env python3
"""Flatten-then-quantize: palette mapping without per-pixel fractioning.

Per-pixel nearest-palette mapping turns smooth gradients into salt-and-pepper
speckle. This tool clusters the image into N flat color regions FIRST
(median-cut), then maps each region's centroid to its nearest palette color,
so every region lands on ONE palette color. A mode-filter pass eats stragglers.

Usage:
  flatten_quantize.py IN.png OUT.png [--size 256] [--colors 14]
                      [--palette tools/art/vinik24.json] [--chroma HEX]
                      [--mode-passes 1] [--bbox-height 205]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageFilter


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_palette(path: Path) -> list[tuple[int, int, int]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    colors = data["colors"] if isinstance(data, dict) else data
    out = []
    for c in colors:
        h = c.lstrip("#")
        out.append(tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)))
    return out


def nearest(c: tuple[int, int, int], palette: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    return min(palette, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def chroma_key(img: Image.Image, hex_color: str, tol: int = 60) -> Image.Image:
    img = img.convert("RGBA")
    h = hex_color.lstrip("#")
    kr, kg, kb = (int(h[i : i + 2], 16) for i in (0, 2, 4))
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if abs(r - kr) < tol and abs(g - kg) < tol and abs(b - kb) < tol:
                px[x, y] = (0, 0, 0, 0)
    return img


def flatten_quantize(
    src: Image.Image,
    palette: list[tuple[int, int, int]],
    size: int,
    colors: int,
    mode_passes: int,
    bbox_height: int,
) -> Image.Image:
    src = src.convert("RGBA")
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    scale = bbox_height / src.height
    small = src.resize(
        (max(1, round(src.width * scale)), bbox_height), Image.Resampling.LANCZOS
    )

    rgb = Image.new("RGB", small.size, (255, 0, 255))
    rgb.paste(small, mask=small.getchannel("A"))
    clustered = rgb.quantize(colors=colors + 1, method=Image.Quantize.MEDIANCUT).convert("RGB")

    cluster_colors = sorted(set(clustered.getdata()))
    remap = {c: nearest(c, palette) for c in cluster_colors}

    out = Image.new("RGBA", small.size, (0, 0, 0, 0))
    po, pc, pa = out.load(), clustered.load(), small.getchannel("A").load()
    for y in range(small.height):
        for x in range(small.width):
            if pa[x, y] >= 128:
                n = remap[pc[x, y]]
                po[x, y] = (n[0], n[1], n[2], 255)

    for _ in range(mode_passes):
        alpha = out.getchannel("A")
        filtered = out.convert("RGB").filter(ImageFilter.ModeFilter(3))
        merged = Image.new("RGBA", out.size, (0, 0, 0, 0))
        merged.paste(filtered, mask=alpha)
        # re-snap: mode filter can average—force back onto palette
        pm, pal2 = merged.load(), {}
        for y in range(merged.height):
            for x in range(merged.width):
                r, g, b, a = pm[x, y]
                if a:
                    key = (r, g, b)
                    if key not in pal2:
                        pal2[key] = nearest(key, palette)
                    n = pal2[key]
                    pm[x, y] = (n[0], n[1], n[2], 255)
        out = merged

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(out, ((size - out.width) // 2, size - out.height - 10))
    return canvas


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("src", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--colors", type=int, default=14, help="flat regions before palette mapping")
    ap.add_argument("--palette", type=Path, default=repo_root() / "tools" / "art" / "vinik24.json")
    ap.add_argument("--chroma", help="chroma-key hex to strip (e.g. '#FFFF00')")
    ap.add_argument("--mode-passes", type=int, default=1)
    ap.add_argument("--bbox-height", type=int, default=205)
    ap.add_argument("--remap", nargs="*", default=[],
                    help="post palette-substitutions as FROMHEX:TOHEX pairs (e.g. '#ee9c24:#c6b7be')")
    ap.add_argument("--remap-box", help="scope --remap to x0,y0,x1,y1 (output-canvas coords)")
    args = ap.parse_args()

    img = Image.open(args.src)
    if args.chroma:
        img = chroma_key(img, args.chroma)
    palette = load_palette(args.palette)
    result = flatten_quantize(img, palette, args.size, args.colors, args.mode_passes, args.bbox_height)
    if args.remap:
        def h2rgb(h):
            h = h.lstrip("#")
            return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))
        table = {h2rgb(a): h2rgb(b) for a, b in (pair.split(":") for pair in args.remap)}
        if args.remap_box:
            bx0, by0, bx1, by1 = (int(v) for v in args.remap_box.split(","))
        else:
            bx0, by0, bx1, by1 = 0, 0, result.width, result.height
        pr = result.load()
        for y in range(by0, min(by1, result.height)):
            for x in range(bx0, min(bx1, result.width)):
                r, g, b, a = pr[x, y]
                if a and (r, g, b) in table:
                    n = table[(r, g, b)]
                    pr[x, y] = (n[0], n[1], n[2], 255)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.out)
    print(f"wrote {args.out} ({result.size[0]}x{result.size[1]}, {args.colors} regions)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
