# Agent Playtest Harness

The playtest harness runs WU without rendering combat frames. It drives seeded runs through the real run/combat services, emits JSON telemetry, and provides a thin visual capture command for agent review workflows.

## Commands

Single run:

```bash
./run.sh --playtest --seed 1 --player heuristic --decision greedy --out /tmp/wu-run.json
```

Batch:

```bash
./run.sh --playtest-batch --seeds 1..20 --player heuristic --decision greedy --out /tmp/wu-batch.json
```

Skill sweep:

```bash
./run.sh --playtest-batch --seeds 1..20 --decision greedy --skill-sweep --out /tmp/wu-sweep.json
```

Visual capture:

```bash
./run.sh --capture /tmp/spec.json --out /tmp/wu-capture
```

## Policies

Player policies:

- `heuristic`: default, skill `0.8`, accepts `--skill 0.0..1.0`.
- `scripted`: fixed input replay hook for deterministic targeted cases.

Decision policies:

- `greedy`: prefers school synergy, empty move slots, duos/masteries, and cheaper shop picks.
- `random`: seeded random choices.
- `school`: prefers `--school <id>`.
- `scripted`: fixed pick replay hook.

## Telemetry

`CombatResult` includes:

- enemy archetype, node type, tier, winner, duration, frames, timeout flag.
- player/enemy HP before and after, minimum posture, damage dealt/taken.
- `boon_procs` and `status_applications`.

`RunTranscript` includes:

- seed, policies, outcome, depth reached, death node, gold, insight.
- node choices, combat results, build snapshots, and run totals.

Batch summaries include:

- `runs`, `win_rate`, `avg_depth`.
- `death_by_node_histogram`.
- `win_rate_by_school`.
- `mastery_reached_rate`.
- raw transcripts for drilldown.

## Determinism

For the same seed and policies, the harness should produce the same run outcome and depth. `RngService` owns cached per-domain streams during a seeded run; streams advance within the run and reset when a new run seed is set. Cosmetic FX RNGs are intentionally out of scope.

## Capture Specs

Capture specs are JSON dictionaries with a `kind` field:

```json
{"kind": "matchup"}
```

Supported kinds are `matchup`, `ui`, and `character`. The current capture path writes PNG output for automation smoke checks; existing `--shot-combat` and `--shot-action` remain the high-fidelity combat review tools.

