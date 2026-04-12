# WU Technique System + 20-Technique MVP Pool — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full technique system from Section C of the MVP spec — a JSON data pipeline, runtime application engine, all 20 techniques (12 A-type passive augments, 6 B-type conditional triggers, 2 D-type stance swaps), the one-copy-only duplicate policy, rage-gated D-type activation via the L-key hook Plan 1 scaffolded, and a technique-based reward screen replacing the current stat-bump rewards.

**Architecture:** Techniques are defined as JSON metadata (id, name, type, rarity) with behavior hardcoded in GDScript `match` statements. A `TechniqueEngine` on each player `Fighter` manages the loadout (add/remove/has), applies stat modifications on acquisition, tracks per-fight temporal state (echo flags, sparrow timers, stance counters), and exposes query methods that `CombatSystem.resolve_hits()` calls to apply combat modifiers. Stance swaps (D-type) override `AttackCatalog` definitions via `get_light_override()`/`get_heavy_override()` and modify dash parameters on the `Fighter`. The reward screen changes from 2 stat-bump options to 3 technique picks with one-copy-only filtering.

**Tech Stack:** Godot 4.6.2 (GDScript), RefCounted data classes, JSON data under `WUGodot/data/Techniques/`. Headless test harness (`godot --headless --script res://tests/run_tests.gd`). No new autoloads — `DataManager` gains technique loading methods; `TechniqueEngine` is instantiated per-fighter, not global.

**Spec reference:** `docs/superpowers/specs/2026-04-10-wu-mvp-design.md` — this plan implements **Section C (Build-Crafting Engine / Technique System)** in full, plus the rage activation flow from Section C's "Rage — role in MVP."

**Plan sequence (5 plans total for the WU MVP):**

1. **Plan 1 — Combat Foundation Refactor.** Implemented at commit `72e34bc`. Output: refined 1-vs-Bandit duel with all Section B bullets live.
2. **Plan 2 (this document) — Technique System + 20-Technique MVP Pool.** Data pipeline, runtime engine, all 20 techniques, rage → D-type stance activation, technique-based rewards.
3. **Plan 3 — Enemy Archetypes + Iron Bear Boss.** 5 archetypes with pattern tables, Xiong Tie 2-phase boss.
4. **Plan 4 — Run Structure Expansion.** 8 node types, procedural map-gen, Event system, Shop system, acquisition-flow hookup.
5. **Plan 5 — Run Flow & Chapter 1 Polish.** Main menu, Victory scroll, Defeat screen, SFX/music integration, final balance pass.

Each plan produces working, testable software. Plan 2 validates through the existing headless test harness (new test modules) and a manual playtest checklist for feel.

---

## File Structure

**New files:**

- `WUGodot/scripts/technique.gd` — data class for one technique: id, name_en, name_cn, type (A/B/D), category, description, rarity. Factory method `from_dictionary()`. Pure metadata — no behavior.
- `WUGodot/scripts/technique_engine.gd` — runtime engine on `Fighter`. Manages technique loadout (`add`/`remove`/`has`), applies stat modifications via stored-delta approach (`_stat_deltas` dictionary — order-independent, safe with temporary buffs), tracks per-fight temporal state (echo flag for B1, flowing-water flag for B3, sparrow timer for A4, gaze timer for B4, stance timer/damage for D1/D2), exposes query methods for `CombatSystem` to call during `resolve_hits()`. ~175 lines.
- `WUGodot/data/Techniques/TechniquePool.json` — all 20 technique definitions as JSON metadata. Loaded by `DataManager._load_techniques()`.
- `WUGodot/tests/test_technique.gd` — tests for `Technique.from_dictionary()` and `DataManager` technique loading.
- `WUGodot/tests/test_technique_engine.gd` — tests for add/remove/has, stat mods, echo/flowing-water/phoenix flags, stance activation, damage multipliers.

**Modified files:**

- `WUGodot/scripts/attack_definition.gd` — add `ignores_block: bool = false` field. Used by D1 Drunken Form light attacks to slip past blocks.
- `WUGodot/scripts/attack_catalog.gd` — add four stance attack definitions: `drunken_light()` (ignores_block), `drunken_heavy()` (+40% damage, slower recovery), `tiger_light()` (+20% speed), `tiger_heavy()` (+50% range leap-strike).
- `WUGodot/scripts/fighter.gd` — add `technique_engine: Variant = null`; add `bleed_timer: float`, `bleed_dps: float` for A3 bleed tracking; add `dash_iframe_end: float` instance variable (replaces `GameConstants.DASH_IFRAME_END` in `_compute_is_invulnerable` and `dash_phase_label`); add `_phoenix_invuln_timer: float` for B6 invulnerability; update `reset_for_combat()` to deactivate stance and reset per-fight technique state; update `start_light_attack()` and `start_heavy_attack()` to check technique engine for stance overrides; update `on_stance_input()` to return bool and delegate to technique engine; add D2 Tiger Stance auto-chain in `update_timers()` attack-finished handler (auto-continues light combo up to 3 hits).
- `WUGodot/scripts/combat_system.gd` — hook technique effects into `resolve_hits()`: A2 stagger, A3 bleed, A5 block bonus, A10 twin dragons, B1 echo, B2 break heal, B3 flowing-water heal, B5 damage multiplier, B6 lethal save, D1/D2 block effects; add `tick_effects(fighter, dt)` for bleed damage tick; add dash-end detection in `update_player()` for A1 and A4; add B3 dash-through detection (with proximity check against enemy attack range); add stance activation feedback on L-key press.
- `WUGodot/scripts/combat_scene.gd` — call `tick_effects()` for both fighters after `resolve_hits()`; add technique list display to HUD; add `KEY_3`/`KEY_KP_3` to `_sync_input_tracker()`.
- `WUGodot/scripts/data_manager.gd` — add `_techniques: Dictionary`, `_load_techniques()`, `get_technique(id)`, `get_all_techniques()`; call `_load_techniques()` from `initialize()`.
- `WUGodot/scripts/main.gd` — replace 2-option stat-bump reward screen with 3-option technique reward screen; add `_rewards: Array` replacing `_reward1`/`_reward2`; add `_generate_technique_rewards()`; update `_update_reward()` for 3 options with `KEY_3` support; update `_draw_reward()` for 3-box layout; update `_apply_reward_by_index()`.
- `WUGodot/scripts/reward_option.gd` — add `technique_id: String` field; add `"technique"` case to `apply()`; add `random_technique(owned_ids)` static factory.
- `WUGodot/scripts/enemy_factory.gd` — initialize `technique_engine = TechniqueEngineScript.new()` on player fighter in `create_player()`.
- `WUGodot/tests/run_tests.gd` — add `test_technique.gd` and `test_technique_engine.gd` to `_TEST_MODULES` array.

---

## Testing Strategy

**Headless tests** (automated, run via `godot --headless --script res://tests/run_tests.gd`):

- `test_technique.gd` — `Technique.from_dictionary()` with valid data, missing fields, type validation.
- `test_technique_engine.gd` — add/remove/has, duplicate prevention, D-type exclusivity, stat mod application/unapplication, echo/flowing-water consume, phoenix once-per-run, stance activation/deactivation, damage multiplier queries.

**Manual playtest checklist** (Task 12):

- Each technique's mechanical effect is observable in combat.
- Stance activation via L-key with full rage drains rage and changes attack feel.
- Reward screen offers 3 technique choices, no duplicates of owned techniques.
- Techniques persist across fights within a run.
- Phoenix Rising saves once per run.

---

### Task 1: Technique Data Class

**Files:**
- Create: `WUGodot/scripts/technique.gd`
- Test: `WUGodot/tests/test_technique.gd`

- [ ] **Step 1: Write the failing test**

Create `WUGodot/tests/test_technique.gd`:

```gdscript
extends RefCounted

const TechniqueScript = preload("res://scripts/technique.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	# Test from_dictionary with full data
	var data: Dictionary = {
		"id": "A1",
		"name_en": "Descending Leaf",
		"name_cn": "落葉",
		"type": "A",
		"category": "movement_attack",
		"description": "Dash ends in a sword stab dealing 8 damage.",
		"rarity": 1,
	}
	var tech: Variant = TechniqueScript.from_dictionary(data)

	var checks: Array[Array] = [
		[tech.id, "A1", "id"],
		[tech.name_en, "Descending Leaf", "name_en"],
		[tech.name_cn, "落葉", "name_cn"],
		[tech.type, "A", "type"],
		[tech.category, "movement_attack", "category"],
		[tech.rarity, 1, "rarity"],
	]
	for check in checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("from_dict %s: expected %s got %s" % [str(check[2]), str(check[1]), str(check[0])])

	# Test from_dictionary with missing fields uses defaults
	var empty_tech: Variant = TechniqueScript.from_dictionary({})
	var default_checks: Array[Array] = [
		[empty_tech.id, "", "default id"],
		[empty_tech.name_en, "", "default name_en"],
		[empty_tech.type, "A", "default type"],
		[empty_tech.rarity, 1, "default rarity"],
	]
	for check in default_checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("default %s: expected %s got %s" % [str(check[2]), str(check[1]), str(check[0])])

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: Fail — `test_technique.gd` is not yet registered and `technique.gd` does not exist. (This step is informational — registration happens in Task 5.)

- [ ] **Step 3: Write the Technique data class**

Create `WUGodot/scripts/technique.gd`:

```gdscript
class_name Technique
extends RefCounted

var id: String = ""
var name_en: String = ""
var name_cn: String = ""
var type: String = "A"
var category: String = ""
var description: String = ""
var rarity: int = 1

