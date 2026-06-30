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

## Pressure-only retune FAILED to converge (reported 2026-06-30, not committed)
Implementer swept boss pressure with strong 1.10 / elite 1.20:

| boss | parry | dash | greedy | pre-boss | checker |
|---|---|---|---|---|---|
| 1.20 | 0.48 | 0.16 | 0.34 | 0.941 | pass |
| 1.05 | 0.50 | 0.20 | 0.41 | 0.941 | pass |
| 1.00 | 0.52 | 0.22 | 0.42 | 0.941 | pass |
| 0.90 | 0.60 | 0.30 | 0.50 | 0.941 | pass |

No candidate hits the bands. **Two diagnosed root causes (per-hit damage is the wrong lever for both):**
1. **Pre-boss stuck ~0.94 at every pressure value.** HP carries between fights (`combat_setup.prepare`→`reset_for_combat` doesn't restore HP; only rest heals 40%), but a *competent policy barely gets hit*, so per-hit damage can't lower its fight win rate. Damage you can parry/dodge isn't a threat to someone parrying/dodging.
2. **Parry vs dash are opposed at the boss.** The dasher's boss answer (dodge) is structurally weaker than the parrier's (parry), so a boss hard enough to hold parry ≤0.45 craters dash below 0.30. Every row above is parry-high/dash-ok or parry-ok/dash-dead.

## Phase 2/3 v2 directive — TEMPO + MARGIN levers (user decision 2026-06-30)
Open the "pressure-only / keep everything" constraint. New lever set:
- **Enemy aggression/tempo ramp (primary pre-boss lever):** ramp enemy `aggression` (attack frequency) — and/or shorten their post-attack vulnerability — by `pool_class` via the same runtime-override plumbing as `block_chance_by_pool_class` (e.g. an `aggression_by_pool_class` map). More frequent/safer offense = fewer free openings = chip the player can't fully dodge → lowers fight win rate where damage couldn't. Weak pool stays honest (protect the fixed dasher early game).
- **Modest player-margin cut:** small reduction to the player's buffer so carryover attrition bites — e.g. rest heal 40%→~30%, or a slight `healthMax`/`postureMax` trim. Keep it small so it doesn't crater dash.
- **Keep `pressure_by_pool_class`** for attrition with a gentle rising shape (weak ~0.80–0.85, strong ~1.05–1.10, elite ~1.20, boss ~1.05–1.15) — aggression now does the pre-boss work, so pressure needn't be extreme.
- **Keep** the prior global player changes (dashCooldown 0.45, parryWindow 0.12, parryPostureDamage 40).

**Relaxed targets (this pass):** parry **~0.45–0.50** · aggressive_dash **~0.27–0.32** · facetank ~0.00 · pre-boss **~0.65–0.78** · zero timeouts · deaths back-half · checker accepts. (Closing the dash/boss gap further is deferred to a dedicated **dasher boss-answer** slice — more Wind/mobility tooling vs the boss.)

**Tuning order:** aggression/tempo + margin first (pull pre-boss + overall down), then pressure for the rising shape, then boss within the relaxed band. Watch the **dash floor ~0.27** — aggression/margin also hit dash; if it sinks, ease aggression on strong/elite before touching the player. Implementer reports the sweep back for verdict.
