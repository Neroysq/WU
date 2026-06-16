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
