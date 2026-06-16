#!/usr/bin/env python3
"""Build a self-contained Hu normalization review page."""

from __future__ import annotations

import argparse
import html
from collections import defaultdict
from pathlib import Path
from typing import Any

from hu_normalization_lib import decode_png_alpha, load_json


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--measurements",
        type=Path,
        default=Path("art/masters/hu/normalization/measurements.json"),
    )
    parser.add_argument(
        "--transforms",
        type=Path,
        default=Path("art/masters/hu/normalization/transforms.json"),
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("art/masters/hu/normalization/review/index.html"),
    )
    args = parser.parse_args()

    measurements = load_json(args.measurements)
    transforms_root = load_json(args.transforms)
    transforms = transforms_root.get("transforms", {})
    poses = measurements.get("poses", [])
    if not isinstance(poses, list) or not isinstance(transforms, dict):
        raise ValueError("invalid measurements/transforms shape")

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for pose in poses:
        if isinstance(pose, dict):
            grouped[str(pose.get("prefix", "other"))].append(pose)

    body = []
    flagged = 0
    for prefix in sorted(grouped):
        cards = []
        for pose in grouped[prefix]:
            pose_name = str(pose["pose"])
            transform = transforms.get(pose_name, {})
            flags = transform.get("flags", []) if isinstance(transform, dict) else []
            if flags:
                flagged += 1
            cards.append(card(pose, transform))
        body.append(f"<section><h2>{html.escape(prefix)} <span>{len(cards)} poses</span></h2><div class=grid>{''.join(cards)}</div></section>")

    aliases = measurements.get("aliases", [])
    alias_rows = ""
    if isinstance(aliases, list):
        alias_rows = "".join(
            f"<tr><td>{esc(str(a.get('pose', '')))}</td><td>{esc(str(a.get('sourcePose', '')))}</td><td>{esc(str(a.get('path', '')))}</td></tr>"
            for a in aliases
            if isinstance(a, dict)
        )

    summary = transforms_root.get("summary", {})
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        f"""<!doctype html>
<meta charset=utf-8>
<title>Hu normalization review</title>
<style>
 :root {{ color-scheme: dark; --bg:#14151a; --panel:#20232a; --ink:#ece7dc; --muted:#a9a397; --line:#353a44; --bad:#ff6b62; --ok:#88d18a; --head:#5fd4ff; --foot:#ffd166; }}
 * {{ box-sizing:border-box }}
 body {{ margin:0; background:var(--bg); color:var(--ink); font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; }}
 header {{ position:sticky; top:0; z-index:3; padding:14px 18px; background:#111318f2; border-bottom:1px solid var(--line); }}
 h1 {{ margin:0 0 8px; font-size:18px; font-weight:700 }}
 .summary {{ display:flex; flex-wrap:wrap; gap:10px; color:var(--muted); font-size:12px }}
 .summary b {{ color:var(--ink) }}
 section {{ padding:18px }}
 h2 {{ margin:0 0 12px; font-size:15px; }}
 h2 span {{ color:var(--muted); font-weight:400 }}
 .grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(210px, 1fr)); gap:12px; align-items:start }}
 article {{ background:var(--panel); border:1px solid var(--line); border-radius:6px; overflow:hidden }}
 article.flagged {{ border-color:#7c3f3b }}
 .frame {{ background-color:#181b21; background-image:linear-gradient(45deg,#232832 25%,transparent 25%),linear-gradient(-45deg,#232832 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#232832 75%),linear-gradient(-45deg,transparent 75%,#232832 75%); background-size:20px 20px; background-position:0 0,0 10px,10px -10px,-10px 0; }}
 svg {{ display:block; width:100%; height:auto; image-rendering:pixelated }}
 .meta {{ padding:8px 9px 9px; border-top:1px solid var(--line); font-size:11px; line-height:1.45 }}
 .pose {{ display:flex; justify-content:space-between; gap:8px; margin-bottom:4px; font-size:12px; color:var(--ink) }}
 .path {{ color:var(--muted); overflow:hidden; text-overflow:ellipsis; white-space:nowrap }}
 .flags {{ margin-top:6px; color:var(--bad); white-space:normal }}
 table {{ width:100%; border-collapse:collapse; font-size:12px }}
 th,td {{ text-align:left; border-bottom:1px solid var(--line); padding:6px 8px }}
</style>
<header>
 <h1>Hu Normalization Review</h1>
 <div class=summary>
  <span>poses <b>{esc(str(measurements.get('counts', {}).get('uniquePoses', '')))}</b></span>
  <span>aliases <b>{esc(str(measurements.get('counts', {}).get('aliases', '')))}</b></span>
  <span>source-backed <b>{esc(str(measurements.get('counts', {}).get('sourceBacked', '')))}</b></span>
  <span>target <b>{esc(str(transforms_root.get('targetPose', '')))}</b></span>
  <span>scale <b>{esc(str(summary.get('minScale', '')))}..{esc(str(summary.get('maxScale', '')))}</b></span>
  <span>flagged <b>{flagged}</b></span>
 </div>
</header>
{''.join(body)}
<section>
 <h2>aliases <span>{len(aliases) if isinstance(aliases, list) else 0} entries</span></h2>
 <table><thead><tr><th>alias</th><th>source pose</th><th>path</th></tr></thead><tbody>{alias_rows}</tbody></table>
</section>
"""
    )
    print(f"wrote {args.out} flagged={flagged}")
    return 0


