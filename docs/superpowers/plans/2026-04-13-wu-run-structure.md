# WU Run Structure Expansion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the run structure from a simple 7-node map with 5 node types to a full ~15-node procedural map with 8 node types (Duel, Elite Duel, Ambush, Master, Event, Shop, Rest, Boss), data-driven events, a shop system with gold economy, and a procedural map generator with forced master convergence and guaranteed rest reachability.

**Architecture:** Three new scene types (EVENT, SHOP, REST) join the existing MAP/COMBAT/REWARD/GAME_OVER in `main.gd`. Each new scene has its own update/draw methods. Events are JSON-driven data loaded by `DataManager`; an `EventRunner` class tracks the current event, choices made, and outcomes. Shop inventory is generated per-node from the technique pool plus fixed consumable slots. Gold is a new field on `Fighter`, awarded after combat victories and spent in shops. The map generator is rewritten to produce ~15 nodes across 7 tiers with placement guarantees (exactly 1 master on a convergence column, at least 1 rest reachable from every path, boss at the end). Ambush nodes trigger 3 sequential single-enemy fights using the existing `CombatScene` and `setup_combat` path.

**Tech Stack:** Godot 4.6.2 (GDScript), RefCounted data classes, JSON data under `WUGodot/data/Events/`. Headless test harness (`godot --headless --script res://tests/run_tests.gd`).

**Spec reference:** `docs/superpowers/specs/2026-04-10-wu-mvp-design.md` — Section D (node types, events, shop inventory) and Section E item 1 (procedural map generation).

**Plan sequence (5 plans total for the WU MVP):**

1. **Plan 1 — Combat Foundation Refactor.** Implemented.
2. **Plan 2 — Technique System + 20-Technique MVP Pool.** Implemented.
3. **Plan 3 — Enemy Archetypes + Iron Bear Boss.** Implemented.
4. **Plan 4 (this document) — Run Structure Expansion.** 8 node types, map-gen, events, shop, gold, rest, master, ambush.
5. **Plan 5 — Run Flow & Chapter 1 Polish.** Main menu, Victory scroll, Defeat screen, SFX/music, balance pass.

Each plan produces working, testable software.

---

## File Structure

**New files:**

- `WUGodot/scripts/event_runner.gd` — Loads an event definition, presents choices, computes outcomes (gold/HP/technique changes). Pure data logic — no drawing. Exposes `load_event(data)`, `get_text()`, `get_choices()`, `choose(index, fighter)` returning an outcome dictionary. ~80 lines.
- `WUGodot/scripts/shop_generator.gd` — Generates a shop inventory for a node: 3 random techniques (priced by rarity), 1 HP potion, 1 posture potion, 1 forget-technique slot. Returns an array of `ShopItem` dictionaries. ~60 lines.
- `WUGodot/data/Events/Events.json` — All 6 MVP event definitions as JSON array.
- `WUGodot/tests/test_event_runner.gd` — Tests for event loading, choice outcomes, gold/HP/technique effects.
- `WUGodot/tests/test_map_generator.gd` — Tests for map structure guarantees: node count, master convergence, rest reachability, boss at end.

**Modified files:**

- `WUGodot/scripts/map_node.gd` — Add 3 new node types: AMBUSH, MASTER, SHOP, REST (total 8). Add `ambush_remaining: int = 0` for gauntlet tracking.
- `WUGodot/scripts/run_state.gd` — Complete rewrite of `create_procedural_run()` to produce ~15 nodes across 7 tiers with placement guarantees (master convergence on tier 3, rest convergence on tier 5).
- `WUGodot/scripts/fighter.gd` — Add `gold: int = 0` field.
- `WUGodot/scripts/main.gd` — Add 3 new scene types (EVENT, SHOP, REST). Add update/draw methods for each. Rewrite `_travel_to_node()` to route to the correct scene type. Rewrite `_on_combat_end()` to handle ambush gauntlet continuation and gold rewards. Add `_get_node_color()` and `_get_node_type_label()` entries for new node types.
- `WUGodot/scripts/combat_scene.gd` — Emit gold reward amount in `combat_end` signal (add `gold_reward` parameter).
- `WUGodot/scripts/data_manager.gd` — Add `_events: Array[Dictionary]`, `_load_events()`, `get_events()`, `get_random_event()`. Call `_load_events()` from `initialize()`.
- `WUGodot/scripts/enemy_factory.gd` — Add `MapNode.NodeType.AMBUSH` case to `_pick_archetype_for_node()` that selects from easy+medium pool (same as BATTLE). Remove stale `create_ambush_enemies` from file structure — ambush uses sequential single-enemy fights via the existing `setup_combat` path.
- `WUGodot/tests/run_tests.gd` — Add `test_event_runner.gd` and `test_map_generator.gd` to `_TEST_MODULES`.

---

## Testing Strategy

**Headless tests:**

- `test_event_runner.gd` — Event loading from dictionary, choice count, outcome effects (gold change, HP change, technique grant), edge cases (insufficient gold, event with combat trigger).
- `test_map_generator.gd` — Generated map has 13-17 nodes, exactly 1 master node, at least 1 rest node, boss at final tier, master reachable from every starting path, all nodes reachable from start.

**Manual playtest checklist** (Task 11):

- Full run through all 8 node types.
- Gold displayed in HUD, increases after combat.
- Shop lets you buy techniques, potions, forget-technique.
- Events show text, choices, and outcomes.
- Rest heals or removes technique.
- Master offers 3 rare techniques for free.
- Ambush spawns 2-3 sequential enemies.
- Map shows ~15 nodes with correct colors/labels.

---

### Task 1: MapNode — Expand to 8 Node Types

**Files:**
- Modify: `WUGodot/scripts/map_node.gd`

- [ ] **Step 1: Add new node types and ambush tracking**

Replace the entire content of `WUGodot/scripts/map_node.gd`:

```gdscript
class_name MapNode
extends RefCounted

enum NodeType {
	BATTLE,
	ELITE,
	AMBUSH,
	MASTER,
	EVENT,
	SHOP,
	REST,
	BOSS,
}

var id: int = 0
var tier: int = 0
var node_type: int = NodeType.BATTLE
var cleared: bool = false
var next_ids: Array[int] = []
var ambush_remaining: int = 0
var event_id: String = ""

func _init(node_id: int = 0, node_tier: int = 0, type_value: int = NodeType.BATTLE, next_list: Array[int] = []) -> void:
	id = node_id
	tier = node_tier
	node_type = type_value
	cleared = false
	next_ids = next_list.duplicate()
	if node_type == NodeType.AMBUSH:
		ambush_remaining = 3
```

- [ ] **Step 2: Commit**

```bash
git add WUGodot/scripts/map_node.gd
git commit -m "feat: expand MapNode to 8 node types with ambush tracking"
```

---

### Task 2: Gold Field on Fighter

**Files:**
- Modify: `WUGodot/scripts/fighter.gd`

- [ ] **Step 1: Add gold field**

In `WUGodot/scripts/fighter.gd`, after `archetype_id` (line 99):

```gdscript
var gold: int = 0
```

- [ ] **Step 2: Commit**

```bash
git add WUGodot/scripts/fighter.gd
git commit -m "feat: add gold field to Fighter"
```

---

### Task 3: Event Data Pipeline

**Files:**
- Create: `WUGodot/data/Events/Events.json`
- Modify: `WUGodot/scripts/data_manager.gd`

- [ ] **Step 1: Create Events.json**

Create `WUGodot/data/Events/Events.json`:

