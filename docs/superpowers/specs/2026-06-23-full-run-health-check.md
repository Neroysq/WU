# Full-Run Health Check (difficulty + boons + visuals integrated)

**Date:** 2026-06-23 · Method: playtest harness batches (heuristic player, 50 seeds greedy/random, skill-sweep, 30 seeds per school-focused). Data: `/tmp/hc_*.json`.

## Headline

The **difficulty *composition* is healthy**, but the **combat rewards facetanking over defense**, the **build depth isn't paying off** (mastery is unreachable, smart-building ≈ random), and there's **moderate school imbalance**. Baseline: win 0.48, avg depth 5.6, at heuristic skill 0.8.

## Findings (prioritized)

### F1 — Defense is underpowered; facetanking wins (HIGH)
Skill sweep is **inverted**: win 0.72 (skill 0.5) → 0.60 → 0.48 (0.8) → 0.52 (0.95); boss win 0.84 (0.5) vs 0.62 (0.95). The heuristic's "skill" gates **defensive reactions** (block/dash the enemy's active attack; `heuristic_player.gd:21`) — so *higher* skill = blocks/dashes more, *lower* skill = ignores incoming and keeps attacking. **The aggressive player wins more, even at the boss.**
- Root cause in the economy: player deals **134 dmg/combat, takes 25**; normals barely threaten (weak/strong win 0.98). Blocking/dashing **wastes offense** and you can out-DPS everything, boss included.
- Impact: the defensive layer of the wuxia combat (block / dash-iframes / parry) is **not worth using** — skill expression is suppressed.
- Levers: raise enemy offense (damage / posture pressure / mix-ups), lower the opportunity cost of defending, or make defense *enable* bigger punishes (parry → riposte windows). Re-run the sweep; a healthy curve has win **rise** with skill.

### F2 — Mastery is dead content (HIGH, cheap to fix)
`mastery_reached_rate ≈ 0.02` across **every** config — even **school-focused** runs (venom-focused mastery 0.00). The 3-of-a-school capstone is essentially never reached in a ~5.5-combat run.
- Likely: offers spread across schools + run length/Insight don't allow 3-of-one + the mastery offer. The deepest #2 payoff is unseen.
- Levers: bias offers toward already-picked schools, lower the mastery threshold, or surface mastery once eligible. Quick to tune + re-measure `mastery_reached_rate`.

### F3 — Build choices feel ~neutral (MEDIUM; suggestive)
Greedy build win **0.48** ≤ random build **0.56** (8pp; within ~2 SE so suggestive, not conclusive). Smart building doesn't beat random picking → boon decisions aren't moving outcomes much; #2's "meaningful choices" aren't landing in win rate.
- Levers: widen power deltas between picks/rarities so choice matters; or the greedy policy itself is mis-heuristic (worth a look). Re-measure greedy−random gap.

### F4 — School imbalance (MEDIUM)
Greedy win-rate by school: **venom 0.67** (top) … **sword 0.43** (bottom), ~24pp spread (school-focused: venom 0.57 vs wind/sword 0.43–0.47). Venom over-performs; sword/wind lag.
- Levers: buff sword/wind riders or trim venom; target ≤ ~10pp spread.

## Healthy (leave alone)
- **Difficulty composition** (#1 working): weak/strong 0.98, elite 0.92, **boss 0.53** wall; win non-rising by ordinal; **tier-1 deaths 1/26**, **21/26 deaths at boss**; **0 timeouts/stalls**.
- **Boons mechanically active**: ~118 procs + 8.2 status applications per combat.

## Caveat
The heuristic player is a proxy, so F1's *magnitude* is model-dependent — but the underlying **134-vs-25 damage economy** confirms facetank dominance is real, not just an AI artifact. F1 and F2 are the highest-leverage for making a run *feel* like it rewards skill and build investment.
