#!/usr/bin/env python3
"""Build a self-contained Hu normalization review page."""

from __future__ import annotations

import argparse
import html
import os
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
    contamination = measurements.get("headContamination", {})
    scale_groups = transforms_root.get("scaleGroups", {})
    vision_counts = count_vision_annotations(poses)
    scale_group_rows = ""
    if isinstance(scale_groups, dict):
        for group, info in sorted(scale_groups.items()):
            if group == "__all__" or not isinstance(info, dict):
                continue
            clean_poses = info.get("cleanPoses", [])
            clean_text = ", ".join(map(str, clean_poses)) if isinstance(clean_poses, list) else ""
            scale_group_rows += (
                f"<tr><td>{esc(group)}</td><td>{esc(str(info.get('scale', '')))}</td>"
                f"<td>{esc(str(info.get('medianHeadWidth', '')))}</td>"
                f"<td>{esc(str(info.get('cleanCount', '')))}</td>"
                f"<td>{esc(str(info.get('source', '')))}</td>"
                f"<td>{esc(clean_text)}</td></tr>"
            )
    montage = head_aligned_montage(grouped, args.out.parent)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    doc = f"""<!doctype html>
<meta charset=utf-8>
<title>Hu normalization review</title>
<style>
 :root {{ color-scheme: dark; --bg:#14151a; --panel:#20232a; --ink:#ece7dc; --muted:#a9a397; --line:#353a44; --bad:#ff6b62; --ok:#88d18a; --head:#5fd4ff; --vision:#ff9f43; --foot:#ffd166; }}
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
 .montages {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(320px, 1fr)); gap:12px }}
 .montage {{ background:var(--panel); border:1px solid var(--line); border-radius:6px; overflow:hidden }}
 .montage h3 {{ margin:0; padding:8px 10px; font-size:12px; border-bottom:1px solid var(--line) }}
 .montage .meta {{ border-top:1px solid var(--line) }}
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
  <span>scale groups <b>{esc(str(summary.get('scaleGroupCount', '')))}</b></span>
  <span>vision heads <b>{vision_counts['total']} ({vision_counts['clean']} clean / {vision_counts['occluded']} held out)</b></span>
  <span>head width >120 raw/effective <b>{contam_text(contamination)}</b></span>
  <span>flagged <b>{flagged}</b></span>
 </div>
</header>
{montage}
<section>
 <h2>scale groups <span>constant scale per action group</span></h2>
 <table><thead><tr><th>group</th><th>scale</th><th>median clean head width</th><th>clean frames</th><th>source</th><th>clean poses</th></tr></thead><tbody>{scale_group_rows}</tbody></table>
</section>
{''.join(body)}
<section>
 <h2>aliases <span>{len(aliases) if isinstance(aliases, list) else 0} entries</span></h2>
 <table><thead><tr><th>alias</th><th>source pose</th><th>path</th></tr></thead><tbody>{alias_rows}</tbody></table>
</section>
"""
    args.out.write_text("\n".join(line.rstrip() for line in doc.splitlines()) + "\n")
    print(f"wrote {args.out} flagged={flagged}")
    return 0