```json
{
  "events": [
    {
      "id": "roadside_villager",
      "title": "Roadside Villager",
      "title_cn": "路邊村民",
      "text": "A villager waves you down from the roadside. 'Please, traveler — bandits took my cart just ahead. Help me, and I'll share what they stole.'",
      "choices": [
        {"label": "Help the villager", "outcome": "help"},
        {"label": "Ignore and continue", "outcome": "ignore"}
      ],
      "outcomes": {
        "help": {"gold": 30, "hp": -10, "message": "You fought off the bandits but took a few hits. The villager shares 30 gold."},
        "ignore": {"message": "You walk on. The villager's cries fade behind you."}
      }
    },
    {
      "id": "travelling_merchant",
      "title": "Travelling Merchant",
      "title_cn": "行商",
      "text": "A merchant with a heavy pack nods at you. 'I carry rare goods — techniques from distant schools. Care to trade?'",
      "choices": [
        {"label": "Trade (opens shop)", "outcome": "trade"},
        {"label": "Leave", "outcome": "leave"}
      ],
      "outcomes": {
        "trade": {"open_shop": true, "shop_rarity_boost": true, "message": "The merchant spreads out wares of unusual quality."},
        "leave": {"message": "You nod politely and move on."}
      }
    },
    {
      "id": "shrine_offering",
      "title": "Shrine Offering",
      "title_cn": "祠堂供品",
      "text": "A weathered roadside shrine, incense still burning. Something about this place feels charged with martial energy.",
      "choices": [
        {"label": "Offer gold (30g)", "outcome": "gold"},
        {"label": "Offer blood (10 HP)", "outcome": "blood"},
        {"label": "Leave", "outcome": "leave"}
      ],
      "outcomes": {
        "gold": {"gold": -30, "grant_technique": "random", "message": "The shrine glows. A technique crystallizes in your mind."},
        "blood": {"hp": -10, "grant_technique": "random", "message": "Blood drips onto the stone. Knowledge floods your thoughts."},
        "leave": {"message": "You bow respectfully and move on."}
      }
    },
    {
      "id": "drunken_master",
      "title": "Drunken Master",
      "title_cn": "醉師",
      "text": "An old man sits on a rock, sipping from a gourd. 'Think you're fast? Press J three times in rhythm. Get it right and I'll teach you something.'",
      "choices": [
        {"label": "Accept the test", "outcome": "test"},
        {"label": "Decline", "outcome": "decline"}
      ],
      "outcomes": {
        "test": {"timing_test": true, "pass": {"grant_technique": "random_B", "message": "The old man grins. 'Not bad.' He shares a secret technique."}, "fail": {"hp": -15, "message": "The old man smacks you with his gourd. 'Too slow!'"}},
        "decline": {"message": "The old man shrugs and takes another sip."}
      }
    },
    {
      "id": "bandit_camp",
      "title": "Bandit Camp",
      "title_cn": "匪營",
      "text": "Smoke rises from behind the trees. A bandit camp, poorly guarded. You could sneak past or fight for their loot.",
      "choices": [
        {"label": "Sneak past", "outcome": "sneak"},
        {"label": "Infiltrate (triggers fight)", "outcome": "infiltrate"}
      ],
      "outcomes": {
        "sneak": {"message": "You slip past without a sound."},
        "infiltrate": {"trigger_combat": true, "combat_gold_multiplier": 2, "message": "You charge in! The bandits scramble for weapons."}
      }
    },
    {
      "id": "abandoned_scroll",
      "title": "Abandoned Scroll",
      "title_cn": "遺卷",
      "text": "A scroll lies half-buried in the dirt, its seal broken. The calligraphy inside describes a martial technique.",
      "choices": [
        {"label": "Read the scroll", "outcome": "read"}
      ],
      "outcomes": {
        "read": {"grant_technique": "random_A", "message": "You study the scroll's teachings. A new technique takes root."}
      }
    }
  ]
}
```

- [ ] **Step 2: Add event loading to DataManager**

In `WUGodot/scripts/data_manager.gd`, add to the static vars (after line 8):

```gdscript
static var _events: Array[Dictionary] = []
```

In `initialize()` (after `_load_techniques()` on line 12):

```gdscript
	_load_events()
```

In `reload_data()` (after `_techniques.clear()` on line 24):

```gdscript
	_events.clear()
```

Add after `get_enemy_archetypes_for_difficulty()` (after line 70):

```gdscript
static func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_data in _events:
		result.append(event_data.duplicate(true))
	return result

static func get_random_event(rng: RandomNumberGenerator = null) -> Dictionary:
	if _events.is_empty():
		return {}
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	return _events[r.randi_range(0, _events.size() - 1)].duplicate(true)
```

Add `_load_events()` after `_load_techniques()`:

```gdscript
static func _load_events() -> void:
	var dir: DirAccess = DirAccess.open("res://data/Events")
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
		var root: Dictionary = _load_json_file("res://data/Events/%s" % file_name)
		var raw_events: Array = []
		if typeof(root.get("events", [])) == TYPE_ARRAY:
			raw_events = root.get("events", []) as Array
		for entry in raw_events:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var event_id: String = str((entry as Dictionary).get("id", ""))
			if event_id.is_empty():
				continue
			_events.append((entry as Dictionary).duplicate(true))
	dir.list_dir_end()
```

- [ ] **Step 3: Commit**

```bash
git add WUGodot/data/Events/Events.json WUGodot/scripts/data_manager.gd
git commit -m "feat: add 6 event definitions and DataManager event loading"
```

---

### Task 4: EventRunner — Choice and Outcome Logic

**Files:**
- Create: `WUGodot/scripts/event_runner.gd`
- Create: `WUGodot/tests/test_event_runner.gd`

- [ ] **Step 1: Write tests**

Create `WUGodot/tests/test_event_runner.gd`:

```gdscript
extends RefCounted

const EventRunnerScript = preload("res://scripts/event_runner.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const DataManagerScript = preload("res://scripts/data_manager.gd")

func _make_fighter() -> Variant:
	var f: Variant = FighterScript.new()
	f.health_max = 100.0
	f.health_current = 100.0
	f.gold = 50
	f.technique_engine = TechniqueEngineScript.new()
	return f

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManagerScript.reload_data()

	# Test 1: load event from dictionary
	var event_data: Dictionary = {
		"id": "test_event",
		"title": "Test Event",
		"text": "A test event.",
		"choices": [
			{"label": "Choice A", "outcome": "a"},
			{"label": "Choice B", "outcome": "b"},
		],
		"outcomes": {
			"a": {"gold": 10, "hp": -5, "message": "You chose A."},
			"b": {"message": "You chose B."},
		},
	}
	var runner: Variant = EventRunnerScript.new()
	runner.load_event(event_data)
	if runner.get_title() == "Test Event":
		passed += 1
	else:
		failed += 1
		failures.append("title should be 'Test Event' (got '%s')" % runner.get_title())

	# Test 2: choices count
	if runner.get_choices().size() == 2:
		passed += 1
	else:
		failed += 1
		failures.append("should have 2 choices (got %d)" % runner.get_choices().size())

	# Test 3: choose returns outcome with gold and hp effects
	var fighter: Variant = _make_fighter()
	var result: Dictionary = runner.choose(0, fighter)
	if fighter.gold == 60 and absf(fighter.health_current - 95.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("choice A: gold=%d (expect 60) hp=%.1f (expect 95)" % [fighter.gold, fighter.health_current])

	# Test 4: message in result
	if str(result.get("message", "")) == "You chose A.":
		passed += 1
	else:
		failed += 1
		failures.append("result message should be 'You chose A.'")

	# Test 5: choosing B has no gold/hp effect
	fighter = _make_fighter()
	runner.load_event(event_data)
	result = runner.choose(1, fighter)
	if fighter.gold == 50 and absf(fighter.health_current - 100.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("choice B should have no gold/hp effect")

	# Test 6: technique grant
	var tech_event: Dictionary = {
		"id": "tech_test",
		"title": "Tech Test",
		"text": "Test.",
		"choices": [{"label": "Go", "outcome": "go"}],
		"outcomes": {"go": {"grant_technique": "random_A", "message": "Got tech."}},
	}
	fighter = _make_fighter()
	runner.load_event(tech_event)
	result = runner.choose(0, fighter)
	if fighter.technique_engine.technique_ids().size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("technique grant should add 1 technique (got %d)" % fighter.technique_engine.technique_ids().size())

	# Test 7: insufficient gold prevents negative-gold outcome
	var expensive_event: Dictionary = {
		"id": "expensive",
		"title": "Expensive",
		"text": "Test.",
		"choices": [{"label": "Pay", "outcome": "pay"}],
		"outcomes": {"pay": {"gold": -100, "grant_technique": "random", "message": "Paid."}},
	}
	fighter = _make_fighter()
	fighter.gold = 20
	runner.load_event(expensive_event)
	result = runner.choose(0, fighter)
	if fighter.gold == 20:
		passed += 1
	else:
		failed += 1
		failures.append("should not deduct gold when insufficient (got %d)" % fighter.gold)

	# Test 8: DataManager loads events
	var events: Array[Dictionary] = DataManagerScript.get_events()
	if events.size() == 6:
		passed += 1
	else:
		failed += 1
		failures.append("DataManager should load 6 events (got %d)" % events.size())

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Implement EventRunner**

Create `WUGodot/scripts/event_runner.gd`:

```gdscript
class_name EventRunner
extends RefCounted

