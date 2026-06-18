# WU — Difficulty Curve (Chapter 1) — Design

**Date:** 2026-06-18
**Status:** draft (pre-plan) — for user review
**Sub-project:** #1 of the "complete fun run" effort (difficulty curve). Builds on the run/combat systems and is validated by the playtest harness.

**Goal:** Make a run ramp **easy → hard with depth** within a chapter, via **enemy composition** (which enemies appear), not stat inflation — and prove the ramp with harness telemetry.

**Why:** Today every battle pulls from the same easy/medium pool regardless of `node.tier`; the depth signal exists but is unused, so the run never ramps.

---

## 1. Decided (from brainstorming)

- **Composition-only** ramp (no enemy stat inflation in chapter 1).
- **Fixed function of depth** (deterministic, seed-stable; no adaptive/rubber-band).
- **StS-informed model:** a discrete **weak → strong normal pool** gate by depth, plus a separate **elite tier** and the **boss** wall — rather than a smooth per-tier gradient.
- **Validated by the harness** (`win-rate-by-depth`, `death-by-node`).
- **Stat-scaling is the explicit escalation lever for *cross-chapter / a difficulty mode* (the StS "new act + Ascension" analog), NOT chapter 1.**

---

## 2. Reference: how Slay the Spire does it (what we're copying)

- Within an act, normal enemies are **not** stat-scaled by room. There are two normal pools — **weak** and **strong**; the **first ~3 monster rooms use the weak pool**, the rest use the **strong pool** (a discrete switch by encounter index, with anti-immediate-repeat).
- **Elites** are a separate, tougher, opt-in pool on elite nodes; **boss** is its own pool (the act wall).
- The *big* escalation is **cross-act (entirely new, stronger pools) + Ascension (global stat/behavior modifiers)** — never per-room scaling inside an act.
- **Key difference for WU:** StS's "strong" leans on **multi-enemy groups**; WU is **single-enemy**, so our "strong" must come from **tougher archetypes + longer ambush gauntlets** — a thinner lever with only 5 archetypes (see §6 constraint).

---

## 3. Model

A chapter defines four encounter sets + a depth gate:

- **Weak pool** — easy archetypes (bandit_swordsman, bandit_spearman). Used by the **first normal combats**.
- **Strong pool** — tougher archetypes (wandering_ronin, sect_disciple). Used by **later** normal combats. (`masked_assassin` is elite-only, not here.)
- **Elite pool** — the toughest archetypes, on **ELITE** nodes (opt-in spikes).
- **Boss** — iron_bear (tier 6 wall), fixed.
- **Ambush** — sequential 1v1 gauntlet; pulls from the depth-appropriate pool, **escalating** within the gauntlet.

