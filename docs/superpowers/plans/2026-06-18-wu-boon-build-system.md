# WU Boon Build System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "pick 1 of 3 random techniques" reward with a Hades-style boon system reskinned as wuxia schools (流) — 6 move-slots, a 4-tier rider ladder, duos & masteries — reusing the existing technique-effect engine.

**Architecture:** Boons are authored as data (`Schools.json`, `Boons.json`). A tier-aware **boon factory** compiles a boon at a given tier into one or more `TechniqueEffect` instances (base + cumulative riders) via a new `create_effect_from_data`. A **`BoonLoadout`** (slot map + passives + active duos/masteries) installs/removes those instances on the existing `TechniqueEngine`. Acquisition flows through a school-offer screen mapped onto existing nodes. Combat is untouched except for new `on_jump`/`on_land`/aerial hooks.

**Tech Stack:** Godot 4.6.2, GDScript. Headless tests via `./run.sh --test`. Data-driven JSON in `WUGodot/data/`. Spec: `docs/superpowers/specs/2026-06-18-wu-boon-build-system-design.md`.

**Verification (every task):** `./run.sh --test 2>&1 | tail -3` → `failed: 0`; `./run.sh --import 2>&1 | grep -ciE "^ERROR|SCRIPT ERROR"` → `0`. Commit prefix `feat(boons):` (code) / `data(boons):` (content). End commits with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

**Create:**
- `WUGodot/data/Schools/Schools.json` — 6 school defs (id, name, hanzi, signature, themeColor, blurb).
- `WUGodot/data/Boons/Boons.json` — boon defs (kind, slot, tiers/riders, requires).
- `WUGodot/scripts/boons/boon_factory.gd` — `build_boon_effects(boon_data, tier)` → `Array[TechniqueEffect]`.
- `WUGodot/scripts/boons/boon_loadout.gd` — slot map + passives + duos/masteries; compile/replace/upgrade/eligibility.
- `WUGodot/scripts/boons/boon_offer.gd` — generate steered 1-of-3 offers, prefer-empty-slot, duo/mastery gating.
- `WUGodot/scripts/techniques/effects/{venom,jolt,deflect,momentum,intent_mark}_effect.gd` — new status effects + riders.
- `WUGodot/scripts/scenes/boon_offer_scene.gd` — offer screen (extends the reward screen).
- `WUGodot/scripts/scenes/loadout_view.gd` — loadout/tooltips panel.
- `WUGodot/tests/test_boon_*.gd`, `test_{venom,jolt,...}_effect.gd`.

**Modify:**
- `WUGodot/scripts/techniques/technique_registry.gd` — add `create_effect_from_data(effect_data)`; `create_effect(id)` delegates; register new types.
- `WUGodot/scripts/technique_engine.gd` — add `add_effect(effect, fighter)` / `remove_effect(effect, fighter)`.
- `WUGodot/scripts/techniques/technique_effect.gd` — add `on_jump`, `on_land`, `modify_aerial_hit` hooks.
- `WUGodot/scripts/combat_system.gd` + `WUGodot/scripts/fighter.gd` — invoke jump/land/aerial hooks.
- `WUGodot/scripts/data_manager.gd` — load Schools/Boons + getters.
- `WUGodot/scripts/run_state.gd` (+ scene context) — hold a `BoonLoadout`.
- `WUGodot/scripts/run_flow.gd` + `WUGodot/scripts/main.gd` — route rewards to boon offers; Insight; favor/steering.
- `WUGodot/data/Techniques/TechniquePool.json` — re-homed into `Boons.json` (Phase 3).

---

# Phase 1 — Boundary + model

### Task 1: `create_effect_from_data` factory boundary

**Files:** Modify `WUGodot/scripts/techniques/technique_registry.gd`; Test `WUGodot/tests/test_boon_factory.gd`

