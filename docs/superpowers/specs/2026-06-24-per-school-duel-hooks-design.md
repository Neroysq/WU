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
2. **Flurry posture (low-risk path)** — `momentum_flurry_effect.modify_outgoing_hit(ctx)`: add posture to the **main hit** (`ctx.posture_damage += params.posture_damage`, or a multiplier), **not** posture-bearing `extra_hits`. (Today `extra_hits` only applies HP — `combat_system.gd:460`; extending that schema with posture/stun/break/recorder handling is deferred unless a later plan explicitly does it.)
3. **Dash-through = Wind's "deflect" (the signature)** — `on_dash_through` fires while an i-frame dash overlaps an active enemy attack in range. **Two required changes** (see "Required hook changes"):
   - **(a) Pass the enemy.** The hook is `on_dash_through(fighter)` today (no enemy) — `combat_system.gd:127`, `technique_engine.gd:172`, `technique_effect.gd:69` — so it *cannot* damage the enemy as written. Change the signature to forward the enemy.
   - **(b) Gate to once per dash-through.** The call fires **every frame** the dash overlaps the active attack (`combat_system.gd:123`), so naive posture would tick many times and instantly break enemies. Apply the wind posture reward **exactly once per dash-through contact** (a flag reset when the dash ends / the contact window clears). Emit one `dash_through` recorder event per contact (event count == 1 in the test).
   So *dodging an attack* is Wind's non-parry posture reward (the mobility analog of a parry) — but only once per dodge.
4. **Momentum → posture burst** — at a momentum threshold, a wind hit converts momentum into a **posture burst** (toward a break), instead of/alongside the HP flurry.

Net: a dash-in / aerial / flurry / dash-through Wind build cracks posture → break → punish, **without parrying** — a genuine second viable duel path.

### 2b. Required hook changes (engine plumbing for the dash-through deflect)
- **`TechniqueEffect.on_dash_through(fighter)` → `on_dash_through(fighter, enemy)`** (`technique_effect.gd:69`) so an effect can damage the enemy.
- **`TechniqueEngine.on_dash_through`** (`:172,174`) forwards the `enemy` to each effect.
- **`CombatSystem`** (`:127`) passes the enemy AND **gates the call to once per dash-through contact** (don't fire the posture reward every frame in the invuln/active/in-range window).
- **Update the existing implementer** `flowing_water_effect.gd:12` to the new 2-arg signature (keep its current behavior; just accept `enemy`).
- **Add `CombatEventRecorder.record_dash_through(fighter, enemy, posture_amount)`** + a `dash_through` event so triggers/telemetry/tests can count it.

**Numbers are data/params** (`params` on each effect + wind boon `data/Boons/Boons.json`), tuned like the rebalance (probe + policy), not hardcoded design.

---

## 3. Validation
- **Scripted-policy gate (primary, quantitative) — hard threshold:** `--player aggressive_dash --decision school --school wind` over **seeds 1..50** must hit **win-rate ≥ 0.18** (vs the 0.08 baseline), with **zero timeouts** and **no improvement to `facetank`** (still ~0.00). Being below/near `parry_duelist` (0.44) is fine — wind is a *second* path, not a replacement. **Prove the build actually equipped Wind:** assert from the transcript/`build_snapshots` that wind boons were taken (a school-focused run that never gets offered wind doesn't count).
- **Duel-ratio probe — Wind mode:** the current `probe_duel_ratios.gd` always builds a **vanilla** player vs a passive enemy (`:58`), so it can't measure Wind. Add a Wind mode (`--probe-duel-ratios --wind`, or a new `--probe-wind-duel`) that **installs a fixed Wind loadout** on the player and runs aerial / flurry / dash-through sequences, asserting they deal **posture** (the vanilla probe stays the baseline).
- **Daemon dogfood (feel):** drive a Wind mobility run — dash-through an attack, watch the enemy's posture drop, build to a break, punish. Screenshot the dash-through posture moment.
- **No regression:** difficulty curve still accepts at 120 seeds; zero timeouts; the rebalance's per-pool attrition/skill ordering (facetank < aggressive_dash < parry) preserved or improved.

## 4. Out of scope (follow-ups)
- The other five schools' duel hooks (soft/iron/venom/thunder/sword) — incremental on this framework.
- Posture-break payoff/deathblow mechanic.
- New Wind boon *content* beyond retuning existing effects (unless a small new effect type is needed for the momentum→posture burst).

## 5. Components
- **Hook plumbing (§2b):** `technique_effect.gd` (on_dash_through 2-arg), `technique_engine.gd` (forward enemy), `combat_system.gd` (pass enemy + once-per-contact gate), `flowing_water_effect.gd` (update to 2-arg, behavior unchanged), `combat_event_recorder.gd` (`record_dash_through` + event).
- **Wind effects:** `momentum_aerial_effect.gd` (posture), `momentum_flurry_effect.gd` (posture on main hit), the dash-through deflect (in `momentum_effect.gd` or a small new `momentum_deflect_effect.gd`); possibly a `momentum_posture_burst` effect type in `technique_registry.gd` + wind boon data.
- **Probe:** Wind mode in `WUGodot/tools/probe_duel_ratios.gd` (`--wind`) or a new `--probe-wind-duel` that installs a fixed Wind loadout.
- **Tests:** per-effect posture-interaction units (aerial/flurry add `ctx.posture_damage`); dash-through gating test (one `dash_through` event + bounded posture per dodge); scripted-policy comparison (aggressive_dash + school=wind ≥ 0.18, facetank unchanged).
- **Reuse:** `HitContext.posture_damage`, the scripted policies, the duel-ratio probe.

## 6. Sequencing (phases — full plan after approval)
1. **Aerial + flurry posture** — retune the two effects to add `ctx.posture_damage` (flurry on the main hit, not extra_hits); unit tests asserting posture rises.
2. **Dash-through deflect** — do the §2b hook plumbing (2-arg `on_dash_through` + forward enemy + `flowing_water` update + recorder), then once-per-contact dash-through → momentum + enemy posture; test asserts **exactly one** `dash_through` event + bounded posture per dodge.
3. **Momentum→posture burst** — threshold conversion (effect + wind boon data); test.
4. **Validation + tune** — add the probe Wind mode; run `--player aggressive_dash --decision school --school wind` (seeds 1..50) to **≥0.18** (loadout-proven), facetank unchanged, zero timeouts; duel-ratio Wind probe; daemon dogfood; harness no-regression (difficulty accepts at 120). Tune params to hit the threshold. ✋ STOP for the user's verdict.
5. **Record** before/after + the wind knobs; note the framework for the next school slice.
