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
**Decision (user, 2026-06-30): guarding ROOTS you — no movement while blocking/parrying.** (The block-walk animation is parked behind the creative revamp; rather than a sliding stopgap, guarding plants your feet — also a classic stand-your-ground guard feel.)
**Implementation (player, `combat_system.update_player`):**
- Gate on the **input**, not `fighter.is_blocking` — `is_blocking` is assigned at `:84`, *after* the movement code (~`:35-40`) runs, so using it would lag a frame. Read `var guard_held: bool = bool(input_state.get("block_down", false))` at the top.
- **Do NOT add BLOCKING to the `can_move` exclusion list** — excluded states skip the lerp entirely, which would freeze residual `velocity.x` and glide. Instead, when `guard_held and fighter.is_grounded`, force `target_speed = 0.0` so the existing `lerp(velocity.x, target_speed, ground_move_control)` brakes to a stop.
- Suppress the IDLE→WALKING transition (`:41-43`) while `guard_held` (the guard pose holds; no walk anim while rooted).
- Airborne: unchanged (no rooting mid-air; air block behaves as today).
- Parry is a tap of the same key (`block_pressed` opens the window) — the root naturally covers the parry moment via `block_down` on those frames; no separate parry handling.
- Enemy side: out of scope (AI movement is its own path; enemies' brief reactive blocks are a lesser visual and rooting them shifts balance). Note it for the enemy-animation pass.
- **Log the block-walk clip** in the animation-pass backlog (revamp track) — rooting supersedes the need short-term, but a guard-walk may return post-revamp as a design choice.
- Balance note: rooting removes guard-mobility entirely — a bigger change than the slow-walk. The scripted policies (esp. `parry_duelist`, which holds block) may shift. **Re-run the 3-policy sweep (50 seeds each)**: parry should stay ~0.55-0.62, dash ~0.30, facetank 0.00; flag if parry drops >0.05.
**Tests:** unit — with `block_down` held + move input (grounded): `velocity.x` decays to ~0 and never accelerates; animation stays BLOCKING (never WALKING); a parry still succeeds while rooted; airborne behavior unchanged. `./run.sh --test` green.
**Verify:** manual feel (guard plants you; release moves instantly); policy sweep within bands.

## Out of scope
- Block-walk animation (revamp/animation track).
- Audio iteration (hero sounds judged "so-so, serviceable" — deferred; see funness memory).