- [ ] **Step 1: Write the failing test** — `test_boon_factory.gd`:
```gdscript
extends RefCounted
const Registry = preload("res://scripts/techniques/technique_registry.gd")
func run_all() -> Dictionary:
    var passed := 0; var failed := 0; var failures: Array[String] = []
    # build an effect directly from effect data, NOT a technique id
    var eff = Registry.create_effect_from_data({"type": "stat_delta", "health_max": 20}, "boon_test")
    if eff != null and eff.id == "boon_test" and int(eff.params.get("health_max", 0)) == 20:
        passed += 1
    else:
        failed += 1; failures.append("create_effect_from_data should build a stat_delta effect with given id+params")
    return {"passed": passed, "failed": failed, "failures": failures}
```
- [ ] **Step 2: Register the test** in the headless test runner (follow the pattern other `test_*.gd` use — add to the suite list in `WUGodot/scripts/test_runner.gd` or wherever `run_all` suites are registered; grep `test_technique_engine` to find it). Run `./run.sh --test` → FAIL (`create_effect_from_data` not defined).
- [ ] **Step 3: Implement** — in `technique_registry.gd`, extract the `match effect_type` block into `create_effect_from_data(effect_data: Dictionary, id: String = "") -> Variant`, and make `create_effect(id)` call it:
```gdscript
static func create_effect(id: String) -> Variant:
    var data: Dictionary = DataManager.get_technique(id)
    if not data.has("effect") or typeof(data.get("effect")) != TYPE_DICTIONARY:
        return null
    return create_effect_from_data((data.get("effect", {}) as Dictionary).duplicate(true), id)

static func create_effect_from_data(effect_data: Dictionary, id: String = "") -> Variant:
    var effect_type: String = str(effect_data.get("type", ""))
    var effect: Variant = _new_effect_for_type(effect_type)
    if effect == null:
        push_error("TechniqueRegistry: unknown effect type '%s'" % effect_type)
        return null
    if id != "": effect.id = id
    effect.params = effect_data.duplicate(true)
    if effect_data.has("display_name"): effect.display_name = str(effect_data["display_name"])
    if effect_data.has("priority"): effect.priority = int(effect_data["priority"])
    if effect_data.has("exclusive_group"): effect.exclusive_group = str(effect_data["exclusive_group"])
    return effect
```
Move the existing `match` into a `static func _new_effect_for_type(effect_type: String) -> Variant:` returning the right `*.new()` (keep all current cases).
- [ ] **Step 4: Run** `./run.sh --test` → PASS, and existing technique tests still pass (the delegation must not regress them).
- [ ] **Step 5: Commit** `git add -A && git commit` — `feat(boons): add create_effect_from_data factory boundary`.

### Task 2: engine `add_effect` / `remove_effect` for pre-built instances

**Files:** Modify `WUGodot/scripts/technique_engine.gd`; Test `WUGodot/tests/test_boon_loadout.gd` (start it here)

- [ ] **Step 1: Failing test** — build an effect via the factory, install it on a fresh `TechniqueEngine` with `add_effect`, assert it's active and participates in hits; then `remove_effect` and assert it's gone. (Use a `Fighter.new()` like `test_technique_engine.gd` does.)
- [ ] **Step 2: Run** → FAIL (`add_effect` not defined).
- [ ] **Step 3: Implement** in `technique_engine.gd` — refactor so `add(id)` builds then calls a shared installer, and expose instance-level methods:
```gdscript
func add_effect(effect: Variant, fighter: Variant) -> void:
    if effect == null: return
    _install_effect(effect, fighter)   # existing private installer

func remove_effect(effect: Variant, fighter: Variant) -> void:
    if effect == null or not _effects.has(effect): return
    if _active_stance_id == effect.id:
        deactivate_stance(fighter)
    if effect.once_per_run:
        _effect_state_archive[effect.id] = effect.state()
    effect.on_remove(fighter)
    _effects.erase(effect)
    _technique_ids.erase(effect.id)
```
Note: `_install_effect` already appends `effect.id`; boon riders share a boon id family — make `_technique_ids` tolerate duplicates by switching boon-installed ids to a per-instance unique key (see Task 4 — loadout assigns `effect.id = "<boonId>#<n>"`). Keep `add(id)` behavior for legacy techniques unchanged.
- [ ] **Step 4: Run** → PASS (+ existing engine tests green).
- [ ] **Step 5: Commit** — `feat(boons): TechniqueEngine add_effect/remove_effect for boon instances`.

