# WU Run Flow & Chapter 1 Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the playable MVP loop by adding a main menu, a wuxia-flavored Victory scroll with run stats, a proper Defeat screen, a boss death slow-mo beat, and a balance tuning pass on combat timing and enemy stats — producing a game that can be played start-to-finish as a complete experience.

**Architecture:** The existing `main.gd` SceneType enum gains two new states: `MAIN_MENU` (replaces the current boot-straight-to-MAP behavior) and `VICTORY` (replaces the generic GAME_OVER for boss wins). `_ready()` starts in MAIN_MENU instead of calling `start_new_run()` immediately. The Victory screen displays run duration, final HP%, gold earned, techniques acquired during the run (tracked separately from live loadout), and a wuxia title. The Defeat screen is the existing GAME_OVER with improved presentation. Boss death flow: killing blow triggers `_boss_death_triggered` → combat simulation freezes (early return before AI/hits/input) → 1-second slow-mo with particles and calligraphy plays (only visuals tick) → timer expires → `_is_paused_on_end = true` → player presses Enter → `combat_end` signal fires → `main.gd` routes to VICTORY. Balance tuning is a JSON-only pass on `GameSettings.json` and enemy data files.

**Tech Stack:** Godot 4.6.2 (GDScript). No new dependencies.

**Spec reference:** `docs/superpowers/specs/2026-04-10-wu-mvp-design.md` — Section A (Victory flow, Defeat flow, typical session timeline).

**Plan sequence (5 plans total for the WU MVP):**

1. **Plan 1 — Combat Foundation Refactor.** Implemented.
2. **Plan 2 — Technique System + 20-Technique MVP Pool.** Implemented.
3. **Plan 3 — Enemy Archetypes + Iron Bear Boss.** Implemented.
4. **Plan 4 — Run Structure Expansion.** Implemented.
5. **Plan 5 (this document) — Run Flow & Chapter 1 Polish.** Main menu, Victory scroll, Defeat screen, boss death beat, balance pass.

This is the final plan. After implementation, the WU MVP is playable end-to-end.

---

## File Structure

**Modified files:**

- `WUGodot/scripts/main.gd` — Add `MAIN_MENU` and `VICTORY` scene types. Add `_run_start_time: float`, `_run_end_time: float`, `_run_gold_earned: int` tracking. Add `_update_main_menu()`, `_draw_main_menu()`, `_update_victory()`, `_draw_victory()`. Modify `_ready()` to start in MAIN_MENU. Modify `_on_combat_end()` to route boss victory to VICTORY instead of GAME_OVER. Modify `_draw_game_over()` for improved defeat presentation. Add gold tracking to `_on_combat_end()`.
- `WUGodot/scripts/combat_scene.gd` — Add boss death slow-mo beat: on enemy death when node is BOSS, trigger 1.0s of 0.2x time scale, particle burst, and calligraphy feedback before emitting `combat_end`. Add `_boss_death_timer: float` and `_boss_death_triggered: bool` to delay the end pause.
- `WUGodot/data/Settings/GameSettings.json` — Balance pass: adjust parry window, posture recovery, block multipliers, and damage values.
- `WUGodot/data/Enemies/BanditSwordsman.json` — Balance: adjust HP, posture, aggression.
- `WUGodot/data/Enemies/BanditSpearman.json` — Balance: adjust HP, posture.
- `WUGodot/data/Enemies/WanderingRonin.json` — Balance: adjust HP, aggression.
- `WUGodot/data/Enemies/SectDisciple.json` — Balance: adjust aggression, block chance.
- `WUGodot/data/Enemies/MaskedAssassin.json` — Balance: adjust HP, teleport chance.
- `WUGodot/data/Enemies/IronBear.json` — Balance: adjust HP for 3-5 minute fight length.

**No new files.** This plan only modifies existing files and JSON data.

---

## Testing Strategy

**Headless tests:** No new test files. The existing 132 tests must continue to pass — this plan changes presentation and balance, not core logic.

**Manual playtest checklist** (Task 5):

