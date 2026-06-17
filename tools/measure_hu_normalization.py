#!/usr/bin/env python3
"""Measure Hu normalization sources and current render sprites.

The output is a durable JSON inventory used by the solver and review page.
It measures every unique v* pose in hu.manifest.json, records the best
available source-stage file, and separately measures the installed render PNG.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from hu_normalization_lib import load_json, measure_alpha, write_json


HEAD_WIDTH_LIMITS = {
    "source": 120.0,
    "render": 60.0,
}
HEAD_WIDE_THIN_RATIO = 1.8

HELD_SOURCES = {
    "vp_block": "art/keyframes/hu/block/block.png",
    "vp_dash": "art/keyframes/hu/dash/dash.png",
    "vp_hit": "art/keyframes/hu/hit/hit.png",
    "vp_stun_a": "art/keyframes/hu/stunned/stun_a.png",
    "vp_stun_b": "art/keyframes/hu/stunned/stun_b.png",
    "vp_rise": "art/keyframes/hu/jump/rise.png",
    "vp_peak": "art/keyframes/hu/jump/peak.png",
    "vp_fall": "art/keyframes/hu/jump/fall.png",
    "vp_land": "art/keyframes/hu/jump/land.png",
}

EXEMPT_POSES = {"vp_dash", "vp_rise", "vp_peak", "vp_fall"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sources",
        type=Path,
        default=Path("art/masters/hu/normalization/manifest.json"),
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("WUGodot/assets/animation_manifests/hu.manifest.json"),
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("art/masters/hu/normalization/measurements.json"),
    )
    args = parser.parse_args()

    repo = Path.cwd()
    source_manifest = load_json(args.sources)
    animation_manifest = load_json(args.manifest)
    source_map = build_source_map(repo, args.sources.parent, source_manifest)
    aliases = source_manifest.get("aliases", {})

    raw_poses = animation_manifest.get("poses", {})
    if not isinstance(raw_poses, dict):
        raise ValueError(f"manifest poses must be an object: {args.manifest}")

    seen_paths: dict[str, str] = {}
    pose_rows: list[dict[str, Any]] = []
    alias_rows: list[dict[str, Any]] = []
    for pose_name in sorted(raw_poses):
        entry = raw_poses[pose_name]
        if not isinstance(entry, dict):
            continue
        render_path = repo / str(entry.get("path", "")).replace("res://", "WUGodot/")
        render_key = str(entry.get("path", ""))
        alias_of = aliases.get(pose_name)
        if alias_of:
            alias_rows.append({"pose": pose_name, "sourcePose": alias_of, "path": render_key})
            continue
        if render_key in seen_paths:
            alias_rows.append({"pose": pose_name, "sourcePose": seen_paths[render_key], "path": render_key})
            continue
        seen_paths[render_key] = pose_name
        if not pose_name.startswith("v"):
            alias_rows.append({"pose": pose_name, "sourcePose": "", "path": render_key})
            continue
        source_info = source_map.get(pose_name)
        source_path = source_info["path"] if source_info else render_path
        source_kind = source_info["kind"] if source_info else "installed_only"
        source_key = source_info.get("sourceKey", "") if source_info else ""
        if not source_path.exists():
            source_path = render_path
            source_kind = "installed_only"
            source_key = ""
        if not render_path.exists():
            raise FileNotFoundError(f"render path missing for {pose_name}: {render_path}")

        source_measure = measure_alpha(source_path)
        render_measure = measure_alpha(render_path)
        prefix, label = split_pose(pose_name)
        pose_rows.append(
            {
                "pose": pose_name,
                "prefix": prefix,
                "label": label,
                "action": action_for_prefix(prefix, pose_name),
                "grounding": "exempt" if pose_name in EXEMPT_POSES else "grounded",
                "sourceKind": source_kind,
                "sourceKey": source_key,
                "sourcePath": rel(source_path, repo),
                "renderPath": rel(render_path, repo),
                "source": source_measure,
                "render": render_measure,
            }
        )

    apply_effective_head_metrics(pose_rows)

    target_pose = next((p for p in pose_rows if p["pose"] == "vi_002"), None)
    target_head = float(target_pose["source"]["headHeight"]) if target_pose else 0.0
    target_render_head = float(target_pose["render"]["headHeight"]) if target_pose else 0.0
    out = {
        "id": "hu_normalization_measurements",
        "generated": datetime.now(timezone.utc).isoformat(),
        "sourceManifest": rel(args.sources, repo),
        "animationManifest": rel(args.manifest, repo),
        "counts": {
            "uniquePoses": len(pose_rows),
            "aliases": len(alias_rows),
            "sourceBacked": sum(1 for p in pose_rows if p["sourceKind"] != "installed_only"),
        },
        "headContamination": head_contamination_summary(pose_rows),
        "target": {
            "pose": "vi_002",
            "sourceHeadHeight": target_head,
            "renderHeadHeight": target_render_head,
        },
        "poses": pose_rows,
        "aliases": alias_rows,
    }
    write_json(args.out, out)
    print(
        f"wrote {args.out} poses={len(pose_rows)} aliases={len(alias_rows)} "
        f"sourceBacked={out['counts']['sourceBacked']}"
    )
    return 0


def build_source_map(repo: Path, source_root: Path, manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    actions = manifest.get("actions", {})
    if not isinstance(actions, dict):
        return {}
    out: dict[str, dict[str, Any]] = {}
    for action in ("entry", "light", "heavy"):
        action_entry = actions.get(action, {})
        labels = action_entry.get("labels", []) if isinstance(action_entry, dict) else []
        prefix = action_entry.get("pose_prefix", "") if isinstance(action_entry, dict) else ""
        for index, label in enumerate(labels, start=1):
            master = f"master_{index:03d}"
            source_path = source_root / action / "masters_pristine" / f"{master}.png"
            out[f"{prefix}_{label}"] = {
                "path": repo / source_path,
                "kind": "masters_pristine",
                "sourceKey": f"{action}/{master}",
            }

    walk = actions.get("walk", {})
    if isinstance(walk, dict):
        prefix = walk.get("pose_prefix", "vw")
        labels = walk.get("labels", [])
        source_labels = walk.get("source_master_labels", labels)
        for label, source_label in zip(labels, source_labels):
            master = f"master_{source_label}"
            out[f"{prefix}_{label}"] = {
                "path": repo / source_root / "walk" / "masters" / f"{master}.png",
                "kind": "walk_master",
                "sourceKey": f"walk/{master}",
            }

    idle = actions.get("idle_ref", {})
    if isinstance(idle, dict):
        prefix = idle.get("pose_prefix", "vi")
        labels = idle.get("labels", [])
        if labels:
            out[f"{prefix}_{labels[0]}"] = {
                "path": repo / source_root / "idle_ref" / "masters_pristine" / "master_001.png",
                "kind": "idle_ref",
                "sourceKey": "idle_ref/master_001",
            }

    for pose, path in HELD_SOURCES.items():
        out[pose] = {
            "path": repo / path,
            "kind": "keyframe",
            "sourceKey": f"held/{pose}",
        }
    return out


def apply_effective_head_metrics(poses: list[dict[str, Any]]) -> None:
    for space in ("source", "render"):
        limit = HEAD_WIDTH_LIMITS[space]
        templates = build_head_templates(poses, space, limit)
        for pose in poses:
            measurement = pose[space]
            raw_bbox = list(measurement.get("headBBox", [0, 0, 0, 0]))
            raw_flags = list(measurement.get("flags", []))
            raw_width = float(raw_bbox[2]) if len(raw_bbox) >= 4 else 0.0
            raw_height = float(raw_bbox[3]) if len(raw_bbox) >= 4 else 0.0
            raw_wide_thin = raw_height > 0.0 and raw_width / raw_height > HEAD_WIDE_THIN_RATIO
            raw_head_flag = any(str(flag).startswith("head-") for flag in raw_flags)
            raw_contaminated = raw_width > limit or raw_wide_thin or raw_head_flag
            measurement["rawHeadBBox"] = raw_bbox
            measurement["rawHeadHeight"] = measurement.get("headHeight", raw_height)
            measurement["rawConfidence"] = measurement.get("confidence", 0.0)
            measurement["rawFlags"] = raw_flags
            measurement["rawHeadWidthContaminated"] = raw_contaminated
            measurement["headWidthLimit"] = limit

            if not raw_contaminated:
                measurement["headWidth"] = raw_width
                measurement["headWidthContaminated"] = False
                continue

            group = scale_group_for_pose(pose)
            template = templates.get(group) or templates.get(str(pose.get("prefix", ""))) or templates.get("__all__")
            if template is None:
                effective_width = min(raw_width, limit)
                effective_height = raw_height
                flags = [flag for flag in raw_flags if not str(flag).startswith("head-")]
                flags.append("head-effective-clamped")
            else:
                effective_width = template["width"]
                effective_height = template["height"]
                flags = [flag for flag in raw_flags if not str(flag).startswith("head-")]
                flags.append("head-effective-from-clean-frames")

            cx = float(raw_bbox[0]) + raw_width * 0.5
            cy = float(raw_bbox[1]) + raw_height * 0.5
            effective_bbox = [
                round(cx - effective_width * 0.5, 3),
                round(cy - effective_height * 0.5, 3),
                round(effective_width, 3),
                round(effective_height, 3),
            ]
            measurement["headBBox"] = effective_bbox
            measurement["headHeight"] = effective_bbox[3]
            measurement["headWidth"] = effective_bbox[2]
            measurement["confidence"] = min(float(measurement.get("confidence", 0.0)), 0.74)
            measurement["flags"] = sorted(set(flags))
            measurement["headWidthContaminated"] = effective_bbox[2] > limit


def build_head_templates(poses: list[dict[str, Any]], space: str, limit: float) -> dict[str, dict[str, float]]:
    grouped: dict[str, list[tuple[float, float]]] = {}
    for pose in poses:
        measurement = pose[space]
        bbox = measurement.get("headBBox", [0, 0, 0, 0])
        if not isinstance(bbox, list) or len(bbox) < 4:
            continue
        width = float(bbox[2])
        height = float(bbox[3])
        confidence = float(measurement.get("confidence", 0.0))
        flags = [str(flag) for flag in measurement.get("flags", [])]
        wide_thin = height > 0.0 and width / height > HEAD_WIDE_THIN_RATIO
        if confidence < 0.8 or width <= 0.0 or height <= 0.0 or width > limit or wide_thin:
            continue
        if any(flag.startswith("head-") for flag in flags):
            continue
        for group in (scale_group_for_pose(pose), str(pose.get("prefix", "")), "__all__"):
            grouped.setdefault(group, []).append((width, height))
    return {
        group: {
            "width": percentile(values, 0.5, index=0),
            "height": percentile(values, 0.5, index=1),
        }
        for group, values in grouped.items()
        if values
    }


def head_contamination_summary(poses: list[dict[str, Any]]) -> dict[str, dict[str, int]]:
    summary: dict[str, dict[str, int]] = {}
    for space in ("source", "render"):
        limit = HEAD_WIDTH_LIMITS[space]
        raw_over_120 = 0
        effective_over_120 = 0
        raw_over_limit = 0
        effective_over_limit = 0
        raw_wide_thin = 0
        raw_head_flagged = 0
        for pose in poses:
            measurement = pose[space]
            raw_bbox = measurement.get("rawHeadBBox", measurement.get("headBBox", [0, 0, 0, 0]))
            bbox = measurement.get("headBBox", [0, 0, 0, 0])
            raw_width = float(raw_bbox[2]) if isinstance(raw_bbox, list) and len(raw_bbox) >= 4 else 0.0
            raw_height = float(raw_bbox[3]) if isinstance(raw_bbox, list) and len(raw_bbox) >= 4 else 0.0
            effective_width = float(bbox[2]) if isinstance(bbox, list) and len(bbox) >= 4 else 0.0
            raw_over_120 += int(raw_width > 120.0)
            effective_over_120 += int(effective_width > 120.0)
            raw_over_limit += int(raw_width > limit)
            effective_over_limit += int(effective_width > limit)
            raw_wide_thin += int(raw_height > 0.0 and raw_width / raw_height > HEAD_WIDE_THIN_RATIO)
            raw_flags = [str(flag) for flag in measurement.get("rawFlags", [])]
            raw_head_flagged += int(any(flag.startswith("head-") for flag in raw_flags))
        summary[space] = {
            "rawOver120": raw_over_120,
            "effectiveOver120": effective_over_120,
            "rawOverLimit": raw_over_limit,
            "effectiveOverLimit": effective_over_limit,
            "rawWideThin": raw_wide_thin,
            "rawHeadFlagged": raw_head_flagged,
        }
    return summary


def scale_group_for_pose(pose: dict[str, Any]) -> str:
    if str(pose.get("prefix", "")) == "vp":
        return "held"
    return str(pose.get("action", pose.get("prefix", "")))


def percentile(values: list[tuple[float, float]], q: float, index: int) -> float:
    selected = sorted(value[index] for value in values)
    if not selected:
        return 0.0
    pos = (len(selected) - 1) * q
    lower = int(pos)
    upper = min(lower + 1, len(selected) - 1)
    if lower == upper:
        return round(selected[lower], 3)
    frac = pos - lower
    return round(selected[lower] * (1.0 - frac) + selected[upper] * frac, 3)


def split_pose(pose: str) -> tuple[str, str]:
    if "_" not in pose:
        return pose, ""
    prefix, label = pose.split("_", 1)
    return prefix, label


def action_for_prefix(prefix: str, pose: str) -> str:
    if prefix == "vd":
        return "entry"
    if prefix == "vh":
        return "heavy"
    if prefix == "vl":
        return "light"
    if prefix == "vw":
        return "walk"
    if prefix == "vi":
        return "idle"
    if prefix == "vp":
        if pose in {"vp_rise", "vp_peak", "vp_fall", "vp_land"}:
            return "jump"
        return pose.removeprefix("vp_")
    return prefix


def rel(path: Path, repo: Path) -> str:
    try:
        return path.resolve().relative_to(repo.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


if __name__ == "__main__":
    raise SystemExit(main())
