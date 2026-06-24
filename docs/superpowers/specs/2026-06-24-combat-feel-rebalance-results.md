# Combat-Feel Rebalance Results

**Date:** 2026-06-24
**Plan:** `docs/superpowers/plans/2026-06-24-combat-feel-rebalance.md`

This record tracks the required baseline -> code-only -> final measurements for the combat-feel rebalance.

## Baseline

Captured before any combat behavior or balance changes, after adding only the duel-ratio probe tool.

Commands:

```bash
./run.sh --probe-duel-ratios
./run.sh --playtest-batch --seeds 1..50 --player heuristic --skill 0.8 --decision greedy --out /tmp/cfr_base_greedy.json
./run.sh --playtest-batch --seeds 1..50 --decision greedy --skill-sweep --out /tmp/cfr_base_sweep.json
python3 WUGodot/tools/check_difficulty_curve.py /tmp/cfr_base_greedy.json
```

### Duel Ratios

| archetype | hp | posture | hp-kill light | break light | break heavy | blocked break | parries break | posture-path kill | posture-path duration | timeout |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| bandit_swordsman | 80 | 85 | 7 | 4 | 3 | 3 | 2 | 5 | 3.25s | false |
| bandit_spearman | 75 | 80 | 7 | 4 | 2 | 3 | 2 | 5 | 2.92s | false |
| wandering_ronin | 110 | 100 | 10 | 5 | 3 | 4 | 3 | 7 | 4.28s | false |
| sect_disciple | 130 | 120 | 11 | 6 | 3 | 4 | 3 | 9 | 5.32s | false |
| masked_assassin | 90 | 85 | 8 | 4 | 3 | 3 | 2 | 5 | 3.25s | false |
| iron_bear | 280 | 160 | 24 | 8 | 4 | 5 | 4 | 20 | 11.33s | false |

Probe JSON: `/tmp/duel_ratios/probe.json`

### Harness Summary

Greedy heuristic, skill 0.8, 50 seeds:

| metric | value |
|---|---:|
| runs | 50 |
| win_rate | 0.48 |
| avg_depth | 5.62 |
| avg_combat_duration | 10.96s |
| timeouts | 0 |

Skill sweep, greedy decision policy, 50 seeds:

| skill | win_rate | avg_depth | timeouts |
|---:|---:|---:|---:|
| 0.50 | 0.72 | 5.56 | 0 |
| 0.65 | 0.60 | 5.76 | 0 |
| 0.80 | 0.48 | 5.62 | 0 |
| 0.95 | 0.52 | 5.40 | 0 |

Baseline read: the sweep is inverted at the low end; lower-skill aggression wins more often than the reaction-defense policy.

### Difficulty Checker

`check_difficulty_curve.py` exited 0.

Key report:

| metric | value |
|---|---:|
| boss_deaths | 21 |
| total_deaths | 26 |
| tier1_death_share | 0.038 |
| boss_conditional_win_rate_report_only | 0.533 |
| pre_boss_normal_win_rate_report_only | 0.981 |

Normal win rate by ordinal:

| ordinal | attempts | wins | win_rate |
|---:|---:|---:|---:|
| 0 | 50 | 49 | 0.980 |
| 1 | 43 | 42 | 0.977 |
| 2 | 28 | 27 | 0.964 |
| 3 | 15 | 15 | 1.000 |
| 4 | 13 | 13 | 1.000 |
| 5 | 5 | 5 | 1.000 |

Death share by node:

| node | deaths |
|---|---:|
| 12:boss | 11 |
| 13:boss | 10 |
| 1:weak | 1 |
| 4:elite | 2 |
| 4:strong | 1 |
| 8:strong | 1 |

## Code-Only

Pending Task 3.

## Tuning Iterations

Pending Task 4.

## Final

Pending Task 5.