- Full loop: main menu → start → map → combat → reward → map → boss → victory → main menu → new run.
- Boss death beat: slow-mo, particles, calligraphy burst on killing blow.
- Victory scroll: shows run time, HP%, gold, technique list, wuxia title.
- Defeat screen: shows "Defeated" with restart.
- Balance: fights feel 2-4 minutes (duel), 3-5 minutes (boss). Gold buys 3-4 shop items per run.

---

### Task 1: Main Menu Scene

**Files:**
- Modify: `WUGodot/scripts/main.gd`

- [ ] **Step 1: Add MAIN_MENU and VICTORY to SceneType**

Replace the `SceneType` enum (lines 5-14):

```gdscript
enum SceneType {
	MAIN_MENU,
	MAP,
	COMBAT,
	REWARD,
	EVENT,
	SHOP,
	REST,
	FORGET_TECHNIQUE,
	VICTORY,
	GAME_OVER,
}
```

- [ ] **Step 2: Add run tracking variables**

After `_combat_gold_multiplier` (line 38):

```gdscript
var _run_start_time: float = 0.0
var _run_end_time: float = 0.0
var _run_gold_earned: int = 0
var _run_techniques_acquired: Array[String] = []
```

- [ ] **Step 3: Modify _ready to start at MAIN_MENU**

Replace `_ready()` (lines 43-50):

```gdscript
func _ready() -> void:
	Engine.max_fps = GameConstants.TARGET_FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DataManager.initialize()
	_current_scene = SceneType.MAIN_MENU
	_combat_scene.combat_end.connect(_on_combat_end)
	_combat_scene.deactivate()
	queue_redraw()
	_sync_input_tracker()
```

- [ ] **Step 4: Update start_new_run to track time**

In `start_new_run()`, add after the `_combat_gold_multiplier = 1` line:

```gdscript
	_run_start_time = Time.get_ticks_msec() / 1000.0
	_run_end_time = 0.0
	_run_gold_earned = 0
	_run_techniques_acquired.clear()
```

- [ ] **Step 5: Add MAIN_MENU and VICTORY to _process match**

Replace the `match _current_scene:` block:

```gdscript
	match _current_scene:
		SceneType.MAIN_MENU:
			_update_main_menu()
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
		SceneType.VICTORY:
			_update_victory()
		SceneType.GAME_OVER:
			_update_game_over()
```

- [ ] **Step 6: Add _update_main_menu**

Add before `_update_map()`:

```gdscript
func _update_main_menu() -> void:
	if _accept_pressed() or _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		start_new_run()
		_current_scene = SceneType.MAP
```

- [ ] **Step 7: Update Escape and R handlers for menu flow**

Replace the Escape handler (lines 81-84):

```gdscript
	if Input.is_key_pressed(KEY_ESCAPE):
		if _current_scene == SceneType.MAIN_MENU or _current_scene == SceneType.MAP or _current_scene == SceneType.GAME_OVER:
			get_tree().quit()
			return
```

Scope the R restart handler (lines 89-93) to only work during MAP and COMBAT:

```gdscript
	if _input_tracker.pressed_key(KEY_R):
		if _current_scene == SceneType.MAP or _current_scene == SceneType.COMBAT:
			start_new_run()
			_current_scene = SceneType.MAP
			_sync_input_tracker()
			queue_redraw()
			return
```

- [ ] **Step 8: Commit**

```bash
git add WUGodot/scripts/main.gd
git commit -m "feat: add MAIN_MENU and VICTORY scene types, boot to main menu"
```

---

### Task 2: Victory Screen — Run Stats and Wuxia Title

**Files:**
- Modify: `WUGodot/scripts/main.gd`

- [ ] **Step 1: Update _on_combat_end for gold tracking and victory routing**

Replace `_on_combat_end()`:

```gdscript
func _on_combat_end(victory: bool) -> void:
	_combat_scene.on_exit()
	_combat_scene.deactivate()

	if victory:
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
		var gold_gained: int = base_gold * _combat_gold_multiplier
		_player.gold += gold_gained
		_run_gold_earned += gold_gained

		if node != null and node.node_type == MapNode.NodeType.AMBUSH:
			node.ambush_remaining -= 1
			if node.ambush_remaining > 0:
				_combat_scene.setup_combat(_player, node)
				_combat_scene.on_enter()
				_current_scene = SceneType.COMBAT
				return

		_run_state.mark_current_node_cleared()
		if node != null and node.node_type == MapNode.NodeType.BOSS:
			_run_end_time = Time.get_ticks_msec() / 1000.0
			_current_scene = SceneType.VICTORY
		else:
			_current_scene = SceneType.REWARD
	else:
		_run_end_time = Time.get_ticks_msec() / 1000.0
		_current_scene = SceneType.GAME_OVER
		_end_message = "Defeated"
```

