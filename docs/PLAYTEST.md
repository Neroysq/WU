# Agent Playtest Harness

The playtest harness runs WU combat logic headlessly for fast telemetry, and uses the normal rendered scene path for visual capture. It drives seeded runs through the real run/combat services, emits JSON telemetry, and provides PNG capture for agent review workflows.

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
./run.sh --capture /tmp/spec.json /tmp/wu-capture
python3 tools/assert_nonblank.py /tmp/wu-capture/matchup.png
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
{"kind": "matchup", "archetype": "bandit_swordsman", "state": "01_idle"}
```

Supported kinds are `matchup`, `ui`, and `character`.

Useful examples:

```json
{"kind": "matchup", "archetype": "iron_bear", "node_type": "boss", "state": "04_light_active"}
```

```json
{"kind": "ui", "screen": "boon_offer", "school": "venom"}
```

```json
{"kind": "character", "build": [{"boon_id": "venom_light", "tier": "epic"}], "state": "01_idle"}
```

Capture runs non-headless through `main.gd`, using the same viewport readback pattern as `--shot-combat`. Run `tools/assert_nonblank.py` on outputs before trusting them in automated review.
