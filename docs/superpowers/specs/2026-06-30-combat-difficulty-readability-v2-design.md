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

**Root cause of the node-2 dash wall — NOT yet diagnosed (correction).** An earlier hypothesis blamed an enemy reactive block→auto-parry, but that mechanism no longer exists in the current build: `trigger_parry_window()` fires only on the *player's* `block_pressed` (`combat_system.gd:80`); the AI block action merely sets `is_blocking = true` (`:238`), and `tests/test_enemy_block_no_parry.gd` characterizes "AI block is not a parry." A dasher's punish into a blocking enemy is *blocked* — reduced HP (×`blockHealthMultiplier` 0.2) but **1.6× posture** (`:382`, `blockPostureMultiplier`) — i.e. blocking actually *helps* the dasher's posture goal, just costs HP throughput. So `blockChance` is **not** a proven linchpin, and lowering it could even reduce the dasher's posture pressure. **The actual node-2 death cause is unknown and Phase 1 must diagnose it first** (daemon + harness) before choosing a lever. Candidate causes to test: weak-pool damage output vs the dasher's slower (no-boon) posture accrual; perilous/unblockable attacks (`bandit_thrust_perilous`, `spear_*`) the dasher eats; getting clipped during punish recovery; or the `aggressive_dash` policy's own play quality. **Do not pre-commit to a fix.**

---

## 2. Agreed design (from the grill)
1. **Curve shape — rising ramp.** Each pool (weak → strong → elite → boss) is meaningfully harder; the boss is the peak of a climb, not a spike after a stroll. Target competent pre-boss *fight* win rate ≈ **0.65–0.75** (down from 0.90).
2. **Non-parry — primary viable.** Target a skilled non-parry run (aggressive_dash proxy) at **0.30–0.35** vs parry's ~0.45 (within ~1.3–1.5×, not 3.6×). The lever is **fundamentals**, not granted boons.
3. **Skilled ceiling — held at ~0.40–0.45.** The ramp changes *where* you die, not the best player's final clear rate.
4. **Death timing — attrition early, lethality late.** Early nodes chip HP/posture but rarely kill; lethality ramps to elite/boss. Node-1/2 deaths become rare; a typical run reaches **node 4+** before a loss is likely, so the boon-build loop gets to express itself.
5. **Non-parry node-1 survival — base fundamentals.** Dash i-frame dodge + light-attack punish is the universal node-1 answer (already base tech). Wind boons (`momentum_deflect`, aerial/flurry posture) **amplify** into real posture pressure later; they are not *required* to function. No granted/starting dash boon (preserves the draft + school identity).
6. **Early enemies — readable on-ramps.** Weak pool: long, legible telegraphs, aggressive but honest, **little/no reactive block-parry**. Reactive defense (block→parry, assassin teleport, spear spacing, bear gimmicks) **ramps in** at strong/elite/boss. The early game *teaches* the duel; the mind-games are the late-game test.

---

## 3. Levers (candidate knobs — pick after Phase-1 diagnosis)
- **Telegraph audit (both weak archetypes):** confirm the weak pool's attacks have windups generous enough to dodge-then-punish on reading alone; lengthen windup in `data/Attacks/*.json` if too fast. Cover **both**: `bandit_swordsman` → `bandit_slash`, `bandit_overhead`, `bandit_thrust_perilous`; `bandit_spearman` → `spear_long_thrust`, `spear_wide_swing`. The perilous/long attacks are unblockable-by-design — fine, but each must be *dodgeable* on its telegraph (the diagnosis confirms whether the dasher is dying to an un-dodgeable window).
- **Early enemy damage (if diagnosis shows attrition kills the dasher):** the early-pool *output* is the likely lever, applied via the per-tier pressure multiplier below (turned DOWN for the weak pool, UP for later pools).
- **`blockChance` (only if diagnosis implicates it):** current weak values are `bandit_swordsman` 0.18, `bandit_spearman` 0.13. Lowering it raises the dasher's HP throughput but *removes* the 1.6× blocked-posture bonus — net effect ambiguous, so change it only if Phase 1 shows blocked punishes are the problem. It is **not** the auto-parry fix the earlier draft claimed.
- **Reactive-defense ramp — must be a runtime pool-class modifier, not per-archetype data.** `blockChance` lives per enemy JSON, but `sect_disciple` appears in **both** `strong_pool` and `elite_pool` (`DifficultyCurve.json:6`), so one JSON value can't be both tiers. Implement the ramp as a **per-pool-class `blockChance` override applied at encounter setup** (same runtime-modifier path as the pressure multiplier below), e.g. weak→0, strong→~0.12, elite→~0.25, boss→authored. (Alternatives rejected: split archetypes = data duplication; per-encounter JSON overrides = scattered.)
- **Rising ramp / attrition — per-tier pressure multiplier with an explicit application point.** Add a per-tier multiplier to `DifficultyCurve.json` and **apply it to the HitContext when the attacker is an enemy** — i.e. multiply `ctx.hp_damage` and `ctx.posture_damage` in `resolve_hits` (`combat_system.gd:368-382` region, after the technique/block math) by the enemy's `incoming_pressure_mult`. **Do NOT rely on `enemy.attack_damage`/`attack_posture_damage` (`enemy_factory.gd:33-34)** — pattern attacks use `attack_def.damage`/`attack_def.posture_damage` (`combat_system.gd:368`), so scaling the fighter fields would be a no-op. Store `incoming_pressure_mult` on the enemy `Fighter` at spawn, set from the curve tier in `enemy_factory`/encounter setup. (Optionally also scale enemy `postureMax`/`healthMax` at spawn for the ramp — that path *does* read fighter fields.) Composition levers already exist and are data-only: `weak_count`, `archetype_rank`, `node_type_weights_by_tier`.
- **Boss spike:** with the ramp the Iron Bear stays the peak but the *magnitude* shrinks. Validate post-ramp; only tune IronBear directly if it's still a cliff after the road got harder.