def head_aligned_montage(grouped: dict[str, list[dict[str, Any]]], out_dir: Path) -> str:
    groups: list[tuple[str, list[dict[str, Any]]]] = [
        ("all", [pose for poses in grouped.values() for pose in poses]),
    ]
    groups.extend((prefix, poses) for prefix, poses in sorted(grouped.items()))

    cards = []
    for label, poses in groups:
        items = []
        min_x = min_y = float("inf")
        max_x = max_y = float("-inf")
        for pose in sorted(poses, key=lambda p: str(p.get("pose", ""))):
            render = pose.get("render", {})
            if not isinstance(render, dict):
                continue
            head = rect(render.get("headBBox", [0, 0, 0, 0]))
            if head[2] <= 0.0 or head[3] <= 0.0:
                continue
            render_path = Path(str(pose.get("renderPath", "")))
            image = decode_png_alpha(render_path)
            head_cx = head[0] + head[2] * 0.5
            head_cy = head[1] + head[3] * 0.5
            x = -head_cx
            y = -head_cy
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x + image.width)
            max_y = max(max_y, y + image.height)
            items.append(
                {
                    "href": os.path.relpath(render_path, out_dir),
                    "pose": str(pose.get("pose", "")),
                    "x": x,
                    "y": y,
                    "width": image.width,
                    "height": image.height,
                    "head": (head[0] + x, head[1] + y, head[2], head[3]),
                }
            )
        if not items:
            continue

        pad = 18.0
        view_x = min_x - pad
        view_y = min_y - pad
        view_w = max_x - min_x + pad * 2.0
        view_h = max_y - min_y + pad * 2.0
        opacity = 0.045 if label == "all" else 0.16
        image_nodes = []
        rect_nodes = []
        for item in items:
            image_nodes.append(
                f'<image href="{esc(str(item["href"]))}" x="{item["x"]:.3f}" y="{item["y"]:.3f}" '
                f'width="{item["width"]}" height="{item["height"]}" opacity="{opacity}" style="image-rendering:pixelated" />'
            )
            hx, hy, hw, hh = item["head"]
            rect_nodes.append(
                f'<rect x="{hx:.3f}" y="{hy:.3f}" width="{hw:.3f}" height="{hh:.3f}" '
                'fill="none" stroke="var(--head)" stroke-width="1" opacity="0.28" />'
            )
        cards.append(
            f"""<div class=montage>
 <h3>{esc(label)} <span>{len(items)} head-aligned poses</span></h3>
 <svg viewBox="{view_x:.3f} {view_y:.3f} {view_w:.3f} {view_h:.3f}" role="img" aria-label="{esc(label)} head-aligned montage">
  <line x1="{view_x:.3f}" y1="0" x2="{view_x + view_w:.3f}" y2="0" stroke="var(--head)" stroke-width="1" opacity="0.7" />
  <line x1="0" y1="{view_y:.3f}" x2="0" y2="{view_y + view_h:.3f}" stroke="var(--head)" stroke-width="1" opacity="0.7" />
  {''.join(image_nodes)}
  {''.join(rect_nodes)}
 </svg>
 <div class=meta>heads share center crosshair; blue boxes show final detected head size</div>
</div>"""
        )

    if not cards:
        return ""
    return (
        "<section><h2>head-aligned montage <span>final size overlay</span></h2>"
        f"<div class=montages>{''.join(cards)}</div></section>"
    )


