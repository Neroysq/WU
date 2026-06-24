# Combat-Feel Rebalance — Make the Duel the Path — Design

**Date:** 2026-06-24
**Status:** draft (pre-plan) — for user review
**Source:** full-run health check (`2026-06-24-full-run-health-check.md`, F1) + the dead-zone resolution (`2026-06-24-light-deadzone-investigation.md`, enemy block→parry). Validated via the interactive playtest daemon (`2026-06-24-interactive-playtest-daemon-design.md`) + batch harness.

**Goal:** Retune combat so **facetank-DPS loses** and victory runs through the **posture/parry duel** — with the boon build as the *punish/identity* layer — **without new mechanics** (one small fairness code change; everything else is data/tuning, dogfooded live).

## Fantasy (decided)
**Duel-skill + build-power.** Each fight is a real exchange you can't facetank: spacing / parry / posture pressure cracks the enemy open; the build is *how* you pressure and punish. Defense/timing = the skill layer; boons = the power/identity layer.

## Hard principle — multiple viable playstyles (parry is NOT mandatory)
The duel must be **engageable by more than one playstyle**. What loses is **facetanking** (standing and trading while ignoring all defense/spacing) — *not* "any build without parry." These must all be viable:
- **Parry-duelist** — deflect to break posture, punish on the stun.
- **Aggressive pressure** — relentless attacks (which deal posture damage) break posture by offense; survive via spacing/cancels.
- **Mobility/dasher** (attack-dash-jump) — dash i-frames to avoid the dangerous hits, hit-and-run; **no parry required**.
Boons reinforce different paths (venom = attrition pressure; wind = mobility; soft = parry/counter; iron = guard/posture; etc.), so school identity maps to a playstyle and each is a real way to win.

## Diagnosis (why it's broken today)
- HP-race bypasses the duel: player deals ~134 HP/combat into an 80-HP enemy, takes ~25 — you win on HP before posture ever matters (F1).
- Skill-sweep is **inverted** (lower skill / more aggression wins more) → defense isn't worth it.
- Enemy reactive block **auto-opens a parry window** (`combat_system.gd:229-230, 259-260`) → punishes the player's close attacks (the "dead-zone").

## Levers (data/tuning unless noted)
1. **Curb the HP race → posture is the efficient kill.** Make enemies **HP-tankier** and/or weight player attacks **toward posture over raw HP**, so chipping HP alone is too slow; you **break posture (→0.7s stun)** to land real damage. Tune the HP:posture ratio so a clean fight is won through ≥1 posture-break, not pure HP chip. **Posture-break must be reachable by attack pressure OR parry** (both deal posture damage) — see the principle above.
2. **Punish facetank.** Raise enemy offense/pressure so standing-and-trading bleeds you out, and ensure archetypes **use existing perilous/unblockable attacks** (force a dash, no new mechanic). Target: a defending/spacing player beats a facetanker.
3. **Fix the duel fairness (THE code change).** Enemy reactive block becomes **block-only** — remove `trigger_parry_window()` from **both** AI block sites: the modern AI path (`combat_system.gd:228-230`) **and** the legacy fallback path (`combat_system.gd:258-260`). **Test:** a player attack into a blocking enemy yields **no `parried:true`** event, **no player stun**, and **enemy posture loss** (blocked-pressure bleeds the enemy 1.5×). Pressuring a blocking enemy then drives toward a break (good!) instead of coin-flip parrying the player. (Deliberate, telegraphed enemy parry can return later as an archetype ability — out of scope.)
4. **No turtling.** Keep player block bleeding own posture (1.5×) so holding block loses to posture-break — defense is active (parry/space/dash), not passive.
5. **Parry stays a strong tool, not the only one.** Current `parryPostureDamage` 50 breaks a weak enemy (~85 posture) in ~2 well-timed parries → stun → punish; **scales with the enemy's posture** (~2 weak, ~3 elite, more for the boss — see the tier-relative table). Keep it strong but **don't buff parry to where offense/dash paths are dominated** (the multi-path principle).