**Depth gate:** a `weak_count` — the first **N** normal combats of the run (by per-combat ordinal, §4) use the weak pool; subsequent normal combats use the strong pool (mirrors StS's "first 3 weak"). **v1 default `weak_count = 1`** (only the first normal combat is weak; the rest are strong), with elite/ambush density rising at tier 4. Tuned via harness. Pool placement: `sect_disciple` is in the **strong** normal pool; `masked_assassin` is **elite-only** initially (so normals have teeth without spiking too hard).

---

## 4. Architecture (data-driven, fixed by depth)

- **`data/Difficulty/DifficultyCurve.json`** (per chapter):
  ```json
  { "chapter": 1,
    "weak_pool": ["bandit_swordsman", "bandit_spearman"],
    "strong_pool": ["wandering_ronin", "sect_disciple"],
    "elite_pool": ["sect_disciple", "masked_assassin"],
    "boss": "iron_bear",
    "weak_count": 1,
    "no_immediate_repeat": true,
    "ambush": { "length_by_tier": {"1":3,"4":4}, "escalate": true },
    "node_type_weights_by_tier": { "1": {...}, "2": {...}, "4": {...} } }
  ```
- **`EncounterResolver` (new) — the API boundary (reviewer P1).** `CombatSetup.prepare`/`EnemyFactory.create_enemy_for_node` only receive `node` today (no `run_state`). Rather than thread `run_state` everywhere, add `EncounterResolver.resolve(run_state, node, wave) -> archetype` that runs **before combat starts** and selects weak/strong/elite/boss, then flows the result through the **existing `forced_archetype` parameter** of `combat_scene.setup_combat`/`CombatSetup.prepare`/`sim.simulate`. **The resolver is called at each side's run_state-aware call site:** live, that's `main._setup_combat_for_node` (~`main.gd:184`, which has `run_state`) → it resolves, then passes `forced_archetype` into `combat_scene.setup_combat(...)` (which itself has no `run_state`); harness, that's `run_driver` → `combat_sim`. Same resolver both sides, so they can't diverge; `enemy_factory`/`CombatSetup` signatures stay as-is. Uses seeded `RngService` (no local `randomize()`).
- **Counter on `run_state` (reviewer P1).** Track **`normal_combats_started`** — counts **normal fights only (battle + each ambush wave)**, NOT elite/boss (those map straight to `elite_pool`/`boss`). For a normal fight, the resolver **selects on the pre-increment value** (`normal_combats_started < weak_count` ⇒ weak, else strong) and **increments after** selecting — so with `weak_count=1` and a start of 0, the first normal fight (0<1) is weak, the next (1<1 false) is strong. Keep the existing **node-clear** tracking separate (run progress). The ambush **wave index** (`ambush_length − ambush_remaining`) drives in-gauntlet escalation. (If the counter only advanced on node-clear, all ambush waves would share one pool — the bug to avoid.)
- **`run_state._pick_node_type`** — fed from `node_type_weights_by_tier` (more elite/ambush deeper).
- **Anti-repeat** — resolver doesn't draw the same weak archetype twice in a row (StS rule).

All knobs live in data → tunable without code, and the harness drives the tuning.

---

## 5. Validation loop (the harness earns its keep)

- **Telemetry linkage (reviewer P2):** add `node_id`, `combat_ordinal`, `pool_class` (`weak|strong|elite|boss`), and `ambush_wave` to `CombatResult`/transcript (the resolver already knows these — pass them into `sim.simulate`). Without them the harness can't prove "weak never after the gate," "boss hardest," or attribute deaths in **multi-fight ambush nodes**.
- Harness **batch** (N seeds, heuristic player @ skill 0.8, greedy build) → **win-rate by `combat_ordinal`/tier/`pool_class`** + **death-by-node/ordinal histogram**.
- **Acceptance:** mid-depth win rate **holds within ±5 pp** and never rises with depth; **boss win rate drops ~10–15 pp below the pre-boss rate (or is the single highest death share)**; **tier-1 deaths stay < 20% of all deaths**; and **no weak-pool archetype ever appears at `normal_combat_ordinal ≥ weak_count`** (the weak gate is normal-only; elite/boss don't consume it).
- A **content/structure test**: weak-pool archetypes never appear after the gate flips to strong on the same run; elite nodes only use `elite_pool`; no chapter-1 stat inflation.
- If the curve **rises** with depth, the harness has proven composition-only is insufficient for this roster → §6 escalation.

---

## 6. The real constraint + escalation path (decided by data, not guess)

Single-enemy combat + only 5 archetypes + no stat scaling is a **tight envelope** for a real ramp over a short run. StS leans on multi-enemy groups and cross-act pools/Ascension; WU can't (yet). So the spec commits to a **harness-gated escalation order** if composition alone can't make win-rate decline with depth:
1. **Tune composition first** (weak_count, elite/ambush density, ambush length) — free.
2. **Add archetypes** to thicken weak/strong pools (content work, separate spec).
3. **Introduce the stat lever** as a **cross-chapter / difficulty-mode** multiplier (the StS Ascension analog) — explicitly *not* chapter-1 per-room scaling.

The harness data picks the lever; we don't pre-commit to inflation.

---

## 7. Out of scope / YAGNI

- Enemy stat scaling within chapter 1 (escalation fallback only, §6).
- Adaptive/rubber-band difficulty.
- New archetypes / new chapters (their own specs).
- Boss changes (iron_bear stays the wall).

---

## 8. Resolved decisions

1. **`weak_count = 1`** (short runs; tier-1 weak, then strong normals — enough curve signal for the harness).
2. **Pool placement:** `sect_disciple` → **strong** normals; `masked_assassin` → **elite-only** initially (teeth without over-spiking normals).
3. **Acceptance:** mid-depth win rate holds within **±5 pp** (never rising); **boss ~10–15 pp below pre-boss** (or the highest death share); **tier-1 deaths < 20%** of all deaths.

---

## 9. Sequencing (phases — full plan after approval)

1. **Data + resolver:** `DifficultyCurve.json` + `DataManager` loader; `EncounterResolver.resolve(run_state, node, wave)` (seeded) returning weak/strong/elite/boss archetype, anti-repeat. Wire it through the existing `forced_archetype` at each run_state-aware call site: live, `main._setup_combat_for_node` (~`main.gd:184`) resolves then passes `forced_archetype` into `combat_scene.setup_combat`; harness, `run_driver`/`combat_sim`.
2. **Counter + node mix:** `run_state.normal_combats_started` (normal fights only — battle + ambush waves; not elite/boss), resolver selects on the **pre-increment** value then increments; keep node-clear separate; `node_type_weights_by_tier` in `_pick_node_type`; ambush wave-index escalation.
3. **Telemetry:** add `node_id`/`combat_ordinal`/`pool_class`/`ambush_wave` to `CombatResult`/transcript via `sim.simulate`.
4. **Tests:** structure tests (no weak after gate, elite-only `masked_assassin`, no stat inflation, ambush waves escalate) + harness batch acceptance (§5 thresholds).
5. **Tune via harness** to the acceptance curve; record the chosen knobs and whether §6 escalation was needed.
