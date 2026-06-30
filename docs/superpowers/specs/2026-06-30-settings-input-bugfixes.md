# Settings / Menu Input Bugfixes

**Date:** 2026-06-30
**Status:** directive (surgical fixes) — from a hands-on playtest of `b2d467b`
**Scope:** two input fixes + one flagged related hazard. No new systems.

## Bug 1 — Esc in settings quits the whole game (input bleed)
**Repro:** open Settings from the title menu, press Esc → settings exits AND the game quits.
**Root cause (confirmed):** `main.gd:85` gates the quit on `Input.is_key_pressed(KEY_ESCAPE)` — a **held-state level check, not a press edge** — for scenes MAIN_MENU/MAP/GAME_OVER. Pressing Esc in Settings: `settings_view.update` sees `input.local_cancel` (edge) → `settings_scene` `goto(MAIN_MENU)`. The Esc key is **still physically held the next frame**, now on the main menu, so the level check at line 85 fires `get_tree().quit()`. One Esc press spans two states. (`_process` runs the quit check *before* the scene update, so on the press frame `_current_scene` is still SETTINGS and it doesn't quit — it's the *carried-over held key* on the following frame that does.)
**Fix:** make the quit **edge-triggered**. Replace `Input.is_key_pressed(KEY_ESCAPE)` at `main.gd:85` with the tracker edge `_input_tracker.pressed_key(KEY_ESCAPE)` (Esc is already synced in `_sync_input_tracker`). Then a held Esc carried out of Settings produces no fresh edge on the menu frame → no quit; a deliberate fresh Esc on the menu still quits.

## Bug 2 — J confirms menu options (misclicks)
**Repro:** in menus, J (the attack key) selects the focused option, causing accidental picks.
**Root cause:** `menu_input.gd:22` — `accept = pressed_key(KEY_J) or KEY_ENTER or KEY_KP_ENTER or KEY_SPACE`. The combat keys J (attack) and Space (dash) double as menu-confirm.
**Fix:** drop the combat keys from menu confirm — `accept = t.pressed_key(KEY_ENTER) or t.pressed_key(KEY_KP_ENTER)` (mouse click stays via `mouse_clicked`). Removing **both J and Space** (both are combat keys that misclick in menus); if you want Space kept, say so. Number keys (1/2/3) for offer/reward are unaffected.
**Hint update:** `map_scene.gd:83` says `"Enter / J or click to travel"` → `"Enter or click to travel"`. (boon/reward already say "Enter or click"; the combat legend's "J tap/hold" is the in-combat attack and stays.)

## Flagged (decide) — Esc on the MAP quits the game and loses the run
The same `main.gd:85` quit list includes `SCENE_MAP`, so Esc mid-run quits the whole app with **no save** — a player pressing Esc expecting "back/menu" loses the run. Options: (a) leave it (just edge-trigger per Bug 1); (b) remove `SCENE_MAP` from the quit list so Esc does nothing on the map; (c) make Esc on the map open a pause/quit-confirm. **Recommend (c) or at least (b)** — instant run-loss on a stray Esc is a feel-bad. Out of scope for the two fixes above unless you choose it.

## Verify
- `./run.sh --test` green. Manual: open Settings (title + pause), Esc returns to the prior screen and does **not** quit; J no longer confirms menu options, Enter/click do; map hint reads "Enter or click to travel."
- Re-capture isn't needed (logic only); a quick interactive pass on title→settings→Esc and a boon-offer pick confirms both.
