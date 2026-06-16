#!/usr/bin/env python3
"""Build a static keyframe-approval page.

Usage: python3 tools/build_keyframe_review.py <candidates-root> [--out review/index.html]

Layout convention: <candidates-root>/<action>/<slot>/cand_*.png
The page is read-only; verdicts are recorded manually in
art/keyframes/keyframes.manifest.json after approval.
"""
from __future__ import annotations

import argparse
import html
import os
import pathlib
import shutil


CURRENT_ART = {
    "guard": "WUGodot/assets/sprites/characters/hu/static.png",
    "idle": "WUGodot/assets/sprites/characters/hu/idle_0.png",
    "walk": "WUGodot/assets/sprites/characters/hu/walk_0.png",
    "light": "WUGodot/assets/sprites/characters/hu/vl_051.png",
    "heavy": "WUGodot/assets/sprites/characters/hu/heavy_1.png",
    "hit": "WUGodot/assets/sprites/characters/hu/hit_0.png",
    "stunned": "WUGodot/assets/sprites/characters/hu/stunned_0.png",
    "block": "WUGodot/assets/sprites/characters/hu/block_0.png",
    "dash": "WUGodot/assets/sprites/characters/hu/dash_0.png",
    "jump": "WUGodot/assets/sprites/characters/hu/jump_0.png",
}


def figure(src: str, caption: str) -> str:
    safe_src = html.escape(src, quote=True)
    return f'<figure><img src="{safe_src}"><figcaption>{html.escape(caption)}</figcaption></figure>'


def rel_url(path: pathlib.Path, base: pathlib.Path) -> str:
    return pathlib.Path(os.path.relpath(path, base)).as_posix()


def copy_current_art(source: pathlib.Path, action: str, base: pathlib.Path) -> pathlib.Path:
    asset_dir = base / "_current"
    asset_dir.mkdir(parents=True, exist_ok=True)
    dest = asset_dir / f"{action}_{source.name}"
    shutil.copy2(source, dest)
    return dest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidates_root")
    parser.add_argument("--out", default="")
    args = parser.parse_args()

    root = pathlib.Path(args.candidates_root).resolve()
    out = pathlib.Path(args.out).resolve() if args.out else root / "index.html"
    repo = pathlib.Path(__file__).resolve().parent.parent

    rows: list[str] = []
    for action_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        for slot_dir in sorted(p for p in action_dir.iterdir() if p.is_dir()):
            cards: list[str] = []
            current = CURRENT_ART.get(action_dir.name)
            if current and (repo / current).exists():
                current_copy = copy_current_art((repo / current).resolve(), action_dir.name, out.parent)
                cards.append(figure(rel_url(current_copy, out.parent), "CURRENT in-game"))
            for candidate in sorted(slot_dir.glob("cand_*.png")):
                cards.append(figure(rel_url(candidate.resolve(), out.parent), candidate.name))
            rows.append(f"<h2>{html.escape(action_dir.name)} / {html.escape(slot_dir.name)}</h2><div class=row>{''.join(cards)}</div>")

    out.parent.mkdir(parents=True, exist_ok=True)
    body = "".join(rows)
    out.write_text(
        f"""<!doctype html><meta charset=utf-8>
<title>WU keyframe review</title>
<style>
 body {{ background:#1a1a2e; color:#eee; font-family:monospace; padding:24px }}
 .row {{ display:flex; flex-wrap:wrap; gap:16px; margin-bottom:28px }}
 figure {{ margin:0; text-align:center }}
 img {{ image-rendering:pixelated; height:340px; background:
       repeating-conic-gradient(#333 0% 25%, #2a2a3e 0% 50%) 0 0/24px 24px }}
 figcaption {{ margin-top:8px; color:#d8caa0 }}
</style>
<h1>Keyframe review</h1>
<p>Verdict per slot in chat: approve cand_N, or redo with notes.</p>
{body}"""
    )
    print(f"wrote {out} — serve with: python3 -m http.server -d {out.parent} 8765")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
