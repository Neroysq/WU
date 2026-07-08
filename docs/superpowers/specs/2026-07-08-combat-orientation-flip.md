# Combat Orientation Flip — Player on the Right — Design Directive

**Date:** 2026-07-08 · **Status:** approved direction (user), for implementer
**Origin:** Hu's canon art is right-facing with the sword in the near (right) hand.
The user wants swords read as RIGHT-handed on screen. Rather than baking mirrored
art (doubles the asset surface, splits the canon), the game flips its combat
orientation and lets the existing runtime facing-flip do the work.

## The change

- **Player spawns on the RIGHT side of the arena, facing LEFT** (`_player.facing = -1`);
  **enemy spawns LEFT, facing RIGHT** (`_enemy.facing = 1`). Today it is the mirror of
  this (combat_scene.gd:230-231, 340-341 and any other spawn/reset sites).
- Art convention is UNCHANGED: all character art keeps facing right natively
  (art/canon/hu/*, clips) and mirrors at runtime via the existing facing flip.
  On screen, the mirrored player reads with the sword on the user-desired side.

## Watchlist (verify, don't assume)

1. **Input semantics:** left/right movement keys must stay world-absolute
   (pressing right moves right). Check any code that multiplies input by `facing`.
2. **Dash/back-dash directions**, knockback signs, and enemy AI approach logic —
   anything with a hardcoded `+1/-1` or `gap` sign (combat_scene.gd:340).
3. **HUD anchoring:** player HP/posture bars sit on the left today — decide whether
   bars follow the fighter (swap sides) or stay put; keep rage pips consistent.
4. **Camera/arena bounds** and spawn `gap` sign.
5. **Captures:** re-run combat + matchup captures; diff facing-sensitive tests;
   `./run.sh --test` green; playtest eyeball for input feel.

## Out of scope

Enemy art stays as-is (mirrors the other way — enemies now natively face right
toward the player… verify enemy sprites don't double-flip).