static func from_dictionary(data: Dictionary) -> Technique:
	var tech: Technique = Technique.new()
	tech.id = str(data.get("id", ""))
	tech.name_en = str(data.get("name_en", ""))
	tech.name_cn = str(data.get("name_cn", ""))
	tech.type = str(data.get("type", "A"))
	tech.category = str(data.get("category", ""))
	tech.description = str(data.get("description", ""))
	tech.rarity = int(data.get("rarity", 1))
	return tech
```

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/technique.gd WUGodot/tests/test_technique.gd
git commit -m "feat: add Technique data class and test"
```

---

### Task 2: Technique JSON Pool + DataManager Loading

**Files:**
- Create: `WUGodot/data/Techniques/TechniquePool.json`
- Modify: `WUGodot/scripts/data_manager.gd`
- Test: `WUGodot/tests/test_technique.gd` (extend)

- [ ] **Step 1: Create the technique data directory and JSON file**

Create `WUGodot/data/Techniques/TechniquePool.json`:

```json
{
  "techniques": [
    {"id": "A1",  "name_en": "Descending Leaf",     "name_cn": "落葉",     "type": "A", "category": "movement_attack", "description": "Dash ends in a sword stab dealing 8 damage.",                                    "rarity": 1},
    {"id": "A2",  "name_en": "Iron Palm",            "name_cn": "鐵掌",     "type": "A", "category": "attack",          "description": "Light attacks have a 20% chance to stagger on hit.",                              "rarity": 1},
    {"id": "A3",  "name_en": "Widow's Kiss",         "name_cn": "寡婦吻",   "type": "A", "category": "attack",          "description": "Heavy attacks apply a 3s bleed dealing 1.5 damage/sec.",                          "rarity": 2},
    {"id": "A4",  "name_en": "Sparrow Wing",         "name_cn": "雀翼",     "type": "A", "category": "movement_attack", "description": "First light attack within 0.6s after a dash has +30% damage.",                    "rarity": 1},
    {"id": "A5",  "name_en": "Stone Posture",        "name_cn": "石身勢",   "type": "A", "category": "defense",         "description": "Blocking reduces incoming damage by an additional 10%.",                          "rarity": 1},
    {"id": "A6",  "name_en": "Heart of Bamboo",      "name_cn": "竹心",     "type": "A", "category": "defense",         "description": "+15 max posture.",                                                                "rarity": 1},
    {"id": "A7",  "name_en": "Crane Step",           "name_cn": "鶴步",     "type": "A", "category": "movement",        "description": "+15% ground move speed.",                                                         "rarity": 1},
    {"id": "A8",  "name_en": "Mountain Root",        "name_cn": "山根",     "type": "A", "category": "defense",         "description": "Posture recovery rate +25% when not under pressure.",                              "rarity": 1},
    {"id": "A9",  "name_en": "Cloud Hands",          "name_cn": "雲手",     "type": "A", "category": "defense",         "description": "Parry window extended by 0.03s.",                                                  "rarity": 2},
    {"id": "A10", "name_en": "Twin Dragons",         "name_cn": "雙龍",     "type": "A", "category": "attack",          "description": "Heavy attacks deal a follow-through second hit at 50% damage.",                   "rarity": 2},
    {"id": "A11", "name_en": "Wind in the Sleeves",  "name_cn": "袖中風",   "type": "A", "category": "movement",        "description": "Dash speed +25% and dash cooldown -0.15s.",                                       "rarity": 1},
    {"id": "A12", "name_en": "Inkstone Discipline",  "name_cn": "墨石定",   "type": "A", "category": "defense",         "description": "+20 max HP.",                                                                     "rarity": 1},
    {"id": "B1",  "name_en": "Mountain's Echo",      "name_cn": "山谷回響", "type": "B", "category": "trigger_parry",   "description": "After a perfect parry, your next attack is a guaranteed posture break.",           "rarity": 2},
    {"id": "B2",  "name_en": "Breath of Returning Spring", "name_cn": "回春氣", "type": "B", "category": "trigger_break", "description": "On posture break, restore 15 HP.",                                           "rarity": 2},
    {"id": "B3",  "name_en": "Flowing Water",        "name_cn": "流水意",   "type": "B", "category": "trigger_dash",    "description": "Dash through an attack; your next hit heals 5 HP.",                               "rarity": 2},
    {"id": "B4",  "name_en": "Thousand-Mile Gaze",   "name_cn": "千里眼",   "type": "B", "category": "trigger_kill",    "description": "After killing an enemy, gain 3s of +50% move speed.",                             "rarity": 2},
    {"id": "B5",  "name_en": "Scar of the Past",     "name_cn": "舊傷",     "type": "B", "category": "trigger_hp",      "description": "When below 30% HP, all damage dealt is +25%.",                                    "rarity": 2},
    {"id": "B6",  "name_en": "Phoenix Rising",       "name_cn": "鳳凰起",   "type": "B", "category": "trigger_lethal",  "description": "On lethal damage, heal to 20% HP + 2s invincibility. Once per run.",              "rarity": 3},
    {"id": "D1",  "name_en": "Drunken Form",         "name_cn": "醉拳",     "type": "D", "category": "stance",          "description": "Extended dash i-frames. Light attacks slip past blocks. Heavy +40% damage. Ends after 20 HP damage taken.", "rarity": 3},
    {"id": "D2",  "name_en": "Tiger Stance",         "name_cn": "虎形",     "type": "D", "category": "stance",          "description": "Light attacks +20% speed. Block reflects 10% damage. Heavy +50% range. Lasts 15s.", "rarity": 3}
  ]
}
```

- [ ] **Step 2: Add technique loading to DataManager**

In `WUGodot/scripts/data_manager.gd`, add the static variable after `_rewards` (line 8):

```gdscript
static var _techniques: Dictionary = {}
```

Add `_load_techniques()` call to `initialize()` (after line 15, before existing loads are fine — insert after `_load_game_settings()`):

```gdscript
_load_techniques()
```

Add `_techniques.clear()` to `reload_data()` (after line 22, before `initialize()`).

Add the loading method and accessors (before `_load_game_settings`, or at end of file before defaults):

```gdscript
static func get_technique(id: String) -> Dictionary:
	if _techniques.has(id):
		return (_techniques[id] as Dictionary).duplicate(true)
	return {}

static func get_all_techniques() -> Dictionary:
	return _techniques.duplicate(true)

static func _load_techniques() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Techniques")
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if file_name.get_extension().to_lower() != "json":
			continue
		var root: Dictionary = _load_json_file("res://data/Techniques/%s" % file_name)
		var raw_techniques: Array = []
		if typeof(root.get("techniques", [])) == TYPE_ARRAY:
			raw_techniques = root.get("techniques", []) as Array
		for entry in raw_techniques:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var tech_id: String = str((entry as Dictionary).get("id", ""))
			if tech_id.is_empty():
				continue
			_techniques[tech_id] = entry as Dictionary
	dir.list_dir_end()
```

- [ ] **Step 3: Add DataManager loading test to test_technique.gd**

Append to the `run_all()` method in `WUGodot/tests/test_technique.gd`, before the return:

```gdscript
	# Test DataManager loads techniques
	DataManager.reload_data()
	var a1_data: Dictionary = DataManager.get_technique("A1")
	if str(a1_data.get("id", "")) == "A1":
		passed += 1
	else:
		failed += 1
		failures.append("DataManager.get_technique('A1') should return A1 data")

	var all_techniques: Dictionary = DataManager.get_all_techniques()
	if all_techniques.size() == 20:
		passed += 1
	else:
		failed += 1
		failures.append("get_all_techniques should return 20 (got %d)" % all_techniques.size())

	var missing: Dictionary = DataManager.get_technique("NONEXISTENT")
	if missing.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("get_technique for missing id should return empty dict")
```

- [ ] **Step 4: Commit**

```bash
git add WUGodot/data/Techniques/TechniquePool.json WUGodot/scripts/data_manager.gd WUGodot/scripts/technique.gd WUGodot/tests/test_technique.gd
git commit -m "feat: add technique JSON pool and DataManager loading"
```

---

### Task 3: TechniqueEngine Core

**Files:**
- Create: `WUGodot/scripts/technique_engine.gd`
- Create: `WUGodot/tests/test_technique_engine.gd`

- [ ] **Step 1: Write the failing test for add/remove/has**

Create `WUGodot/tests/test_technique_engine.gd`:

