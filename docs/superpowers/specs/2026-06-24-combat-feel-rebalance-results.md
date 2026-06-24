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

Captured after Lever 3 only: enemy reactive block is block-only, with both AI `trigger_parry_window()` calls removed. No data tuning yet.

Commands:

```bash
./run.sh --probe-duel-ratios
./run.sh --playtest-batch --seeds 1..50 --player heuristic --skill 0.8 --decision greedy --out /tmp/cfr_code_greedy.json
./run.sh --playtest-batch --seeds 1..50 --decision greedy --skill-sweep --out /tmp/cfr_code_sweep.json
python3 WUGodot/tools/check_difficulty_curve.py /tmp/cfr_code_greedy.json
```

### Duel Ratios

The passive/held-block probe is unchanged from baseline. That is expected: the code change removes AI auto-parry from reactive block decisions, while the probe's blocked-pressure scenario directly holds `enemy.is_blocking = true` and never opens a parry window.

| archetype | hp | posture | hp-kill light | break light | break heavy | blocked break | parries break | posture-path kill | posture-path duration | timeout |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| bandit_swordsman | 80 | 85 | 7 | 4 | 3 | 3 | 2 | 5 | 3.25s | false |
| bandit_spearman | 75 | 80 | 7 | 4 | 2 | 3 | 2 | 5 | 2.92s | false |
| wandering_ronin | 110 | 100 | 10 | 5 | 3 | 4 | 3 | 7 | 4.28s | false |
| sect_disciple | 130 | 120 | 11 | 6 | 3 | 4 | 3 | 9 | 5.32s | false |
| masked_assassin | 90 | 85 | 8 | 4 | 3 | 3 | 2 | 5 | 3.25s | false |
| iron_bear | 280 | 160 | 24 | 8 | 4 | 5 | 4 | 20 | 11.33s | false |

### Harness Summary

Greedy heuristic, skill 0.8, 50 seeds:

| metric | baseline | code-only |
|---|---:|---:|
| runs | 50 | 50 |
| win_rate | 0.48 | 0.80 |
| avg_depth | 5.62 | 5.76 |
| avg_combat_duration | 10.96s | 9.52s |
| timeouts | 0 | 0 |

Skill sweep, greedy decision policy, 50 seeds:

| skill | baseline win_rate | code-only win_rate | code-only avg_depth | code-only timeouts |
|---:|---:|---:|---:|---:|
| 0.50 | 0.72 | 0.84 | 5.78 | 0 |
| 0.65 | 0.60 | 0.80 | 5.84 | 0 |
| 0.80 | 0.48 | 0.80 | 5.76 | 0 |
| 0.95 | 0.52 | 0.64 | 5.60 | 0 |

Code-only read: removing enemy auto-parry fixes the unfair reactive-block punishment but makes the current numbers too player-favorable. Data tuning must pull overall win rate back toward the target while preserving the fair block behavior.

### Difficulty Checker

`check_difficulty_curve.py` exited 1, recorded here as code-only signal.

Failure:

```text
normal ordinal 5 win rate rose from 0.929 to 1.000 (> 0.05 tolerance)
```

Key report:

| metric | value |
|---|---:|
| boss_deaths | 5 |
| total_deaths | 10 |
| tier1_death_share | 0.000 |
| boss_conditional_win_rate_report_only | 0.889 |
| pre_boss_normal_win_rate_report_only | 0.981 |

Normal win rate by ordinal:

| ordinal | attempts | wins | win_rate |
|---:|---:|---:|---:|
| 0 | 50 | 50 | 1.000 |
| 1 | 45 | 44 | 0.978 |
| 2 | 29 | 28 | 0.966 |
| 3 | 16 | 16 | 1.000 |
| 4 | 14 | 13 | 0.929 |
| 5 | 5 | 5 | 1.000 |

## Tuning Iterations

### Candidate A

Captured after the Task 4 tuning loop and the harness-policy correction.

Additional code correction:

- `HeuristicPlayer` no longer blocks through the full enemy windup. It reacts during hit-active frames or within 0.12s of active startup, then otherwise keeps normal spacing/attack behavior. This fixes the simulator policy artifact where higher `skill` meant "freeze defensively through every telegraph."

Data changes:

- Enemy HP increased within the no-sponge band: weak +15-23%, ronin/assassin/disciple +31-35%, boss +50%.
- Enemy offense shifted toward health danger, not extra anti-block posture: enemy attack `damage` raised; enemy attack `posture_damage` left at the prior values.
- Strong/boss windups shortened so committed attacks reach the real threat window sooner.
- Enemy aggression raised and reactive block chance lowered so enemies attack instead of turtling.
- `parryPostureDamage` raised from 50 to 60, preserving tier-relative breaks.

