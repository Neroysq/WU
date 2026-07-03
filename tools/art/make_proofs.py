#!/usr/bin/env python3
"""Build derived proof images for WU canon art review."""
from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path

from PIL import Image


PANEL_BG = (15, 15, 27, 255)
CHECKER_A = "#2a2a3e"
CHECKER_B = "#333348"


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def profile_scale(profile_id: str) -> float:
    path = repo_root() / "WUGodot" / "data" / "VisualProfiles" / "DefaultProfiles.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    for profile in data.get("profiles", []):
        if profile.get("id") == profile_id:
            return float(profile["scale"])
    raise ValueError(f"profile {profile_id!r} not found in {path}")


def resize_nearest(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.resize(size, Image.Resampling.NEAREST)


def scale_nearest(image: Image.Image, scale: float) -> Image.Image:
    width = max(1, round(image.width * scale))
    height = max(1, round(image.height * scale))
    return resize_nearest(image, (width, height))


def silhouette(image: Image.Image) -> Image.Image:
    src = image.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 255))
    alpha = src.getchannel("A").point(lambda value: 255 if value else 0)
    out.putalpha(alpha)
    return out


def rel_url(path: Path, base: Path) -> str:
    return Path(os.path.relpath(path, base)).as_posix()


def figure(src: Path, caption: str, base: Path) -> str:
    return (
        "<figure>"
        f'<img src="{html.escape(rel_url(src, base), quote=True)}">'
        f"<figcaption>{html.escape(caption)}</figcaption>"
        "</figure>"
    )


def write_review(out_dir: Path, title: str, figures: list[tuple[Path, str]], note: str) -> None:
    body = "".join(figure(path, caption, out_dir) for path, caption in figures)
    out = out_dir / "review.html"
    out.write_text(
        f"""<!doctype html><meta charset=utf-8>
<title>{html.escape(title)}</title>
<style>
 body {{ background:#0f0f1b; color:#faf6f6; font-family:monospace; padding:24px }}
 .row {{ display:flex; flex-wrap:wrap; gap:20px; align-items:flex-start }}
 figure {{ margin:0; text-align:center }}
 img {{ image-rendering:pixelated; background:
       repeating-conic-gradient({CHECKER_A} 0% 25%, {CHECKER_B} 0% 50%) 0 0/24px 24px;
       border:1px solid #565a75; max-width:100%; height:auto }}
 figcaption {{ margin-top:8px; color:#c6b7be }}
 p {{ max-width:920px; line-height:1.45 }}
</style>
<h1>{html.escape(title)}</h1>
<p>{html.escape(note)}</p>
<div class=row>{body}</div>
""",
        encoding="utf-8",
    )


def make_char_proof(source: Path, out_dir: Path, scale: float) -> None:
    src = Image.open(source).convert("RGBA")
    runtime = scale_nearest(src, scale)
    sil = scale_nearest(silhouette(src), scale)
    runtime_path = out_dir / "runtime.png"
    silhouette_path = out_dir / "silhouette.png"
    runtime.save(runtime_path)
    sil.save(silhouette_path)
    write_review(
        out_dir,
        f"{source.name} character proof",
        [(source.resolve(), "source"), (runtime_path, f"runtime scale x{scale:g}"), (silhouette_path, "pure-black silhouette at runtime scale")],
        "Judge readability at runtime scale. The silhouette proof is deliberately harsh.",
    )


def parse_grid(grid: str) -> tuple[int, int]:
    try:
        cols_s, rows_s = grid.lower().split("x", 1)
        cols, rows = int(cols_s), int(rows_s)
    except ValueError as exc:
        raise ValueError(f"--grid must look like 6x1 or 3x2, got {grid!r}") from exc
    if cols <= 0 or rows <= 0:
        raise ValueError("--grid dimensions must be positive")
    return cols, rows


def make_icon_proof(source: Path, out_dir: Path, grid: str) -> None:
    src = Image.open(source).convert("RGBA")
    cols, rows = parse_grid(grid)
    cell_w = src.width // cols
    cell_h = src.height // rows
    if cell_w <= 0 or cell_h <= 0:
        raise ValueError(f"{source}: {src.size} too small for grid {grid}")

    cells: list[Image.Image] = []
    for row in range(rows):
        for col in range(cols):
            left = col * cell_w
            top = row * cell_h
            right = src.width if col == cols - 1 else (col + 1) * cell_w
            bottom = src.height if row == rows - 1 else (row + 1) * cell_h
            cell = src.crop((left, top, right, bottom))
            bbox = cell.getbbox()
            if bbox:
                cell = cell.crop(bbox)
            cells.append(cell)

    count = len(cells)
    pad = 8
    gap = 8
    out = Image.new("RGBA", (count * 24 + (count + 1) * gap, 24 + pad * 2), PANEL_BG)
    for index, cell in enumerate(cells):
        icon = resize_nearest(cell, (24, 24))
        out.alpha_composite(icon, (gap + index * (24 + gap), pad))

    out_path = out_dir / "24px.png"
    out.save(out_path)
    write_review(
        out_dir,
        f"{source.name} icon proof",
        [(source.resolve(), "source sheet"), (out_path, "24px row on panel background")],
        f"Grid {grid} cells (transparent borders trimmed) nearest-neighbor scaled to 24x24.",
    )


def make_scene_proof(source: Path, out_dir: Path, scene_width: int) -> None:
    src = Image.open(source).convert("RGBA")
    if scene_width <= 0:
        raise ValueError("--scene-width must be positive")
    height = max(1, round(src.height * scene_width / src.width))
    runtime = resize_nearest(src, (scene_width, height))
    out_path = out_dir / "runtime.png"
    runtime.save(out_path)
    write_review(
        out_dir,
        f"{source.name} scene proof",
        [(source.resolve(), "source"), (out_path, f"fit to {scene_width}px combat width")],
        "Scene proof fits the sheet to the current 1920-wide arena proportion.",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--kind", choices=("char", "icon", "scene"), required=True)
    parser.add_argument("--profile", help="Visual profile id for --kind char")
    parser.add_argument("--scale", type=float, help="Explicit scale override for --kind char")
    parser.add_argument("--grid", default="6x1", help="Icon sheet grid as COLSxROWS (e.g. 6x1, 3x2) for --kind icon")
    parser.add_argument("--scene-width", type=int, default=1920)
    args = parser.parse_args()

    source = args.source.resolve()
    out_dir = (args.out or source.with_suffix("")).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.kind == "char":
        if args.scale is None and not args.profile:
            parser.error("--kind char requires --profile or --scale")
        scale = args.scale if args.scale is not None else profile_scale(args.profile)
        make_char_proof(source, out_dir, scale)
    elif args.kind == "icon":
        make_icon_proof(source, out_dir, args.grid)
    else:
        make_scene_proof(source, out_dir, args.scene_width)

    print(f"wrote proof assets to {out_dir}")
    print(f"review: {out_dir / 'review.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
