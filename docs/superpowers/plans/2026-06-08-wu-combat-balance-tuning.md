# WU Combat Balance Tuning — Match-the-Blade Reach Pass

Date: 2026-06-08
Type: **playtest tuning checklist** (not a TDD plan — "fair" is judged by playing, not asserted by a test)
Trigger: Track B + anchor pipeline gave Hu authored, art-matching reach (~2.4× the old scalar). Enemies still use short scalar ranges, so duels are lopsided until retuned. This is the open part of the anchor-pipeline plan's Task 8.

> **Rev 2 (accuracy pass):** corrected the Hu reach baseline to the real `range_units` 226.6/236.4 → **connects at ~249/258** c2c (was wrongly stated 226/236); fixed the spacing rule to **`preferredRange ≈ range_units − attacker.half_width`** with the exact half-width math; regenerated §4 from each archetype's real `pattern_table` ranges (bandit_overhead 72, ronin 76–92, spear 110/120, bear 70–95); and required a reproducible **`--shot-archetype=<id>`** capture flag (the current hook randomizes the enemy and only forces Hu's states).

---

## 1. The gap, concretely

- **Hu's `range_units` = 226.6 (light) / 236.4 (heavy)** (geometry-derived, `attack_catalog.gd:17,32`), so he **connects at ~249px (light) / ~258px (heavy)** center-to-center (`range_units + defender.half_width`, `half_width = 22`).
- **Enemies engage far closer** — `preferredRange` (`data/Enemies/*.json`) and their attack `range_units` (`attack_catalog.gd`, per `pattern_table`):

| archetype | preferredRange | aggression | attack range_units (pattern_table) | role |
|---|---:|---:|---|---|
| BanditSwordsman | 72 | 0.45 | slash 68, thrust_perilous 88, overhead 72 | basic melee |
| WanderingRonin | 80 | 0.55 | slash 76, thrust 88, sweep 80, perilous_thrust 92 | mid duelist |
| SectDisciple | 78 | 0.65 | slash 74, thrust 82, sweep 78, counter 70, jump 90 | aggressive elite |
| MaskedAssassin | 68 | 0.60 | smoke_thrust 68, flicker 72, backstab 64, perilous_grab 60 | glass cannon (teleports) |
| IronBear (boss) | 90 | 0.50 | swipe 90, overhead 85, stomp 70, crush_grab 95 (+mountain_breaker 100, roar_aoe 140) | heavy boss |
| BanditSpearman | 110 | 0.40 | spear_long_thrust 110, spear_wide_swing 120 | zoner (longest reach) |

Hu connects at ~249/258; enemies connect at `range_units + 22` ≈ **86–142** (spearman the only one near fair). So most enemies must walk **~110–160px through Hu's kill zone** before they can swing. That's the unfairness to fix.

**Root asymmetry:** Hu uses authored capsule geometry (long, art-matched); enemies use scalar `range_units` (short). Until enemies get authored geometry too (the deferred enemy-manifest follow-up), close the gap by data.

---

## 2. Pick a strategy (do this first)

- [ ] **Decide the approach** (can mix per archetype):
  - **A — Close the range gap (recommended quick pass):** raise enemy attack `range_units` + `preferredRange` toward Hu's so melee trades are roughly even. `preferredRange` (JSON) is F5-reloadable; attack `range_units` (catalog code) changes require a relaunch. Enemy sprites also have extended strikes, so longer scalar reach reads fine even without capsules.
  - **B — Keep Hu's reach edge, compensate with pressure:** leave enemy ranges short but raise `aggression`/`dashChance`/approach so enemies crowd in and punish whiffs. Makes Hu's reach a real earned advantage. Good for fast archetypes (assassin, disciple).
  - **C — Authored enemy geometry (proper, deferred):** enemy manifests + capsules so their reach matches their art symmetrically. The real long-term fix; out of scope here.

  Recommendation: **A as the baseline for slow/standard melee + B as flavor for fast archetypes**, with C tracked as the follow-up.

---

## 3. The knobs (where each lives)

All hot-reloadable with `F5` in combat — no recompile for the data ones.