```gdscript
extends RefCounted

const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()

	# --- add / has / technique_ids ---
	var fighter: Fighter = Fighter.new()
	fighter.health_max = 100.0
	fighter.health_current = 100.0
	fighter.posture_max = 100.0
	fighter.posture_current = 100.0
	fighter.move_speed = 320.0
	fighter.posture_recovery_rate = 12.0
	fighter.parry_window = 0.15
	fighter.dash_speed = 1100.0
	fighter.air_dash_speed = 950.0
	fighter.dash_cooldown = 0.80
	fighter.rage_max = 100.0
	fighter.rage_current = 0.0
	fighter.dash_duration = 0.22
	fighter.dash_iframe_end = 0.18

	var engine: Variant = TechniqueEngineScript.new()

	# Test 1: initially empty
	if engine.technique_ids().size() == 0:
		passed += 1
	else:
		failed += 1
		failures.append("engine should start empty")

	# Test 2: add and has
	engine.add("A6", fighter)
	if engine.has("A6"):
		passed += 1
	else:
		failed += 1
		failures.append("should have A6 after add")

	# Test 3: technique_ids returns correct list
	if engine.technique_ids().size() == 1 and engine.technique_ids()[0] == "A6":
		passed += 1
	else:
		failed += 1
		failures.append("technique_ids should be ['A6']")

	# Test 4: duplicate add is no-op
	engine.add("A6", fighter)
	if engine.technique_ids().size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("duplicate add should not increase count")

	# Test 5: remove
	var pre_remove_posture: float = fighter.posture_max
	engine.remove("A6", fighter)
	if not engine.has("A6") and engine.technique_ids().size() == 0:
		passed += 1
	else:
		failed += 1
		failures.append("should not have A6 after remove")

	# Test 6: D-type exclusivity — adding D2 when D1 exists removes D1
	engine.add("D1", fighter)
	engine.add("D2", fighter)
	if engine.has("D2") and not engine.has("D1"):
		passed += 1
	else:
		failed += 1
		failures.append("D2 should replace D1 (D-type exclusive)")
	engine.remove("D2", fighter)

	# Test 7: remove non-existent is no-op
	engine.remove("FAKE", fighter)
	if engine.technique_ids().size() == 0:
		passed += 1
	else:
		failed += 1
		failures.append("remove non-existent should be no-op")

	# --- echo / flowing water / phoenix ---

	# Test 8: echo consume
	engine.add("B1", fighter)
	engine.set_echo()
	if engine.consume_echo():
		passed += 1
	else:
		failed += 1
		failures.append("consume_echo should return true when active")

	# Test 9: echo second consume is false
	if not engine.consume_echo():
		passed += 1
	else:
		failed += 1
		failures.append("consume_echo should return false after consumed")
	engine.remove("B1", fighter)

	# Test 10: flowing water consume
	engine.add("B3", fighter)
	engine.on_dash_through()
	if engine.consume_flowing_water():
		passed += 1
	else:
		failed += 1
		failures.append("consume_flowing_water should return true after dash through")
	if not engine.consume_flowing_water():
		passed += 1
	else:
		failed += 1
		failures.append("second consume_flowing_water should be false")
	engine.remove("B3", fighter)

	# Test 11: phoenix — once per run
	engine.add("B6", fighter)
	fighter.health_current = 0.0
	if engine.check_lethal_save(fighter):
		passed += 1
	else:
		failed += 1
		failures.append("phoenix should save on first lethal")

	# Test 12: phoenix health restored to 20%
	if absf(fighter.health_current - fighter.health_max * 0.2) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("phoenix should heal to 20%% max HP (got %.1f)" % fighter.health_current)

	# Test 13: phoenix second use fails
	fighter.health_current = 0.0
	if not engine.check_lethal_save(fighter):
		passed += 1
	else:
		failed += 1
		failures.append("phoenix should not save twice per run")
	engine.remove("B6", fighter)
	fighter.health_current = fighter.health_max

	# Test 14: reset_combat_state clears per-fight flags but not phoenix
	engine.add("B1", fighter)
	engine.add("B6", fighter)
	engine.set_echo()
	engine.reset_combat_state(fighter)
	if not engine.consume_echo():
		passed += 1
	else:
		failed += 1
		failures.append("reset_combat_state should clear echo")

	# phoenix_used should persist after reset_combat_state (set from test 11)
	fighter.health_current = 0.0
	if not engine.check_lethal_save(fighter):
		passed += 1
	else:
		failed += 1
		failures.append("phoenix_used should persist through reset_combat_state")
	fighter.health_current = fighter.health_max
	engine.remove("B1", fighter)
	engine.remove("B6", fighter)

	# Test 15: B4 gaze deferred application — on_kill sets earned flag, update() applies buff
	engine.add("B4", fighter)
	var base_speed: float = fighter.move_speed
	engine.on_kill(fighter)
	# on_kill should NOT modify speed immediately — buff is deferred
	if absf(fighter.move_speed - base_speed) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("on_kill should defer gaze buff, not apply immediately")
	# Simulate next-fight start: reset clears active gaze but preserves earned flag
	engine.reset_combat_state(fighter)
	# First update tick applies the deferred buff
	engine.update(0.016, fighter)
	if fighter.move_speed > base_speed + 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("first update after on_kill should apply gaze speed bonus")
	# After 3s the buff expires naturally
	engine.update(3.0, fighter)
	if absf(fighter.move_speed - base_speed) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("gaze bonus should expire after 3s (got %.1f, expected %.1f)" % [fighter.move_speed, base_speed])
	engine.remove("B4", fighter)

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Implement TechniqueEngine foundation**

Create `WUGodot/scripts/technique_engine.gd`:

```gdscript
class_name TechniqueEngine
extends RefCounted

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

var _technique_ids: Array[String] = []
var _active_stance_id: String = ""
var _stance_timer: float = 0.0
var _stance_damage_taken: float = 0.0
var _pre_stance_dash_duration: float = 0.0
var _pre_stance_dash_iframe_end: float = 0.0
var _phoenix_used: bool = false
var _echo_active: bool = false
var _flowing_water_heal: bool = false
var _sparrow_timer: float = 0.0
var _gaze_timer: float = 0.0
var _gaze_speed_bonus: float = 0.0
var _gaze_earned: bool = false
var _stat_deltas: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func has(id: String) -> bool:
	return _technique_ids.has(id)

func technique_ids() -> Array[String]:
	return _technique_ids.duplicate()

func add(id: String, fighter: Fighter) -> void:
	if has(id):
		return
	if id.begins_with("D"):
		for existing_id in _technique_ids.duplicate():
			if existing_id.begins_with("D"):
				remove(existing_id, fighter)
	_technique_ids.append(id)
	_apply_on_add(id, fighter)

func remove(id: String, fighter: Fighter) -> void:
	if not has(id):
		return
	if _active_stance_id == id:
		deactivate_stance(fighter)
	_technique_ids.erase(id)
	_unapply(id, fighter)

func _apply_on_add(_id: String, _fighter: Fighter) -> void:
	pass

func _unapply(_id: String, _fighter: Fighter) -> void:
	pass

func update(dt: float, fighter: Fighter) -> void:
	# B4 deferred gaze: apply the buff at the start of the next fight
	if _gaze_earned and _gaze_timer <= 0.0:
		_gaze_speed_bonus = fighter.move_speed * 0.5
		fighter.move_speed += _gaze_speed_bonus
		_gaze_timer = 3.0
		_gaze_earned = false
	if _sparrow_timer > 0.0:
		_sparrow_timer -= dt
	if _gaze_timer > 0.0:
		_gaze_timer -= dt
		if _gaze_timer <= 0.0:
			fighter.move_speed -= _gaze_speed_bonus
			_gaze_speed_bonus = 0.0
	if _active_stance_id == "D2" and _stance_timer > 0.0:
		_stance_timer -= dt
		if _stance_timer <= 0.0:
			deactivate_stance(fighter)

func activate_stance(fighter: Fighter) -> bool:
	if _active_stance_id != "":
		return false
	var d_id: String = ""
	for id in _technique_ids:
		if id.begins_with("D"):
			d_id = id
			break
	if d_id == "":
		return false
	if fighter.rage_current < fighter.rage_max:
		return false
	fighter.rage_current = 0.0
	_active_stance_id = d_id
	_stance_damage_taken = 0.0
	match d_id:
		"D1":
			_pre_stance_dash_duration = fighter.dash_duration
			_pre_stance_dash_iframe_end = fighter.dash_iframe_end
			fighter.dash_duration = 0.30
			# i-frame phase = 0.22s; absolute end = DASH_STARTUP_END(0.04) + 0.22 = 0.26
			fighter.dash_iframe_end = 0.26
		"D2":
			_stance_timer = 15.0
	return true

func deactivate_stance(fighter: Fighter) -> void:
	if _active_stance_id == "":
		return
	match _active_stance_id:
		"D1":
			fighter.dash_duration = _pre_stance_dash_duration
			fighter.dash_iframe_end = _pre_stance_dash_iframe_end
	_active_stance_id = ""
	_stance_timer = 0.0
	_stance_damage_taken = 0.0

func is_stance_active() -> bool:
	return _active_stance_id != ""

func active_stance() -> String:
	return _active_stance_id

func get_light_override() -> Variant:
	match _active_stance_id:
		"D1":
			return AttackCatalogScript.drunken_light()
		"D2":
			return AttackCatalogScript.tiger_light()
	return null

func get_heavy_override() -> Variant:
	match _active_stance_id:
		"D1":
			return AttackCatalogScript.drunken_heavy()
		"D2":
			return AttackCatalogScript.tiger_heavy()
	return null

func set_echo() -> void:
	_echo_active = true

func consume_echo() -> bool:
	if _echo_active:
		_echo_active = false
		return true
	return false

func consume_flowing_water() -> bool:
	if _flowing_water_heal:
		_flowing_water_heal = false
		return true
	return false

func on_dash_through() -> void:
	if has("B3"):
		_flowing_water_heal = true

func on_dash_end() -> void:
	if has("A4"):
		_sparrow_timer = 0.6

func has_sparrow_bonus() -> bool:
	return _sparrow_timer > 0.0

func consume_sparrow() -> void:
	_sparrow_timer = 0.0

func on_kill(fighter: Fighter) -> void:
	if not has("B4"):
		return
	if _gaze_timer > 0.0:
		# Already active in a multi-enemy fight — refresh timer
		_gaze_timer = 3.0
		return
	# Deferred: buff applies at the start of the next fight's first update() tick
	_gaze_earned = true

func on_posture_break(fighter: Fighter) -> void:
	if has("B2"):
		fighter.health_current = minf(fighter.health_current + 15.0, fighter.health_max)