- [ ] **Step 2: Add _update_victory**

Add after `_update_forget_technique()`:

```gdscript
func _update_victory() -> void:
	if _accept_pressed() or _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		_current_scene = SceneType.MAIN_MENU
```

- [ ] **Step 3: Track technique acquisitions**

In `_apply_reward_by_index()`, add after `selected.apply(_player)`:

```gdscript
	if selected.technique_id != "" and not _run_techniques_acquired.has(selected.technique_id):
		_run_techniques_acquired.append(selected.technique_id)
```

In `_resolve_event_choice()`, add after `_event_showing_result = true`:

```gdscript
	var granted: String = str(_event_result.get("granted_technique", ""))
	if not granted.is_empty() and not _run_techniques_acquired.has(granted):
		_run_techniques_acquired.append(granted)
```

In `_update_shop()`, after the successful technique purchase block (where `_shop_items.remove_at` is called for technique type), add:

```gdscript
				var bought_id: String = str(item.get("technique_id", ""))
				if not bought_id.is_empty() and not _run_techniques_acquired.has(bought_id):
					_run_techniques_acquired.append(bought_id)
```

- [ ] **Step 4: Update _draw to handle new scenes**

Replace the `_draw()` method:

```gdscript
func _draw() -> void:
	match _current_scene:
		SceneType.MAIN_MENU:
			_draw_main_menu()
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
		SceneType.VICTORY:
			_draw_victory()
		SceneType.GAME_OVER:
			_draw_game_over()
```

- [ ] **Step 5: Add _draw_main_menu**

```gdscript
func _draw_main_menu() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color8(10, 10, 14), true)

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var title_y: float = float(GameConstants.VIEW_HEIGHT) * 0.3

	# Title: WU in large calligraphy style
	_draw_text("武", center_x - 40.0, title_y, Color(0.95, 0.92, 0.85, 0.95), 80)
	_draw_text("W U", center_x - 30.0, title_y + 60.0, Color(0.7, 0.68, 0.62, 0.8), 28)

	# Subtitle
	_draw_text("A Sekiro-paced wuxia duel roguelike", center_x - 180.0, title_y + 110.0, Color(0.55, 0.54, 0.5, 0.7), 16)

	# Start prompt
	var prompt_pulse: float = 0.5 + 0.5 * sin(_cursor_flash * 4.0)
	_draw_text("Press Enter to begin", center_x - 100.0, float(GameConstants.VIEW_HEIGHT) * 0.65, Color(0.8, 0.78, 0.7, prompt_pulse), 20)

	# Version / credits
	_draw_text("Chapter 1: Jianghu", center_x - 80.0, float(GameConstants.VIEW_HEIGHT) - 80.0, Color(0.4, 0.38, 0.35, 0.5), 14)

	# Decorative border lines
	var border_color: Color = Color(0.3, 0.28, 0.22, 0.3)
	draw_rect(Rect2(60.0, 60.0, float(GameConstants.VIEW_WIDTH) - 120.0, 2.0), border_color)
	draw_rect(Rect2(60.0, float(GameConstants.VIEW_HEIGHT) - 62.0, float(GameConstants.VIEW_WIDTH) - 120.0, 2.0), border_color)
	draw_rect(Rect2(60.0, 60.0, 2.0, float(GameConstants.VIEW_HEIGHT) - 120.0), border_color)
	draw_rect(Rect2(float(GameConstants.VIEW_WIDTH) - 62.0, 60.0, 2.0, float(GameConstants.VIEW_HEIGHT) - 120.0), border_color)
```

- [ ] **Step 6: Add _draw_victory**

