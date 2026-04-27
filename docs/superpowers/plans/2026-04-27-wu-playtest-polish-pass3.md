# WU Playtest Polish — Pass 3

**Date:** 2026-04-27
**Source:** Playtest sweep at `/tmp/wu-playtest-2026-04-27/` (16 states), three days after the rerun fixes shipped in commit `830dc54`.
**Companion plans:**
- `docs/superpowers/plans/2026-04-24-wu-playtest-polish.md` — original playtest polish (rev 3, landed in `a3d0ab8`).
- `docs/superpowers/plans/2026-04-24-wu-playtest-polish-rerun.md` — rerun fixes (rev 2, landed in `830dc54`).
**Revision:** 4 — rev 3 fixed the legend lifecycle entry point, the rest fallback, and the shared reward-path verification. Rev 4 reconciles the re-shoot count (it is eleven, not eight or nine), upgrades the event panel helper from `-> float` to a layout `Dictionary` so wrapped lines survive across the height computation and the draw, and explicitly extends the master-reward branch into `_draw_reward_option_with_desc` (the selected-card border + glow), not just the header.

This pass closes the issues that surfaced after the rerun was confirmed visually clean.

---

## Findings summary

| # | Priority | Issue |
|---|---|---|
| 1 | P1 | Combat keybind legend is always-on, full-width English text — reads as debug overlay against the polished arena |
| 2 | P1 | Event / Victory / Rest panels are functional but vertically underfilled — large empty band below content |
| 3 | P2 | Main menu still slightly top-heavy: title card at `0.36 * VIEW_HEIGHT` leaves a wide empty band above |
| 4 | P2 | Game-over panel is a tiny floating box on a vast dark canvas — lacks weight for a run-ending moment |
| 5 | P3 | Master reward looks identical to a regular technique reward — no signal that it's a Master's Teaching node |

---

## P1 — Combat keybind strip pulls focus

**Evidence.**
- `/tmp/wu-playtest-2026-04-27/10_combat_duel.png` — full-text legend `A/D move  W jump  J tap/hold  K block/parry  Space dash  L stance  P pause  R restart` runs across the bottom in `COLOR_TEXT_BODY` at size 15.
- Same in `12_combat_ambush.png` and `13_combat_boss.png`. The bamboo-arena art is now strong; the legend competes with it.

**Root cause.** `WUGodot/scripts/combat_scene.gd:417-419`:

```gdscript
var controls_panel: Rect2 = Rect2(520.0, float(GameConstants.VIEW_HEIGHT) - 70.0, 880.0, 44.0)
_draw_panel(controls_panel)
_draw_text("A/D move  W jump  J tap/hold  K block/parry  Space dash  L stance  P pause  R restart",
           controls_panel.position.x + 18.0, controls_panel.position.y + 28.0,
           GameConstants.COLOR_TEXT_BODY, 15)
```

The strip is 880 × 44 px (≈ 38 % of viewport width), unconditional, full English copy.

**Fix.** Show on first-fight-of-the-run only with a fade-out, and re-summon while paused. The decision is computed in `main.gd` (where `_run_state` lives) and pushed into `CombatScene.setup_combat(...)`, so `CombatScene` itself does not need a reference to `RunState`.

1. **Add a per-run flag in `RunState`.** Add `var legend_seen_this_run: bool = false`. Initialise to `false` in `RunState.create_procedural_run()` so each new run shows the legend once. (Locate the run-init function — check `start_new_run()` in `main.gd:61` for where `_run_state` is constructed.)
2. **Compute the flag in `main.gd` and pass it down.** When transitioning to a combat node (search for the `MapNode.NodeType.BATTLE` / `BOSS` / `ELITE` / `AMBUSH` branches in `main.gd` that ultimately call `combat_scene.setup_combat`), compute:
    ```gdscript
    var show_legend := not _run_state.legend_seen_this_run
    if show_legend:
        _run_state.legend_seen_this_run = true
    ```
    Add a `show_controls_legend: bool = false` parameter to `CombatScene.setup_combat(player, node, show_controls_legend := false)` at `combat_scene.gd:64` and pass `show_legend` from each call site. Defaulting to `false` preserves existing behaviour for any other caller.
