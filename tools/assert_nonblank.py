#!/usr/bin/env python3
import argparse
import struct
import sys
import zlib


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth(left, up, upper_left):
    p = left + up - upper_left
    pa = abs(p - left)
    pb = abs(p - up)
    pc = abs(p - upper_left)
    if pa <= pb and pa <= pc:
        return left
    if pb <= pc:
        return up
    return upper_left


def _image_stats(path, max_distinct):
    with open(path, "rb") as fh:
        data = fh.read()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: not a PNG")

    pos = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    idat = bytearray()
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        chunk_type = data[pos + 4 : pos + 8]
        chunk_data = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk_data)
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None:
        raise ValueError(f"{path}: missing IHDR")
    if bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"{path}: unsupported PNG format bit_depth={bit_depth} color_type={color_type}")

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    raw = zlib.decompress(bytes(idat))
    prev = [0] * stride
    pos = 0
    distinct = set()
    total = 0
    total_sq = 0
    samples = 0

    for _y in range(height):
        filter_type = raw[pos]
        pos += 1
        scan = raw[pos : pos + stride]
        pos += stride
        row = [0] * stride
        for i, raw_value in enumerate(scan):
            left = row[i - channels] if i >= channels else 0
            up = prev[i]
            upper_left = prev[i - channels] if i >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = up
            elif filter_type == 3:
                predictor = (left + up) // 2
            elif filter_type == 4:
                predictor = _paeth(left, up, upper_left)
            else:
                raise ValueError(f"{path}: unsupported PNG filter {filter_type}")
            row[i] = (raw_value + predictor) & 0xFF

        for x in range(0, stride, channels):
            rgb = (row[x], row[x + 1], row[x + 2])
            if len(distinct) < max_distinct:
                distinct.add(rgb)
            for channel in rgb:
                total += channel
                total_sq += channel * channel
                samples += 1
        prev = row

    mean = total / float(samples)
    variance = total_sq / float(samples) - mean * mean
    return {
        "width": width,
        "height": height,
        "distinct": len(distinct),
        "variance": variance,
    }


def main():
    parser = argparse.ArgumentParser(description="Fail if a PNG is effectively a flat fill.")
    parser.add_argument("png")
    parser.add_argument("--min-colors", type=int, default=8)
    parser.add_argument("--min-variance", type=float, default=1.0)
    args = parser.parse_args()

    stats = _image_stats(args.png, args.min_colors)
    print(
        "%s: %dx%d distinct>=%d? %d variance=%.2f"
        % (args.png, stats["width"], stats["height"], args.min_colors, stats["distinct"], stats["variance"])
    )
    if stats["distinct"] < args.min_colors or stats["variance"] < args.min_variance:
        print("%s: blank/flat image detected" % args.png, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
