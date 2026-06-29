# Settings & Key Rebinding — Design

**Date:** 2026-06-25
**Status:** draft (pre-plan) — for user review
**Origin:** design-review finding **M1** (`docs/.../design-audit-20260624/design-audit-wu.md`) — "no settings / difficulty / key-rebind UX exists." This spec covers the **settings screen + persistence + key rebinding**; **difficulty selection is designed-but-deferred** (its own balance slice).

**Goal:** Give the player a real Settings surface — rebind the 7 combat controls and toggle fullscreen, persisted across sessions — reachable from the title menu and the in-run pause.

**Why:** Keys are hardcoded (`fighter.gd:140`, W/J/K/L/Space) with no way to change them, no settings screen, and nothing persists between sessions. This is the largest remaining UX gap from the live review.

---

## 1. Key insight — rebinding is cheap because the seam already exists

Input is **already indirected** through a per-fighter `controls` dictionary mapping action → Godot keycode:
```gdscript
# fighter.gd:140 (DEFAULT_CONTROLS) and Fighter.player_controls()
{"left": KEY_A, "right": KEY_D, "attack": KEY_J, "block": KEY_K, "dash": KEY_SPACE, "jump": KEY_W, "stance": KEY_L}
```
Combat reads keys via `_input_tracker.pressed_key(controls[action])`. So rebinding = **rewrite the dict's values + persist + a capture UI** — no Godot `InputMap` migration is required (the proposal's Phase A5 assumed one; this seam makes it unnecessary for v1). `Fighter.player_controls()` becomes "read from `SettingsManager`, falling back to the hardcoded defaults." The one input-layer change is switching these 7 reads from logical to **physical** keys for layout independence (§2c).

---

## 2. Architecture (4 components, each mirroring an existing pattern)

| Component | Pattern it mirrors | Responsibility |
|---|---|---|
| **`SettingsManager`** (static) | `DataManager` (static loader) | Own `user://settings.json`; load at boot, save on every change; expose keybinds, `try_bind`, `reset_defaults`, fullscreen. **First write to `user://` in the project** — no run save/load dependency. |
| **`SettingsView`** (reusable view) | `scripts/scenes/loadout_view.gd` | Draw the settings panel + handle selection / rebind-capture input. One implementation, used by both entry points. |
| **`SettingsScene`** (`SCENE_SETTINGS = 11`) | the `scripts/scenes/*_scene.gd` controllers | Title-menu entry; thin controller wrapping `SettingsView`; Esc → back to menu. |
| **Pause integration** | existing `_is_paused` overlay (`combat_scene.gd:373-385`) | Embed `SettingsView` as a pause sub-state (combat is long-lived; no teardown). On save, also push new binds into the live `_player.controls`. |