3. **Wire the timer in `setup_combat`.** Add `var _controls_legend_timer: float = 0.0` to `combat_scene.gd`. Inside `setup_combat`, set `_controls_legend_timer = 6.0` if `show_controls_legend` is true. Do **not** put this in `_ready()` — `_ready()` fires once at boot before `_run_state` exists, while `setup_combat` is the per-fight entry point.
4. **Decrement in `_process(delta)`.** Locate the existing `_process` in `combat_scene.gd` and add `if _controls_legend_timer > 0.0: _controls_legend_timer = max(0.0, _controls_legend_timer - delta)`. Without this step the legend never fades.
5. **Gate the draw at `combat_scene.gd:417-419`.** Only draw the legend when `_controls_legend_timer > 0.0 or _is_paused or _is_paused_on_end`. Use the scene's own pause flags — these are scene-local, not on `Fighter`. This mirrors the existing `show_full_loadout` guard at `combat_scene.gd:423`.
6. **Alpha fade.** When timer-driven, ramp from 1.0 → 0.0 over the final 1.0 s: `var alpha := clamp(_controls_legend_timer, 0.0, 1.0)`. When pause-driven, render at full alpha. Apply `alpha` to both the panel `Color.a` and the text `Color.a`.
7. **Pause toggle behaviour.** No extra timer push needed at `combat_scene.gd:131` — the gate condition already lets the legend appear while paused and disappear the instant the player un-pauses, which is the right refresher behaviour.

If a future tutorial layer doesn't surface, fallback option:

**Compact key-cap mode (alternative to first-fight gating).** Replace the long English line with eight 28-px key-cap chips (just the key letters, no labels) at lower-left, ~280 px wide. Always visible, but reads as ambient HUD instead of utility text. Use this if playtesters get lost without the legend.

**Recommended:** ship the first-fight + on-pause gate. Reassess after one playtest session whether the compact fallback is needed.

**Verify.** Re-shoot `10_combat_duel.png` after the legend has faded — bottom of screen should show only the technique panel and the boss-beat overlay region. Re-shoot a paused state to confirm the legend reappears.

**Effort.** ~30 min.

---

## P1 — Event / Victory / Rest panels under-filled

**Evidence.**
- `/tmp/wu-playtest-2026-04-27/05_event_choice.png` and `06_event_result.png` — event panel covers ~70 % of viewport but content (title + 1 paragraph + 2 choice rows OR title + 1 paragraph + 1 result paragraph + footer) needs ~25 %. Lower half of the panel is empty in both states.
- `/tmp/wu-playtest-2026-04-27/15_victory.png` — scroll panel covers most of the viewport; below the technique list there is a long empty band before the flavor line.
- `/tmp/wu-playtest-2026-04-27/08_rest.png` — Rest panel sits high with content occupying the upper third; the lower two-thirds of the panel are empty. Same hug-content pattern.

**Root cause.**
- Event panel at `main.gd:647`: `Rect2(360, 186, VIEW_WIDTH-720, 420 or 500)`. Two hard-coded heights (one per state); neither matches actual content.
- Victory scroll at `main.gd:790-820`: `scroll = Rect2(center_x - 340, 80, 680, VIEW_HEIGHT - 160)` — full-viewport-tall by construction.
- Rest panel at `main.gd:725`: `Rect2(520, 260, VIEW_WIDTH-1040, 280)` — fixed 280 px tall, independent of choice count or HP line presence.

**Fix — content-hugging composition.**

### Event panel — choice state (`main.gd:644-680`, else branch)

1. Wrap the body once at the configured size and capture the line count: `var body_lines := _wrap_text(_event_runner.get_text(), max_width, 18).size()`. Reuse the wrapped result when drawing so we do not wrap twice.
2. Body block height = `body_lines * 28.0` (the same `28.0` line-height passed to `_draw_text_block`).
3. Choice block height = `_event_choices.size() * 56.0 + 16.0`.
4. Footer band = 48.0 (instruction line at `panel.end.y - 34` plus the optional `_shop_message` at `-62`).
5. Total height = 96 (title + rule line) + body block + 24 (gap) + choice block + 16 (gap) + footer = computed.
6. Replace the `500.0` literal with the computed height. Centre vertically: `var y0 := (VIEW_HEIGHT - h) * 0.5`.

