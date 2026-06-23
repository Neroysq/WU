# Venom Dash — Keyframe Brief (Task 8, Gate 1) — last Venom slot

**Date:** 2026-06-23 · **For:** `venom_held_dash` (dash slot skin; `venom_dash` boon exists).

## Key difference from light/heavy: the dash is a SINGLE held pose

The base dash clip `held_dash` is **one keypose (`vp_dash`) held for a fixed 0.2s** (`useFighterOffset`, NOT `fromAttackDef`) while the engine translates Hu at dash speed. It is **not** a windup/active/recovery swing. So the venom dash is the **simplest** of the three slots:
- **Image-gen only** (GPT Image 2) — **no Seedance, no harvest, no idle-pinning** (the dash holds one pose; it doesn't return to idle within the clip).
- One Gate-1 keyframe → install. Fast.

(Optional: 2–3 glide frames if a single pose reads too static in motion — but base ships one pose, so default to one.)

## Design intent — "Venom Glide"

A low, **serpentine forward dash** — Hu glides like a striking snake, body leaning/coiled into the dash, leaving a **green venom trail/afterimage** streaking behind. Sword held ready (not attacking). Distinct from the base dash (a generic crouched dash lunge) by the **venom trail + serpentine body line**.

## Hard constraints
- **Single pose**, facing **right**, sword in a ready/carry grip (no attack swing).
- Match Hu's pixel-art style/proportions/palette; **venom-green trail** consistent with the light/heavy FX.
- Size vs idle; **grounded** (dash is a fast ground glide — feet skimming, not airborne); `footAnchor` correct so the engine seats + translates it cleanly.
- Transparent bg, full body in frame, mouth closed.
- Visual only — dash speed/i-frames/duration stay base; `venom_dash` venom stacks come from the boon effect.

## Reference frames
- `WUGodot/assets/sprites/characters/hu/vi_050.png` — identity/style/palette.
- `WUGodot/assets/sprites/characters/hu/vp_dash.png` — **base dash pose**: the dash silhouette/lean, canvas, and ground root to match (the venom version replaces this).
- Installed Venom light/heavy frames (`WUGodot/assets/sprites/characters/hu/venom/`) — **venom-green trail color/texture** so all venom moves share one look.

## Generation prompt seed (GPT Image 2)
> 2D side-view pixel-art wuxia swordsman facing right, **venom-sect dash** — a low fast forward dash/glide, body leaning serpentine into the motion, sword held ready (not striking), a **green venom trail/afterimage streaking behind**. Feet skimming the ground line, full body in frame, character height equal to Hu's idle; match Hu's exact pixel-art style, blue-grey robe, proportions, palette; transparent background; mouth closed.

## Install (after Gate-1 approval)
- Add `venom_vp_dash` pose to `skins/venom.manifest.json` (path, footAnchor, weaponTip, hurtbox from base dash).
- `skins/venom/venom_held_dash.timeline.json`: `{ "id":"venom_held_dash", "duration":0.2, "useFighterOffset":true, "keyposes":[{"t":0.0,"pose":"venom_vp_dash"}] }` (mirror base `held_dash`; **fixed 0.2s, not fromAttackDef**).
- Verify: import, test 518/0, anchor-sanity, resolved clip=`venom_held_dash`, base-vs-venom dash capture `cmp` 1, determinism `cmp` 0, non-blank. Gate 2 in-game (dash with `venom_dash` equipped).

## Gate flow
Gate 1: approve the venom-glide pose (single keyframe) → install → Gate 2 in-game. (No Seedance step for this slot.)