```gdscript
func _draw_victory() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color8(12, 11, 16), true)

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5

	# Scroll panel
	var scroll: Rect2 = Rect2(center_x - 340.0, 80.0, 680.0, float(GameConstants.VIEW_HEIGHT) - 160.0)
	draw_rect(scroll, Color8(28, 26, 22, 240), true)
	# Scroll border (gold trim)
	var gold: Color = GameConstants.COLOR_GOLD_DARK
	draw_rect(Rect2(scroll.position.x, scroll.position.y, scroll.size.x, 3.0), gold)
	draw_rect(Rect2(scroll.position.x, scroll.end.y - 3.0, scroll.size.x, 3.0), gold)
	draw_rect(Rect2(scroll.position.x, scroll.position.y, 3.0, scroll.size.y), gold)
	draw_rect(Rect2(scroll.end.x - 3.0, scroll.position.y, 3.0, scroll.size.y), gold)

	var y: float = scroll.position.y + 50.0
	var left: float = scroll.position.x + 40.0

	# Wuxia title
	_draw_text("江湖初顯", center_x - 60.0, y, Color(0.95, 0.88, 0.65, 0.95), 36)
	y += 40.0
	_draw_text("The Wanderer Emerges", center_x - 100.0, y, Color(0.75, 0.72, 0.65, 0.8), 18)
	y += 60.0

	# Separator
	draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(0.5, 0.45, 0.35, 0.4))
	y += 30.0

	# Run stats
	var run_duration: float = _run_end_time - _run_start_time
	var minutes: int = int(run_duration) / 60
	var seconds: int = int(run_duration) % 60
	_draw_text("Run Duration", left, y, Color(0.6, 0.58, 0.52, 0.7), 14)
	_draw_text("%d:%02d" % [minutes, seconds], left + 200.0, y, Color(0.9, 0.88, 0.8, 0.9), 16)
	y += 30.0

	var hp_pct: int = int(round(_player.health_current / maxf(_player.health_max, 1.0) * 100.0))
	_draw_text("Final HP", left, y, Color(0.6, 0.58, 0.52, 0.7), 14)
	_draw_text("%d%%" % hp_pct, left + 200.0, y, Color(0.9, 0.88, 0.8, 0.9), 16)
	y += 30.0

	_draw_text("Gold Earned", left, y, Color(0.6, 0.58, 0.52, 0.7), 14)
	_draw_text("%d" % _run_gold_earned, left + 200.0, y, Color(1.0, 0.85, 0.3, 0.9), 16)
	y += 40.0

	# Techniques acquired
	draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(0.5, 0.45, 0.35, 0.4))
	y += 20.0
	_draw_text("Techniques Mastered", left, y, Color(0.6, 0.58, 0.52, 0.7), 14)
	y += 24.0

	if _run_techniques_acquired.is_empty():
		_draw_text("(none)", left + 20.0, y, Color(0.5, 0.48, 0.44, 0.6), 14)
		y += 20.0
	else:
		for tech_id in _run_techniques_acquired:
			var tech_data: Dictionary = DataManager.get_technique(tech_id)
			var cn: String = str(tech_data.get("name_cn", ""))
			var en: String = str(tech_data.get("name_en", tech_id))
			_draw_text("%s %s" % [cn, en], left + 20.0, y, Color(0.85, 0.82, 0.75, 0.85), 15)
			y += 22.0

	# Teaser
	y = scroll.end.y - 80.0
	draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(0.5, 0.45, 0.35, 0.4))
	y += 20.0
	_draw_text("The road beyond the bamboo leads deeper into the jianghu...", left, y, Color(0.5, 0.48, 0.42, 0.6), 13)

	# Return prompt
	var pulse: float = 0.5 + 0.5 * sin(_cursor_flash * 4.0)
	_draw_text("Press Enter to return", center_x - 90.0, scroll.end.y + 30.0, Color(0.7, 0.68, 0.6, pulse), 16)
```

- [ ] **Step 7: Improve _draw_game_over for defeat**

Replace `_draw_game_over()`:

