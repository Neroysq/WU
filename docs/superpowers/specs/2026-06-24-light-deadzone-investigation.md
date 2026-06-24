# Investigation — light attack whiffs a close, in-front enemy

**Date:** 2026-06-24 · Status: **root cause UNCONFIRMED** — need in-engine evidence before any fix.

## Symptom (user)
An enemy **directly in front, on the ground** can be close enough that the **light attack whiffs** (no hit).

## What static analysis found (and ruled out)
Replicated `query_hit` exactly (player authored capsule vs enemy hurtbox):
- Light capsule (pose `vl_051`, `hitbox_template.gd:18` sword near-end `chest.lerp(tip,0.35)`, radius 20×2): world `a≈(40,-183)`, `b≈(364,-204)`, r=40.
- Enemy hurtbox: **fallback rect** `[D−38, D+38] × [−260, 0]` — the enemy is **not** registered with the hit geometry (`combat_setup.gd:15` registers only the player), so no narrow/offset authored hurtbox.
- **Distance sweep result: HITS at every close range** (D from −30 to 190+). Only misses when the enemy is ~30px *behind* center.
- So the **0.35 near-end lerp is NOT the cause** — pulling it back is a no-op. No body collision exists and facing auto-updates each frame (`combat_system:446`), so "enemy crossed behind you" doesn't explain a *directly-in-front* whiff either.

**Conclusion:** the geometry predicts a hit; the whiff is a runtime factor not visible in the code (candidates: the active-window timing, the actual strike pose/anchors at the hit frame differing from `vl_051`, a vertical/height mismatch at the real positions, or the venom skin interacting with the attack state).

## Evidence to capture (implementer)
1. **Debug-overlay frame of the whiff.** With DEBUG on, the scene already draws the player attack capsule + enemy hurtbox (`combat_scene.gd:709`). Reproduce: enemy directly in front and close, player light during its **active window**, and capture the frame where it whiffs. We need to *see* whether the capsule and hurtbox overlap at that instant. Save the PNG.
2. **Headless distance sweep probe.** Add a small probe (tool or test): place player + enemy both grounded, facing, trigger player `hu_light`, step through the **active frames**, and for D in e.g. 30..200 log `query_hit`, `segment_rect_distance`, the world capsule (`debug_capsule_world`) and the enemy hurtbox (`debug_hurtbox_world`). Output which D/frames miss. This turns the bug into reproducible numbers (and later a regression test).

Report both back. Then we fix the actual cause — and add the sweep as a test asserting close-range light connects.

## Note
Do NOT change `hitbox_template.gd` yet — the sweep proves that edit wouldn't fix this.
