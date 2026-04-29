#!/usr/bin/env python3
"""Install WU 256-native character regen output into the Godot project.

The tool expects aiexp sprite-extractor output with action directories such as:

    /tmp/wu_regen_256/hu/run/walk-cycle/frames/frame_001.png

It copies the PNG slots expected by the current animation JSONs and updates
WUGodot/data/VisualProfiles/DefaultProfiles.json scale/yOffset values.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
import sys
import zlib
from pathlib import Path
from typing import Iterable


ActionSlots = dict[str, list[str]]


CHARACTERS = {
    "hu": {
        "profile": "player_humanoid",
        "scale": 1.625,
        "actions": {
            "walk-cycle": ["walk_0.png", "walk_1.png", "walk_2.png", "walk_3.png"],
            "idle": ["idle_0.png", "idle_1.png"],
            "attack-windup": ["attack_0.png", "attack_1.png"],
            "attack-strike": ["attack_2.png"],
            "attack-recovery": ["attack_3.png"],
            "block": ["block_0.png", "block_1.png"],
            "hit-react": ["hit_0.png", "hit_1.png"],
            "stunned": ["stunned_0.png", "stunned_1.png"],
            "dash": ["dash_0.png", "dash_1.png"],
            "jump": ["jump_0.png", "jump_1.png", "jump_2.png"],
        },
    },
    "bandit_sword": {
        "profile": "enemy_humanoid_basic",
        "scale": 1.575,
        "actions": None,
    },
    "bandit_spear": {
        "profile": "enemy_humanoid_basic_spear",
        "scale": 1.575,
        "actions": None,
    },
    "ronin": {
        "profile": "enemy_humanoid_ronin",
        "scale": 1.625,
        "actions": None,
    },
    "disciple": {
        "profile": "enemy_humanoid_elite",
        "scale": 1.675,
        "actions": None,
    },
    "assassin": {
        "profile": "enemy_humanoid_assassin",
        "scale": 1.675,
        "actions": None,
    },
    "iron_bear": {
        "profile": "enemy_humanoid_boss",
        "scale": 1.775,
        "actions": None,
    },
}

ENEMY_ACTIONS = {
    "walk-cycle": ["walk_0.png", "walk_1.png", "walk_2.png", "walk_3.png"],
    "idle": ["idle_0.png", "idle_1.png"],
    "attack-windup": ["attack_0.png", "attack_1.png"],
    "attack-strike": ["attack_2.png"],
    "attack-recovery": ["attack_3.png"],
    "block": ["block_0.png", "block_1.png"],
    "hit-react": ["hit_0.png", "hit_1.png"],
    "stunned": ["stunned_0.png", "stunned_1.png"],
}

for config in CHARACTERS.values():
    if config["actions"] is None:
        config["actions"] = ENEMY_ACTIONS


class InstallError(RuntimeError):
    pass


def read_png(path: Path) -> tuple[int, int, int, int, bytes, dict[str, bytes]]:
    with path.open("rb") as handle:
        if handle.read(8) != b"\x89PNG\r\n\x1a\n":
            raise InstallError(f"{path} is not a PNG")
        chunks: dict[str, list[bytes]] = {}
        width = height = bit_depth = color_type = -1
        while True:
            length_raw = handle.read(4)
            if not length_raw:
                break
            length = struct.unpack(">I", length_raw)[0]
            chunk_type = handle.read(4).decode("ascii")
            data = handle.read(length)
            handle.read(4)
            chunks.setdefault(chunk_type, []).append(data)
            if chunk_type == "IHDR":
                width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", data)
                if bit_depth != 8:
                    raise InstallError(f"{path} uses unsupported PNG bit depth {bit_depth}")
                if interlace != 0:
                    raise InstallError(f"{path} uses unsupported interlacing")
            if chunk_type == "IEND":
                break
    if width < 0:
        raise InstallError(f"{path} has no IHDR")
    return width, height, bit_depth, color_type, b"".join(chunks.get("IDAT", [])), {
        key: value[0] for key, value in chunks.items() if value
    }


def png_size(path: Path) -> tuple[int, int]:
    width, height, _, _, _, _ = read_png(path)
    return width, height


def unfilter_rows(path: Path) -> tuple[int, int, int, list[bytes]]:
    width, height, _, color_type, idat, _ = read_png(path)
    bpp_by_color_type = {
        0: 1,
        2: 3,
        3: 1,
        4: 2,
        6: 4,
    }
    if color_type not in bpp_by_color_type:
        raise InstallError(f"{path} uses unsupported PNG color type {color_type}")
    bpp = bpp_by_color_type[color_type]
    stride = width * bpp
    raw = zlib.decompress(idat)
    rows: list[bytes] = []
    offset = 0
    prev = bytearray(stride)
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        scan = bytearray(raw[offset : offset + stride])
        offset += stride
        for i in range(stride):
            left = scan[i - bpp] if i >= bpp else 0
            up = prev[i]
            up_left = prev[i - bpp] if i >= bpp else 0
            if filter_type == 0:
                value = scan[i]
            elif filter_type == 1:
                value = scan[i] + left
            elif filter_type == 2:
                value = scan[i] + up
            elif filter_type == 3:
                value = scan[i] + ((left + up) // 2)
            elif filter_type == 4:
                value = scan[i] + paeth(left, up, up_left)
            else:
                raise InstallError(f"{path} uses unsupported PNG filter {filter_type}")
            scan[i] = value & 0xFF
        rows.append(bytes(scan))
        prev = scan
    return width, height, color_type, rows


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def bottom_padding(path: Path) -> int:
    width, height, color_type, rows = unfilter_rows(path)
    if color_type == 6:
        bpp = 4
        alpha_index = 3
    elif color_type == 4:
        bpp = 2
        alpha_index = 1
    else:
        return 0
    bottom = -1
    for y, row in enumerate(rows):
        for x in range(width):
            if row[x * bpp + alpha_index] > 0:
                bottom = y
                break
    if bottom < 0:
        raise InstallError(f"{path} is fully transparent")
    return height - 1 - bottom


def source_dirs(stage: Path) -> list[Path]:
    run_dirs = [path for path in stage.iterdir() if path.is_dir() and path.name.startswith("run")]
    run_dirs.sort(key=lambda path: (path.stat().st_mtime_ns, path.name), reverse=True)
    return run_dirs + [stage]


def sample_indices(src_n: int, wu_n: int) -> list[int]:
    """Pick wu_n evenly spaced 0-based indices from src_n source frames."""
    if src_n < wu_n:
        raise InstallError(f"cannot fill {wu_n} WU slots from {src_n} source frame(s)")
    if wu_n == 1:
        return [0]
    if src_n == wu_n:
        return list(range(src_n))
    return [round(i * (src_n - 1) / (wu_n - 1)) for i in range(wu_n)]


def find_static(stage: Path) -> Path:
    candidates = [
        stage / "static.png",
        stage / "run" / "static" / "frames" / "frame_001.png",
        stage / "run" / "remove-bg" / "character_transparent.png",
        stage / "run" / "input_character.png",
    ]
    for path in candidates:
        if path.exists():
            return path
    raise InstallError(f"missing static PNG under {stage}")


def find_action_frames(stage: Path, action: str) -> list[Path]:
    for base in source_dirs(stage):
        frames = sorted((base / action / "frames").glob("frame_*.png"))
        if frames:
            return frames
        converted = sorted((base / action / "convert").glob("pixel_*.png"))
        if converted:
            return converted
    raise InstallError(f"missing {action} frames under {stage}")


def selected_action_frames(stage: Path, action: str, dest_names: list[str]) -> list[tuple[str, Path]]:
    source_frames = find_action_frames(stage, action)
    indices = sample_indices(len(source_frames), len(dest_names))
    return [(dest_name, source_frames[index]) for dest_name, index in zip(dest_names, indices)]


def copy_png(src: Path, dest: Path, dry_run: bool) -> None:
    size = png_size(src)
    if size != (256, 256):
        raise InstallError(f"{src} is {size[0]}x{size[1]}, expected 256x256")
    if dry_run:
        print(f"copy {src} -> {dest}")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)


def install_character(project: Path, source_root: Path, character: str, dry_run: bool) -> float:
    config = CHARACTERS[character]
    stage = source_root / character
    if not stage.exists():
        stage = source_root
    dest_dir = project / "assets" / "sprites" / "characters" / character
    if not dest_dir.exists():
        raise InstallError(f"missing destination directory {dest_dir}")

    static_src = find_static(stage)
    copy_png(static_src, dest_dir / "static.png", dry_run)
    actions: ActionSlots = config["actions"]
    for action, dest_names in actions.items():
        for dest_name, src in selected_action_frames(stage, action, dest_names):
            copy_png(src, dest_dir / dest_name, dry_run)

    scale = float(config["scale"])
    y_offset = round(bottom_padding(static_src) * scale, 3)
    print(f"{character}: scale={scale}, yOffset={y_offset}")
    return y_offset


def update_profiles(project: Path, y_offsets: dict[str, float], dry_run: bool) -> None:
    profiles_path = project / "data" / "VisualProfiles" / "DefaultProfiles.json"
    data = json.loads(profiles_path.read_text())
    by_profile = {config["profile"]: (name, config) for name, config in CHARACTERS.items()}
    for profile in data["profiles"]:
        profile_id = profile["id"]
        if profile_id not in by_profile:
            continue
        character, config = by_profile[profile_id]
        if character not in y_offsets:
            continue
        profile["scale"] = float(config["scale"])
        profile["yOffset"] = y_offsets[character]
    if dry_run:
        print(f"would update {profiles_path}")
        return
    text = json.dumps(data, indent=2)
    text = re.sub(
        r"\[\n\s+(-?\d+(?:\.\d+)?),\n\s+(-?\d+(?:\.\d+)?)\n\s+\]",
        r"[\1, \2]",
        text,
    )
    profiles_path.write_text(text + "\n")


def parse_characters(value: str) -> list[str]:
    if value == "all":
        return list(CHARACTERS.keys())
    characters = [item.strip() for item in value.split(",") if item.strip()]
    unknown = [item for item in characters if item not in CHARACTERS]
    if unknown:
        raise InstallError(f"unknown character(s): {', '.join(unknown)}")
    return characters


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True, type=Path, help="Staged aiexp output root.")
    parser.add_argument("--project", default=Path("WUGodot"), type=Path, help="Godot project directory.")
    parser.add_argument("--characters", default="all", help="'all' or comma-separated character ids.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(list(argv))

    project = args.project.resolve()
    source_root = args.source_root.resolve()
    y_offsets: dict[str, float] = {}
    for character in parse_characters(args.characters):
        y_offsets[character] = install_character(project, source_root, character, args.dry_run)
    update_profiles(project, y_offsets, args.dry_run)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except InstallError as exc:
        print(f"install_regen_256.py: error: {exc}", file=sys.stderr)
        raise SystemExit(1)
