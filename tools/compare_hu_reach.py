#!/usr/bin/env python3
"""Compare Hu reach snapshots and fail on gameplay-relevant drift."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _load(path: Path) -> dict:
    with path.open() as handle:
        return json.load(handle)


def _fmt(value: float) -> str:
    return f"{value:.1f}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--max-attack-delta", type=float, default=8.0)
    parser.add_argument("--max-enemy-percent-delta", type=float, default=0.03)
    parser.add_argument("--strict-band", action="store_true")
    args = parser.parse_args()

    before = _load(args.before)
    after = _load(args.after)
    failures: list[str] = []

    print("HU reach before/after")
    print("attack      before  after   delta  range_before  range_after")
    for attack_id in sorted(before["attacks"]):
        b = before["attacks"][attack_id]
        a = after["attacks"].get(attack_id)
        if a is None:
            failures.append(f"missing attack in after snapshot: {attack_id}")
            continue
        delta = float(a["derivedReach"]) - float(b["derivedReach"])
        print(
            f"{attack_id:<10} {_fmt(b['derivedReach']):>6} {_fmt(a['derivedReach']):>6}"
            f" {_fmt(delta):>7} {_fmt(b['rangeUnits']):>13} {_fmt(a['rangeUnits']):>12}"
        )
        if abs(delta) > args.max_attack_delta:
            failures.append(
                f"{attack_id} reach drift {_fmt(delta)} exceeds +/-{_fmt(args.max_attack_delta)}"
            )

    b_light = float(before["attacks"]["hu_light"]["derivedReach"])
    a_light = float(after["attacks"]["hu_light"]["derivedReach"])
    b_min = float(before["enemyBand"]["rangeUnitsMin"])
    b_max = float(before["enemyBand"]["rangeUnitsMax"])
    a_min = float(after["enemyBand"]["rangeUnitsMin"])
    a_max = float(after["enemyBand"]["rangeUnitsMax"])
    print()
    print(f"enemy band before range_units {_fmt(b_min)}..{_fmt(b_max)}")
    print(f"enemy band after  range_units {_fmt(a_min)}..{_fmt(a_max)}")
    print("enemy             shortest  before%  after%  status")
    for enemy_id in sorted(after["enemies"]):
        enemy = after["enemies"][enemy_id]
        if "shortestRangeUnits" not in enemy:
            print(f"{enemy_id:<17} --        --       --      {enemy.get('error', 'missing')}")
            continue
        shortest = float(enemy["shortestRangeUnits"])
        before_pct = (shortest + float(enemy["halfWidth"])) / b_light
        after_pct = (shortest + float(enemy["halfWidth"])) / a_light
        in_after_band = a_min <= shortest <= a_max
        status = "in-band" if in_after_band else "out-of-band"
        print(f"{enemy_id:<17} {_fmt(shortest):>8} {before_pct:>7.3f} {after_pct:>7.3f}  {status}")
        if abs(after_pct - before_pct) > args.max_enemy_percent_delta:
            failures.append(
                f"{enemy_id} reach ratio drift {after_pct - before_pct:+.3f} "
                f"exceeds +/-{args.max_enemy_percent_delta:.3f}"
            )
        if args.strict_band and not in_after_band:
            failures.append(f"{enemy_id} shortest range {_fmt(shortest)} outside after band")

    if failures:
        print()
        print("STOP: reach comparator failed")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print()
    print("reach comparator: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