func check_lethal_save(fighter: Fighter) -> bool:
	if not has("B6") or _phoenix_used:
		return false
	_phoenix_used = true
	fighter.health_current = fighter.health_max * 0.2
	fighter._phoenix_invuln_timer = 2.0
	return true

func on_stance_damage(amount: float, fighter: Fighter) -> bool:
	if _active_stance_id != "D1":
		return false
	_stance_damage_taken += amount
	if _stance_damage_taken >= 20.0:
		deactivate_stance(fighter)
		return true
	return false

func roll_stagger() -> bool:
	return has("A2") and _rng.randf() < 0.2

func reset_combat_state(fighter: Fighter) -> void:
	_echo_active = false
	_flowing_water_heal = false
	_sparrow_timer = 0.0
	if _gaze_speed_bonus > 0.0:
		fighter.move_speed -= _gaze_speed_bonus
	_gaze_timer = 0.0
	_gaze_speed_bonus = 0.0
	# _gaze_earned intentionally persists — carries the buff into the next fight
	_stance_damage_taken = 0.0
```

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/technique_engine.gd WUGodot/tests/test_technique_engine.gd
git commit -m "feat: add TechniqueEngine core with add/remove/has and event state"
```

---

### Task 4: Stat-Mod Techniques (A6, A7, A8, A9, A11, A12)

**Files:**
- Modify: `WUGodot/scripts/technique_engine.gd` (fill in `_apply_on_add` and `_unapply`)
- Modify: `WUGodot/tests/test_technique_engine.gd` (add stat mod tests)

- [ ] **Step 1: Add stat mod tests**

Append to `run_all()` in `WUGodot/tests/test_technique_engine.gd`, before the return:

```gdscript
	# --- Stat mod tests ---
	var sf: Fighter = Fighter.new()
	sf.health_max = 100.0
	sf.health_current = 100.0
	sf.posture_max = 100.0
	sf.posture_current = 100.0
	sf.move_speed = 320.0
	sf.posture_recovery_rate = 12.0
	sf.parry_window = 0.15
	sf.dash_speed = 1100.0
	sf.air_dash_speed = 950.0
	sf.dash_cooldown = 0.80
	sf.rage_max = 100.0
	sf.rage_current = 0.0
	sf.dash_duration = 0.22
	sf.dash_iframe_end = 0.18

	var se: Variant = TechniqueEngineScript.new()

	# Test A6: +15 posture_max
	se.add("A6", sf)
	if absf(sf.posture_max - 115.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A6 should set posture_max to 115 (got %.1f)" % sf.posture_max)

	se.remove("A6", sf)
	if absf(sf.posture_max - 100.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A6 remove should restore posture_max to 100 (got %.1f)" % sf.posture_max)

	# Test A7: +15% move_speed
	se.add("A7", sf)
	var expected_speed: float = 320.0 * 1.15
	if absf(sf.move_speed - expected_speed) < 0.1:
		passed += 1
	else:
		failed += 1
		failures.append("A7 should set move_speed to %.1f (got %.1f)" % [expected_speed, sf.move_speed])
	se.remove("A7", sf)

	# Test A12: +20 health_max
	se.add("A12", sf)
	if absf(sf.health_max - 120.0) < 0.01 and absf(sf.health_current - 120.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A12 should set health_max to 120 (got %.1f/%.1f)" % [sf.health_max, sf.health_current])
	se.remove("A12", sf)

	# Test A9: +0.03 parry window
	se.add("A9", sf)
	if absf(sf.parry_window - 0.18) < 0.001:
		passed += 1
	else:
		failed += 1
		failures.append("A9 should set parry_window to 0.18 (got %.3f)" % sf.parry_window)
	se.remove("A9", sf)

	# Test A11: dash_speed +25%, dash_cooldown -0.15
	se.add("A11", sf)
	if absf(sf.dash_speed - 1375.0) < 0.1 and absf(sf.dash_cooldown - 0.65) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A11 dash_speed=%.1f (expect 1375) cooldown=%.2f (expect 0.65)" % [sf.dash_speed, sf.dash_cooldown])
	se.remove("A11", sf)

	# Test A8: +25% posture_recovery_rate
	se.add("A8", sf)
	if absf(sf.posture_recovery_rate - 15.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("A8 should set recovery to 15.0 (got %.1f)" % sf.posture_recovery_rate)
	se.remove("A8", sf)
```

- [ ] **Step 2: Run test to verify failures**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: stat mod tests fail because `_apply_on_add` and `_unapply` are stubs.

- [ ] **Step 3: Implement stat mod application**

Replace the `_apply_on_add` and `_unapply` methods in `WUGodot/scripts/technique_engine.gd`:

```gdscript
func _apply_on_add(id: String, fighter: Fighter) -> void:
	var delta: Variant = null
	match id:
		"A6":
			delta = {"posture_max": 15.0, "posture_current": 15.0}
			fighter.posture_max += 15.0
			fighter.posture_current += 15.0
		"A7":
			var bonus: float = fighter.move_speed * 0.15
			delta = {"move_speed": bonus}
			fighter.move_speed += bonus
		"A8":
			var bonus: float = fighter.posture_recovery_rate * 0.25
			delta = {"posture_recovery_rate": bonus}
			fighter.posture_recovery_rate += bonus
		"A9":
			delta = {"parry_window": 0.03}
			fighter.parry_window += 0.03
		"A11":
			var ds: float = fighter.dash_speed * 0.25
			var ads: float = fighter.air_dash_speed * 0.25
			var cd_reduction: float = minf(0.15, fighter.dash_cooldown - 0.1)
			delta = {"dash_speed": ds, "air_dash_speed": ads, "dash_cooldown": -cd_reduction}
			fighter.dash_speed += ds
			fighter.air_dash_speed += ads
			fighter.dash_cooldown -= cd_reduction
		"A12":
			delta = {"health_max": 20.0, "health_current": 20.0}
			fighter.health_max += 20.0
			fighter.health_current += 20.0
	if delta != null:
		_stat_deltas[id] = delta

func _unapply(id: String, fighter: Fighter) -> void:
	var delta: Variant = _stat_deltas.get(id)
	if delta == null:
		return
	match id:
		"A6":
			fighter.posture_max -= float(delta["posture_max"])
			fighter.posture_current = minf(fighter.posture_current, fighter.posture_max)
		"A7":
			fighter.move_speed -= float(delta["move_speed"])
		"A8":
			fighter.posture_recovery_rate -= float(delta["posture_recovery_rate"])
		"A9":
			fighter.parry_window -= float(delta["parry_window"])
		"A11":
			fighter.dash_speed -= float(delta["dash_speed"])
			fighter.air_dash_speed -= float(delta["air_dash_speed"])
			fighter.dash_cooldown -= float(delta["dash_cooldown"])
		"A12":
			fighter.health_max -= float(delta["health_max"])
			fighter.health_current = minf(fighter.health_current, fighter.health_max)
	_stat_deltas.erase(id)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All stat mod tests pass. (Tests won't run yet — test module not registered until Task 5. Verify manually that the file parses without errors.)

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/technique_engine.gd WUGodot/tests/test_technique_engine.gd
git commit -m "feat: implement stat-mod techniques A6/A7/A8/A9/A11/A12"
```

---

### Task 5: Fighter + Factory + Test Harness Integration

**Files:**
- Modify: `WUGodot/scripts/fighter.gd`
- Modify: `WUGodot/scripts/enemy_factory.gd`
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Add new fields to Fighter**

In `WUGodot/scripts/fighter.gd`:

After the existing `const` declarations (line 3), add:

```gdscript
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
```

After `_attack_state` (line 95), add:

```gdscript
var technique_engine: Variant = null
```

After `dash_cooldown` (line 98), add:

```gdscript
var dash_iframe_end: float = GameConstants.DASH_IFRAME_END
```

After `was_hit_this_swing` (line 109), add:

```gdscript
var bleed_timer: float = 0.0
var bleed_dps: float = 0.0
```

After `_ai_decision_timer` (line 131), add:

```gdscript
var _phoenix_invuln_timer: float = 0.0
```

- [ ] **Step 2: Update _compute_is_invulnerable to use instance fields**

Replace the `_compute_is_invulnerable` method (lines 242-246) in `WUGodot/scripts/fighter.gd`:

```gdscript
func _compute_is_invulnerable() -> bool:
	if _phoenix_invuln_timer > 0.0:
		return true
	if _dash_timer <= 0.0:
		return false
	var dash_elapsed: float = dash_duration - _dash_timer
	return dash_elapsed >= GameConstants.DASH_STARTUP_END and dash_elapsed < dash_iframe_end
```

- [ ] **Step 3: Update dash_phase_label to use instance field**

Replace `GameConstants.DASH_IFRAME_END` with `dash_iframe_end` in `dash_phase_label()` (line 254):

```gdscript
func dash_phase_label() -> String:
	if _dash_timer <= 0.0:
		return "idle"
	var dash_elapsed: float = dash_duration - _dash_timer
	if dash_elapsed < GameConstants.DASH_STARTUP_END:
		return "startup"
	if dash_elapsed < dash_iframe_end:
		return "iframes"
	return "recovery"
```

- [ ] **Step 4: Update update_timers for bleed and phoenix**

In `WUGodot/scripts/fighter.gd`, in `update_timers(dt)`, add after the `_ai_decision_timer` block (after line 171):

```gdscript
	if _phoenix_invuln_timer > 0.0:
		_phoenix_invuln_timer -= dt

	if technique_engine != null:
		technique_engine.update(dt, self)
```

- [ ] **Step 5: Add D2 Tiger Stance auto-chain to update_timers**