### Event panel — result state (`main.gd:644-680`, `_event_showing_result == true` branch)

This was missing from rev 1. The result branch at `main.gd:661-663` draws **body block + result block + continue footer**, not body + choices.

1. Body wrap as above → `body_lines`.
2. Result block: `var result_lines := _wrap_text(str(_event_result.get("message", "")), max_width, 19).size()` and height = `result_lines * 30.0` (the `30.0` line-height passed to the second `_draw_text_block` at line 662).
3. Footer band = 28.0 ("Press Enter to continue" at `panel.end.y - 34`).
4. Total height = 96 (title + rule) + body block + 34 (gap before result) + result block + 16 (gap) + footer.
5. Replace the `420.0` literal with this computed height; same vertical centring as the choice state.

**Helper contract.** Both states share a helper, but it cannot return `float` only — the draw path needs the wrapped lines too, and re-wrapping is wasteful. Return a small layout struct keyed by string:

```gdscript
func _compute_event_panel_layout(max_width: float) -> Dictionary:
    var body_lines: Array[String] = _wrap_text(_event_runner.get_text(), max_width, 18)
    var result_lines: Array[String] = []
    if _event_showing_result:
        result_lines = _wrap_text(str(_event_result.get("message", "")), max_width, 19)
    var height: float = 96.0  # title + rule
    height += body_lines.size() * 28.0
    if _event_showing_result:
        height += 34.0 + result_lines.size() * 30.0 + 16.0 + 28.0
    else:
        height += 24.0 + _event_choices.size() * 56.0 + 16.0 + 48.0
    return {
        "height": height,
        "body_lines": body_lines,
        "result_lines": result_lines,
    }
```

The draw path consumes the dictionary, draws the wrapped lines directly (no second wrap), and uses `height` for the panel rect. Alternative: accept a single double-wrap (cheap given the line counts involved) and keep the helper as `-> float`. The dictionary approach is recommended; it makes the contract explicit and avoids hidden recomputation.

### Victory scroll (`main.gd:790-820`)

1. Compute total content height: header (~80) + stats block (~120) + technique list (`technique_count * 32 + header_band`) + flavor + prompt.
2. Replace `Rect2(center_x - 340, 80, 680, VIEW_HEIGHT - 160)` with a content-hugging scroll. Max height ~720 px so it still feels like a scroll, not a postcard.
3. Centre vertically; the prompt at `scroll.end.y - 28` already follows the scroll (alpha + position fix landed in `830dc54`).

### Rest panel (`main.gd:725`)

This is a pure re-centring task; the existing height is already correct.

1. The two choice rows draw at `y = panel.position.y + 126` and `+ 200`; row rects extend to `y + 42`, so the second row's bottom sits at `panel.position.y + 242`. The footer at `panel.end.y - 28` (= `panel.position.y + 252` at h=280) clears the row by 10 px. **Do not shrink the panel** — at h=240 the footer would land at `panel.position.y + 212`, inside the second row's rect (188..252) → collision.
2. The visible problem is the panel anchor: at `y = 260` the panel sits in the upper half, leaving the lower band empty. Re-centre vertically: `var y0 := (VIEW_HEIGHT - 280.0) * 0.5` (= 400). Keep the existing 280 height.
3. If after re-centring the screen still feels under-filled, the right next move is **not** to shrink the panel but to add a faint vignette around it (similar to the modal backdrop at `_draw_modal_backdrop`) so the surrounding emptiness reads as intentional negative space rather than under-utilisation.

**Optional follow-on (out of scope for this pass).** Once panels hug content, the visual void is gone but the screens will feel small. A later art pass can add per-event ornament silhouettes (villager / bandit / ronin keyed off `event.id`) and a chapter seal on the victory scroll. Heavier lift; needs new assets.