### Task 3: Schools/Boons data files + DataManager loaders

**Files:** Create `WUGodot/data/Schools/Schools.json`, `WUGodot/data/Boons/Boons.json`; Modify `WUGodot/scripts/data_manager.gd`; Test extend `test_boon_factory.gd`

- [ ] **Step 1: Failing test** — assert `DataManager.get_school("venom")` returns a dict with `signature == "venom"`, and `DataManager.get_boon("venom_light")` returns a dict with `kind == "move"`, `slot == "light"`, and a `tiers.common.effect` dict.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — seed minimal data + loaders:
  - `Schools.json`: `[{"id":"venom","name":"Venom Sect","hanzi":"毒","signature":"venom","themeColor":"#7ec850","blurb":"Snowballing poison."}]` (one entry to start; full roster in Phase 7).
  - `Boons.json`: one entry:
    ```json
    [{"id":"venom_light","school":"venom","kind":"move","slot":"light",
      "tiers":{"common":{"effect":{"type":"venom","stacks":1}},
               "rare":{"riders":[{"type":"venom_slow"}]},
               "epic":{"riders":[{"type":"venom_spread"}]},
               "legendary":{"riders":[{"type":"venom_heavy_detonate"}]}}}]
    ```
  - In `data_manager.gd`, mirror the existing technique loader: load both files in `initialize()`, store keyed-by-id, add `get_school(id)`, `get_boon(id)`, `get_all_boons()`, `get_boons_for_school(school_id)`. Add to the `reload_data()` path and the F5 reload.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): Schools/Boons data files + DataManager loaders`.

### Task 4: `BoonFactory.build_boon_effects(boon, tier)` (cumulative riders)

**Files:** Create `WUGodot/scripts/boons/boon_factory.gd`; Test `test_boon_factory.gd`

- [ ] **Step 1: Failing test** — `build_boon_effects(DataManager.get_boon("venom_light"), "epic")` returns an array of 3 effects (base + rare rider + epic rider), each with id prefixed `venom_light#`, and NOT including the legendary rider. At `"common"` it returns 1 effect.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** `boon_factory.gd`:
```gdscript
class_name BoonFactory
extends RefCounted
const Registry = preload("res://scripts/techniques/technique_registry.gd")
const TIER_ORDER := ["common", "rare", "epic", "legendary"]

static func build_boon_effects(boon: Dictionary, tier: String) -> Array:
    var out: Array = []
    if boon.get("kind", "") in ["duo", "mastery"]:
        var e = Registry.create_effect_from_data((boon.get("effect", {}) as Dictionary), str(boon["id"]) + "#0")
        if e != null: out.append(e)
        return out
    var tiers: Dictionary = boon.get("tiers", {})
    var n := 0
    for t in TIER_ORDER:
        if not tiers.has(t): continue
        var td: Dictionary = tiers[t]
        if td.has("effect"):
            out.append(_mk(td["effect"], boon, n)); n += 1
        for rider in (td.get("riders", []) as Array):
            out.append(_mk(rider, boon, n)); n += 1
        if t == tier: break
    return out

static func _mk(effect_data: Dictionary, boon: Dictionary, n: int) -> Variant:
    var e = Registry.create_effect_from_data(effect_data, "%s#%d" % [boon["id"], n])
    return e
```
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): tier-aware boon factory (cumulative riders)`.

### Task 5: `BoonLoadout` (slots, passives, replace, upgrade, eligibility)

**Files:** Create `WUGodot/scripts/boons/boon_loadout.gd`; Test `test_boon_loadout.gd`

- [ ] **Step 1: Failing tests** (one assertion each, add incrementally):
  - `add_boon("venom_light","common")` fills the `light` slot and installs effects on the engine.
  - adding another `light` move-boon **replaces** the first (old effects removed, new installed).
  - `upgrade_boon("venom_light")` → tier becomes `rare`, re-compiles (now 2 effects), Insight not handled here.
  - `is_duo_eligible(duoBoon)` true only when both required schools have a boon.
  - `active_schools()` returns the set of schools currently held.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** `boon_loadout.gd` holding: `slots: Dictionary` (slot→{boon_id, tier, effects[]}), `passives: Array`, `duos/masteries: Array`, a ref to the `TechniqueEngine` + `fighter`. Methods: `add_boon(id, tier)` (route by kind/slot; replace if slot filled — `engine.remove_effect` each old, then `BoonFactory.build_boon_effects` + `engine.add_effect`), `upgrade_boon(id)` (next tier, recompile), `is_duo_eligible`/`is_mastery_eligible` (check `requires` vs held), `active_schools`, `school_boon_count(school)`, `serialize`/`restore` for run-state persistence.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): BoonLoadout (slots, replace, upgrade, eligibility)`.

