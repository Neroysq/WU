# Combat Difficulty & Readability v2 — Results (in progress)

**Date:** 2026-06-30
**Spec:** `2026-06-30-combat-difficulty-readability-v2-design.md`
**Status:** Phase 1 ACCEPTED · Phase 2/3 (difficulty shape) RETUNE PENDING

## First implementation — `ca081ca` (Implement combat difficulty ramp tuning)

**Plumbing (correct, matches spec):** `pressure_by_pool_class` + `block_chance_by_pool_class` in `DifficultyCurve.json`; `incoming_pressure_mult` on `Fighter`; applied in `resolve_hits` via `if attacker.is_ai` (`combat_system.gd:~395`); threaded through `combat_setup`/`combat_sim`/`combat_controller`. 556 tests pass; checker accepts.

**Verified policy sweep (50 seeds; reviewer re-ran):**
| Policy | Win | Node-1/2 deaths | Death cluster |
|---|---|---|---|
| aggressive_dash | **0.30** ✅ | **0** ✅ (was 16) | node 4 / boss |
| facetank | 0.00 ✅ | — | node 2 |
| parry_duelist | **0.62** ❌ (target 0.40–0.45) | — | boss (15) |

Pre-boss normal win **0.946** ❌ (target 0.65–0.75; went the wrong way from 0.90). Parry/dash gap **2.07×** ❌ (target ≤~1.5×). Zero timeouts ✅.

### Verdict
- **Phase 1 (non-parry early-game viability) — ACCEPTED.** The node-2 dash wall is gone (0.125→0.30, 16→0 early deaths). Likely lever: `dashCooldown 0.80→0.45` + weak-pool softening.
- **Difficulty SHAPE — wrong.** `pressure_by_pool_class` shipped as `weak 0.80, strong 0.98, elite 1.18, boss 0.90` — that does **not** rise toward the boss. The **boss was nerfed (0.90)**, and parry players die at the boss, so parry overshot to 0.62; **strong stayed flat (0.98)**, so the road got *easier* (pre-boss 0.95).

### Out-of-spec global player changes (landed in `ca081ca`)
- `dashCooldown 0.80→0.45`, `parryWindow 0.15→0.12`, `parryPostureDamage 60→40`.
- **User decision (2026-06-30): KEEP the dash buff + parry nerfs; fix the shape through enemy pressure only.**

## Retune directive (Phase 2/3 — values + re-validate, no new architecture)
**Keep (do not touch):** `dashCooldown 0.45`, `parryWindow 0.12`, `parryPostureDamage 40`, `weak_count 2`, `block_chance_by_pool_class` (0 / 0.12 / 0.25), weak pressure `0.80`, telegraphs.

**Change `pressure_by_pool_class` so it rises toward the boss:**
- `boss 0.90 → ~1.20` (boss is the peak; main lever to pull parry 0.62 → ~0.45)
- `strong 0.98 → ~1.10` (mid-game ramp → pre-boss → 0.65–0.75)
- `elite → keep ~1.20`
- `weak → keep 0.80` (protects the fixed dasher early game)

**Re-validate (§4 gates), iterate the two values until all hold:**
- parry 0.40–0.45 · aggressive_dash ≥0.30 (watch — harder strong/boss pulls it down; if <0.30 ease strong/boss slightly, do **not** re-buff the player) · facetank 0.00 · gap ≤~1.5× · zero timeouts
- pre-boss win 0.65–0.75 (the real proof the ramp landed) · deaths back-half · checker accepts (monotonic, boss-highest, tier1<20%)

**Tension:** pulling parry down via strong/boss also pulls dash down — the end state is a balance point, expect 2–3 iterations on those two numbers. Implementer reports the sweep back for verdict.