**Verify.** Re-shoot `05_event_choice.png`, `06_event_result.png`, `15_victory.png`. Panels should hug their content; vertical bands of empty space gone.

**Effort.** ~25 min for the two hug-rewrites combined.

---

## P2 — Main menu top-heavy

**Evidence.** `/tmp/wu-playtest-2026-04-27/01_main_menu.png` — title card at `title_y = VIEW_HEIGHT * 0.36` puts the card centre at ≈ 388 px. Card top at ≈ 210 px leaves the upper band (0–210) unanchored. Bamboo strip + prompt cluster at the bottom (≈ 800–1080) pulls the eye down. The middle band (560–800) feels like a void between the two heavier ends.

**Current values** (verified at `main.gd:541-555`):

- `title_y = VIEW_HEIGHT * 0.36` (≈ 388).
- `title_panel = Rect2(center_x - 360, title_y - 150, 720, 340)` — card top ≈ 238, bottom ≈ 578.
- `"武"` glyph at size 200.
- Prompt at `VIEW_HEIGHT * 0.89` (≈ 961).

**Fix — drop title further + raise prompt.**

```gdscript
var title_y: float = float(GameConstants.VIEW_HEIGHT) * 0.42  # was 0.36
# title_panel rect unchanged; the y anchor moves with title_y
...
_draw_centered_text("Press Enter to begin", center_x,
    float(GameConstants.VIEW_HEIGHT) * 0.82,  # was 0.89
    Color(...),
    ...)
```

After the change:

- Card centre at ≈ 454 px, bottom at ≈ 624 px.
- Bamboo strip (currently ≈ 700–1000) overlaps the card's lower edge slightly — card and bamboo become one composition unit instead of two heavy ends.
- Prompt at ≈ 886 px sits just above bamboo crowns.

**Optional ornament (deferred).** A thin horizontal ink stroke at `y = 80–120` to anchor the top edge. Adds another 5 min if the rebalanced layout still reads top-heavy after the y-shifts; otherwise skip.

**Verify.** Re-shoot `01_main_menu.png`. Empty band above the card should shrink; card and bamboo strip should read as a single vertical column.

**Effort.** ~5 min.

---

## P2 — Game-over panel under-weighted

**Evidence.** `/tmp/wu-playtest-2026-04-27/16_game_over.png` — the "敗 / Defeated / Time / Press Enter" panel is a small box (520 × 260) centred on a vast nearly-black canvas. There is no atmospheric framing for what should feel like a heavy moment. The panel reads as a confirmation dialog more than a run-ending beat.

**Root cause.** `main.gd:860`: `var panel: Rect2 = Rect2(center_x - 260.0, center_y - 150.0, 520.0, 260.0)`. The panel is content-hugging (good) but there is no ambient framing around it.

**Fix.** Two non-exclusive options:

- **A. Enlarge the 敗 character.** Currently sized similarly to the menu's 武 (around 132–200). Bump to 280–320 so it reads as the dominant visual element, with "Defeated" / Time / prompt clustered below. Drop the surrounding rectangle frame; let the negative space itself be the framing.
- **B. Add a subtle background atmosphere.** Draw a faint fading red radial wash centred on the 敗 glyph (40 px radius soft-edge, alpha 0.06–0.12). Cheap; gives the screen weight without new art.

Recommended: **A + B**. ~10 min combined.

**Verify.** Re-shoot `16_game_over.png`. The 敗 should dominate vertically; the screen should feel like an ending beat, not a modal.

**Effort.** ~10 min.

---

## P3 — Master reward indistinguishable from regular technique reward

**Evidence.** `/tmp/wu-playtest-2026-04-27/04_reward_master.png` and `03_reward_technique.png` are essentially identical layouts ("得技 Technique Acquired", three choice cards, same accent colours). Players cannot tell from the screen alone whether they're at a normal Battle reward or the rarer Master node — which the map highlights with `#905ea9` (purple).

**Fix — small differentiation, no new asset.** The branch lives at two layers: `_draw_reward()` for the header / wash, and `_draw_reward_option_with_desc` for the per-card border + glow.

