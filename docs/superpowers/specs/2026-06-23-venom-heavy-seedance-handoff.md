# Handoff — Venom Heavy via Seedance (idle + 3 guides)

**To:** implementer · **Date:** 2026-06-23 · Gate-1 poses/style **approved**.
**Goal:** smooth `venom_hu_attack_heavy` (the "Venom Fang Cleave"), generated with Seedance from a small guide set, idle-pinned. Same pipeline as the venom light, fewer guide frames.

Keyframes: `/tmp/venom_heavy_kf/` (K1–K5, idle). Brief: `2026-06-23-venom-heavy-keyframe-brief.md`.

## 1. Guide sequence (user's call)
Feed Seedance this ordered sequence — **idle at both ends, K1/K4/K5 between** (K2 and K3 dropped; K4 carries the impact beat):

`idle (vi_050) → K1_windup_start → K4_active_end → K5_recovery → idle (vi_050)`

- **Prep each guide to idle character size** (so Seedance sees consistent scale), applying the user's relative size factors: **K1 ×1.32, K4 ×1.00, K5 ×1.00** (idle = 1.0). These are rough hints — the **final harvest re-normalizes to idle anyway** (§3), so don't over-fuss.
- **Mechanism:** pin idle as `--start-frame` and `--end-frame`. If `aiexp animate-video` supports **intermediate keyframes/multi-ref**, pass K1→K4→K5 as the in-between guides. If it only supports start/end pins, keep idle/idle and convey K1/K4/K5 via the prompt path (and as style refs) — but prefer real keyframe guides if the tool allows.

## 2. Prompt (slow-mo, single beat, returns to idle)
> 2D wuxia fighting-game **venom-sect heavy sword attack in smooth SLOW MOTION**, one continuous strike across the entire clip. **Start and end in the neutral idle guard stance.** From idle: slowly raise the sword high overhead in a charged windup with venom pooling and dripping, then a heavy downward cleave that **bursts** a green venom splatter on impact (close range), then a weighty recovery **back to the same idle guard stance** — fully returned to idle by the final frame. Strike **in place without translating**; constant slow pace, the cleave landing around the **midpoint**. Keep Hu's exact pixel-art style/proportions/palette.

**Negatives:** ending in a different pose than the start, finishing early then holding, pausing mid-motion, a second swing/reset, high knees, drifting, floating, camera move, style drift, extra characters, mouth open, long thrust (close cleave, not a reach).

## 3. Validate → harvest → author
- **Validate source first:** adjacent-frame diff over masters (PIL `ImageChops.difference`, mean abs RGB). Expect **one spike at the cleave/impact**, no late reset/second swing; if a discontinuity remains, regenerate. (Per [[seedance-overlong-filler]].)
- **Harvest/resample** the full clean span to ~30 frames for **hu_heavy's 0.85s**; **first/last frames read as idle**; normalize to idle size, recompute `footAnchor`.
- **Author** `WUGodot/assets/animation_clips/skins/venom/venom_hu_attack_heavy.timeline.json` + poses in `skins/venom.manifest.json`. Keep `id`, `"duration":"fromAttackDef"`; map coil/charge→windup, cleave/impact→active at `"windup_end"`..`"active_end"`, recovery→tail; events `attack_active_start`/`attack_active_end` at the anchors; `smear` track over the cleave. (hu_heavy: windup_end norm 0.471, active_end norm 0.647.)

## 4. Verify + Gate 2
- `./run.sh --import && ./run.sh --test` (518/0), `--anchor-sanity`, base-vs-venom **heavy** active diff `cmp` 1, determinism `cmp` 0, `assert_nonblank`.
- Drop source under `/tmp/venom_heavy_kf/seedance_run/` + harvested frames in `/tmp/venom_heavy_kf/seedance/` so the review pages rebuild.
- **✋ STOP** — report in-game stills + motion preview + adjacent-diff for Gate 2.

## Process note (future moves)
~**3 guide keyframes** (charge / impact / recover) + idle ends are enough — no need to generate all 5 for Gate 1 going forward. The clip stays Seedance-smooth; only the guide count drops. See [[move-anim-seedance-pipeline]].