In `WUGodot/scripts/fighter.gd`, replace the attack finished handler in `update_timers()` (lines 186-189):

```gdscript
	if bool(events.get("finished", false)):
		was_hit_this_swing = false
		# D2 Tiger Stance: auto-chain light attacks into 3-hit combo
		if technique_engine != null and technique_engine.active_stance() == "D2" \
				and _attack_state.def != null and _attack_state.def.id == "tiger_light" \
				and combo_count < 3:
			combo_window = combo_window_duration
			start_light_attack()
		elif current_animation == AnimationState.ATTACKING:
			current_animation = AnimationState.IDLE
```

This makes a single light-attack press in Tiger Stance commit to a rapid 3-hit claw combo (+20% speed per hit). The existing combo system naturally increments `combo_count` because `combo_window > 0` when `start_light_attack()` fires. Heavy attacks remain single-hit.

- [ ] **Step 6: Update reset_for_combat**

In `WUGodot/scripts/fighter.gd`, add to `reset_for_combat()` (after line 154, before closing):

```gdscript
	bleed_timer = 0.0
	bleed_dps = 0.0
	_phoenix_invuln_timer = 0.0
	if technique_engine != null:
		technique_engine.deactivate_stance(self)
		technique_engine.reset_combat_state(self)
```

- [ ] **Step 7: Update start_light_attack and start_heavy_attack for stance overrides**

Replace `start_light_attack()` (line 299-300) in `WUGodot/scripts/fighter.gd`:

```gdscript
func start_light_attack() -> void:
	var override: Variant = null
	if technique_engine != null:
		override = technique_engine.get_light_override()
	_start_attack_with(override if override != null else AttackCatalogScript.hu_light())
```

Replace `start_heavy_attack()` (line 302-303):

```gdscript
func start_heavy_attack() -> void:
	var override: Variant = null
	if technique_engine != null:
		override = technique_engine.get_heavy_override()
	_start_attack_with(override if override != null else AttackCatalogScript.hu_heavy())
```

- [ ] **Step 8: Update on_stance_input to return bool and delegate**

Replace `on_stance_input()` (lines 370-371):

```gdscript
func on_stance_input() -> bool:
	if technique_engine == null:
		return false
	return technique_engine.activate_stance(self)
```

- [ ] **Step 9: Initialize technique_engine in EnemyFactory.create_player**

In `WUGodot/scripts/enemy_factory.gd`, add after line 2 (class declaration or at top):

```gdscript
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
```

In `create_player()`, add before `return player` (before line 85):

```gdscript
	player.technique_engine = TechniqueEngineScript.new()
```

- [ ] **Step 10: Register test modules in run_tests.gd**

In `WUGodot/tests/run_tests.gd`, add to the `_TEST_MODULES` array (after line 6):

```gdscript
	"res://tests/test_technique.gd",
	"res://tests/test_technique_engine.gd",
```

- [ ] **Step 11: Run all tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass (25 existing + ~25 new technique tests).

- [ ] **Step 12: Commit**

```bash
git add WUGodot/scripts/fighter.gd WUGodot/scripts/enemy_factory.gd WUGodot/tests/run_tests.gd
git commit -m "feat: integrate TechniqueEngine into Fighter and EnemyFactory"
```

---

### Task 6: AttackDefinition + AttackCatalog Updates

**Files:**
- Modify: `WUGodot/scripts/attack_definition.gd`
- Modify: `WUGodot/scripts/attack_catalog.gd`

- [ ] **Step 1: Add ignores_block to AttackDefinition**

In `WUGodot/scripts/attack_definition.gd`, add after `knockback_units` (line 21):

```gdscript
var ignores_block: bool = false
```

- [ ] **Step 2: Add stance attack definitions to AttackCatalog**

In `WUGodot/scripts/attack_catalog.gd`, append before the final empty line:

```gdscript

static func drunken_light():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "drunken_light"
	def.duration = 0.55
	def.windup_end = 0.20
	def.active_end = 0.32
	def.damage = 12.0
	def.posture_damage = 18.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.ignores_block = true
	def.range_units = 68.0
	def.knockback_units = 280.0
	return def

static func drunken_heavy():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "drunken_heavy"
	def.duration = 1.10
	def.windup_end = 0.45
	def.active_end = 0.60
	def.damage = 30.8
	def.posture_damage = 58.8
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 84.0
	def.knockback_units = 480.0
	return def

static func tiger_light():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "tiger_light"
	def.duration = 0.40
	def.windup_end = 0.14
	def.active_end = 0.24
	def.damage = 12.0
	def.posture_damage = 22.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 72.0
	def.knockback_units = 280.0
	return def

static func tiger_heavy():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "tiger_heavy"
	def.duration = 0.85
	def.windup_end = 0.40
	def.active_end = 0.55
	def.damage = 22.0
	def.posture_damage = 42.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 126.0
	def.knockback_units = 500.0
	return def
```

- [ ] **Step 3: Run tests to verify nothing broke**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass. The new `ignores_block` field defaults to `false`, so existing `AttackDefinition` instances are unaffected.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/attack_definition.gd WUGodot/scripts/attack_catalog.gd
git commit -m "feat: add ignores_block field and stance attack definitions"
```

---

### Task 7: Combat Modifier Hooks (A2, A3, A5, A10, B5)

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd`

This task hooks five technique effects into `resolve_hits()` and adds `tick_effects()` for bleed processing.

- [ ] **Step 1: Add tick_effects method for bleed**

In `WUGodot/scripts/combat_system.gd`, add after `clamp_world_bounds` (after line 255):

```gdscript

func tick_effects(fighter: Fighter, dt: float) -> void:
	if fighter.bleed_timer > 0.0:
		var bleed_damage: float = fighter.bleed_dps * dt
		fighter.health_current -= bleed_damage
		fighter.health_current = maxf(fighter.health_current, 0.0)
		fighter.bleed_timer -= dt
		if fighter.bleed_timer <= 0.0:
			fighter.bleed_timer = 0.0
			fighter.bleed_dps = 0.0
		if bleed_damage > 0.1:
			emit_signal("damage_dealt", fighter.position + Vector2(0.0, -fighter.height - 20.0), bleed_damage, false)
```

- [ ] **Step 2: Hook B5 Scar of the Past damage multiplier into resolve_hits**

In `resolve_hits()`, after the combo damage bonus calculation (after line 198 — `var posture_damage: float = ...`), add:

```gdscript
		if attacker.technique_engine != null and attacker.technique_engine.has("B5"):
			if attacker.health_current <= attacker.health_max * 0.3:
				hp_damage *= 1.25
				posture_damage *= 1.25
```

- [ ] **Step 3: Hook A5 Stone Posture into blocking branch**

In `resolve_hits()`, in the blocking branch (after line 203 — `hp_damage *= float(settings.get("blockHealthMultiplier", 0.2))`), add:

```gdscript
			if defender.technique_engine != null and defender.technique_engine.has("A5"):
				hp_damage *= 0.5
```

This halves the already-blocked damage: base blocks 80% (deals 20%), A5 blocks 90% (deals 10%).

- [ ] **Step 4: Add ignores_block check to blocking condition**

In `resolve_hits()`, add `ignores_block` variable after `attack_is_perilous` (after line 170):

```gdscript
		var attack_ignores_block: bool = attack_def != null and attack_def.ignores_block
```

Modify the blocking `if` condition (line 201) from:

```gdscript
		if defender.is_blocking and not attack_is_perilous:
```

To:

```gdscript
		if defender.is_blocking and not attack_is_perilous and not attack_ignores_block:
```

After the perilous block `elif` (line 206-207), add a new branch for ignores_block:

```gdscript
		elif defender.is_blocking and attack_ignores_block:
			emit_signal("show_feedback", "SLIPPED!", 0.5)
```

- [ ] **Step 5: Hook A3 Widow's Kiss bleed on heavy**

In `resolve_hits()`, after `defender.health_current -= hp_damage` (after line 211), add:

```gdscript
		if attacker.technique_engine != null and attacker.technique_engine.has("A3"):
			if attack_def != null and attack_def.is_heavy:
				defender.bleed_timer = 3.0
				defender.bleed_dps = 1.5
```

- [ ] **Step 6: Hook A2 Iron Palm stagger**

In `resolve_hits()`, after the hit reaction block (after line 241 — `defender.animation_timer = 0.0`), add:

```gdscript
		if attacker.technique_engine != null and attacker.technique_engine.roll_stagger():
			if attack_def != null and not attack_def.is_heavy and defender._attack_state.is_active():
				defender._attack_state.clear()
				defender._attack_cooldown = 0.3
				emit_signal("show_feedback", "STAGGER!", 0.4)
```

- [ ] **Step 7: Hook A10 Twin Dragons second hit**

In `resolve_hits()`, after the final `emit_signal("spawn_particles", ...)` (after line 248), add:

```gdscript
		if attacker.technique_engine != null and attacker.technique_engine.has("A10"):
			if attack_def != null and attack_def.is_heavy:
				var twin_damage: float = hp_damage * 0.5
				defender.health_current -= twin_damage
				defender.health_current = maxf(defender.health_current, 0.0)
				var twin_pos: Vector2 = defender.position + Vector2(float(defender.facing) * -8.0, -defender.height - 30.0)
				emit_signal("damage_dealt", twin_pos, twin_damage, true)
				emit_signal("spawn_particles", twin_pos, 8, Color8(255, 200, 100))
```

- [ ] **Step 8: Call tick_effects from combat_scene**

In `WUGodot/scripts/combat_scene.gd`, after the two `resolve_hits` calls (after line 158), add:

```gdscript
		_combat_system.tick_effects(_player, dt)
		_combat_system.tick_effects(_enemy, dt)
```

- [ ] **Step 9: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass. Combat modifier hooks are integration-level — verified via playtest in Task 12.

- [ ] **Step 10: Commit**

```bash
git add WUGodot/scripts/combat_system.gd WUGodot/scripts/combat_scene.gd
git commit -m "feat: hook A2/A3/A5/A10/B5 combat modifiers into resolve_hits"
```

---

### Task 8: Dash Techniques (A1 Descending Leaf, A4 Sparrow Wing)

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd`

- [ ] **Step 1: Add dash-end detection and A1/A4 hooks to update_player**

In `update_player()` in `WUGodot/scripts/combat_system.gd`, the dash-end and technique hooks need to fire when the dash timer transitions from positive to zero. The dash timer is decremented inside `fighter.update_timers(dt)`, so capture the pre-update state.

Replace the `fighter.update_timers(dt)` call (line 91) with:

```gdscript
	var was_dashing: bool = fighter._dash_timer > 0.0
	fighter.update_timers(dt)
	var dash_just_ended: bool = was_dashing and fighter._dash_timer <= 0.0

	if dash_just_ended and fighter.technique_engine != null:
		fighter.technique_engine.on_dash_end()
		if fighter.technique_engine.has("A1") and enemy != null:
			var stab_range: float = 60.0
			var dist: float = absf(enemy.position.x - fighter.position.x)
			if dist <= stab_range + enemy.half_width:
				var facing_enemy: bool = (1 if enemy.position.x > fighter.position.x else -1) == fighter.facing
				if facing_enemy:
					enemy.health_current -= 8.0
					enemy.health_current = maxf(enemy.health_current, 0.0)
					emit_signal("damage_dealt", enemy.position + Vector2(0.0, -enemy.height - 20.0), 8.0, false)
					emit_signal("spawn_particles", enemy.position + Vector2(0.0, -enemy.height * 0.5), 6, Color8(255, 180, 100))
					emit_signal("show_feedback", "落葉!", 0.4)
```

- [ ] **Step 2: Add B3 dash-through detection**

In `update_player()`, after the position update (`fighter.position += fighter.velocity * dt`, line 92), add:

```gdscript
	if fighter.is_invulnerable and enemy != null and enemy.is_hit_active():
		var dist: float = absf(enemy.position.x - fighter.position.x)
		var in_attack_zone: bool = dist <= enemy.current_attack_range() + fighter.half_width
		if in_attack_zone and fighter.technique_engine != null:
			fighter.technique_engine.on_dash_through()
```

- [ ] **Step 3: Hook A4 Sparrow Wing damage bonus into resolve_hits**

In `resolve_hits()` in `WUGodot/scripts/combat_system.gd`, after the B5 damage multiplier block (added in Task 7 Step 2), add:

```gdscript
		if attacker.technique_engine != null and attacker.technique_engine.has("A4"):
			if attack_def != null and not attack_def.is_heavy and attacker.technique_engine.has_sparrow_bonus():
				hp_damage *= 1.30
				attacker.technique_engine.consume_sparrow()
				emit_signal("show_feedback", "雀翼!", 0.4)
```

- [ ] **Step 4: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/combat_system.gd
git commit -m "feat: implement A1 dash-stab and A4 sparrow-wing post-dash bonus"
```

---

### Task 9: Event Triggers (B1, B2, B3, B4, B6)

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd`
- Modify: `WUGodot/scripts/combat_scene.gd`

- [ ] **Step 1: Hook B1 Mountain's Echo into parry branch**

In `resolve_hits()` in `WUGodot/scripts/combat_system.gd`, in the parry success branch (after `defender.gain_rage(15.0)`, line 183), add:

```gdscript
			if defender.technique_engine != null and defender.technique_engine.has("B1"):
				defender.technique_engine.set_echo()
				emit_signal("show_feedback", "ECHO!", 0.5)
```

- [ ] **Step 2: Hook B1 echo consume for guaranteed posture break**

In `resolve_hits()`, after the A4 sparrow block (Task 8 Step 3), add:

```gdscript
		var echo_consumed: bool = false
		if attacker.technique_engine != null and attacker.technique_engine.consume_echo():
			posture_damage = defender.posture_current + 1.0
			echo_consumed = true
			emit_signal("show_feedback", "山谷回響!", 0.6)
```

- [ ] **Step 3: Hook B3 Flowing Water heal on hit**

In `resolve_hits()`, after the echo consume block, add:

```gdscript
		if attacker.technique_engine != null and attacker.technique_engine.consume_flowing_water():
			attacker.health_current = minf(attacker.health_current + 5.0, attacker.health_max)
			emit_signal("show_feedback", "流水!", 0.5)
```

- [ ] **Step 4: Hook B2 Breath of Returning Spring into posture break**

In `resolve_hits()`, inside the `will_posture_break` block (after the existing visual effects — after `emit_signal("show_feedback", "破", 0.9)`), add:

```gdscript
			if attacker.technique_engine != null:
				attacker.technique_engine.on_posture_break(attacker)
				if attacker.technique_engine.has("B2"):
					emit_signal("show_feedback", "回春!", 0.6)
```

- [ ] **Step 5: Hook B6 Phoenix Rising lethal save**

In `resolve_hits()`, after `defender.health_current -= hp_damage` and after the A3 bleed hook, add (before `var will_posture_break`):

```gdscript
		if defender.health_current <= 0.0 and defender.technique_engine != null:
			if defender.technique_engine.check_lethal_save(defender):
				emit_signal("camera_shake", 16.0)
				emit_signal("slow_motion", 0.4, 0.5)
				emit_signal("show_feedback", "鳳凰起!", 0.8)
				emit_signal("spawn_particles", defender.position + Vector2(0.0, -defender.height * 0.5), 24, Color8(255, 120, 40))
```

- [ ] **Step 6: Hook B4 Thousand-Mile Gaze on kill**

In `WUGodot/scripts/combat_scene.gd`, in `_process()`, modify the death detection block. Replace (lines 163-168):

```gdscript
		if _player.health_current <= 0.0:
			_is_paused_on_end = true
			_end_message = "Defeat (Enter: continue)"
		elif _enemy.health_current <= 0.0:
			_is_paused_on_end = true
			_end_message = "Boss Defeated (Enter)" if _current_node.node_type == MapNode.NodeType.BOSS else "Victory (Enter)"
```

With:

```gdscript
		if _player.health_current <= 0.0:
			_is_paused_on_end = true
			_end_message = "Defeat (Enter: continue)"
		elif _enemy.health_current <= 0.0:
			if _player.technique_engine != null:
				_player.technique_engine.on_kill(_player)
			_is_paused_on_end = true
			_end_message = "Boss Defeated (Enter)" if _current_node.node_type == MapNode.NodeType.BOSS else "Victory (Enter)"
```

- [ ] **Step 7: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add WUGodot/scripts/combat_system.gd WUGodot/scripts/combat_scene.gd
git commit -m "feat: implement B1/B2/B3/B4/B6 event trigger techniques"
```

---

### Task 10: D-Type Stance System (D1 Drunken Form, D2 Tiger Stance)

**Files:**
- Modify: `WUGodot/scripts/combat_system.gd`
- Modify: `WUGodot/tests/test_technique_engine.gd`

The stance activation/deactivation logic and attack overrides are already in `TechniqueEngine` (Task 3) and `Fighter` (Task 5). This task wires up the remaining combat-level effects: activation feedback, D1 stance-damage tracking, and D2 block reflection.

- [ ] **Step 1: Add stance activation tests**

Append to `run_all()` in `WUGodot/tests/test_technique_engine.gd`, before the return:

```gdscript
	# --- Stance tests ---
	var df: Fighter = Fighter.new()
	df.health_max = 100.0
	df.health_current = 100.0
	df.posture_max = 100.0
	df.posture_current = 100.0
	df.move_speed = 320.0
	df.posture_recovery_rate = 12.0
	df.parry_window = 0.15
	df.dash_speed = 1100.0
	df.air_dash_speed = 950.0
	df.dash_cooldown = 0.80
	df.dash_duration = 0.22
	df.dash_iframe_end = 0.18
	df.rage_max = 100.0
	df.rage_current = 0.0

	var de: Variant = TechniqueEngineScript.new()

	# Test: no D-type equipped → activate fails
	if not de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("activate_stance should fail with no D-type")

	# Test: D1 equipped but not enough rage → fails
	de.add("D1", df)
	df.rage_current = 50.0
	if not de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("activate_stance should fail without full rage")

	# Test: D1 with full rage → succeeds
	df.rage_current = 100.0
	if de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("activate_stance should succeed with full rage")

	# Test: rage drained to 0
	if absf(df.rage_current) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("rage should be 0 after stance activation (got %.1f)" % df.rage_current)

	# Test: D1 dash modifications applied
	# 0.26 = absolute elapsed end of i-frame phase (DASH_STARTUP_END 0.04 + 0.22s i-frames)
	if absf(df.dash_duration - 0.30) < 0.01 and absf(df.dash_iframe_end - 0.26) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("D1 dash_duration=%.2f (expect 0.30) iframe_end=%.2f (expect 0.26)" % [df.dash_duration, df.dash_iframe_end])

	# Test: stance already active → second activate fails
	df.rage_current = 100.0
	if not de.activate_stance(df):
		passed += 1
	else:
		failed += 1
		failures.append("should not activate stance when already active")

	# Test: deactivate restores dash params
	de.deactivate_stance(df)
	if absf(df.dash_duration - 0.22) < 0.01 and absf(df.dash_iframe_end - 0.18) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("deactivate should restore dash params (got %.2f/%.2f)" % [df.dash_duration, df.dash_iframe_end])

	# Test: D1 stance damage tracking
	df.rage_current = 100.0
	de.activate_stance(df)
	var broke: bool = de.on_stance_damage(15.0, df)
	if not broke:
		passed += 1
	else:
		failed += 1
		failures.append("15 damage should not break D1 (threshold 20)")
	broke = de.on_stance_damage(6.0, df)
	if broke and not de.is_stance_active():
		passed += 1
	else:
		failed += 1
		failures.append("21 cumulative damage should break D1")

	de.remove("D1", df)

	# Test: D2 timer deactivation
	de.add("D2", df)
	df.rage_current = 100.0
	de.activate_stance(df)
	if de.is_stance_active() and de.active_stance() == "D2":
		passed += 1
	else:
		failed += 1
		failures.append("D2 should be active after activation")
	de.update(15.1, df)
	if not de.is_stance_active():
		passed += 1
	else:
		failed += 1
		failures.append("D2 should deactivate after 15s")
	de.remove("D2", df)
```