### Task 6: Wire `BoonLoadout` into run state

**Files:** Modify `WUGodot/scripts/run_state.gd` (+ scene context that carries run data); Test `test_boon_loadout.gd`

- [ ] **Step 1: Failing test** — a fresh run state exposes an empty `BoonLoadout`; adding a boon survives a `serialize`→`restore` round-trip.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — add a `BoonLoadout` to the run/scene context (replace/augment `run_techniques_acquired[]`); ensure it's created on run start and serialized with the rest of run state. Keep legacy technique arrays only if still needed during Phase 3 migration.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): carry BoonLoadout in run state`.

---

# Phase 2 — New effects + hooks

### Task 7: jump / land / aerial hooks

**Files:** Modify `WUGodot/scripts/techniques/technique_effect.gd`, `WUGodot/scripts/combat_system.gd`, `WUGodot/scripts/fighter.gd`; Test `test_boon_loadout.gd` or a new `test_jump_hooks.gd`

- [ ] **Step 1: Failing test** — a stub effect overriding `on_jump`/`on_land` records calls; simulate a jump and a landing through the combat/fighter path and assert both fired. (Mirror how `test_technique_combat.gd` drives the fighter.)
- [ ] **Step 2:** Run → FAIL (hooks not invoked).
- [ ] **Step 3: Implement** — add to `technique_effect.gd`:
```gdscript
func on_jump(_fighter: Variant) -> void: pass
func on_land(_fighter: Variant) -> void: pass
func modify_aerial_hit(_ctx: Variant) -> void: pass   # called from modify_outgoing_hit path when attacker not grounded
```
In `fighter.gd`/`combat_system.gd`, at the existing jump trigger and landing-recovery transition (search `has_double_jump` and the `LANDING` state), broadcast to the engine's effects (mirror how `on_dash_end`/`on_parry_success` are dispatched). For `modify_aerial_hit`, in the hit pipeline call it when `attacker.is_grounded == false`. **Do not** add a second double-jump — baseline already grants one.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): on_jump/on_land/aerial hooks`.

### Task 8: Venom effect family (exemplar — full riders)

**Files:** Create `WUGodot/scripts/techniques/effects/venom_effect.gd`; register types in `technique_registry.gd`; Test `WUGodot/tests/test_venom_effect.gd`

This is the **reference pattern** for status effects with riders. Each rider is its own effect TYPE registered in the factory.

