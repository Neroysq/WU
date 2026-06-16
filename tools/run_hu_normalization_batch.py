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


SUPPORTED_VIDEO_ACTIONS = {"entry", "light", "heavy"}
OUT_SIZE_RE = re.compile(r"out-size for pixelize:\s*(\d+):(\d+)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actions", required=True, help="comma-separated action names: entry,light,heavy")
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
    unsupported = [a for a in actions if a not in SUPPORTED_VIDEO_ACTIONS]
    if unsupported:
        raise SystemExit(
            "unsupported actions for this runner: %s (supported: %s)"
            % (",".join(unsupported), ",".join(sorted(SUPPORTED_VIDEO_ACTIONS)))
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
            action_info = source_actions.get(action, {})
            if not isinstance(action_info, dict):
                raise SystemExit(f"missing action metadata: {action}")
            labels = action_info.get("labels", [])
            prefix = str(action_info.get("pose_prefix", action))
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
                ],
                repo,
            )
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


def abs_path(repo: Path, path: Path) -> str:
    return str(path if path.is_absolute() else (repo / path).resolve())


if __name__ == "__main__":
    raise SystemExit(main())