- [ ] **Step 2: Wire stance activation feedback in update_player**

In `combat_system.gd`, replace the stance input handling (line 82-83):

```gdscript
	if bool(input_state.get("stance_pressed", false)):
		fighter.on_stance_input()
```

With:

```gdscript
	if bool(input_state.get("stance_pressed", false)):
		if fighter.on_stance_input():
			var stance_name: String = ""
			if fighter.technique_engine != null:
				match fighter.technique_engine.active_stance():
					"D1":
						stance_name = "醉拳 DRUNKEN FORM"
					"D2":
						stance_name = "虎形 TIGER STANCE"
			emit_signal("camera_shake", 10.0)
			emit_signal("slow_motion", 0.6, 0.3)
			emit_signal("show_feedback", stance_name, 0.8)
			emit_signal("spawn_particles", fighter.position, 20, Color8(255, 200, 50))
```

- [ ] **Step 3: Hook D1 stance-damage tracking into resolve_hits**

In `resolve_hits()`, after the knockback application (after `defender.velocity = Vector2(...)`, around the original line 231 area), add:

```gdscript
		if defender.technique_engine != null and defender.technique_engine.is_stance_active():
			if defender.technique_engine.on_stance_damage(hp_damage, defender):
				emit_signal("show_feedback", "STANCE BROKEN!", 0.6)
				emit_signal("camera_shake", 8.0)
```

- [ ] **Step 4: Hook D2 block reflection into blocking branch**

In `resolve_hits()`, in the blocking branch (after the A5 block, before `defender.gain_rage(6.0)`), add:

```gdscript
			if defender.technique_engine != null and defender.technique_engine.is_stance_active() and defender.technique_engine.active_stance() == "D2":
				posture_damage *= 1.5
				var base_damage: float = (attack_def.damage if attack_def != null else attacker.attack_damage) * combo_damage_bonus
				var reflect_damage: float = base_damage * 0.10
				attacker.health_current -= reflect_damage
				attacker.health_current = maxf(attacker.health_current, 0.0)
				emit_signal("damage_dealt", attacker.position + Vector2(0.0, -attacker.height - 20.0), reflect_damage, false)
```

- [ ] **Step 5: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass, including new stance tests.

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/combat_system.gd WUGodot/tests/test_technique_engine.gd
git commit -m "feat: implement D1 Drunken Form and D2 Tiger Stance combat effects"
```

---

### Task 11: Reward System Rewrite

**Files:**
- Modify: `WUGodot/scripts/reward_option.gd`
- Modify: `WUGodot/scripts/main.gd`

- [ ] **Step 1: Add technique support to RewardOption**

In `WUGodot/scripts/reward_option.gd`, add a field after `amount` (line 8):

```gdscript
var technique_id: String = ""
```

Add a `"technique"` case to `apply()` (after line 9, before the existing `match`):

Replace the `apply` method:

```gdscript
func apply(fighter: Fighter) -> void:
	if effect == "technique":
		if fighter.technique_engine != null and technique_id != "":
			fighter.technique_engine.add(technique_id, fighter)
		return
	match effect:
		"attack_damage":
			fighter.attack_damage += amount
		"posture_max":
			fighter.posture_max += amount
			fighter.posture_current += amount
		"attack_posture_damage":
			fighter.attack_posture_damage += amount
		"move_speed":
			fighter.move_speed += amount
```

Add `technique_id` to `from_dictionary`:

Replace `from_dictionary` (lines 35-41):

```gdscript
static func from_dictionary(data: Dictionary) -> RewardOption:
	var option: RewardOption = RewardOption.new()
	option.id = str(data.get("id", "reward"))
	option.label = str(data.get("label", "Reward"))
	option.effect = str(data.get("effect", ""))
	option.amount = float(data.get("amount", 0.0))
	option.technique_id = str(data.get("technique_id", ""))
	return option
```

Add the technique reward factory method at end of file:

```gdscript

static func random_technique(owned_ids: Array[String]) -> RewardOption:
	var all_techniques: Dictionary = DataManager.get_all_techniques()
	var pool: Array[Dictionary] = []
	for tech_id in all_techniques.keys():
		if not owned_ids.has(str(tech_id)):
			pool.append(all_techniques[tech_id] as Dictionary)
	if pool.is_empty():
		return random()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var option: RewardOption = RewardOption.new()
	option.id = str(pick.get("id", ""))
	option.label = "%s (%s)" % [str(pick.get("name_en", "")), str(pick.get("name_cn", ""))]
	option.effect = "technique"
	option.technique_id = option.id
	return option
```

- [ ] **Step 2: Rewrite main.gd reward state**

In `WUGodot/scripts/main.gd`, replace the two reward variables (lines 17-18):

```gdscript
var _reward1: RewardOption
var _reward2: RewardOption
```

With:

```gdscript
var _rewards: Array = []
```

- [ ] **Step 3: Update start_new_run**

In `start_new_run()`, replace (lines 40-41):

```gdscript
	_reward1 = null
	_reward2 = null
```

With:

```gdscript
	_rewards.clear()
```

- [ ] **Step 4: Rewrite _update_reward for 3 technique options**

Replace `_update_reward()` (lines 99-123):

```gdscript
func _update_reward() -> void:
	if _rewards.is_empty():
		_rewards = _generate_technique_rewards(3)

	var max_idx: int = _rewards.size() - 1
	if _input_tracker.pressed_key(KEY_A) or _input_tracker.pressed_key(KEY_LEFT):
		_reward_selection_idx = maxi(0, _reward_selection_idx - 1)
	if _input_tracker.pressed_key(KEY_D) or _input_tracker.pressed_key(KEY_RIGHT):
		_reward_selection_idx = mini(max_idx, _reward_selection_idx + 1)

	if _input_tracker.pressed_key(KEY_1) or _input_tracker.pressed_key(KEY_KP_1):
		_apply_reward_by_index(0)
		return
	if _input_tracker.pressed_key(KEY_2) or _input_tracker.pressed_key(KEY_KP_2):
		_apply_reward_by_index(1)
		return
	if _input_tracker.pressed_key(KEY_3) or _input_tracker.pressed_key(KEY_KP_3):
		if _rewards.size() > 2:
			_apply_reward_by_index(2)
			return

	var hovered_idx: int = _get_hovered_reward_index()
	if hovered_idx >= 0:
		_reward_selection_idx = hovered_idx

	if _accept_pressed():
		_apply_reward_by_index(_reward_selection_idx)
	elif hovered_idx >= 0 and _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		_apply_reward_by_index(hovered_idx)
```

- [ ] **Step 5: Add _generate_technique_rewards helper**

Add after `_update_reward()`:

```gdscript
func _generate_technique_rewards(count: int) -> Array:
	var owned_ids: Array[String] = []
	if _player.technique_engine != null:
		owned_ids = _player.technique_engine.technique_ids()
	var rewards: Array = []
	var used_ids: Array[String] = owned_ids.duplicate()
	for i in range(count):
		var reward: RewardOption = RewardOption.random_technique(used_ids)
		rewards.append(reward)
		if reward.technique_id != "":
			used_ids.append(reward.technique_id)
	return rewards
```

- [ ] **Step 6: Rewrite _apply_reward_by_index**

Replace `_apply_reward_by_index()` (lines 150-163):

```gdscript
func _apply_reward_by_index(index: int) -> void:
	if index < 0 or index >= _rewards.size():
		return
	var selected: RewardOption = _rewards[index]
	selected.apply(_player)
	_rewards.clear()
	_reward_selection_idx = 0
	_current_scene = SceneType.MAP
```

- [ ] **Step 7: Rewrite _draw_reward for 3-box layout**

Replace `_draw_reward()` (lines 231-249):

```gdscript
func _draw_reward() -> void:
	_draw_background()

	var panel: Rect2 = _get_reward_panel_rect()
	_draw_panel(panel)
	_draw_text("Choose Technique", panel.position.x + 26.0, panel.position.y + 40.0, Color(0.95, 0.95, 0.98, 0.95), 24)
	_draw_text("Arrows, 1/2/3, Enter or click", panel.position.x + 26.0, panel.position.y + 68.0, Color(0.72, 0.74, 0.78, 0.85), 15)

	for i in range(_rewards.size()):
		var box: Rect2 = _get_reward_box_rect(i)
		var reward_label: String = "..."
		var reward_desc: String = ""
		if i < _rewards.size():
			reward_label = _rewards[i].label
			if _rewards[i].technique_id != "":
				var tech_data: Dictionary = DataManager.get_technique(_rewards[i].technique_id)
				reward_desc = str(tech_data.get("description", ""))
		_draw_reward_option_with_desc(box, reward_label, reward_desc, _reward_selection_idx == i)
