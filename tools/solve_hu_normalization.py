#!/usr/bin/env python3
"""Solve Hu frame-normalization transforms from measurements."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from hu_normalization_lib import load_json, median, write_json

MIN_CLEAN_HEAD_WIDTH: float = 34.0
LOCKED_BUILD4_SCALES: dict[str, float] = {
    "idle": 1.0,
    "light": 1.06,
    "heavy": 1.06,
    "walk": 1.04,
    "entry": 1.08,
    "held": 1.04,
}


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
    parser.add_argument(
        "--scale-mode",
        choices=("locked-build4", "clean-head-width"),
        default="locked-build4",
    )
    args = parser.parse_args()

    measurements = load_json(args.measurements)
    poses = measurements.get("poses", [])
    if not isinstance(poses, list):
        raise ValueError("measurements.poses must be a list")
    by_pose = {str(p["pose"]): p for p in poses if isinstance(p, dict) and "pose" in p}
    target = by_pose.get(args.target_pose)
    if target is None:
        raise ValueError(f"target pose not found: {args.target_pose}")
    target_head_width = float(target["render"]["headBBox"][2])
    if target_head_width <= 0.0:
        raise ValueError(f"target pose has invalid render head width: {args.target_pose}")

    overrides = load_json(args.manual_overrides) if args.manual_overrides else {}
    override_transforms = overrides.get("transforms", overrides)
    if not isinstance(override_transforms, dict):
        override_transforms = {}

    group_targets = solve_group_targets(poses)
    measured_scale_groups = solve_scale_groups(poses, target_head_width)
    scale_groups = (
        solve_locked_build4_scale_groups(poses, measured_scale_groups)
        if args.scale_mode == "locked-build4"
        else measured_scale_groups
    )
    transforms: dict[str, dict[str, Any]] = {}
    pose_summaries: list[dict[str, Any]] = []
    for pose in poses:
        if not isinstance(pose, dict):
            continue
        pose_name = str(pose["pose"])
        render = pose["render"]
        source = pose["source"]
        scale_group = scale_group_for_pose(pose)
        scale_info = scale_groups.get(scale_group, scale_groups.get("__all__", {"scale": 1.0}))
        scale = float(scale_info["scale"])
        grounding = str(pose.get("grounding", "grounded"))
        group = str(pose.get("prefix", ""))
        target_xy = group_targets.get(group, {"x": 0.0, "y": 0.0})
        # Build 4 plants roots in the lossless master stage: scale_masters uses a
        # common foot canvas and install_video crops to the action foot target.
        # Re-applying measured render offsets here would move the root a second
        # time and break anchor-sanity foot spread checks.
        offset_x = 0.0
        offset_y = 0.0
        flags = transform_flags(scale, offset_x, offset_y, source.get("flags", []), render.get("flags", []))
        transform = {
            "pose": pose_name,
            "scale": round(scale, 5),
            "offsetX": round(offset_x, 3),
            "offsetY": round(offset_y, 3),
            "grounding": grounding,
            "scaleGroup": scale_group,
            "scaleSource": str(scale_info.get("source", "fallback")),
            "sourceKey": str(pose.get("sourceKey", "")),
            "targetFoot": [round(float(target_xy["x"]), 3), round(float(target_xy["y"]), 3)],
            "flags": flags,
            "spatialFlags": spatial_flags(offset_x, offset_y),
        }
        manual = override_transforms.get(pose_name, {})
        if isinstance(manual, dict):
            transform.update(manual)
            if manual:
                transform["manualOverride"] = True
        transforms[pose_name] = transform
        source_key = str(pose.get("sourceKey", ""))
        if source_key and source_key.startswith(("entry/", "light/", "heavy/", "walk/", "held/")):
            transforms[source_key] = {
                "pose": pose_name,
                "scale": transform["scale"],
                "scaleGroup": scale_group,
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
                "scaleGroup": scale_group,
            }
        )

    out = {
        "id": "hu_normalization_transforms",
        "generated": datetime.now(timezone.utc).isoformat(),
        "measurements": args.measurements.as_posix(),
        "targetPose": args.target_pose,
        "targetRenderHeadWidth": target_head_width,
        "groupTargets": group_targets,
        "scaleGroups": scale_groups,
        "scaleMode": args.scale_mode,
        "transforms": transforms,
        "summary": {
            "poses": len([k for k in transforms if "_" in k and "/" not in k]),
            "sourceKeys": len([k for k in transforms if "/" in k]),
            "flagged": sum(1 for row in pose_summaries if row["flags"]),
            "maxScale": max((float(row["scale"]) for row in pose_summaries), default=1.0),
            "minScale": min((float(row["scale"]) for row in pose_summaries), default=1.0),
            "scaleGroupCount": len([key for key in scale_groups if key != "__all__"]),
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


def solve_scale_groups(poses: list[Any], target_head_width: float) -> dict[str, dict[str, Any]]:
    groups: dict[str, list[tuple[str, float]]] = {}
    all_clean: list[tuple[str, float]] = []
    for pose in poses:
        if not isinstance(pose, dict):
            continue
        render = pose.get("render", {})
        if not isinstance(render, dict) or not is_clean_scale_sample(render):
            continue
        width = raw_head_width(render)
        row = (str(pose.get("pose", "")), width)
        group = scale_group_for_pose(pose)
        groups.setdefault(group, []).append(row)
        all_clean.append(row)

    fallback_width = median([width for _pose, width in all_clean], target_head_width)
    out: dict[str, dict[str, Any]] = {
        "__all__": {
            "medianHeadWidth": round(fallback_width, 3),
            "scale": round(target_head_width / fallback_width if fallback_width > 0.0 else 1.0, 5),
            "cleanCount": len(all_clean),
            "source": "all-clean-render-head-width",
        }
    }
    pose_groups = sorted({scale_group_for_pose(pose) for pose in poses if isinstance(pose, dict)})
    for group in pose_groups:
        samples = groups.get(group, [])
        if samples:
            width = median([sample_width for _pose, sample_width in samples], fallback_width)
            source = "action-clean-render-head-width"
            clean_poses = [pose_name for pose_name, _width in samples]
        else:
            width = fallback_width
            source = "fallback-all-clean-render-head-width"
            clean_poses = []
        out[group] = {
            "medianHeadWidth": round(width, 3),
            "scale": round(target_head_width / width if width > 0.0 else 1.0, 5),
            "cleanCount": len(samples),
            "cleanPoses": clean_poses,
            "source": source,
        }
    return out


def solve_locked_build4_scale_groups(
    poses: list[Any], measured_groups: dict[str, dict[str, Any]]
) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    all_info = dict(measured_groups.get("__all__", {}))
    all_info["scale"] = 1.0
    all_info["source"] = "locked-build4-user-approved"
    out["__all__"] = all_info

    pose_groups = sorted({scale_group_for_pose(pose) for pose in poses if isinstance(pose, dict)})
    for group in pose_groups:
        info = dict(measured_groups.get(group, {}))
        previous_scale = float(info.get("scale", 1.0))
        info["scale"] = LOCKED_BUILD4_SCALES.get(group, previous_scale)
        info["source"] = "locked-build4-user-approved"
        info["previousMetricScale"] = round(previous_scale, 5)
        info["lockedBuild4"] = True
        out[group] = info
    return out


def scale_group_for_pose(pose: dict[str, Any]) -> str:
    if str(pose.get("prefix", "")) == "vp":
        return "held"
    return str(pose.get("action", pose.get("prefix", "")))


def is_clean_scale_sample(render: dict[str, Any]) -> bool:
    width = raw_head_width(render)
    if width < MIN_CLEAN_HEAD_WIDTH:
        return False
    if "visionHead" in render:
        return bool(render.get("visionClean", False)) and float(render.get("confidence", 0.0)) >= 0.8
    if bool(render.get("rawHeadWidthContaminated", render.get("headWidthContaminated", False))):
        return False
    if float(render.get("rawConfidence", render.get("confidence", 0.0))) < 0.8:
        return False
    raw_flags = [str(flag) for flag in render.get("rawFlags", render.get("flags", []))]
    return not any(flag.startswith("head-") for flag in raw_flags)


def raw_head_width(render: dict[str, Any]) -> float:
    if "visionHead" in render:
        bbox = render.get("headBBox", [0, 0, 0, 0])
        if isinstance(bbox, list) and len(bbox) >= 4:
            return float(bbox[2])
    raw_bbox = render.get("rawHeadBBox", render.get("headBBox", [0, 0, 0, 0]))
    if isinstance(raw_bbox, list) and len(raw_bbox) >= 4:
        return float(raw_bbox[2])
    return 0.0


def transform_flags(scale: float, offset_x: float, offset_y: float, source_flags: Any, render_flags: Any) -> list[str]:
    flags: list[str] = []
    if scale < 0.85 or scale > 1.18:
        flags.append("scale-review")
    for flag in list(source_flags or []):
        if str(flag).startswith("head-") and "effective" not in str(flag):
            flags.append(f"source-{flag}")
    for flag in list(render_flags or []):
        if str(flag).startswith("head-") and "effective" not in str(flag):
            flags.append(f"render-{flag}")
    return sorted(set(flags))


def spatial_flags(offset_x: float, offset_y: float) -> list[str]:
    flags: list[str] = []
    if abs(offset_x) > 16.0:
        flags.append("offset-x-review")
    if abs(offset_y) > 12.0:
        flags.append("offset-y-review")
    return flags


if __name__ == "__main__":
    raise SystemExit(main())