1. **Header text branches on node type** in `_draw_reward()` (`main.gd:620`). When the current map node is `MapNode.NodeType.MASTER`, render `拜師 Master's Teaching` instead of `得技 Technique Acquired`.
2. **Header band background tint** in the same `_draw_reward()` body: a thin purple wash (`Color(0.564, 0.243, 0.459, 0.18)`, the VINIK24 `#905ea9` at 18 % alpha) instead of the existing warm-grey wash.
3. **Selected-card border + glow** at `_draw_reward_option_with_desc` (`main.gd:902-916`). Currently the selected border and the 0.10-alpha glow rect both hardcode `GameConstants.COLOR_PANEL_ACCENT` (gold). The header tweak is not enough — the per-card visual still reads gold without this layer.

   The cleanest fix is to **add an `accent: Color = COLOR_PANEL_ACCENT` parameter** to the helper:

   ```gdscript
   func _draw_reward_option_with_desc(
       rect: Rect2,
       label: String,
       description: String,
       selected: bool,
       accent: Color = GameConstants.COLOR_PANEL_ACCENT,
   ) -> void:
       ...
       if selected:
           border = accent
       if selected:
           draw_rect(rect.grow(8.0),
               Color(accent.r, accent.g, accent.b, 0.10), true)
       ...
   ```

   `_draw_reward()` then passes `GameConstants.COLOR_VIOLET` (or a new `COLOR_MASTER_ACCENT = #905ea9`) for Master nodes and the default gold for everything else. Default-arg keeps every other caller unchanged.

Players who learn the purple cue on the map will recognise it on the reward screen.

**Verify.** Re-shoot `04_reward_master.png`. Compare side-by-side with `03_reward_technique.png` and confirm a player can distinguish the two screens at a glance.

**Effort.** ~15 min including string lookup for "Master's Teaching" (`拜師` literally; or use the existing localisation strings if any).

---

## Order of operations

1. **P1 combat HUD** (gate the legend, decrement timer, fade alpha). Highest-impact change for atmosphere; isolated to `combat_scene.gd` + a one-field add to `RunState`.
2. **P1 panels hug** (event choice + event result + victory + rest). Touches `_draw_event`, `_draw_victory`, `_draw_rest` in `main.gd`. Author the `_compute_event_panel_height` helper to keep the calling sites clean.
3. **P2 menu rebalance** (two y-coordinate edits in `_draw_main_menu`).
4. **P2 game-over weight** (enlarge 敗, add radial wash). Five lines.
5. **P3 master reward differentiation** (header text + tint + border colour). Three lines + one new bilingual string.

Total: ~90 min work, one re-import, **eleven-shot re-shoot** (see verification list below: `01`, `03`, `04`, `05`, `06`, `08`, `10`, `13`, `15`, `16`, plus the new `17_combat_paused`).

---

## Preconditions

- Commits `a3d0ab8` (polish) and `830dc54` (rerun) landed.
- Godot 4.6.2+ available via `./run.sh`. Use `./run.sh --reimport` if any new font sizes / panels affect the import cache (unlikely for this pass — pure code edits).
- Playtest capture tooling available to re-shoot the eleven target states (ten existing + one new paused-combat capture; see verification checklist).

---

## Verification checklist after implementation

Re-shoot **eleven** states (ten existing + the new paused capture: `01`, `03`, `04`, `05`, `06`, `08`, `10`, `13`, `15`, `16`, `17`). Note `03_reward_technique.png` is included because `_draw_reward()` at `main.gd:620` is shared between regular Battle/Boss reward and Master reward — the master differentiation branches inside the shared function and could regress the regular path.