---

## 4. Validation
Two kinds of gate — what the existing checker enforces vs. what is **manual** (the checker does not assert policy bands).

**Commands:**
```bash
for p in parry_duelist aggressive_dash facetank; do
  ./run.sh --playtest-batch --seeds 1..50 --player $p --out /tmp/v2_$p.json
done
./run.sh --playtest-batch --seeds 1..120 --out /tmp/v2_greedy120.json
python3 WUGodot/tools/check_difficulty_curve.py /tmp/v2_greedy120.json
```

**Automated (checker, `tools/check_difficulty_curve.py:79-110`) — must still accept on the 120-seed greedy run:** normal win rate **monotonic non-increasing across ordinals** (this is the rising-ramp shape it already enforces), **boss has the highest death share**, **tier-1 death share < 20%**. Note the checker only *reports* (does not gate) pre-boss/boss conditional win rate.

**Manual gates (compute from the per-policy JSONs — the checker does NOT assert these):**
- `parry_duelist` win ≈ **0.40–0.45** (headline over all 50, never filtered).
- `aggressive_dash` win ≈ **0.30–0.35** (up from 0.125), and its **node-1/2 death share collapses** (compute from `death_by_node_histogram`/transcript `death`).
- `facetank` win ≈ **0.00**.
- **Zero timeouts** in every batch (count transcripts with `outcome == "timeout"`).
- **Competent pre-boss fight win ≈ 0.65–0.75** (down from 0.90) — read `pre_boss_normal_win_rate_report_only` from the checker output on a parry-policy batch, or compute per-fight.
- **Death distribution shifts to the back half**; avg losing-run depth rises (reaches node 4+).
- *(Optional)* extend `check_difficulty_curve.py` (or add a small `analyze_policies.py`) to assert the policy bands + zero-timeouts so these become automated; otherwise they are checklist items the implementer computes and reports at the STOP.
- **Daemon dogfood (feel):** drive a no-boon dasher through nodes 1–2 — first to **diagnose** (Phase 1), then to confirm the fix: dodge → light-punish lands and the dasher survives the early game; then confirm mid/elite fights attrit HP/posture meaningfully.

---

## 5. Sequencing (phases — ordered so each is validated before the next)
1. **Diagnose the node-2 dash death, THEN fix early-game readability.** First drive the daemon with a no-boon `aggressive_dash` run through nodes 1–2 and read the event transcript to find the *actual* cause (see §1 candidates: damage attrition / un-dodgeable perilous window / recovery-frame clips / policy quality). Then apply the lever the diagnosis points to (telegraph lengthening and/or weak-pool damage down via the multiplier; `blockChance` only if implicated). **Gate:** `aggressive_dash` node-1/2 death share collapses and its win lifts off 0.125; parry/facetank unaffected.
2. **Rising ramp + attrition + reactive-defense ramp** — add the per-tier pressure multiplier (`DifficultyCurve.json` + the `incoming_pressure_mult` application point in `resolve_hits`, §3), the per-pool-class `blockChance` runtime override at encounter setup, and composition tuning. **Gate:** competent pre-boss fight win ~0.65–0.75; deaths shift to the back half; lethality late; checker still accepts (monotonic, boss-highest, tier1<20%).
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
- **Code (for the runtime modifiers):** a new `incoming_pressure_mult` field on `Fighter` (default 1.0); `enemy_factory.gd`/encounter setup sets it + the per-pool-class `blockChance` override from the curve tier (`data_manager.gd get_difficulty_curve`); `combat_system.gd resolve_hits` (~:368-382) multiplies `ctx.hp_damage`/`ctx.posture_damage` by the enemy attacker's `incoming_pressure_mult`. Characterization test that an enemy's pressure mult scales dealt damage but the player's stays 1.0.
- **Reuse:** scripted policies (`--player parry_duelist|aggressive_dash|facetank`), `check_difficulty_curve.py`, the interactive daemon, the `--playtest-batch` harness.