```

- [ ] **Step 8: Update layout helpers**

Replace `_get_reward_panel_rect()` (lines 325-328):

```gdscript
func _get_reward_panel_rect() -> Rect2:
	var width: float = minf(1200.0, float(GameConstants.VIEW_WIDTH) - 200.0)
	var height: float = 260.0
	return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - height) * 0.5 - 20.0, width, height)
```

Replace `_get_reward_box_rect()` (lines 330-337):

```gdscript
func _get_reward_box_rect(index: int) -> Rect2:
	var panel: Rect2 = _get_reward_panel_rect()
	var count: int = maxi(_rewards.size(), 1)
	var gap: float = 20.0
	var box_width: float = (panel.size.x - gap * float(count + 1)) / float(count)
	var box_height: float = 120.0
	var x: float = panel.position.x + gap + float(index) * (box_width + gap)
	var y: float = panel.position.y + 96.0
	return Rect2(x, y, box_width, box_height)
```

Replace `_get_hovered_reward_index()` (lines 339-347):

```gdscript
func _get_hovered_reward_index() -> int:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	for i in range(_rewards.size()):
		var box: Rect2 = _get_reward_box_rect(i)
		if box.has_point(mouse_pos):
			return i
	return -1
```

Add the new draw helper after `_draw_reward_option`:

```gdscript
func _draw_reward_option_with_desc(rect: Rect2, label: String, description: String, selected: bool) -> void:
	var border: Color = Color(1.0, 1.0, 1.0, 0.12)
	if selected:
		border = Color(0.92, 0.93, 0.98, 0.92)
	draw_rect(rect, Color(0.09, 0.10, 0.12, 0.85), true)
	draw_rect(rect, border, false, 2.0)
	_draw_text(label, rect.position.x + 18.0, rect.position.y + 36.0, Color(0.90, 0.92, 0.96, 0.95), 18)
	if description != "":
		_draw_text(description, rect.position.x + 18.0, rect.position.y + 62.0, Color(0.68, 0.70, 0.74, 0.85), 13)
	if selected:
		_draw_menu_cursor(Vector2(rect.position.x - 16.0, rect.position.y + 36.0))
```

- [ ] **Step 9: Add KEY_3 to main.gd _sync_input_tracker**

In `WUGodot/scripts/main.gd`, in `_sync_input_tracker()`, add to the keys array (after `KEY_KP_2`):

```gdscript
		KEY_3,
		KEY_KP_3,
```

- [ ] **Step 10: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass. Reward UI is verified via playtest.

- [ ] **Step 11: Commit**

```bash
git add WUGodot/scripts/reward_option.gd WUGodot/scripts/main.gd
git commit -m "feat: rewrite reward screen with 3 technique options and one-copy-only filter"
```

---

### Task 12: HUD Technique Display + Test Harness + Playtest Checklist

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd`

- [ ] **Step 1: Add technique list to combat HUD**

In `WUGodot/scripts/combat_scene.gd`, in `_draw_hud()`, after the controls help text (after line 354), add:

```gdscript
	if _player != null and _player.technique_engine != null:
		var tech_ids: Array[String] = _player.technique_engine.technique_ids()
		if not tech_ids.is_empty():
			var tech_y: float = 148.0
			_draw_text("Techniques:", 36.0, tech_y, Color8(200, 195, 180), 14)
			tech_y += 18.0
			for tech_id in tech_ids:
				var tech_data: Dictionary = DataManager.get_technique(tech_id)
				var display: String = "%s %s" % [str(tech_data.get("name_cn", tech_id)), str(tech_data.get("name_en", ""))]
				var tech_color: Color = Color8(170, 175, 165)
				if tech_id.begins_with("D"):
					tech_color = Color8(255, 200, 50)
				elif tech_id.begins_with("B"):
					tech_color = Color8(140, 200, 255)
				_draw_text(display, 36.0, tech_y, tech_color, 13)
				tech_y += 16.0

		if _player.technique_engine.is_stance_active():
			var stance_id: String = _player.technique_engine.active_stance()
			var stance_label: String = "醉拳" if stance_id == "D1" else "虎形"
			var pulse: float = sin(_player.animation_timer * 6.0) * 0.3 + 0.7
			_draw_text("STANCE: %s" % stance_label, 36.0, 104.0, Color(1.0, 0.85, 0.3, pulse), 16)
```

- [ ] **Step 2: Add bleed visual indicator**

In `_draw_fighter()` in `WUGodot/scripts/combat_scene.gd`, after the stun indicator block (after line 340), add:

```gdscript
	if fighter.bleed_timer > 0.0:
		var bleed_pulse: float = sin(fighter.animation_timer * 8.0) * 0.4 + 0.6
		var bleed_rect: Rect2 = Rect2(body_rect.position.x, body_rect.end.y + 4.0, body_rect.size.x, 4.0)
		draw_rect(bleed_rect, Color8(180, 30, 30, int(160.0 * bleed_pulse)), true)
```

- [ ] **Step 3: Run full test suite**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass (25 original + ~35 new = ~60 total).

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "feat: add technique HUD display, stance indicator, and bleed visual"
```

- [ ] **Step 5: Manual playtest checklist**

Run the game: `HOME=/tmp/godot-home godot --path WUGodot`

Verify each item (pass/fail):

**Stat-mod techniques:**
- [ ] A6 Heart of Bamboo: posture bar is visibly longer in HUD
- [ ] A7 Crane Step: player moves noticeably faster
- [ ] A12 Inkstone Discipline: health bar is visibly longer

**Combat modifiers:**
- [ ] A2 Iron Palm: occasionally see "STAGGER!" feedback when light attacks hit
- [ ] A3 Widow's Kiss: heavy attack shows bleed indicator on enemy, enemy takes tick damage
- [ ] A5 Stone Posture: blocking reduces more damage (compare HP loss with/without)
- [ ] A10 Twin Dragons: heavy attacks show second damage number
- [ ] B5 Scar of the Past: damage increases when below 30% HP

**Dash techniques:**
- [ ] A1 Descending Leaf: see "落葉!" and damage number after dash ends near enemy
- [ ] A4 Sparrow Wing: see "雀翼!" when light attacking shortly after dash

**Event triggers:**
- [ ] B1 Mountain's Echo: parry shows "ECHO!", next attack shows "山谷回響!" and breaks posture
- [ ] B2 Breath of Returning Spring: posture break heals player (HP bar increases)
- [ ] B3 Flowing Water: dashing through an enemy's active attack (close range) arms a heal; next hit heals player
- [ ] B4 Thousand-Mile Gaze: after killing an enemy, player moves noticeably faster in the opening seconds of the next fight (speed bonus visible for ~3s)
- [ ] B6 Phoenix Rising: lethal damage shows "鳳凰起!" and player survives at 20% HP; second lethal kills normally

**D-type stances:**
- [ ] Press L without D-type: nothing happens
- [ ] Pick up D1 or D2, fill rage to 100, press L: stance activates with feedback
- [ ] D1: dash feels longer and more evasive, light attacks ignore blocks ("SLIPPED!"), heavy hits harder
- [ ] D2: light attacks feel faster, blocking reflects damage, heavy has longer range
- [ ] D1 breaks after ~20 HP damage taken
- [ ] D2 deactivates after ~15 seconds

**Reward screen:**
- [ ] After combat victory, 3 technique options appear (not stat bumps)
- [ ] Technique names show Chinese + English
- [ ] Descriptions show below names
- [ ] Can select via 1/2/3 keys, arrows+enter, or mouse click
- [ ] Picking a technique adds it to the HUD technique list
- [ ] Already-owned techniques do not appear in future rewards

**Persistence:**
- [ ] Techniques persist across fights within a run
- [ ] New run starts with empty technique loadout
- [ ] Phoenix Rising one-time use persists across fights

---

## Self-Review

**1. Spec coverage:** Every technique from Section C's "Full MVP technique pool" table (A1–A12, B1–B6, D1–D2) has a task and step implementing it. Rage activation (Section C "Rage — role in MVP") is covered in Task 10 (stance activation). One-copy-only duplicate policy is covered in Task 3 (engine `add()` with `has()` check) and Task 11 (reward filtering). Acquisition flow table is partially covered (combat reward = Task 11; shop/event/master sources are Plan 4 scope). The spec's "No C-type in MVP" is respected — no C-type techniques appear.

**2. Placeholder scan:** No TBD/TODO items. Every step has code blocks or commands with expected output.

**3. Type consistency:**
- `technique_engine` is `Variant` on Fighter (avoids circular reference), created via `TechniqueEngineScript.new()` in EnemyFactory.
- `_apply_on_add`/`_unapply` match statements cover the same ids.
- `activate_stance`/`deactivate_stance` use matching field names (`_pre_stance_dash_duration`, `_pre_stance_dash_iframe_end`).
- `resolve_hits` checks use `attacker.technique_engine` / `defender.technique_engine` consistently with null guards.
- `RewardOption.technique_id` is set in `random_technique()` and read in `apply()`.
- `get_light_override()`/`get_heavy_override()` return the same types that `_start_attack_with()` expects (`Variant` wrapping `AttackDefinition`).

**4. Scope vs. Plan 1 boundary:** Plan 1's `on_stance_input()` scaffold (print debug) is replaced in Task 5 Step 7 with delegation to `technique_engine.activate_stance()`. No Plan 1 code is deleted — only the debug print in `on_stance_input` is replaced.
