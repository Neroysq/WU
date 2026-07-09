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

## Revision (2026-07-08, after the hand-consistency work)

The runtime-flip-only approach is superseded for the PLAYER. Learned: k5/k6's
sword hand could not be fixed generatively (codex anchors or mirrors); the user
mirrored those pins deterministically, making them left-facing — and clips must
be rolled from uniformly-facing pins or the hand swaps mid-clip.

**Final convention:**
- **Player art faces LEFT natively.** k5/k6 already do; k1-k4/k7 and the
  light/heavy/block clip frames get a one-time deterministic batch mirror at
  install. Dash/jump clips are being re-rolled left-facing from uniform pins.
- **Player spawns RIGHT, faces LEFT, and is NEVER runtime-flipped** (that would
  undo the handedness). Enemy keeps runtime flipping as today.
- Anatomical result: Hu is right-handed on screen at all times.
- Back-dash note stands: one dash clip serves both directions for now.

## GROUND TRUTH (2026-07-09, user-confirmed on the layout mock)

1. **Layout FINAL:** player always on the RIGHT facing LEFT; enemy on the LEFT.
2. **Sword hand FINAL:** as in the mock — blade on the VIEWER side, fully visible
   (anatomically his left when facing left; readability over strict anatomy).
   Operationally: final on-screen player art = MIRROR of the right-facing canon.
3. **Dash:** the v6 back-dash structure is directionally correct (guard-right +
   leftward flight; mirrors at install into the final rightward back-dash).
   Its defect is the SOMERSAULT — a dash must not roll. Re-roll with rolling
   forbidden (approval pending). One dash clip serves both directions for now.

Install derivation: batch-mirror ALL player pins + clip frames (deterministic);
player never runtime-flipped; enemy keeps runtime flip.