### 2a. Persistence — `SettingsManager`
- File: `user://settings.json` (JSON, matching the repo's JSON-everywhere convention).
- Schema:
```json
{"version": 1, "keybinds": {"left": 65, "right": 68, "attack": 74, "block": 75, "dash": 32, "jump": 87, "stance": 76}, "fullscreen": false}
```
  Stored values are **physical keycodes** (ints, the `KEY_*` enum referenced to US-QWERTY positions — see §2c). Round-trip is lossless.
- API (static):
  - `load() -> void` — read file; on missing/corrupt/old-version, fall back to defaults and rewrite. Called once at boot (`main.gd._ready` before first scene). **Must also apply the stored values at boot:** call `set_fullscreen(stored_fullscreen)` so the window mode is restored across sessions (not just kept in the dict).
  - `keybinds() -> Dictionary` — current action→physical-keycode map (defaults-merged so a newly-added action is always present). **Returns a deep copy** (`.duplicate(true)`), matching `DataManager`'s duplicate-return pattern, so callers can never alias the manager's internal dict (see §2d).
  - `try_bind(action: String, physical_keycode: int) -> Dictionary` — returns `{"ok": bool, "reason": String}`. Rejects reserved keys and duplicates (see §2b, §3). On ok, mutate the internal dict + `save()`.
  - `reset_defaults() -> void` — restore `Fighter.DEFAULT_CONTROLS`, `save()`.
  - `set_fullscreen(on: bool) -> void` — store + apply `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN/WINDOWED)` + `save()`.
  - `save() -> void` — write pretty JSON to `user://settings.json`.
- Defaults source: `Fighter.DEFAULT_CONTROLS` (extracted from the existing hardcoded dict; the values are reinterpreted as physical keycodes — the `KEY_A`/`KEY_W`/… constants already reference US-QWERTY positions) is the single source of truth for defaults; `SettingsManager` merges loaded values over a deep copy of it.
- `Fighter.player_controls()` returns `SettingsManager.keybinds()` (already a deep copy), so every player gets its own dict (no aliasing) and new combats pick up rebinds automatically.

### 2c. Physical keys (input-layer change)
The 7 rebindable combat controls use **physical** keys so WASD-style defaults sit in the same physical position on AZERTY/QWERTZ. Scope is contained to the combat controls; fixed/global keys (Esc, F5, Enter — same position on every layout) stay as-is.
- **`InputTracker`** gains a physical path: track the combat-control physical keycodes and expose `pressed_physical_key(keycode)` (backed by `Input.is_physical_key_pressed`). Combat input reads the 7 controls via this; menu-nav/global keys keep the existing logical `pressed_key`.
- **Capture** reads `event.physical_keycode` (not `event.keycode`).
- **Display** shows the player's actual layout label: `OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical_keycode))`, falling back to `OS.get_keycode_string(physical_keycode)`.

### 2d. Dictionary ownership
`keybinds()` and `player_controls()` return deep copies; `try_bind`/`reset_defaults` mutate only the manager's internal dict. The pause "live apply" copies `keybinds()` (a fresh dict) into `_player.controls` — so a mutation of `_player.controls` can never alias the manager or `DEFAULT_CONTROLS`.

### 2b. Reserved keys (never bindable)
The **globally-intercepted** keys that `main.gd`/`menu_input.gd` act on regardless of scene: `KEY_ESCAPE` (quit/cancel), **`KEY_F5` (`reload_data` → `DataManager.reload_data()`, `menu_input.gd:25` + `main.gd`)**, `KEY_R` (restart), `KEY_P` (pause), `KEY_QUOTELEFT` (debug toggle), `KEY_ENTER`/`KEY_KP_ENTER` (accept). Binding a combat action to any of these would double-fire a global action, so `try_bind` rejects them with `reason = "Reserved key"`. (Menu-nav letters W/A/S/D are NOT reserved — they're the movement defaults and only mean "nav" inside menu scenes.) The reserved check compares against the captured **physical** keycode.

---

## 3. Rebind UX (in `SettingsView`)

Panel sections, top to bottom:
1. **Keybindings** — 7 rows, one per combat action, label + current key name (layout label via `OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical_keycode))`):
   `Move Left · Move Right · Attack · Block / Parry · Dash · Jump · Stance`
2. **Display** — `Fullscreen: On/Off` toggle row.
3. **Difficulty: Normal** — **disabled** row, hint "Coming soon" (marks the surface; see §5).
4. **Reset to Defaults** — restores `Fighter.DEFAULT_CONTROLS`.

**Interaction:**
- Up/Down (or W/S) move selection; Enter/click activates the row.
- Activating a keybinding row → **capture mode**: row shows "Press a key…". The next pressed `InputEventKey` calls `try_bind(action, event.physical_keycode)`:
  - ok → row updates to the new key.
  - reserved → flash `reason` ("Reserved key"), stay in capture.
  - **conflict (key already bound to another combat action) → reject-and-warn**: flash "Already bound to {Action}", stay in capture. (Chosen over silent swap: no surprise side effects. Swap is the documented alternative if play-testing wants it.)
  - Esc cancels capture (keeps the old bind).
- Activating Fullscreen toggles it immediately (applies + persists).
- Activating Reset restores defaults immediately (persists).
- Esc (when not capturing) exits Settings: `SettingsScene` → title menu; pause overlay → back to paused combat.

**Live apply from pause:** when a bind changes while reached from the pause overlay, `SettingsManager.save()` runs **and** the combat scene copies `SettingsManager.keybinds()` (a fresh deep copy) into `_player.controls` so the rebind takes effect on resume without restarting the run.

### 3a. Capture mechanism — raw event forwarding (required)
Scene controllers today only receive a **polled** `MenuInput` built from a fixed `InputTracker` key list (`main.gd:86`, `combat_scene.gd:_sync_input_tracker`) — they never see arbitrary key events, so capture cannot work via the normal input path. The host node must **forward raw key events** while capturing:
- `SettingsView` exposes `is_capturing() -> bool` and `feed_key_event(event: InputEventKey) -> void`.
- The host (`Main` for `SettingsScene`, `CombatScene` for the pause sub-state) implements `_unhandled_input(event)`: when the settings view `is_capturing()` and `event is InputEventKey and event.pressed and not event.echo`, call `feed_key_event(event)` and `get_viewport().set_input_as_handled()` (so the keypress doesn't also trigger gameplay/menu nav). When not capturing, normal polled input proceeds unchanged.
- This is the only place the project reads raw events instead of the polled tracker; it's scoped to capture mode only.

---

## 4. Entry points

- **Title menu** (`menu_scene.gd`): today it's a single "Press Enter to begin". Add a small vertical menu — `Begin` / `Settings` — with selection (Up/Down, Enter). `Settings` → `ctx.goto(SCENE_SETTINGS)`. (Keep the existing art; this adds a 2-item selector near the existing prompt.)
- **In-run pause** (`combat_scene.gd`): the pause overlay gains a `Settings` affordance (a labeled key, e.g. "O: settings" alongside "P: resume"). Opening sets a `_settings_open` sub-state that routes input/draw to `SettingsView`; Esc returns to the paused overlay.

---

## 5. Difficulty — designed, deferred (NOT built here)

Documented so the next slice is a drop-in; the Settings row is disabled until then.
- **Tiers:** `Tranquil` (easy) / `Wanderer` (normal, default) / `Demon` (hard).
- **What a tier scales (data multipliers, not new systems):** enemy HP %, enemy aggression / blockChance, posture-damage-taken by the player, and optionally reward generosity. Applied as multipliers over the existing `data/Enemies/*.json` + `DifficultyCurve.json`.
- **Default = today's calibrated balance = `Wanderer`** (this session's rebalance is normal).
- **Validation:** each tier must still pass `python3 WUGodot/tools/check_difficulty_curve.py` at its own target band; reuse the playtest harness with a `--difficulty` knob.
- **Persistence:** add `"difficulty": "wanderer"` to the settings schema (the `version` field already allows additive migration).
- Out of scope reason: tiers need a balance-tuning sub-project; bundling it would turn a tractable UX spec into a balance spec.

---

## 6. Components summary
- **New:** `scripts/settings_manager.gd` (static), `scripts/scenes/settings_view.gd` (reusable view), `scripts/scenes/settings_scene.gd` (controller), `SCENE_SETTINGS = 11` in `scene_context.gd`, `Fighter.DEFAULT_CONTROLS` extracted as the named default, a `"settings"` case in `main.gd._prepare_capture_ui`.
- **Modified:** `fighter.gd` (`player_controls()` reads `SettingsManager`, deep-copy return), `scripts/ui/input_tracker.gd` (physical-key path: track combat-control physical keycodes + `pressed_physical_key`), combat input read sites (7 controls → `pressed_physical_key`), `menu_scene.gd` (Begin/Settings selector), `combat_scene.gd` (pause → settings sub-state + `_unhandled_input` capture-forward + live `_player.controls` refresh + **`_draw_controls_legend` renders current key names** via the physical→label mapping instead of the hardcoded "A/D move W jump …" string), `main.gd` (`SettingsManager.load()` at boot incl. fullscreen apply + `_unhandled_input` capture-forward + scene routing + capture UI), `scene_context.gd` (scene id + routing).

## 7. Testing
- **Unit (headless):** `SettingsManager` load/save round-trip (write → reload → equal); `try_bind` returns ok for a free physical key, `reason="Already bound to …"` for a duplicate, `reason="Reserved key"` for **Esc / F5 / R / P / ` / Enter**; `reset_defaults()` restores `DEFAULT_CONTROLS`; corrupt/missing file falls back to defaults without throwing. Use a temp `user://` path.
- **Aliasing (P2):** mutating a dict returned by `keybinds()` (or a player's `_player.controls`) does NOT change `SettingsManager`'s internal state or `Fighter.DEFAULT_CONTROLS` (proves deep-copy ownership).
- **Fullscreen persistence:** after `set_fullscreen(true)` + `save()`, a fresh `load()` reports fullscreen true AND issues the `window_set_mode` apply (assert via a seam, e.g. a stored value + an applied-flag, since headless can't observe the real window).
- **Integration:** `Fighter.player_controls()` reflects a rebind after `try_bind` (and returns an independent copy each call).
- **Visual:** add `"settings"` to `_prepare_capture_ui` so `./run.sh --capture {"kind":"ui","screen":"settings"}` renders the panel for screenshot review (and `tools/assert_nonblank.py`).
- **No regression:** existing 542 tests stay green; combat input unaffected when `settings.json` is absent (defaults); the combat legend shows defaults when unbound.

## 8. Explicitly out of scope (YAGNI)
- Difficulty implementation (§5 design only).
- Audio/volume settings — no audio system exists yet (proposal B1).
- Gamepad/controller rebinding, multiple bindings per action, mouse-button binds.
- Resolution/windowed-size options beyond the fullscreen toggle.
- Run save/load — settings persistence is intentionally independent.

## 9. Sequencing (phases — full plan after approval)
1. **`SettingsManager` + persistence + tests** — static loader, schema, `try_bind`/reserved(incl. F5)/conflict logic, `reset_defaults`, boot `load()` incl. fullscreen apply; deep-copy `keybinds()`; `DEFAULT_CONTROLS` extracted. Unit tests first (TDD: round-trip, aliasing, reserved, fullscreen-persist).
2. **Physical-key input path** — `InputTracker.pressed_physical_key` + the 7 combat reads switch to physical; `Fighter.player_controls()` reads `SettingsManager` (deep copy). Regression: combat unaffected with no settings file.
3. **`SettingsView`** — render keybindings(layout labels)/display/reset rows + selection + rebind-capture + warnings; `is_capturing()`/`feed_key_event()`.
4. **Entry points + raw-capture wiring** — `SettingsScene` + `SCENE_SETTINGS` + title-menu Begin/Settings selector; pause sub-state; `_unhandled_input` capture-forward in `Main` and `CombatScene`; live `_player.controls` refresh; **dynamic combat legend**.
5. **Capture hook + visual verify** — `"settings"` in `_prepare_capture_ui`; screenshot; assert_nonblank.
6. **Record** — note the deferred-difficulty design pointer for the next slice.
