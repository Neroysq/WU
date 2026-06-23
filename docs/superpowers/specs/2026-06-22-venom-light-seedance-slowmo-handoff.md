# Handoff — Venom Light, Seedance "slow-mo over full clip" recipe

**To:** implementer · **Date:** 2026-06-22
**Why:** the first Seedance run wasted the back half of the 4s (slow settle + a spurious second swing at ~frame 69→70, adjacent-diff 19 vs median 0.58) and starved the fast slash, so the in-game clip juddered. Fix the **source**, not just the harvest: make the whole 4s be the move, in slow motion. See [[seedance-overlong-filler]].

## 1. Regenerate (aiexp animate-video / Seedance)
- **Duration:** 4s (model default) — but the prompt stretches ONE attack across all of it.
- **Pins:** start-frame `K1_windup_start.png` (coil), end-frame `K5_recovery.png` (recovery/guard).
- **Prompt (genre-framed, slow-mo, single beat):**
  > 2D wuxia fighting-game **venom-sect light sword attack performed in smooth SLOW MOTION**, one single continuous strike spread evenly across the entire clip: from a low coiled serpent stance, slowly lash the sword forward into a rising fang-thrust to full extension with venom-green spray, then slowly recover toward a low guard. Constant slow pace the whole time — the strike lands around the **midpoint**. Striking **in place without translating**. Keep this character's exact pixel-art style, blue-grey robe, proportions, palette.
- **Negatives:** finishing early then holding still, idle/pause at the end, **a second swing or reset**, high knees, drifting lunges, floating, camera move, style drift, extra characters, mouth open.
- If it still finishes early + idles: push "even slow pace across the FULL duration, strike at the midpoint" harder; do **not** shorten — we want the whole clip to be motion.

## 2. Validate the source before harvesting
- Run the adjacent-frame diff (PIL `ImageChops.difference`, mean abs RGB over masters). **No spike ≫ median** in the kept span (the old run had a 19 vs 0.58 glitch). If a discontinuity remains, regenerate — don't harvest a glitchy master.
- Confirm the contact sheet shows continuous motion end-to-end (no static tail, no re-swing).

## 3. Harvest + author
- **Resample the full clean span** to the in-game frame budget (~30 frames for hu_light's 0.5s @ 60fps). Even decimation is now fine because slow-mo spreads the motion evenly — but still verify the active beat reads smooth.
- Map beats to phases (coil→windup, strike/burst→active at `windup_end`..`active_end`, recovery→tail). Normalize to idle size, recompute footAnchor.
- Re-author `skins/venom/venom_hu_attack_light.timeline.json` + `skins/venom.manifest.json` (replace current). Keep `id`, `"duration":"fromAttackDef"`, events, smear.

## 4. Verify + Gate 2
- `./run.sh --import && ./run.sh --test` (518/0), `--anchor-sanity`, diff-vs-base `cmp` 1, determinism `cmp` 0, non-blank.
- Drop the new source under `/tmp/venom_light_seedance_run/venom-light/` and harvested frames in `/tmp/venom_light_kf/seedance/` so I rebuild the motion preview + source page.
- **✋ STOP** — report in-game stills + motion preview + the adjacent-diff check for Gate 2.

This slow-mo recipe becomes the standard for **heavy → dash** too.