```gdscript
func _draw_game_over() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color8(14, 10, 10), true)

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var center_y: float = float(GameConstants.VIEW_HEIGHT) * 0.5

	# Defeat kanji
	_draw_text("敗", center_x - 30.0, center_y - 60.0, Color(0.6, 0.2, 0.15, 0.8), 60)
	_draw_text("Defeated", center_x - 50.0, center_y + 10.0, Color(0.7, 0.3, 0.25, 0.7), 22)

	# Run duration
	var run_duration: float = _run_end_time - _run_start_time
	var minutes: int = int(run_duration) / 60
	var seconds: int = int(run_duration) % 60
	_draw_text("Time: %d:%02d" % [minutes, seconds], center_x - 50.0, center_y + 60.0, Color(0.5, 0.45, 0.4, 0.6), 14)

	# Return prompt
	var pulse: float = 0.5 + 0.5 * sin(_cursor_flash * 4.0)
	_draw_text("Press Enter to return", center_x - 90.0, center_y + 120.0, Color(0.6, 0.55, 0.5, pulse), 16)
```

- [ ] **Step 8: Update _update_game_over to return to MAIN_MENU**

Replace `_update_game_over()`:

```gdscript
func _update_game_over() -> void:
	if _accept_pressed() or _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		_current_scene = SceneType.MAIN_MENU
```

- [ ] **Step 9: Commit**

```bash
git add WUGodot/scripts/main.gd
git commit -m "feat: add Victory scroll with run stats and improved Defeat screen"
```

---

### Task 3: Boss Death Slow-Mo Beat

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd`

- [ ] **Step 1: Add boss death state**

In `WUGodot/scripts/combat_scene.gd`, add after `_heavy_committed_attack` (line 31):

```gdscript
var _boss_death_timer: float = 0.0
var _boss_death_triggered: bool = false
```

- [ ] **Step 2: Replace the death detection block**

Replace the death detection block (lines 167-174) with:

```gdscript
		if _player.health_current <= 0.0:
			_is_paused_on_end = true
			_end_message = "Defeat (Enter: continue)"
		elif _enemy.health_current <= 0.0:
			if _player.technique_engine != null:
				_player.technique_engine.on_kill(_player)
			if _current_node.node_type == MapNode.NodeType.BOSS:
				_boss_death_triggered = true
				_boss_death_timer = 1.0
				_trigger_slow_mo(0.2, 1.0)
				_on_camera_shake(20.0)
				_show_feedback("破山!", 1.2)
				_particle_system.spawn_hit_sparks(_enemy.position + Vector2(0.0, -_enemy.height * 0.5), 40, Color8(255, 200, 80))
				_particle_system.spawn_hit_sparks(_enemy.position + Vector2(0.0, -_enemy.height * 0.3), 20, Color8(255, 120, 40))
			else:
				_is_paused_on_end = true
				_end_message = "Victory (Enter)"
```

Additionally, insert a guard at the top of the combat simulation block. After the hitstop/slow-mo/time-scale section (before `_combat_system.update_facing`), add:

```gdscript
	# During boss death beat, freeze combat but keep visuals ticking
	if _boss_death_triggered:
		_boss_death_timer -= delta
		if _boss_death_timer <= 0.0:
			_is_paused_on_end = true
			_end_message = "Boss Defeated (Enter)"
		if not _is_paused:
			_camera.update(delta)
			_particle_system.update(dt)
			_damage_number_system.update(dt)
		_sync_input_tracker()
		queue_redraw()
		return
```

This goes right before the `_combat_system.update_facing(_player, _enemy)` line. When `_boss_death_triggered` is true, the function returns early — no player input, no AI, no hit resolution. Only camera, particles, and damage numbers keep updating for visual effect.

- [ ] **Step 3: Reset boss death state in setup_combat**

In `setup_combat()`, add after `_heavy_committed_attack = false` (line 79):

```gdscript
	_boss_death_timer = 0.0
	_boss_death_triggered = false
```

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "feat: add boss death slow-mo beat with particle burst and calligraphy"
```

---

### Task 4: Balance Tuning Pass

**Files:**
- Modify: `WUGodot/data/Settings/GameSettings.json`
- Modify: `WUGodot/data/Enemies/BanditSwordsman.json`
- Modify: `WUGodot/data/Enemies/BanditSpearman.json`
- Modify: `WUGodot/data/Enemies/WanderingRonin.json`
- Modify: `WUGodot/data/Enemies/SectDisciple.json`
- Modify: `WUGodot/data/Enemies/MaskedAssassin.json`
- Modify: `WUGodot/data/Enemies/IronBear.json`

