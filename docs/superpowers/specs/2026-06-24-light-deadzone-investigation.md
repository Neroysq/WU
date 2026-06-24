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

## Confirmed by CC (2026-06-24)
- Ran a matchup capture (`state:04_light_active`, DEBUG overlay on) — **light HITS** at the only distance the capture tool can set. The capture states only pose the enemy at **preferred (medium) range** (`_dev_place_at_enemy_preferred_range`); there is **no point-blank knob**, so the user's close-whiff can't be reproduced via the existing capture path.
- Static sweep + code review (enemy unregistered → tall fallback hurtbox; capsule reaches to overlap) all say a close, grounded, in-front enemy **should** connect. So the cause is runtime-specific and needs a **point-blank probe**.

## Probe to add (implementer) — point-blank, grounded, in front
Add a headless probe (tool under `WUGodot/tools/` or a test). Steps:
1. Build player + a `bandit_swordsman` enemy via the real `CombatSetup.prepare` (same `hit_geometry` registration as live), both grounded, player facing the enemy.
2. For **center-distance D in 0, 10, 20, … 200** (start at/near overlap — this is the missing range): set the enemy at distance D directly in front, trigger player `hu_light`, and **step the attack through its full active window** (windup_end→active_end).
3. Each frame, log: D, `attack_state.elapsed`/phase, `is_hit_active`, `combat_system` connect result (the real path), `query_hit`, `ShapeMath.segment_rect_distance`, the world capsule `debug_capsule_world` (a,b,r), and `debug_hurtbox_world(enemy)` rect.
4. Output a table of **which (D, frame) miss**, and **save a debug-overlay PNG at the first missing distance** (so we see capsule vs hurtbox).
- Also run one pass with the enemy **slightly elevated** (small +y) to check a vertical-band miss.
- If the probe HITS at all D too, the bug isn't in this isolated setup → escalate to instrumenting **live** combat (log `connect`/positions each frame during a real fight) to catch the actual game-state difference.

Report the table + the PNG. Then we fix the actual cause and keep the probe as a **regression test** (assert close-range light connects).

## Probe result (implementer, 2026-06-24) — geometry RULED OUT
`probe_light_deadzone.gd` (`./run.sh --probe-light-deadzone`): grounded D 0..200, elevated −20y, and signed-overlap D −80..200 — **all hit, no misses** (D=0: query_hit + resolve_connect true, 37px margin). The isolated real `CombatSetup`/`CombatSystem` path does **not** reproduce the whiff. So the cause is **live game state** the probe didn't set.

## Prime suspects (live-only states)
The whiff is almost certainly one of these, none of which the probe exercised:
- **Enemy i-frames / invulnerable** (`combat_system.gd:260` early-returns) — e.g. just dashed or in a brief invuln.
- **Enemy blocking** → hit lands but HP damage ×0.2 (`:340`) → *looks* like a whiff.
- **Enemy parry** → player gets stunned, no damage (`:302`) → reads as a whiff.
- **`was_hit_this_swing`** already consumed, or the attack got cancelled before its active window.
- **Boon attack-override**: if a technique overrides light with a def whose `id` ≠ `hu_light`, `has_authored_hitbox` is false → falls to the `in_range` path (still hits close, but confirm).

## Next step — live instrumentation (after narrowing)
If the context questions don't pinpoint it: add a gated per-frame log in the live combat resolve path that, while the player light is active and an enemy is within ~1.5× range, dumps: positions/distance, facing, `is_invulnerable`, `is_blocking`, parry-active, `was_hit_this_swing`, attack `def.id`, `is_hit_active`, `query_hit`, `in_range`, `connect`. User reproduces the whiff with it on; share the log + a synced debug frame.

## Note
Do NOT change `hitbox_template.gd` — CC's exact sweep proves that edit is a no-op for this bug.