var _event_data: Dictionary = {}
var _resolved: bool = false

func load_event(data: Dictionary) -> void:
	_event_data = data.duplicate(true)
	_resolved = false

func get_title() -> String:
	return str(_event_data.get("title", ""))

func get_title_cn() -> String:
	return str(_event_data.get("title_cn", ""))

func get_text() -> String:
	return str(_event_data.get("text", ""))

func get_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = _event_data.get("choices", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in (raw as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry as Dictionary)
	return result

func choose(index: int, fighter: Fighter) -> Dictionary:
	var choices: Array[Dictionary] = get_choices()
	if index < 0 or index >= choices.size():
		return {"message": "Invalid choice."}

	var outcome_key: String = str(choices[index].get("outcome", ""))
	var outcomes: Dictionary = _event_data.get("outcomes", {}) as Dictionary
	var outcome: Dictionary = outcomes.get(outcome_key, {}) as Dictionary

	_resolved = true
	return _apply_outcome(outcome, fighter)

func _apply_outcome(outcome: Dictionary, fighter: Fighter) -> Dictionary:
	var result: Dictionary = {}
	result["message"] = str(outcome.get("message", ""))

	# Gold
	var gold_change: int = int(outcome.get("gold", 0))
	if gold_change < 0 and fighter.gold < absi(gold_change):
		result["message"] = "Not enough gold."
		result["blocked"] = true
		return result
	fighter.gold += gold_change

	# HP
	var hp_change: float = float(outcome.get("hp", 0.0))
	if hp_change != 0.0:
		fighter.health_current = clampf(fighter.health_current + hp_change, 1.0, fighter.health_max)

	# Technique grant
	var grant: String = str(outcome.get("grant_technique", ""))
	if not grant.is_empty() and fighter.technique_engine != null:
		var tech_id: String = _resolve_technique_grant(grant, fighter)
		if not tech_id.is_empty():
			fighter.technique_engine.add(tech_id, fighter)
			result["granted_technique"] = tech_id

	# Special flags
	if outcome.has("open_shop"):
		result["open_shop"] = true
		result["shop_rarity_boost"] = bool(outcome.get("shop_rarity_boost", false))
	if outcome.has("trigger_combat"):
		result["trigger_combat"] = true
		result["combat_gold_multiplier"] = int(outcome.get("combat_gold_multiplier", 1))
	if outcome.has("timing_test"):
		result["timing_test"] = true
		result["pass_outcome"] = outcome.get("pass", {})
		result["fail_outcome"] = outcome.get("fail", {})

	return result

func apply_timing_result(passed_test: bool, fighter: Fighter) -> Dictionary:
	var choices: Array[Dictionary] = get_choices()
	var outcomes: Dictionary = _event_data.get("outcomes", {}) as Dictionary
	# Find the timing test outcome
	for choice in choices:
		var outcome_key: String = str(choice.get("outcome", ""))
		var outcome: Dictionary = outcomes.get(outcome_key, {}) as Dictionary
		if outcome.has("timing_test"):
			var sub_outcome: Dictionary = outcome.get("pass", {}) as Dictionary if passed_test else outcome.get("fail", {}) as Dictionary
			return _apply_outcome(sub_outcome, fighter)
	return {"message": "Test complete."}

func _resolve_technique_grant(grant_type: String, fighter: Fighter) -> String:
	var all_tech: Dictionary = DataManager.get_all_techniques()
	var owned: Array[String] = fighter.technique_engine.technique_ids()
	var pool: Array[String] = []

	for tech_id in all_tech.keys():
		if owned.has(str(tech_id)):
			continue
		var tech: Dictionary = all_tech[tech_id] as Dictionary
		match grant_type:
			"random_A":
				if str(tech.get("type", "")) == "A":
					pool.append(str(tech_id))
			"random_B":
				if str(tech.get("type", "")) == "B":
					pool.append(str(tech_id))
			_:
				pool.append(str(tech_id))

	if pool.is_empty():
		return ""
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return pool[rng.randi_range(0, pool.size() - 1)]
```

- [ ] **Step 3: Commit**

```bash
git add WUGodot/scripts/event_runner.gd WUGodot/tests/test_event_runner.gd
git commit -m "feat: add EventRunner with choice/outcome logic and tests"
```

---

### Task 5: ShopGenerator — Inventory Generation

**Files:**
- Create: `WUGodot/scripts/shop_generator.gd`

- [ ] **Step 1: Implement ShopGenerator**

Create `WUGodot/scripts/shop_generator.gd`:

```gdscript
class_name ShopGenerator
extends RefCounted

static func generate_shop(owned_ids: Array[String], rarity_boost: bool = false) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var items: Array[Dictionary] = []
	var used_ids: Array[String] = owned_ids.duplicate()

	# 3 technique slots
	var all_tech: Dictionary = DataManager.get_all_techniques()
	for i in range(3):
		var pool: Array[Dictionary] = []
		for tech_id in all_tech.keys():
			if used_ids.has(str(tech_id)):
				continue
			var tech: Dictionary = all_tech[tech_id] as Dictionary
			pool.append(tech)
		if pool.is_empty():
			break
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var rarity: int = int(pick.get("rarity", 1))
		var base_price: int = 20 + (rarity - 1) * 15
		if rarity_boost:
			base_price = int(float(base_price) * 0.8)
		items.append({
			"type": "technique",
			"technique_id": str(pick.get("id", "")),
			"label": "%s (%s)" % [str(pick.get("name_en", "")), str(pick.get("name_cn", ""))],
			"description": str(pick.get("description", "")),
			"price": base_price,
		})
		used_ids.append(str(pick.get("id", "")))

	# HP potion
	items.append({
		"type": "hp_potion",
		"label": "HP Potion",
		"description": "Heal 30% max HP.",
		"price": 20,
	})

	# Posture potion
	items.append({
		"type": "posture_potion",
		"label": "Posture Potion",
		"description": "Restore 50% max posture.",
		"price": 15,
	})

	# Forget technique
	items.append({
		"type": "forget_technique",
		"label": "Forget Technique",
		"description": "Remove one technique from your loadout.",
		"price": 25,
	})

	return items

static func buy_item(item: Dictionary, fighter: Fighter) -> Dictionary:
	var price: int = int(item.get("price", 0))
	if fighter.gold < price:
		return {"success": false, "message": "Not enough gold."}

	fighter.gold -= price
	var item_type: String = str(item.get("type", ""))

	match item_type:
		"technique":
			var tech_id: String = str(item.get("technique_id", ""))
			if fighter.technique_engine != null and not tech_id.is_empty():
				fighter.technique_engine.add(tech_id, fighter)
			return {"success": true, "message": "Learned %s." % str(item.get("label", "technique"))}
		"hp_potion":
			fighter.health_current = minf(fighter.health_current + fighter.health_max * 0.3, fighter.health_max)
			return {"success": true, "message": "Healed 30% HP."}
		"posture_potion":
			fighter.posture_current = minf(fighter.posture_current + fighter.posture_max * 0.5, fighter.posture_max)
			return {"success": true, "message": "Restored 50% posture."}
		"forget_technique":
			return {"success": true, "message": "Choose a technique to forget.", "open_forget": true}

	return {"success": false, "message": "Unknown item."}
```

- [ ] **Step 2: Commit**

```bash
git add WUGodot/scripts/shop_generator.gd
git commit -m "feat: add ShopGenerator for shop inventory and purchasing"
```

---

### Task 6: Procedural Map Generator Rewrite

**Files:**
- Modify: `WUGodot/scripts/run_state.gd`
- Create: `WUGodot/tests/test_map_generator.gd`

- [ ] **Step 1: Write map generator tests**

Create `WUGodot/tests/test_map_generator.gd`:

```gdscript
extends RefCounted

const RunStateScript = preload("res://scripts/run_state.gd")
const MapNodeScript = preload("res://scripts/map_node.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	# Generate 5 maps to test structural guarantees
	for seed_val in range(5):
		var run: Variant = RunStateScript.create_procedural_run(seed_val * 1000 + 42)

		# Test: node count in range 13-17
		if run.nodes.size() >= 13 and run.nodes.size() <= 17:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: node count %d not in [13,17]" % [seed_val, run.nodes.size()])

		# Test: exactly 1 master node
		var master_count: int = 0
		for node in run.nodes:
			if node.node_type == MapNodeScript.NodeType.MASTER:
				master_count += 1
		if master_count == 1:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: master_count=%d (expect 1)" % [seed_val, master_count])

		# Test: rest node on convergence tier (reachable from every path)
		var rest_count: int = 0
		var rest_is_convergence: bool = false
		for node in run.nodes:
			if node.node_type == MapNodeScript.NodeType.REST:
				rest_count += 1
				# Convergence = single node in its tier
				if run.count_in_tier(node.tier) == 1:
					rest_is_convergence = true
		if rest_count >= 1 and rest_is_convergence:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: rest must be on a convergence tier (count=%d, convergence=%s)" % [seed_val, rest_count, str(rest_is_convergence)])

		# Test: exactly 1 boss at final tier
		var boss_count: int = 0
		for node in run.nodes:
			if node.node_type == MapNodeScript.NodeType.BOSS:
				boss_count += 1
				if node.tier != run.max_tier:
					failed += 1
					failures.append("seed %d: boss not at final tier" % seed_val)
		if boss_count == 1:
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: boss_count=%d (expect 1)" % [seed_val, boss_count])

		# Test: all nodes reachable from start
		var reachable: Dictionary = {}
		var queue: Array[int] = [run.nodes[0].id]
		while not queue.is_empty():
			var current_id: int = queue.pop_front()
			if reachable.has(current_id):
				continue
			reachable[current_id] = true
			var current_node: Variant = run.get_node(current_id)
			if current_node != null:
				for next_id in current_node.next_ids:
					if not reachable.has(next_id):
						queue.append(next_id)
		if reachable.size() == run.nodes.size():
			passed += 1
		else:
			failed += 1
			failures.append("seed %d: only %d/%d nodes reachable" % [seed_val, reachable.size(), run.nodes.size()])

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Rewrite RunState.create_procedural_run**

Replace the entire content of `WUGodot/scripts/run_state.gd`:

```gdscript
class_name RunState
extends RefCounted

var nodes: Array[MapNode] = []
var current_node_id: int = 0
var max_tier: int = 0

static func create_simple_three_tier() -> RunState:
	return create_procedural_run()

static func create_procedural_run(seed_value: int = -1) -> RunState:
	var run: RunState = RunState.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	# 7 tiers: start(0), 5 middle(1-5), boss(6)
	var tier_count: int = 7
	var next_id: int = 0
	var tier_nodes: Array = []

	# Tier 0: single start node (event)
	var start: MapNode = MapNode.new(next_id, 0, MapNode.NodeType.EVENT, [])
	run.nodes.append(start)
	tier_nodes.append([start])
	next_id += 1

	# Middle tiers 1-5
	# Tier 3: single MASTER convergence node (all paths pass through)
	# Tier 5: single REST convergence node (all paths pass through)
	# Tiers 1, 2, 4: variable width for route diversity
	for tier in range(1, 6):
		var bucket: Array = []
		if tier == 3:
			# Master convergence: single node, all paths funnel here
			var master: MapNode = MapNode.new(next_id, tier, MapNode.NodeType.MASTER, [])
			run.nodes.append(master)
			bucket.append(master)
			next_id += 1
		elif tier == 5:
			# Rest convergence: single node, guarantees rest reachable from every path
			var rest: MapNode = MapNode.new(next_id, tier, MapNode.NodeType.REST, [])
			run.nodes.append(rest)
			bucket.append(rest)
			next_id += 1
		else:
			# Tiers 1-2: always 3 nodes; tier 4: 3-4 nodes
			var node_count: int = 3 if tier <= 2 else rng.randi_range(3, 4)
			for idx in range(node_count):
				var ntype: int = _pick_node_type(rng, tier, idx, node_count)
				var node: MapNode = MapNode.new(next_id, tier, ntype, [])
				run.nodes.append(node)
				bucket.append(node)
				next_id += 1
		tier_nodes.append(bucket)

	# Tier 6: boss
	var boss: MapNode = MapNode.new(next_id, 6, MapNode.NodeType.BOSS, [])
	run.nodes.append(boss)
	tier_nodes.append([boss])

	# Connect tiers
	for tier_idx in range(tier_nodes.size() - 1):
		_connect_tiers(tier_nodes[tier_idx] as Array, tier_nodes[tier_idx + 1] as Array, rng)

	run.current_node_id = start.id
	run.max_tier = 6
	return run

static func _pick_node_type(rng: RandomNumberGenerator, tier: int, idx: int, count: int) -> int:
	# Tier 4 (late-run): shop/elite/event mix
	if tier == 4:
		if idx == 0:
			return MapNode.NodeType.ELITE
		if idx == 1:
			return MapNode.NodeType.SHOP
		var pool: Array[int] = [MapNode.NodeType.BATTLE, MapNode.NodeType.EVENT, MapNode.NodeType.SHOP]
		return pool[rng.randi_range(0, pool.size() - 1)]

	# Tiers 1-2: combat focused
	if idx == 0:
		return MapNode.NodeType.BATTLE
	var roll: float = rng.randf()
	if roll < 0.4:
		return MapNode.NodeType.BATTLE
	if roll < 0.6:
		return MapNode.NodeType.EVENT
	if roll < 0.75:
		return MapNode.NodeType.AMBUSH
	if roll < 0.85:
		return MapNode.NodeType.SHOP
	return MapNode.NodeType.ELITE

static func _connect_tiers(prev_nodes: Array, next_nodes: Array, rng: RandomNumberGenerator) -> void:
	var incoming: Dictionary = {}
	for next_variant in next_nodes:
		var next_node: MapNode = next_variant as MapNode
		incoming[next_node.id] = 0

	for prev_idx in range(prev_nodes.size()):
		var prev_node: MapNode = prev_nodes[prev_idx] as MapNode
		prev_node.next_ids.clear()
		var anchor: int = int(round(float(prev_idx) * float(maxi(next_nodes.size() - 1, 0)) / float(maxi(prev_nodes.size() - 1, 1))))
		var targets: Array[int] = [anchor]
		if next_nodes.size() > 1 and rng.randf() < 0.5:
			var offset: int = -1 if rng.randf() < 0.5 else 1
			var neighbor: int = clampi(anchor + offset, 0, next_nodes.size() - 1)
			if not targets.has(neighbor):
				targets.append(neighbor)
		for target_idx in targets:
			var target_node: MapNode = next_nodes[target_idx] as MapNode
			prev_node.next_ids.append(target_node.id)
			incoming[target_node.id] = int(incoming.get(target_node.id, 0)) + 1

	for next_idx in range(next_nodes.size()):
		var candidate: MapNode = next_nodes[next_idx] as MapNode
		if int(incoming.get(candidate.id, 0)) > 0:
			continue
		var source_idx: int = clampi(next_idx, 0, prev_nodes.size() - 1)
		var source: MapNode = prev_nodes[source_idx] as MapNode
		if not source.next_ids.has(candidate.id):
			source.next_ids.append(candidate.id)

func get_node(node_id: int) -> MapNode:
	for node in nodes:
		if node.id == node_id:
			return node
	return null

func get_current_node() -> MapNode:
	return get_node(current_node_id)

func get_available_next() -> Array[MapNode]:
	var current: MapNode = get_current_node()
	var available: Array[MapNode] = []
	if current == null:
		return available
	for next_id in current.next_ids:
		var node: MapNode = get_node(next_id)
		if node != null:
			available.append(node)
	return available

func advance_to(node_id: int) -> void:
	current_node_id = node_id

func mark_current_node_cleared() -> void:
	var node: MapNode = get_current_node()
	if node != null:
		node.cleared = true

func count_in_tier(tier: int) -> int:
	var count: int = 0
	for node in nodes:
		if node.tier == tier:
			count += 1
	return count

func index_in_tier(target: MapNode) -> int:
	var index: int = 0
	for node in nodes:
		if node.tier != target.tier:
			continue
		if node.id == target.id:
			return index
		index += 1
	return 0
```

- [ ] **Step 3: Register test modules**

In `WUGodot/tests/run_tests.gd`, add to `_TEST_MODULES`:

```gdscript
	"res://tests/test_event_runner.gd",
	"res://tests/test_map_generator.gd",
```

- [ ] **Step 4: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/run_state.gd WUGodot/tests/test_map_generator.gd WUGodot/tests/run_tests.gd
git commit -m "feat: rewrite map generator with 7 tiers, master convergence, rest guarantee"
```

---

### Task 7: Main.gd — New Scene Types and Node Routing

**Files:**
- Modify: `WUGodot/scripts/main.gd`

- [ ] **Step 1: Add new scene types and state variables**

In `main.gd`, replace the `SceneType` enum (lines 2-7):

```gdscript
enum SceneType {
	MAP,
	COMBAT,
	REWARD,
	EVENT,
	SHOP,
	REST,
	FORGET_TECHNIQUE,
	GAME_OVER,
}
```

Add imports at the top of the script (after line 0):

```gdscript
const EventRunnerScript = preload("res://scripts/event_runner.gd")
const ShopGeneratorScript = preload("res://scripts/shop_generator.gd")
```

Add new state variables after `_game_over_hover_restart` (after line 19):

```gdscript
var _event_runner: Variant = null
var _event_choices: Array[Dictionary] = []
var _event_choice_idx: int = 0
var _event_result: Dictionary = {}
var _event_showing_result: bool = false
var _shop_items: Array[Dictionary] = []
var _shop_selection_idx: int = 0
var _shop_message: String = ""
var _shop_message_timer: float = 0.0
var _forget_selection_idx: int = 0
var _rest_choice_idx: int = 0
var _combat_gold_multiplier: int = 1
```

- [ ] **Step 2: Update start_new_run to reset new state**

In `start_new_run()`, add after `_game_over_hover_restart = false` (line 41):

```gdscript
	_event_runner = null
	_event_choices.clear()
	_event_choice_idx = 0
	_event_result.clear()
	_event_showing_result = false
	_shop_items.clear()
	_shop_selection_idx = 0
	_shop_message = ""
	_shop_message_timer = 0.0
	_forget_selection_idx = 0
	_rest_choice_idx = 0
	_combat_gold_multiplier = 1
```

- [ ] **Step 3: Update _process to handle new scene types and fix Escape**

Replace the Escape handler (lines 48-50) so it only quits from MAP/GAME_OVER:

```gdscript
	if Input.is_key_pressed(KEY_ESCAPE):
		if _current_scene == SceneType.MAP or _current_scene == SceneType.GAME_OVER:
			get_tree().quit()
			return
```

Replace the `match _current_scene:` block (lines 62-69):

```gdscript
	match _current_scene:
		SceneType.MAP:
			_update_map()
		SceneType.COMBAT:
			pass
		SceneType.REWARD:
			_update_reward()
		SceneType.EVENT:
			_update_event(delta)
		SceneType.SHOP:
			_update_shop(delta)
		SceneType.REST:
			_update_rest()
		SceneType.FORGET_TECHNIQUE:
			_update_forget_technique()
		SceneType.GAME_OVER:
			_update_game_over()
```

- [ ] **Step 4: Rewrite _travel_to_node for all 8 node types**

Replace `_travel_to_node()` (lines 148-163):

```gdscript
func _travel_to_node(chosen: MapNode) -> void:
	_run_state.advance_to(chosen.id)
	_map_selection_idx = 0

	match chosen.node_type:
		MapNode.NodeType.BATTLE, MapNode.NodeType.ELITE:
			_combat_gold_multiplier = 1
			_combat_scene.setup_combat(_player, chosen)
			_combat_scene.on_enter()
			_current_scene = SceneType.COMBAT
		MapNode.NodeType.AMBUSH:
			if chosen.ambush_remaining <= 0:
				chosen.ambush_remaining = 3
			_combat_gold_multiplier = 1
			_combat_scene.setup_combat(_player, chosen)
			_combat_scene.on_enter()
			_current_scene = SceneType.COMBAT
		MapNode.NodeType.BOSS:
			_combat_gold_multiplier = 1
			_combat_scene.setup_combat(_player, chosen)
			_combat_scene.on_enter()
			_current_scene = SceneType.COMBAT
		MapNode.NodeType.EVENT:
			var event_data: Dictionary = DataManager.get_random_event()
			if event_data.is_empty():
				_run_state.mark_current_node_cleared()
				return
			_event_runner = EventRunnerScript.new()
			_event_runner.load_event(event_data)
			_event_choices = _event_runner.get_choices()
			_event_choice_idx = 0
			_event_result.clear()
			_event_showing_result = false
			_current_scene = SceneType.EVENT
		MapNode.NodeType.SHOP:
			var owned: Array[String] = []
			if _player.technique_engine != null:
				owned = _player.technique_engine.technique_ids()
			_shop_items = ShopGeneratorScript.generate_shop(owned)
			_shop_selection_idx = 0
			_shop_message = ""
			_shop_message_timer = 0.0
			_current_scene = SceneType.SHOP
		MapNode.NodeType.REST:
			_rest_choice_idx = 0
			_current_scene = SceneType.REST
		MapNode.NodeType.MASTER:
			_rewards = _generate_master_rewards()
			_reward_selection_idx = 0
			_current_scene = SceneType.REWARD
```

- [ ] **Step 5: Add _generate_master_rewards helper**

Add after `_generate_technique_rewards()`:

```gdscript
func _generate_master_rewards() -> Array:
	var owned_ids: Array[String] = []
	if _player.technique_engine != null:
		owned_ids = _player.technique_engine.technique_ids()
	var rewards: Array = []
	var used_ids: Array[String] = owned_ids.duplicate()
	var all_tech: Dictionary = DataManager.get_all_techniques()
	# Filter to rarity 2+ (rare techniques)
	var rare_pool: Array[Dictionary] = []
	for tech_id in all_tech.keys():
		if used_ids.has(str(tech_id)):
			continue
		var tech: Dictionary = all_tech[tech_id] as Dictionary
		if int(tech.get("rarity", 1)) >= 2:
			rare_pool.append(tech)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(3):
		if rare_pool.is_empty():
			break
		var idx: int = rng.randi_range(0, rare_pool.size() - 1)
		var pick: Dictionary = rare_pool[idx]
		rare_pool.remove_at(idx)
		var option: RewardOption = RewardOption.new()
		option.id = str(pick.get("id", ""))
		option.label = "%s (%s)" % [str(pick.get("name_en", "")), str(pick.get("name_cn", ""))]
		option.effect = "technique"
		option.technique_id = option.id
		rewards.append(option)
	return rewards
```

- [ ] **Step 6: Rewrite _on_combat_end for gold and ambush gauntlet**

Replace `_on_combat_end()` (lines 174-188):

```gdscript
func _on_combat_end(victory: bool) -> void:
	_combat_scene.on_exit()
	_combat_scene.deactivate()

	if victory:
		# Gold reward
		var base_gold: int = 15
		var node: MapNode = _run_state.get_current_node()
		if node != null:
			match node.node_type:
				MapNode.NodeType.ELITE:
					base_gold = 30
				MapNode.NodeType.AMBUSH:
					base_gold = 10
				MapNode.NodeType.BOSS:
					base_gold = 0
		_player.gold += base_gold * _combat_gold_multiplier

		# Ambush gauntlet continuation
		if node != null and node.node_type == MapNode.NodeType.AMBUSH:
			node.ambush_remaining -= 1
			if node.ambush_remaining > 0:
				_combat_scene.setup_combat(_player, node)
				_combat_scene.on_enter()
				_current_scene = SceneType.COMBAT
				return

		_run_state.mark_current_node_cleared()
		if node != null and node.node_type == MapNode.NodeType.BOSS:
			_current_scene = SceneType.GAME_OVER
			_end_message = "Victory! Run Complete!"
		else:
			_current_scene = SceneType.REWARD
	else:
		_current_scene = SceneType.GAME_OVER
		_end_message = "Defeat..."
```

- [ ] **Step 7: Add AMBUSH to EnemyFactory._pick_archetype_for_node**

In `WUGodot/scripts/enemy_factory.gd`, in `_pick_archetype_for_node()`, add a case for AMBUSH after the BATTLE case:

```gdscript
		MapNode.NodeType.AMBUSH:
			var pool: Array[String] = DataManager.get_enemy_archetypes_for_difficulty("easy")
			var medium: Array[String] = DataManager.get_enemy_archetypes_for_difficulty("medium")
			pool.append_array(medium)
			if pool.is_empty():
				return "bandit_swordsman"
			return pool[rng.randi_range(0, pool.size() - 1)]
```

- [ ] **Step 8: Add _update_event**

Add after `_update_reward()`:

```gdscript
func _update_event(delta: float) -> void:
	if _shop_message_timer > 0.0:
		_shop_message_timer -= delta

	if _event_runner == null:
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _event_showing_result:
		if _accept_pressed():
			var result: Dictionary = _event_result
			if result.get("open_shop", false):
				var owned: Array[String] = []
				if _player.technique_engine != null:
					owned = _player.technique_engine.technique_ids()
				_shop_items = ShopGeneratorScript.generate_shop(owned, bool(result.get("shop_rarity_boost", false)))
				_shop_selection_idx = 0
				_shop_message = ""
				_shop_message_timer = 0.0
				_run_state.mark_current_node_cleared()
				_current_scene = SceneType.SHOP
			elif result.get("trigger_combat", false):
				_combat_gold_multiplier = int(result.get("combat_gold_multiplier", 1))
				var node: MapNode = _run_state.get_current_node()
				if node != null:
					_combat_scene.setup_combat(_player, node)
					_combat_scene.on_enter()
					_current_scene = SceneType.COMBAT
				else:
					_run_state.mark_current_node_cleared()
					_current_scene = SceneType.MAP
			else:
				_run_state.mark_current_node_cleared()
				_current_scene = SceneType.MAP
		return

	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_event_choice_idx = maxi(0, _event_choice_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_event_choice_idx = mini(_event_choices.size() - 1, _event_choice_idx + 1)

	for i in range(mini(3, _event_choices.size())):
		var key: int = KEY_1 + i
		if _input_tracker.pressed_key(key):
			_event_choice_idx = i
			_resolve_event_choice(i)
			return

	if _accept_pressed():
		_resolve_event_choice(_event_choice_idx)

func _resolve_event_choice(index: int) -> void:
	_event_result = _event_runner.choose(index, _player)
	# Blocked (e.g. insufficient gold) — stay in choice mode, show message briefly
	if _event_result.get("blocked", false):
		_shop_message = str(_event_result.get("message", "Cannot do that."))
		_shop_message_timer = 1.5
		_event_runner.load_event(_event_runner._event_data)
		return
	# Drunken Master timing test: auto-resolve with 50% pass chance (MVP simplification)
	if _event_result.get("timing_test", false):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		var passed_test: bool = rng.randf() < 0.5
		_event_result = _event_runner.apply_timing_result(passed_test, _player)
	_event_showing_result = true
```

- [ ] **Step 9: Add _update_shop**

```gdscript
func _update_shop(delta: float) -> void:
	if _shop_message_timer > 0.0:
		_shop_message_timer -= delta

	var max_idx: int = _shop_items.size() - 1
	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_shop_selection_idx = maxi(0, _shop_selection_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_shop_selection_idx = mini(max_idx, _shop_selection_idx + 1)

	if _input_tracker.pressed_key(KEY_Q) or _input_tracker.pressed_key(KEY_ESCAPE):
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _accept_pressed() and _shop_selection_idx >= 0 and _shop_selection_idx < _shop_items.size():
		var item: Dictionary = _shop_items[_shop_selection_idx]
		var result: Dictionary = ShopGeneratorScript.buy_item(item, _player)
		_shop_message = str(result.get("message", ""))
		_shop_message_timer = 2.0
		if bool(result.get("success", false)):
			if result.get("open_forget", false):
				_forget_selection_idx = 0
				_current_scene = SceneType.FORGET_TECHNIQUE
				return
			# Remove purchased item from shop (all types are single-use)
			_shop_items.remove_at(_shop_selection_idx)
			_shop_selection_idx = mini(_shop_selection_idx, maxi(_shop_items.size() - 1, 0))
```

- [ ] **Step 10: Add _update_rest**

```gdscript
func _update_rest() -> void:
	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_rest_choice_idx = maxi(0, _rest_choice_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_rest_choice_idx = mini(1, _rest_choice_idx + 1)

	if _accept_pressed():
		if _rest_choice_idx == 0:
			# Heal 40% max HP
			_player.health_current = minf(_player.health_current + _player.health_max * 0.4, _player.health_max)
			_run_state.mark_current_node_cleared()
			_current_scene = SceneType.MAP
		elif _rest_choice_idx == 1:
			# Remove technique
			if _player.technique_engine != null and not _player.technique_engine.technique_ids().is_empty():
				_forget_selection_idx = 0
				_current_scene = SceneType.FORGET_TECHNIQUE
			else:
				_run_state.mark_current_node_cleared()
				_current_scene = SceneType.MAP
```

- [ ] **Step 11: Add _update_forget_technique**

```gdscript
func _update_forget_technique() -> void:
	if _player.technique_engine == null:
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	var tech_ids: Array[String] = _player.technique_engine.technique_ids()
	if tech_ids.is_empty():
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_forget_selection_idx = maxi(0, _forget_selection_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_forget_selection_idx = mini(tech_ids.size() - 1, _forget_selection_idx + 1)

	if _input_tracker.pressed_key(KEY_Q) or _input_tracker.pressed_key(KEY_ESCAPE):
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _accept_pressed() and _forget_selection_idx >= 0 and _forget_selection_idx < tech_ids.size():
		var remove_id: String = tech_ids[_forget_selection_idx]
		_player.technique_engine.remove(remove_id, _player)
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
```

- [ ] **Step 12: Commit**

```bash
git add WUGodot/scripts/main.gd WUGodot/scripts/enemy_factory.gd
git commit -m "feat: add event/shop/rest/master/ambush scene routing and update logic"
```

---

### Task 8: Main.gd — Drawing for New Scene Types

**Files:**
- Modify: `WUGodot/scripts/main.gd`

- [ ] **Step 1: Update _draw to handle new scenes**

Replace the `_draw()` method:

```gdscript
func _draw() -> void:
	match _current_scene:
		SceneType.MAP:
			_draw_map()
		SceneType.COMBAT:
			pass
		SceneType.REWARD:
			_draw_reward()
		SceneType.EVENT:
			_draw_event()
		SceneType.SHOP:
			_draw_shop()
		SceneType.REST:
			_draw_rest()
		SceneType.FORGET_TECHNIQUE:
			_draw_forget_technique()
		SceneType.GAME_OVER:
			_draw_game_over()
```

- [ ] **Step 2: Add _draw_event**

```gdscript
func _draw_event() -> void:
	_draw_background()
	var panel: Rect2 = Rect2(160.0, 100.0, float(GameConstants.VIEW_WIDTH) - 320.0, float(GameConstants.VIEW_HEIGHT) - 200.0)
	_draw_panel(panel)

	if _event_runner == null:
		return

	var title: String = _event_runner.get_title()
	var title_cn: String = _event_runner.get_title_cn()
	if not title_cn.is_empty():
		title = "%s %s" % [title_cn, title]
	_draw_text(title, panel.position.x + 26.0, panel.position.y + 40.0, Color(0.95, 0.95, 0.98, 0.95), 24)
	_draw_text(_event_runner.get_text(), panel.position.x + 26.0, panel.position.y + 80.0, Color(0.78, 0.80, 0.84, 0.9), 15)

	if _event_showing_result:
		var msg: String = str(_event_result.get("message", ""))
		_draw_text(msg, panel.position.x + 26.0, panel.position.y + 160.0, Color(0.9, 0.85, 0.6, 0.95), 16)
		_draw_text("Press Enter to continue", panel.position.x + 26.0, panel.end.y - 40.0, Color(0.6, 0.62, 0.66, 0.7), 14)
	else:
		var y: float = panel.position.y + 160.0
		for i in range(_event_choices.size()):
			var choice: Dictionary = _event_choices[i]
			var label: String = "%d. %s" % [i + 1, str(choice.get("label", "..."))]
			var color: Color = Color(0.92, 0.93, 0.98, 0.95) if i == _event_choice_idx else Color(0.6, 0.62, 0.66, 0.8)
			if i == _event_choice_idx:
				_draw_menu_cursor(Vector2(panel.position.x + 10.0, y))
			_draw_text(label, panel.position.x + 40.0, y, color, 17)
			y += 30.0
		if _shop_message_timer > 0.0:
			_draw_text(_shop_message, panel.position.x + 26.0, panel.end.y - 60.0, Color(0.9, 0.5, 0.4, 0.95), 15)
		_draw_text("W/S or 1-3 to choose, Enter to confirm", panel.position.x + 26.0, panel.end.y - 40.0, Color(0.6, 0.62, 0.66, 0.7), 14)
```

- [ ] **Step 3: Add _draw_shop**

```gdscript
func _draw_shop() -> void:
	_draw_background()
	var panel: Rect2 = Rect2(160.0, 60.0, float(GameConstants.VIEW_WIDTH) - 320.0, float(GameConstants.VIEW_HEIGHT) - 120.0)
	_draw_panel(panel)
	_draw_text("Shop", panel.position.x + 26.0, panel.position.y + 40.0, Color(0.95, 0.95, 0.98, 0.95), 24)
	_draw_text("Gold: %d" % _player.gold, panel.position.x + 200.0, panel.position.y + 40.0, Color(1.0, 0.85, 0.3, 0.95), 20)

	var y: float = panel.position.y + 80.0
	for i in range(_shop_items.size()):
		var item: Dictionary = _shop_items[i]
		var label: String = str(item.get("label", "???"))
		var price: int = int(item.get("price", 0))
		var desc: String = str(item.get("description", ""))
		var can_afford: bool = _player.gold >= price
		var selected: bool = i == _shop_selection_idx
		var text_color: Color = Color(0.92, 0.93, 0.98, 0.95) if selected else Color(0.6, 0.62, 0.66, 0.8)
		if not can_afford:
			text_color = Color(0.5, 0.3, 0.3, 0.7)
		if selected:
			_draw_menu_cursor(Vector2(panel.position.x + 10.0, y))
		_draw_text("%s — %dg" % [label, price], panel.position.x + 40.0, y, text_color, 16)
		_draw_text(desc, panel.position.x + 40.0, y + 18.0, Color(0.55, 0.57, 0.6, 0.7), 13)
		y += 48.0

	if _shop_message_timer > 0.0:
		_draw_text(_shop_message, panel.position.x + 26.0, panel.end.y - 60.0, Color(0.9, 0.85, 0.6, 0.95), 16)
	_draw_text("W/S to browse, Enter to buy, Q to leave", panel.position.x + 26.0, panel.end.y - 30.0, Color(0.6, 0.62, 0.66, 0.7), 14)
```

- [ ] **Step 4: Add _draw_rest**

```gdscript
func _draw_rest() -> void:
	_draw_background()
	var panel: Rect2 = Rect2(400.0, 260.0, float(GameConstants.VIEW_WIDTH) - 800.0, 300.0)
	_draw_panel(panel)
	_draw_text("Rest Site", panel.position.x + 26.0, panel.position.y + 40.0, Color(0.95, 0.95, 0.98, 0.95), 24)
	_draw_text("HP: %d/%d" % [int(round(_player.health_current)), int(round(_player.health_max))], panel.position.x + 26.0, panel.position.y + 70.0, Color(0.8, 0.82, 0.86, 0.85), 15)

	var choices: Array[String] = ["Heal (40% max HP)", "Remove a technique"]
	var y: float = panel.position.y + 110.0
	for i in range(choices.size()):
		var color: Color = Color(0.92, 0.93, 0.98, 0.95) if i == _rest_choice_idx else Color(0.6, 0.62, 0.66, 0.8)
		if i == _rest_choice_idx:
			_draw_menu_cursor(Vector2(panel.position.x + 10.0, y))
		_draw_text(choices[i], panel.position.x + 40.0, y, color, 17)
		y += 30.0
	_draw_text("W/S to choose, Enter to confirm", panel.position.x + 26.0, panel.end.y - 30.0, Color(0.6, 0.62, 0.66, 0.7), 14)
```

- [ ] **Step 5: Add _draw_forget_technique**

```gdscript
func _draw_forget_technique() -> void:
	_draw_background()
	var panel: Rect2 = Rect2(400.0, 160.0, float(GameConstants.VIEW_WIDTH) - 800.0, 500.0)
	_draw_panel(panel)
	_draw_text("Forget Technique", panel.position.x + 26.0, panel.position.y + 40.0, Color(0.95, 0.95, 0.98, 0.95), 24)

	if _player.technique_engine == null:
		return
	var tech_ids: Array[String] = _player.technique_engine.technique_ids()
	var y: float = panel.position.y + 80.0
	for i in range(tech_ids.size()):
		var tech_data: Dictionary = DataManager.get_technique(tech_ids[i])
		var display: String = "%s %s" % [str(tech_data.get("name_cn", tech_ids[i])), str(tech_data.get("name_en", ""))]
		var desc: String = str(tech_data.get("description", ""))
		var selected: bool = i == _forget_selection_idx
		var color: Color = Color(0.92, 0.93, 0.98, 0.95) if selected else Color(0.6, 0.62, 0.66, 0.8)
		if selected:
			_draw_menu_cursor(Vector2(panel.position.x + 10.0, y))
		_draw_text(display, panel.position.x + 40.0, y, color, 16)
		_draw_text(desc, panel.position.x + 40.0, y + 18.0, Color(0.55, 0.57, 0.6, 0.7), 13)
		y += 44.0
	_draw_text("W/S to browse, Enter to forget, Q to cancel", panel.position.x + 26.0, panel.end.y - 30.0, Color(0.6, 0.62, 0.66, 0.7), 14)
```

- [ ] **Step 6: Update _get_node_color and _get_node_type_label for new types**

Replace `_get_node_color()`:

```gdscript
func _get_node_color(node_type: int) -> Color:
	match node_type:
		MapNode.NodeType.BATTLE:
			return Color8(104, 186, 255)
		MapNode.NodeType.ELITE:
			return Color8(255, 165, 115)
		MapNode.NodeType.AMBUSH:
			return Color8(255, 100, 100)
		MapNode.NodeType.MASTER:
			return Color8(200, 160, 255)
		MapNode.NodeType.EVENT:
			return Color8(182, 194, 214)
		MapNode.NodeType.SHOP:
			return Color8(248, 224, 142)
		MapNode.NodeType.REST:
			return Color8(120, 220, 160)
		MapNode.NodeType.BOSS:
			return Color8(255, 105, 128)
		_:
			return Color8(210, 210, 220)
```

Replace `_get_node_type_label()`:

```gdscript
func _get_node_type_label(node_type: int) -> String:
	match node_type:
		MapNode.NodeType.BATTLE:
			return "Duel"
		MapNode.NodeType.ELITE:
			return "Elite Duel"
		MapNode.NodeType.AMBUSH:
			return "Ambush"
		MapNode.NodeType.MASTER:
			return "Master"
		MapNode.NodeType.EVENT:
			return "Event"
		MapNode.NodeType.SHOP:
			return "Shop"
		MapNode.NodeType.REST:
			return "Rest"
		MapNode.NodeType.BOSS:
			return "Boss"
		_:
			return "Unknown"
```

- [ ] **Step 7: Add gold display to map HUD**

In `_draw_map()`, add after the "Path Select" title text (after line 232):

```gdscript
	_draw_text("Gold: %d" % _player.gold, GameConstants.VIEW_WIDTH - 200.0, 74.0, Color(1.0, 0.85, 0.3, 0.95), 20)
```

- [ ] **Step 8: Update _sync_input_tracker for new keys**

Replace `_sync_input_tracker()`:

```gdscript
func _sync_input_tracker() -> void:
	var keys: Array[int] = [
		KEY_ESCAPE,
		KEY_F5,
		KEY_R,
		KEY_A,
		KEY_D,
		KEY_W,
		KEY_S,
		KEY_Q,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_UP,
		KEY_DOWN,
		KEY_ENTER,
		KEY_KP_ENTER,
		KEY_SPACE,
		KEY_J,
		KEY_1,
		KEY_2,
		KEY_3,
		KEY_KP_1,
		KEY_KP_2,
		KEY_KP_3,
	]
	_input_tracker.sync_keys(keys)
	_input_tracker.sync_mouse_buttons([MOUSE_BUTTON_LEFT])
```

- [ ] **Step 9: Commit**

```bash
git add WUGodot/scripts/main.gd
git commit -m "feat: add drawing for event/shop/rest/forget scenes, gold HUD, updated map labels"
```

---

### Task 9: Run Tests and Full Verification

**Files:**
- No new files.

- [ ] **Step 1: Run all headless tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass (98 existing + ~33 new).

- [ ] **Step 2: Verify headless import**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --import`

Expected: Completes without errors.

- [ ] **Step 3: Verify headless startup**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --quit-after 1`

Expected: Starts and quits cleanly.

---

### Task 10: Manual Playtest Checklist

- [ ] **Step 1: Manual playtest**

Run the game: `HOME=/tmp/godot-home godot --path WUGodot`

Verify each item (pass/fail):

**Map structure:**
- [ ] Map shows ~15 nodes across 7 tiers
- [ ] Node colors differ by type (blue=duel, orange=elite, red=ambush, purple=master, gray=event, yellow=shop, green=rest, pink=boss)
- [ ] Node labels show correct type names when selected
- [ ] All nodes are reachable from the start
- [ ] Gold counter visible on map screen

**Duel/Elite/Boss nodes:**
- [ ] Duel: 1v1 fight against easy/medium enemy, earns 15 gold on victory
- [ ] Elite: 1v1 fight against hard enemy, earns 30 gold on victory
- [ ] Boss: Xiong Tie fight, ends run on victory (no gold reward)

**Ambush node:**
- [ ] Triggers 3 sequential fights
- [ ] After each fight, next fight starts automatically
- [ ] Each fight earns 10 gold
- [ ] After all 3, transitions to reward screen

**Event node:**
- [ ] Shows event title (Chinese + English) and text
- [ ] Choices displayed, navigable with W/S or 1-3 keys
- [ ] Selecting a choice shows outcome message
- [ ] Gold/HP effects apply correctly
- [ ] Technique grants work
- [ ] "Not enough gold" blocks payment choices

**Shop node:**
- [ ] Shows 6 items: 3 techniques + HP potion + posture potion + forget
- [ ] Technique prices vary by rarity
- [ ] Items show descriptions
- [ ] "Not enough gold" prevents purchase
- [ ] Purchasing a technique removes it from the list
- [ ] HP potion heals 30% max HP
- [ ] Posture potion restores 50% max posture
- [ ] Forget technique opens technique list for removal
- [ ] Q exits shop

**Rest node:**
- [ ] Two choices: heal or remove technique
- [ ] Heal restores 40% max HP
- [ ] Remove opens technique list

**Master node:**
- [ ] Shows 3 rare technique options (rarity 2+)
- [ ] Techniques are free (no gold cost)
- [ ] Selecting one adds it and returns to map

**Integration:**
- [ ] Gold persists across the run
- [ ] Techniques acquired from events/shops/master work in combat
- [ ] Reward screen still shows after non-boss combat victories
- [ ] All existing techniques and combat mechanics still function

---

## Review Cycle Audit

After implementation, verify these cross-cutting concerns:

1. **Backward compatibility:** All existing 98 tests still pass.
2. **MapNode enum stability:** Adding new enum values before BOSS does not break existing serialization — the current code uses the enum values directly, no persistence.
3. **Gold economy balance:** Duel=15g, Elite=30g, Ambush=10g×3=30g total. Shop techniques cost 20-50g. HP potion=20g. A typical 7-node path yields ~120-150g, enough for 3-4 purchases.
4. **Master convergence:** Tier 3 is a single-node tier (MASTER), so all paths converge through it.
5. **Rest convergence:** Tier 5 is a single-node tier (REST), so all paths converge through it before the boss. Both master and rest are structurally guaranteed reachable from every path.
6. **Event JSON schema:** All 6 events have id, title, text, choices, and outcomes. Outcomes may contain gold, hp, grant_technique, open_shop, trigger_combat, or timing_test.
