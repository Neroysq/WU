# Combat Difficulty & Readability v2 — Design

**Date:** 2026-06-30
**Status:** draft (pre-plan) — for user review
**Origin:** playtest of the current build (40 seeds/policy) + a grilling session that resolved the intended curve, playstyle viability, and death-timing. Builds on the combat-feel rebalance (posture duel = win path) and the Wind duel hooks.

**Goal:** Reshape combat difficulty from a *flat-then-cliff* curve into a *rising ramp*, and make the early game a readable skill on-ramp so non-parry builds are viable from node 1 — without lowering the skilled-player ceiling.

---

## 1. Playtest evidence (the problem)
40 seeds per scripted policy, current build:

| Policy | Win | Avg depth | Death cluster |
|---|---|---|---|
| parry_duelist | 0.45 | 5.5 | **boss (node 6): 15 of 22** |
| greedy (default) | 0.275 | 4.6 | spread 2/4/6 |
| aggressive_dash | 0.125 | 4.0 | **early (node 2): 16** |
| facetank | 0.00 | 1.9 | node 2 |

- **Pre-boss normal win rate ≈ 0.90** (report-only) — a competent player cruises 5 nodes, then the Iron Bear is a cliff. Difficulty is back-loaded onto one fight.
- **Playstyles fail at opposite ends:** parry dies *late* (boss), aggressive-dash dies *early* (node 2). Non-parry can't clear the early game, not merely "weaker late."
- **Parry is 3.6× the dash win rate** (0.45 vs 0.125) despite the Wind hooks and the stated goal that non-parry be viable.

**Root cause of the node-2 dash wall (confirmed in code):** weak-pool enemies have `blockChance` 0.18 (`BanditSwordsman.json:24`); `ai_brain.gd:38` reactive-blocks on that chance when the player attacks; `combat_system.gd:81` opens a **parry window on any block** — so a no-boon dasher dodges in, lights, the enemy reactive-blocks and **auto-parries the punish**, and the dasher gets stunned. Fundamentals can't carry the early game while the *first* enemies you meet punish a clean punish.

---

## 2. Agreed design (from the grill)
1. **Curve shape — rising ramp.** Each pool (weak → strong → elite → boss) is meaningfully harder; the boss is the peak of a climb, not a spike after a stroll. Target competent pre-boss *fight* win rate ≈ **0.65–0.75** (down from 0.90).
2. **Non-parry — primary viable.** Target a skilled non-parry run (aggressive_dash proxy) at **0.30–0.35** vs parry's ~0.45 (within ~1.3–1.5×, not 3.6×). The lever is **fundamentals**, not granted boons.
3. **Skilled ceiling — held at ~0.40–0.45.** The ramp changes *where* you die, not the best player's final clear rate.
4. **Death timing — attrition early, lethality late.** Early nodes chip HP/posture but rarely kill; lethality ramps to elite/boss. Node-1/2 deaths become rare; a typical run reaches **node 4+** before a loss is likely, so the boon-build loop gets to express itself.
5. **Non-parry node-1 survival — base fundamentals.** Dash i-frame dodge + light-attack punish is the universal node-1 answer (already base tech). Wind boons (`momentum_deflect`, aerial/flurry posture) **amplify** into real posture pressure later; they are not *required* to function. No granted/starting dash boon (preserves the draft + school identity).
6. **Early enemies — readable on-ramps.** Weak pool: long, legible telegraphs, aggressive but honest, **little/no reactive block-parry**. Reactive defense (block→parry, assassin teleport, spear spacing, bear gimmicks) **ramps in** at strong/elite/boss. The early game *teaches* the duel; the mind-games are the late-game test.

---