- **Per-enemy behavior** — `WUGodot/data/Enemies/<Archetype>.json`:
  - `preferredRange` — distance the AI closes to before it will attack (`ai_brain.gd:44`).
  - `aggression` — chance/biases toward attacking when in range (`ai_brain.gd:52`).
  - `blockChance`, `retreatChance`, `dashChance` — defensive/spacing reactions.
  - `pattern_table` — which attacks the archetype uses.
- **Enemy attack reach + feel** — `WUGodot/scripts/attack_catalog.gd` (per attack: `range_units`, `windup_end`, `active_end`, `duration`, `damage`, `posture_damage`, `forward_lunge`). *Code, not data — needs a reload via the editor/run, not F5.*
- **Hu baseline (do NOT change to "fix" balance):** `hu_light`/`hu_heavy` `range_units` are geometry-derived; the headless reach-consistency test guards them. Tune enemies to Hu, not the reverse.

**Key relationship to keep consistent (exact half-width math):**
- The AI *chooses* to attack when `|Δx| ≤ preferredRange + ai.half_width + target.half_width` (`ai_brain.gd:44`).
- The swing *connects* when `|Δx| ≤ attack.range_units + defender.half_width` (`combat_system.gd:269`).
- For the enemy to actually land when it commits, the commit distance must be inside the hit distance: `preferredRange + attacker.half_width + defender.half_width ≤ range_units + defender.half_width` → **`preferredRange ≤ range_units − attacker.half_width`**.

