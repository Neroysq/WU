# Per-School Duel Hooks - Wind Slice Results

Date: 2026-06-24

## Summary

Accepted implementation for the Wind slice. Wind now gives the aggressive-dash policy a posture-duel path without changing global combat numbers or enemy data.

## Implemented

- `on_dash_through(fighter, enemy) -> Dictionary` now returns merged effect results.
- `momentum_deflect` adds dash-through posture pressure and momentum.
- `CombatSystem.apply_posture_break_aware()` is shared by normal hits and dash-through posture so posture breaks still stun, record, and fire `on_posture_break`.
- Dash-through posture is gated once per contact and records one `dash_through` event.
- `momentum_aerial` scales `ctx.posture_damage`.
- `momentum_flurry` adds posture to the main hit, not `extra_hits`.
- `--probe-duel-ratios --wind` installs a fixed Wind loadout and reports aerial, flurry, and dash-through posture.
- Boon text now describes posture riders and templates `momentum_deflect`.

## Final Wind Knobs

| Area | Value |
| --- | --- |
| Wind dash commons | `momentum_deflect` rider on `wind_descending_leaf`, `wind_sparrow_wing`, `wind_flowing_water` |
| Dash-through deflect | 28 posture, +18 momentum, once per contact |
| Wind light common | `momentum_flurry` threshold 35, cost 15, +12 posture, +3 flurry damage |
| Wind light common rider | movement builds 12 momentum/s, decay 6/s |
| Wind jump common | aerial HP x1.25, posture x2.0, +10 landing momentum |

## Validation

Commands:

```bash
./run.sh --import
./run.sh --test
./run.sh --probe-duel-ratios --wind
./run.sh --playtest-batch --seeds 1..50 --player aggressive_dash --decision school --school wind --out /tmp/wind_aggressive_dash.json
./run.sh --playtest-batch --seeds 1..50 --player facetank --decision school --school wind --out /tmp/wind_facetank.json
./run.sh --playtest-batch --seeds 1..120 --out /tmp/wind_greedy_120.json
python3 WUGodot/tools/check_difficulty_curve.py /tmp/wind_greedy_120.json
```

Results:

| Gate | Result |
| --- | --- |
| Import | pass |
| Unit/integration tests | 542 passed / 0 failed |
| Wind probe | aerial 44.0 posture, flurry 34.0 posture, dash-through 28.0 posture, 1 event, +18 momentum, no timeout |
| Aggressive dash + school Wind | 10/50 wins = 0.20 |
| Facetank + school Wind | 0/50 wins = 0.00 |
| Wind acquisition in aggressive batch | 24/50 runs; 9/24 Wind runs won; avg first Wind node 4.67 |
| Timeouts | 0 in aggressive, facetank, and 120-seed regression batches |
| Difficulty regression | accepted; boss deaths 29, max non-boss node 28, tier-1 death share 0.0119 |

## Notes

- The baseline aggressive-dash result from the combat-feel rebalance was 0.08. This slice lifts it to 0.20 while keeping facetank at 0.00.
- The broad 120-seed greedy batch lands at 0.30 win rate with Wind final-school win rate 0.405. This is higher than the pre-Wind skill floor, but the difficulty-curve gate still accepts and boss remains the highest death-share point.
- The non-headless daemon was not separately driven in this pass; the same dash-through posture event is covered by `test_wind_duel_hooks.gd` and `--probe-duel-ratios --wind`.

## Next Schools

Use the same pattern for the next school:

- keep posture application owned by `CombatSystem`;
- return effect intent through hook dictionaries;
- add source-level recorder events when the interaction matters to triggers/telemetry;
- gate the school with one scripted policy and one probe mode before tuning content numbers.
