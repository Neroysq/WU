# Playtest Fixes — Reward Rarity Color + Guard-Walk Slide

**Date:** 2026-06-30
**Status:** directive (small fixes) — from a hands-on playtest of `f91b7ab`
**Scope:** one draw-only fix, one minimal feel stopgap. No systems.

## Fix 1 — Technique rewards show no rarity distinction
**Repro:** the reward screen (得技 "Technique Acquired") offers techniques of different rarity with identical presentation.
**Facts:** techniques have `rarity: 1|2|3` (`data/Techniques/TechniquePool.json` — 9× r1, 8× r2, 3× r3); rarity already drives shop price (`shop_generator.gd:23`) but is **never rendered anywhere**. `reward_scene.gd:73` draws every option via `UiDraw.reward_option` with one accent; `RewardOption` doesn't even carry the field (`reward_option.gd` has no rarity).
**Fix (mirror the boon-offer treatment):**
- Plumb rarity: `RewardOption.from_dictionary` copies `rarity` (default 1); expose it to the scene.
- Render: rarity chip + border tint on the option box, mapping rarity → the existing boon rarity colors (1 → common `COLOR_LIGHT_BLUE`, 2 → rare `COLOR_SKY_BLUE`, 3 → epic `COLOR_PURPLE_LIGHT`) — either a `rarity_color` param on `UiDraw.reward_option` or a small chip drawn by `reward_scene` after the row (same look as `boon_offer_scene._draw_offer_card`'s chip). Stat-bump rewards (no rarity) stay as today.
- **Shop too** (same data, same gap): tint the price or add the small chip per row in `shop_scene` using the same mapping — the shop already knows rarity for pricing.
**Verify:** `--capture {"kind":"ui","screen":"reward"}` (temp spec file) with techniques of different rarity forced/present → chips/tints visibly differ; same for `screen: shop`. `python3 tools/assert_nonblank.py` on both.

## Fix 2 — Moving while guarding slides a static block pose
**Repro:** hold block + move — the character glides across the ground frozen in the guard pose.
**Facts:** `combat_system.gd:84` allows full-speed movement while `is_blocking` (no penalty exists); `BLOCKING` is a held pose (no block-walk clip exists).
**Decision context:** the *real* fix is a block-walk animation — **parked behind the creative revamp** per the funness pivot (`2026-06-30-funness-direction.md`); don't author placeholder clips now.
**Stopgap (recommended, minimal):**
- **Slow guard movement** to ~45% move speed while `is_blocking` (new `blockMoveMultiplier: 0.45` in `GameSettings.json`, applied where `update_player` computes ground movement). Genre-standard guard-walk feel; the slow, deliberate slide reads intentional rather than broken, and it's a data knob.
- Optional: reuse the existing footstep dust particles at reduced rate while guard-moving so the feet aren't dead.
- **Log the block-walk clip** in the animation-pass backlog (revamp track) — this stopgap does not close that item.
- Balance note: slower guard movement is a (small) nerf to turtling mobility — facetank is already 0.00 and parry reads unaffected (parry is a tap, not a held walk), but re-run the 3-policy sweep (30 seeds each) to confirm no band moves.
**Verify:** manual feel (guard-walk reads deliberate); policy sweep parry/dash/facetank within current bands; `./run.sh --test` green.

## Out of scope
- Block-walk animation (revamp/animation track).
- Audio iteration (hero sounds judged "so-so, serviceable" — deferred; see funness memory).