def card(pose: dict[str, Any], transform: Any) -> str:
    pose_name = str(pose["pose"])
    render_path = Path(str(pose["renderPath"]))
    image = decode_png_alpha(render_path)
    render = pose["render"]
    head = rect(render.get("headBBox", [0, 0, 0, 0]))
    vision = render.get("visionHead", {})
    vision_box = rect(vision.get("visionBox", [0, 0, 0, 0]) if isinstance(vision, dict) else [0, 0, 0, 0])
    has_vision = isinstance(vision, dict) and bool(vision)
    bbox = rect(render.get("bbox", [0, 0, 0, 0]))
    foot = render.get("contactFoot", [0.0, 0.0])
    flags = transform.get("flags", []) if isinstance(transform, dict) else []
    spatial_flags = transform.get("spatialFlags", []) if isinstance(transform, dict) else []
    scale = transform.get("scale", "") if isinstance(transform, dict) else ""
    scale_group = transform.get("scaleGroup", "") if isinstance(transform, dict) else ""
    scale_source = transform.get("scaleSource", "") if isinstance(transform, dict) else ""
    offset_x = transform.get("offsetX", "") if isinstance(transform, dict) else ""
    offset_y = transform.get("offsetY", "") if isinstance(transform, dict) else ""
    target = transform.get("targetFoot", foot) if isinstance(transform, dict) else foot
    ground_y = float(target[1]) if isinstance(target, list) and len(target) > 1 else float(foot[1])
    cls = " flagged" if flags else ""
    flag_text = f"<div class=flags>{esc(', '.join(map(str, flags)))}</div>" if flags else ""
    spatial_text = f"<div class=path>{esc(', '.join(map(str, spatial_flags)))}</div>" if spatial_flags else ""
    raw_head = render.get("rawHeadBBox", render.get("headBBox", [0, 0, 0, 0]))
    raw_width = raw_head[2] if isinstance(raw_head, list) and len(raw_head) >= 4 else ""
    effective_width = head[2]
    vision_rect = ""
    vision_text = ""
    if has_vision:
        vision_rect = (
            f'<rect x="{vision_box[0]}" y="{vision_box[1]}" width="{vision_box[2]}" height="{vision_box[3]}" '
            'fill="none" stroke="var(--vision)" stroke-width="1.5" stroke-dasharray="4 3" />'
        )
        status = "clean" if bool(vision.get("clean", False)) else "held-out"
        vision_text = (
            f"<div>vision {esc(status)} box {esc(str(vision.get('bbox', '')))} "
            f"conf {esc(str(vision.get('confidence', '')))}</div>"
            f"<div class=path>{esc(str(vision.get('notes', '')))}</div>"
        )
    return f"""<article class="{cls.strip()}">
 <div class=frame>
  <svg viewBox="0 0 {image.width} {image.height}" role="img" aria-label="{esc(pose_name)}">
   <image href="{image.data_url()}" x="0" y="0" width="{image.width}" height="{image.height}" style="image-rendering:pixelated" />
   <rect x="{bbox[0]}" y="{bbox[1]}" width="{bbox[2]}" height="{bbox[3]}" fill="none" stroke="#777" stroke-width="1" />
   {vision_rect}
   <rect x="{head[0]}" y="{head[1]}" width="{head[2]}" height="{head[3]}" fill="none" stroke="var(--head)" stroke-width="2" />
   <line x1="0" y1="{ground_y:.3f}" x2="{image.width}" y2="{ground_y:.3f}" stroke="var(--foot)" stroke-width="1.5" stroke-dasharray="5 4" />
   <circle cx="{float(foot[0]):.3f}" cy="{float(foot[1]):.3f}" r="4" fill="var(--foot)" />
  </svg>
 </div>
 <div class=meta>
  <div class=pose><strong>{esc(pose_name)}</strong><span>{esc(str(pose.get('grounding', '')))}</span></div>
  <div>scale {esc(str(scale))} group {esc(str(scale_group))}</div>
  <div class=path>{esc(str(scale_source))}</div>
  <div>offset {esc(str(offset_x))},{esc(str(offset_y))}</div>
  <div>head w raw→eff {esc(str(raw_width))}→{esc(str(effective_width))} h {esc(str(render.get('headHeight', '')))} conf {esc(str(render.get('confidence', '')))}</div>
  {vision_text}
  <div class=path title="{esc(str(pose.get('sourcePath', '')))}">{esc(str(pose.get('sourceKind', '')))} | {esc(str(pose.get('sourcePath', '')))}</div>
  {spatial_text}
  {flag_text}
 </div>
</article>"""


def rect(values: Any) -> tuple[float, float, float, float]:
    if isinstance(values, list) and len(values) >= 4:
        return (float(values[0]), float(values[1]), float(values[2]), float(values[3]))
    return (0.0, 0.0, 0.0, 0.0)


def esc(value: str) -> str:
    return html.escape(value, quote=True)


def count_vision_annotations(poses: list[Any]) -> dict[str, int]:
    total = 0
    clean = 0
    for pose in poses:
        if not isinstance(pose, dict):
            continue
        vision = pose.get("render", {}).get("visionHead", {})
        if not isinstance(vision, dict) or not vision:
            continue
        total += 1
        if bool(vision.get("clean", False)):
            clean += 1
    return {"total": total, "clean": clean, "occluded": total - clean}


def contam_text(value: Any) -> str:
    if not isinstance(value, dict):
        return ""
    source = value.get("source", {})
    render = value.get("render", {})
    if not isinstance(source, dict) or not isinstance(render, dict):
        return ""
    return (
        f"source {source.get('rawOver120', '')}/{source.get('effectiveOver120', '')}, "
        f"render {render.get('rawOver120', '')}/{render.get('effectiveOver120', '')}"
    )


if __name__ == "__main__":
    raise SystemExit(main())
