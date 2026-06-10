# A3 — Split main.gd into Scene Controllers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the 1,251-line `main.gd` monolith to a ~250-line router by extracting per-scene controllers + a testable `RunFlow`, bringing the run-flow logic (gold, ambush sequencing, travel decisions, reward generation) under headless test for the first time — with **zero behavior change**.

**Architecture:** Each meta-game scene (menu/map/reward/forget/event/shop/rest/endings) becomes a `RefCounted` controller with `enter(ctx)`, `update(ctx, input, delta)`, `draw(ctx, canvas)`. Controllers consume a **pure `MenuInput` snapshot** (built once per frame from `InputTracker`) instead of touching `Input` — that seam is what makes them headless-testable. Shared drawing helpers move to a static `UiDraw`. Run-flow *decisions* (travel, combat outcome, gold, rewards) move to a `RunFlow` `RefCounted` that returns transition values instead of mutating `_current_scene`. `main.gd` keeps: ready/router/global keys, combat-scene wiring, dev-shot machinery.

**Tech Stack:** Godot 4.6.2 (GDScript, repo's RefCounted-first style), headless runner (`./run.sh --test`).

**Hard boundaries:** zero behavior change (playtest-identical); **no changes** to `combat_scene.gd` (beyond none), technique/attack systems, or data formats (A4 moves magic numbers to JSON *later* — this plan moves code, not values); no key rebinding (A5 later — `KEY_*` constants stay, but centralized in the `MenuInput` builder). Record `A3_BASE` (`git rev-parse HEAD`) before starting; final check: `git diff --name-only <A3_BASE>...HEAD` touches only `main.gd`, new `scripts/scenes|ui` files, and tests.

---

## File Structure

**New:**
- `WUGodot/scripts/ui/menu_input.gd` — pure input snapshot (`up/down/left/right/accept/cancel/restart/numbers`) + builder from `InputTracker`.
- `WUGodot/scripts/ui/ui_draw.gd` — static draw helpers moved verbatim from main (`panel`, `text`, `centered_text`, `text_lines`, `text_block`, `menu_cursor`, `reward_option`, `font_for_size`, `measure_text`, `wrap_text`) taking `canvas: CanvasItem` as first arg.
- `WUGodot/scripts/scene_context.gd` — shared state bundle: `run_state`, `player`, `combat_gold_multiplier`, run stats (`gold_earned`, `techniques_acquired`, `start/end_time`), `end_message`, `cursor_flash`, plus transition requests: `next_scene: int` (`-1` = none) and `combat_node: MapNode` (router consumes both).
- `WUGodot/scripts/run_flow.gd` — run-flow decisions (below).
- `WUGodot/scripts/scenes/menu_scene.gd`, `map_scene.gd`, `reward_scene.gd`, `forget_scene.gd`, `event_scene.gd`, `shop_scene.gd`, `rest_scene.gd`, `ending_scene.gd` (victory + game-over share one controller).

**New tests:** `test_menu_input.gd`, `test_run_flow.gd`, `test_scene_controllers.gd`.

**Modified:** `WUGodot/scripts/main.gd` (shrinks task by task), `WUGodot/tests/run_tests.gd`.

**Untouched:** `combat_scene.gd`, all combat/technique/attack/data files.

---

## Task 0: Base + safety net

- [ ] **Step 1:** `git rev-parse HEAD` → record as `A3_BASE`.
- [ ] **Step 2:** `./run.sh --test` → confirm the current green count (≈277) — the whole-suite gate for every task below.
- [ ] **Step 3:** Manual smoke route once (menu → map → battle → reward → shop → event → rest → boss → victory; and a defeat → game over) noting anything already odd — this is the behavioral baseline for the per-task playtests.

---

## Task 1: MenuInput + UiDraw (the seams)

**Files:** create `scripts/ui/menu_input.gd`, `scripts/ui/ui_draw.gd`; test `tests/test_menu_input.gd`.

- [ ] **Step 1: Failing test + register**

```gdscript
extends RefCounted
const MI = preload("res://scripts/ui/menu_input.gd")

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	# Pure construction (what controller tests will use).
	var input: Variant = MI.new()
	input.down = true
	input.accept = true
	if input.down and input.accept and not input.up:
		passed += 1
	else:
		failed += 1; failures.append("MenuInput fields should be settable plainly")

	# step_index: clamped vertical navigation (the shared menu pattern).
	if MI.step_index(0, 1, input) == 1:           # down from 0 of [0..1] -> 1
		passed += 1
	else:
		failed += 1; failures.append("down should advance index")
	var up_input: Variant = MI.new(); up_input.up = true
	if MI.step_index(0, 3, up_input) == 0:        # up at top clamps
		passed += 1
	else:
		failed += 1; failures.append("up at top should clamp to 0")

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2:** run → FAIL (missing script).
- [ ] **Step 3: Implement**

```gdscript
class_name MenuInput
extends RefCounted
# Pure per-frame input snapshot. Controllers consume THIS, never Input/InputTracker/
# get_viewport(), so controller logic is headless-testable. Key constants live only in
# from_tracker() (single place A5's InputMap migration will touch).

var up: bool = false
var down: bool = false
var left: bool = false
var right: bool = false
var accept: bool = false        # J / Enter / KP-Enter / Space — MUST match main._accept_pressed() (main.gd:1209)
var local_cancel: bool = false  # Q / Esc — shop & forget use these as local "back" (main.gd:265, :325)
var number: int = -1            # 1..9, from BOTH the top row AND the keypad (reward selection)
var mouse_pos: Vector2 = Vector2.INF   # viewport-space; INF = no mouse info
var mouse_clicked: bool = false        # left button just pressed this frame

static func from_tracker(t: InputTracker, viewport: Viewport) -> MenuInput:
	var m := MenuInput.new()
	m.up = t.pressed_key(KEY_W) or t.pressed_key(KEY_UP)
	m.down = t.pressed_key(KEY_S) or t.pressed_key(KEY_DOWN)
	m.left = t.pressed_key(KEY_A) or t.pressed_key(KEY_LEFT)
	m.right = t.pressed_key(KEY_D) or t.pressed_key(KEY_RIGHT)
	m.accept = t.pressed_key(KEY_J) or t.pressed_key(KEY_ENTER) or t.pressed_key(KEY_KP_ENTER) or t.pressed_key(KEY_SPACE)
	m.local_cancel = t.pressed_key(KEY_Q) or t.pressed_key(KEY_ESCAPE)
	for i in range(1, 10):
		if t.pressed_key(KEY_0 + i) or t.pressed_key(KEY_KP_0 + i):
			m.number = i
			break
	m.mouse_pos = viewport.get_mouse_position()
	m.mouse_clicked = t.pressed_mouse(MOUSE_BUTTON_LEFT) if t.has_method("pressed_mouse") else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return m

static func step_index(idx: int, max_idx: int, input: MenuInput) -> int:
	if input.up: idx = maxi(0, idx - 1)
	if input.down: idx = mini(max_idx, idx + 1)
	return idx
```

**Fidelity contract (gate for this task):** before finalizing `from_tracker`, read `main._accept_pressed()` (`main.gd:1209`) and every scene's exact key+mouse reads, and reproduce them **exactly** — the known set already includes: accept = J/Enter/KP-Enter/Space; shop/forget local-back = Q or Esc; reward selection via top-row *and keypad* numbers; map/reward hover + click via viewport mouse position (`main.gd:163, :1121`). The `mouse_clicked` builder line above is a sketch — match it to however `_input_tracker`/mouse is actually read today (verify the real mouse API before writing it). **Esc remains scene-dependent**: the router's global Esc-quit (menu/map/game-over) stays in main; `local_cancel` carries Esc only into scenes that treat it as "back" today. Mouse-dependent controllers (map/reward/shop) consume `mouse_pos`/`mouse_clicked` from the snapshot — tests set these fields directly.

`ui_draw.gd`: move `_draw_background/_draw_panel/_draw_text/_draw_centered_text/_draw_text_lines/_draw_text_block/_draw_menu_cursor/_draw_reward_option_with_desc/_font_for_size/_measure_text/_wrap_text` (main.gd:972-1063) **verbatim** as `static func`s with `canvas: CanvasItem` first param (`canvas.draw_rect(...)` etc.). Main's copies stay until each scene migrates (avoid one giant diff); deleted in Task 8.

- [ ] **Step 4:** run → PASS (3 asserts). **Step 5:** commit `feat(ui): MenuInput snapshot + UiDraw static helpers`.

---

## Task 2: RunFlow extraction (the testable core)

**Files:** create `scripts/run_flow.gd`; test `tests/test_run_flow.gd`; modify `main.gd` to delegate.

- [ ] **Step 1: Failing tests + register.** Pin today's behavior exactly (numbers from `main.gd:344-512`):

```gdscript
extends RefCounted
const RF = preload("res://scripts/run_flow.gd")
const MapNodeScript = preload("res://scripts/map_node.gd")
const FighterScript = preload("res://scripts/fighter.gd")

func _node(t: int) -> Variant:
	var n: Variant = MapNodeScript.new()
	n.node_type = t
	return n

func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	var failures: Array[String] = []

	# Victory gold by node type: BATTLE 15, ELITE 30, AMBUSH 10, BOSS 0; multiplier applies.
	for spec in [[MapNodeScript.NodeType.BATTLE, 1, 15], [MapNodeScript.NodeType.ELITE, 1, 30], [MapNodeScript.NodeType.AMBUSH, 1, 10], [MapNodeScript.NodeType.BOSS, 1, 0], [MapNodeScript.NodeType.BATTLE, 2, 30]]:
		var d: Dictionary = RF.combat_victory_outcome(_node(int(spec[0])), int(spec[1]))
		if int(d.get("gold", -1)) == int(spec[2]):
			passed += 1
		else:
			failed += 1; failures.append("gold for type %s x%s should be %s (got %s)" % [spec[0], spec[1], spec[2], d.get("gold")])

	# Ambush sequencing: 3 fights, re-enter combat twice, clear+reward on the third.
	var amb: Variant = _node(MapNodeScript.NodeType.AMBUSH)
	amb.ambush_remaining = 3
	var d1: Dictionary = RF.combat_victory_outcome(amb, 1)
	var d2: Dictionary = RF.combat_victory_outcome(amb, 1)
	var d3: Dictionary = RF.combat_victory_outcome(amb, 1)
	if str(d1.get("next")) == "combat_again" and str(d2.get("next")) == "combat_again" and str(d3.get("next")) == "reward":
		passed += 1
	else:
		failed += 1; failures.append("ambush should chain 3 fights then reward (got %s/%s/%s)" % [d1.get("next"), d2.get("next"), d3.get("next")])

	# Boss victory routes to victory screen; defeat routes to game over.
	if str(RF.combat_victory_outcome(_node(MapNodeScript.NodeType.BOSS), 1).get("next")) == "victory":
		passed += 1
	else:
		failed += 1; failures.append("boss win should go to victory")

	# Technique reward generation: 3 unowned options; respects owned filter.
	DataManager.initialize()
	var rewards: Array = RF.generate_technique_rewards(3, [])
	if rewards.size() == 3:
		passed += 1
	else:
		failed += 1; failures.append("should offer 3 technique rewards (got %d)" % rewards.size())

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: Implement `run_flow.gd`** by **moving** the decision logic out of main:
  - `combat_victory_outcome(node, gold_multiplier) -> {gold: int, next: String}` — body from `_on_combat_end`'s victory branch (`main.gd:482-505`): gold table, decrement `ambush_remaining` and return `next: "combat_again"` while > 0, `"victory"` for cleared boss, else `"reward"`. (It mutates `node.ambush_remaining` exactly as today.)
  - `travel_decision(node, player) -> Dictionary` — from `_travel_to_node` (`main.gd:344-399`): returns `{scene: "combat"|"event"|"shop"|"rest"|"reward"|"map", ...payload}`. **Not pure, by design — same side effects as today**: it MAY mutate the node exactly as the current code does (`chosen.event_id = …` when assigning a random event, `chosen.ambush_remaining = 3` priming) and it invokes RNG (random event pick, `ShopGenerator`, master-reward sampling). Tests therefore assert *shapes and invariants* (a SHOP decision carries ≥1 items; an EVENT decision sets `node.event_id` non-empty; deterministic branches like REST/MASTER-empty-pool assert exact transitions) rather than exact random contents. Event runner *setup* still happens in the event controller's `enter` from the returned `event_data`.
  - `generate_technique_rewards(count, owned_ids)` / `generate_master_rewards(owned_ids)` — moved from `main.gd:401-444`, with `owned_ids` as a parameter instead of reading `_player` (pure).
  - `main.gd` `_on_combat_end`/`_travel_to_node` become thin: call RunFlow, apply the returned transition (set `_current_scene`, `_player.gold += gold`, `_run_gold_earned += gold`, `_setup_combat_for_node` on `"combat_again"`). **Behavior identical; only the decision moved.**
- [ ] **Step 4:** run → PASS (8 asserts) + full suite green + smoke-play a battle/ambush/boss route.
- [ ] **Step 5:** commit `refactor(run): extract RunFlow decisions from main`.

---

## Task 3: Controller pattern + Rest & Ending (exemplar)

**Files:** create `scripts/scene_context.gd`, `scripts/scenes/rest_scene.gd`, `scripts/scenes/ending_scene.gd`; extend `tests/test_scene_controllers.gd`; modify `main.gd`.

- [ ] **Step 1: SceneContext**

```gdscript
class_name SceneContext
extends RefCounted
# Shared meta-game state handed to scene controllers. Controllers request
# transitions by setting next_scene / combat_node; the router applies them.

var run_state: RunState
var player: Fighter
var combat_gold_multiplier: int = 1
var run_gold_earned: int = 0
var run_techniques_acquired: Array[String] = []
var run_start_time: float = 0.0
var run_end_time: float = 0.0
var end_message: String = ""
var cursor_flash: float = 0.0
# Transient user-facing notice, shared by shop AND event (today both write
# main's _shop_message/_shop_message_timer — see main.gd:206 blocked-choice path).
var notice_message: String = ""
var notice_timer: float = 0.0

var next_scene: int = -1          # SceneType value, or -1 = stay
var combat_node: MapNode = null   # set to request combat setup

func goto(scene: int) -> void:
	next_scene = scene
```

- [ ] **Step 2: Rest controller (full exemplar — every other controller follows this shape)**

```gdscript
class_name RestScene
extends RefCounted
const MI = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var choice_idx: int = 0

func enter(_ctx: SceneContext) -> void:
	choice_idx = 0

func update(ctx: SceneContext, input: Variant, _delta: float) -> void:
	choice_idx = MI.step_index(choice_idx, 1, input)
	if input.accept:
		if choice_idx == 0:
			ctx.player.health_current = minf(ctx.player.health_current + ctx.player.health_max * 0.4, ctx.player.health_max)
			ctx.run_state.mark_current_node_cleared()
			ctx.goto(Main.SceneType.MAP)
		else:
			if ctx.player.technique_engine != null and not ctx.player.technique_engine.technique_ids().is_empty():
				ctx.goto(Main.SceneType.FORGET_TECHNIQUE)
			else:
				ctx.run_state.mark_current_node_cleared()
				ctx.goto(Main.SceneType.MAP)

func draw(ctx: SceneContext, canvas: CanvasItem) -> void:
	# moved VERBATIM from main._draw_rest (main.gd:815-851), with _draw_* -> UiDraw.*(canvas, ...)
	pass  # (transplant in implementation; not duplicated here)
```

(If `Main.SceneType` can't be referenced from a RefCounted cleanly, move the `SceneType` enum into `scene_context.gd` and have main alias it — one mechanical find/replace, decide at implementation.)

- [ ] **Step 3: Router delegation in main**

```gdscript
var _scenes: Dictionary = {}   # SceneType -> controller; built in _ready
var _ctx: SceneContext

# in _process, replace the per-scene match arms for migrated scenes with:
	var controller: Variant = _scenes.get(_current_scene)
	if controller != null:
		controller.update(_ctx, MenuInput.from_tracker(_input_tracker, get_viewport()), delta)
		_apply_ctx_transitions()   # consumes ctx.next_scene / ctx.combat_node, calls enter() on the new controller
# in _draw, same delegation for migrated scenes; unmigrated arms keep their old calls.
```

**New-run reset contract:** today `start_new_run()` (`main.gd:72-100`) clears ~19 scene vars by hand; once that state lives inside persistent controller instances it would silently survive into the next run. Rule: `start_new_run()` **rebuilds the controllers dict** (`_scenes = _build_scenes()`) and replaces `_ctx` with a fresh `SceneContext` — fresh objects, no per-field clearing to forget. (Per-visit state is additionally reset by `enter()` on every transition, as the rest exemplar shows.) As scene vars migrate in Tasks 3–7, delete their lines from `start_new_run()`; by Task 8 it should construct, not clear.

- [ ] **Step 4: Controller test** (`test_scene_controllers.gd`): rest heal = +40% capped, clears node, goes to MAP; forget branch when techniques owned; ending controller returns to menu/new-run on accept. Drive with hand-built `MenuInput` + a `SceneContext` with a real `RunState`/`Fighter` — **no Input/engine needed**: that's the payoff of the seam.
- [ ] **Step 5:** suite green + playtest rest + victory/game-over screens. Delete the moved `_update_rest/_draw_rest/_update_victory/_update_game_over/_draw_victory/_draw_game_over` from main. Commit `refactor(scenes): controller pattern + rest/ending extracted`.

---

## Tasks 4–7: Remaining scenes (same recipe, one commit each)

Each task: create controller(s) by **moving** the listed functions + state vars, add 2–4 controller tests for its decision logic, suite green, playtest that scene, delete moved code from main, commit.

| Task | Controller(s) | Moves from main.gd | State vars that move | Tests to add |
|---|---|---|---|---|
| 4 | `menu_scene.gd`, `map_scene.gd` | `_update_main_menu:144`, `_draw_main_menu:601` **+ its scene-view helpers** (`_draw_bamboo_silhouettes`, `_draw_scene_frame`); `_update_map:149`, `_draw_map:627` **+ its helpers** (`_draw_map_wash`, `_get_map_node_position`, `_get_node_color`, `_get_node_type_label`) (travel goes through `RunFlow.travel_decision`) | `_map_selection_idx` | map: selection clamps to available next nodes; accept requests the chosen node's transition; hover/click selects a node (via snapshot `mouse_pos`/`mouse_clicked`) |
| 5 | `reward_scene.gd`, `forget_scene.gd` | `_update_reward:171`, `_draw_reward:685`, `_apply_reward_by_index:466`; `_update_forget_technique:308`, `_draw_forget_technique:852` | `_rewards`, `_reward_selection_idx`, `_forget_selection_idx` | reward apply adds technique + records `run_techniques_acquired` (number keys incl. keypad); forget removes + returns; `local_cancel` backs out where today's Q/Esc does; empty-rewards fallback to MAP |
| 6 | `shop_scene.gd` | `_update_shop:255`, `_draw_shop:775` | `_shop_items`, `_shop_selection_idx` (messages → `ctx.notice_*`) | purchase deducts gold + learns; insufficient gold sets `ctx.notice_message`; forget-item opens FORGET; `local_cancel` leaves shop as today |
| 7 | `event_scene.gd` | `_update_event:206`, `_draw_event:715`, `_resolve_event_choice:445`, `_compute_event_panel_layout:758` | `_event_runner/_event_data/_event_choices/_event_choice_idx/_event_result/_event_showing_result` (its blocked-message writes → `ctx.notice_*` — today it reuses `_shop_message`) | choice resolution applies gold/HP/technique outcomes via EventRunner; blocked outcome sets `ctx.notice_message`; result screen → MAP |

**Move rules:**
- Bodies transplant verbatim with exactly three substitutions: `_draw_*` → `UiDraw.*(canvas, …)`, tracker/`Input` reads → the `MenuInput` snapshot, `_current_scene =` → `ctx.goto(...)`. Mouse logic reads `input.mouse_pos`/`input.mouse_clicked` (never `get_viewport()` — controllers are `RefCounted`).
- **Scene-specific view helpers move into their controller as private funcs** (the Task 4 lists above; before each task, grep that scene's `_draw_X` body for `self.`-helper calls and take them along). `UiDraw` holds only the generic primitives from Task 1 — anything menu/map-shaped stays with menu/map, or main never reaches the line target.
- `_shop_message/_shop_message_timer` is **shared** by shop *and* event today (`main.gd:206` writes it for blocked choices) → both controllers use `ctx.notice_message/notice_timer`; the **router** decrements `notice_timer` each frame (one place), and `UiDraw` renders it where the scenes draw it today.

---

## Task 8: Slim main + final gates

- [ ] **Step 1:** Delete the now-unused private draw helpers from main (moved to UiDraw in Task 1), the migrated match arms, and any orphaned state vars. main retains: `_ready`, `start_new_run`, `_process` (global keys F5/R/Esc + delegation + `_apply_ctx_transitions`), `_draw` (delegation + combat passthrough), `_setup_combat_for_node`, `_on_combat_end` (thin RunFlow wrapper), dev-shot functions, `_sync_input_tracker`.
- [ ] **Step 2:** `wc -l WUGodot/scripts/main.gd` → target **≤ 300** (from 1,251; dev-shot machinery is ~80 lines of that).
- [ ] **Step 3:** Full gates: `./run.sh --test` (expect ≈277 + ~15 new), `./run.sh --import`, `git diff --check`; boundary: `git diff --name-only <A3_BASE>...HEAD | grep -vE "main\.gd|scripts/scenes/|scripts/ui/|scene_context|run_flow|tests/"` → empty.
- [ ] **Step 4:** Full playtest route (Task 0's baseline route) — every scene must behave identically: menu, map nav + travel, all node types, reward/forget, shop purchase + forced-forget, event choices + blocked path, rest both branches, ambush ×3, boss → victory scroll, defeat → game over, R-restart, F5 reload, Esc quit points.
- [ ] **Step 5:** Commit `refactor(main): router-only main.gd (scene controllers complete)`.

---

## Self-Review Notes

- **The seam is the point**: `MenuInput` makes every controller and `RunFlow` testable headless — the run-flow logic (gold/ambush/rewards/travel) gets its first tests ever (Task 2), which is the durable value beyond line count.
- **Move, don't rewrite**: draw/update bodies transplant verbatim; the only mechanical rewrites are `_draw_*`→`UiDraw.*`, tracker-reads→snapshot, `_current_scene=`→`ctx.goto`. Anything else is scope creep.
- **One scene per commit** with a playtest gate keeps every step revertable and bisectable.
- **A4/A5 hooks honored, not done**: magic numbers (gold 15/30/10, heal 0.4, prices) move *unchanged* into RunFlow/controllers — extracting them to JSON is A4, on top of this structure. All `KEY_*` constants end up in exactly one function (`MenuInput.from_tracker`) — A5's InputMap migration becomes a one-function change.
- **Known risks**: (1) `Main.SceneType` referencing from RefCounted — fallback documented (enum moves to SceneContext); (2) mouse handling fidelity — carried through the snapshot (`mouse_pos`/`mouse_clicked`), verified by the per-scene playtests; (3) per-scene key nuances — Task 1's fidelity contract is the gate; (4) dev-shot capture path exercises combat states via main — re-run `--shot-combat` once in Task 8 to confirm it survived.

**Review fixes folded in:**
- **MenuInput fidelity** — `accept` includes Enter/KP-Enter/Space/J (matching `_accept_pressed`, `main.gd:1209`); added `local_cancel` (Q/Esc shop+forget back, with Esc's scene-dependence noted), keypad-aware `number`, and the builder marked as gated on reading every scene's real reads.
- **Mouse contract un-contradicted** — `mouse_pos`/`mouse_clicked` live in the snapshot; controllers never touch `get_viewport()`; map/reward hover+click consume snapshot fields (testable by setting them).
- **Scene-view helpers** — menu/map's private helpers (`_draw_bamboo_silhouettes`, `_draw_scene_frame`, `_draw_map_wash`, `_get_map_node_position`, `_get_node_color`, `_get_node_type_label`) move **with their controllers**, not into UiDraw; a grep-the-body rule covers every scene's task.
- **Shared `_shop_message`** — became neutral `ctx.notice_message/notice_timer` (event's blocked-choice path writes it too, `main.gd:206`); router owns the timer decrement.
- **`travel_decision` honesty** — documented as side-effecting (node mutation + RNG) exactly like today; tests assert invariants, not random contents.
- **New-run reset** — `start_new_run()` rebuilds controllers + fresh `SceneContext` instead of field-by-field clearing.
