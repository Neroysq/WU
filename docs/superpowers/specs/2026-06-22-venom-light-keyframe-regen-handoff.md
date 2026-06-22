# Handoff — Regenerate Venom Light Keyframes (Task 8, Gate 1)

**To:** implementer · **From:** Gate-1 review · **Date:** 2026-06-22

## Why this is a re-do

The first Gate-1 scratch set (`/tmp/venom_light_kf/K1..K5`) was **programmatically drawn** (code primitives), not produced with the image model. Result: flat shading, thick uniform outlines, blocky "wheel" feet — it does **not** match Hu's existing hand-styled pixel art, so it would read as a foreign asset in-game at Gate 2. The poses (serpent-fang) are directionally fine; the **rendering method** is the problem.

## What to do

Regenerate the 5 keyframes with the **image model (GPT Image 2 / "image 2")**, **image-to-image**, feeding Hu's real sprite frames as **style + identity + proportion references** so the output matches Hu's art language (shading, line weight, palette, body proportions, foot/boot rendering).

### Reference frames (use as style/identity input)
- Idle / scale anchor: `WUGodot/assets/sprites/characters/hu/vi_050.png`
- Light windup: `…/hu/vl_001.png`, `…/hu/vl_051.png`
- Light active/extended: `…/hu/vl_055.png`, `…/hu/vl_081.png`
- Guard (off-hand read): `…/hu/vi_002.png`

The generated Venom frames must look like the **same character and same renderer** as these — only the technique (pose) and a subtle venom-green blade sheen + droplets differ.

### The 5 keyframes (poses per the brief `2026-06-22-venom-light-keyframe-brief.md`)
| File | Pose |
|---|---|
| `K1_windup_start.png` | low coiled serpent stance, blade drawn back beside rear hip, clawed off-hand fang-guard forward, S-curved torso |
| `K2_windup_peak.png` | max coil/load — blade cocked low-and-back, shoulders wound like a spring |
| `K3_active_strike.png` | explosive rising fang-lash at **full reach** (match the long reach of `vl_081`), venom spray off the tip, motion smear |
| `K4_active_end.png` | full extension held, lingering venom mist trailing |
| `K5_recovery.png` | blade re-coiling toward the fang-guard, last venom drip, settling toward neutral |

Optional polish: push the serpentine coil / S-curve a bit harder (wild-&-comical register) without breaking readability.

### Hard constraints (unchanged)
- Match Hu's **pixel-art style + palette + proportions** (the whole point of this re-do).
- **Overall character size = idle** (`vi_050`); judge overall char vs idle, not head box.
- **Feet on the ground line**, planted (except the lunge push); render boots like Hu's, not blocks.
- Authored **facing right**; **transparent background**; full body in frame.
- Visual only — these map onto `hu_light` timing later (windup_end 0.18 / active_end 0.30 / 0.50); active frames must keep full reach so the visual matches the hitbox.

## Return contract
- Overwrite the 5 PNGs in `/tmp/venom_light_kf/` (keep `idle.png` = `vi_050.png`).
- **Do not** install into `venom.manifest.json` — still pre-approval (Gate 1).
- Ping when ready; the review page (`/tmp/venom_light_kf/review/gate1.html`) will pick up the new frames after I re-trim.
