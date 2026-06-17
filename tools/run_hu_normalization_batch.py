#!/usr/bin/env python3
"""Run a Hu normalization re-derive batch in scratch space.

By default this only stages, scales, and pixelizes into /tmp. Passing
--install also runs install_video_frames.gd and measure_anchors, which modifies
runtime sprite assets and hu.manifest.json.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
from pathlib import Path
from typing import Any

from hu_normalization_lib import load_json


SUPPORTED_ACTIONS = {"entry", "light", "heavy", "walk", "held"}
HELD_LABELS = ["hit", "stun_a", "stun_b", "block", "dash", "rise", "peak", "fall", "land"]
HELD_FOOT_X = 334
OUT_SIZE_RE = re.compile(r"out-size for pixelize:\s*(\d+):(\d+)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actions", required=True, help="comma-separated action names: entry,light,heavy,walk,held")
    parser.add_argument("--scratch", type=Path, default=Path("/private/tmp/wu-hu-normalization-batch"))
    parser.add_argument(
        "--sources",
        type=Path,
        default=Path("art/masters/hu/normalization/manifest.json"),
    )
    parser.add_argument(
        "--transforms",
        type=Path,
        default=Path("art/masters/hu/normalization/transforms.json"),
    )
    parser.add_argument(
        "--idle-ref",
        type=Path,
        default=Path("art/masters/hu/normalization/idle_ref/masters_pristine"),
    )
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()

    repo = Path.cwd()
    actions = [a.strip() for a in args.actions.split(",") if a.strip()]
    unsupported = [a for a in actions if a not in SUPPORTED_ACTIONS]
    if unsupported:
        raise SystemExit(
            "unsupported actions for this runner: %s (supported: %s)"
            % (",".join(unsupported), ",".join(sorted(SUPPORTED_ACTIONS)))
        )

    source_manifest = load_json(args.sources)
    source_actions = source_manifest.get("actions", {})
    if not isinstance(source_actions, dict):
        raise SystemExit("source manifest has no actions object")

    scratch = args.scratch.resolve()
    if not str(scratch).startswith(("/tmp/", "/private/tmp/")):
        raise SystemExit(f"scratch must be under /tmp: {scratch}")
    if scratch.exists():
        shutil.rmtree(scratch)
    scratch.mkdir(parents=True)

    for action in actions:
        if action == "held":
            held_stage = scratch.parent / f"{scratch.name}-held-stage"
            run(["./run.sh", "--stage-held-keyframes", str(held_stage)], repo)
            shutil.copytree(held_stage / "held", scratch / "held")
            continue
        if action == "walk":
            stage_walk(repo, source_actions, scratch)
            continue
        src = repo / "art" / "masters" / "hu" / "normalization" / action
        if not src.exists():
            raise SystemExit(f"missing source action dir: {src}")
        shutil.copytree(src, scratch / action)

    scale = run(
        [
            "./run.sh",
            "--scale-masters",
            str(scratch),
            f"--transforms={abs_path(repo, args.transforms)}",
            f"--idle-ref={abs_path(repo, args.idle_ref)}",
        ],
        repo,
    )
    out_size = parse_out_size(scale.stdout)
    run(
        [
            "aiexp",
            "sprite-extractor",
            "pixelize",
            str(scratch),
            "--out-size",
            out_size,
            "--palette",
            "vinik24",
            "--fit-mode",
            "exact",
        ],
        repo,
    )

    if args.install:
        for action in actions:
            if action == "held":
                labels = HELD_LABELS
                prefix = "vp"
                extra_install_args = [f"--foot-x={HELD_FOOT_X}"]
            else:
                action_info = source_actions.get(action, {})
                if not isinstance(action_info, dict):
                    raise SystemExit(f"missing action metadata: {action}")
                labels = action_info.get("labels", [])
                prefix = str(action_info.get("pose_prefix", action))
                extra_install_args = []
            if not isinstance(labels, list) or not labels:
                raise SystemExit(f"missing labels for action: {action}")
            run(
                [
                    "./run.sh",
                    "--install-video",
                    str(scratch),
                    f"--action={action}",
                    f"--prefix={prefix}",
                    "--frames=" + ",".join(str(label) for label in labels),
                    f"--transforms={abs_path(repo, args.transforms)}",
                ]
                + extra_install_args,
                repo,
            )
        run(["./run.sh", "--import"], repo)
        run(["./run.sh", "--measure-anchors"], repo)

    print(f"scratch build ready: {scratch}")
    if not args.install:
        print("runtime art unchanged; pass --install to update sprites and hu.manifest.json")
    return 0


def run(argv: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    print("+ " + " ".join(argv))
    completed = subprocess.run(argv, cwd=cwd, text=True, capture_output=True)
    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, end="")
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)
    return completed


def parse_out_size(output: str) -> str:
    matches = OUT_SIZE_RE.findall(output)
    if not matches:
        raise SystemExit("scale_masters output did not include pixelize out-size")
    width, height = matches[-1]
    return f"{width}:{height}"


def stage_walk(repo: Path, source_actions: dict[str, Any], scratch: Path) -> None:
    action_info = source_actions.get("walk", {})
    if not isinstance(action_info, dict):
        raise SystemExit("missing action metadata: walk")
    labels = action_info.get("labels", [])
    source_labels = action_info.get("source_master_labels", labels)
    if not isinstance(labels, list) or not isinstance(source_labels, list) or len(labels) != len(source_labels):
        raise SystemExit("walk labels/source_master_labels mismatch")

    source_dir = repo / "art" / "masters" / "hu" / "normalization" / "walk" / "masters"
    staged_dir = scratch / "walk" / "masters"
    staged_dir.mkdir(parents=True)
    for index, source_label in enumerate(source_labels, start=1):
        source_stem = f"master_{source_label}"
        staged_stem = f"master_{index:03d}"
        for suffix in (".png", ".json"):
            src = source_dir / f"{source_stem}{suffix}"
            if not src.exists():
                raise SystemExit(f"missing walk source master: {src}")
            shutil.copy2(src, staged_dir / f"{staged_stem}{suffix}")


def abs_path(repo: Path, path: Path) -> str:
    return str(path if path.is_absolute() else (repo / path).resolve())


if __name__ == "__main__":
    raise SystemExit(main())
