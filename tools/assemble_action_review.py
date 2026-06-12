#!/usr/bin/env python3
"""Assemble --shot-action output into review artifacts.

Usage: python3 tools/assemble_action_review.py /tmp/wu-shot-action
Emits in the same dir: action.gif (gameplay speed) and strip.png
(phase-marked contact sheet, 12 columns). Requires ffmpeg on PATH.
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: assemble_action_review.py <shot-action-dir>", file=sys.stderr)
        return 1

    shot_dir = pathlib.Path(sys.argv[1])
    phases = json.loads((shot_dir / "phases.json").read_text())
    frames = sorted(shot_dir.glob("frame_*.png"))
    expected = int(phases["frames"])
    if len(frames) != expected:
        raise SystemExit(f"expected {expected} frames, found {len(frames)}")

    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-framerate",
            str(phases["fps"]),
            "-i",
            str(shot_dir / "frame_%03d.png"),
            "-vf",
            "split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse",
            str(shot_dir / "action.gif"),
        ],
        check=True,
        capture_output=True,
    )

    cols = 12
    picks = [frames[round(i * (len(frames) - 1) / (cols - 1))] for i in range(cols)]
    windup_end = int(phases.get("windup_end_frame", -1))
    active_end = int(phases.get("active_end_frame", -1))
    inputs: list[str] = []
    filters: list[str] = []
    for i, frame_path in enumerate(picks):
        frame_idx = round(i * (len(frames) - 1) / (cols - 1))
        color = "white"
        if windup_end >= 0:
            color = "yellow" if frame_idx < windup_end else ("red" if frame_idx <= active_end else "cyan")
        inputs += ["-i", str(frame_path)]
        filters.append(f"[{i}:v]scale=320:-1,pad=326:ih+6:3:3:{color}[f{i}]")

    chain = "".join(f"[f{i}]" for i in range(cols))
    filters.append(f"{chain}hstack=inputs={cols}[out]")
    subprocess.run(
        ["ffmpeg", "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[out]", str(shot_dir / "strip.png")],
        check=True,
        capture_output=True,
    )
    print(f"wrote {shot_dir / 'action.gif'} and {shot_dir / 'strip.png'} (yellow=windup red=active cyan=recovery)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
