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
3. **Fix the duel fairness (THE code change).** Enemy reactive block becomes **block-only** — remove the `trigger_parry_window()` on AI block (`combat_system.gd:229-230, 259-260`). Pressuring a blocking enemy then **chips + bleeds its posture (1.6×) toward a break** (good!) instead of coin-flip parrying the player. (Deliberate, telegraphed enemy parry can return later as an archetype ability — out of scope.)
4. **No turtling.** Keep player block bleeding own posture (1.6×) so holding block loses to posture-break — defense is active (parry/space/dash), not passive.
5. **Parry stays a strong tool, not the only one.** Verify ~55 parry-posture breaks an 85-posture enemy in ~2 well-timed parries → stun → punish. Don't buff parry to the point other paths are dominated.

## Validation
- **Daemon dogfooding (primary).** Drive fights via the interactive daemon and confirm: (a) facetank now loses; (b) **parry-duel** path works (parry→break→punish, build burst lands in the stun); (c) **aggressive-dash** path also wins without parrying. The batch heuristic can't parry, so hands-on is the real feel check — across at least these two playstyles.
- **Harness (gross checks).** Re-run the health-check batches: the **skill-sweep is no longer inverted** (win rate non-decreasing with skill; the low-skill/facetank win rate drops from ~0.72); overall win ~0.5; **difficulty curve still holds** (boss = highest death share, non-rising by ordinal, tier-1 deaths <20%); zero timeouts.
- **Deferred companion:** teach `HeuristicPlayer` to parry (so the skill-sweep becomes a true duel-skill metric) — its own task, not this pass.

## Out of scope (follow-ups)
- Posture-break payoff/deathblow mechanic; per-school duel hooks (build-into-posture); telegraphed enemy parry as an archetype ability; the heuristic-parry upgrade.

## Tuning knobs (where the numbers live)
- `data/Attacks/Attacks.json` (per-attack `damage` vs `posture_damage`, perilous flags), `data/Enemies/*` (enemy HP/posture/aggression/blockChance), `GameConstants` (`POSTURE_*`, `PARRY_WINDOW`, `STUN_DURATION`, block multipliers), combat `settings` (block/parry multipliers). All retunable without code except lever 3.

## Sequencing (phases — full plan after approval)
1. **Lever 3 code change** (enemy block→block-only) + a test (attacking a blocking enemy deals posture, not a parry on the player).
2. **Baseline capture** — run the health-check batches pre-change; record current numbers as the before.
3. **Rebalance tuning** (levers 1,2,4,5 via data) — iterate with daemon dogfooding (parry-duel + aggressive-dash runs) until the duel reads.
4. **Harness acceptance** — skill-sweep inversion gone, facetank drops, win ~0.5, difficulty curve intact; record the chosen numbers.
5. **Record** before/after + the validated knobs.
