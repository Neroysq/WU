# Identity Content Pass (九仙山 slice 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin every identity surface to the 九仙山 fiction — animal schools, new title/event/boss/ending text, school icons, and the depth-band palette — with **zero gameplay change** (ids, mechanics, numbers untouched).

**Architecture:** Display-layer only. `Schools.json` display fields change (ids fixed); boon display names rename in place; new `icon` field + renderer with hanzi fallback; a `tier_band` context threads through the shared background draw; capture specs gain `tier_band` support so the gates are runnable.

**Tech Stack:** Godot 4.6.2 / GDScript, JSON data, `./run.sh --test` + `--capture` gates.
**Spec:** `docs/superpowers/specs/2026-07-03-creative-identity-revamp-design.md`

---

## Task 1: Schools display revamp (data only)

**Files:** Modify `WUGodot/data/Schools/Schools.json`; Test: existing suite (`test_boon_text` name gate).

- [ ] **Step 1:** For each school, change ONLY `name`, `hanzi`, `blurb` (ids, `signature`, `themeColor` unchanged):

| id (FIXED) | hanzi | name | blurb |
|---|---|---|---|
| `iron` | 熊 | Bear | Rooted stances, an iron hide — the mountain does not move. The art of 熊鐵 Xiong Tie, first of the Nine. |
| `thunder` | 牛 | Ox | One step, one thunderclap — fights end in a single collision. The art of 牛雷 Niu Lei. |
| `soft` | 鶴 | Crane | The centerline is sacred: receive, redirect, answer. The art of 鶴柔 He Rou. |
| `wind` | 燕 | Swallow | Walk the circle; never be where the blade lands. The art of 燕影 Yan Ying. |
| `venom` | 蛇 | Snake | Patience and venom — the bite is only the beginning. The art of 蛇噬 She Shi. |
| `sword` | 鷹 | Eagle | See the opening before it opens: seize, mark, finish. The art of 鷹目 Ying Mu. |

- [ ] **Step 2:** `./run.sh --import && ./run.sh --test` → green (no test asserts old school names; `test_boon_text` name-quality gate still passes).
- [ ] **Step 3:** Commit `feat(identity): schools become the Nine's animal styles`.

## Task 2: Boon display renames in place (data only)

**Files:** Modify `WUGodot/data/Boons/Boons.json` (display `name` fields + the ONE display payload below — never `id`, `school`, tiers, or effect *types/numbers*), `WUGodot/scripts/boons/boon_text.gd` (one describer wording).