## 3. Levers (concrete knobs)
- **Kill the early reactive auto-parry (the linchpin):** weak pool (`bandit_swordsman`, `bandit_spearman`) `blockChance 0.18 → ~0.0`. This removes the block→parry that eats a no-boon punish (`ai_brain.gd:38` + `combat_system.gd:81`). Keep their aggression honest (~0.55) so they still pressure.
- **Telegraph audit:** confirm the weak pool's attacks (`pattern_table`: `bandit_slash`, `bandit_overhead`, `bandit_thrust_perilous`) have windups generous enough to dodge-then-punish on reading alone (lengthen windup in `data/Attacks/*.json` if too fast). Note: `bandit_thrust_perilous` is unblockable-by-design — fine, but it must be *dodgeable* on telegraph.
- **Reactive-defense ramp by pool:** `blockChance` rises with tier — weak ~0.0, strong (`wandering_ronin`/`sect_disciple`) ~0.12–0.18, elite (`masked_assassin`) ~0.25+, boss its own. So the "block opens a parry" mind-game is a late-game test, not a first-node ambush.
- **Rising ramp / attrition:** scale per-tier *pressure* so mid/elite fights chip more HP/posture (lethal late) while weak fights attrit but rarely kill. Prefer a **per-tier pressure multiplier** in `DifficultyCurve.json` (applied to enemy attack HP/posture damage and/or postureMax/HP) over hand-editing every enemy — cleaner, and it pre-builds the seam for the deferred difficulty *tiers* (this pass calibrates "Normal"/Wanderer). Composition levers already exist: `weak_count`, `archetype_rank`, `node_type_weights_by_tier`.
- **Boss spike:** with the ramp the Iron Bear stays the peak but the *magnitude* shrinks. Validate post-ramp; only tune IronBear directly if it's still a cliff after the road got harder.

---

## 4. Validation (the gate — harness is the measurement)
Over **50 seeds per policy** (unforced/greedy boon picks; headline win over all 50, never filtered):
- `parry_duelist` ≈ **0.40–0.45** (held), dies mostly at boss.
- `aggressive_dash` ≈ **0.30–0.35** (up from 0.125), **node-1/2 death share collapses**.
- `facetank` ≈ **0.00** (unchanged — facetanking still loses).
- **Zero timeouts.**
- **Competent pre-boss fight win ≈ 0.65–0.75** (down from 0.90).
- **Death distribution shifts to the back half**; avg losing-run depth rises (reaches node 4+); node-1/2 death share drops sharply.
- `python3 WUGodot/tools/check_difficulty_curve.py` **accepts** at 120 seeds.
- **Daemon dogfood (feel):** drive a no-boon dasher through nodes 1–2 — confirm dodge → light-punish *lands* (enemy no longer reactive-parries); then confirm mid/elite fights attrit HP/posture meaningfully.

---

## 5. Sequencing (phases — ordered so each is validated before the next)
1. **Early-pool readability** — weak `blockChance → ~0`; telegraph audit/lengthen on the weak attacks. **Gate:** `aggressive_dash` node-1/2 death share collapses and its win lifts off 0.125 (readability alone should move it). Parry/facetank unaffected.
2. **Rising ramp + attrition + reactive-defense ramp** — per-tier pressure multiplier (`DifficultyCurve.json`), `blockChance` ramp by pool, composition tuning. **Gate:** competent pre-boss fight win ~0.65–0.75; deaths shift to the back half; lethality late.
3. **Re-validate + tune** — full 50-seed policy sweep to the §4 targets (parry 0.40–0.45, dash 0.30–0.35, facetank 0.00), 120-seed checker accepts, zero timeouts, daemon feel pass. Tune knobs to hit the bands. ✋ **STOP** for the user's verdict.
4. **Record** — before/after table, the per-tier pressure values, and the note that this calibrates the "Normal" difficulty tier (feeds the deferred difficulty-selection slice).

---

## 6. Out of scope (YAGNI)
- Difficulty *tier selection* (Tranquil/Wanderer/Demon) — this pass calibrates the baseline "Normal"; the selector is the deferred slice in `2026-06-25-settings-keybinding-design.md` §5.
- New enemies, new boss, or boss redesign (only magnitude tuning if still a cliff post-ramp).
- The other schools' duel hooks (Soft/Iron/Venom/Thunder/Sword) — independent track.
- New AI behaviors/memory beyond the blockChance ramp (the legacy aggression ramp stays).

## 7. Components
- **Data:** `data/Enemies/*.json` (`blockChance` per pool, possibly `aggression`/HP/posture), `data/Attacks/*.json` (weak-attack windups), `data/Difficulty/DifficultyCurve.json` (per-tier pressure multiplier + composition).
- **Code (only if a per-tier multiplier is added):** the difficulty/enemy-factory path that applies the curve (`enemy_factory.gd`, `data_manager.gd get_difficulty_curve`) reads + applies the multiplier.
- **Reuse:** scripted policies (`--player parry_duelist|aggressive_dash|facetank`), `check_difficulty_curve.py`, the interactive daemon, the `--playtest-batch` harness.