- [ ] `01_main_menu.png` — reads as coherent vertical column, no empty band above title card.
- [ ] `03_reward_technique.png` — **fresh re-shoot**. Header still reads `得技 Technique Acquired`; gold accent unchanged; no purple bleed from the master branch.
- [ ] `04_reward_master.png` — header reads `拜師 Master's Teaching`; selected card border is purple; visually distinct from `03` at a glance.
- [ ] `05_event_choice.png` and `06_event_result.png` — both states hug their content; no empty band below the last choice / result paragraph.
- [ ] `08_rest.png` — panel re-centred vertically; sits in the middle third. Footer still clears the second row.
- [ ] `10_combat_duel.png` (post-fade) — keybind legend not visible; only technique panel + boss-beat overlay region at the bottom.
- [ ] `13_combat_boss.png` (post-fade) — keybind legend not visible during boss combat; legend's first-fight gate flipped before the boss node was reached.
- [ ] `15_victory.png` — scroll hugs content; flavor line and prompt sit just below the technique list.
- [ ] `16_game_over.png` — 敗 character dominates; faint radial wash visible; prompt visible.
- [ ] **NEW** `17_combat_paused.png` — captured during a paused combat state; the keybind legend reappears at full alpha while paused. Add this to the capture script's coverage list.

Also:

- [ ] `./run.sh --test` passes (144+ tests). If the legend lifecycle (`legend_seen_this_run` flip + `setup_combat` gating) wants test coverage, add a narrow test mirroring the `_wrap_text` extraction pattern from `830dc54`.
- [ ] No regression on shop / forget-technique / map — those stayed green in this re-shoot and should remain unchanged. (Reward regular path now has its own re-shoot above.)

---

## Out of scope for this pass

