# In-Game Pause Menu (Esc) — Design

**Date:** 2026-06-30
**Status:** draft (pre-plan) — for user review
**Origin:** playtest of `b2d467b`. Esc currently instant-quits the game (and bleeds out of Settings). Decision: **Esc opens a unified in-game menu everywhere except the main menu**, and combat's `P`/`O` keys are removed in favor of it. **Supersedes** the Bug-1 edge-trigger fix in `2026-06-30-settings-input-bugfixes.md` (the bare Esc-quit is removed entirely); **incorporates** that doc's Bug 2 (J→Enter).

**Goal:** one consistent Esc menu — Resume / Settings / Quit to Title / Quit Game — that pauses play, replacing the dangerous instant-quit and the scattered combat-pause keys.

---

## 1. Behavior
- **Esc in any in-run scene** (combat, map, shop, rest, event, reward, boon_offer, forget) → open the **PauseMenu** (pauses combat). Items: **Resume · Settings · Quit to Title · Quit Game**.
- **Esc on the MAIN menu** → **Quit-confirm** ("Quit? Enter = yes / Esc = no"), not the in-game menu.
- **Esc precedence** (all edge-triggered, no held-key bleed):
  1. SettingsView capture active → Esc cancels the capture (existing behavior).
  2. PauseMenu's Settings sub-view open → Esc → back to PauseMenu.
  3. PauseMenu open → Esc → Resume (close, unpause).
  4. In-run scene, menu closed → Esc → open PauseMenu.
  5. Main menu → Esc → toggle Quit-confirm.
- **Menu actions:** Resume → close + unpause · Settings → open SettingsView (back → PauseMenu) · Quit to Title → tear down the run, `goto(MAIN_MENU)` (run abandoned — no save exists; deliberate pick) · Quit Game → `get_tree().quit()`.
- **Confirm:** menu open pauses combat fully (no sim advance). Selection via Up/Down (+ W/S), confirm via **Enter / click** (not J — see §4).

## 2. Architecture (reuse the SettingsView two-host pattern)
- **`PauseMenuView`** (new reusable view, like `settings_view.gd`/`loadout_view.gd`): draws the menu panel + handles selection/activation; `update(input) -> {action}` where action ∈ `{none, resume, open_settings, quit_title, quit_game}`; also hosts a SettingsView sub-state (so "Settings" opens within the overlay, Esc returns to the menu).
- **Two host sites** (mirrors how SettingsView is hosted by both `settings_scene` and `combat_scene`):
  - **Combat** (`combat_scene.gd`, child node): Esc opens `PauseMenuView` as a sub-state (replacing the removed `_is_paused`/P + `_settings_open`/O machinery). Combat pauses while open. Quit-to-title emits a signal → `main.gd` tears down combat (`on_exit`/`deactivate`) + `goto(MAIN_MENU)`.
  - **Meta scenes** (`main.gd`, controller dispatch): a global `_game_menu_open` flag + a `PauseMenuView`. In `_process`, when Esc edge fires and `_current_scene` is in-run and the menu isn't open → open it and **stop calling `controller.update`** (pause). In `_draw`, after `controller.draw`, draw the PauseMenuView overlay when open. Route input to the view while open (incl. the raw-key forward for SettingsView capture, extending the existing `_unhandled_input`).
- **Main menu confirm:** a small Quit-confirm (reuse a 2-option PauseMenuView variant, or a dedicated prompt in `menu_scene`).

## 3. Removals
- `main.gd:85` instant `Input.is_key_pressed(KEY_ESCAPE)` → `get_tree().quit()` block — **deleted** (replaced by §1).
- Combat **`KEY_P`** pause toggle (`combat_scene.gd:373-385`) and **`KEY_O`** settings open (`:410`) — **deleted**; Esc replaces both. The old pause overlay text ("Press P to resume…") is replaced by PauseMenuView.
- Keep `R` (restart) and `` ` `` (debug) as separate hotkeys (untouched; not part of this change).

## 4. Menu confirm key (Bug 2, folded in)
`menu_input.gd:22` — `accept = t.pressed_key(KEY_ENTER) or t.pressed_key(KEY_KP_ENTER)` (drop `KEY_J` and `KEY_SPACE`; mouse click stays via `mouse_clicked`). Update `map_scene.gd:83` hint `"Enter / J or click to travel"` → `"Enter or click to travel"`. Applies to all menus incl. the new PauseMenu.

## 5. Testing
- **Unit:** `PauseMenuView.update` returns the right action per selection; SettingsView sub-state open/back; quit-confirm Y/N.
- **Integration (headless):** Esc in a meta scene opens the menu and pauses `controller.update`; Esc again resumes; Quit-to-title routes to MAIN_MENU; in combat, Esc pauses the sim (no advance) and Resume continues; `menu_input.accept` excludes J/Space.
- **Visual:** capture the PauseMenu over **map** and over **combat** (`--capture {kind:ui,screen:map}` after opening — or a dedicated capture hook state; combat via a `kind:matchup` capture with a paused/menu state if the hook supports it). `assert_nonblank`.
- **Manual:** title→Settings→Esc (returns, no quit); in-run Esc→menu→each action; main-menu Esc→confirm.
- `./run.sh --test` green; existing settings/rebind tests still pass.

## 6. Out of scope
- Save/load (Quit-to-title abandons the run; no persistence exists).
- Moving Restart/Debug into the menu (separate).
- Controller/gamepad menu nav.

## 7. Sequencing
1. **Bug 2** (menu_input accept Enter/KP_Enter + map hint) — tiny, independent.
2. **`PauseMenuView`** (+ unit tests) with the 4 actions + SettingsView sub-state.
3. **Combat host** — remove P/O + old pause overlay; Esc → PauseMenuView; quit-to-title signal → main.
4. **Meta host** — `main.gd` `_game_menu_open` + Esc open/route/draw/pause; delete the `:85` instant-quit.
5. **Main-menu Esc** → quit-confirm.
6. Captures + manual pass.