So set **`preferredRange ≈ (shortest attack in the pattern_table).range_units − attacker.half_width`** (use the *shortest* so even the enemy's stubbiest attack reaches when it commits). Setting `preferredRange ≈ range_units` (no offset) makes the enemy commit by roughly its half-width too far out and whiff.

---

## 4. Suggested starting values (iterate from here, don't ship blind)

First-pass targets — set, F5/reload, fight, adjust. Hu connects at **~249/258**; aim for enemies connecting at **~70–85% of that** (≈ 174–211 c2c → enemy `range_units` ≈ **152–189**) so Hu keeps a *slight* edge, not a dominating one. `preferredRange = (shortest bumped attack) − attacker.half_width` per §3.

| archetype | attack range_units (now → start) | preferredRange (now → start) | pressure tweaks |
|---|---|---|---|
| BanditSwordsman | slash 68→**140**, overhead 72→**145**, thrust_perilous 88→**150** | 72 → **118** (=140−22) | aggression 0.45 → 0.50 |
| WanderingRonin | slash 76→**150**, sweep 80→**150**, thrust 88→**160**, perilous_thrust 92→**165** | 80 → **128** | keep aggression 0.55 |
| SectDisciple | counter 70→**150**, slash 74→**150**, sweep 78→**150**, thrust 82→**155**, jump 90→**160** | 78 → **126** (=150−24) | keep aggression 0.65; raise dashChance (B) |
| MaskedAssassin | keep short (60–72) | 68 → **40** | strategy B: teleport + aggression 0.60→0.65, dashChance up |
| IronBear (boss) | stomp 70→**150**, overhead 85→**160**, swipe 90→**165**, crush_grab 95→**170**; scale mountain_breaker 100→**175**, roar_aoe stays AoE | 90 → **120** (=150−30) | slow but hits hard — keep |
| BanditSpearman | spear_long 110→**180**, spear_wide 120→**175** | 110 → **153** | aggression 0.40 (keep cautious) |

Notes:
- Spearman stays the **longest-reach** enemy (its identity) — give it reach closest to Hu's.
- Assassin is the intentional **outlier**: keep it short-reach, close the gap via teleport/dash (strategy B), so it feels like a fragile flanker, not a fair trader. Its `preferredRange 40` keeps it darting to point-blank.
- Bump each enemy's attack `range_units` and `preferredRange` **together** (§3), and set `preferredRange` off the **shortest** attack in its table.
- **Intentional band exception:** BanditSwordsman's shortest attack starts at **140** (hit ~162 c2c ≈ 65% of Hu), just below the 152–189 band. That's deliberate — the basic bandit is the **weakest, most-outranged** archetype (earliest fights), not a fair trader. If you'd rather it sit in-band, raise slash to ~152. Every other archetype's lowest attack should land in the band.
- These are starting points to iterate from in real fights (§6) — not final values.

---

## 5. Capture recipe (extend the existing hook)

The `--shot-combat` hook currently (a) **randomizes the enemy via `EnemyFactory`** and (b) only **forces Hu's states**. For reproducible per-archetype balance shots, it must be extended first:

- [ ] **Extend the hook to take an archetype and force the enemy's states.** Add a flag, e.g. `--shot-archetype=<id>` (bandit_swordsman / wandering_ronin / sect_disciple / masked_assassin / iron_bear / bandit_spearman), that:
  - spawns that specific enemy (bypass the random `EnemyFactory` selection),
  - positions both fighters at the enemy's `preferredRange` engagement distance,
  - forces the **enemy** into windup/active states (mirroring how Hu's states are forced) so the shot is deterministic.
- [ ] Capture, with the debug overlay on:
  - `05_enemy_windup.png` — enemy mid-windup at its `preferredRange` (where it commits).
  - `06_enemy_active.png` — enemy active frame (does its scalar reach visually connect at that distance?).
  - `07_neutral_spacing.png` — both idle at the engagement distance (Hu's capsule reach vs the enemy's threat zone — visibly fair?).
- [ ] Run per archetype: `./run.sh --shot-archetype=<id> /tmp/wu-balance-<id>` after each tuning pass.

Without the archetype flag + forced enemy states, the shots are non-reproducible (random enemy, no enemy attack frame). Screenshots catch reach mismatch and spacing; they do **not** judge feel — that needs real fights (§6).

---

## 6. What "fair" looks like (acceptance, per real fight)

Fight each archetype to a few exchanges and check:

- [ ] **Enemy can land hits without suicide** — it isn't forced to eat 2–3 of Hu's hits just to get in range once.
- [ ] **Hu's reach is an advantage, not an auto-win** — the player can poke, but a passive player still gets punished (enemy closes/pressures).
- [ ] **Spacing reads honestly** — the distance at which each side connects roughly matches the visible weapons (Hu's capsule; enemy's blade).
- [ ] **Archetype identity preserved** — spearman zones, assassin flanks/teleports, disciple pressures, bear is a slow heavy threat, bandits are basic.
- [ ] **No stat-screen weirdness** — `range_units`/`preferredRange` changes didn't break AI block/retreat reactions (`ai_brain.gd:38` `block_reaction_range` scales off Hu's reach, so it should still trigger — verify enemies still block telegraphs).
- [ ] **Boss check** — Iron Bear's grab/stomp still connect at their animations; the longer-reach Hu doesn't trivialize phase 2.

---

## 7. Iteration loop

- [ ] 1. Set one archetype's `preferredRange` + attack `range_units` (§3 relationship) to the §4 starting values.
- [ ] 2. Reload (F5 for the JSON; relaunch for `attack_catalog.gd` changes), fight it, capture `05–07`.
- [ ] 3. Adjust toward the §6 criteria; repeat until that archetype feels fair.
- [ ] 4. Move to the next archetype. Do the **boss last** (it composes several attacks).
- [ ] 5. Final pass: a full run start→boss to confirm difficulty curve still ramps.

---

## 8. Guard rails

- [ ] **Don't touch Hu's `range_units`** to fix balance — it's geometry-derived and test-guarded. Tune enemies to Hu.
- [ ] **Keep `preferredRange ≈ (shortest attack range_units) − attacker.half_width`** (−22 for normal enemies) per §3 — the most common mistake is changing one without the other, or dropping the −22 offset (which makes the enemy commit too far out and whiff).
- [ ] **Headless stays green** — these are enemy scalar/data changes; `./run.sh --test` (229/0) must still pass (the reach-consistency test is Hu-only, unaffected). Run it after the catalog edits.
- [ ] **Commit per archetype** (or in one balance commit) once §6 passes — small, reviewable diffs.

---

## 9. Done = 

- [ ] Every archetype meets §6 in a real fight.
- [ ] A full run plays through with a sensible difficulty ramp.
- [ ] `./run.sh --test` green; `--anchor-sanity` OK; `git diff --check` clean.
- [ ] Then — and only then — the anchor-pipeline plan's **Task 8 is complete** and the animation revamp can be called done.

**Follow-up (separate plan):** authored enemy geometry (Strategy C) — enemy manifests + capsules so enemy reach matches their art the way Hu's now does, retiring the scalar-vs-geometry asymmetry this pass works around.
