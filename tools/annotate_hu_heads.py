#!/usr/bin/env python3
"""Generate bootstrap head annotations for Hu normalization.

This writes the same schema expected from a vision pass. The bootstrap uses
face-colored connected components to locate the head in installed render
sprites, then snaps the box to nearby opaque pixels. A true VLM/manual pass can
replace this file without changing measurement or solving code.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from collections import deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from hu_normalization_lib import load_json, measure_alpha, write_json


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
ALPHA_MIN = 16


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("WUGodot/assets/animation_manifests/hu.manifest.json"),
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("art/masters/hu/normalization/vision_heads.json"),
    )
    args = parser.parse_args()

    repo = Path.cwd()
    manifest = load_json(args.manifest)
    poses = manifest.get("poses", {})
    if not isinstance(poses, dict):
        raise ValueError("manifest poses must be an object")

    annotations: dict[str, dict[str, Any]] = {}
    seen_paths: set[str] = set()
    for pose_name in sorted(poses):
        entry = poses[pose_name]
        if not isinstance(entry, dict) or not pose_name.startswith("v"):
            continue
        render_key = str(entry.get("path", ""))
        if render_key in seen_paths:
            continue
        seen_paths.add(render_key)
        render_path = repo / render_key.replace("res://", "WUGodot/")
        if not render_path.exists():
            continue
        annotations[pose_name] = annotate_one(render_path)

    out = {
        "id": "hu_vision_head_annotations",
        "generated": datetime.now(timezone.utc).isoformat(),
        "provider": "local_face_color_component_bootstrap",
        "coordinateSpace": "render",
        "annotations": annotations,
    }
    write_json(args.out, out)
    clean = sum(1 for item in annotations.values() if bool(item.get("clean", False)))
    print(f"wrote {args.out} annotations={len(annotations)} clean={clean}")
    return 0


def annotate_one(path: Path) -> dict[str, Any]:
    img = decode_rgba(path)
    alpha = [(a > ALPHA_MIN) for _r, _g, _b, a in img["pixels"]]
    skin = skin_components(img)
    alpha_bbox = bbox_for_indices(alpha, img["width"], img["height"])
    if not skin:
        fallback = proportional_fallback(alpha_bbox)
        return annotation(fallback, fallback, False, 0.35, "no skin component", path)

    comp = choose_head_component(skin, alpha_bbox)
    geometric = measure_alpha(path).get("headBBox", [0, 0, 0, 0])
    face_box = comp["bbox"]
    if is_usable_geometric_head(geometric, face_box):
        snapped = tuple(int(round(v)) for v in geometric[:4])
        return annotation(snapped, snapped, True, 0.96, "vision-selected geometric head bbox", path)

    vision_box = bounded_head_box(face_box, img["width"], img["height"])
    snapped = snap_connected_alpha(alpha, img["width"], img["height"], vision_box, face_box)
    if not usable_head_dimensions(snapped):
        snapped = vision_box
    width, height = snapped[2], snapped[3]
    aspect = width / max(height, 1)
    occluded = not usable_head_dimensions(snapped)
    confidence = 0.91 if not occluded else 0.72
    notes = "vision face component, alpha-snapped head"
    if occluded:
        notes = f"review: snapped head unusual w={width} h={height} aspect={aspect:.2f}"
    return annotation(snapped, vision_box, not occluded, confidence, notes, path)


def annotation(
    bbox: tuple[int, int, int, int],
    vision_box: tuple[int, int, int, int],
    clean: bool,
    confidence: float,
    notes: str,
    path: Path,
) -> dict[str, Any]:
    return {
        "bbox": list(bbox),
        "visionBox": list(vision_box),
        "clean": clean,
        "occluded": not clean,
        "confidence": round(confidence, 3),
        "provider": "local_face_color_component_bootstrap",
        "notes": notes,
        "path": path.as_posix(),
    }


def skin_components(img: dict[str, Any]) -> list[dict[str, Any]]:
    width = img["width"]
    height = img["height"]
    pixels = img["pixels"]
    mask = bytearray(width * height)
    for i, (r, g, b, a) in enumerate(pixels):
        if a > ALPHA_MIN and is_skin(r, g, b):
            mask[i] = 1
    seen = bytearray(width * height)
    out: list[dict[str, Any]] = []
    for idx, value in enumerate(mask):
        if value == 0 or seen[idx]:
            continue
        q: deque[int] = deque([idx])
        seen[idx] = 1
        xs: list[int] = []
        ys: list[int] = []
        while q:
            cur = q.popleft()
            x = cur % width
            y = cur // width
            xs.append(x)
            ys.append(y)
            for ny in range(max(0, y - 1), min(height - 1, y + 1) + 1):
                for nx in range(max(0, x - 1), min(width - 1, x + 1) + 1):
                    ni = ny * width + nx
                    if mask[ni] and not seen[ni]:
                        seen[ni] = 1
                        q.append(ni)
        if len(xs) < 8:
            continue
        out.append(
            {
                "area": len(xs),
                "bbox": (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1),
                "center": (sum(xs) / len(xs), sum(ys) / len(ys)),
            }
        )
    return out


def is_skin(r: int, g: int, b: int) -> bool:
    if (r, g, b) in {(244, 158, 76), (223, 113, 38), (171, 82, 54)}:
        return True
    return r >= 150 and g >= 65 and b <= 125 and r > g * 1.18 and g > b * 1.05


def choose_head_component(components: list[dict[str, Any]], alpha_bbox: tuple[int, int, int, int]) -> dict[str, Any]:
    ax, ay, aw, ah = alpha_bbox
    upper_limit = ay + ah * 0.75
    plausible = [
        c
        for c in components
        if c["bbox"][1] <= upper_limit and c["area"] >= 18 and c["bbox"][2] >= 8 and c["bbox"][3] >= 8
    ]
    if not plausible:
        plausible = components
    alpha_center = ax + aw * 0.5
    return max(
        plausible,
        key=lambda c: (
            min(float(c["area"]), 700.0) * 1.0
            - abs(float(c["center"][0]) - alpha_center) * 0.35
            - max(0.0, float(c["bbox"][1]) - (ay + ah * 0.65)) * 0.5
        ),
    )


def is_usable_geometric_head(values: Any, face_box: tuple[int, int, int, int]) -> bool:
    if not isinstance(values, list) or len(values) < 4:
        return False
    head = tuple(int(round(float(v))) for v in values[:4])
    if not usable_head_dimensions(head):
        return False
    hx, hy, hw, hh = head
    fx, fy, fw, fh = face_box
    face_center_x = fx + fw * 0.5
    face_center_y = fy + fh * 0.5
    contains_face_center = hx <= face_center_x <= hx + hw and hy <= face_center_y <= hy + hh
    plausible_top = 8 <= fy - hy <= 30
    plausible_bottom = hy + hh <= fy + fh + 22
    return contains_face_center and plausible_top and plausible_bottom


def usable_head_dimensions(box: tuple[int, int, int, int]) -> bool:
    _x, _y, width, height = box
    if width < 34 or width > 60:
        return False
    if height < 30 or height > 68:
        return False
    aspect = width / max(height, 1)
    return 0.58 <= aspect <= 1.75


def bounded_head_box(face_box: tuple[int, int, int, int], width: int, height: int) -> tuple[int, int, int, int]:
    x, y, w, h = face_box
    left = clamp(round(w * 0.42), 8, 14)
    right = clamp(round(w * 0.26), 6, 12)
    top = clamp(round(h * 0.55), 14, 24)
    bottom = clamp(round(h * 0.12), 3, 8)
    nx = max(0, x - left)
    ny = max(0, y - top)
    nr = min(width, x + w + right)
    nb = min(height, y + h + bottom)
    return (nx, ny, nr - nx, nb - ny)


def clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def snap_connected_alpha(
    mask: list[bool],
    width: int,
    height: int,
    box: tuple[int, int, int, int],
    seed_box: tuple[int, int, int, int],
) -> tuple[int, int, int, int]:
    bx, by, bw, bh = box
    sx, sy, sw, sh = seed_box
    x0 = max(bx, sx)
    y0 = max(by, sy)
    x1 = min(bx + bw, sx + sw)
    y1 = min(by + bh, sy + sh)
    seeds = [
        y * width + x
        for y in range(y0, y1)
        for x in range(x0, x1)
        if mask[y * width + x]
    ]
    if not seeds:
        return box

    seen: set[int] = set(seeds)
    q: deque[int] = deque(seeds)
    left = width
    right = -1
    top = height
    bottom = -1
    while q:
        cur = q.popleft()
        x = cur % width
        y = cur // width
        left = min(left, x)
        right = max(right, x)
        top = min(top, y)
        bottom = max(bottom, y)
        for ny in range(max(by, y - 1), min(by + bh - 1, y + 1) + 1):
            for nx in range(max(bx, x - 1), min(bx + bw - 1, x + 1) + 1):
                ni = ny * width + nx
                if ni not in seen and mask[ni]:
                    seen.add(ni)
                    q.append(ni)
    if right < 0:
        return box
    return (left, top, right - left + 1, bottom - top + 1)


def bbox_for_indices(mask: list[bool], width: int, height: int) -> tuple[int, int, int, int]:
    left = width
    right = -1
    top = height
    bottom = -1
    for y in range(height):
        for x in range(width):
            if mask[y * width + x]:
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
    if right < 0:
        return (0, 0, width, height)
    return (left, top, right - left + 1, bottom - top + 1)


def proportional_fallback(alpha_bbox: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x, y, w, h = alpha_bbox
    size = max(20, int(round(h * 0.23)))
    return (int(round(x + w * 0.35)), y, size, size)


def decode_rgba(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    if not raw.startswith(PNG_SIGNATURE):
        raise ValueError(f"not a PNG: {path}")
    pos = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    palette: list[tuple[int, int, int]] = []
    transparency = b""
    idat = bytearray()
    while pos + 8 <= len(raw):
        length = struct.unpack(">I", raw[pos : pos + 4])[0]
        ctype = raw[pos + 4 : pos + 8]
        payload = raw[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if interlace != 0 or bit_depth != 8:
                raise ValueError(f"unsupported PNG encoding: {path}")
        elif ctype == b"PLTE":
            palette = [tuple(payload[i : i + 3]) for i in range(0, len(payload), 3)]
        elif ctype == b"tRNS":
            transparency = payload
        elif ctype == b"IDAT":
            idat.extend(payload)
        elif ctype == b"IEND":
            break
    if width is None or height is None or color_type is None:
        raise ValueError(f"missing PNG header: {path}")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    stride = width * channels
    inflated = zlib.decompress(bytes(idat))
    rows: list[bytearray] = []
    cursor = 0
    prev = bytearray(stride)
    for _y in range(height):
        filter_type = inflated[cursor]
        cursor += 1
        row = bytearray(inflated[cursor : cursor + stride])
        cursor += stride
        unfilter(row, prev, channels, filter_type)
        rows.append(row)
        prev = row
    pixels: list[tuple[int, int, int, int]] = []
    for row in rows:
        for x in range(width):
            if color_type == 6:
                r, g, b, a = row[x * 4 : x * 4 + 4]
            elif color_type == 2:
                r, g, b = row[x * 3 : x * 3 + 3]
                a = 255
            elif color_type == 3:
                index = row[x]
                r, g, b = palette[index]
                a = transparency[index] if index < len(transparency) else 255
            elif color_type == 4:
                gray, a = row[x * 2 : x * 2 + 2]
                r = g = b = gray
            else:
                gray = row[x]
                r = g = b = gray
                a = 255
            pixels.append((r, g, b, a))
    return {"width": width, "height": height, "pixels": pixels}


def unfilter(row: bytearray, prev: bytearray, bpp: int, filter_type: int) -> None:
    if filter_type == 0:
        return
    for i in range(len(row)):
        left = row[i - bpp] if i >= bpp else 0
        up = prev[i]
        up_left = prev[i - bpp] if i >= bpp else 0
        if filter_type == 1:
            value = left
        elif filter_type == 2:
            value = up
        elif filter_type == 3:
            value = (left + up) // 2
        elif filter_type == 4:
            value = paeth(left, up, up_left)
        else:
            raise ValueError(f"unsupported PNG filter {filter_type}")
        row[i] = (row[i] + value) & 0xFF


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


if __name__ == "__main__":
    raise SystemExit(main())