def card(pose: dict[str, Any], transform: Any) -> str:
    pose_name = str(pose["pose"])
    render_path = Path(str(pose["renderPath"]))
    image = decode_png_alpha(render_path)
    render = pose["render"]
    head = rect(render.get("headBBox", [0, 0, 0, 0]))
    bbox = rect(render.get("bbox", [0, 0, 0, 0]))
    foot = render.get("contactFoot", [0.0, 0.0])
    flags = transform.get("flags", []) if isinstance(transform, dict) else []
    scale = transform.get("scale", "") if isinstance(transform, dict) else ""
    offset_x = transform.get("offsetX", "") if isinstance(transform, dict) else ""
    offset_y = transform.get("offsetY", "") if isinstance(transform, dict) else ""
    target = transform.get("targetFoot", foot) if isinstance(transform, dict) else foot
    ground_y = float(target[1]) if isinstance(target, list) and len(target) > 1 else float(foot[1])
    cls = " flagged" if flags else ""
    flag_text = f"<div class=flags>{esc(', '.join(map(str, flags)))}</div>" if flags else ""
    return f"""<article class="{cls.strip()}">
 <div class=frame>
  <svg viewBox="0 0 {image.width} {image.height}" role="img" aria-label="{esc(pose_name)}">
   <image href="{image.data_url()}" x="0" y="0" width="{image.width}" height="{image.height}" style="image-rendering:pixelated" />
   <rect x="{bbox[0]}" y="{bbox[1]}" width="{bbox[2]}" height="{bbox[3]}" fill="none" stroke="#777" stroke-width="1" />
   <rect x="{head[0]}" y="{head[1]}" width="{head[2]}" height="{head[3]}" fill="none" stroke="var(--head)" stroke-width="2" />
   <line x1="0" y1="{ground_y:.3f}" x2="{image.width}" y2="{ground_y:.3f}" stroke="var(--foot)" stroke-width="1.5" stroke-dasharray="5 4" />
   <circle cx="{float(foot[0]):.3f}" cy="{float(foot[1]):.3f}" r="4" fill="var(--foot)" />
  </svg>
 </div>
 <div class=meta>
  <div class=pose><strong>{esc(pose_name)}</strong><span>{esc(str(pose.get('grounding', '')))}</span></div>
  <div>scale {esc(str(scale))} offset {esc(str(offset_x))},{esc(str(offset_y))}</div>
  <div>head {esc(str(render.get('headHeight', '')))} conf {esc(str(render.get('confidence', '')))}</div>
  <div class=path title="{esc(str(pose.get('sourcePath', '')))}">{esc(str(pose.get('sourceKind', '')))} | {esc(str(pose.get('sourcePath', '')))}</div>
  {flag_text}
 </div>
</article>"""


def rect(values: Any) -> tuple[float, float, float, float]:
    if isinstance(values, list) and len(values) >= 4:
        return (float(values[0]), float(values[1]), float(values[2]), float(values[3]))
    return (0.0, 0.0, 0.0, 0.0)


def esc(value: str) -> str:
    return html.escape(value, quote=True)


if __name__ == "__main__":
    raise SystemExit(main())
