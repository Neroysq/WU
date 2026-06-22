# Venom Light — Gate-1 Approved Poses + Scale Calibration

**Date:** 2026-06-22 · **Status:** poses + scale approved; clip authoring next.

## Approved
- Gate-1 keyframes (GPT Image 2, image-to-image off Hu refs) approved for **style + poses**.
- Source frames: `/tmp/venom_light_kf/K{1..5}_*.png` (569×395 RGBA), idle ref `vi_050.png`.

## Per-frame scale (vs idle = 1.000), user-calibrated on the ghost-overlay tool

| Keyframe | t-anchor (hu_light) | scale vs idle |
|---|---|---|
| K1_windup_start | 0.00 (windup) | **0.875** |
| K2_windup_peak  | windup_end 0.18 | **0.910** |
| K3_active_strike | ~0.40 (active) | **1.023** |
| K4_active_end   | active_end 0.30 | **0.845** |
| K5_recovery     | ~0.75 (recovery) | **0.970** |

**Meaning:** on the review tool, each keyframe was scaled until its **character** matched the idle ghost (overall size, not head box); 1.000 = idle size. These are per-pose normalization factors. The ~18% spread is GPT Image 2 size inconsistency between poses, so they must be applied per-pose (not one clip scale).

**Apply at authoring:** when baking each keyframe onto the action canvas / into `venom.manifest.json`, scale the character by its factor so all poses read at a consistent idle-matched size, and **recompute `footAnchor` after each down-scale** (the build-6 lesson — stale anchors float the character). See [[judge-art-size-overall-in-game]].
