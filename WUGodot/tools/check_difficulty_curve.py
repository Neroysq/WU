#!/usr/bin/env python3
import json
import sys
from collections import defaultdict


TOLERANCE = 0.05


def _rate(wins, attempts):
    return float(wins) / float(attempts) if attempts else 0.0


def _load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _combat_won(combat):
    return str(combat.get("winner", "")) == "player"


def _death_record(transcript):
    death = transcript.get("death", {})
    return death if isinstance(death, dict) else {}


def _is_boss(record):
    return str(record.get("pool_class", "")) == "boss" or str(record.get("enemy_archetype", "")) == "iron_bear"


def check(summary):
    transcripts = summary.get("transcripts", [])
    if not isinstance(transcripts, list) or not transcripts:
        return ["summary must include transcripts[]"], {}

    ordinal_attempts = defaultdict(int)
    ordinal_wins = defaultdict(int)
    boss_attempts = 0
    boss_wins = 0
    pre_boss_attempts = 0
    pre_boss_wins = 0
    deaths_by_node = defaultdict(int)
    boss_deaths = 0
    tier1_deaths = 0
    total_deaths = 0

    for transcript in transcripts:
        combats = transcript.get("combats", [])
        if not isinstance(combats, list):
            continue
        for combat in combats:
            if not isinstance(combat, dict):
                continue
            pool_class = str(combat.get("pool_class", ""))
            ordinal = combat.get("normal_combat_ordinal", -1)
            if pool_class in ("weak", "strong") and isinstance(ordinal, int) and ordinal >= 0:
                ordinal_attempts[ordinal] += 1
                if _combat_won(combat):
                    ordinal_wins[ordinal] += 1
                    pre_boss_wins += 1
                pre_boss_attempts += 1
            if pool_class == "boss":
                boss_attempts += 1
                if _combat_won(combat):
                    boss_wins += 1

        death = _death_record(transcript)
        if not death:
            continue
        total_deaths += 1
        node_key = "%s:%s" % (death.get("node_id", "?"), death.get("pool_class", death.get("node_type", "?")))
        deaths_by_node[node_key] += 1
        if _is_boss(death):
            boss_deaths += 1
        if int(death.get("tier", 0)) <= 1:
            tier1_deaths += 1

    errors = []
    ordinal_rates = {}
    previous_rate = None
    for ordinal in sorted(ordinal_attempts.keys()):
        rate = _rate(ordinal_wins[ordinal], ordinal_attempts[ordinal])
        ordinal_rates[str(ordinal)] = {
            "attempts": ordinal_attempts[ordinal],
            "wins": ordinal_wins[ordinal],
            "win_rate": rate,
        }
        if previous_rate is not None and rate > previous_rate + TOLERANCE:
            errors.append(
                "normal ordinal %d win rate rose from %.3f to %.3f (> %.2f tolerance)"
                % (ordinal, previous_rate, rate, TOLERANCE)
            )
        previous_rate = rate

    max_deaths = max(deaths_by_node.values()) if deaths_by_node else 0
    if total_deaths <= 0:
        errors.append("no deaths recorded; boss death-share gate cannot pass")
    elif boss_deaths <= 0 or boss_deaths < max_deaths:
        errors.append(
            "boss must have the highest death share (boss=%d, max_node=%d, total=%d)"
            % (boss_deaths, max_deaths, total_deaths)
        )

    tier1_share = _rate(tier1_deaths, total_deaths)
    if total_deaths > 0 and tier1_share >= 0.20:
        errors.append("tier-1 deaths must stay below 20%% (got %.3f)" % tier1_share)

    report = {
        "runs": len(transcripts),
        "normal_win_rate_by_ordinal": ordinal_rates,
        "boss_deaths": boss_deaths,
        "total_deaths": total_deaths,
        "death_share_by_node": dict(sorted(deaths_by_node.items())),
        "tier1_death_share": tier1_share,
        "boss_conditional_win_rate_report_only": _rate(boss_wins, boss_attempts),
        "pre_boss_normal_win_rate_report_only": _rate(pre_boss_wins, pre_boss_attempts),
    }
    return errors, report


def main(argv):
    if len(argv) != 2:
        print("usage: check_difficulty_curve.py <batch_summary.json>", file=sys.stderr)
        return 2
    errors, report = check(_load(argv[1]))
    print(json.dumps(report, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print("FAIL: %s" % error, file=sys.stderr)
        return 1
    print("difficulty curve accepted")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