- [ ] **Step 1: Failing tests** — (a) `venom` effect on a hit applies a venom stack to the defender (a `venom_stacks` + `venom_timer` field on the HitContext or defender — add to `HitContext` like `bleed_timer`); (b) venom ticks damage over time via `update`/combat tick; (c) `venom_slow` rider reduces defender move_speed while venomed; (d) `venom_spread` rider, on a venomed defender's death, applies venom to nearby; (e) `venom_heavy_detonate` rider: a heavy hit consumes stacks for burst.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — add `venom_timer`/`venom_stacks`/`venom_dps` to `TechniqueEffect.HitContext` (mirror bleed fields), apply/tick in the combat damage path (mirror bleed application/tick in `combat_system.gd`). Author `venom_effect.gd` with the base `venom` type (`modify_outgoing_hit` adds stacks) and **separate small effect classes/types** for `venom_slow`, `venom_spread`, `venom_heavy_detonate` (each a tiny `*_effect.gd` or branch in one file keyed by `params.type`). Register every new type in `_new_effect_for_type`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): venom effect family (base + slow/spread/detonate riders)`.

### Tasks 9–12: Jolt, Deflect, Momentum, Intent-mark effect families

**Files:** `WUGodot/scripts/techniques/effects/{jolt,deflect,momentum,intent_mark}_effect.gd` (+ riders); register types; Tests `test_{jolt,deflect,momentum,intent_mark}_effect.gd`

Each follows the **Task 8 pattern** (base type + per-tier rider types; status field on HitContext/fighter where needed; apply+tick in combat path; factory registration; one assertion per behavior). Per-effect specifics:

- [ ] **Task 9 — Jolt** (Thunderclap): base = hit applies Jolt to target + arcs to one nearby enemy (use the scene's enemy list; in single-enemy combat, arc is a no-op but still flags Jolt). Riders: `jolt_amp` (jolted take +dmg), `jolt_nova` (heavy → AoE jolt), `jolt_dash_discharge` (dash consumes jolt for burst). Hooks: `modify_outgoing_hit`, `on_dash_end`. Commit `feat(boons): jolt effect family`.
- [ ] **Task 10 — Deflect** (Soft Palm): base = perfect-parry window grants a riposte (use `on_parry_success`). Riders: `deflect_riposte_dmg`, `deflect_reduce` (passive incoming-dmg reduction via `modify_block`), `deflect_redirect` (light counter). Commit `feat(boons): deflect effect family`.
- [ ] **Task 11 — Momentum** (Windstep): base = a `momentum` meter (builds on dash/move, decays); riders: `momentum_flurry` (light gains extra hits at high momentum via `ctx.extra_hits`), `momentum_aerial` (uses `modify_aerial_hit`/`on_land` for a landing burst), `momentum_speed` (passive `stat_delta`-like). Hooks: `on_dash_end`, `on_jump`/`on_land`, `update`. Commit `feat(boons): momentum effect family`.
- [ ] **Task 12 — Intent-mark** (Sword Intent): base = hit applies an Intent mark to target; heavy consumes marks for crit burst. Riders: `intent_reach` (passive +range), `intent_crit_vs_marked`, `intent_dash_flash` (dash applies mark). Hooks: `modify_outgoing_hit`. Reuse `bleed`-style detonation infra if helpful. Commit `feat(boons): intent-mark effect family`.

Each task: write failing tests → run FAIL → implement + register type → run PASS → commit.

---

# Phase 3 — Re-home the 20 techniques

### Task 13: migrate TechniquePool into Boons by slot/behavior

**Files:** Modify `WUGodot/data/Boons/Boons.json`, `WUGodot/data/Techniques/TechniquePool.json`; Test `WUGodot/tests/test_boon_rehome.gd`

- [ ] **Step 1: Failing test** — for each migrated technique, assert a corresponding boon exists with the right `kind`+`slot` and that `BoonFactory.build_boon_effects(...)` yields an effect whose `params.type` matches the original technique's effect type (so combat behavior is preserved). Example: dash-stab → a `dash` move-boon; heavy-bleed → a `heavy` move-boon; stat mods → passives; Drunken/Tiger → `stance` move-boons.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — author Boons.json entries that reuse the **existing effect types** (`dash_stab`, `stagger`, `bleed_on_heavy`, `stat_delta`, `stance_drunken`, `stance_tiger`, etc.) as each boon's `tiers.common.effect`, assigning `school`/`slot`/`kind` by behavior (map each of the 20 individually — do NOT bucket by A/B/D letter). Add Rare/Epic/Legendary riders where natural (or leave higher tiers minimal for now; Phase 7 enriches). Mark legacy `TechniquePool.json` entries as deprecated/removed once nothing references them (keep until offer flow uses boons).
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `data(boons): re-home techniques into boons by slot/behavior`.

---

# Phase 4 — Acquisition & offer flow

### Task 14: `BoonOffer` generator (steered, 1-of-3, prefer-empty-slot, gating)

**Files:** Create `WUGodot/scripts/boons/boon_offer.gd`; Test `WUGodot/tests/test_boon_offer.gd`

- [ ] **Step 1: Failing tests** — `BoonOffer.generate(loadout, school, depth, rng)` returns 3 distinct boons from `school`; with empty slots present it **prefers** boons for empty slots; a duo is included only when `loadout.is_duo_eligible`; offered tier weights skew higher with `depth`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** `boon_offer.gd` — pull `get_boons_for_school(school)`, filter by ownership/eligibility, weight empty-slot move-boons up, roll tier by depth, return 3 distinct. Include eligible duos/masteries from the school pool.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): boon offer generator (steered, prefer-empty-slot)`.

### Task 15: Offer screen + node integration

**Files:** Create `WUGodot/scripts/scenes/boon_offer_scene.gd`; Modify `WUGodot/scripts/run_flow.gd`, `WUGodot/scripts/main.gd`; Test `test_boon_offer.gd` (logic) + manual scene check

- [ ] **Step 1: Failing test (logic)** — after a battle victory, `run_flow` produces a boon offer (school chosen per steering rules) and on selection the loadout gains the boon. Test the data path headlessly (selection → `loadout.add_boon`).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — `boon_offer_scene.gd` mirroring `reward_scene.gd`: render the school banner + 1-of-3 cards (slot, tier + rider preview, "replaces: …"); on pick call `loadout.add_boon`. Route battle/ambush/master/elite/event nodes through it in `main.gd`'s node switch + `run_flow.gd` (replace the technique reward path). Keep boss → no offer.
- [ ] **Step 4:** Run `./run.sh --test` (logic) + load the scene headless/import clean.
- [ ] **Step 5: Commit** — `feat(boons): boon offer screen + node routing`.

### Task 16: Steering — school choice + favor

**Files:** Modify `WUGodot/scripts/run_flow.gd`, `WUGodot/scripts/event_runner.gd`; Test `test_boon_offer.gd`

- [ ] **Step 1: Failing test** — at Master/Elite/Event the player is offered a **choice of school** (≥2 options) before the 1-of-3; an event "favor" sets a bias so the next battle's school is the favored one.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — add a `favored_school` field to run state; battle nodes use it (then clear) else random; Master/Elite/Event present a school picker first. Add a "favor" outcome to the event schema/`event_runner`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): school steering (choice + favor)`.

---

# Phase 5 — Insight upgrades + duos/masteries

### Task 17: Insight currency + boon upgrade

**Files:** Modify `WUGodot/scripts/fighter.gd` (or run state), `WUGodot/scripts/scenes/shop_scene.gd`, `WUGodot/scripts/scenes/rest_scene.gd`; Test `test_boon_loadout.gd`

