#!/usr/bin/env python3
"""Shared helpers for Hu frame-normalization tooling."""

from __future__ import annotations

import base64
import json
import math
import statistics
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
ALPHA_MIN = 16


@dataclass(frozen=True)
class PngAlpha:
    path: Path
    width: int
    height: int
    alpha: bytes

    def opaque(self, x: int, y: int) -> bool:
        return self.alpha[y * self.width + x] > ALPHA_MIN

    def data_url(self) -> str:
        encoded = base64.b64encode(self.path.read_bytes()).decode("ascii")
        return f"data:image/png;base64,{encoded}"


def load_json(path: Path) -> dict[str, Any]:
    with path.open() as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"expected object JSON: {path}")
    return data


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")


def decode_png_alpha(path: Path) -> PngAlpha:
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
            if interlace != 0:
                raise ValueError(f"interlaced PNG unsupported: {path}")
            if bit_depth != 8:
                raise ValueError(f"PNG bit depth {bit_depth} unsupported: {path}")
        elif ctype == b"PLTE":
            palette = [
                (payload[i], payload[i + 1], payload[i + 2])
                for i in range(0, len(payload), 3)
            ]
        elif ctype == b"tRNS":
            transparency = payload
        elif ctype == b"IDAT":
            idat.extend(payload)
        elif ctype == b"IEND":
            break

    if width is None or height is None or bit_depth is None or color_type is None:
        raise ValueError(f"missing IHDR: {path}")

    channels_by_type = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
    if color_type not in channels_by_type:
        raise ValueError(f"PNG color type {color_type} unsupported: {path}")
    channels = channels_by_type[color_type]
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
        _unfilter(row, prev, channels, filter_type)
        rows.append(row)
        prev = row

    alpha = bytearray(width * height)
    for y, row in enumerate(rows):
        for x in range(width):
            if color_type == 6:
                a = row[x * 4 + 3]
            elif color_type == 4:
                a = row[x * 2 + 1]
            elif color_type == 3:
                index = row[x]
                a = transparency[index] if index < len(transparency) else 255
            else:
                a = 255
            alpha[y * width + x] = a
    return PngAlpha(path=path, width=width, height=height, alpha=bytes(alpha))


