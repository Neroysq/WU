# Boon Move-Skin (#3) — Venom Slice COMPLETE + roadmap

**Date:** 2026-06-23 · Closes Task 8 of `docs/superpowers/plans/2026-06-22-wu-boon-move-skin.md`.

## Shipped — the move-skin **system** + the **Venom slice**

System (Tasks 1–7.5): `MoveSkinResolver`, presenter routing, `skin_tint` (flash-priority-safe single tint path), loadout wiring, configure cache-reset, harness capture proof. The player's per-move clip is skinned by the infusing 流; base + recolor fallback; player-only.

Venom slice (Task 8) — all three reachable slots, Gate-2 approved:
- **Light** (`venom_hu_attack_light`) — serpent fang-thrust, Seedance slow-mo, idle-pinned, 0.5s.
- **Heavy** (`venom_hu_attack_heavy`) — overhead venom cleave + impact splatter, Seedance slow-mo, idle-pinned, 0.85s.
- **Dash** (`venom_held_dash`) — venom glide single held pose, image-gen only, 0.2s.

## Skin grid — filled cells

| 流 \ slot | light | heavy | dash | block | stance | jump |
|---|---|---|---|---|---|---|
| 毒 Venom | ✅ | ✅ | ✅ | — | — | — |
| 雷 Thunder | — | — | — | — | — | — |
| 柔 Soft | — | — | — | — | — | — |
| 鐵 Iron | — | — | — | — | — | — |
| 風 Wind | — | — | — | — | — | — |
| 劍 Sword | — | — | — | — | — | — |

Empty cells ride the **base + school-recolor fallback** automatically; a bespoke clip supersedes it the moment it's authored.

## Proven pipeline (for every remaining cell)
1. **Brief** the move's school concept (grounded in the base clip's timing/phases).
2. **~3 GPT Image 2 keyframes** (charge / impact / recover) — Gate-1 pose/style approval (review page).
3. **Attacks (light/heavy):** Seedance `animate-video`, **idle-pinned both ends**, slow-mo single-beat across the full 4s → validate (adjacent-diff: one impact spike, no reset) → harvest/resample to the move's duration → normalize to idle → author multi-frame clip on `fromAttackDef` phases.
   **Dash:** single held pose, image-gen only (mirror base `held_dash`, fixed duration) — no Seedance.
4. **Gate 2** in-game.

Lessons captured in memory: [[move-anim-seedance-pipeline]], [[seedance-overlong-filler]], [[character-art-placeholder]].

## Out of scope / backlog (unchanged)
- Venom block/stance/jump (need those boons; stance has no anim-state — active-mode recolor only for now).
- The other 5 schools × slots — incremental art track on the pipeline above, any time.
- Duo/mastery blended visuals; relic/equipment aura (spec B).
