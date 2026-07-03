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


def make_icon_proof(source: Path, out_dir: Path, cells: int) -> None:
    src = Image.open(source).convert("RGBA")
    if cells <= 0:
        raise ValueError("--cells must be positive")
    cell_width = src.width // cells
    if cell_width <= 0:
        raise ValueError(f"{source}: width {src.width} too small for {cells} cells")

    pad = 8
    gap = 8
    out = Image.new("RGBA", (cells * 24 + (cells + 1) * gap, 24 + pad * 2), PANEL_BG)
    for index in range(cells):
        left = index * cell_width
        right = src.width if index == cells - 1 else (index + 1) * cell_width
        icon = resize_nearest(src.crop((left, 0, right, src.height)), (24, 24))
        out.alpha_composite(icon, (gap + index * (24 + gap), pad))

    out_path = out_dir / "24px.png"
    out.save(out_path)
    write_review(
        out_dir,
        f"{source.name} icon proof",
        [(source.resolve(), "source row"), (out_path, "24px row on panel background")],
        "Each equal-width source cell is nearest-neighbor scaled to 24x24.",
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
    parser.add_argument("--cells", type=int, default=6, help="Equal cells for --kind icon")
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
        make_icon_proof(source, out_dir, args.cells)
    else:
        make_scene_proof(source, out_dir, args.scene_width)

    print(f"wrote proof assets to {out_dir}")
    print(f"review: {out_dir / 'review.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