- Per-event silhouette ornaments / chapter seal art (deferred to a later art pass).
- Compact key-cap fallback (only ship if first-fight gating leaves new players lost; treat as a follow-up).
- Top-edge ornament stroke on the menu (skip unless the y-shift alone doesn't rebalance).
- Combat HUD information architecture rework (technique panel position, enemy nameplate styling) — none flagged in this re-shoot.
- Map polish (gold-coin glyph for "Gold:", chapter Chinese label on the Selected Route footer for symmetry) — observed in `02_map.png`, low priority.

---

## What "done" looks like

After this pass, the four key playtest deltas across menu / event / victory / combat read as authored compositions, not as functional layouts with placeholder padding. The polish-pass arc that started with the original 16-shot playtest closes here unless a new round surfaces material issues.

---

## Revision notes (rev 2, 2026-04-27)

Three review corrections + three additional findings from a deeper pass through the playtest sweep:

**Corrections:**

1. **Combat-legend implementability.** Rev 1 said to gate on `_player.is_paused`, but pause state lives on `CombatScene` as `_is_paused` / `_is_paused_on_end` (combat_scene.gd:23, :32, :131, :310). Rev 1 also never said where `_controls_legend_timer` is decremented, so following it literally would have produced a legend that never fades. Rev 2 spells out: scene-local pause flags (matching the existing `show_full_loadout` guard at `combat_scene.gd:423`), explicit `_process` decrement step, and a `_legend_seen_this_run` flag on `RunState` (not a session flag, not on Fighter) so the legend shows once per run and resets via the existing `start_new_run()` path.
2. **Event result-state height.** Rev 1's height formula only covered the choice state (body + choices + footer). The result state at `main.gd:661-663` draws **body + result block + continue footer**, no choices. Rev 2 authors a separate result-state formula with `result_lines * 30.0` and asks the implementer to share both via a `_compute_event_panel_height` helper.
3. **Verification scope.** Rev 1 listed six shots but the checklist required validating boss-combat legend behaviour and a paused state. Rev 2 expands to eight shots (adding `13_combat_boss`, `04_reward_master`, and a new `17_combat_paused`) so every claim in the checklist has a corresponding screenshot.

**Open question resolved.** Legend persistence is **per-run, not per-session**. Reset on `start_new_run()`. Players need the refresher between runs because of natural attention drift; mid-run combat-to-combat does not need it. The flag lives on `RunState`, not on `Fighter` or a static singleton.

**New findings from re-reviewing the additional shots:**

4. **Rest panel under-filled** (P1, bundled with event/victory hug). `08_rest.png` shows the panel anchored at `y=260` in the upper half. Re-centre to the viewport mid-third; existing panel height is approximately right.
5. **Game-over panel under-weighted** (P2). `16_game_over.png` shows a small box on a vast canvas. Enlarge 敗 to 280–320 and add a faint radial wash for atmosphere.
6. **Master reward not visually distinct** (P3). `04_reward_master.png` is identical to `03_reward_technique.png`. Branch header text to `拜師 Master's Teaching`, tint header band purple (`#905ea9` at 18 % alpha), use purple for selected-card border. No new assets needed.

**Out-of-scope nits noted:** `02_map.png` could use a coin glyph and a chapter label on the route footer; deferred.

---

## Revision notes (rev 3, 2026-04-27)

Three review corrections after a code-grounded second pass:

1. **Legend lifecycle was attached to the wrong entry point.** Rev 2 said to flip `_legend_seen_this_run` in `combat_scene.gd._ready()`. But `_ready()` runs once at boot before `_run_state` exists (`combat_scene.gd:44`), and `CombatScene` has no field that holds the run state. The per-fight init point is `setup_combat(player, node)` at `combat_scene.gd:64`. Rev 3 moves the decision up a layer: `main.gd` (which owns `_run_state`) computes `show_controls_legend` before each combat transition and passes it as a new optional parameter into `setup_combat(player, node, show_controls_legend := false)`. `CombatScene` keeps a local timer; the run-state flag never crosses the layer boundary. Open-question variant from the review accepted: "decision computed up a layer" is cleaner than "plumb run_state into CombatScene", and rev 3 ships that variant.
2. **Rest "drop to 240" fallback would have collided.** Rev 2 said the height was about right but offered `h = 240` as a fallback if the panel still felt light. With the second row drawing at `panel.position.y + 200` and rect height 64, the row's bottom is at `panel.position.y + 242`. At `h = 240`, the footer at `panel.end.y - 28` lands at `panel.position.y + 212` — inside the second row's rect (188..252). Rev 3 drops the 240 fallback entirely; the task is pure re-centring with the existing 280 height. If the screen still feels light after re-centring, the next move is a vignette overlay, not a height shrink.
3. **Verification scope still missed the regular reward path.** `_draw_reward()` at `main.gd:620` is shared by Master and regular Battle/Boss reward nodes. The master differentiation branches inside that function, so the regular reward can regress silently. Rev 2 only added `04_reward_master.png` and asked for a side-by-side against the older `03_reward_technique.png` capture. Rev 3 explicitly adds a fresh `03_reward_technique.png` shot to the re-shoot list and clears the stale "six target states" line in the preconditions block (now: nine target states).

---

## Revision notes (rev 4, 2026-04-27)

Three more review corrections:

1. **Re-shoot count was internally inconsistent.** Rev 3 listed "eight-shot re-shoot" in the order-of-operations summary, "nine target states" in Preconditions, and 11 actual entries (`01, 03, 04, 05, 06, 08, 10, 13, 15, 16, 17`) in the verification checklist. Rev 4 reconciles all three to **eleven** to match the checklist (the canonical source). Avoids drift in the capture script and any task-list copy-paste.
2. **Event panel helper contract upgraded.** Rev 3 said "wrap once, reuse the lines" but specified a helper that returned `float` only. A height-only helper cannot also hand back the wrapped lines, so as written either the rule is violated (re-wrap during draw) or the helper is unimplementable. Rev 4 makes the helper return a `Dictionary` containing `height`, `body_lines`, and `result_lines`. The draw path consumes the same dictionary so wrapping happens exactly once. Alternative documented (single double-wrap, keep `-> float`) but recommended approach is the dictionary.
3. **Master-reward branch must reach `_draw_reward_option_with_desc`.** Rev 3 noted `_draw_reward()` is shared but stopped at the header tweak. Inspection of `main.gd:902-916` shows the selected-card border and the 0.10-alpha glow rect both hardcode `GameConstants.COLOR_PANEL_ACCENT` (gold). Without touching that helper, the per-card visual still reads gold even after the header changes. Rev 4 adds an `accent: Color = COLOR_PANEL_ACCENT` parameter to the helper signature so `_draw_reward()` can pass `#905ea9` for Master nodes and the default gold for everything else; the default-arg keeps every other call site unchanged.