## Validation
**Correction:** the batch `HeuristicPlayer` **already reaction-parries** — on a defensive reaction it sets `block_pressed`, which opens the player parry window (`heuristic_player.gd:30` → `combat_system.gd:78-81`). So the skill-sweep is a **crude reaction-parry/block policy**, not parry-free, and the inverted sweep (more "skill" = more reaction-defense = currently *worse*) is exactly the symptom this pass fixes.
- **Harness (quantitative gate).** Re-run the health-check batches: the **skill-sweep is no longer inverted** (win rate non-decreasing with skill; the low-skill/facetank win rate drops from ~0.72); overall win ~0.5; **difficulty curve still holds** (boss = highest death share, non-rising by ordinal, tier-1 deaths <20%); zero timeouts. Plus the **duel-ratio table** below.
- **Daemon dogfooding (feel check).** Drive fights via the interactive daemon and confirm the *nuanced* feel the crude heuristic can't capture: (a) facetank loses; (b) a **parry-duel** run works (parry→break→punish, build burst in the stun); (c) an **aggressive-dash** run *also* wins **without parrying** (the multi-path principle).
- **Deferred companion:** **distinct scripted playstyle policies** (a dedicated parry-duelist policy, an aggressive-dash policy) so the harness can quantitatively confirm *each* path is viable — its own task, not this pass.

## Duel-ratio gate (fill before/after, per archetype — prevents HP-sponges & mandatory parry)
Tuning is **not** "make HP bigger." Before touching numbers, capture a baseline table and re-capture after; the implementer must hit the target column. Per archetype (`bandit_swordsman`, `bandit_spearman`, `wandering_ronin`, `sect_disciple`, `masked_assassin`, `iron_bear`):

| metric | meaning | target |
|---|---|---|
| **hits-to-HP-kill** | clean light hits to drop HP to 0 (no posture) | **goes UP** vs baseline (HP-race slower) but **not a sponge** (≈ keep ≤ ~1.5× baseline) |
| **hits-to-posture-break (light)** | light hits (unblocked) to break posture | finite & reasonable (aggressive offense is a valid break path) |
| **hits-to-posture-break (heavy)** | heavy hits to break posture | meaningfully fewer than light |
| **blocked-pressure breaks?** | does sustained pressure break a *blocking* enemy's posture (1.5×)? | **yes** (pressuring a turtle works — post lever 3) |
| **parries-to-break** | well-timed parries (~50 posture) to break | **tier-relative**: weak (~80–85 posture: bandit/spearman/assassin) ~2; ronin/disciple (100/120) ~2–3; iron_bear (160 + recovery 14/s, boss) intentionally higher / phase-specific. **Don't flatten posture across the roster.** |
| **break→punish payoff** | damage landable in the 0.7s stun | a posture-break path kills **faster than** pure HP-race (so the duel is the efficient win) |
| **avg combat duration** | seconds | within a healthy band (no marathon sponges) |
| **timeouts** | combats hitting `max_time` | **0** |

Reference current values: `hu_light` 12 HP / 22 posture, `hu_heavy` 22 HP / 42 posture; `GameSettings.json` `blockHealthMultiplier 0.2`, `blockPostureMultiplier 1.5`, `parryPostureDamage 50.0`, `parryStunDuration 0.6`; enemy HP/posture in `data/Enemies`. **Acceptance:** posture-break is the *efficient* kill on every archetype, multiple break paths exist (offense **or** parry), no HP sponge, no timeouts.

## Out of scope (follow-ups)
- Posture-break payoff/deathblow mechanic; per-school duel hooks (build-into-posture); telegraphed enemy parry as an archetype ability; **distinct scripted playstyle policies** (parry-duelist / aggressive-dash) for quantitative per-path validation.

## Tuning knobs (where the numbers live)
- `data/Attacks/Attacks.json` (per-attack `damage` vs `posture_damage`, perilous flags), `data/Enemies/*` (enemy HP/posture/aggression/`blockChance`), `WUGodot/data/Settings/GameSettings.json` (`blockHealthMultiplier` 0.2, `blockPostureMultiplier` 1.5, `parryPostureDamage` 50.0, `parryStunDuration` 0.6), `GameConstants` (`POSTURE_RECOVERY_RATE`, `PARRY_WINDOW`, `STUN_DURATION`). All retunable without code except lever 3.

## Sequencing (phases — full plan after approval)
0. **Baseline capture (BEFORE any change).** Run the health-check batches + fill the duel-ratio table on the **current** build. This is the "before"; it must not include the lever-3 fix.
1. **Lever 3 code change** (remove `trigger_parry_window` at both AI block sites) + its test (blocked player attack → no `parried:true`, no player stun, enemy posture loss). Re-run the harness to record the **code-only** effect (and confirm "blocked-pressure breaks" flips to yes).
2. **Rebalance tuning** (levers 1,2,4,5 via data) — iterate against the **duel-ratio targets** with daemon dogfooding (parry-duel + aggressive-dash runs) until the duel reads and both paths win.
3. **Harness acceptance** — skill-sweep inversion gone, facetank win-rate drops, win ~0.5, difficulty curve intact, zero timeouts, duel-ratio targets met.
4. **Record** baseline → code-only → final, plus the chosen knobs.
