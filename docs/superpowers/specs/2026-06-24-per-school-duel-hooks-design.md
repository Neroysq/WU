# Per-School Duel Hooks — Framework + Wind Slice — Design

**Date:** 2026-06-24
**Status:** draft (pre-plan) — for user review
**Builds on:** the combat-feel rebalance (`2026-06-24-combat-feel-rebalance-design.md` — the posture duel is now the win path) and the boon/technique-effect system (#2). Validated via the playtest harness (scripted policies + duel-ratio probe) and the interactive daemon.

**Goal:** Make each school's build a distinct **answer to the posture duel** ("build is the punish"), starting with **Wind** as the non-parry **mobility-pressure** path — closing the rebalance's open gap (`aggressive_dash` 0.08 vs `parry_duelist` 0.44).

**Why:** The rebalance made combat a posture duel, but today's boon effects pre-date it — they mostly add **HP/status**, which barely cracks posture. So non-parry builds underperform and "build is the punish" isn't realized. Each school should pressure/reward/amplify the *posture* duel through hooks that already exist.

---

## 1. Framework (all six schools — the shared principle)

Every school interacts with the **posture duel** through the existing `TechniqueEffect` hooks, with **`HitContext.posture_damage` as the shared currency**. A school's signature gives it one of three duel functions:
- **Pressure** posture (so offense cracks the enemy → break window),
- **Reward** its defensive answer (parry / dodge / guard),
- **Amplify** the punish during the break/stun.

**Duel roles (approved):**
| school | signature | duel role | primary hooks |
|---|---|---|---|
| soft | deflect | **PARRY** — riposte + bonus posture on parry | `on_parry_success`, `modify_outgoing_hit` |
| iron | guard | **GUARD** — posture economy, block-pressure, stance | `modify_block`, `on_stance_*`, posture stats |
| **wind** | momentum | **MOBILITY-PRESSURE** — dash/aerial/flurry pressure posture (non-parry) | `on_dash_through`, `modify_aerial_hit`, `modify_outgoing_hit` |
| venom | venom | **DoT-PRESSURE** — poison bleeds posture over time | `update`, `modify_outgoing_hit` |
| thunder | jolt | **BURST** — jolt amplifies; discharge on movement | `modify_outgoing_hit`, `on_dash_*` |
| sword | intent | **PUNISH-AMP** — marks → crit/burst during the break | `on_posture_break_dealt`, `modify_outgoing_hit` |

**Only Wind is implemented in this spec.** The other five are the incremental track on this same framework (each its own slice later), exactly like the move-skin grid.

---

## 2. Wind slice — mobility as posture pressure (the non-parry path)

**Today (HP/speed-focused):** `momentum_effect` builds a `fighter.momentum` resource on dash (`on_dash_end`, +25/dash); `momentum_aerial_effect` ×1.25 **HP** on aerial hits; `momentum_flurry_effect` adds **HP** extra-hits at a momentum threshold; `momentum_speed_effect` +move_speed. None touch posture → useless for cracking the duel post-rebalance.

**Retune so mobility pressures posture:**
1. **Aerial posture** — `momentum_aerial_effect.modify_aerial_hit(ctx)`: also scale `ctx.posture_damage` (aerial strikes pressure posture, not just HP).
2. **Flurry posture** — `momentum_flurry_effect`: the flurry extra-hits / the modified hit carry **posture damage** (a flurry bleeds posture).
3. **Dash-through = Wind's "deflect" (the signature)** — `on_dash_through(fighter)` fires when an i-frame dash passes through an active enemy attack (`combat_system.gd:113`-area). Make it **build momentum AND apply posture damage to the enemy** — so *dodging an attack* is Wind's non-parry posture reward (the mobility analog of a parry). Surface a recorder event so triggers/telemetry see it.
4. **Momentum → posture burst** — at a momentum threshold, a wind hit converts momentum into a **posture burst** (toward a break), instead of/alongside the HP flurry.

Net: a dash-in / aerial / flurry / dash-through Wind build cracks posture → break → punish, **without parrying** — a genuine second viable duel path.

**Numbers are data/params** (`params` on each effect + wind boon `data/Boons/Boons.json`), tuned like the rebalance (probe + policy), not hardcoded design.

---

## 3. Validation
- **Scripted-policy gate (primary, quantitative):** `aggressive_dash` policy with a **wind build** (reuse the existing `--decision school --school wind` to steer boon picks) vs the same policy with `--decision greedy` (mixed build), over the same 50 seeds. The wind build must **meaningfully raise** the non-parry win rate (target: clear improvement over the 0.08 baseline, toward the parry path) — proving Wind closes the gap. (No new build-injection tooling needed; school-focused decision already concentrates wind.)
- **Duel-ratio probe:** a Wind-equipped pressure sequence breaks posture in fewer effective hits than vanilla (mobility now pressures posture).
- **Daemon dogfood (feel):** drive a Wind mobility run — dash-through an attack, watch the enemy's posture drop, build to a break, punish. Screenshot the dash-through posture moment.
- **No regression:** difficulty curve still accepts at 120 seeds; zero timeouts; the rebalance's per-pool attrition/skill ordering (facetank < aggressive_dash < parry) preserved or improved.

## 4. Out of scope (follow-ups)
- The other five schools' duel hooks (soft/iron/venom/thunder/sword) — incremental on this framework.
- Posture-break payoff/deathblow mechanic.
- New Wind boon *content* beyond retuning existing effects (unless a small new effect type is needed for the momentum→posture burst).

## 5. Components
- Modify: `WUGodot/scripts/techniques/effects/momentum_aerial_effect.gd` (posture), `momentum_flurry_effect.gd` (posture), `momentum_effect.gd` / `on_dash_through` path (dash-through → momentum + posture; possibly a small new `momentum_deflect_effect.gd`).
- Possibly new: `momentum_posture_burst` effect type in `technique_registry.gd` + wind boon data referencing it.
- Tests: per-effect posture-interaction unit tests; a scripted-policy comparison (aggressive_dash ± wind).
- Reuse: `HitContext.posture_damage`, `CombatEventRecorder` (a `dash_through`/posture event), the duel-ratio probe, the scripted policies.

## 6. Sequencing (phases — full plan after approval)
1. **Aerial + flurry posture** — retune the two effects to carry posture; unit tests asserting `ctx.posture_damage` rises.
2. **Dash-through deflect** — `on_dash_through` builds momentum + applies enemy posture damage + recorder event; test.
3. **Momentum→posture burst** — threshold conversion (effect + wind boon data); test.
4. **Validation + tune** — scripted `aggressive_dash ± wind` comparison, duel-ratio probe, daemon dogfood, harness no-regression; tune params to close the gap. ✋ STOP for the user's verdict.
5. **Record** before/after + the wind knobs; note the framework for the next school slice.