def _unfilter(row: bytearray, prev: bytearray, bpp: int, filter_type: int) -> None:
    if filter_type == 0:
        return
    if filter_type == 1:
        for i in range(len(row)):
            row[i] = (row[i] + (row[i - bpp] if i >= bpp else 0)) & 0xFF
        return
    if filter_type == 2:
        for i in range(len(row)):
            row[i] = (row[i] + prev[i]) & 0xFF
        return
    if filter_type == 3:
        for i in range(len(row)):
            left = row[i - bpp] if i >= bpp else 0
            up = prev[i]
            row[i] = (row[i] + ((left + up) // 2)) & 0xFF
        return
    if filter_type == 4:
        for i in range(len(row)):
            left = row[i - bpp] if i >= bpp else 0
            up = prev[i]
            up_left = prev[i - bpp] if i >= bpp else 0
            row[i] = (row[i] + _paeth(left, up, up_left)) & 0xFF
        return
    raise ValueError(f"unsupported PNG filter: {filter_type}")


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def measure_alpha(path: Path) -> dict[str, Any]:
    img = decode_png_alpha(path)
    bbox = alpha_bbox(img)
    if bbox[2] <= 0 or bbox[3] <= 0:
        return {
            "path": str(path),
            "size": [img.width, img.height],
            "bbox": [0, 0, 0, 0],
            "headBBox": [0, 0, 0, 0],
            "headHeight": 0,
            "contactFoot": [img.width * 0.5, img.height - 1],
            "confidence": 0.0,
            "flags": ["empty-alpha"],
        }

    col_count = [0] * img.width
    col_top = [-1] * img.width
    col_bot = [-1] * img.width
    left, top, width, height = bbox
    bottom = top + height - 1
    for y in range(top, bottom + 1):
        base = y * img.width
        for x in range(left, left + width):
            if img.alpha[base + x] > ALPHA_MIN:
                col_count[x] += 1
                if col_top[x] < 0:
                    col_top[x] = y
                col_bot[x] = y

    body_threshold = max(8, int(round(height * 0.25)))
    body_cols = [x for x in range(left, left + width) if col_count[x] >= body_threshold]
    flags: list[str] = []
    if body_cols:
        body_left = min(body_cols)
        body_right = max(body_cols)
        body_top = min(col_top[x] for x in body_cols if col_top[x] >= 0)
        body_bot = max(col_bot[x] for x in body_cols)
    else:
        flags.append("body-columns-fallback")
        body_left = left
        body_right = left + width - 1
        body_top = top
        body_bot = bottom

    foot_x, foot_y, foot_flags = contact_foot(img, body_left, body_right, bottom)
    flags.extend(foot_flags)

    head_bbox, head_flags, confidence = detect_head(img, body_left, body_right, body_top, body_bot)
    flags.extend(head_flags)
    return {
        "path": str(path),
        "size": [img.width, img.height],
        "bbox": [left, top, width, height],
        "bodyColumns": [body_left, body_right],
        "headBBox": list(head_bbox),
        "headHeight": head_bbox[3],
        "contactFoot": [round(foot_x, 3), round(foot_y, 3)],
        "confidence": round(confidence, 3),
        "flags": sorted(set(flags)),
    }


def alpha_bbox(img: PngAlpha) -> tuple[int, int, int, int]:
    left = img.width
    right = -1
    top = img.height
    bottom = -1
    for y in range(img.height):
        base = y * img.width
        for x in range(img.width):
            if img.alpha[base + x] > ALPHA_MIN:
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
    if right < 0:
        return (0, 0, 0, 0)
    return (left, top, right - left + 1, bottom - top + 1)


def contact_foot(img: PngAlpha, body_left: int, body_right: int, bottom: int) -> tuple[float, float, list[str]]:
    flags: list[str] = []
    xs: list[int] = []
    foot_y = bottom
    for y in range(bottom, max(-1, bottom - 6), -1):
        row_xs = [
            x
            for x in range(body_left, body_right + 1)
            if 0 <= x < img.width and img.alpha[y * img.width + x] > ALPHA_MIN
        ]
        if row_xs:
            xs = row_xs
            foot_y = y
            break
    if not xs:
        flags.append("foot-fallback-bbox")
        return ((body_left + body_right) * 0.5, float(bottom), flags)
    return (statistics.fmean(xs), float(foot_y), flags)


def detect_head(
    img: PngAlpha, body_left: int, body_right: int, body_top: int, body_bot: int
) -> tuple[tuple[int, int, int, int], list[str], float]:
    flags: list[str] = []
    if body_bot <= body_top:
        return ((body_left, body_top, max(1, body_right - body_left + 1), 1), ["head-fallback-empty"], 0.0)

    body_h = body_bot - body_top + 1
    scan_bottom = min(body_bot, body_top + max(12, int(round(body_h * 0.42))))
    row_widths: dict[int, int] = {}
    occupied_rows: list[int] = []
    for y in range(body_top, scan_bottom + 1):
        width = 0
        for x in range(body_left, body_right + 1):
            if img.alpha[y * img.width + x] > ALPHA_MIN:
                width += 1
        row_widths[y] = width
        if width > 0:
            occupied_rows.append(y)

    if not occupied_rows:
        return ((body_left, body_top, max(1, body_right - body_left + 1), max(1, int(body_h * 0.16))), ["head-fallback-no-rows"], 0.1)

    head_top = occupied_rows[0]
    initial_rows = [row_widths[y] for y in occupied_rows[: min(6, len(occupied_rows))] if row_widths[y] > 0]
    initial = statistics.median(initial_rows) if initial_rows else 1.0
    upper_max = max(row_widths[y] for y in occupied_rows)
    threshold = max(initial * 1.55, upper_max * 0.58)
    min_head_h = max(12, int(round(body_h * 0.20)))
    head_bottom = -1
    for y in occupied_rows:
        if y < head_top + min_head_h:
            continue
        window = [row_widths.get(k, 0) for k in range(y, min(scan_bottom, y + 2) + 1)]
        if statistics.fmean(window) >= threshold:
            head_bottom = max(head_top, y - 1)
            break

    if head_bottom < 0:
        flags.append("head-fallback-proportional")
        head_bottom = min(body_bot, head_top + max(12, int(round(body_h * 0.27))))
        confidence = 0.35
    else:
        confidence = 0.82

    xs: list[int] = []
    ys: list[int] = []
    for y in range(head_top, head_bottom + 1):
        for x in range(body_left, body_right + 1):
            if img.alpha[y * img.width + x] > ALPHA_MIN:
                xs.append(x)
                ys.append(y)
    if not xs:
        flags.append("head-fallback-empty-region")
        return ((body_left, head_top, max(1, body_right - body_left + 1), max(1, head_bottom - head_top + 1)), flags, 0.2)

    head_left = min(xs)
    head_right = max(xs)
    head_top = min(ys)
    head_bottom = max(ys)
    head_w = head_right - head_left + 1
    head_h = head_bottom - head_top + 1
    if head_h < max(8, body_h * 0.14):
        flags.append("head-small")
        confidence = min(confidence, 0.45)
    if head_h > body_h * 0.38:
        flags.append("head-large")
        confidence = min(confidence, 0.45)
    return ((head_left, head_top, head_w, head_h), flags, confidence)


def median(values: list[float], fallback: float = 0.0) -> float:
    clean = [v for v in values if math.isfinite(v)]
    if not clean:
        return fallback
    return float(statistics.median(clean))