Commands:

```bash
./run.sh --probe-duel-ratios
./run.sh --import
./run.sh --test
./run.sh --playtest-batch --seeds 1..50 --player heuristic --skill 0.8 --decision greedy --out /tmp/cfr_candidate_greedy.json
./run.sh --playtest-batch --seeds 1..50 --decision greedy --skill-sweep --out /tmp/cfr_candidate_sweep.json
python3 WUGodot/tools/check_difficulty_curve.py /tmp/cfr_candidate_greedy.json
```

### Candidate Duel Ratios

| archetype | hp | posture | hp-kill light | break light | break heavy | blocked break | parries break | posture-path kill | posture-path duration | timeout |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| bandit_swordsman | 92 | 85 | 8 | 4 | 3 | 3 | 2 | 6 | 3.77s | false |
| bandit_spearman | 86 | 80 | 8 | 4 | 2 | 3 | 2 | 6 | 3.43s | false |
| wandering_ronin | 145 | 100 | 13 | 5 | 3 | 4 | 2 | 10 | 5.83s | false |
| sect_disciple | 175 | 120 | 15 | 6 | 3 | 4 | 3 | 13 | 7.38s | false |
| masked_assassin | 120 | 85 | 10 | 4 | 3 | 3 | 2 | 8 | 4.80s | false |
| iron_bear | 420 | 160 | 35 | 8 | 4 | 5 | 4 | 32 | 17.53s | false |

Read: HP-kill counts are up but stay under the ~1.5x ceiling; posture break counts are unchanged; parry remains tier-relative.

### Candidate Harness Summary

Greedy heuristic, skill 0.8, 50 seeds:

| metric | baseline | code-only | candidate |
|---|---:|---:|---:|
| runs | 50 | 50 | 50 |
| win_rate | 0.48 | 0.80 | 0.48 |
| avg_depth | 5.62 | 5.76 | 5.92 |
| avg_combat_duration | 10.96s | 9.52s | 9.78s |
| timeouts | 0 | 0 | 0 |

Skill sweep, greedy decision policy, 50 seeds:

| skill | baseline win_rate | code-only win_rate | candidate win_rate | candidate avg_depth |
|---:|---:|---:|---:|---:|
| 0.50 | 0.72 | 0.84 | 0.50 | 5.68 |
| 0.65 | 0.60 | 0.80 | 0.46 | 5.88 |
| 0.80 | 0.48 | 0.80 | 0.48 | 5.92 |
| 0.95 | 0.52 | 0.64 | 0.46 | 5.92 |

Read: the low-skill/facetank win rate dropped from 0.72 baseline / 0.84 code-only to 0.50. The sweep is no longer strongly inverted, but it is flat/noisy rather than cleanly non-decreasing.

### Candidate Difficulty Checker

`check_difficulty_curve.py` exits 1 on this candidate.

Failure:

```text
normal ordinal 3 win rate rose from 0.931 to 1.000 (> 0.05 tolerance)
```

Key report:

| metric | value |
|---|---:|
| boss_deaths | 24 |
| total_deaths | 26 |
| tier1_death_share | 0.000 |
| boss_conditional_win_rate_report_only | 0.500 |
| pre_boss_normal_win_rate_report_only | 0.988 |

Normal win rate by ordinal:

| ordinal | attempts | wins | win_rate |
|---:|---:|---:|---:|
| 0 | 50 | 50 | 1.000 |
| 1 | 46 | 46 | 1.000 |
| 2 | 29 | 27 | 0.931 |
| 3 | 16 | 16 | 1.000 |
| 4 | 14 | 14 | 1.000 |
| 5 | 6 | 6 | 1.000 |

Read: boss gating, no tier-1 deaths, and zero timeouts are good. The remaining issue is pre-boss normal pressure: only two strong-normal deaths occurred in the 50-seed candidate batch, so the small-sample ordinal check still fails.

### Daemon Smoke

Commands were driven through the interactive daemon file transport under `/tmp/wu-playtest/`.

Verified:

- Daemon command/response loop worked.
- Screenshots were read-only (`mutated:false`) and nonblank:
  - `/tmp/wu-playtest/cfr-candidate/shots/parry_ronin_start_3.png`
  - `/tmp/wu-playtest/cfr-bandit/shots/parry_bandit_end_444.png`
- Event streams included attacks, phase changes, hits, whiffs, stuns, deaths where applicable.

Manual-script dogfood is inconclusive: the simple scripted command loops produced hits/stuns but did not reliably finish fights, and one aggressive ronin script lost. I did not tune combat around those scripts; the reliable decision point remains the probe + batch telemetry above.

## Final

Pending Task 5 / user balance verdict.