- [ ] **Step 1: Failing test** — run state has `insight` (int); spending it via `loadout.upgrade_boon(id)` raises the boon's tier and re-compiles its effects (assert effect count grows by the new tier's riders); insufficient insight rejects.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — add `insight` to run state; award it (elite/boss/event); add an "upgrade a boon (cost: Insight)" action to shop + rest scenes calling `upgrade_boon`. Guard against upgrading past `legendary`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): Insight currency + boon upgrades`.

### Task 18: Duos & masteries grant flow

**Files:** Modify `WUGodot/scripts/boons/boon_offer.gd`, `boon_loadout.gd`; Test `test_boon_offer.gd`

- [ ] **Step 1: Failing test** — once eligibility is met, the offer pool surfaces the duo/mastery; selecting it adds a single-tier boon whose effects activate; ineligible duos never appear.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — duo/mastery offers appear at Master (and eligible Elite); `add_boon` for `kind in [duo,mastery]` installs the single-tier effect and records it in `loadout.duos/masteries`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** — `feat(boons): duo & mastery grant flow`.

---

# Phase 6 — Loadout UI + tooltips

### Task 19: Loadout view + effect tooltips

**Files:** Create `WUGodot/scripts/scenes/loadout_view.gd`; Modify pause/map UI host; Test: import-clean + manual

- [ ] **Step 1:** (UI — no headless assertion beyond import) build `loadout_view.gd`: 6 slot cards (boon name, tier, rider list), passives list, active duos/masteries, per-card tooltip text generated from the boon's resolved tier riders. Wire it to the map/pause screen.
- [ ] **Step 2:** `./run.sh --import` clean; visually verify the panel renders the current loadout.
- [ ] **Step 3: Commit** — `feat(boons): loadout view + tooltips`.

---

# Phase 7 — Content pass (the 6 schools)

### Task 20: Author the v1 boon matrix

**Files:** Modify `WUGodot/data/Schools/Schools.json`, `WUGodot/data/Boons/Boons.json`; Test extend `test_boon_offer.gd` / a `test_content_matrix.gd`

- [ ] **Step 1: Failing test (content gate)** — assert each of the 6 schools has **≥3 move-boons across ≥3 distinct slots + 2 passives + ≥1 duo**, every move/passive boon defines all 4 tiers, every `effect.type` is a registered type, and every duo/mastery's `requires` references valid schools.
- [ ] **Step 2:** Run → FAIL (content incomplete).
- [ ] **Step 3: Author content** — fill `Schools.json` (6 schools per spec §4) and `Boons.json` following the schema (spec §8) and the Venom exemplar (spec §5): each move/passive boon with `tiers.{common,rare,epic,legendary}` where Rare/Epic/Legendary each add a **rider** (reuse the effect types built in Phase 2/3); author the duos (Galvanic Venom, Thousand Cuts, Immovable, Lightning Draw, …) and 6 masteries with `requires`.
- [ ] **Step 4:** Run → PASS (content gate green); play a run to sanity-check offers/build feel.
- [ ] **Step 5: Commit** — `data(boons): v1 school boon matrix (6 schools)`.

---

## Self-Review

- **Spec coverage:** slots (Task 5/7), schools+roster (Task 3/20), 4-tier riders (Task 4/8/20), kinds move/passive/duo/mastery (Task 5/18), Insight (Task 17), steering+favor (Task 16), prefer-empty-slot (Task 14), `create_effect_from_data` boundary (Task 1), jump hooks + no-double-jump (Task 7), re-home by behavior (Task 13), engine reuse (Task 2), data model (Task 3/20), UI/tooltips (Task 15/19). Visual variance + difficulty curve correctly **excluded** (other sub-projects).
- **No placeholders:** each code task has the actual signatures/snippets; content task (20) is gated by an automated content test, not vibes.
- **Type consistency:** `create_effect_from_data(effect_data, id)`, `BoonFactory.build_boon_effects(boon, tier)`, `BoonLoadout.add_boon(id, tier)` / `upgrade_boon(id)`, `TechniqueEngine.add_effect/remove_effect`, boon-instance ids `"<boonId>#<n>"` — used consistently across tasks.
- **Open risk flagged for the implementer:** Tasks 1–2 must not regress existing technique tests (the factory/engine refactor is the load-bearing change); confirm the exact dispatch sites for the new hooks (Task 7) and the bleed-style status apply/tick path (Task 8) against current `combat_system.gd` before coding.
