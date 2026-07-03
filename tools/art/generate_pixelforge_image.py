#!/usr/bin/env python3
"""Generate one Pixelforge pixel-art candidate into an explicit file path."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def load_aiexp_env() -> None:
    try:
        from aiexp_paths import load_env
    except Exception:
        return
    load_env()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--metadata", type=Path)
    parser.add_argument("--backend", default="openrouter")
    parser.add_argument("--model", default="openai/gpt-5.4-image-2")
    parser.add_argument("--palette", default="vinik24")
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--fit-mode", choices=("pad", "cover"), default="pad")
    parser.add_argument("--remove-bg", action="store_true")
    parser.add_argument("--style-preset", default="sprite-v1")
    parser.add_argument("--proxy")
    args = parser.parse_args()

    if (args.width is None) != (args.height is None):
        parser.error("--width and --height must be provided together")

    load_aiexp_env()
    api_key = os.environ.get("OPENROUTER_API_KEY") or None
    if args.backend == "openrouter" and not api_key:
        print("OPENROUTER_API_KEY is not set", file=sys.stderr)
        return 2

    from pixelforge.api import generate_pixel_image
    from pixelforge.types import PixelImageRequest

    request = PixelImageRequest(
        prompt=args.prompt,
        model=args.model,
        palette=args.palette,
        size=args.size,
        width=args.width,
        height=args.height,
        fit_mode=args.fit_mode,
        remove_bg=args.remove_bg,
        style_preset=args.style_preset,
    )
    result = generate_pixel_image(
        request,
        backend=args.backend,
        api_key=api_key,
        proxy=args.proxy,
    )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(result.png_bytes)

    metadata_path = args.metadata or args.out.with_suffix(".metadata.json")
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(
        json.dumps(
            {
                "request": request.model_dump(mode="json"),
                "backend": args.backend,
                "generator_metadata": result.generator_metadata,
                "converter_metadata": result.converter_metadata,
                "removal_metadata": result.removal_metadata,
                "fit_metadata": result.fit_metadata,
                "removal_applied": result.removal_applied,
                "transparent_fraction": result.transparent_fraction,
            },
            indent=2,
            sort_keys=True,
        ),
        encoding="utf-8",
    )

    print(f"wrote {args.out}")
    print(f"metadata {metadata_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