- [ ] **Step 1:** Apply these renames (rule: names must fit the school's animal; vacate "drunken" for the Panda):
  - `wind_crane_step`: Crane Step → **Swallow Skim** (crane name belongs to `soft`)
  - `wind_sparrow_wing`: Sparrow Wing → **Swallow Wing**
  - `soft_drunken_form`: Drunken Form → **Yielding Crane** — vacating 醉拳 takes **three display edits**, not one: (a) the boon `name`; (b) the effect payload's stance **`display_name`** (`Boons.json:199`, currently 醉拳 DRUNKEN FORM — shown in the combat STANCE label via `active_stance_display_name()`, `technique_engine.gd:243`/`combat_scene.gd:872`) → **柔鶴 YIELDING CRANE**; (c) the `stance_drunken` describer in `boon_text.gd:100` ("drunken stance: …") → **"yielding stance: longer dash and %.0f break damage"**. The effect **type id `stance_drunken` and all mechanics stay unchanged** (internal id, not display).
  - `soft_iron_palm`: Iron Palm → **Crane's Beak** (iron belongs to `iron`/Bear)
  - `wind_mastery`: Windstep Mastery → **Swallow Mastery**; `soft_mastery`: Soft Palm Mastery → **Crane Mastery** (sweep ALL `*_mastery` names to `<Animal> Mastery`)
  - Sweep the remaining boons for animal-mismatch names against the Task-1 table; rename display-only where a name contradicts its school's animal (most — Descending Leaf, Flowing Water, Cutting Breeze, Cloud Hands, Mountain Echo — read fine; leave them).
- [ ] **Step 2:** `./run.sh --test` green (boon-text gate: names stay readable/non-raw). Commit `feat(identity): boon names fit their animal schools; drunken vacated`.

## Task 3: School icons (asset + renderer + fallback) ✋ art checkpoint

**Files:** Create `WUGodot/assets/icons/schools/{iron,thunder,soft,wind,venom,sword}.png`; Modify `Schools.json` (`icon` field), `scripts/scenes/boon_offer_scene.gd` (:62 header, :141 school-choice), `scripts/combat_scene.gd` (school chips :1156/:1203), **`scripts/scenes/loadout_view.gd`** (the map loadout panel's actual renderer — `map_scene.gd:99` only calls `LoadoutViewScript.draw`; the rows render in `loadout_view.gd:40` — draw each slot/passive row's school icon before the boon name, school resolved from the boon's data), `tests/run_tests.gd` (register the new module); Test `tests/test_school_icons.gd`.

- [ ] **Step 1:** Generate six small animal pictogram icons (~24px, VINIK24-compatible, strong silhouettes: bear head, ox head, crane, swallow in flight, coiled snake, eagle head). Any pipeline (GPT Image 2 → pixelize per the existing art workflow, or hand-pixel). **✋ STOP — show the icon sheet to the user for approval before installing** (per the project's art-review convention).
- [ ] **Step 2:** Add `"icon": "res://assets/icons/schools/<id>.png"` per school in `Schools.json`.
- [ ] **Step 3:** Renderer: a small helper (e.g. `UiDraw.school_mark(canvas, school_data, pos, size)`) that draws the icon texture if the `icon` path loads, else the `hanzi` text (fallback). Use it at all four surfaces above (icon + text name alongside, per spec).
- [ ] **Step 4:** Test `test_school_icons.gd`: all six school entries have non-empty `icon` paths AND the files exist; a synthetic school dict with no icon falls back to hanzi without error. **Register `"res://tests/test_school_icons.gd"` in `run_tests.gd`'s `_TEST_MODULES`** (static list — new tests don't run otherwise).
- [ ] **Step 5 (gate captures):** two forced school-choice captures covering all six ids + one boon-offer capture + a `kind:"matchup"` capture with a `build` (combat chips) + a `"screen":"map"` capture with a `build` (loadout panel). Icons visible in all; `python3 tools/assert_nonblank.py` each.
- [ ] **Step 6:** Commit `feat(identity): school animal icons + hanzi fallback`.

## Task 4: Title screen (strings only)

**Files:** Modify `scripts/scenes/menu_scene.gd`.

- [ ] **Step 1:** Replace the four strings:
  - "The Wanderer Emerges" → **"The Pilgrim Climbs"**
  - "A Sekiro-paced wuxia duel roguelike" → **"天下武功出九仙 — all martial arts under heaven come from the Nine Immortals"**
  - "第一章 江湖" → **"第一章 九仙山"**
  - "Bamboo roads, wandering blades, and a debt still unpaid" → **"A nobody climbs the mountain to learn. The mountain has other plans."**
- [ ] **Step 2:** Manual/capture check (menu renders, no overflow). Commit `feat(identity): 九仙山 title screen`.

## Task 5: Enemy flavor (display names only)

**Files:** Modify `WUGodot/data/Enemies/*.json` (`name`/`name_cn` only — stats untouched).

- [ ] **Step 1:** Re-frame enemies as the mountain's population (disciples/dropouts of the styles):
  - bandit_swordsman: 匪劍 Bandit Swordsman → **棄徒刀 Dropout Blade** · bandit_spearman: 匪槍 → **棄徒槍 Dropout Spear** (failed outer-gate disciples turned bandit)
  - wandering_ronin: 浪人 Wandering Ronin → **獨行客 Lone Walker** · sect_disciple: 門徒 Sect Disciple → **外門弟子 Outer-Gate Disciple**
  - masked_assassin: 面刺客 Masked Assassin → **無面者 The Faceless** (high-path, touched)
  - iron_bear: 熊鐵 Xiong Tie — **unchanged** (he was always the pattern).
- [ ] **Step 2:** `./run.sh --test` green (combat HUD shows the new names). Commit `feat(identity): enemies as the mountain's population`.

## Task 6: Events rewrite (text only — foreshadow, never mechanics)

**Files:** Modify `WUGodot/data/Events/Events.json` (title/body/choice-label text ONLY; every outcome field untouched — `event_runner.gd:58` behavior identical).

- [ ] **Step 1:** Rewrite the six in the bright-with-a-shadow register (may FORESHADOW loss-as-cleansing; must never state or imply mechanical purification):
  - `roadside_villager` → **Villager at the First Step**: warns cheerfully — "The higher you climb, the friendlier the smiles. Don't trust the teeth."
  - `travelling_merchant` → **Pilgrim-Road Merchant**: sells Nine-Immortal souvenirs; Hu is delighted; the merchant never climbs past the second shrine, "as policy."
  - `shrine_offering` → **The Hungry Shrine**: an old shrine that "asks more than coin" — giving something up feels strangely light (foreshadow only; outcomes unchanged).
  - `drunken_master` → **The Drunk Below the Gate**: a shabby drunk who smells of wine and bamboo, refuses to teach, laughs at the Nine — "the only master on this mountain who never asks for tuition." (熊貓 tease; never named.)
  - `bandit_camp` → **Dropout Camp**: bandits are failed disciples; their forms are recognizably bad copies of the styles.
  - `abandoned_scroll` → **A Founder-Era Scroll**: forms older than any school; reading them too long makes the eyes ache (door foreshadow).
- [ ] **Step 2:** `./run.sh --test` green; one event capture nonblank. Commit `feat(identity): events as mountain story beats`.

## Task 7: Xiong Tie boss beats (renderer + strings)

**Files:** Modify `scripts/combat_scene.gd`.

- [ ] **Step 1:** Change the renderer signature (existing call at `:496` stays valid):
```gdscript
func _show_boss_beat(message: String, duration: float = 1.1, caption: String = "") -> void:
```
Store `caption` in a var; `_draw_boss_beat` draws the caption line ONLY when non-empty (replacing the hardcoded "Iron Bear falls" at `:961`).
- [ ] **Step 2:** Death beat call becomes `_show_boss_beat("破山!", 1.1, "the gate stands open — something above is listening")`.
- [ ] **Step 3:** Intro beat: at boss-fight start (where the BOSS-node combat begins/entry animation triggers), call `_show_boss_beat("山門不開。", 1.4, "熊鐵 Xiong Tie — First of the Nine keeps the gate")`.
- [ ] **Step 4:** Test: existing suite green; a matchup capture on the boss archetype shows the intro beat frame (capture state at fight start). Commit `feat(identity): Xiong Tie gatekeeper beats`.

## Task 8: Ending texts (strings only)

**Files:** Modify `scripts/scenes/ending_scene.gd` (victory + game-over strings; no new branches — the judgment/走火入魔 branch is the corruption slice).

- [ ] **Step 1:** Victory reads hollow: headline **"山門開了 — The Gate Stands Open"**, body **"The gatekeeper kneels. The summit is silent. Somewhere above, a door you cannot see has noticed you."**
- [ ] **Step 2:** Game-over in fiction: **"The mountain keeps what it kills."**
- [ ] **Step 3 (capture plumbing — these screens have no capture cases today, `main.gd:407`):** add `"victory"`, `"game_over"`, and `"forget"` cases to `_prepare_capture_ui` (route to the matching `SCENE_*` with a minimal payload; forget needs a technique in the loadout — reuse `_apply_capture_build`). Menu stays manual (Task 4).
- [ ] **Step 4:** Suite green; victory + game_over captures nonblank. Commit `feat(identity): hollow-victory and mountain ending texts + ending/forget capture cases`.

## Task 9: Depth-band palette (the one code system in this pass)

**Files:** Create `scripts/ui/depth_band.gd`; Modify `scripts/game_constants.gd` (band tints), `scripts/ui/ui_draw.gd` (`background`), `scripts/visual/background_renderer.gd` (ctx), the 8 covered scenes (map, combat, event, shop, rest, boon_offer, reward, forget), `scripts/main.gd` (capture `tier_band`), `tests/run_tests.gd` (register); Test `tests/test_depth_band.gd`.

- [ ] **Step 1:** `depth_band.gd` (static): `band_for_node(node) -> String` — `"gate"` if BOSS type; else by tier: `<=1 "foothill"`, `2-3 "mid"`, `4-5 "high"`, else `"high"`. `band_for_run(run_state)` = band of current node (fallback `"foothill"`).
- [ ] **Step 2:** `GameConstants.BAND_TINTS: Dictionary` — `foothill: Color(1,1,1,0)` (no-op), `mid`: slight cool wash, `high`: colder/darker wash, `gate`: darkest (exact VINIK24-derived values tuned by capture; alpha-overlay wash rects are sufficient — no new art).
- [ ] **Step 3:** `UiDraw.background(canvas, band: String = "foothill")` applies the wash after the base; `BackgroundRenderer.draw(..., ctx)` reads `ctx.band` the same way. Each covered scene passes `DepthBand.band_for_run(ctx.run_state)` (combat: from its node). Menu/settings/ending stay callers of the default (opted out).
- [ ] **Step 4:** Capture support: UI capture specs accept `"tier_band": "high"` (or `"tier": N`) — `_prepare_capture_ui`/`_prepare_capture_matchup` set the band context before `_set_scene`, for **every** UI screen.
- [ ] **Step 5:** Test `test_depth_band.gd`: band function boundaries (tier 1/2/3/4/5, BOSS node); tints exist for all four bands. **Register `"res://tests/test_depth_band.gd"` in `run_tests.gd`'s `_TEST_MODULES`.**
- [ ] **Step 6 (gate):** tiered captures — map, combat (matchup), boon_offer, reward each at `foothill` vs `high`; pairs must visibly differ; all nonblank. Commit `feat(identity): depth-band palette — the mountain darkens as you climb`.

## Task 10: Full verification + record ✋

- [ ] `./run.sh --import && ./run.sh --test` → 0 failures. Full capture set from Tasks 3/6/7/8/9 re-run.
- [ ] Playtest sanity: 30-seed greedy batch — win rate & timeouts unchanged from baseline (~0.49, 0) proving zero gameplay drift.
- [ ] Write `docs/superpowers/specs/2026-07-03-identity-content-pass-results.md` (before/after surface table, capture inventory). ✋ **STOP — present captures to the user** (this pass is judged by eye).

## Self-Review
- **Spec coverage:** §3 schools/renames/ids (T1,T2) · §6 icons+contract (T3) · §7 surfaces: title (T4), enemies (T5), events-foreshadow-only (T6), boss beats incl. renderer constraint (T7), endings-no-new-branches (T8) · §6 depth-band function/callers/capture support/gates (T9). Out of scope respected: no mechanics, no cleanse wiring, no judgment branch, no dialogue system.
- **Placeholder scan:** all strings are actual copy; icon art is a generation step with a user checkpoint (art can't be pre-written).
- **Consistency:** ids never change anywhere; `_show_boss_beat` signature matches the spec's; band names (`foothill/mid/high/gate`) consistent across T9 steps and the spec.
