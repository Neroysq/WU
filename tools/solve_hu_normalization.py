#!/usr/bin/env python3
"""Solve Hu frame-normalization transforms from measurements."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from hu_normalization_lib import load_json, median, write_json


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--measurements",
        type=Path,
        default=Path("art/masters/hu/normalization/measurements.json"),
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("art/masters/hu/normalization/transforms.json"),
    )
    parser.add_argument("--target-pose", default="vi_002")
    parser.add_argument("--manual-overrides", type=Path, default=None)
    args = parser.parse_args()

    measurements = load_json(args.measurements)
    poses = measurements.get("poses", [])
    if not isinstance(poses, list):
        raise ValueError("measurements.poses must be a list")
    by_pose = {str(p["pose"]): p for p in poses if isinstance(p, dict) and "pose" in p}
    target = by_pose.get(args.target_pose)
    if target is None:
        raise ValueError(f"target pose not found: {args.target_pose}")
    target_head = float(target["render"]["headHeight"])
    if target_head <= 0.0:
        raise ValueError(f"target pose has invalid render head height: {args.target_pose}")

    overrides = load_json(args.manual_overrides) if args.manual_overrides else {}
    override_transforms = overrides.get("transforms", overrides)
    if not isinstance(override_transforms, dict):
        override_transforms = {}

    group_targets = solve_group_targets(poses)
    transforms: dict[str, dict[str, Any]] = {}
    pose_summaries: list[dict[str, Any]] = []
    for pose in poses:
        if not isinstance(pose, dict):
            continue
        pose_name = str(pose["pose"])
        render = pose["render"]
        source = pose["source"]
        head = float(render.get("headHeight", 0.0))
        scale = target_head / head if head > 0.0 else 1.0
        grounding = str(pose.get("grounding", "grounded"))
        group = str(pose.get("prefix", ""))
        target_xy = group_targets.get(group, {"x": 0.0, "y": 0.0})
        foot = render.get("contactFoot", [0.0, 0.0])
        offset_x = float(target_xy["x"]) - float(foot[0])
        offset_y = 0.0 if grounding == "exempt" else float(target_xy["y"]) - float(foot[1])
        flags = transform_flags(scale, offset_x, offset_y, source.get("flags", []), render.get("flags", []))
        transform = {
            "pose": pose_name,
            "scale": round(scale, 5),
            "offsetX": round(offset_x, 3),
            "offsetY": round(offset_y, 3),
            "grounding": grounding,
            "sourceKey": str(pose.get("sourceKey", "")),
            "targetFoot": [round(float(target_xy["x"]), 3), round(float(target_xy["y"]), 3)],
            "flags": flags,
        }
        manual = override_transforms.get(pose_name, {})
        if isinstance(manual, dict):
            transform.update(manual)
            if manual:
                transform["manualOverride"] = True
        transforms[pose_name] = transform
        source_key = str(pose.get("sourceKey", ""))
        if source_key and source_key.startswith(("entry/", "light/", "heavy/", "walk/")):
            transforms[source_key] = {
                "pose": pose_name,
                "scale": transform["scale"],
                "flags": flags,
            }
        pose_summaries.append(
            {
                "pose": pose_name,
                "sourceKey": source_key,
                "scale": transform["scale"],
                "offsetX": transform["offsetX"],
                "offsetY": transform["offsetY"],
                "flags": flags,
            }
        )

    out = {
        "id": "hu_normalization_transforms",
        "generated": datetime.now(timezone.utc).isoformat(),
        "measurements": args.measurements.as_posix(),
        "targetPose": args.target_pose,
        "targetRenderHeadHeight": target_head,
        "groupTargets": group_targets,
        "transforms": transforms,
        "summary": {
            "poses": len([k for k in transforms if "_" in k and "/" not in k]),
            "sourceKeys": len([k for k in transforms if "/" in k]),
            "flagged": sum(1 for row in pose_summaries if row["flags"]),
            "maxScale": max((float(row["scale"]) for row in pose_summaries), default=1.0),
            "minScale": min((float(row["scale"]) for row in pose_summaries), default=1.0),
        },
        "poses": pose_summaries,
    }
    write_json(args.out, out)
    print(
        f"wrote {args.out} poses={out['summary']['poses']} sourceKeys={out['summary']['sourceKeys']} "
        f"flagged={out['summary']['flagged']} scale={out['summary']['minScale']:.3f}..{out['summary']['maxScale']:.3f}"
    )
    return 0


def solve_group_targets(poses: list[Any]) -> dict[str, dict[str, float]]:
    groups: dict[str, dict[str, list[float]]] = {}
    for pose in poses:
        if not isinstance(pose, dict) or str(pose.get("grounding", "grounded")) != "grounded":
            continue
        prefix = str(pose.get("prefix", ""))
        foot = pose.get("render", {}).get("contactFoot", [0.0, 0.0])
        groups.setdefault(prefix, {"x": [], "y": []})
        groups[prefix]["x"].append(float(foot[0]))
        groups[prefix]["y"].append(float(foot[1]))
    return {
        prefix: {
            "x": round(median(values["x"]), 3),
            "y": round(median(values["y"]), 3),
        }
        for prefix, values in sorted(groups.items())
    }


def transform_flags(scale: float, offset_x: float, offset_y: float, source_flags: Any, render_flags: Any) -> list[str]:
    flags: list[str] = []
    if scale < 0.85 or scale > 1.18:
        flags.append("scale-review")
    if abs(offset_x) > 16.0:
        flags.append("offset-x-review")
    if abs(offset_y) > 12.0:
        flags.append("offset-y-review")
    for flag in list(source_flags or []):
        if str(flag).startswith("head-"):
            flags.append(f"source-{flag}")
    for flag in list(render_flags or []):
        if str(flag).startswith("head-") or str(flag).startswith("foot-"):
            flags.append(f"render-{flag}")
    return sorted(set(flags))


if __name__ == "__main__":
    raise SystemExit(main())