The balance targets from the spec:
- Duel fights: 2-4 minutes
- Boss fight: 3-5 minutes
- A typical run visits ~7-8 nodes, earning ~120-150g total, enough for 3-4 shop purchases
- Parry should feel generous but rewarding (0.15s window per spec)
- Posture recovery should be slow enough that pressure matters but fast enough that the player doesn't feel stuck

- [ ] **Step 1: Update GameSettings.json**

Replace `WUGodot/data/Settings/GameSettings.json`:

```json
{
  "selectedCharacter": "Hu",
  "viewWidth": 1920,
  "viewHeight": 1080,
  "targetFPS": 60,

  "groundY": 940.0,
  "worldBoundsLeft": 80.0,
  "worldBoundsRight": 1840.0,

  "defaultPostureRecoveryRate": 10.0,
  "parryWindow": 0.15,
  "stunDuration": 0.7,
  "groundMoveControl": 0.25,
  "airMoveControl": 0.12,
  "attackMoveControlMultiplier": 2.0,
  "blockHealthMultiplier": 0.2,
  "blockPostureMultiplier": 1.5,
  "parryPostureDamage": 50.0,
  "parryStunDuration": 0.6,

  "cameraShakeDecay": 20.0,
  "timeScaleRecovery": 0.08,
  "maxParticles": 100,

  "damageNumberLifetime": 1.0,
  "damageNumberSpeed": 60.0,
  "damageNumberGravity": 120.0
}
```

