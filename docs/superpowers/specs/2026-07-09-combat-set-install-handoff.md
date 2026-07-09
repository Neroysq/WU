# Combat Set Install — Implementer Handoff (rev 2)

**Date:** 2026-07-09 (rev 2 after review findings — all six verified in code and fixed below)
**All art user-approved** — provenance rows for all five clips now in `art/canon/canon.manifest.json`
(incl. `hu_clip_heavy` / `hu_clip_deflect`, approved via the 2026-07-08 board pass; set closed 2026-07-09).

## 1. Per-asset mirror table (replaces the old "batch mirror ALL" wording)

"Final facing" = LEFT (the on-screen player convention: player right, faces left, blade viewer-side).

| asset | source path | current facing | action | install path |
|---|---|---|---|---|
| k1–k4, k7 pins | `art/canon/hu/k{1,2,3,4,7}.png` | RIGHT | **mirror** | install-time copy only (canon keeps stored facing) |
| k5, k6 pins | `art/canon/hu/k{5,6}.png` | LEFT (manifest: mirror pass) | **no-op** | same |
| light clip | `art/canon/hu/clips/attack_light/f*.png` | RIGHT | **mirror** | game sprites dir |
| heavy clip | `art/canon/candidates/hu/clips/heavy/v2/f*.png` | RIGHT | **mirror** | promote → `art/canon/hu/clips/attack_heavy/` + game |
| deflect clip | `art/canon/candidates/hu/clips/block/f*.png` | RIGHT | **mirror** | promote → `art/canon/hu/clips/guard_deflect/` + game |
| jump clip | `art/canon/candidates/hu/clips/jump/v7-noflip/f*.png` | RIGHT | **mirror** | promote → `art/canon/hu/clips/jump/` + game |
| back-dash clip | `art/canon/hu/clips/dash/f*.png` | LEFT already | **no-op** | game |

Rule of thumb: everything whose guard frames face right mirrors once; k5/k6 and the dash clip
are already left-facing (their manifest notes say so). Canon files stay in their stored facing —
mirroring happens in the install copy step, so canon remains the generation-facing record.

## 2. Player render-facing (the presenter DOES flip — this must change)

`fighter_presenter.gd` multiplies by gameplay facing in THREE places (`sx`, `rotation_rad`,
`off_x` — lines ~184-188). With left-baked art and `_player.facing = -1`, the current code
flips it back to right-facing. Fix (generalizes cleanly, no special cases):

- Add `native_facing` to the manifest meta (`hu.manifest.json`: `-1` once left-baked art
  installs; default `1` everywhere else incl. enemies).
- Presenter computes `render_facing = float(fighter.facing) * native_facing` and uses it in
  exactly those three sites (`sx`, `rotation` sign, `off_x` sign). Nothing else changes:
  gameplay `facing` keeps driving movement/knockback/AI; foot-anchor math already consumes the
  signed `sx`/`off_x` so it follows.
- Result: player facing -1 with native -1 → render factor +1 (no flip; blade viewer-side).
  Enemy native +1 → behavior identical to today.

## 3. Orientation flip in-game

Per `2026-07-08-combat-orientation-flip.md` GROUND TRUTH + watchlist: spawn player RIGHT
(`combat_scene.gd` ~:230-231 → `_player.facing = -1`, `_enemy.facing = 1`; ~:340-341 spawn
`gap` sign), world-absolute input keys, direction signs (dash/knockback), HUD side decision,
enemy no-double-flip check.

## 4. Clip install target (base files, NOT skins)

Default Hu combat wires `res://assets/animation_manifests/hu.manifest.json` +
`res://assets/animation_graphs/humanoid.graph.json` (`combat_scene.gd:113-116`). Install into
the BASE manifest + the base clip timelines it references (locate each clip file via the
manifest's own entries). The skins/ path is only for school move-skins — do not install there.

## 5. Frame installer contract (the venom recipe does NOT run as-is)

`WUGodot/tools/install_video_frames.gd` requires `<run>/<action>/pixelize/pixel_%03d.png` +
pixel sidecars + `masters/master_%03d.json` (`install_video_frames.gd:46-55`). The canon dirs
ship processed 256-canvas PNGs with NO sidecars (they went through harvest normalization the
run dirs know nothing about). Two options — pick one:

- **(a) New raw-frame installer** (recommended): `tools/install_raw_frames.gd` taking a dir of
  `f%02d.png` (256×256, content bottom-anchored at y=246, x-centered):
  `footAnchor = (content bbox center x, content bbox bottom)` per frame;
  `weaponTip` required only on attack ACTIVE frames — measure the blade tip (farthest steel
  pixel from body center) with a per-clip JSON override for hand-correction.
- (b) Rebuild sidecars into the venv-run layout — NOT recommended (the harvest's
  scaling/cropping would have to be re-derived).

## 6. Timelines

Per clip: 16 frames → keyposes across phases, evenly: windup (0→`windup_end`), active
(`windup_end`→`active_end`), recovery (→1.0); keep `id`, `"duration":"fromAttackDef"`, the
`attack_active_start/end` events; add a `smear` track over heavy's strike frame (frame ~9 —
the baked blade-arc smear). Deflect: frames 5–12 are the block-hold loop segment. Idle = k1
static first pass; walk pins to k1 (generate later if step-hold reads poorly).

## 7. Verification (exact commands)

1. `./run.sh --import && ./run.sh --test` → `failed: 0`.
2. `./run.sh --anchor-sanity` (run.sh:78) → clean.
3. Captures (`./run.sh --capture <spec.json> <out>` — spec FILE required, run.sh:141):
   - combat: `./run.sh --shot-combat` → player on the RIGHT, facing LEFT, blade on the
     viewer side in guard.
   - `{"kind":"matchup","build":[{"boon_id":"wind_descending_leaf","tier":"epic"}]}` →
     mid-action captures for light/heavy: blade length must read EQUAL across action frames
     (the zoom-law check) and the sword stays in the same hand.
   - `tools/assert_nonblank.py` per capture; diff-vs-base `cmp` on facing-sensitive baselines.
4. In-game scale judgment vs idle (standing rule) + head-size constancy spot-check
   (the user's anchor: post-normalization head size within ~10% across a clip's frames).

## Deferred (on record)

Forward-dash variant · K7 wrist-point install (experimental) · hero-sound iteration ·
relaxed idle/walk as out-of-combat set · enemy canon (Xiong Tie, Dropout Blade, stances,
scenes — canon plan Tasks 7–10).