Changes from previous (these affect enemy/fallback defaults — the player character Hu.json already has parryWindow=0.15 and postureRecoveryRate=12.0, so these settings don't override player feel):
- `parryWindow`: 0.12 → 0.15 (align fallback with spec; Hu.json already at 0.15)
- `defaultPostureRecoveryRate`: 12.0 → 10.0 (affects enemies without explicit recovery — makes enemy posture pressure more meaningful)
- `blockPostureMultiplier`: 1.6 → 1.5 (slightly less punishing block posture for both player and enemies)
- `parryPostureDamage`: 55.0 → 50.0 (parry reward reduced slightly for both sides)

- [ ] **Step 2: Update enemy data for fight-length targets**

Replace `WUGodot/data/Enemies/BanditSwordsman.json`:

```json
{
  "archetype": "bandit_swordsman",
  "name": "Bandit Swordsman",
  "name_cn": "匪劍",
  "difficulty": "easy",
  "visualProfile": "enemy_humanoid_basic",
  "moveSpeed": 200.0,
  "jumpForce": 700.0,
  "gravity": 2800.0,
  "healthMax": 80.0,
  "postureMax": 85.0,
  "postureRecoveryRate": 8.0,
  "attackRange": 72.0,
  "halfWidth": 22.0,
  "height": 88.0,
  "colorBody": "#FF7878",
  "colorAccent": "#D23C3C",
  "pattern_table": ["bandit_slash", "bandit_thrust_perilous", "bandit_overhead"],
  "aggression": 0.45,
  "blockChance": 0.2,
  "preferredRange": 72.0,
  "retreatChance": 0.02,
  "dashChance": 0.03
}
```

Changes: healthMax 90→80, postureMax 100→85, postureRecoveryRate 10→8, aggression 0.5→0.45, blockChance 0.25→0.2. Target: ~2 min fights.

Replace `WUGodot/data/Enemies/BanditSpearman.json`:

```json
{
  "archetype": "bandit_spearman",
  "name": "Bandit Spearman",
  "name_cn": "匪槍",
  "difficulty": "easy",
  "visualProfile": "enemy_humanoid_basic",
  "moveSpeed": 180.0,
  "jumpForce": 650.0,
  "gravity": 2800.0,
  "healthMax": 75.0,
  "postureMax": 80.0,
  "postureRecoveryRate": 7.0,
  "attackRange": 110.0,
  "halfWidth": 22.0,
  "height": 90.0,
  "colorBody": "#C89664",
  "colorAccent": "#966432",
  "pattern_table": ["spear_long_thrust", "spear_wide_swing"],
  "aggression": 0.4,
  "blockChance": 0.15,
  "preferredRange": 110.0,
  "retreatChance": 0.04,
  "dashChance": 0.02
}
```

Changes: healthMax 80→75, postureMax 90→80, postureRecoveryRate 9→7. Spearman is fragile but annoying at range.

Replace `WUGodot/data/Enemies/WanderingRonin.json`:

```json
{
  "archetype": "wandering_ronin",
  "name": "Wandering Ronin",
  "name_cn": "浪人",
  "difficulty": "medium",
  "visualProfile": "enemy_humanoid_elite",
  "moveSpeed": 300.0,
  "jumpForce": 750.0,
  "gravity": 2800.0,
  "healthMax": 110.0,
  "postureMax": 100.0,
  "postureRecoveryRate": 10.0,
  "attackRange": 80.0,
  "halfWidth": 22.0,
  "height": 90.0,
  "colorBody": "#8888CC",
  "colorAccent": "#5555AA",
  "pattern_table": ["ronin_slash", "ronin_thrust", "ronin_sweep", "ronin_perilous_thrust"],
  "aggression": 0.55,
  "blockChance": 0.3,
  "preferredRange": 80.0,
  "retreatChance": 0.03,
  "dashChance": 0.06
}
```

Changes: healthMax 120→110, aggression 0.6→0.55, blockChance 0.35→0.3. Target: ~3 min fights.

Replace `WUGodot/data/Enemies/SectDisciple.json`:

```json
{
  "archetype": "sect_disciple",
  "name": "Sect Disciple",
  "name_cn": "門徒",
  "difficulty": "hard",
  "visualProfile": "enemy_humanoid_elite",
  "moveSpeed": 380.0,
  "jumpForce": 780.0,
  "gravity": 2800.0,
  "healthMax": 130.0,
  "postureMax": 120.0,
  "postureRecoveryRate": 12.0,
  "attackRange": 78.0,
  "halfWidth": 24.0,
  "height": 92.0,
  "colorBody": "#FFAA6E",
  "colorAccent": "#E65C00",
  "pattern_table": ["disciple_slash", "disciple_thrust", "disciple_sweep", "disciple_counter", "disciple_jump_attack"],
  "aggression": 0.65,
  "blockChance": 0.4,
  "preferredRange": 78.0,
  "retreatChance": 0.03,
  "dashChance": 0.08
}
```

Changes: aggression 0.7→0.65, blockChance 0.45→0.4. Target: ~3-4 min fights. Still the toughest non-boss.

Replace `WUGodot/data/Enemies/MaskedAssassin.json`:

```json
{
  "archetype": "masked_assassin",
  "name": "Masked Assassin",
  "name_cn": "面刺客",
  "difficulty": "hard",
  "visualProfile": "enemy_humanoid_elite",
  "moveSpeed": 420.0,
  "jumpForce": 800.0,
  "gravity": 2800.0,
  "healthMax": 90.0,
  "postureMax": 85.0,
  "postureRecoveryRate": 9.0,
  "attackRange": 68.0,
  "halfWidth": 20.0,
  "height": 86.0,
  "colorBody": "#444466",
  "colorAccent": "#222244",
  "pattern_table": ["smoke_thrust", "flicker_slash", "assassin_backstab", "assassin_perilous_grab"],
  "aggression": 0.6,
  "blockChance": 0.2,
  "preferredRange": 68.0,
  "retreatChance": 0.06,
  "dashChance": 0.12,
  "teleport_chance": 0.06
}
```

Changes: healthMax 100→90, postureMax 90→85, aggression 0.65→0.6, teleport_chance 0.08→0.06. Glass cannon — hard-hitting but killable fast if you read the teleports.

Replace `WUGodot/data/Enemies/IronBear.json`:

```json
{
  "archetype": "iron_bear",
  "name": "Xiong Tie",
  "name_cn": "熊鐵",
  "difficulty": "boss",
  "visualProfile": "enemy_humanoid_boss",
  "moveSpeed": 240.0,
  "jumpForce": 600.0,
  "gravity": 2800.0,
  "healthMax": 280.0,
  "postureMax": 160.0,
  "postureRecoveryRate": 14.0,
  "attackRange": 90.0,
  "halfWidth": 30.0,
  "height": 104.0,
  "colorBody": "#CC6644",
  "colorAccent": "#884422",
  "pattern_table": ["bear_swipe", "bear_overhead", "bear_stomp", "bear_crush_grab"],
  "aggression": 0.5,
  "blockChance": 0.15,
  "preferredRange": 90.0,
  "retreatChance": 0.01,
  "dashChance": 0.03
}
```

Changes: healthMax 300→280, postureRecoveryRate 16→14, aggression 0.55→0.5. Target: 3-5 min boss fight. Slightly less HP but also slightly less recovery, so posture-break strategies are more viable.

- [ ] **Step 3: Run tests to verify no regressions**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All 132 tests pass (balance changes are JSON-only, no code affected).

- [ ] **Step 4: Commit**

```bash
git add WUGodot/data/Settings/GameSettings.json WUGodot/data/Enemies/
git commit -m "balance: tune combat timing, parry window, posture recovery, and enemy stats"
```

---

### Task 5: Manual Playtest Checklist

- [ ] **Step 1: Manual playtest**

Run the game: `HOME=/tmp/godot-home godot --path WUGodot`

Verify each item (pass/fail):

**Main menu:**
- [ ] Game boots to main menu showing "武 WU" title
- [ ] Subtitle and "Press Enter to begin" visible
- [ ] Pressing Enter starts a new run and transitions to map
- [ ] Escape on main menu quits the game
- [ ] Decorative border frame visible

**Full run loop:**
- [ ] Start → map → select node → combat → reward → map → repeat
- [ ] All 8 node types function (Duel, Elite, Ambush, Master, Event, Shop, Rest, Boss)
- [ ] Boss node leads to Victory screen (not Game Over)
- [ ] Non-boss death leads to Defeat screen
- [ ] Victory screen → Enter → main menu
- [ ] Defeat screen → Enter → main menu
- [ ] Main menu → Enter → fresh new run

**Victory scroll:**
- [ ] Gold-bordered scroll panel visible
- [ ] "江湖初顯 / The Wanderer Emerges" title
- [ ] Run duration in M:SS format
- [ ] Final HP percentage
- [ ] Total gold earned
- [ ] List of techniques acquired (Chinese + English names)
- [ ] Teaser line: "The road beyond the bamboo..."
- [ ] "Press Enter to return" prompt pulses

**Defeat screen:**
- [ ] "敗 / Defeated" in red tones
- [ ] Run duration shown
- [ ] "Press Enter to return" prompt pulses
- [ ] Returns to main menu (not immediate restart)

**Boss death beat:**
- [ ] On boss killing blow: time slows to ~0.2x for ~1 second
- [ ] "破山!" feedback text appears
- [ ] Large particle burst around boss
- [ ] Camera shake on death
- [ ] After slow-mo completes, combat pauses with end message

**Balance feel:**
- [ ] Bandit Swordsman: ~2 min fight, parry-friendly
- [ ] Bandit Spearman: ~2 min fight, reach forces spacing
- [ ] Wandering Ronin: ~3 min fight, perilous thrust requires dash
- [ ] Sect Disciple: ~3-4 min fight, aggressive mirror-match
- [ ] Masked Assassin: ~3-4 min fight, teleports keep player reactive
- [ ] Iron Bear: ~3-5 min fight, Bear Crush and Mountain-Breaker force movement
- [ ] Parry window feels generous (0.15s)
- [ ] Posture breaks happen regularly but require sustained pressure
- [ ] Gold economy: ~120-150g per run, enough for 3-4 shop purchases
- [ ] A full run takes ~15-25 minutes

---

## Review Cycle Audit

After implementation, verify:

1. **All 132 existing tests pass.** No code logic changed in combat or technique systems.
2. **Main menu is the entry point.** `_ready()` no longer calls `start_new_run()` — player must press Enter.
3. **Victory/Defeat both return to main menu.** Neither loops directly back to gameplay.
4. **Boss death beat doesn't skip.** The 1-second slow-mo fully plays before the pause screen appears.
5. **Gold tracking is cumulative.** `_run_gold_earned` accumulates across all combats in the run.
6. **Balance changes are JSON-only.** If any test fails, the JSON changes may have violated hardcoded test expectations — check test_boss_controller.gd assertions against IronBear.json HP changes.
